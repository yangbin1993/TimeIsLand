import { Context } from '@kit.AbilityKit';
import { uiObserver } from '@kit.ArkUI';
import { hiAppEvent, hilog } from '@kit.PerformanceAnalysisKit';
import { BehaviorEventType, BehaviorSequenceItem, TrackerConfigProvider, TrackerEventParams } from './TrackerTypes';

const TAG: string = 'AppEventTracker';
const DOMAIN: number = 0x0000;

/**
 * 鸿蒙全局事件打点与端侧行为感知追踪门面 (AppEventTracker)
 * 
 * 核心架构特性：
 * 1. 零代码全自动页面埋点：基于 ArkUI uiObserver 全局监听 Navigation 路由状态变更与停留时长；
 * 2. 系统级稳定性自动捕获：通过 hiAppEvent.addWatcher 自动拦截并汇总 Crash、Freeze 等故障；
 * 3. 端侧轻量特征环形缓冲池 (Ring Buffer)：在内存中维护最近 N 条用户行为序列，为端侧智能预测 (Next Action Prediction) 提供毫秒级特征提取；
 * 4. 依赖倒置设计：支持业务宿主注入 TrackerConfigProvider，解耦数据上报平台与本地逻辑；
 * 5. 严格遵循 ArkTS 强类型约束：杜绝无类型对象字面量与语法降级。
 */
export class AppEventTracker {
  private static instance: AppEventTracker;

  /**
   * 业务配置提供者
   */
  private configProvider?: TrackerConfigProvider;

  /**
   * 是否已完成全局初始化
   */
  private isInitialized: boolean = false;

  /**
   * 端侧行为特征环形内存缓冲池
   */
  private ringBuffer: BehaviorSequenceItem[] = [];

  /**
   * 缓冲池默认最大容量
   */
  private maxBufferSize: number = 50;

  /**
   * 页面进入时间戳暂存表 (用于精确计算页面驻留时长 Dwell Time)
   */
  private pageEnterTimes: Map<string, number> = new Map();

  /**
   * 系统稳定性事件监听 Watcher 句柄持有者
   */
  private stabilityWatcherHolder?: hiAppEvent.AppEventPackageHolder;

  private constructor() {}

  /**
   * 获取 AppEventTracker 全局统一单例
   */
  public static getInstance(): AppEventTracker {
    if (!AppEventTracker.instance) {
      AppEventTracker.instance = new AppEventTracker();
    }
    return AppEventTracker.instance;
  }

  /**
   * 全局装配并初始化埋点追踪与行为感知服务
   * 推荐在 AppAbility.onCreate 中调用
   * 
   * @param context 应用程序全局上下文
   * @param config 可选业务配置提供者
   */
  public initialize(context: Context, config?: TrackerConfigProvider): void {
    if (this.isInitialized) {
      hilog.warn(DOMAIN, TAG, 'AppEventTracker has already been initialized.');
      return;
    }

    this.configProvider = config;
    if (config?.maxBufferSize && config.maxBufferSize > 0) {
      this.maxBufferSize = config.maxBufferSize;
    }

    hilog.info(DOMAIN, TAG, `Initializing AppEventTracker with maxBufferSize=${this.maxBufferSize}...`);

    // 1. 注册系统稳定性异常全自动观察者 (hiAppEvent Watcher)
    this.setupStabilityWatcher();

    // 2. 注册 ArkUI 路由生命周期全自动页面埋点 (uiObserver)
    const enablePageTracking = config?.enableAutoPageTracking ?? true;
    if (enablePageTracking) {
      this.setupAutoPageTracking();
    }

    this.isInitialized = true;
    hilog.info(DOMAIN, TAG, 'AppEventTracker initialized successfully.');
  }

  /**
   * 设置业务配置提供者 (支持运行时动态替换)
   */
  public setConfigProvider(provider: TrackerConfigProvider): void {
    this.configProvider = provider;
    if (provider.maxBufferSize && provider.maxBufferSize > 0) {
      this.maxBufferSize = provider.maxBufferSize;
    }
  }

  /**
   * 注册系统稳定性异常观察者 (Crash, Freeze, Resource Fault)
   */
  private setupStabilityWatcher(): void {
    try {
      const watcher: hiAppEvent.Watcher = {
        name: 'AppStabilityWatcher',
        appEventFilters: [
          {
            domain: hiAppEvent.domain.OS,
            eventTypes: [hiAppEvent.EventType.FAULT]
          }
        ],
        onReceive: (domain: string, appEventGroups: Array<hiAppEvent.AppEventGroup>): void => {
          for (const group of appEventGroups) {
            hilog.error(
              DOMAIN,
              TAG,
              `[StabilityFault] domain=${domain}, eventName=${group.name}`
            );

            const faultParams = new TrackerEventParams(
              undefined,
              undefined,
              domain,
              group.appEventInfos.length
            );

            // 转化为内部标准事件写入环形缓冲池
            const faultItem: BehaviorSequenceItem = {
              id: `${Date.now()}_fault`,
              eventName: group.name,
              eventType: BehaviorEventType.STABILITY_FAULT,
              timestamp: Date.now(),
              params: faultParams
            };
            this.recordSequenceItem(faultItem);

            // 触发业务宿主配置的稳定性报警回调
            if (this.configProvider?.onStabilityFault) {
              this.configProvider.onStabilityFault(domain, group.name, faultParams);
            }
          }
        }
      };

      this.stabilityWatcherHolder = hiAppEvent.addWatcher(watcher);
      hilog.info(DOMAIN, TAG, 'hiAppEvent stability watcher registered.');
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Failed to register stability watcher: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 注册 ArkUI 路由全自动页面埋点 (基于 uiObserver)
   */
  private setupAutoPageTracking(): void {
    try {
      uiObserver.on('navDestinationUpdate', (info: uiObserver.NavDestinationInfo): void => {
        const pageName = info.name as string;
        const state = info.state;

        if (state === uiObserver.NavDestinationState.ON_SHOWN) {
          // 页面展示/激活
          this.pageEnterTimes.set(pageName, Date.now());
          this.recordInternalEvent('page_show', BehaviorEventType.PAGE_VIEW, pageName);
          hilog.info(DOMAIN, TAG, `[AutoTrack] Page Shown: ${pageName}`);
        } else if (state === uiObserver.NavDestinationState.ON_HIDDEN) {
          // 页面隐藏/离开，计算驻留时长
          let dwellDuration: number = 0;
          if (this.pageEnterTimes.has(pageName)) {
            const enterTime = this.pageEnterTimes.get(pageName) ?? Date.now();
            dwellDuration = Date.now() - enterTime;
            this.pageEnterTimes.delete(pageName);
          }

          const pageParams = new TrackerEventParams(dwellDuration);
          this.recordInternalEvent('page_hide', BehaviorEventType.PAGE_VIEW, pageName, dwellDuration, pageParams);
          hilog.info(DOMAIN, TAG, `[AutoTrack] Page Hidden: ${pageName}, Dwell: ${dwellDuration}ms`);
        }
      });
      hilog.info(DOMAIN, TAG, 'ArkUI uiObserver navDestinationUpdate listener registered.');
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Failed to setup auto page tracking: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 将强类型参数转换为系统 hiAppEvent params 结构
   */
  private buildHiAppEventParams(params?: TrackerEventParams): Record<string, hiAppEvent.ParamType> {
    const map: Record<string, hiAppEvent.ParamType> = {};
    if (!params) {
      return map;
    }
    if (params.dwell_ms !== undefined) {
      map['dwell_ms'] = params.dwell_ms;
    }
    if (params.button_name !== undefined) {
      map['button_name'] = params.button_name;
    }
    if (params.domain !== undefined) {
      map['domain'] = params.domain;
    }
    if (params.eventCount !== undefined) {
      map['eventCount'] = params.eventCount;
    }
    return map;
  }

  /**
   * 记录行为项至环形缓冲池，并持久化到底层 hiAppEvent 与外部回调
   */
  private recordSequenceItem(item: BehaviorSequenceItem): void {
    // 1. 环形队列维护：达到上限时弹出最旧记录，保留最近高价值行为
    if (this.ringBuffer.length >= this.maxBufferSize) {
      this.ringBuffer.shift();
    }
    this.ringBuffer.push(item);

    // 2. 底层 hiAppEvent 写入 (安全沙箱持久化)
    try {
      const appEventInfo: hiAppEvent.AppEventInfo = {
        domain: 'app_behavior',
        name: item.eventName,
        eventType: hiAppEvent.EventType.BEHAVIOR,
        params: this.buildHiAppEventParams(item.params)
      };
      hiAppEvent.write(appEventInfo);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Failed to write hiAppEvent: ${JSON.stringify(err)}`);
    }

    // 3. 分发至业务配置提供者 (例如集成第三方大数据或云端分析 SDK)
    if (this.configProvider?.onEventTracked) {
      this.configProvider.onEventTracked(item);
    }
  }

  /**
   * 构造并记录内部行为事件
   */
  private recordInternalEvent(
    eventName: string,
    eventType: BehaviorEventType,
    pageName?: string,
    durationMs?: number,
    params?: TrackerEventParams
  ): void {
    const item: BehaviorSequenceItem = {
      id: `${Date.now()}_${Math.floor(Math.random() * 1000)}`,
      eventName: eventName,
      eventType: eventType,
      pageName: pageName,
      timestamp: Date.now(),
      durationMs: durationMs,
      params: params
    };
    this.recordSequenceItem(item);
  }

  /**
   * 业务手动打点：记录自定义交互行为
   * 
   * @param eventName 事件名称
   * @param params 强类型实体参数
   * @param pageName 可选当前所在页面
   */
  public trackBehavior(eventName: string, params?: TrackerEventParams, pageName?: string): void {
    this.recordInternalEvent(eventName, BehaviorEventType.CUSTOM, pageName, undefined, params);
  }

  /**
   * 业务手动打点：记录关键按钮/卡片点击事件
   * 
   * @param buttonName 按钮/卡片标识
   * @param pageName 可选当前页面
   */
  public trackClick(buttonName: string, pageName?: string): void {
    const clickParams = new TrackerEventParams(undefined, buttonName);
    this.recordInternalEvent(`click_${buttonName}`, BehaviorEventType.CLICK, pageName, undefined, clickParams);
  }

  /**
   * 获取端侧最近发生的用户行为特征序列 (提供给端侧智能预测模型)
   * 
   * @param limit 获取的最大条数 (默认为全部当前缓冲池数据)
   * @returns 行为序列拷贝数组 (按时间由旧到新排序)
   */
  public getRecentBehaviors(limit?: number): BehaviorSequenceItem[] {
    if (!limit || limit >= this.ringBuffer.length) {
      return [...this.ringBuffer];
    }
    return this.ringBuffer.slice(this.ringBuffer.length - limit);
  }

  /**
   * 清空本地行为特征缓冲池
   */
  public clearBehaviorBuffer(): void {
    this.ringBuffer = [];
  }

  // ================= 静态便捷调用方法 =================

  /**
   * 静态快捷打点方法
   */
  public static track(eventName: string, params?: TrackerEventParams, pageName?: string): void {
    AppEventTracker.getInstance().trackBehavior(eventName, params, pageName);
  }

  /**
   * 静态快捷点击打点
   */
  public static trackClick(buttonName: string, pageName?: string): void {
    AppEventTracker.getInstance().trackClick(buttonName, pageName);
  }

  /**
   * 静态快捷提取端侧最近特征序列
   */
  public static getRecentBehaviors(limit?: number): BehaviorSequenceItem[] {
    return AppEventTracker.getInstance().getRecentBehaviors(limit);
  }
}

/**
 * 快捷导出全局埋点与行为追踪门面单例
 */
export const appEventTracker: AppEventTracker = AppEventTracker.getInstance();
