/**
 * 应用网络请求异常抽象基类 (AppHttpError)
 * 所有网络相关错误（底层网络故障、HTTP状态异常、业务返回码异常）的共同父类
 */
export abstract class AppHttpError extends Error {
  /**
   * 错误归类码
   */
  public readonly code: number;

  /**
   * 原始底层响应或错误上下文对象
   */
  public readonly raw?: Object;

  constructor(code: number, message: string, raw?: Object) {
    super(message);
    this.name = 'AppHttpError';
    this.code = code;
    this.raw = raw;
  }
}

/**
 * 底层网络与传输层异常 (NetworkError)
 * 产生场景：设备断网无连接、DNS 解析失败、TCP 建立握手超时、SSL 证书不受信等
 */
export class NetworkError extends AppHttpError {
  constructor(message: string, raw?: Object) {
    super(-1, message, raw);
    this.name = 'NetworkError';
  }
}

/**
 * HTTP 协议层状态码错误 (HttpStatusError)
 * 产生场景：服务端返回非 200 HTTP 响应码（例如 400 Bad Request, 401 Unauthorized, 404 Not Found, 500 Internal Server Error）
 */
export class HttpStatusError extends AppHttpError {
  /**
   * HTTP 响应状态码数值
   */
  public readonly httpStatus: number;

  constructor(httpStatus: number, message: string, raw?: Object) {
    super(httpStatus, message, raw);
    this.name = 'HttpStatusError';
    this.httpStatus = httpStatus;
  }
}

/**
 * 业务逻辑异常 (BusinessError)
 * 产生场景：HTTP 通信成功且状态码为 200，但后端返回的业务数据中 code !== 0 && code !== 200（例如 10001 密码错误、10002 余额不足）
 */
export class BusinessError extends AppHttpError {
  /**
   * 后端定义的业务错误码
   */
  public readonly businessCode: number;

  constructor(businessCode: number, message: string, raw?: Object) {
    super(businessCode, message, raw);
    this.name = 'BusinessError';
    this.businessCode = businessCode;
  }
}
