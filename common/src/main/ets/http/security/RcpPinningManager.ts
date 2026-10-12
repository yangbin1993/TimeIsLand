import { rcp } from '@kit.RemoteCommunicationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';
import { CommonStrings } from '../../constants/CommonStrings';

const TAG = 'RcpPinningManager';
const DOMAIN = 0x0000;

/**
 * 证书告警与安全自愈事件监听器
 */
export interface CertificateAlertListener {
  /**
   * 触发逃生自愈成功回调
   * @param updatedPins 更新后的最新公钥指纹集合
   */
  onPinsRecovered(updatedPins: string[]): void;

  /**
   * 触发第三道防线全局降级退守告警回调
   * @param reason 降级原因说明
   * @param domain 异常域名
   */
  onPinningFallbackTriggered(reason: string, domain: string): void;
}

/**
 * 鸿蒙网络请求动态证书固定与自愈管理器 (RcpPinningManager)
 * 对应 Android 架构中的 OkHttpPinningManager.kt
 *
 * HTTPS 安全校验策略 —— 生产级三道防线体系：
 *
 * 1. 【第一道防线：静态内置】INITIAL_PINS
 *    解决：App 离线状态或首次冷启动的高安全校验，杜绝中间人攻击与抓包。
 *
 * 2. 【第二道防线：本地记忆】Preferences 持久化存储
 *    解决：App 自愈后的持久性。通过逃生通道获取最新指纹后持久化固化，下次冷启动无需重复触发异常自愈。
 *
 * 3. 【第三道防线：逃生自愈与系统退守】
 *    解决：极端生存与容灾问题。当服务端紧急轮转证书或证书意外过期导致握手失败（如 RCP 2300060）时：
 *    - 优先经由隔离的系统标准 CA 通道拉取最新指纹完成自愈重试；
 *    - 若逃生通道不可用，退守为信任系统标准根证书 CA，保证核心业务不中断，并分发告警。
 */
export class RcpPinningManager {
  private static instance: RcpPinningManager;

  private readonly pinStorageKey: string = 'key_ssl_pins';
  private businessDomain: string = 'api.example.com';
  private configServerUrl: string = 'https://config.example.com/api/v1/pins';

  /**
   * 运行时全局标记：是否因为持续失败而激活了全局退守（Soft Pinning）
   */
  public isPinningFallbackEnabled: boolean = false;

  // -------------------------------------------------------------------------
  // 第一道防线配置：硬编码内置公钥指纹 (Static Pins)
  // -------------------------------------------------------------------------
  private readonly initialPins: string[] = [
    'sha256/AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=',
    'sha256/BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB='
  ];

  // 内存中实时生效的指纹库
  private currentPins: string[] = [];

  // 并发防抖锁：复用逃生通道异步任务，避免并发洪峰冲击逃生服务器
  private activeRecoveryPromise: Promise<string[]> | null = null;

  // 告警监听器集合
  private readonly alertListeners: CertificateAlertListener[] = [];

  // 本地首选项实例缓存
  private prefStore: preferences.Preferences | null = null;

  // 会话重载回调
  private onSessionReloadNeeded: (() => void) | null = null;

  private constructor() {
    this.currentPins = [...this.initialPins];
  }

  /**
   * 获取全局单例管理器
   */
  public static getInstance(): RcpPinningManager {
    if (!RcpPinningManager.instance) {
      RcpPinningManager.instance = new RcpPinningManager();
    }
    return RcpPinningManager.instance;
  }

  /**
   * 初始化管理器（激活第二道防线：从本地持久化加载记忆指纹）
   * 
   * @param context UIAbility 上下文（若提供则开启 ArkData preferences 持久化）
   * @param sessionReloadCallback 当安全证书配置更新时用于热重载 HttpClient Session 的回调
   */
  public initialize(context?: common.Context, sessionReloadCallback?: () => void): void {
    if (sessionReloadCallback) {
      this.onSessionReloadNeeded = sessionReloadCallback;
    }

    if (context) {
      try {
        const options: preferences.Options = { name: 'app_ssl_security' };
        this.prefStore = preferences.getPreferencesSync(context, options);
        const savedPinsJson = this.prefStore.getSync(this.pinStorageKey, '') as string;
        if (savedPinsJson && savedPinsJson.trim().length > 0) {
          const parsed = JSON.parse(savedPinsJson) as string[];
          if (Array.isArray(parsed) && parsed.length > 0) {
            hilog.info(DOMAIN, TAG, '激活第二道防线：从本地持久化存储加载记忆指纹: %{public}s', savedPinsJson);
            this.currentPins = parsed;
            this.notifySessionReload();
          }
        }
      } catch (err) {
        hilog.warn(DOMAIN, TAG, '从本地存储加载证书指纹失败，退回初始内置指纹: %{public}s', JSON.stringify(err));
      }
    }
  }

  /**
   * 注册证书事件监听器（供 APM、运维监控或 UI 告警订阅）
   */
  public addAlertListener(listener: CertificateAlertListener): void {
    this.alertListeners.push(listener);
  }

  /**
   * 配置业务受信任域名
   */
  public setBusinessDomain(domain: string): void {
    this.businessDomain = domain;
  }

  /**
   * 配置逃生通道服务器 URL
   */
  public setConfigServerUrl(url: string): void {
    this.configServerUrl = url;
  }

  /**
   * 获取当前生效的指纹列表
   */
  public getCurrentPins(): string[] {
    return [...this.currentPins];
  }

  /**
   * 构建 RCP 会话安全配置对象
   * 
   * @param forceFallback 是否强制使用降级模式（仅依赖系统 CA，跳过 Pinning）
   */
  public buildSecurityConfiguration(forceFallback: boolean = false): rcp.SecurityConfiguration {
    // 若处于降级状态或强制退守，执行【第三道防线】：仅使用系统根证书 CA 校验
    if (this.isPinningFallbackEnabled || forceFallback) {
      hilog.warn(DOMAIN, TAG, '构建安全配置：当前处于全局退守模式，仅使用系统标准 CA 校验');
      const fallbackConfig: rcp.SecurityConfiguration = {
        remoteValidation: 'system'
      };
      return fallbackConfig;
    }

    // 默认高安全性模式：基于内置/更新后的指纹库进行 Pinning 校验
    const pinningList: rcp.CertificatePinning[] = this.currentPins.map((pin: string): rcp.CertificatePinning => {
      const cleanHash = pin.startsWith('sha256/') ? pin.substring(7) : pin;
      const item: rcp.CertificatePinning = {
        kind: 'public-key',
        publicKeyHash: cleanHash,
        hashAlgorithm: 'SHA-256'
      };
      return item;
    });

    const standardConfig: rcp.SecurityConfiguration = {
      remoteValidation: 'system',
      certificatePinning: pinningList
    };

    return standardConfig;
  }

  // -------------------------------------------------------------------------
  // 第二道防线逻辑：动态更新与持久化存储 (Dynamic Update & Storage)
  // -------------------------------------------------------------------------

  /**
   * 刷新指纹：将【逃生通道】获取的新指纹转化为【本地记忆】并热重载会话
   * 
   * @param newPins 最新的公钥指纹列表
   * @param persist 是否写入本地存储
   */
  public refreshPins(newPins: string[], persist: boolean = true): void {
    if (!newPins || newPins.length === 0) {
      return;
    }

    hilog.info(DOMAIN, TAG, '证书指纹库更新，正在热重载网络会话并固化至本地...');
    this.currentPins = [...newPins];
    // 重置降级标记，因为新指纹已就位
    this.isPinningFallbackEnabled = false;

    // 持久化到本地首选项，确保下次冷启动无需再次逃生
    if (persist && this.prefStore) {
      try {
        this.prefStore.putSync(this.pinStorageKey, JSON.stringify(newPins));
        this.prefStore.flush();
        hilog.info(DOMAIN, TAG, '本地证书指纹数据库已完成持久化同步');
      } catch (e) {
        hilog.error(DOMAIN, TAG, '固化指纹到本地首选项失败: %{public}s', JSON.stringify(e));
      }
    }

    // 分发自愈成功回调
    this.alertListeners.forEach((listener) => {
      listener.onPinsRecovered(newPins);
    });

    // 触发 HttpClient 热重载 Session
    this.notifySessionReload();
  }

  // -------------------------------------------------------------------------
  // 第三道防线逻辑：逃生自愈通道与系统退守 (Recovery Path & Graceful Fallback)
  // -------------------------------------------------------------------------

  /**
   * 逃生通道请求：在校验失败时尝试自愈拉取最新指纹
   * 核心机制：
   * 1. 独立隔离请求：显式绕过当前锁定指纹，仅依赖系统 CA 与备用服务器握手；
   * 2. 并发防抖：复用活动 Promise，避免雪崩请求打穿逃生通道。
   */
  public async fetchNewPins(): Promise<string[]> {
    if (this.activeRecoveryPromise) {
      hilog.info(DOMAIN, TAG, '逃生通道任务正在执行中，复用正在进行的恢复请求...');
      return this.activeRecoveryPromise;
    }

    this.activeRecoveryPromise = this.performFetchNewPins();
    try {
      const result = await this.activeRecoveryPromise;
      return result;
    } finally {
      this.activeRecoveryPromise = null;
    }
  }

  private async performFetchNewPins(): Promise<string[]> {
    hilog.warn(DOMAIN, TAG, '触发证书安全保护：正在尝试通过独立逃生通道自愈...');

    let tempSession: rcp.Session | null = null;
    try {
      // 隔离会话：强制使用纯系统 CA 校验，不附加任何 Pinning
      tempSession = rcp.createSession({
        requestConfiguration: {
          security: {
            remoteValidation: 'system'
          },
          transfer: {
            timeout: {
              connectMs: 5000,
              transferMs: 5000
            }
          }
        }
      });

      const request = new rcp.Request(this.configServerUrl, 'GET');
      const response = await tempSession.fetch(request);

      if (response.statusCode === 200) {
        const text = response.toString() ?? '';
        hilog.info(DOMAIN, TAG, '逃生通道通信成功，解析新指纹配置: %{public}s', text);
        const parsed = JSON.parse(text) as Record<string, Object>;
        if (parsed && Array.isArray(parsed['pins'])) {
          const pins = parsed['pins'] as string[];
          if (pins.length > 0) {
            return pins;
          }
        }
      }
      return [];
    } catch (err) {
      hilog.error(DOMAIN, TAG, '逃生通道自愈请求发生异常: %{public}s', JSON.stringify(err));
      return [];
    } finally {
      if (tempSession) {
        try {
          tempSession.close();
        } catch (e) {
          // 忽略关闭异常
        }
      }
    }
  }

  /**
   * 核心协同调度：处理证书过期或指纹校验失败
   * 
   * @param targetUrl 触发失败的请求 URL
   * @returns 是否恢复成功（返回 true 表示可使用更新/降级后的 Session 进行透明重试）
   */
  public async handleCertificateFailure(targetUrl: string): Promise<boolean> {
    // 1. 若已经进入全局退守状态，说明退守后仍然失败（可能是服务器硬性挂掉），不再无限循环
    if (this.isPinningFallbackEnabled) {
      hilog.error(DOMAIN, TAG, '当前已处于全局退守模式，跳过重复自愈');
      return false;
    }

    hilog.warn(DOMAIN, TAG, '检测到 SSL 握手或证书校验故障，启动自愈决策流: %{public}s', targetUrl);

    // 2. 尝试从逃生通道获取新指纹（第二道防线自愈）
    const newPins = await this.fetchNewPins();
    if (newPins && newPins.length > 0) {
      hilog.info(DOMAIN, TAG, '逃生通道自愈成功，已拉取到最新指纹，热更新并准备重试');
      this.refreshPins(newPins, true);
      return true;
    }

    // 3. 逃生通道失败，触发【第三道防线：系统退守 (Soft Pinning)】
    // 场景：服务器紧急更换证书且逃生服务器临时异常。
    // 策略：开启全局降级标记，动态重置为信任系统标准 CA，保证核心业务不死。
    hilog.error(DOMAIN, TAG, '逃生通道自愈未成功，激活第三道防线：开启全局降级模式，退守至系统标准 CA');
    this.isPinningFallbackEnabled = true;

    // 分发告警事件供运维追踪
    this.alertListeners.forEach((listener) => {
      listener.onPinningFallbackTriggered(
        CommonStrings.SSL_FALLBACK_REASON,
        this.businessDomain
      );
    });

    // 热重载 Session 为降级配置
    this.notifySessionReload();
    return true;
  }

  /**
   * 手动重置降级状态并恢复严格 Pinning 校验
   */
  public resetFallbackMode(): void {
    hilog.info(DOMAIN, TAG, '手动重置降级模式，恢复严格证书指纹校验');
    this.isPinningFallbackEnabled = false;
    this.notifySessionReload();
  }

  private notifySessionReload(): void {
    if (this.onSessionReloadNeeded) {
      try {
        this.onSessionReloadNeeded();
      } catch (e) {
        hilog.error(DOMAIN, TAG, '热重载 Session 失败: %{public}s', JSON.stringify(e));
      }
    }
  }
}
