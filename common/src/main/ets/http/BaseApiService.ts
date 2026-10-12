import { HttpClient, httpClient } from './HttpClient';
import { RequestOptions } from './model/HttpOptions';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'BaseApiService';
const DOMAIN: number = 0x0000;

/**
 * 生产级通用网络请求服务抽象基类 (BaseApiService)
 * 对标 Android Retrofit 体系中的网络接口契约基类与请求调度底座
 * 
 * 核心设计职责：
 * 1. 屏蔽底层通信栈细节：内部持有 HttpClient 实例，向上暴露纯净的 HTTP 请求动词；
 * 2. 强类型参数与返回模型契约：所有请求方法均支持泛型声明，杜绝隐式 any；
 * 3. 统一请求拦截与配置透传：统一接管 Query 参数、Header 附加及超时配置；
 * 4. 依赖注入友好：支持构造函数无参默认单例注入，亦支持单测 Mock 客户端传入。
 */
export abstract class BaseApiService {
  /**
   * 底层 HTTP 通信核心客户端
   */
  protected client: HttpClient;

  /**
   * 构造函数：支持外部注入特定配置的 HttpClient，默认采用全局单例
   * 
   * @param customClient 可选的自定义网络客户端实例
   */
  constructor(customClient?: HttpClient) {
    this.client = customClient ?? httpClient;
    hilog.info(DOMAIN, TAG, `${this.constructor.name} service initialized`);
  }

  /**
   * 发起 HTTP GET 业务请求
   * 
   * @param url 请求接口相对路径或完整 URL
   * @param queryParams 可选的 URL 查询参数键值对
   * @param options 可选的高级网络配置 (如超时时间、重试策略、wifiOnly 等)
   * @returns 泛型解析后的响应数据 Promise<T>
   */
  protected async get<T>(
    url: string,
    queryParams?: Record<string, string | number | boolean>,
    options?: RequestOptions
  ): Promise<T> {
    const opts: RequestOptions = options ?? {};
    if (queryParams) {
      opts.params = queryParams;
    }
    return this.client.get<T>(url, opts);
  }

  /**
   * 发起 HTTP POST 业务请求
   * 
   * @param url 请求接口相对路径或完整 URL
   * @param body 可选的请求体对象 (将自动序列化为 JSON)
   * @param options 可选的高级网络配置
   * @returns 泛型解析后的响应数据 Promise<T>
   */
  protected async post<T>(
    url: string,
    body?: Object,
    options?: RequestOptions
  ): Promise<T> {
    return this.client.post<T>(url, body, options);
  }

  /**
   * 发起 HTTP PUT 业务请求
   * 
   * @param url 请求接口相对路径或完整 URL
   * @param body 可选的请求体对象
   * @param options 可选的高级网络配置
   * @returns 泛型解析后的响应数据 Promise<T>
   */
  protected async put<T>(
    url: string,
    body?: Object,
    options?: RequestOptions
  ): Promise<T> {
    return this.client.put<T>(url, body, options);
  }

  /**
   * 发起 HTTP DELETE 业务请求
   * 
   * @param url 请求接口相对路径或完整 URL
   * @param queryParams 可选的 URL 查询参数
   * @param options 可选的高级网络配置
   * @returns 泛型解析后的响应数据 Promise<T>
   */
  protected async delete<T>(
    url: string,
    queryParams?: Record<string, string | number | boolean>,
    options?: RequestOptions
  ): Promise<T> {
    const opts: RequestOptions = options ?? {};
    if (queryParams) {
      opts.params = queryParams;
    }
    return this.client.delete<T>(url, opts);
  }

  /**
   * 发起 HTTP PATCH 局部字段更新请求
   *
   * @param url 请求接口相对路径或完整 URL
   * @param body 待局部更新的字段载荷（仅需包含变更字段，服务端按需合并）
   * @param options 可选的高级网络配置
   * @returns 泛型解析后的响应数据 Promise<T>
   */
  protected async patch<T>(
    url: string,
    body?: Object,
    options?: RequestOptions
  ): Promise<T> {
    return this.client.patch<T>(url, body, options);
  }
}
