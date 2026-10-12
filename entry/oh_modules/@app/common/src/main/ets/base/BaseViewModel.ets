import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'BaseViewModel';
const DOMAIN = 0x0000;

/**
 * 界面统一 UI 状态机枚举
 */
export enum UIState {
  IDLE = 0,       // 初始/空闲状态：无任务执行
  LOADING = 1,    // 正在加载中：展示全局或局部骨架屏/转圈 Loading
  SUCCESS = 2,    // 处理成功：正常展示业务数据界面
  EMPTY = 3,      // 空数据状态：请求成功但数据列表为空，展示通用空态图
  ERROR = 4       // 错误/异常状态：网络故障或业务拦截，展示重试按钮与错误文案
}

/**
 * 现代化 BaseViewModel 抽象基类
 * 基于 HarmonyOS 状态管理 V2 (@ObservedV2 与 @Trace) 深度构建
 * 
 * 核心架构规范：
 * 1. 职责单一：严格作为业务逻辑与响应式状态流的管理者，绝不耦合直接操作 UI/Window 的逻辑
 * 2. 状态驱动：通过统一的 uiState 枚举管理视图的生命周期状态（加载中/成功/空数据/错误）
 * 3. 资源收口：提供规范的 onCleared() 生命周期钩子，在对应宿主页面销毁时安全释放定时器或网络监听
 */
@ObservedV2
export class BaseViewModel {
  /**
   * 当前 ViewModel 绑定的统一 UI 状态
   */
  @Trace public uiState: UIState = UIState.IDLE;

  /**
   * 当前处于 ERROR 状态时的错误描述文案
   */
  @Trace public errorMessage: string = '';

  constructor() {
    hilog.info(DOMAIN, TAG, `${this.constructor.name} created`);
  }

  /**
   * 切换至加载中状态 (LOADING)
   * 自动清空此前的历史错误信息
   */
  public setLoading(): void {
    this.uiState = UIState.LOADING;
    this.errorMessage = '';
  }

  /**
   * 切换至业务成功状态 (SUCCESS)
   * 触发视图刷新渲染主内容区域
   */
  public setSuccess(): void {
    this.uiState = UIState.SUCCESS;
    this.errorMessage = '';
  }

  /**
   * 切换至空数据状态 (EMPTY)
   */
  public setEmpty(): void {
    this.uiState = UIState.EMPTY;
    this.errorMessage = '';
  }

  /**
   * 切换至错误异常状态 (ERROR)
   * 
   * @param message 需向用户提示或记录的错误原因
   */
  public setError(message: string): void {
    this.uiState = UIState.ERROR;
    this.errorMessage = message;
    hilog.error(DOMAIN, TAG, `State set to ERROR: ${message}`);
  }

  /**
   * 重置状态为初始空闲态 (IDLE)
   */
  public resetState(): void {
    this.uiState = UIState.IDLE;
    this.errorMessage = '';
  }

  /**
   * 快速判断当前是否处于加载状态
   */
  public isLoading(): boolean {
    return this.uiState === UIState.LOADING;
  }

  /**
   * ViewModel 业务初始化钩子，可在组件挂载后按需重写调用
   */
  public onInit(): void {}

  /**
   * ViewModel 销毁清理钩子
   * 在绑定的组件 aboutToDisappear 或所属 NavDestination 弹出销毁时由宿主调用，释放长连接、取消订阅与定时器
   */
  public onCleared(): void {
    hilog.info(DOMAIN, TAG, `${this.constructor.name} cleared`);
  }
}
