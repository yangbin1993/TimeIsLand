import { taskpool } from '@kit.ArkTS';

/**
 * 后台并发任务优先级枚举映射
 */
export enum TaskPriority {
  /**
   * 最高优先级，适用于直接影响 UI 交互即时性的任务
   */
  HIGH = taskpool.Priority.HIGH,
  /**
   * 默认中等优先级，适用于绝大多数标准异步业务计算
   */
  MEDIUM = taskpool.Priority.MEDIUM,
  /**
   * 低优先级，适用于非紧急的数据同步或日志分析任务
   */
  LOW = taskpool.Priority.LOW,
  /**
   * 空闲优先级，仅在 CPU 空闲时调度执行
   */
  IDLE = taskpool.Priority.IDLE
}

/**
 * 并发任务执行配置项
 */
export interface TaskExecutionOptions {
  /**
   * 任务执行调度优先级，默认 MEDIUM
   */
  priority?: taskpool.Priority;

  /**
   * 任务超时时间戳阈值（毫秒）。若超时则主动触发 taskpool.cancel 取消并抛出超时异常
   */
  timeoutMs?: number;

  /**
   * 任务可读名称标识，供日志追踪与耗时度量使用
   */
  name?: string;
}

/**
 * 组任务与序列任务项契约定义
 */
export interface TaskItem<T, P> {
  /**
   * 标注 @Concurrent 装饰器的独立工作函数
   */
  func: (arg: P) => T;

  /**
   * 传递给工作函数的入参对象（必须为可序列化数据）
   */
  arg: P;
}

/**
 * 双任务异构并发聚合结果容器
 * 深度对标 Android Kotlin Pair<A, B>，规避 ArkTS arkts-no-tuple-types 限制
 */
export class TaskPair<T1, T2> {
  public readonly first: T1;
  public readonly second: T2;

  constructor(first: T1, second: T2) {
    this.first = first;
    this.second = second;
  }
}

/**
 * 三任务异构并发聚合结果容器
 * 深度对标 Android Kotlin Triple<A, B, C>，规避 ArkTS arkts-no-tuple-types 限制
 */
export class TaskTriple<T1, T2, T3> {
  public readonly first: T1;
  public readonly second: T2;
  public readonly third: T3;

  constructor(first: T1, second: T2, third: T3) {
    this.first = first;
    this.second = second;
    this.third = third;
  }
}
