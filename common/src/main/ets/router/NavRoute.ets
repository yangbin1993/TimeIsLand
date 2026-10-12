import { RouteRegistry } from './RouteRegistry';

/**
 * 强类型路由契约定义 (NavRoute)
 * 解决传统纯字符串路由弱类型、无编译期检查、重构易出错及孤岛路由白屏痛点
 * 深度对标 Android Jetpack Navigation 2.8+ 的 Type-Safe Navigation 模式
 *
 * 核心安全特性：
 * 1. 构造函数完全私有化（private constructor），严禁在业务端随意 new 伪造假路由
 * 2. 路由契约与页面渲染器原子强绑定（WrappedBuilder），彻底消灭由于漏写 PageMap 导致的静默白屏
 * 3. 严格遵循 ArkTS 强类型规范，使用 undefined 默认泛型彻底规避 arkts-no-void-as-type-argument 报错
 *
 * @template P 页面跳转入参结构类型 (默认为 undefined，表示无需入参)
 * @template R 页面回退结果结构类型 (默认为 undefined，表示无需返回值)
 */
export class NavRoute<P = undefined, R = undefined> {
  /**
   * 页面路由在 NavPathStack 体系中的全局唯一注册标识名称
   */
  public readonly name: string;

  /**
   * 仅用于 TypeScript / ArkTS 编译期静态泛型类型推导与参数校验，运行时不占用内存
   */
  public readonly _paramType?: P;

  /**
   * 仅用于 TypeScript / ArkTS 编译期静态泛型类型推导与结果校验，运行时不占用内存
   */
  public readonly _resultType?: R;

  /**
   * 绑定的页面原子构建器 (WrappedBuilder)
   */
  private builder?: WrappedBuilder<[]>;

  /**
   * 🔒 私有化构造函数，禁止外部直接 new 实例化
   */
  private constructor(name: string, builder?: WrappedBuilder<[]>) {
    this.name = name;
    this.builder = builder;
    if (builder) {
      RouteRegistry.register(name, builder);
    }
  }

  /**
   * 路由定义统一工厂方法
   *
   * @param name 唯一路由标识名称
   * @param builder 对应页面的原子构建器（可选，也可通过 .bind() 流式绑定）
   */
  public static define<P = undefined, R = undefined>(
    name: string,
    builder?: WrappedBuilder<[]>
  ): NavRoute<P, R> {
    return new NavRoute<P, R>(name, builder);
  }

  /**
   * 将当前路由契约与页面的真实构建器进行原子绑定
   * 绑定后自动加入全局 RouteRegistry 注册中心，供 Navigation 全自动安全派发
   *
   * @param builder 页面 WrappedBuilder 构建器
   */
  public bind(builder: WrappedBuilder<[]>): NavRoute<P, R> {
    this.builder = builder;
    RouteRegistry.register(this.name, builder);
    return this;
  }

  /**
   * 获取当前路由契约绑定的页面构建器
   */
  public getBuilder(): WrappedBuilder<[]> | undefined {
    return this.builder;
  }
}
