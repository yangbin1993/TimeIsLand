import { hilog } from '@kit.PerformanceAnalysisKit';
import { container } from '../di/Container';
import { HttpClient } from '../http/HttpClient';
import { HttpConfigProvider } from '../http/config/HttpConfigProvider';
import { PermissionHelper } from '../permission/PermissionHelper';
import { PermissionConfigProvider } from '../permission/config/PermissionConfigProvider';
import { AppEventTracker } from '../tracker/AppEventTracker';
import { TrackerConfigProvider } from '../tracker/TrackerTypes';

const TAG: string = 'FrameworkFacade';
const DOMAIN: number = 0x0000;

/**
 * 应用级依赖倒置契约聚合结构 (FrameworkContracts)
 * 集中声明宿主业务模块需反向注入给 common 基础设施的所有抽象契约
 */
export interface FrameworkContracts {
  /**
   * 网络通信体系基础配置提供者 (必填)
   * 负责提供动态 BaseUrl、通用请求头、超时时间及调试模式
   */
  httpConfig: HttpConfigProvider;

  /**
   * 权限管理体系交互配置提供者 (可选)
   * 负责提供业务权限解释文案 (Rationale)、拒绝后二次引导弹窗及全局权限埋点监听
   */
  permissionConfig?: PermissionConfigProvider;

  /**
   * 埋点追踪与行为感知配置提供者 (可选)
   * 负责提供自定义上报过滤、外部大数据平台桥接与稳定性告警联动
   */
  trackerConfig?: TrackerConfigProvider;
}

/**
 * 依赖倒置契约统一管理门面 (FrameworkFacade)
 * 
 * 核心架构职责：
 * 1. 契约聚合收敛：将散落在不同基础设施（网络、权限等）中的依赖倒置入口统一收敛为一个高内聚门面；
 * 2. 一站式装配调度：宿主业务模块在应用冷启动 (AppAbility.onCreate) 时仅需调用一次 initialize()；
 * 3. 自动注入分发：门面内部自动将具体的业务提供者绑定到 HttpClient、PermissionHelper 并同步托管至 DI Container 容器；
 * 4. 状态受控与防御：提供生命周期就绪检查 (isInitialized) 与契约安全访问通道。
 */
export class FrameworkFacade {
  private static instance: FrameworkFacade;
  private contracts?: FrameworkContracts;
  private initialized: boolean = false;

  private constructor() {}

  /**
   * 获取 FrameworkFacade 全局统一单例
   */
  public static getInstance(): FrameworkFacade {
    if (!FrameworkFacade.instance) {
      FrameworkFacade.instance = new FrameworkFacade();
    }
    return FrameworkFacade.instance;
  }

  /**
   * 一站式初始化并装配所有依赖倒置契约
   * 
   * @param contracts 宿主业务层实现的契约集合
   */
  public initialize(contracts: FrameworkContracts): void {
    if (this.initialized) {
      hilog.warn(DOMAIN, TAG, 'FrameworkFacade has already been initialized. Re-initializing will override existing providers.');
    }

    this.contracts = contracts;

    // 1. 装配网络通信底座 (HttpClient)
    const http = HttpClient.getInstance();
    http.setConfigProvider(contracts.httpConfig);
    container.registerSingleton('HttpConfigProvider', contracts.httpConfig);
    container.registerSingleton('HttpClient', http);
    hilog.info(DOMAIN, TAG, 'HttpConfigProvider assembled into HttpClient successfully');

    // 2. 装配权限管理套件 (PermissionHelper)
    const permHelper = PermissionHelper.getInstance();
    if (contracts.permissionConfig) {
      permHelper.setConfigProvider(contracts.permissionConfig);
      container.registerSingleton('PermissionConfigProvider', contracts.permissionConfig);
      hilog.info(DOMAIN, TAG, 'PermissionConfigProvider assembled into PermissionHelper successfully');
    }
    container.registerSingleton('PermissionHelper', permHelper);

    // 3. 装配事件追踪与行为感知套件 (AppEventTracker)
    const tracker = AppEventTracker.getInstance();
    if (contracts.trackerConfig) {
      tracker.setConfigProvider(contracts.trackerConfig);
      container.registerSingleton('TrackerConfigProvider', contracts.trackerConfig);
      hilog.info(DOMAIN, TAG, 'TrackerConfigProvider assembled into AppEventTracker successfully');
    }
    container.registerSingleton('AppEventTracker', tracker);

    this.initialized = true;
    hilog.info(DOMAIN, TAG, 'FrameworkFacade unified initialization completed successfully');
  }

  /**
   * 检查门面是否已完成初始化装配
   */
  public isInitialized(): boolean {
    return this.initialized;
  }

  /**
   * 获取当前生效的网络配置提供者
   * 
   * @throws Error 若尚未完成初始化装配
   */
  public getHttpConfig(): HttpConfigProvider {
    if (!this.contracts?.httpConfig) {
      throw new Error('[FrameworkFacade] HttpConfigProvider has not been initialized. Please call FrameworkFacade.getInstance().initialize() first.');
    }
    return this.contracts.httpConfig;
  }

  /**
   * 获取当前生效的权限配置提供者
   */
  public getPermissionConfig(): PermissionConfigProvider | undefined {
    return this.contracts?.permissionConfig;
  }

  /**
   * 获取当前生效的埋点追踪配置提供者
   */
  public getTrackerConfig(): TrackerConfigProvider | undefined {
    return this.contracts?.trackerConfig;
  }
}

/**
 * 快捷导出全局门面单例
 */
export const frameworkFacade: FrameworkFacade = FrameworkFacade.getInstance();
