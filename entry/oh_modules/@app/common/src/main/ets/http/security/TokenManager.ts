import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'TokenManager';
const DOMAIN = 0x0000;

/**
 * Token 刷新回调函数类型
 * 业务层实现此接口，执行实际的 Refresh Token 网络请求并返回新令牌对
 */
export type TokenRefreshAction = () => Promise<TokenPair>;

/**
 * Access + Refresh Token 双令牌数据模型
 */
export interface TokenPair {
  /**
   * 短效访问凭证（通常 2小时~24小时过期）
   */
  accessToken: string;

  /**
   * 长效刷新凭证（通常 7天~30天过期，仅用于换取新 AccessToken）
   */
  refreshToken: string;

  /**
   * AccessToken 过期时间戳（Unix ms），若服务端未返回则由框架基于 expiresIn 推算
   */
  expiresAt?: number;

  /**
   * AccessToken 有效期秒数（服务端下发字段，框架将自动推算 expiresAt）
   */
  expiresIn?: number;
}

/**
 * Token 状态变更事件监听器
 */
export type TokenChangeListener = (pair: TokenPair | null) => void;

/**
 * 生产级双令牌生命周期管理器 (TokenManager)
 *
 * 核心架构特性：
 * 1. 双令牌机制 (Access + Refresh)：
 *    AccessToken 短效（如2h），用于接口鉴权；RefreshToken 长效（如30d），
 *    仅在 AccessToken 临期或过期时通过专用接口换新，保障用户无感续期。
 *
 * 2. 刷新请求防并发去重（并发加锁）：
 *    当多个接口同时触发 401 时，框架仅执行一次 Token 刷新，
 *    其余并发请求等待同一个 Promise 复用结果，杜绝竞态刷新与 RefreshToken 单次消费。
 *
 * 3. 预过期主动刷新（提前缓冲时间窗口）：
 *    默认在 AccessToken 过期前 5 分钟触发主动换新，
 *    规避精确过期边界附近的 401 概率波动。
 *
 * 4. 失效彻底清零（安全退出协议）：
 *    连续刷新失败（RefreshToken 亦过期）时，自动清空所有令牌并通知业务层跳转登录页。
 *
 * 5. 依赖倒置友好：
 *    通过 setRefreshAction() 注入具体的令牌刷新网络调用，框架对业务实现透明。
 */
export class TokenManager {
  private static instance: TokenManager;

  /**
   * 当前有效的令牌对
   */
  private tokenPair: TokenPair | null = null;

  /**
   * 提前刷新时间缓冲窗口（ms），默认 5 分钟
   */
  private readonly refreshBufferMs: number;

  /**
   * 业务层注入的 Token 刷新动作
   */
  private refreshAction?: TokenRefreshAction;

  /**
   * 并发刷新防重复锁：当前正在进行中的刷新 Promise
   */
  private pendingRefreshPromise: Promise<boolean> | null = null;

  /**
   * Token 变更监听器集合
   */
  private changeListeners: Set<TokenChangeListener> = new Set();

  private constructor(refreshBufferMs?: number) {
    this.refreshBufferMs = refreshBufferMs ?? 5 * 60 * 1000;
  }

  /**
   * 获取 TokenManager 全局单例实例
   */
  public static getInstance(): TokenManager {
    if (!TokenManager.instance) {
      TokenManager.instance = new TokenManager();
    }
    return TokenManager.instance;
  }

  /**
   * 注入业务层的 Token 刷新动作（推荐在 AppAbility.onCreate 中通过 FrameworkFacade 统一注册）
   *
   * @param action 异步刷新函数，需向服务端发起 refreshToken 请求并返回新令牌对
   */
  public setRefreshAction(action: TokenRefreshAction): void {
    this.refreshAction = action;
    hilog.info(DOMAIN, TAG, 'TokenRefreshAction registered.');
  }

  /**
   * 保存从服务端登录响应中解析出的初始令牌对
   * 若服务端返回 expiresIn 字段，自动推算本地 expiresAt 时间戳
   *
   * @param pair 服务端返回的双令牌数据
   */
  public saveToken(pair: TokenPair): void {
    const enrichedPair: TokenPair = { ...pair };
    if (!enrichedPair.expiresAt && enrichedPair.expiresIn && enrichedPair.expiresIn > 0) {
      enrichedPair.expiresAt = Date.now() + enrichedPair.expiresIn * 1000;
    }
    this.tokenPair = enrichedPair;
    this.notifyListeners(this.tokenPair);
    hilog.info(
      DOMAIN, TAG,
      `Token saved. AccessToken expires at: ${this.tokenPair.expiresAt ?? 'unknown'}`
    );
  }

  /**
   * 获取当前有效的 AccessToken（若已临近过期则立即触发刷新）
   * 这是 AuthInterceptor 调用令牌的统一入口，确保拿到的 Token 始终有效
   *
   * @returns 当前有效的 AccessToken，若无令牌或刷新失败则返回空字符串
   */
  public async getValidAccessToken(): Promise<string> {
    if (!this.tokenPair) {
      return '';
    }

    // AccessToken 尚在有效期且未进入预刷新缓冲窗口
    if (!this.isAccessTokenExpiringSoon()) {
      return this.tokenPair.accessToken;
    }

    // 进入预刷新或已过期：触发无感刷新
    hilog.info(DOMAIN, TAG, 'AccessToken is expiring or expired, triggering proactive refresh...');
    const refreshed = await this.refreshTokens();
    return refreshed ? (this.tokenPair?.accessToken ?? '') : '';
  }

  /**
   * 获取当前 AccessToken（同步版本，不触发刷新，仅供日志或诊断使用）
   */
  public getAccessToken(): string {
    return this.tokenPair?.accessToken ?? '';
  }

  /**
   * 获取当前 RefreshToken
   */
  public getRefreshToken(): string {
    return this.tokenPair?.refreshToken ?? '';
  }

  /**
   * 判断当前是否持有有效令牌（不判断过期时间，仅判断非空）
   */
  public hasToken(): boolean {
    return !!this.tokenPair?.accessToken;
  }

  /**
   * 清除所有令牌（登出、账号切换或安全事件触发时调用）
   */
  public clearToken(): void {
    this.tokenPair = null;
    this.pendingRefreshPromise = null;
    this.notifyListeners(null);
    hilog.info(DOMAIN, TAG, 'All tokens cleared.');
  }

  /**
   * 手动触发一次 Token 刷新（AuthInterceptor 收到 401 时主动调用）
   * 利用 pendingRefreshPromise 实现并发去重，多个 401 并发仅执行一次刷新
   *
   * @returns true 表示刷新成功，false 表示 RefreshToken 亦已失效需重新登录
   */
  public async refreshTokens(): Promise<boolean> {
    // 并发防重：若已有刷新任务在途，直接复用其 Promise 结果
    if (this.pendingRefreshPromise) {
      hilog.info(DOMAIN, TAG, 'Concurrent refresh detected, reusing inflight refresh promise...');
      return this.pendingRefreshPromise;
    }

    this.pendingRefreshPromise = this.doRefresh();
    try {
      const result = await this.pendingRefreshPromise;
      return result;
    } finally {
      this.pendingRefreshPromise = null;
    }
  }

  /**
   * 实际执行 Token 刷新的私有方法
   */
  private async doRefresh(): Promise<boolean> {
    if (!this.refreshAction) {
      hilog.error(DOMAIN, TAG, 'TokenRefreshAction is not registered. Call setRefreshAction() first.');
      return false;
    }

    if (!this.tokenPair?.refreshToken) {
      hilog.warn(DOMAIN, TAG, 'RefreshToken is missing, cannot perform refresh.');
      this.clearToken();
      return false;
    }

    try {
      hilog.info(DOMAIN, TAG, 'Executing token refresh action...');
      const newPair = await this.refreshAction();
      this.saveToken(newPair);
      hilog.info(DOMAIN, TAG, 'Token refreshed successfully.');
      return true;
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Token refresh failed: ${(err as Error).message}`);
      // 刷新失败说明 RefreshToken 亦已过期，彻底清零强制重新登录
      this.clearToken();
      return false;
    }
  }

  /**
   * 判断 AccessToken 是否已过期或进入预刷新缓冲窗口
   */
  private isAccessTokenExpiringSoon(): boolean {
    if (!this.tokenPair?.expiresAt) {
      // 未配置过期时间则视为永久有效（兼容无 expiresIn 的旧服务端）
      return false;
    }
    const remainingMs = this.tokenPair.expiresAt - Date.now();
    return remainingMs <= this.refreshBufferMs;
  }

  /**
   * 注册 Token 状态变更监听器
   *
   * @param listener Token 发生变更时的回调（包括保存与清除）
   */
  public addChangeListener(listener: TokenChangeListener): void {
    this.changeListeners.add(listener);
  }

  /**
   * 注销 Token 状态变更监听器
   */
  public removeChangeListener(listener: TokenChangeListener): void {
    this.changeListeners.delete(listener);
  }

  /**
   * 通知所有已注册的监听器当前最新令牌状态
   */
  private notifyListeners(pair: TokenPair | null): void {
    this.changeListeners.forEach((listener) => {
      try {
        listener(pair);
      } catch (err) {
        hilog.warn(DOMAIN, TAG, `Error in TokenChangeListener: ${(err as Error).message}`);
      }
    });
  }
}

/**
 * 快捷导出全局 TokenManager 单例
 */
export const tokenManager: TokenManager = TokenManager.getInstance();
