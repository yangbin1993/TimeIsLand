import { common } from '@kit.AbilityKit';
import { connection } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'AppLifecycleManager';
const DOMAIN = 0x0000;

/**
 * 应用前后台状态枚举
 */
export enum AppForegroundState {
  /**
   * 应用进入前台（对用户可见，可接受交互）
   */
  FOREGROUND = 'FOREGROUND',

  /**
   * 应用退入后台（不可见，避免消耗大量电量）
   */
  BACKGROUND = 'BACKGROUND'
}

/**
 * 网络连接状态枚举
 */
export enum NetworkState {
  /**
   * 网络连接正常
   */
  CONNECTED = 'CONNECTED',

  /**
   * 网络断开
   */
  DISCONNECTED = 'DISCONNECTED'
}

/**
 * 前后台状态变化监听器类型
 */
export type ForegroundListener = (state: AppForegroundState) => void;

/**
 * 网络状态变化监听器类型
 */
export type NetworkStateListener = (state: NetworkState) => void;

/**
 * 应用生命周期统一事件管理器 (AppLifecycleManager)
 *
 * 核心架构职责：
 * 1. 前后台事件统一分发：封装 AbilityStage 的 onForeground/onBackground 回调，
 *    向框架内各模块（网络层、埋点层、缓存层）提供统一的状态通知，
 *    避免各模块各自注册 AbilityStage 监听的分散耦合；
 *
 * 2. 网络状态感知统一分发：基于 @kit.NetworkKit 的 connection.on('netAvailable'/
 *    'netLost') 事件，向上层模块提供精确的网络恢复/断开通知，
 *    支持业务层在网络恢复后自动重拉数据；
 *
 * 3. 观察者模式解耦：通过 addForegroundListener/addNetworkListener 注册，
 *    各关心者自行订阅，互不干扰；生命周期结束时通过 remove 精确注销，防止内存泄漏；
 *
 * 4. 依赖倒置友好：在 AppAbility/AbilityStage 中调用 notifyForeground/
 *    notifyBackground 即可驱动整个通知体系，框架模块无需直接依赖 Ability 层。
 */
export class AppLifecycleManager {
  private static instance: AppLifecycleManager;

  /**
   * 前后台状态监听器集合
   */
  private foregroundListeners: Set<ForegroundListener> = new Set();

  /**
   * 网络状态监听器集合
   */
  private networkListeners: Set<NetworkStateListener> = new Set();

  /**
   * 当前应用前后台状态快照（供同步查询）
   */
  private currentForegroundState: AppForegroundState = AppForegroundState.BACKGROUND;

  /**
   * 当前网络连接状态快照
   */
  private currentNetworkState: NetworkState = NetworkState.CONNECTED;

  /**
   * 网络状态监听 NetId（用于精确注销）
   */
  private netConnectionHandle?: connection.NetConnection;

  /**
   * 是否已完成初始化
   */
  private isInitialized: boolean = false;

  private constructor() {}

  /**
   * 获取 AppLifecycleManager 全局单例
   */
  public static getInstance(): AppLifecycleManager {
    if (!AppLifecycleManager.instance) {
      AppLifecycleManager.instance = new AppLifecycleManager();
    }
    return AppLifecycleManager.instance;
  }

  /**
   * 初始化生命周期管理器，启动网络状态监听
   * 推荐在 AppAbility.onCreate 中调用
   *
   * @param context 应用程序上下文
   */
  public initialize(context: common.Context): void {
    if (this.isInitialized) {
      hilog.warn(DOMAIN, TAG, 'AppLifecycleManager already initialized.');
      return;
    }

    this.setupNetworkMonitor();
    this.isInitialized = true;
    hilog.info(DOMAIN, TAG, 'AppLifecycleManager initialized successfully.');
  }

  // ==================== 前后台事件驱动入口（由 Ability 层调用） ====================

  /**
   * 通知应用已进入前台
   * 在 AppAbility.onForeground 中调用
   */
  public notifyForeground(): void {
    if (this.currentForegroundState === AppForegroundState.FOREGROUND) {
      return;
    }
    this.currentForegroundState = AppForegroundState.FOREGROUND;
    hilog.info(DOMAIN, TAG, 'App entered FOREGROUND state.');
    this.dispatchForeground(AppForegroundState.FOREGROUND);
  }

  /**
   * 通知应用已退入后台
   * 在 AppAbility.onBackground 中调用
   */
  public notifyBackground(): void {
    if (this.currentForegroundState === AppForegroundState.BACKGROUND) {
      return;
    }
    this.currentForegroundState = AppForegroundState.BACKGROUND;
    hilog.info(DOMAIN, TAG, 'App entered BACKGROUND state.');
    this.dispatchForeground(AppForegroundState.BACKGROUND);
  }

  // ==================== 监听器注册与注销 ====================

  /**
   * 注册前后台状态变化监听器
   *
   * @param listener 状态变化回调函数
   */
  public addForegroundListener(listener: ForegroundListener): void {
    this.foregroundListeners.add(listener);
    // 注册后立即回调当前状态，便于新注册者同步当前状态
    try {
      listener(this.currentForegroundState);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Initial foreground state dispatch error: ${(err as Error).message}`);
    }
  }

  /**
   * 注销前后台状态变化监听器
   */
  public removeForegroundListener(listener: ForegroundListener): void {
    this.foregroundListeners.delete(listener);
  }

  /**
   * 注册网络状态变化监听器
   *
   * @param listener 网络状态变化回调函数
   */
  public addNetworkListener(listener: NetworkStateListener): void {
    this.networkListeners.add(listener);
    // 注册后立即回调当前网络状态
    try {
      listener(this.currentNetworkState);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Initial network state dispatch error: ${(err as Error).message}`);
    }
  }

  /**
   * 注销网络状态变化监听器
   */
  public removeNetworkListener(listener: NetworkStateListener): void {
    this.networkListeners.delete(listener);
  }

  // ==================== 状态查询 ====================

  /**
   * 同步获取当前应用前后台状态
   */
  public getForegroundState(): AppForegroundState {
    return this.currentForegroundState;
  }

  /**
   * 同步获取当前网络连接状态
   */
  public getNetworkState(): NetworkState {
    return this.currentNetworkState;
  }

  /**
   * 判断当前是否处于前台
   */
  public isInForeground(): boolean {
    return this.currentForegroundState === AppForegroundState.FOREGROUND;
  }

  /**
   * 判断当前网络是否连通
   */
  public isNetworkConnected(): boolean {
    return this.currentNetworkState === NetworkState.CONNECTED;
  }

  // ==================== 内部实现 ====================

  /**
   * 启动 NetworkKit 网络连接状态监听
   */
  private setupNetworkMonitor(): void {
    try {
      this.netConnectionHandle = connection.createNetConnection();

      // 监听网络可用（连接恢复）事件
      this.netConnectionHandle.on('netAvailable', (): void => {
        if (this.currentNetworkState !== NetworkState.CONNECTED) {
          this.currentNetworkState = NetworkState.CONNECTED;
          hilog.info(DOMAIN, TAG, 'Network became CONNECTED.');
          this.dispatchNetwork(NetworkState.CONNECTED);
        }
      });

      // 监听网络丢失（断开）事件
      this.netConnectionHandle.on('netLost', (): void => {
        if (this.currentNetworkState !== NetworkState.DISCONNECTED) {
          this.currentNetworkState = NetworkState.DISCONNECTED;
          hilog.warn(DOMAIN, TAG, 'Network became DISCONNECTED.');
          this.dispatchNetwork(NetworkState.DISCONNECTED);
        }
      });

      this.netConnectionHandle.register((err) => {
        if (err) {
          hilog.error(DOMAIN, TAG, `Network monitor register failed: ${JSON.stringify(err)}`);
        } else {
          hilog.info(DOMAIN, TAG, 'Network monitor registered successfully.');
        }
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Failed to setup network monitor: ${(err as Error).message}`);
    }
  }

  /**
   * 分发前后台状态到所有注册的监听器
   */
  private dispatchForeground(state: AppForegroundState): void {
    this.foregroundListeners.forEach((listener) => {
      try {
        listener(state);
      } catch (err) {
        hilog.error(DOMAIN, TAG, `Error in ForegroundListener: ${(err as Error).message}`);
      }
    });
  }

  /**
   * 分发网络状态到所有注册的监听器
   */
  private dispatchNetwork(state: NetworkState): void {
    this.networkListeners.forEach((listener) => {
      try {
        listener(state);
      } catch (err) {
        hilog.error(DOMAIN, TAG, `Error in NetworkStateListener: ${(err as Error).message}`);
      }
    });
  }

  /**
   * 销毁生命周期管理器，注销网络监听（应用销毁时调用）
   */
  public destroy(): void {
    if (this.netConnectionHandle) {
      try {
        this.netConnectionHandle.unregister((err) => {
          if (err) {
            hilog.warn(DOMAIN, TAG, `Network monitor unregister error: ${JSON.stringify(err)}`);
          }
        });
      } catch (err) {
        hilog.warn(DOMAIN, TAG, `Failed to destroy network monitor: ${(err as Error).message}`);
      }
    }
    this.foregroundListeners.clear();
    this.networkListeners.clear();
    this.isInitialized = false;
    hilog.info(DOMAIN, TAG, 'AppLifecycleManager destroyed.');
  }
}

/**
 * 快捷导出全局应用生命周期管理器单例
 */
export const appLifecycleManager: AppLifecycleManager = AppLifecycleManager.getInstance();
