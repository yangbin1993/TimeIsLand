/**
 * MVI (Model-View-Intent) 架构核心契约与类型定义
 */

/**
 * 一次性副作用监听器函数契约
 * 
 * @template EFFECT 副作用联合类型
 */
export type EffectListener<EFFECT> = (effect: EFFECT) => void;

/**
 * 基础意图抽象接口标记 (可选，便于类型约束)
 */
export interface BaseIntent {
  type: string;
}

/**
 * 基础一次性副作用标记 (可选，便于类型约束)
 */
export interface BaseEffect {
  type: string;
}
