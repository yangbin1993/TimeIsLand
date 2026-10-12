import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError, HttpStatusError, NetworkError } from '../http/model/HttpErrors';
import { CancelledError } from '../http/model/CancelToken';
import { SslCertificateError } from '../http/model/SslCertificateError';
import { DataResult, DataResults } from './DataResult';
import { CommonStrings } from '../constants/CommonStrings';

const TAG: string = 'BaseRepository';
const DOMAIN: number = 0x0000;

/**
 * 鸿蒙生产级通用数据仓库基类 (BaseRepository)
 * 对标 Android Clean Architecture 中的 BaseRepositoryImpl
 * 
 * 核心架构特性：
 * 1. 单一可信数据源 (SSOT)：
 *    向下屏蔽 Remote(网络) 与 Local(首选项/数据库) 数据细节，向上为 ViewModel 输出干净的领域模型。
 * 2. 经典获取策略模板：
 *    内置 safeApiCall (安全网络调用)、networkFirst (网络优先/离线降级)、cacheFirst (缓存秒开/异步落盘)。
 * 3. 三级异常自动归约与折叠：
 *    自动捕获 NetworkError、HttpStatusError 与 BusinessError，输出安全的 DataResult，杜绝上层样板代码。
 */
export abstract class BaseRepository {
  private memoryCacheMap: Map<string, Object> = new Map();

  constructor() {
    hilog.info(DOMAIN, TAG, `${this.constructor.name} initialized`);
  }

  /**
   * 写入 L1 内存级短期缓存
   */
  protected setMemoryCache<T>(key: string, data: T): void {
    this.memoryCacheMap.set(key, data as Object);
  }

  /**
   * 读取 L1 内存级短期缓存
   */
  protected getMemoryCache<T>(key: string): T | null {
    if (this.memoryCacheMap.has(key)) {
      return this.memoryCacheMap.get(key) as T;
    }
    return null;
  }

  /**
   * 清空所有 L1 内存缓存
   */
  protected clearMemoryCache(): void {
    this.memoryCacheMap.clear();
  }

  /**
   * 安全网络接口调用模板 (Safe API Call)
   * 配合 HttpClient 自动完成业务状态码与分级异常拦截，解包为标准 DataResult
   * 
   * @param requestAction 异步网络请求闭包 (如调用 httpClient.get/post)
   * @returns 强类型统一结果 DataResult<T>
   */
  protected async safeApiCall<T>(
    requestAction: () => Promise<T>
  ): Promise<DataResult<T>> {
    try {
      const data: T = await requestAction();
      return DataResults.success<T>(data);
    } catch (error) {
      return this.handleException<T>(error as Object);
    }
  }

  /**
   * 网络优先数据获取策略模板 (Network First Strategy)
   * 对标 Android 中的 networkFirstStrategy：
   * 1. 优先拉取远端服务端数据；
   * 2. 成功后触发本地异步落盘，并返回最新数据；
   * 3. 若网络或远端服务异常，平滑降级查询本地离线缓存返回；
   * 4. 若本地亦无缓存，向上抛出统一的格式化错误。
   * 
   * @param remoteFetch 远端接口请求闭包
   * @param localFetch 本地持久化查询闭包 (未命中返回 null)
   * @param saveLocal 本地落盘更新闭包
   */
  protected async networkFirst<T>(
    remoteFetch: () => Promise<T>,
    localFetch: () => Promise<T | null>,
    saveLocal: (data: T) => Promise<void>
  ): Promise<DataResult<T>> {
    try {
      // 1. 发起远程网络拉取
      const remoteData: T = await remoteFetch();

      // 2. 异步写入本地持久化
      try {
        await saveLocal(remoteData);
      } catch (saveErr) {
        hilog.warn(DOMAIN, TAG, `Failed to persist remote data locally: %{public}s`, JSON.stringify(saveErr));
      }
      return DataResults.success<T>(remoteData);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Remote fetch failed, attempting local cache fallback: %{public}s`, JSON.stringify(err));

      // 3. 降级尝试从本地读取缓存
      try {
        const localData: T | null = await localFetch();
        if (localData !== null) {
          hilog.info(DOMAIN, TAG, 'Local cache fallback successful');
          return DataResults.success<T>(localData);
        }
      } catch (localErr) {
        hilog.error(DOMAIN, TAG, `Failed to read local fallback cache: %{public}s`, JSON.stringify(localErr));
      }

      // 4. 本地无缓存，返回规范异常
      return this.handleException<T>(err as Object);
    }
  }

  /**
   * 缓存优先数据获取策略模板 (Cache First Strategy)
   * 1. 优先查询本地持久化存储，命中则直接秒开返回；
   * 2. 若本地无缓存，发起网络请求并异步写入本地。
   * 
   * @param localFetch 本地持久化查询闭包
   * @param remoteFetch 远端接口请求闭包
   * @param saveLocal 本地落盘更新闭包
   */
  protected async cacheFirst<T>(
    localFetch: () => Promise<T | null>,
    remoteFetch: () => Promise<T>,
    saveLocal: (data: T) => Promise<void>
  ): Promise<DataResult<T>> {
    // 1. 优先查询本地持久化
    try {
      const localData: T | null = await localFetch();
      if (localData !== null) {
        hilog.info(DOMAIN, TAG, 'Cache hit directly from local source');
        return DataResults.success<T>(localData);
      }
    } catch (localErr) {
      hilog.warn(DOMAIN, TAG, `Local cache read warning: %{public}s`, JSON.stringify(localErr));
    }

    // 2. 本地未命中，走安全网络调用并落盘
    return this.safeApiCall<T>(async (): Promise<T> => {
      const remoteData: T = await remoteFetch();
      try {
        await saveLocal(remoteData);
      } catch (saveErr) {
        hilog.warn(DOMAIN, TAG, `Failed to cache remote data: %{public}s`, JSON.stringify(saveErr));
      }
      return remoteData;
    });
  }

  /**
   * 统一分级异常格式化与映射中心
   * 将 NetworkError、HttpStatusError、BusinessError 转为领域友好的错误模型
   * 
   * @param error 捕获到的异常实例
   */
  protected handleException<T>(error: Object): DataResult<T> {
    if (error instanceof CancelledError) {
      hilog.info(DOMAIN, TAG, `Request cancelled in repository: ${error.reason}`);
      return DataResults.error<T>(error.reason || 'Request cancelled', -1002);
    } else if (error instanceof SslCertificateError) {
      hilog.error(DOMAIN, TAG, `SSL certificate error caught: [${error.sslErrorCode}] ${error.message}`);
      const tip = error.isExpired
        ? CommonStrings.SSL_EXPIRED_TIP
        : CommonStrings.SSL_MISMATCH_TIP;
      return DataResults.error<T>(tip, error.sslErrorCode);
    } else if (error instanceof NetworkError) {
      hilog.error(DOMAIN, TAG, `Network error caught: ${error.message}`);
      return DataResults.error<T>(CommonStrings.REPO_NET_ERROR, -1001);
    } else if (error instanceof HttpStatusError) {
      hilog.error(DOMAIN, TAG, `HTTP error caught: [${error.httpStatus}] ${error.message}`);
      return DataResults.error<T>(`${CommonStrings.REPO_HTTP_ERROR_PREFIX} (${error.httpStatus})`, error.httpStatus);
    } else if (error instanceof BusinessError) {
      hilog.warn(DOMAIN, TAG, `Business error caught: [${error.businessCode}] ${error.message}`);
      return DataResults.error<T>(error.message, error.businessCode);
    } else {
      const defaultErr: Error = error as Error;
      const msg: string = defaultErr.message || CommonStrings.REPO_UNKNOWN_ERROR;
      hilog.error(DOMAIN, TAG, `Unhandled exception caught: ${msg}`);
      return DataResults.error<T>(msg, -9999);
    }
  }
}
