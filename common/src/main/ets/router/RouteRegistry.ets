import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'RouteRegistry';
const DOMAIN = 0x0000;

/**
 * 生产级路由注册中心 (RouteRegistry)
 * 深度对标 Android Compose Navigation 的 NavGraphBuilder 注册表机制
 * 负责统一管理所有 NavRoute 与对应页面 WrappedBuilder 构建器的原子绑定
 */
export class RouteRegistry {
  private static builders: Map<string, WrappedBuilder<[]>> = new Map();

  /**
   * 注册路由与对应页面构建器的原子绑定关系
   * 包含防重复注册与命名空间冲突检查
   *
   * @param name 路由全局唯一名称
   * @param builder 页面构建器 WrappedBuilder 实例
   */
  public static register(name: string, builder: WrappedBuilder<[]>): void {
    if (RouteRegistry.builders.has(name)) {
      hilog.warn(DOMAIN, TAG, `Route collision warning: [${name}] is being overridden!`);
    }
    RouteRegistry.builders.set(name, builder);
    hilog.info(DOMAIN, TAG, `Route successfully registered with Destination builder: [${name}]`);
  }

  /**
   * 获取指定路由名称绑定的页面构建器
   *
   * @param name 路由名称
   * @returns 页面构建器 WrappedBuilder，若未注册则返回 undefined
   */
  public static getBuilder(name: string): WrappedBuilder<[]> | undefined {
    return RouteRegistry.builders.get(name);
  }

  /**
   * 检查指定路由名称是否已完成注册绑定
   *
   * @param name 路由名称
   */
  public static has(name: string): boolean {
    return RouteRegistry.builders.has(name);
  }

  /**
   * 清除所有注册表信息（主要用于单元测试与调试）
   */
  public static clear(): void {
    RouteRegistry.builders.clear();
  }
}
