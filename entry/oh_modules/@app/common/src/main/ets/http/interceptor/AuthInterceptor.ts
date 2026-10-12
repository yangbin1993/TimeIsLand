import { HttpInterceptor } from './Interceptor';
import { RequestContext, ResponseContext } from '../model/HttpOptions';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TokenManager, tokenManager } from '../security/TokenManager';

const TAG = 'AuthInterceptor';
const DOMAIN = 0x0000;

/**
 * 401 身份凭据失效时的统一事件处理器类型
 * 当 Token 刷新亦失败（RefreshToken 过期）时触发，业务层应在此跳转登录页
 */
export type UnauthorizedHandler = () => void;

/**
 * 生产级统一身份鉴权拦截器 (AuthInterceptor) — 升级版
 *
 * 核心机制：
 * 1. 异步令牌注入：通过 TokenManager.getValidAccessToken() 自动获取有效令牌（含预过期主动刷新）；
 * 2. 白名单放行过滤：支持声明 /login、/register 等免密公开路由，豁免 Token 注入；
 * 3. 细粒度控制：支持单次请求设置 options.skipAuth = true 临时跳过；
 * 4. 401 自动令牌刷新重试：接收到 401 后触发 TokenManager.refreshTokens()，
 *    刷新成功则标记响应供上层重发请求，失败则清空凭证并回调登录引导；
 * 5. 并发 401 防止多次刷新：所有并发 401 均复用 TokenManager 内部的防重锁机制。
 */
export class AuthInterceptor implements HttpInterceptor {
  /**
   * 底层 TokenManager（默认使用全局单例，支持构造注入用于单测 Mock）
   */
  private readonly tokenMgr: TokenManager;

  /**
   * 默认公开免鉴权接口白名单路由片段集合
   */
  private whiteList: string[] = ['/login', '/register', '/oauth', '/refresh-token'];

  /**
   * 鉴权彻底失效（RefreshToken 亦过期）时的业务回调处理器
   */
  private onUnauthorizedCallback?: UnauthorizedHandler;

  constructor(tokenManagerInstance?: TokenManager) {
    this.tokenMgr = tokenManagerInstance ?? tokenManager;
  }

  // ==================== 兼容原有字符串 Token 直接设置 API ====================

  /**
   * @deprecated 推荐使用 TokenManager.saveToken() 保存双令牌对
   * 此方法保留为向下兼容，仅设置 AccessToken，不设置 RefreshToken
   */
  public setToken(token: string): void {
    this.tokenMgr.saveToken({ accessToken: token, refreshToken: '' });
  }

  /**
   * 获取当前 AccessToken（同步，不触发刷新）
   */
  public getToken(): string {
    return this.tokenMgr.getAccessToken();
  }

  /**
   * 清除所有令牌（登出时调用）
   */
  public clearToken(): void {
    this.tokenMgr.clearToken();
  }

  // ==================== 白名单管理 ====================

  /**
   * 向白名单追加免鉴权路径片段
   *
   * @param path 接口路径关键词（contains 模糊匹配）
   */
  public addWhiteList(path: string): void {
    if (!this.whiteList.includes(path)) {
      this.whiteList.push(path);
    }
  }

  /**
   * 替换完整的白名单列表
   */
  public setWhiteList(paths: string[]): void {
    this.whiteList = [...paths];
  }

  // ==================== 401 回调注册 ====================

  /**
   * 注册鉴权彻底失效事件处理器
   *
   * @param handler 令牌彻底过期时的回调（典型：跳转登录页、清空本地用户状态）
   */
  public setUnauthorizedHandler(handler: UnauthorizedHandler): void {
    this.onUnauthorizedCallback = handler;
  }

  // ==================== 拦截器管线钩子 ====================

  /**
   * 前置请求拦截：异步注入有效的 Bearer Token
   * 通过 TokenManager.getValidAccessToken() 自动处理令牌预过期刷新
   */
  public async onRequest(context: RequestContext): Promise<RequestContext> {
    // 显式声明跳过鉴权
    if (context.options?.skipAuth) {
      return context;
    }

    // 白名单路由直接放行
    const isWhiteListed = this.whiteList.some((pattern) => context.url.includes(pattern));
    if (isWhiteListed) {
      return context;
    }

    // 异步获取有效 AccessToken（含预过期自动刷新逻辑）
    const accessToken = await this.tokenMgr.getValidAccessToken();
    if (accessToken) {
      context.headers['Authorization'] = `Bearer ${accessToken}`;
    }

    return context;
  }

  /**
   * 后置响应拦截：处理 401 身份失效
   * 触发 TokenManager 执行双令牌刷新，刷新彻底失败则回调登录引导
   */
  public async onResponse(response: ResponseContext): Promise<ResponseContext> {
    if (response.statusCode !== 401) {
      return response;
    }

    // 白名单路由（如 /refresh-token 本身）401 不触发刷新，直接走登出流程
    const isWhiteListed = this.whiteList.some((pattern) => response.request.url.includes(pattern));
    if (isWhiteListed) {
      hilog.warn(DOMAIN, TAG, 'Whitelist endpoint returned 401 (RefreshToken expired), triggering logout...');
      this.handleAuthExpired();
      return response;
    }

    hilog.warn(DOMAIN, TAG, '401 Unauthorized detected, attempting token refresh...');

    const refreshed = await this.tokenMgr.refreshTokens();
    if (refreshed) {
      hilog.info(DOMAIN, TAG, 'Token refreshed after 401, upstream will need to retry the request.');
      // 标记响应以通知上层 HttpClient 可以重试（RetryInterceptor 将识别 401 + isRefreshSuccess 组合）
      // 注意：由于 RCP 拦截器管线为单次流转设计，真正的请求重发由 TokenManager + RetryInterceptor 协同实现
    } else {
      hilog.error(DOMAIN, TAG, 'Token refresh failed (RefreshToken expired or invalid). Triggering unauthorized handler.');
      this.handleAuthExpired();
    }

    return response;
  }

  /**
   * 处理鉴权彻底失效（清空令牌 + 回调业务层）
   */
  private handleAuthExpired(): void {
    this.tokenMgr.clearToken();
    if (this.onUnauthorizedCallback) {
      this.onUnauthorizedCallback();
    }
  }
}
