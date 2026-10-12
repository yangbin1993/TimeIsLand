import { hilog } from '@kit.PerformanceAnalysisKit';
import { NavRoute } from './NavRoute';
import { RouteRegistry } from './RouteRegistry';

const TAG = 'AppRouter';
const DOMAIN = 0x0000;

/**
 * 路由守卫上下文信息（传递给守卫函数的导航意图）
 */
export interface NavigationContext {
  /**
   * 目标页面路由名称
   */
  targetName: string;

  /**
   * 传递给目标页面的参数对象
   */
  param?: Object;

  /**
   * 当前导航栈深度（可用于判断当前所在页面层级）
   */
  currentStackSize: number;
}

/**
 * 路由守卫决策结果
 */
export interface GuardDecision {
  /**
   * true 表示允许本次导航通过；false 表示拦截本次导航
   */
  allow: boolean;

  /**
   * 若拦截本次导航，可指定重定向的目标页面路由名称（如重定向至登录页）
   * 若为 undefined 则静默拦截，不进行任何跳转
   */
  redirectTo?: string;

  /**
   * 重定向时传递给目标页面的参数
   */
  redirectParam?: Object;
}

/**
 * 路由守卫抽象函数类型
 * 返回 GuardDecision 来决定是否允许本次路由跳转
 */
export type NavigationGuard = (context: NavigationContext) => Promise<GuardDecision> | GuardDecision;

/**
 * 全局导航路由调度器 (AppRouter) — 增强版（含 NavigationGuard 路由守卫）
 * 基于 HarmonyOS Navigation + NavPathStack 封装，实现组件化页面解耦与栈管理
 *
 * 核心优势：
 * 1. 彻底解耦传统 @ohos.router 强依赖 URL 字符串导致的硬编码与跨包跳转障碍
 * 2. 天然支持单页面栈、双栏分栏模式（折叠屏/平板），深度契合鸿蒙跨端全场景规范
 * 3. 单例模式提供全局访问能力，可在任意 ViewModel、Repository 或工具类中安全触发导航
 * 4. NavigationGuard 路由守卫机制：在导航执行前按顺序运行所有已注册守卫，
 *    支持登录鉴权拦截、页面访问权限管控与自动重定向
 */
export class AppRouter {
  private static instance: AppRouter;
  private pathStack: NavPathStack = new NavPathStack();

  /**
   * 已注册的路由守卫列表（按注册顺序顺次执行）
   */
  private guards: NavigationGuard[] = [];

  /**
   * 全局守卫跳过白名单（命中的路由名称不经过守卫检查）
   */
  private guardWhiteList: Set<string> = new Set(['LoginPage']);

  private constructor() {}

  /**
   * 获取全局单例实例
   */
  public static getInstance(): AppRouter {
    if (!AppRouter.instance) {
      AppRouter.instance = new AppRouter();
    }
    return AppRouter.instance;
  }

  /**
   * 绑定根 Navigation 的页面栈实例
   * 通常在根组件（如 LoginPage）的 aboutToAppear 中注入
   *
   * @param stack 根组件通过 @Provide 提供的 NavPathStack 实例
   */
  public setPathStack(stack: NavPathStack): void {
    this.pathStack = stack;
    hilog.info(DOMAIN, TAG, 'NavPathStack has been initialized and bound.');
  }

  /**
   * 获取当前绑定的页面栈实例
   */
  public getPathStack(): NavPathStack {
    return this.pathStack;
  }

  // ==================== 路由守卫管理 ====================

  /**
   * 注册路由守卫（按注册顺序依次执行，任意守卫返回 allow=false 即拦截导航）
   *
   * @param guard 路由守卫函数
   */
  public addGuard(guard: NavigationGuard): void {
    this.guards.push(guard);
    hilog.info(DOMAIN, TAG, `NavigationGuard registered, total guards: ${this.guards.length}`);
  }

  /**
   * 移除指定路由守卫
   */
  public removeGuard(guard: NavigationGuard): void {
    const index = this.guards.indexOf(guard);
    if (index !== -1) {
      this.guards.splice(index, 1);
    }
  }

  /**
   * 清除所有已注册的路由守卫
   */
  public clearGuards(): void {
    this.guards = [];
  }

  /**
   * 向守卫白名单追加路由名称（白名单内的路由跳过所有守卫）
   *
   * @param routeNames 免守卫路由名称列表
   */
  public addGuardWhiteList(...routeNames: string[]): void {
    routeNames.forEach((name) => this.guardWhiteList.add(name));
  }

  /**
   * 执行所有注册守卫的链式校验
   * 任意守卫返回 allow=false 则立即终止链，并执行重定向（若配置）
   *
   * @param context 当前导航意图上下文
   * @returns 最终守卫决策结果
   */
  private async runGuards(context: NavigationContext): Promise<GuardDecision> {
    // 白名单路由直接放行
    if (this.guardWhiteList.has(context.targetName)) {
      return { allow: true };
    }

    for (const guard of this.guards) {
      try {
        const decision = await Promise.resolve(guard(context));
        if (!decision.allow) {
          hilog.warn(
            DOMAIN, TAG,
            `NavigationGuard blocked navigation to [${context.targetName}]` +
            (decision.redirectTo ? `, redirecting to [${decision.redirectTo}]` : '')
          );
          return decision;
        }
      } catch (err) {
        hilog.error(DOMAIN, TAG, `NavigationGuard error for [${context.targetName}]: ${(err as Error).message}`);
        // 守卫执行异常时默认放行，避免因框架故障导致 APP 无法使用
        return { allow: true };
      }
    }

    return { allow: true };
  }

  // ==================== 类型安全强契约导航方法 (Type-Safe Navigation) ====================

  /**
   * 强类型页面入栈跳转 (Push) - 无参重载
   * 目标页面无需传参时调用此方法，禁止传递额外未定义参数
   *
   * @param route 目标页面路由契约对象 (P=void)
   * @param param 缺省或 undefined
   * @param animated 是否开启页面转场动画，默认为 true
   */
  public push<R>(route: NavRoute<undefined, R>, param?: undefined, animated?: boolean): Promise<void>;

  /**
   * 强类型页面入栈跳转 (Push) - 强类型有参重载
   * 编译期严格校验入参结构，杜绝拼写错误与字段缺失
   *
   * @param route 目标页面路由契约对象
   * @param param 符合契约 P 结构的入参对象
   * @param animated 是否开启页面转场动画，默认为 true
   */
  public push<P, R>(route: NavRoute<P, R>, param: P, animated?: boolean): Promise<void>;

  /**
   * 强类型页面入栈跳转统一实现
   */
  public async push<P, R>(route: NavRoute<P, R>, param?: P, animated: boolean = true): Promise<void> {
    const rawParam = param !== undefined ? (param as Object) : undefined;
    return this.pushPathByName(route.name, rawParam, animated);
  }

  /**
   * 强类型页面栈顶替换 (Replace) - 无参重载
   *
   * @param route 目标页面路由契约对象 (P=undefined)
   * @param param 缺省或 undefined
   * @param animated 是否开启页面转场动画，默认为 true
   */
  public replace<R>(route: NavRoute<undefined, R>, param?: undefined, animated?: boolean): Promise<void>;

  /**
   * 强类型页面栈顶替换 (Replace) - 强类型有参重载
   *
   * @param route 目标页面路由契约对象
   * @param param 符合契约 P 结构的入参对象
   * @param animated 是否开启页面转场动画，默认为 true
   */
  public replace<P, R>(route: NavRoute<P, R>, param: P, animated?: boolean): Promise<void>;

  /**
   * 强类型页面栈顶替换统一实现
   */
  public async replace<P, R>(route: NavRoute<P, R>, param?: P, animated: boolean = true): Promise<void> {
    const rawParam = param !== undefined ? (param as Object) : undefined;
    return this.replacePathByName(route.name, rawParam, animated);
  }

  /**
   * 强类型回退至指定契约页面 (PopToRoute)
   * 连续弹出页面直到目标路由位于栈顶
   *
   * @param route 目标页面路由契约
   * @param result 返回给目标页面的类型化结果对象
   * @param animated 是否开启转场动画，默认为 true
   * @returns 弹出的页面层数
   */
  public popToRoute<P, R>(route: NavRoute<P, R>, result?: R, animated: boolean = true): number {
    const rawResult = result !== undefined ? (result as Object) : undefined;
    return this.popToName(route.name, rawResult, animated);
  }

  /**
   * 强类型带返回值安全弹出当前栈顶页面 (PopWithResult)
   * 供子页面向上一级页面回传指定类型的结构化数据
   *
   * @param result 符合目标页面定义回传契约的结果数据
   * @param animated 是否开启转场动画，默认为 true
   */
  public popWithResult<R>(result: R, animated: boolean = true): void {
    const rawResult = result !== undefined ? (result as Object) : undefined;
    this.pop(rawResult, animated);
  }

  /**
   * 依据路由契约获取目标页面的最新入参
   *
   * @param route 目标页面路由契约
   * @returns 目标页面入参结构，不存在则返回 undefined
   */
  public getParamByRoute<P, R>(route: NavRoute<P, R>): P | undefined {
    const params = this.pathStack.getParamByName(route.name) as Object[];
    if (params && params.length > 0) {
      return params[params.length - 1] as P;
    }
    return undefined;
  }

  // ==================== 兼容性动态路由方法（供 DeepLink / Push 动态调用） ====================

  /**
   * 压入指定路由名称的目标页面 (Push)
   * 执行前会顺次运行所有注册的路由守卫
   *
   * @param name 目标页面路由名称，需在 Navigation 的 navDestination 分发表中注册
   * @param param 传递给目标页面的参数对象
   * @param animated 是否开启原生页面转场动画，默认为 true
   */
  public async pushPathByName(name: string, param?: Object, animated: boolean = true): Promise<void> {
    const context: NavigationContext = {
      targetName: name,
      param: param,
      currentStackSize: this.pathStack.size()
    };

    const decision = await this.runGuards(context);

    if (!decision.allow) {
      if (decision.redirectTo) {
        hilog.info(DOMAIN, TAG, `Guard redirect: ${name} -> ${decision.redirectTo}`);
        if (!RouteRegistry.has(decision.redirectTo)) {
          // 若重定向目标未在 Destination 注册（例如 LoginPage 属于 Navigation 宿主根容器），安全清空栈回退至根页面，杜绝 404
          if (this.pathStack.size() > 0) {
            this.pathStack.clear(animated);
          }
        } else {
          this.pathStack.pushPathByName(decision.redirectTo, decision.redirectParam ?? param, animated);
        }
      }
      return;
    }

    hilog.info(DOMAIN, TAG, `pushPathByName -> ${name}`);
    this.pathStack.pushPathByName(name, param, animated);
  }

  /**
   * 替换当前栈顶页面为指定页面 (Replace)
   * 执行前会顺次运行所有注册的路由守卫
   *
   * @param name 目标页面路由名称
   * @param param 页面传递参数对象
   * @param animated 是否开启转场动画，默认为 true
   */
  public async replacePathByName(name: string, param?: Object, animated: boolean = true): Promise<void> {
    const context: NavigationContext = {
      targetName: name,
      param: param,
      currentStackSize: this.pathStack.size()
    };

    const decision = await this.runGuards(context);

    if (!decision.allow) {
      if (decision.redirectTo) {
        if (!RouteRegistry.has(decision.redirectTo)) {
          // 若重定向目标未在 Destination 注册，安全清空栈回退至根页面，杜绝 404
          if (this.pathStack.size() > 0) {
            this.pathStack.clear(animated);
          }
        } else {
          this.pathStack.replacePathByName(decision.redirectTo, decision.redirectParam ?? param, animated);
        }
      }
      return;
    }

    hilog.info(DOMAIN, TAG, `replacePathByName -> ${name}`);
    this.pathStack.replacePathByName(name, param, animated);
  }

  /**
   * 弹出当前栈顶页面 (Pop)
   *
   * @param result 返回给上一级页面的结果数据对象
   * @param animated 是否开启转场动画，默认为 true
   */
  public pop(result?: Object, animated: boolean = true): void {
    hilog.info(DOMAIN, TAG, 'pop current page');
    this.pathStack.pop(result, animated);
  }

  /**
   * 连续弹出页面直至回退到指定路由名称的页面
   *
   * @param name 目标页面路由名称
   * @param result 返回给目标页面的结果对象
   * @param animated 是否开启转场动画，默认为 true
   * @returns 弹出的页面层数
   */
  public popToName(name: string, result?: Object, animated: boolean = true): number {
    hilog.info(DOMAIN, TAG, `popToName -> ${name}`);
    return this.pathStack.popToName(name, result, animated);
  }

  /**
   * 清空整个导航栈并返回根界面
   *
   * @param animated 是否开启转场动画，默认为 true
   */
  public clear(animated: boolean = true): void {
    hilog.info(DOMAIN, TAG, 'clear all page stacks');
    this.pathStack.clear(animated);
  }

  /**
   * 获取当前导航栈内的页面深度
   */
  public size(): number {
    return this.pathStack.size();
  }

  /**
   * 检查指定路由名称是否在导航栈中存在
   */
  public contains(name: string): boolean {
    return this.pathStack.getAllPathName().includes(name);
  }

  /**
   * 获取当前栈顶页面的路由名称
   */
  public getCurrentName(): string | undefined {
    const names = this.pathStack.getAllPathName();
    return names.length > 0 ? names[names.length - 1] : undefined;
  }
}

/**
 * 路由未找到 404 兜底视图组件
 * 彻底消除由于开发者漏注册或路由拼错导致的黑屏/白屏，提供优雅的异常反馈与返回通道
 */
@Component
struct RouteNotFoundView {
  @Prop routeName: string = '';

  build() {
    NavDestination() {
      Column({ space: 16 }) {
        Text('404')
          .fontSize(44)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FF3B30')

        Text('页面路由未找到')
          .fontSize(18)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')

        Text(`当前目标路由 [${this.routeName}] 未绑定任何页面构建器，请检查路由注册中心。`)
          .fontSize(14)
          .fontColor('#888888')
          .textAlign(TextAlign.Center)
          .padding({ left: 32, right: 32 })

        Button('返回上一页')
          .height(42)
          .width(140)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#007AFF')
          .margin({ top: 16 })
          .onClick((): void => {
            AppRouter.getInstance().pop();
          })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor('#FFFFFF')
    }
    .hideTitleBar(true)
  }
}

/**
 * 全局全自动 NavDestination 分发构建器 (AppRouterDestination)
 * 供 Navigation 根组件的 navDestination 属性直接绑定
 * 彻底消灭在各个 Page 中手写繁琐易漏的 if-else PageMap 分发逻辑
 *
 * @param name 目标路由名称
 */
@Builder
export function AppRouterDestination(name: string) {
  AppRouterDestinationContent(name)
}

@Builder
function AppRouterDestinationContent(name: string) {
  if (RouteRegistry.has(name)) {
    AppRouterRenderBuilder(name)
  } else {
    RouteNotFoundView({ routeName: name })
  }
}

@Builder
function AppRouterRenderBuilder(name: string) {
  // 从全局注册表中提取对应的 WrappedBuilder 并执行其渲染方法
  AppRouterInvokeBuilder(RouteRegistry.getBuilder(name), name)
}

@Builder
function AppRouterInvokeBuilder(builder: WrappedBuilder<[]> | undefined, name: string) {
  if (builder) {
    builder.builder()
  } else {
    RouteNotFoundView({ routeName: name })
  }
}

