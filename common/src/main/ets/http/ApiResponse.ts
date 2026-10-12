/**
 * 通用业务响应体契约接口
 */
export interface ApiResponse<T> {
  code: number;
  message: string;
  data: T;
}

/**
 * 自定义统一 HTTP/业务异常类
 */
export class HttpError extends Error {
  public readonly code: number;
  public readonly raw?: Object;

  constructor(code: number, message: string, raw?: Object) {
    super(message);
    this.name = 'HttpError';
    this.code = code;
    this.raw = raw;
  }
}

/**
 * 业务成功状态码校验判断
 * 默认为 0 或 200
 */
export function isApiSuccess(code: number): boolean {
  return code === 0 || code === 200;
}
