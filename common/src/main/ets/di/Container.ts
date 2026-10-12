import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'Container';
const DOMAIN = 0x0000;

/**
 * 延迟创建单例的工厂函数契约
 */
export type Factory<T> = () => T;

/**
 * 类型安全依赖注入令牌 (InjectionKey<T>)
 * 通过泛型令牌替代裸字符串键，在编译期保证 resolve 返回值类型正确，
 * 彻底消除字符串键重构时的运行时崩溃风险。
 *
 * 使用方式：
 * ```ts
 * // 1. 在模块中声明 Key（推荐放在 AppKeys.ts 统一管理）
 * export const USER_REPO_KEY = new InjectionKey<UserRepository>('UserRepository');
 *
 * // 2. 注册
 * container.bind(USER_REPO_KEY, new UserRepository());
 *
 * // 3. 解析（返回类型自动推导为 UserRepository）
 * const repo = container.get(USER_REPO_KEY);
 * ```
 */
export class InjectionKey<T> {
  /**
   * 调试友好的描述标签
   */
  public readonly description: string;

  constructor(description: string) {
    this.description = description;
  }

  public toString(): string {
    return `InjectionKey[${this.description}]`;
  }
}

/**
 * 轻量级依赖注入容器 (Container)
 * 解决大中型鸿蒙项目中模块间的硬编码强耦合，提供集中式的服务注册与查找定位能力
 * 
 * 核心特性：
 * 1. 立即单例模式 (registerSingleton)：适用于轻量对象或启动时必须就绪的核心基础设施（如 HttpClient）
 * 2. 懒加载单例模式 (registerLazySingleton)：延迟至首次 resolve() 时才执行工厂构造并缓存单例，大幅降低应用冷启动耗时
 * 3. 兼容 ServiceLocator 命名别名，支持无缝平滑迁移
 */
export class Container {
  private static instance: Container;
  // 已实例化的单例注册表
  private singletons: Map<string, Object> = new Map();
  // 延迟初始化的工厂函数注册表
  private factories: Map<string, Factory<Object>> = new Map();

  private constructor() {}

  /**
   * 获取全局单例容器实例
   */
  public static getInstance(): Container {
    if (!Container.instance) {
      Container.instance = new Container();
    }
    return Container.instance;
  }

  /**
   * 注册已实例化的单例对象
   * 
   * @param key 服务的唯一标识字符串
   * @param instance 已经创建完毕的单例对象
   */
  public registerSingleton<T extends Object>(key: string, instance: T): void {
    hilog.info(DOMAIN, TAG, `Register singleton: ${key}`);
    this.singletons.set(key, instance);
  }

  /**
   * 注册延迟创建单例的工厂方法
   * 只有在首次调用 resolve 时才真正执行 factory 回调并缓存单例结果，节约冷启动内存与耗时
   * 
   * @param key 服务的唯一标识字符串
   * @param factory 负责创建实例的工厂函数
   */
  public registerLazySingleton<T extends Object>(key: string, factory: Factory<T>): void {
    hilog.info(DOMAIN, TAG, `Register lazy singleton: ${key}`);
    this.factories.set(key, factory);
  }

  /**
   * 兼容原有 ServiceLocator 的注册别名方法
   */
  public register<T extends Object>(key: string, instance: T): void {
    this.registerSingleton(key, instance);
  }

  /**
   * 根据唯一标识解析获取依赖实例
   * 优先查找已存在的单例；若命中延迟工厂，则动态实例化、缓存并清理工厂
   * 
   * @param key 服务的唯一标识字符串
   * @returns 强类型解析的目标依赖实例
   * @throws Error 当指定 key 未注册任何单例或工厂时抛出
   */
  public resolve<T>(key: string): T {
    // 1. 命中已有的常驻单例
    if (this.singletons.has(key)) {
      return this.singletons.get(key) as T;
    }

    // 2. 命中延迟初始化工厂
    if (this.factories.has(key)) {
      const factory = this.factories.get(key)!;
      const instance = factory();
      this.singletons.set(key, instance);
      this.factories.delete(key);
      hilog.info(DOMAIN, TAG, `Instantiated lazy singleton: ${key}`);
      return instance as T;
    }

    // 3. 依赖缺失报错保护
    const errorMsg = `[Container] No dependency registered for key: ${key}`;
    hilog.error(DOMAIN, TAG, '%{public}s', errorMsg);
    throw new Error(errorMsg);
  }

  /**
   * 检查指定 key 是否已经在容器中注册（包括单例和工厂）
   */
  public has(key: string): boolean {
    return this.singletons.has(key) || this.factories.has(key);
  }

  /**
   * 清空所有注册的服务与缓存的单例实例
   * 常用于单元测试重置或用户彻底退出登录时清理
   */
  public clear(): void {
    this.singletons.clear();
    this.factories.clear();
    hilog.info(DOMAIN, TAG, 'Container cleared');
  }

  // ==================== 类型安全 InjectionKey 系列 API ====================

  /**
   * 使用类型安全 InjectionKey 注册单例实例（编译期类型验证）
   *
   * @param key 类型安全 InjectionKey 令牌
   * @param instance 已创建完毕的单例实例
   */
  public bind<T extends Object>(key: InjectionKey<T>, instance: T): void {
    hilog.info(DOMAIN, TAG, `Bind singleton: ${key.description}`);
    this.singletons.set(key.description, instance);
  }

  /**
   * 使用类型安全 InjectionKey 注册延迟加载工厂
   *
   * @param key 类型安全 InjectionKey 令牌
   * @param factory 延迟实例化工厂函数
   */
  public bindLazy<T extends Object>(key: InjectionKey<T>, factory: Factory<T>): void {
    hilog.info(DOMAIN, TAG, `Bind lazy singleton: ${key.description}`);
    this.factories.set(key.description, factory);
  }

  /**
   * 通过类型安全 InjectionKey 解析依赖（返回类型自动推导，无需手动泛型标注）
   *
   * @param key 类型安全 InjectionKey 令牌
   * @returns 强类型依赖实例 T
   * @throws Error 当指定 Key 未注册时抛出
   */
  public get<T>(key: InjectionKey<T>): T {
    return this.resolve<T>(key.description);
  }

  /**
   * 检查 InjectionKey 是否已经注册
   */
  public hasKey<T>(key: InjectionKey<T>): boolean {
    return this.has(key.description);
  }
}

/**
 * 快捷导出全局默认容器单例
 */
export const container = Container.getInstance();

/**
 * 向下兼容现有工程习惯的 ServiceLocator 别名
 */
export const sl = container;
