import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'AppEventBus';
const DOMAIN: number = 0x0000;

/**
 * 事件监听回调函数类型
 */
export type EventCallback<T> = (payload: T) => void;

/**
 * 内部监听包装项
 */
interface SubscriptionItem {
  callback: EventCallback<Object | undefined>;
  once: boolean;
}

/**
 * 生产级跨组件强类型事件总线 (AppEventBus)
 * 深度对标 Android EventBus / LiveData/SharedFlow 广播
 * 
 * 核心架构特性：
 * 1. 跨边界无侵入解耦：支持跨页面、跨 ViewModel、跨后台任务的高效消息通信；
 * 2. 闭包安全解绑：订阅接口返回清理闭包 () => void，防止页面销毁后的内存泄漏；
 * 3. 单次监听 (once) 机制：用于瞬时通知（如支付完成、单次鉴权刷新）；
 * 4. 故障隔离防御：单个监听者业务逻辑抛错不影响总线分发与其他监听者运行。
 */
export class AppEventBus {
  private static instance: AppEventBus;
  private listenersMap: Map<string, SubscriptionItem[]> = new Map();

  private constructor() {}

  /**
   * 获取 AppEventBus 全局统一单例
   */
  public static getInstance(): AppEventBus {
    if (!AppEventBus.instance) {
      AppEventBus.instance = new AppEventBus();
    }
    return AppEventBus.instance;
  }

  /**
   * 注册事件监听
   *
   * @param event 事件唯一名称
   * @param callback 接收到事件时的回调函数
   * @returns 注销该订阅的解绑闭包
   */
  public on<T>(event: string, callback: EventCallback<T>): () => void {
    if (!this.listenersMap.has(event)) {
      this.listenersMap.set(event, []);
    }

    const subItem: SubscriptionItem = {
      callback: callback as EventCallback<Object | undefined>,
      once: false
    };

    const list = this.listenersMap.get(event)!;
    list.push(subItem);

    return () => {
      this.off(event, callback);
    };
  }

  /**
   * 注册仅触发一次的事件监听 (单次消费后自动销毁)
   *
   * @param event 事件名称
   * @param callback 回调函数
   * @returns 注销解绑闭包
   */
  public once<T>(event: string, callback: EventCallback<T>): () => void {
    if (!this.listenersMap.has(event)) {
      this.listenersMap.set(event, []);
    }

    const subItem: SubscriptionItem = {
      callback: callback as EventCallback<Object | undefined>,
      once: true
    };

    const list = this.listenersMap.get(event)!;
    list.push(subItem);

    return () => {
      this.off(event, callback);
    };
  }

  /**
   * 向指定事件通道广播发送数据载荷
   *
   * @param event 事件名称
   * @param payload 事件携带的业务数据实体
   */
  public emit<T>(event: string, payload?: T): void {
    const subscribers = this.listenersMap.get(event);
    if (!subscribers || subscribers.length === 0) {
      return;
    }

    // 拷贝当前订阅者列表，防止在执行期间有动态取消导致遍历索引偏移
    const currentList = [...subscribers];
    const remainingList: SubscriptionItem[] = [];

    for (let i = 0; i < currentList.length; i++) {
      const item = currentList[i];
      try {
        item.callback(payload as (Object | undefined));
      } catch (err) {
        hilog.error(DOMAIN, TAG, `Error executing listener for event [${event}]: ${(err as Error).message}`);
      }

      // 如果非 once 监听则保留
      if (!item.once) {
        remainingList.push(item);
      }
    }

    if (remainingList.length > 0) {
      this.listenersMap.set(event, remainingList);
    } else {
      this.listenersMap.delete(event);
    }
  }

  /**
   * 注销指定事件的具体监听函数
   *
   * @param event 事件名称
   * @param callback 要注销的回调引用
   */
  public off<T>(event: string, callback?: EventCallback<T>): void {
    if (!this.listenersMap.has(event)) {
      return;
    }

    if (!callback) {
      this.listenersMap.delete(event);
      return;
    }

    const list = this.listenersMap.get(event)!;
    const filtered = list.filter((item) => item.callback !== (callback as EventCallback<Object | undefined>));

    if (filtered.length > 0) {
      this.listenersMap.set(event, filtered);
    } else {
      this.listenersMap.delete(event);
    }
  }

  /**
   * 清除指定事件或全部事件总线监听
   *
   * @param event 可选指定的事件名称 (若不传则清空全部)
   */
  public clear(event?: string): void {
    if (event) {
      this.listenersMap.delete(event);
    } else {
      this.listenersMap.clear();
    }
    hilog.info(DOMAIN, TAG, `AppEventBus listeners cleared${event ? ` for [${event}]` : ''}`);
  }
}

/**
 * 快捷导出全局事件总线单例
 */
export const appEventBus: AppEventBus = AppEventBus.getInstance();
