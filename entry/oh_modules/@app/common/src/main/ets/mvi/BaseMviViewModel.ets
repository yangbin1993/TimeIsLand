import { hilog } from '@kit.PerformanceAnalysisKit';
import { EffectListener } from './MviTypes';

const TAG: string = 'BaseMviViewModel';
const DOMAIN: number = 0x0000;

/**
 * 现代化鸿蒙 MVI (Model-View-Intent) 架构核心基类
 * 
 * 核心架构特性：
 * 1. 单向数据流 (Unidirectional Data Flow, UDF)：
 *    UI 交互只能通过唯一的 dispatch(intent) 发出交互意图，杜绝分散的方法暴露与隐式状态修改。
 * 2. 单一可信状态 (Single Source of Truth, SSOT)：
 *    通过单一响应式 state 对象承载页面渲染所需的全量数据，配合 ArkTS 状态管理 V2 实现精准刷新。
 * 3. 一次性副作用分离 (SideEffect)：
 *    将 Toast、弹窗、页面路由等非持久瞬时操作作为 Effect 派发与消费，杜绝界面重评时的状态重放。
 * 
 * @template STATE 页面单一响应式状态模型（通常由 @ObservedV2 装饰的类实例承载）
 * @template INTENT 用户交互意图联合类型（通常采用区分联合类型 Discriminated Union 表达）
 * @template EFFECT 一次性副作用联合类型
 */
export abstract class BaseMviViewModel<STATE extends Object, INTENT, EFFECT> {
  /**
   * 页面单一可信状态（由具体子类初始化具体的响应式状态类实例）
   */
  public abstract state: STATE;

  /**
   * 副作用观察者监听器集合
   */
  private effectListeners: Array<EffectListener<EFFECT>> = [];

  constructor() {
    hilog.info(DOMAIN, TAG, `${this.constructor.name} MVI ViewModel initialized`);
  }

  /**
   * 外部意图统一分发入口 (UI 层与 ViewModel 交互的唯一途径)
   * 
   * @param intent 承载具体用户操作与参数的意图对象
   */
  public dispatch(intent: INTENT): void {
    hilog.info(DOMAIN, TAG, `[Intent Dispatched]: %{public}s`, JSON.stringify(intent));
    this.handleIntent(intent);
  }

  /**
   * 意图处理核心抽象方法 (由业务子类实现具体业务突变或异步流转，对标 Reducer)
   * 
   * @param intent 接收到的意图对象
   */
  protected abstract handleIntent(intent: INTENT): void;

  /**
   * 触发一次性副作用发射 (供内部业务逻辑在特定时机调用，如网络成功跳转或错误提示)
   * 
   * @param effect 需执行的一次性副作用事件
   */
  protected emitEffect(effect: EFFECT): void {
    hilog.info(DOMAIN, TAG, `[Effect Emitted]: %{public}s`, JSON.stringify(effect));
    // 遍历当前已注册的副作用监听器进行消费
    this.effectListeners.forEach((listener: EffectListener<EFFECT>): void => {
      try {
        listener(effect);
      } catch (err) {
        hilog.error(DOMAIN, TAG, `Error executing effect listener: %{public}s`, JSON.stringify(err));
      }
    });
  }

  /**
   * UI 组件生命周期挂载时订阅副作用事件流
   * 
   * @param listener 副作用回调处理函数
   */
  public observeEffect(listener: EffectListener<EFFECT>): void {
    if (this.effectListeners.indexOf(listener) === -1) {
      this.effectListeners.push(listener);
    }
  }

  /**
   * UI 组件生命周期卸载时取消订阅副作用，防止内存泄漏
   * 
   * @param listener 待注销的回调处理函数
   */
  public removeEffectListener(listener: EffectListener<EFFECT>): void {
    const index: number = this.effectListeners.indexOf(listener);
    if (index !== -1) {
      this.effectListeners.splice(index, 1);
    }
  }

  /**
   * 清空所有已注册的副作用监听器
   */
  public clearEffectListeners(): void {
    this.effectListeners = [];
  }

  /**
   * ViewModel 销毁清理生命周期钩子
   * 推荐在宿主组件 aboutToDisappear 时触发
   */
  public onCleared(): void {
    this.clearEffectListeners();
    hilog.info(DOMAIN, TAG, `${this.constructor.name} MVI ViewModel cleared`);
  }
}
