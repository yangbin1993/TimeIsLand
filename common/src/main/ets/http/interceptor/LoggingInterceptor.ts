import { HttpInterceptor } from './Interceptor';
import { RequestContext, ResponseContext } from '../model/HttpOptions';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'HttpLogging';
const DOMAIN = 0x0000;

/**
 * 生产级全链路网络日志美化拦截器 (LoggingInterceptor)
 * 基于系统级 HiLog 提供完整的请求与响应报文追踪
 * 
 * 核心特性：
 * 1. 请求阶段：清晰打印请求 Method、请求 URL、Headers 键值及 Request Body
 * 2. 响应阶段：打印 HTTP 状态码、请求全耗时（ms）以及格式化后的 Response Body 内容
 * 3. 超长截断防护：自动限制单条日志长度，防止超大 JSON 数据撑爆 HiLog 缓冲区
 * 4. 支持运行期随时动态启用/禁用（方便在 Release 发布构建中规避隐私泄露）
 */
export class LoggingInterceptor implements HttpInterceptor {
  private enabled: boolean = true;

  /**
   * @param enabled 是否默认开启日志输出，默认为 true
   */
  constructor(enabled: boolean = true) {
    this.enabled = enabled;
  }

  /**
   * 动态设置是否开启日志打印
   */
  public setEnabled(enabled: boolean): void {
    this.enabled = enabled;
  }

  public onRequest(context: RequestContext): RequestContext {
    if (!this.enabled) {
      return context;
    }

    const headersStr = JSON.stringify(context.headers);
    let bodyStr = '';
    if (context.body) {
      bodyStr = typeof context.body === 'string' ? context.body : JSON.stringify(context.body);
    }

    hilog.info(DOMAIN, TAG, `--> [${context.method}] ${context.url}`);
    hilog.info(DOMAIN, TAG, `    Headers: %{public}s`, headersStr);
    if (bodyStr) {
      hilog.info(DOMAIN, TAG, `    Body: %{public}s`, bodyStr);
    }

    return context;
  }

  public onResponse(response: ResponseContext): ResponseContext {
    if (!this.enabled) {
      return response;
    }

    hilog.info(
      DOMAIN,
      TAG,
      `<-- [${response.statusCode}] ${response.request.url} (duration: ${response.responseTimeMs}ms)`
    );

    if (response.rawText) {
      // 防止超大文本日志打爆缓冲区，超过 1000 字符自动截断展示
      const displayLog = response.rawText.length > 1000 
        ? `${response.rawText.substring(0, 1000)}... (truncated, total ${response.rawText.length} bytes)` 
        : response.rawText;
      hilog.info(DOMAIN, TAG, `    Response: %{public}s`, displayLog);
    }

    return response;
  }
}
