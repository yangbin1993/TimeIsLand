/**
 * 专注会话运行状态枚举
 */
export enum FocusState {
  /**
   * 空闲待命状态
   */
  IDLE = 'IDLE',
  /**
   * 正在专注计时中
   */
  RUNNING = 'RUNNING',
  /**
   * 暂停中
   */
  PAUSED = 'PAUSED',
  /**
   * 休息阶段
   */
  RESTING = 'RESTING',
  /**
   * 无界心流延展漫游态 (倒计时归零后正向累加思维惯性)
   */
  FLOW_DRIFT = 'FLOW_DRIFT',
  /**
   * 已完成专注
   */
  COMPLETED = 'COMPLETED',
  /**
   * 中途主动终止
   */
  CANCELED = 'CANCELED'
}

/**
 * 专注分类标签实体
 */
export interface FocusTag {
  /**
   * 标签唯一标识 (主键自增或唯一ID)
   */
  id: number;
  /**
   * 归属用户 ID (华为账号 openID 或 'guest_local')
   */
  userId?: string;
  /**
   * 标签英文唯一键或名称
   */
  name: string;
  /**
   * 标签代表颜色 HEX 字符串，如 #4A90E2
   */
  colorHex: string;
  /**
   * 系统预置图标名称
   */
  iconName: string;
  /**
   * 是否为内置预置标签 (不可被删除)
   */
  isSystem: boolean;
}

/**
 * 专注记录持久化实体 (与 RDB focus_record 数据表映射)
 */
export interface FocusRecordEntity {
  /**
   * 自增主键 ID
   */
  id?: number;
  /**
   * 归属用户 ID (华为账号 openID 或 'guest_local')
   */
  userId?: string;
  /**
   * 关联的标签 ID
   */
  tagId: number;
  /**
   * 目标设定专注时长 (单位：分钟)
   */
  targetMinutes: number;
  /**
   * 实际有效专注时长 (单位：秒)
   */
  actualSeconds: number;
  /**
   * 专注开始时间戳 (毫秒)
   */
  startTime: number;
  /**
   * 专注结束时间戳 (毫秒)
   */
  endTime: number;
  /**
   * 记录最终状态 (COMPLETED | CANCELED)
   */
  state: FocusState;
  /**
   * 专注心流简短便签/心得
   */
  note?: string;
  /**
   * 自评分数 1 ~ 5 星
   */
  rating?: number;
  /**
   * 是否发生心流延展漫游
   */
  isFlowDrift?: boolean;
  /**
   * 心流延展增量秒数
   */
  driftSeconds?: number;
  /**
   * 本次专注是否在心流避风港缓冲保护下恢复
   */
  isGracePeriodUsed?: boolean;
  /**
   * 是否因避风港超时而优雅安全归档
   */
  graceOvertimeDocked?: boolean;
}

/**
 * 白噪音环境音配置项
 */
export interface WhiteNoiseItem {
  /**
   * 唯一标识
   */
  id: string;
  /**
   * 多语言字符串标识
   */
  nameKey: string;
  /**
   * 图标资源名
   */
  iconSymbol: string;
}

/**
 * 单日专注时间聚合统计指标
 */
export interface DayFocusSummary {
  /**
   * 日期字符串，格式 YYYY-MM-DD
   */
  dateString: string;
  /**
   * 当日累计专注分钟数
   */
  totalMinutes: number;
  /**
   * 当日专注会话完成次数
   */
  completedSessions: number;
}

/**
 * 标签维度聚合统计项
 */
export interface TagFocusSummary {
  /**
   * 标签 ID
   */
  tagId: number;
  /**
   * 标签名称
   */
  tagName: string;
  /**
   * 标签颜色
   */
  colorHex: string;
  /**
   * 累计专注分钟数
   */
  totalMinutes: number;
  /**
   * 占比百分比 0 ~ 100
   */
  percentage: number;
}

/**
 * 时光岛全局概览统计模型
 */
export interface FocusOverviewStat {
  /**
   * 今日累计专注分钟数
   */
  todayMinutes: number;
  /**
   * 今日已完成番茄钟个数
   */
  todayCompletedCount: number;
  /**
   * 历史累计总专注分钟数
   */
  allTimeMinutes: number;
  /**
   * 连续打卡坚持天数
   */
  streakDays: number;
  /**
   * 最近7天每日趋势
   */
  recentDailyStats: DayFocusSummary[];
  /**
   * 标签分布统计
   */
  tagDistributions: TagFocusSummary[];
}

/**
 * 心流气韵预置标签标准色彩池设计令牌 (HEX 集中统一管理)
 */
export const TAG_COLOR_WORK = '#4A90E2';
export const TAG_COLOR_STUDY = '#50E3C2';
export const TAG_COLOR_READING = '#F5A623';
export const TAG_COLOR_THINKING = '#9013FE';
export const TAG_COLOR_SPORT = '#7ED321';
export const TAG_COLOR_MEDITATION = '#FBBF24';
export const TAG_COLOR_CREATIVE = '#ACC7FF';
export const TAG_COLOR_DEFAULT = '#4A90E2';
export const TAG_COLOR_CUSTOM = '#60A5FA';
export const TAG_COLOR_EMERALD = '#4EDEA3';
