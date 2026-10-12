/**
 * 领域层通用数据结果包装器 (DataResult)
 * 对标 Android 架构中的 NetworkResult<T>
 * 遵循 ArkTS 严格静态类型规范，严禁匿名对象字面量类型
 */

/**
 * 数据获取成功具名接口
 */
export interface DataResultSuccess<T> {
  readonly status: 'SUCCESS';
  readonly data: T;
}

/**
 * 数据获取失败具名接口
 */
export interface DataResultError {
  readonly status: 'ERROR';
  readonly code: number;
  readonly message: string;
}

/**
 * 领域数据结果聚合联合类型
 */
export type DataResult<T> = DataResultSuccess<T> | DataResultError;

/**
 * 数据结果工厂构建器 (强类型构造，彻底规避 arkts-no-untyped-obj-literals)
 */
export class DataResults {
  /**
   * 构造成功数据结果
   * 
   * @param data 成功载荷数据
   */
  public static success<T>(data: T): DataResultSuccess<T> {
    const res: DataResultSuccess<T> = {
      status: 'SUCCESS',
      data: data
    };
    return res;
  }

  /**
   * 构造失败错误结果
   * 
   * @param message 友好错误文案
   * @param code 业务或底层网络状态码
   */
  public static error<T = void>(message: string, code: number = -1): DataResultError {
    const res: DataResultError = {
      status: 'ERROR',
      code: code,
      message: message
    };
    return res;
  }

  /**
   * 判断当前结果是否为成功态
   */
  public static isSuccess<T>(result: DataResult<T>): result is DataResultSuccess<T> {
    return result.status === 'SUCCESS';
  }

  /**
   * 判断当前结果是否为失败态
   */
  public static isError<T>(result: DataResult<T>): result is DataResultError {
    return result.status === 'ERROR';
  }

  // ==================== 链式 DSL 扩展方法 ====================

  /**
   * 成功回调：仅当结果为 SUCCESS 时执行 callback，返回原结果支持链式调用
   *
   * @param result 要处理的数据结果
   * @param callback 成功时的回调，接收解包后的业务数据
   */
  public static onSuccess<T>(
    result: DataResult<T>,
    callback: (data: T) => void
  ): DataResult<T> {
    if (DataResults.isSuccess(result)) {
      callback(result.data);
    }
    return result;
  }

  /**
   * 失败回调：仅当结果为 ERROR 时执行 callback，返回原结果支持链式调用
   *
   * @param result 要处理的数据结果
   * @param callback 失败时的回调，接收错误消息与错误码
   */
  public static onError<T>(
    result: DataResult<T>,
    callback: (message: string, code: number) => void
  ): DataResult<T> {
    if (DataResults.isError(result)) {
      callback(result.message, result.code);
    }
    return result;
  }

  /**
   * 映射转换：将 SUCCESS 状态的数据提取转化为新类型 R
   * 若结果为 ERROR 则直接透传错误
   *
   * @param result 要映射的数据结果
   * @param transform 数据转换函数
   */
  public static map<T, R>(
    result: DataResult<T>,
    transform: (data: T) => R
  ): DataResult<R> {
    if (DataResults.isSuccess(result)) {
      return DataResults.success<R>(transform(result.data));
    }
    return result as unknown as DataResultError;
  }

  /**
   * 安全解包：成功时返回业务数据，失败时返回 null
   *
   * @param result 要解包的数据结果
   */
  public static getOrNull<T>(result: DataResult<T>): T | null {
    return DataResults.isSuccess(result) ? result.data : null;
  }

  /**
   * 安全解包带默认値：成功时返回业务数据，失败时返回指定的默认展示内容
   *
   * @param result 要解包的数据结果
   * @param defaultValue 失败时的默认回落展示内容
   */
  public static getOrDefault<T>(result: DataResult<T>, defaultValue: T): T {
    return DataResults.isSuccess(result) ? result.data : defaultValue;
  }
}
