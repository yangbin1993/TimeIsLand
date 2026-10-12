import { errorManager } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { appEventTracker } from '../tracker/AppEventTracker';
import { TrackerEventParams } from '../tracker/TrackerTypes';

const TAG: string = 'CrashHandler';
const DOMAIN: number = 0x0000;

/**
 * 崩溃与未捕获异常上下文信息契约
 */
export interface CrashInfo {
  /**
   * 异常名称或类型
   */
  name: string;

  /**
   * 详细错误描述
   */
  message: string;

  /**
   * 异常发生时间戳 (ms)
   */
  timestamp: number;

  /**
   * 调用堆栈追踪字符串
   */
  stack?: string;
}

/**
 * 崩溃感知与自定义后置处理回调契约
 */
export type CrashListener = (crashInfo: CrashInfo) => void;

/**
 * 生产级应用全局未捕获异常守卫 (CrashHandler)
 * 深度接管主线程运行时崩溃与 Promise 未处理拒绝
 * 
 * 核心架构特性：
 * 1. 深度挂载 HarmonyOS errorManager 系统级错误总线；
 * 2. 自动格式化异常上下文并与 AppEventTracker 联动持久化落盘；
 * 3. 支持业务层多订阅者感知（如上传至 APM 监控、保存用户编辑草稿）；
 * 4. 防重入保护，避免异常上报本身抛错引发二次连锁崩溃。
 */
export class CrashHandler {
  private static instance: CrashHandler;
  private observerId: number = -1;
  private isRegistered: boolean = false;
  private listeners: CrashListener[] = [];

  private constructor() {}

  /**
   * 获取 CrashHandler 统一单例
   */
  public static getInstance(): CrashHandler {
    if (!CrashHandler.instance) {
      CrashHandler.instance = new CrashHandler();
    }
    return CrashHandler.instance;
  }

  /**
   * 添加自定义崩溃监听回调
   *
   * @param listener 崩溃监听器
   * @returns 注销该监听器的解绑函数
   */
  public addListener(listener: CrashListener): () => void {
    this.listeners.push(listener);
    return () => {
      const idx = this.listeners.indexOf(listener);
      if (idx !== -1) {
        this.listeners.splice(idx, 1);
      }
    };
  }

  /**
   * 挂载全局异常监听守卫
   * 推荐在 AppAbility.onCreate 早期启动阶段执行挂载
   */
  public register(): void {
    if (this.isRegistered) {
      hilog.warn(DOMAIN, TAG, 'CrashHandler already registered, ignoring duplicate registration');
      return;
    }

    try {
      const observer: errorManager.ErrorObserver = {
        onUnhandledException: (errMsg: string) => {
          this.handleCrash({
            name: 'UnhandledException',
            message: errMsg,
            timestamp: Date.now()
          });
        },
        onException: (errorObj: Error) => {
          this.handleCrash({
            name: errorObj.name || 'ApplicationException',
            message: errorObj.message || 'Unknown error message',
            timestamp: Date.now(),
            stack: errorObj.stack
          });
        }
      };

      this.observerId = errorManager.on('error', observer);
      this.isRegistered = true;
      hilog.info(DOMAIN, TAG, `CrashHandler registered successfully with observerId: ${this.observerId}`);
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Failed to register errorManager observer: ${(err as Error).message}`);
    }
  }

  /**
   * 注销全局异常监听
   */
  public unregister(): void {
    if (!this.isRegistered || this.observerId === -1) {
      return;
    }

    try {
      errorManager.off('error', this.observerId);
      this.isRegistered = false;
      this.observerId = -1;
      hilog.info(DOMAIN, TAG, 'CrashHandler unregistered successfully');
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Failed to unregister errorManager: ${(err as Error).message}`);
    }
  }

  /**
   * 统一异常收集与分发逻辑
   */
  private handleCrash(info: CrashInfo): void {
    hilog.fatal(DOMAIN, TAG, `[CRASH DETECTED] ${info.name}: ${info.message}\nStack: ${info.stack ?? 'N/A'}`);

    // 1. 联动 AppEventTracker 记录关键错误埋点
    try {
      const faultParams = new TrackerEventParams(undefined, undefined, info.name, 1);
      appEventTracker.trackBehavior('APP_CRASH_EVENT', faultParams);
    } catch (trackerErr) {
      // 容错防崩
    }

    // 2. 依次通知业务层自定义监听者
    for (let i = 0; i < this.listeners.length; i++) {
      try {
        this.listeners[i](info);
      } catch (listenerErr) {
        hilog.error(DOMAIN, TAG, `Custom crash listener failed: ${(listenerErr as Error).message}`);
      }
    }
  }
}

/**
 * 快捷导出全局崩溃守卫单例
 */
export const crashHandler: CrashHandler = CrashHandler.getInstance();
