/**
 * 全局事件追踪与行为感知类型定义与契约 (TrackerTypes)
 * 为数据分析、稳定性监控以及端侧智能行为预测 (Next Action Prediction) 提供统一强类型基座
 */

/**
 * 用户与系统行为事件枚举分类
 */
export enum BehaviorEventType {
  /**
   * 页面浏览与路由跳转事件 (自动全埋点)
   */
  PAGE_VIEW = 'PAGE_VIEW',

  /**
   * 交互点击事件
   */
  CLICK = 'CLICK',

  /**
   * 业务自定义事件
   */
  CUSTOM = 'CUSTOM',

  /**
   * 系统级稳定性异常故障 (Crash, Freeze 等)
   */
  STABILITY_FAULT = 'STABILITY_FAULT'
}

/**
 * 结构化埋点与特征参数实体类 (TrackerEventParams)
 * 严格遵循 ArkTS 强类型规范，杜绝无类型对象字面量 (arkts-no-untyped-obj-literals)
 */
export class TrackerEventParams {
  public dwell_ms?: number;
  public button_name?: string;
  public domain?: string;
  public eventCount?: number;

  constructor(dwell_ms?: number, button_name?: string, domain?: string, eventCount?: number) {
    this.dwell_ms = dwell_ms;
    this.button_name = button_name;
    this.domain = domain;
    this.eventCount = eventCount;
  }
}

/**
 * 行为序列数据单元 (用于端侧轻量环形特征缓冲池)
 * 供端侧机器学习/马尔可夫链模型毫秒级提取最近的行为序列特征
 */
export interface BehaviorSequenceItem {
  /**
   * 事件唯一标识
   */
  id: string;

  /**
   * 事件名称 (例如 page_show, click_tab, add_to_cart 等)
   */
  eventName: string;

  /**
   * 事件分类
   */
  eventType: BehaviorEventType;

  /**
   * 发生事件的页面名称
   */
  pageName?: string;

  /**
   * 事件发生时间戳 (毫秒)
   */
  timestamp: number;

  /**
   * 停留时长 (毫秒，页面退出事件特有)
   */
  durationMs?: number;

  /**
   * 强类型扩展参数实体
   */
  params?: TrackerEventParams;
}

/**
 * 埋点与事件感知依赖倒置配置契约 (TrackerConfigProvider)
 * 允许业务宿主层定制过滤规则、外部上报桥接与稳定性预警联动
 */
export interface TrackerConfigProvider {
  /**
   * 是否开启 Navigation 路由全自动页面埋点 (默认 true)
   */
  enableAutoPageTracking?: boolean;

  /**
   * 端侧行为环形特征缓冲池最大容量 (默认 50 条)
   */
  maxBufferSize?: number;

  /**
   * 统一事件追踪回调 (可在此接入第三方如 华为分析 Analytics Kit、神策等)
   */
  onEventTracked?: (event: BehaviorSequenceItem) => void;

  /**
   * 系统稳定性异常故障回调 (Crash、卡顿等)
   */
  onStabilityFault?: (faultDomain: string, faultName: string, eventInfo?: TrackerEventParams) => void;
}
