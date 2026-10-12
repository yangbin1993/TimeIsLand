import { CancelToken } from './CancelToken';

/**
 * 支持的 HTTP 基础请求动词类型
 */
export type HttpMethod = 'GET' | 'POST' | 'PUT' | 'DELETE' | 'PATCH';

/**
 * 单次 HTTP 请求的细粒度配置项
 */
export interface RequestOptions {
  /**
   * URL 查询参数键值对（由框架自动进行键值 encodeURIComponent 转义拼接）
   */
  params?: Record<string, string | number | boolean>;

  /**
   * 单次请求专属自定义请求头（将与全局请求头智能合并，同名优先覆盖）
   */
  headers?: Record<string, string>;

  /**
   * 建立 TCP/TLS 连接超时时间（单位：毫秒）
   */
  connectTimeoutMs?: number;

  /**
   * 数据传输与读取超时时间（单位：毫秒）
   */
  transferTimeoutMs?: number;

  /**
   * 是否跳过全局 Bearer Token 的自动注入（如公开注册/登录或三方免密接口）
   */
  skipAuth?: boolean;

  /**
   * 是否限制仅在 WiFi 网络环境下发起（蜂窝移动网络下触发流量保护拦截）
   */
  wifiOnly?: boolean;

  /**
   * 请求取消令牌 (若传入，当调用 token.cancel() 时将主动中止此请求并抛出 CancelledError)
   */
  cancelToken?: CancelToken;

  /**
   * 是否启用并发请求去重 (针对相同 URL 与查询参数的并发在途请求，共享同一个 Promise 结果，防止重复刷接口)
   * 默认为 false；可在高频刷新场景或幂等查询中显式开启
   */
  deduplicate?: boolean;
}

/**
 * 责任链拦截器管线中流转的前置请求上下文 (RequestContext)
 */
export interface RequestContext {
  url: string;
  method: HttpMethod;
  headers: Record<string, string>;
  params?: Record<string, string | number | boolean>;
  body?: Object | string;
  options?: RequestOptions;
}

/**
 * 责任链拦截器管线中流转的后置响应上下文 (ResponseContext)
 */
export interface ResponseContext {
  statusCode: number;
  headers: Record<string, string>;
  data: Object;
  rawText: string;
  responseTimeMs: number;
  request: RequestContext;
}
