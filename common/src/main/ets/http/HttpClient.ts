import { rcp } from '@kit.RemoteCommunicationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ApiResponse, isBusinessSuccess } from './model/ApiResponse';
import { BusinessError, HttpStatusError, NetworkError } from './model/HttpErrors';
import { SslCertificateError } from './model/SslCertificateError';
import { HttpMethod, RequestContext, RequestOptions, ResponseContext } from './model/HttpOptions';
import { CancelToken, CancelledError } from './model/CancelToken';
import { HttpInterceptor } from './interceptor/Interceptor';
import { NetworkStateInterceptor } from './interceptor/NetworkStateInterceptor';
import { HeaderInterceptor } from './interceptor/HeaderInterceptor';
import { AuthInterceptor, UnauthorizedHandler } from './interceptor/AuthInterceptor';
import { LoggingInterceptor } from './interceptor/LoggingInterceptor';
import { CertificateFailureInterceptor } from './interceptor/CertificateFailureInterceptor';
import { RetryInterceptor, RetryConfig } from './interceptor/RetryInterceptor';
import { RcpPinningManager } from './security/RcpPinningManager';
import { HttpConfigProvider } from './config/HttpConfigProvider';
import { CommonStrings } from '../constants/CommonStrings';
import { common } from '@kit.AbilityKit';

const TAG = 'HttpClient';
const DOMAIN = 0x0000;

/**
 * 全局超时时间配置结构
 */
export interface TimeoutConfig {
  connectTimeoutMs?: number;   // 建立 TCP/TLS 连接超时时间 (ms)
  transferTimeoutMs?: number;  // 数据传输与读取超时时间 (ms)
}

/**
 * 生产级通用 HTTP 客户端门面 (HttpClient)
 * 基于 HarmonyOS NEXT 官方最新的 @kit.RemoteCommunicationKit (RCP) 深度构建
 * 
 * 核心架构特性：
 * 1. 会话级连接池复用：单例管理底层 rcp.Session，消除高频创建销毁导致的 TCP 握手开销
 * 2. 对称责任链拦截器管线：支持前置 onRequest 与后置 onResponse 双向流转
 * 3. 鸿蒙专属通信感知：内置断网快速熔断与蜂窝数据防超额流量拦截
 * 4. 强类型分层异常分类：精准区分底层网络故障、HTTP 状态码错误与业务逻辑返回码异常
 * 5. 全场景 RESTful 支持：智能参数拼接、自动转义、泛型反序列化
 * 6. HTTPS 安全三道防线：集成 RcpPinningManager，支持证书过期识别、逃生通道自愈与系统退守
 */
export class HttpClient {
  private static instance: HttpClient;
  private baseUrl: string = 'https://api.example.com';
  private configProvider?: HttpConfigProvider;
  private session: rcp.Session;
  private interceptors: HttpInterceptor[] = [];
  private currentTimeout: TimeoutConfig = { connectTimeoutMs: 10000, transferTimeoutMs: 15000 };
  private inflightRequests: Map<string, Promise<unknown>> = new Map();

  // 安全与证书锁定管理器
  public readonly pinningManager: RcpPinningManager;

  // 内置核心拦截器实例，便于开发者快速外部配置与定制
  public readonly networkStateInterceptor: NetworkStateInterceptor;
  public readonly headerInterceptor: HeaderInterceptor;
  public readonly authInterceptor: AuthInterceptor;
  public readonly loggingInterceptor: LoggingInterceptor;
  public readonly certificateFailureInterceptor: CertificateFailureInterceptor;

  // 内置指数退避自动重试拦截器
  public readonly retryInterceptor: RetryInterceptor;

  private constructor() {
    this.pinningManager = RcpPinningManager.getInstance();
    // 监听安全配置变更以热重载底层 Session
    this.pinningManager.initialize(undefined, () => this.rebuildSession());

    // 实例化底层单例会话，注入安全证书配置
    this.session = this.createRcpSession(this.currentTimeout);

    // 初始化核心拦截器链（网络状态感知置于管线首位进行快速断网熔断）
    this.networkStateInterceptor = new NetworkStateInterceptor();
    this.certificateFailureInterceptor = new CertificateFailureInterceptor(this.pinningManager);
    this.headerInterceptor = new HeaderInterceptor('1.0.0');
    this.authInterceptor = new AuthInterceptor();
    this.loggingInterceptor = new LoggingInterceptor(true);
    this.retryInterceptor = new RetryInterceptor();

    this.interceptors.push(this.networkStateInterceptor);
    this.interceptors.push(this.certificateFailureInterceptor);
    this.interceptors.push(this.headerInterceptor);
    this.interceptors.push(this.authInterceptor);
    this.interceptors.push(this.loggingInterceptor);

    hilog.info(DOMAIN, TAG, 'HttpClient initialized with RCP session, SSL pinning manager & default interceptor pipeline.');
  }

  /**
   * 构建带有安全配置与超时控制的底层 RCP 会话
   */
  private createRcpSession(timeoutConfig?: TimeoutConfig): rcp.Session {
    const securityConfig = this.pinningManager.buildSecurityConfiguration();
    return rcp.createSession({
      requestConfiguration: {
        security: securityConfig,
        transfer: {
          timeout: {
            connectMs: timeoutConfig?.connectTimeoutMs ?? this.currentTimeout.connectTimeoutMs ?? 10000,
            transferMs: timeoutConfig?.transferTimeoutMs ?? this.currentTimeout.transferTimeoutMs ?? 15000
          }
        }
      }
    });
  }

  /**
   * 热重载底层的 RCP Session（当证书指纹动态刷新或触发全局降级退守时调用）
   */
  public rebuildSession(): void {
    try {
      const oldSession = this.session;
      this.session = this.createRcpSession(this.currentTimeout);
      hilog.info(DOMAIN, TAG, 'HttpClient session 热重载成功 (安全策略与证书指纹已同步更新)');
      if (oldSession) {
        try {
          oldSession.close();
        } catch (e) {
          // 忽略旧会话关闭异常
        }
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, '热重载 HttpClient session 失败: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 初始化证书锁定与自愈体系（推荐在 UIAbility onCreate 中调用）
   * 
   * @param context UIAbility 上下文（开启 Preferences 本地固化）
   * @param businessDomain 业务主域名
   * @param configServerUrl 逃生通道配置地址
   */
  public initializePinning(context?: common.Context, businessDomain?: string, configServerUrl?: string): void {
    if (businessDomain) {
      this.pinningManager.setBusinessDomain(businessDomain);
    }
    if (configServerUrl) {
      this.pinningManager.setConfigServerUrl(configServerUrl);
    }
    this.pinningManager.initialize(context, () => this.rebuildSession());
  }

  /**
   * 获取全局单例 HttpClient 实例
   */
  public static getInstance(): HttpClient {
    if (!HttpClient.instance) {
      HttpClient.instance = new HttpClient();
    }
    return HttpClient.instance;
  }

  /**
   * 依赖倒置核心入口：注册业务层配置提供者 (HttpConfigProvider)
   * 业务模块在启动时注入具体实现，实现域名、环境与公共请求头的动态提供
   * 
   * @param provider 业务宿主模块实现的 HttpConfigProvider 实例
   */
  public setConfigProvider(provider: HttpConfigProvider): void {
    this.configProvider = provider;
    // 若业务提供者提供了定制超时设置，自动应用并同步底层会话
    if (provider.getConnectTimeoutMs || provider.getTransferTimeoutMs) {
      const connectMs = provider.getConnectTimeoutMs ? provider.getConnectTimeoutMs() : this.currentTimeout.connectTimeoutMs;
      const transferMs = provider.getTransferTimeoutMs ? provider.getTransferTimeoutMs() : this.currentTimeout.transferTimeoutMs;
      this.currentTimeout = {
        connectTimeoutMs: connectMs,
        transferTimeoutMs: transferMs
      };
      this.rebuildSession();
    }
    hilog.info(DOMAIN, TAG, `HttpConfigProvider registered successfully: ${this.getBaseUrl()}`);
  }

  /**
   * 获取当前配置提供者实例
   */
  public getConfigProvider(): HttpConfigProvider | undefined {
    return this.configProvider;
  }

  /**
   * 配置全局请求基础域名（兼容直接设置方式）
   * @param url 基础域名路径，如 https://api.example.com
   */
  public setBaseUrl(url: string): void {
    this.baseUrl = url.endsWith('/') ? url.slice(0, -1) : url;
    hilog.info(DOMAIN, TAG, `Base URL configured manually: ${this.baseUrl}`);
  }

  /**
   * 获取当前配置的基础域名（优先从注入的 HttpConfigProvider 动态拉取）
   */
  public getBaseUrl(): string {
    if (this.configProvider) {
      const dynamicUrl = this.configProvider.getBaseUrl();
      return dynamicUrl.endsWith('/') ? dynamicUrl.slice(0, -1) : dynamicUrl;
    }
    return this.baseUrl;
  }

  /**
   * 设置全局用户鉴权 Token
   * @param token Bearer Token 凭证字符串
   */
  public setAuthToken(token: string): void {
    this.authInterceptor.setToken(token);
  }

  /**
   * 清除当前保存在拦截器中的 Token 凭据
   */
  public clearAuthToken(): void {
    this.authInterceptor.clearToken();
  }

  /**
   * 注册 401 身份未授权/过期统一回调
   * @param handler 身份过期时的回调函数（例如触发登录页跳转）
   */
  public setUnauthorizedHandler(handler: UnauthorizedHandler): void {
    this.authInterceptor.setUnauthorizedHandler(handler);
  }

  /**
   * 注册自定义拦截器（例如签名加密、指标监控）
   * @param interceptor 符合 HttpInterceptor 契约的实例
   */
  public addInterceptor(interceptor: HttpInterceptor): void {
    this.interceptors.push(interceptor);
  }

  /**
   * 动态配置全局自动重试策略
   * 支持运行时覆盖默认重试次数、退避基准时间与可重试状态码
   *
   * @param config 重试策略配置项
   */
  public setRetryConfig(config: RetryConfig): void {
    (this as unknown as { _retryInterceptor: RetryInterceptor })._retryInterceptor = new RetryInterceptor(config);
    // 用新配置的 RetryInterceptor 替换实例引用（绕过 readonly 仅用于运行时热更新）
    Object.assign(this, { retryInterceptor: new RetryInterceptor(config) });
    hilog.info(DOMAIN, TAG, `RetryInterceptor config updated: maxRetries=${config.maxRetries ?? 3}`);
  }

  /**
   * 重新配置全局超时时间
   * @param config 包含 connectTimeoutMs 与 transferTimeoutMs 的配置对象
   */
  public setTimeout(config: TimeoutConfig): void {
    this.currentTimeout = {
      connectTimeoutMs: config.connectTimeoutMs ?? this.currentTimeout.connectTimeoutMs,
      transferTimeoutMs: config.transferTimeoutMs ?? this.currentTimeout.transferTimeoutMs
    };
    this.rebuildSession();
  }

  /**
   * 从完整 URL 中提取主机名/域名
   */
  private extractDomain(url: string): string {
    const match = url.match(/^https?:\/\/([^/?#:]+)/i);
    return match && match[1] ? match[1] : this.getBaseUrl();
  }

  /**
   * 拼接完整的绝对请求 URL 并处理 Query 参数的智能键值编码与转义
   */
  private buildFullUrl(endpoint: string, params?: Record<string, string | number | boolean>): string {
    const currentBaseUrl = this.getBaseUrl();
    let fullUrl = endpoint.startsWith('http://') || endpoint.startsWith('https://')
      ? endpoint
      : `${currentBaseUrl}${endpoint.startsWith('/') ? endpoint : '/' + endpoint}`;

    if (!params) {
      return fullUrl;
    }

    const queryParts: string[] = [];
    const keys = Object.keys(params);
    for (let i = 0; i < keys.length; i++) {
      const key = keys[i];
      const value = params[key];
      if (value !== undefined && value !== null) {
        queryParts.push(`${encodeURIComponent(key)}=${encodeURIComponent(String(value))}`);
      }
    }

    if (queryParts.length > 0) {
      const separator = fullUrl.includes('?') ? '&' : '?';
      fullUrl += `${separator}${queryParts.join('&')}`;
    }

    return fullUrl;
  }

  /**
   * 执行前置请求拦截器链（正序执行：Network -> Header -> Auth -> Logging）
   */
  private async runRequestInterceptors(context: RequestContext): Promise<RequestContext> {
    let currentContext = context;
    for (let i = 0; i < this.interceptors.length; i++) {
      const interceptor = this.interceptors[i];
      if (interceptor.onRequest) {
        currentContext = await interceptor.onRequest(currentContext);
      }
    }
    return currentContext;
  }

  /**
   * 执行后置响应拦截器链（倒序执行：Logging -> Auth -> Header -> Network，形成对称封闭责任链）
   */
  private async runResponseInterceptors(response: ResponseContext): Promise<ResponseContext> {
    let currentResponse = response;
    for (let i = this.interceptors.length - 1; i >= 0; i--) {
      const interceptor = this.interceptors[i];
      if (interceptor.onResponse) {
        currentResponse = await interceptor.onResponse(currentResponse);
      }
    }
    return currentResponse;
  }

  /**
   * 统一网络请求核心驱动方法
   * 
   * @param endpoint 目标请求端点或完整 URL
   * @param method HTTP 请求动词
   * @param options 单次请求的个性化配置项
   * @param body 请求体数据载荷
   * @returns 解析后的业务实体数据 T
   * @throws NetworkError 断网、超时或底层网络故障
   * @throws HttpStatusError 服务端非 200 HTTP 状态码
   * @throws BusinessError 业务状态码不等于成功码
   */
  public async request<T>(
    endpoint: string,
    method: HttpMethod = 'GET',
    options?: RequestOptions,
    body?: Object | string
  ): Promise<T> {
    const shouldDeduplicate = options?.deduplicate === true;
    const dedupeKey = shouldDeduplicate ? `${method}:${this.buildFullUrl(endpoint, options?.params)}` : '';

    if (dedupeKey && this.inflightRequests.has(dedupeKey)) {
      hilog.info(DOMAIN, TAG, `Reusing inflight request promise for: ${dedupeKey}`);
      return this.inflightRequests.get(dedupeKey) as Promise<T>;
    }

    const requestPromise = this.retryInterceptor.executeWithRetry<T>(
      method,
      () => this.doRequest<T>(endpoint, method, options, body)
    );

    if (dedupeKey) {
      this.inflightRequests.set(dedupeKey, requestPromise);
      requestPromise.finally(() => {
        this.inflightRequests.delete(dedupeKey);
      });
    }

    return requestPromise;
  }

  /**
   * 单次实际网络请求驱动（由 RetryInterceptor.executeWithRetry 包裹调用）
   */
  private async doRequest<T>(
    endpoint: string,
    method: HttpMethod = 'GET',
    options?: RequestOptions,
    body?: Object | string
  ): Promise<T> {
    const targetUrl = this.buildFullUrl(endpoint, options?.params);

    // 1. 初始化并顺次执行前置拦截器 (合并业务配置提供者的全局 Header)
    const dynamicHeaders: Record<string, string> = this.configProvider?.getCommonHeaders
      ? this.configProvider.getCommonHeaders()
      : {};
    const mergedHeaders: Record<string, string> = { ...dynamicHeaders, ...(options?.headers ?? {}) };

    let context: RequestContext = {
      url: targetUrl,
      method: method,
      headers: mergedHeaders,
      params: options?.params,
      body: body,
      options: options
    };
    context = await this.runRequestInterceptors(context);

    // 2. 构造符合 RCP 规范的底层请求对象
    const startTime = Date.now();
    let rcpContent: string | undefined = undefined;
    if (context.body !== undefined && context.body !== null) {
      rcpContent = typeof context.body === 'string' ? context.body : JSON.stringify(context.body);
    }

    const rcpHeaders: Record<string, string> = { ...context.headers };
    const rcpRequest = new rcp.Request(context.url, context.method, rcpHeaders, rcpContent);

    // 协作式请求取消：检查取消状态并注册解绑监听器
    options?.cancelToken?.throwIfCancelled();
    let cancelCleanup: (() => void) | undefined = undefined;

    try {
      if (options?.cancelToken) {
        cancelCleanup = options.cancelToken.onCancel((reason) => {
          try {
            this.session.cancel(rcpRequest);
            hilog.info(DOMAIN, TAG, `RCP request cancelled for: ${context.url}, reason: ${reason || 'unspecified'}`);
          } catch (e) {
            // 容错
          }
        });
      }

      // 3. 调用单例会话发起远程通信，内置证书过期与指纹失效三道防线自愈机制
      let rcpResponse: rcp.Response;
      try {
        rcpResponse = await this.session.fetch(rcpRequest);
      } catch (fetchErr) {
        // 若在通信过程中被主动取消，直接映射为强类型 CancelledError
        if (options?.cancelToken?.isCancelled) {
          throw new CancelledError(options.cancelToken.reason);
        }

        // 智能识别 SSL / 证书过期 / 指纹不匹配错误
        if (SslCertificateError.isSslOrCertError(fetchErr)) {
          const domain = this.extractDomain(context.url);
          hilog.warn(DOMAIN, TAG, '捕获到 SSL 证书/指纹校验异常，启动安全自愈防线: %{public}s', context.url);
          const recovered = await this.pinningManager.handleCertificateFailure(context.url);
          if (recovered) {
            hilog.info(DOMAIN, TAG, '自愈或退守生效，执行底层透明重试: %{public}s', context.url);
            try {
              options?.cancelToken?.throwIfCancelled();
              rcpResponse = await this.session.fetch(rcpRequest);
            } catch (retryErr) {
              if (options?.cancelToken?.isCancelled) {
                throw new CancelledError(options.cancelToken.reason);
              }
              hilog.error(DOMAIN, TAG, '透明重试依然失败，向上抛出强类型证书安全异常: %{public}s', JSON.stringify(retryErr));
              throw SslCertificateError.fromError(retryErr, domain);
            }
          } else {
            throw SslCertificateError.fromError(fetchErr, domain);
          }
        } else {
          throw fetchErr;
        }
      }

      const responseTimeMs = Date.now() - startTime;
      const rawText = rcpResponse.toString() ?? '';

      // 4. 解析响应文本为结构化数据对象
      let parsedData: Object = {};
      if (rawText.trim().startsWith('{') || rawText.trim().startsWith('[')) {
        try {
          parsedData = JSON.parse(rawText);
        } catch (e) {
          parsedData = {};
        }
      }

      // 5. 逆向流转执行后置响应拦截器
      let responseContext: ResponseContext = {
        statusCode: rcpResponse.statusCode,
        headers: rcpResponse.headers as Record<string, string>,
        data: parsedData,
        rawText: rawText,
        responseTimeMs: responseTimeMs,
        request: context
      };
      responseContext = await this.runResponseInterceptors(responseContext);

      // 6. 校验 HTTP 协议层状态码
      if (responseContext.statusCode !== 200) {
        throw new HttpStatusError(
          responseContext.statusCode,
          `HTTP Status Error: ${responseContext.statusCode}`,
          responseContext.rawText
        );
      }

      // 7. 校验后端业务响应数据契约 ApiResponse
      const apiResponse = responseContext.data as ApiResponse<T>;
      if (apiResponse && typeof apiResponse.code === 'number') {
        if (isBusinessSuccess(apiResponse.code)) {
          return apiResponse.data;
        } else {
          throw new BusinessError(
            apiResponse.code,
            apiResponse.message || CommonStrings.NET_BUSINESS_FAILED,
            apiResponse
          );
        }
      }

      // 8. 若非标准包装结构（如第三方三方接口），直接返回转换后的实体
      return responseContext.data as T;
    } catch (error) {
      // 已归类的错误（包括主动取消异常）直接向上抛出
      if (
        error instanceof CancelledError ||
        error instanceof BusinessError ||
        error instanceof HttpStatusError ||
        error instanceof NetworkError ||
        error instanceof SslCertificateError
      ) {
        throw error;
      }
      // 网络层未连通、超时、DNS 故障等未知异常统一归一化为 NetworkError
      const errMsg = (error as Error).message || CommonStrings.NET_DEFAULT_FAILURE;
      hilog.error(DOMAIN, TAG, `Network failure for [${context.method}] ${context.url}: %{public}s`, errMsg);
      throw new NetworkError(errMsg, error);
    } finally {
      if (cancelCleanup) {
        cancelCleanup();
      }
    }
  }

  // ===================== RESTful 快捷方法 =====================

  /**
   * 发起 HTTP GET 请求
   * 
   * @param url 请求路径或完整 URL
   * @param options 包含 params 查询参数、headers 与 wifiOnly 限制的配置
   * @throws {BusinessError | HttpStatusError | NetworkError | CancelledError} 网络或业务失败时抛出强类型异常
   */
  public async get<T>(url: string, options?: RequestOptions): Promise<T> {
    return this.request<T>(url, 'GET', options);
  }

  /**
   * 发起 HTTP POST 请求
   * 
   * @param url 请求路径或完整 URL
   * @param body 请求体数据载荷（自动序列化为 JSON）
   * @param options 个性化请求配置项
   * @throws {BusinessError | HttpStatusError | NetworkError | CancelledError} 网络或业务失败时抛出强类型异常
   */
  public async post<T>(url: string, body?: Object | string, options?: RequestOptions): Promise<T> {
    return this.request<T>(url, 'POST', options, body);
  }

  /**
   * 发起 HTTP PUT 更新请求
   * 
   * @param url 请求路径或完整 URL
   * @param body 待更新的数据载荷
   * @param options 个性化请求配置项
   * @throws {BusinessError | HttpStatusError | NetworkError | CancelledError} 网络或业务失败时抛出强类型异常
   */
  public async put<T>(url: string, body?: Object | string, options?: RequestOptions): Promise<T> {
    return this.request<T>(url, 'PUT', options, body);
  }

  /**
   * 发起 HTTP DELETE 删除请求
   * 
   * @param url 请求路径或完整 URL
   * @param options 个性化请求配置项
   * @throws {BusinessError | HttpStatusError | NetworkError | CancelledError} 网络或业务失败时抛出强类型异常
   */
  public async delete<T>(url: string, options?: RequestOptions): Promise<T> {
    return this.request<T>(url, 'DELETE', options);
  }

  /**
   * 发起 HTTP PATCH 局部更新请求
   * 
   * @param url 请求路径或完整 URL
   * @param body 待局部更新的字段载荷
   * @param options 个性化请求配置项
   * @throws {BusinessError | HttpStatusError | NetworkError | CancelledError} 网络或业务失败时抛出强类型异常
   */
  public async patch<T>(url: string, body?: Object | string, options?: RequestOptions): Promise<T> {
    return this.request<T>(url, 'PATCH', options, body);
  }
}

/**
 * 快捷导出全局默认 HttpClient 单例实例
 */
export const httpClient = HttpClient.getInstance();
