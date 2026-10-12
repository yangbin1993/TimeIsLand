/**
 * 统一后端业务数据契约响应体 (ApiResponse)
 * 规范服务端返回的标准 JSON 外壳模型
 * 
 * @template T 实际业务领域实体的泛型类型
 */
export interface ApiResponse<T> {
  /**
   * 业务状态码：通常 0 或 200 代表业务执行成功，非 0/200 代表特定业务错误
   */
  code: number;

  /**
   * 服务端下发的操作结果提示或异常描述文案
   */
  message: string;

  /**
   * 实际业务数据载荷，由框架自动进行强类型反序列化
   */
  data: T;

  /**
   * 服务端生成响应时的毫秒时间戳（可选）
   */
  timestamp?: number;
}

/**
 * 判断后端返回的业务状态码是否代表成功
 * 
 * @param code 服务端返回的业务 code
 * @returns 是否成功
 */
export function isBusinessSuccess(code: number): boolean {
  return code === 0 || code === 200;
}
