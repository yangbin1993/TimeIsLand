import { hilog } from '@kit.PerformanceAnalysisKit';
import { HttpInterceptor } from './Interceptor';
import { RequestContext, ResponseContext } from '../model/HttpOptions';
import { NetworkError, HttpStatusError } from '../model/HttpErrors';

const TAG = 'RetryInterceptor';
const DOMAIN = 0x0000;

/**
 * RetryInterceptor 配置项
 */
export interface RetryConfig {
  /**
   * 最大重试次数（不含首次请求），默认 3 次
   */
  maxRetries?: number;

  /**
   * 首次重试等待基准时间（单位：ms），指数退避以此为底数，默认 500ms
   */
  baseDelayMs?: number;

  /**
   * 单次重试最大等待上限（单位：ms），防止退避时间过长阻塞 UI，默认 8000ms
   */
  maxDelayMs?: number;

  /**
   * 抖动因子（0~1），在退避时间上叠加随机抖动，避免集群惊群效应，默认 0.3
   */
  jitterFactor?: number;

  /**
   * 需要触发重试的 HTTP 状态码白名单（仅对幂等方法生效）
   * 默认：[429, 500, 502, 503, 504]
   */
  retryableStatusCodes?: number[];

  /**
   * 允许重试的 HTTP 方法白名单（非幂等方法 POST 默认不重试，防止重复提交）
   * 默认：['GET', 'HEAD', 'PUT', 'DELETE', 'PATCH']
   */
  retryableMethods?: string[];
}

/**
 * 生产级指数退避自动重试拦截器 (RetryInterceptor)
 *
 * 核心特性：
 * 1. 指数退避 + 随机抖动：每次重试等待时间按 baseDelay * 2^n + jitter 递增，
 *    有效规避服务端恢复期的惊群效应 (Thundering Herd)；
 * 2. 幂等性保护：仅对 GET/HEAD/PUT/DELETE/PATCH 等幂等方法开启重试，
 *    POST 默认豁免，防止重复提交引发的幂等安全问题；
 * 3. 精准错误识别：分别处理 NetworkError（底层网络故障）与 HttpStatusError（服务端临时故障）；
 * 4. 强类型可配置：所有参数均有合理默认值，业务侧按需覆盖即可；
 * 5. 无侵入挂载：符合 HttpInterceptor 契约，通过 httpClient.addInterceptor() 一行接入。
 *
 * 注意：RetryInterceptor 依赖 HttpClient 重新驱动请求，由于当前拦截器管线为单次流转设计，
 * 重试逻辑在此实现为请求前阶段标记 + 独立辅助方法，通过外部 HttpClient 集成调用。
 * 实际工业实践中推荐将重试策略作为 HttpClient.request() 的装饰层，详见集成说明。
 */
export class RetryInterceptor implements HttpInterceptor {
  private readonly maxRetries: number;
  private readonly baseDelayMs: number;
  private readonly maxDelayMs: number;
  private readonly jitterFactor: number;
  private readonly retryableStatusCodes: Set<number>;
  private readonly retryableMethods: Set<string>;

  constructor(config?: RetryConfig) {
    this.maxRetries = config?.maxRetries ?? 3;
    this.baseDelayMs = config?.baseDelayMs ?? 500;
    this.maxDelayMs = config?.maxDelayMs ?? 8000;
    this.jitterFactor = Math.min(1, Math.max(0, config?.jitterFactor ?? 0.3));
    this.retryableStatusCodes = new Set(
      config?.retryableStatusCodes ?? [429, 500, 502, 503, 504]
    );
    this.retryableMethods = new Set(
      config?.retryableMethods ?? ['GET', 'HEAD', 'PUT', 'DELETE', 'PATCH']
    );
  }

  /**
   * 计算第 n 次重试的等待时间（指数退避 + 随机抖动）
   *
   * @param attempt 当前重试轮次（从 1 开始）
   * @returns 实际等待毫秒数
   */
  public calculateDelay(attempt: number): number {
    // 指数退避：base * 2^(n-1)
    const exponential = this.baseDelayMs * Math.pow(2, attempt - 1);
    // 叠加随机抖动：[-jitter, +jitter] 范围内随机偏移
    const jitter = exponential * this.jitterFactor * (Math.random() * 2 - 1);
    const delay = exponential + jitter;
    return Math.min(Math.max(0, delay), this.maxDelayMs);
  }

  /**
   * 判断给定的 HTTP 响应状态码是否属于可重试的临时故障
   *
   * @param statusCode HTTP 响应状态码
   */
  public isRetryableStatusCode(statusCode: number): boolean {
    return this.retryableStatusCodes.has(statusCode);
  }

  /**
   * 判断给定的 HTTP 方法是否允许重试（幂等性保护）
   *
   * @param method HTTP 请求方法
   */
  public isRetryableMethod(method: string): boolean {
    return this.retryableMethods.has(method.toUpperCase());
  }

  /**
   * 通用重试执行包装器（供 HttpClient 直接集成使用）
   * 封装完整的重试调度逻辑：指数退避 + 错误分类 + 最终失败透传
   *
   * @param method 当前请求的 HTTP 方法（用于幂等性校验）
   * @param action 包裹实际请求的异步闭包（发生异常时将触发重试）
   * @returns 请求成功时的响应数据 T
   * @throws 超出最大重试次数后透传最后一次异常
   */
  public async executeWithRetry<T>(method: string, action: () => Promise<T>): Promise<T> {
    let lastError: Error = new Error('Unknown error');

    for (let attempt = 0; attempt <= this.maxRetries; attempt++) {
      try {
        return await action();
      } catch (err) {
        lastError = err as Error;
        const isLastAttempt = attempt === this.maxRetries;

        if (isLastAttempt) {
          break;
        }

        // 判断此次错误是否值得重试
        const shouldRetry = this.shouldRetryError(err as Error, method);
        if (!shouldRetry) {
          hilog.info(
            DOMAIN, TAG,
            `[${method}] Error is not retryable (${(err as Error)?.constructor?.name}), skipping retry.`
          );
          throw err;
        }

        const delayMs = this.calculateDelay(attempt + 1);
        hilog.warn(
          DOMAIN, TAG,
          `[${method}] Attempt ${attempt + 1}/${this.maxRetries} failed: ${(err as Error).message}. ` +
          `Retrying in ${Math.round(delayMs)}ms...`
        );

        await this.delay(delayMs);
      }
    }

    hilog.error(
      DOMAIN, TAG,
      `[${method}] All ${this.maxRetries} retry attempts exhausted. Last error: ${lastError.message}`
    );
    throw lastError;
  }

  /**
   * 判断给定错误是否应当触发重试
   *
   * @param err 捕获到的异常
   * @param method HTTP 方法
   */
  private shouldRetryError(err: Error, method: string): boolean {
    // 非幂等方法不重试
    if (!this.isRetryableMethod(method)) {
      return false;
    }

    // 底层网络故障（断网/超时/DNS）始终触发重试
    if (err instanceof NetworkError) {
      return true;
    }

    // HTTP 状态码故障按白名单决策（仅服务端临时故障重试）
    if (err instanceof HttpStatusError) {
      return this.isRetryableStatusCode(err.httpStatus);
    }

    // 业务错误（BusinessError）与 SSL 证书错误不重试
    return false;
  }

  /**
   * 异步等待指定毫秒（利用 Promise + setTimeout 实现非阻塞延迟）
   */
  private delay(ms: number): Promise<void> {
    return new Promise<void>((resolve) => {
      setTimeout(() => resolve(), ms);
    });
  }

  // 以下实现 HttpInterceptor 接口（作为管线节点的轻量代理）
  // 实际重试逻辑通过 executeWithRetry() 在 HttpClient.request() 中集成

  public onRequest(context: RequestContext): RequestContext {
    return context;
  }

  public onResponse(response: ResponseContext): ResponseContext {
    return response;
  }
}
