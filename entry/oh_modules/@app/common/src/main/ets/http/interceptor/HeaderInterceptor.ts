import { HttpInterceptor } from './Interceptor';
import { RequestContext } from '../model/HttpOptions';

/**
 * 生产级通用请求头拦截器 (HeaderInterceptor)
 * 
 * 核心机制：
 * 1. 自动注入 JSON 序列化标头 Content-Type 与 Accept
 * 2. 注入平台上下文标识 X-Platform: HarmonyOS 与当前客户端版本号 X-App-Version
 * 3. 每次请求自动生成唯一的全链路跟踪标记 X-Trace-Id，便于服务端日志追踪与排障
 * 4. 智能合并机制：保留业务请求在 options.headers 中显式配置的同名字段
 */
export class HeaderInterceptor implements HttpInterceptor {
  private appVersion: string;

  /**
   * @param appVersion 客户端当前发布版本号，默认 1.0.0
   */
  constructor(appVersion: string = '1.0.0') {
    this.appVersion = appVersion;
  }

  public onRequest(context: RequestContext): RequestContext {
    // 动态生成基于时间戳与随机数的唯一追踪 TraceId
    const traceId = `req_${Date.now()}_${Math.floor(Math.random() * 1000000)}`;

    const defaultHeaders: Record<string, string> = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'X-Platform': 'HarmonyOS',
      'X-App-Version': this.appVersion,
      'X-Trace-Id': traceId
    };

    // 智能合并请求头，保留业务主动声明的自定义覆盖项
    context.headers = {
      ...defaultHeaders,
      ...context.headers
    };

    return context;
  }
}
