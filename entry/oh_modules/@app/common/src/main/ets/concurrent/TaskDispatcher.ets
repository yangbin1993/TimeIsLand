import { taskpool } from '@kit.ArkTS';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { TaskPriority, TaskExecutionOptions, TaskItem, TaskPair, TaskTriple } from './TaskTypes';

const TAG: string = 'TaskDispatcher';
const DOMAIN: number = 0x0000;

/**
 * 顶层并发 JSON 反序列化执行函数
 * 严禁捕获外部作用域闭包变量，纯函数输入输出
 */
@Concurrent
function concurrentParseJson(raw: string): Object {
  try {
    return JSON.parse(raw) as Object;
  } catch (err) {
    throw new Error(`Failed to parse JSON string: ${(err as Error).message}`);
  }
}

/**
 * 顶层并发 JSON 序列化执行函数
 * 严禁捕获外部作用域闭包变量，纯函数输入输出
 */
@Concurrent
function concurrentStringifyJson(data: Object): string {
  try {
    return JSON.stringify(data);
  } catch (err) {
    throw new Error(`Failed to stringify JSON object: ${(err as Error).message}`);
  }
}

/**
 * 生产级后台任务并发池调度门面 (TaskDispatcher)
 * 深度对标 Android Kotlin 协程 Dispatchers.IO 与 iOS TaskPriority.background
 * 
 * 核心架构特性：
 * 1. Actor 隔离执行保障：将耗时 CPU 密集型任务安全调度至系统 TaskPool 线程池，杜绝主线程 120 FPS 掉帧与 Watchdog 崩溃；
 * 2. 强类型泛型接口：支持输入参数与返回结果的编译期类型安全校验；
 * 3. 任务超时与主动取消：支持配置 timeoutMs，超时自动触发 taskpool.cancel 熔断机制；
 * 4. 批处理与序列编排：深度封装 TaskGroup（并行归约）与 SequenceRunner（串行后台管道）；
 * 5. 内置高频重算工具：提供预置的后台大文本 JSON 序列化/反序列化支持；
 * 6. 全链路异常安全防护：对所有可能抛出异常的底层 API 进行深度防御与结构化捕获。
 */
export class TaskDispatcher {
  /**
   * 将单一任务分发至后台 TaskPool 线程池执行
   *
   * @param func 标记 @Concurrent 装饰器的独立工作函数
   * @param param 传递给工作函数的输入参数
   * @param options 任务调度配置选项（优先级、超时时间与名称）
   * @returns 异步返回任务执行结果 Promise<T>
   */
  public static async execute<T, P>(
    func: (arg: P) => T,
    param: P,
    options?: TaskExecutionOptions
  ): Promise<T> {
    const priority = options?.priority ?? taskpool.Priority.MEDIUM;
    const taskName = options?.name ?? 'AnonymousTask';
    const startTime = Date.now();

    hilog.info(DOMAIN, TAG, `Dispatching task [${taskName}] with priority [${priority}]`);

    try {
      const task: taskpool.Task = options?.name
        ? (param !== undefined
            ? new taskpool.Task(options.name, func, param as Object)
            : new taskpool.Task(options.name, func))
        : (param !== undefined
            ? new taskpool.Task(func, param as Object)
            : new taskpool.Task(func));

      // 若未配置超时时长，直接执行
      if (!options?.timeoutMs || options.timeoutMs <= 0) {
        const result = (await taskpool.execute(task, priority)) as T;
        const elapsed = Date.now() - startTime;
        hilog.info(DOMAIN, TAG, `Task [${taskName}] completed in ${elapsed} ms`);
        return result;
      }

      // 配置了超时熔断机制：通过 Promise.race 实现超时主动取消
      const timeoutMs = options.timeoutMs;
      let timerId: number = -1;

      const timeoutPromise = new Promise<T>((_: (value: T) => void, reject: (reason: Error) => void): void => {
        timerId = setTimeout((): void => {
          try {
            taskpool.cancel(task);
            hilog.warn(DOMAIN, TAG, `Task [${taskName}] timed out after ${timeoutMs} ms and was canceled.`);
          } catch (cancelErr) {
            hilog.warn(DOMAIN, TAG, `Failed to cancel timed-out task [${taskName}]: ${(cancelErr as Error).message}`);
          }
          reject(new Error(`Task [${taskName}] timed out after ${timeoutMs} ms`));
        }, timeoutMs);
      });

      const executionPromise = taskpool.execute(task, priority).then((res: Object | undefined): T => {
        clearTimeout(timerId);
        const elapsed = Date.now() - startTime;
        hilog.info(DOMAIN, TAG, `Task [${taskName}] finished in ${elapsed} ms`);
        return res as T;
      }).catch((err: Error): never => {
        clearTimeout(timerId);
        hilog.error(DOMAIN, TAG, `Task [${taskName}] failed: ${err.message}`);
        throw err;
      });

      return await Promise.race([executionPromise, timeoutPromise]);
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Task [${taskName}] execution error: ${(err as Error).message}`);
      throw err as Error;
    }
  }

  /**
   * 并发执行一组任务并聚合返回所有结果 (TaskGroup)
   * 类似 Promise.all，但所有任务均分配在不同的后台工作线程并行计算
   *
   * @param tasks 任务数组，包含独立的 @Concurrent 函数与参数
   * @param priority 调度优先级，默认为 MEDIUM
   * @returns 聚合后的结果数组 Promise<T[]>
   */
  public static async executeGroup<T, P>(
    tasks: TaskItem<T, P>[],
    priority: taskpool.Priority = taskpool.Priority.MEDIUM
  ): Promise<T[]> {
    if (tasks.length === 0) {
      return [];
    }

    const startTime = Date.now();
    hilog.info(DOMAIN, TAG, `Dispatching TaskGroup with ${tasks.length} tasks...`);

    try {
      const group = new taskpool.TaskGroup();

      for (let i = 0; i < tasks.length; i++) {
        const item = tasks[i];
        const task: taskpool.Task = item.arg !== undefined
          ? new taskpool.Task(item.func, item.arg as Object)
          : new taskpool.Task(item.func);
        group.addTask(task);
      }

      const rawResults = (await taskpool.execute(group, priority)) as Object[];
      const elapsed = Date.now() - startTime;
      hilog.info(DOMAIN, TAG, `TaskGroup completed ${tasks.length} tasks in ${elapsed} ms`);
      return rawResults as T[];
    } catch (err) {
      hilog.error(DOMAIN, TAG, `TaskGroup failed: ${(err as Error).message}`);
      throw err as Error;
    }
  }

  /**
   * 在后台工作线程按严格顺序串行执行一组任务 (SequenceRunner)
   * 保证前一个任务完全执行完毕后才触发下一个任务，全程不阻塞 UI 渲染主线程
   *
   * @param tasks 按序执行的任务序列
   * @returns 按执行顺序返回的统一结果数组 Promise<T[]>
   */
  public static async executeSequence<T, P>(tasks: TaskItem<T, P>[]): Promise<T[]> {
    if (tasks.length === 0) {
      return [];
    }

    const startTime = Date.now();
    hilog.info(DOMAIN, TAG, `Dispatching SequenceRunner with ${tasks.length} tasks in series...`);

    try {
      const runner = new taskpool.SequenceRunner();
      const results: T[] = [];

      for (let i = 0; i < tasks.length; i++) {
        const item = tasks[i];
        const task: taskpool.Task = item.arg !== undefined
          ? new taskpool.Task(item.func, item.arg as Object)
          : new taskpool.Task(item.func);
        const res = (await runner.execute(task)) as T;
        results.push(res);
      }

      const elapsed = Date.now() - startTime;
      hilog.info(DOMAIN, TAG, `SequenceRunner completed all ${tasks.length} tasks in ${elapsed} ms`);
      return results;
    } catch (err) {
      hilog.error(DOMAIN, TAG, `SequenceRunner failed: ${(err as Error).message}`);
      throw err as Error;
    }
  }

  /**
   * 将大体积 JSON 字符串反序列化卸载至 TaskPool 后台工作线程
   * 彻底避免解析超大体积 JSON 报文时导致主线程丢帧卡顿
   *
   * @param rawJson 待解析的 JSON 字符串
   * @param priority 调度优先级，默认为 MEDIUM
   */
  public static async parseJson<T>(
    rawJson: string,
    priority: taskpool.Priority = taskpool.Priority.MEDIUM
  ): Promise<T> {
    try {
      const task = new taskpool.Task(concurrentParseJson, rawJson);
      const result = (await taskpool.execute(task, priority)) as Object;
      return result as T;
    } catch (err) {
      hilog.error(DOMAIN, TAG, `parseJson failed: ${(err as Error).message}`);
      throw err as Error;
    }
  }

  /**
   * 将大体积对象序列化为 JSON 字符串卸载至 TaskPool 后台工作线程
   *
   * @param data 待序列化的对象
   * @param priority 调度优先级，默认为 MEDIUM
   */
  public static async stringifyJson(
    data: Object,
    priority: taskpool.Priority = taskpool.Priority.MEDIUM
  ): Promise<string> {
    try {
      const task = new taskpool.Task(concurrentStringifyJson, data);
      const result = (await taskpool.execute(task, priority)) as string;
      return result;
    } catch (err) {
      hilog.error(DOMAIN, TAG, `stringifyJson failed: ${(err as Error).message}`);
      throw err as Error;
    }
  }

  /**
   * 并行调度两个异构任务并在两者均完成时返回强类型聚合结果 (对标 Android Coroutines awaitAll 与 Kotlin Pair)
   * 支持两个具有不同入参与出参类型的独立并发任务，直接在后台线程池并行计算
   *
   * @param task1 任务1
   * @param task2 任务2
   * @param priority 调度优先级，默认为 MEDIUM
   * @returns 强类型双元聚合结果 Promise<TaskPair<T1, T2>>
   */
  public static async join<T1, P1, T2, P2>(
    task1: TaskItem<T1, P1>,
    task2: TaskItem<T2, P2>,
    priority: taskpool.Priority = taskpool.Priority.MEDIUM
  ): Promise<TaskPair<T1, T2>> {
    const startTime = Date.now();
    hilog.info(DOMAIN, TAG, `Dispatching join with 2 heterogeneous tasks...`);

    try {
      const p1 = TaskDispatcher.execute<T1, P1>(task1.func, task1.arg, { priority });
      const p2 = TaskDispatcher.execute<T2, P2>(task2.func, task2.arg, { priority });
      const rawResults = await Promise.all([p1, p2]);
      const elapsed = Date.now() - startTime;
      hilog.info(DOMAIN, TAG, `join completed in ${elapsed} ms`);
      return new TaskPair<T1, T2>(rawResults[0] as T1, rawResults[1] as T2);
    } catch (err) {
      hilog.error(DOMAIN, TAG, `join failed: ${(err as Error).message}`);
      throw err as Error;
    }
  }

  /**
   * 并行调度三个异构任务并在均完成时返回强类型聚合结果 (对标 Android Coroutines awaitAll 与 Kotlin Triple)
   *
   * @param task1 任务1
   * @param task2 任务2
   * @param task3 任务3
   * @param priority 调度优先级，默认为 MEDIUM
   * @returns 强类型三元聚合结果 Promise<TaskTriple<T1, T2, T3>>
   */
  public static async join3<T1, P1, T2, P2, T3, P3>(
    task1: TaskItem<T1, P1>,
    task2: TaskItem<T2, P2>,
    task3: TaskItem<T3, P3>,
    priority: taskpool.Priority = taskpool.Priority.MEDIUM
  ): Promise<TaskTriple<T1, T2, T3>> {
    const startTime = Date.now();
    hilog.info(DOMAIN, TAG, `Dispatching join3 with 3 heterogeneous tasks...`);

    try {
      const p1 = TaskDispatcher.execute<T1, P1>(task1.func, task1.arg, { priority });
      const p2 = TaskDispatcher.execute<T2, P2>(task2.func, task2.arg, { priority });
      const p3 = TaskDispatcher.execute<T3, P3>(task3.func, task3.arg, { priority });
      const rawResults = await Promise.all([p1, p2, p3]);
      const elapsed = Date.now() - startTime;
      hilog.info(DOMAIN, TAG, `join3 completed in ${elapsed} ms`);
      return new TaskTriple<T1, T2, T3>(rawResults[0] as T1, rawResults[1] as T2, rawResults[2] as T3);
    } catch (err) {
      hilog.error(DOMAIN, TAG, `join3 failed: ${(err as Error).message}`);
      throw err as Error;
    }
  }

  /**
   * 并行调度两个异构任务并通过转换函数归约结果 (深度对标 Kotlin Flow.zip / combine 操作符)
   * 将两个后台并发计算结果在当前上下文通过 combiner 聚合为最终业务数据模型
   *
   * @param task1 任务1
   * @param task2 任务2
   * @param combiner 将两个异构结果合并为目标模型的转换函数
   * @param priority 调度优先级，默认为 MEDIUM
   * @returns 合并后的业务模型 Promise<R>
   */
  public static async zip<T1, P1, T2, P2, R>(
    task1: TaskItem<T1, P1>,
    task2: TaskItem<T2, P2>,
    combiner: (res1: T1, res2: T2) => R,
    priority: taskpool.Priority = taskpool.Priority.MEDIUM
  ): Promise<R> {
    try {
      const pair = await TaskDispatcher.join<T1, P1, T2, P2>(task1, task2, priority);
      return combiner(pair.first, pair.second);
    } catch (err) {
      hilog.error(DOMAIN, TAG, `zip failed: ${(err as Error).message}`);
      throw err as Error;
    }
  }

  /**
   * 并行调度三个异构任务并通过转换函数归约结果 (深度对标 Kotlin Flow.zip / combine 操作符)
   *
   * @param task1 任务1
   * @param task2 任务2
   * @param task3 任务3
   * @param combiner 将三个异构结果合并为目标模型的转换函数
   * @param priority 调度优先级，默认为 MEDIUM
   * @returns 合并后的业务模型 Promise<R>
   */
  public static async zip3<T1, P1, T2, P2, T3, P3, R>(
    task1: TaskItem<T1, P1>,
    task2: TaskItem<T2, P2>,
    task3: TaskItem<T3, P3>,
    combiner: (res1: T1, res2: T2, res3: T3) => R,
    priority: taskpool.Priority = taskpool.Priority.MEDIUM
  ): Promise<R> {
    try {
      const triple = await TaskDispatcher.join3<T1, P1, T2, P2, T3, P3>(task1, task2, task3, priority);
      return combiner(triple.first, triple.second, triple.third);
    } catch (err) {
      hilog.error(DOMAIN, TAG, `zip3 failed: ${(err as Error).message}`);
      throw err as Error;
    }
  }

  // ==================== 统一单例与实例方法支持 ====================

  private static instance: TaskDispatcher;

  private constructor() {}

  /**
   * 获取 TaskDispatcher 全局单例
   */
  public static getInstance(): TaskDispatcher {
    if (!TaskDispatcher.instance) {
      TaskDispatcher.instance = new TaskDispatcher();
    }
    return TaskDispatcher.instance;
  }

  /**
   * 实例方法代理：执行单任务
   */
  public execute<T, P>(
    func: (arg: P) => T,
    param: P,
    options?: TaskExecutionOptions
  ): Promise<T> {
    return TaskDispatcher.execute(func, param, options);
  }

  /**
   * 实例方法代理：执行并行任务组
   */
  public executeGroup<T, P>(
    tasks: TaskItem<T, P>[],
    priority?: taskpool.Priority
  ): Promise<T[]> {
    return TaskDispatcher.executeGroup(tasks, priority);
  }

  /**
   * 实例方法代理：执行串行任务序列
   */
  public executeSequence<T, P>(tasks: TaskItem<T, P>[]): Promise<T[]> {
    return TaskDispatcher.executeSequence(tasks);
  }

  /**
   * 实例方法代理：后台解析 JSON
   */
  public parseJson<T>(
    rawJson: string,
    priority?: taskpool.Priority
  ): Promise<T> {
    return TaskDispatcher.parseJson(rawJson, priority);
  }

  /**
   * 实例方法代理：后台序列化 JSON
   */
  public stringifyJson(
    data: Object,
    priority?: taskpool.Priority
  ): Promise<string> {
    return TaskDispatcher.stringifyJson(data, priority);
  }

  /**
   * 实例方法代理：双任务异构并发聚合
   */
  public join<T1, P1, T2, P2>(
    task1: TaskItem<T1, P1>,
    task2: TaskItem<T2, P2>,
    priority?: taskpool.Priority
  ): Promise<TaskPair<T1, T2>> {
    return TaskDispatcher.join(task1, task2, priority);
  }

  /**
   * 实例方法代理：三任务异构并发聚合
   */
  public join3<T1, P1, T2, P2, T3, P3>(
    task1: TaskItem<T1, P1>,
    task2: TaskItem<T2, P2>,
    task3: TaskItem<T3, P3>,
    priority?: taskpool.Priority
  ): Promise<TaskTriple<T1, T2, T3>> {
    return TaskDispatcher.join3(task1, task2, task3, priority);
  }

  /**
   * 实例方法代理：双任务拉链式聚合归约
   */
  public zip<T1, P1, T2, P2, R>(
    task1: TaskItem<T1, P1>,
    task2: TaskItem<T2, P2>,
    combiner: (res1: T1, res2: T2) => R,
    priority?: taskpool.Priority
  ): Promise<R> {
    return TaskDispatcher.zip(task1, task2, combiner, priority);
  }

  /**
   * 实例方法代理：三任务拉链式聚合归约
   */
  public zip3<T1, P1, T2, P2, T3, P3, R>(
    task1: TaskItem<T1, P1>,
    task2: TaskItem<T2, P2>,
    task3: TaskItem<T3, P3>,
    combiner: (res1: T1, res2: T2, res3: T3) => R,
    priority?: taskpool.Priority
  ): Promise<R> {
    return TaskDispatcher.zip3(task1, task2, task3, combiner, priority);
  }
}

/**
 * 快捷导出全局 TaskDispatcher 单例
 */
export const taskDispatcher: TaskDispatcher = TaskDispatcher.getInstance();
