import { RequestContext, ResponseContext } from '../model/HttpOptions';

/**
 * HTTP 责任链拦截器统一抽象契约接口 (HttpInterceptor)
 * 借鉴 OkHttp Interceptor 设计理念，支持在请求发起前注入 Header/签名，以及在响应到达后统一拦截分析
 */
export interface HttpInterceptor {
  /**
   * 前置请求拦截钩子
   * 在请求正式提交给底层 RCP 会话前触发，支持异步 Promise
   * 
   * @param context 当前流转的请求上下文
   * @returns 经过拦截器增强、篡改或校验后的请求上下文
   */
  onRequest?(context: RequestContext): Promise<RequestContext> | RequestContext;

  /**
   * 后置响应拦截钩子
   * 在底层会话收到网络响应后逆序触发，支持异步 Promise
   * 
   * @param response 当前流转的响应上下文
   * @returns 经过后置拦截器过滤或分析后的响应上下文
   */
  onResponse?(response: ResponseContext): Promise<ResponseContext> | ResponseContext;
}
