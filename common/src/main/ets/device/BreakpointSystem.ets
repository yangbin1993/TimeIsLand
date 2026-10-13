import { window, display } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG = 'DisplayAdaptiveManager';
const DOMAIN = 0x0000;

/**
 * 鸿蒙官方标准断点类型 (Breakpoint)
 * - sm: [0, 600vp) 直板手机、小折叠外屏
 * - md: [600vp, 840vp) 折叠屏展开态、小平板
 * - lg: [840vp, +∞) 平板横屏、大折叠全开、2in1 桌面
 */
export type BreakpointType = 'sm' | 'md' | 'lg';

/**
 * 折叠屏硬件折叠状态契约
 */
export type FoldStatusType = 'UNKNOWN' | 'EXPANDED' | 'FOLDED' | 'HALF_FOLDED';

/**
 * 断点阈值常量 (单位: vp)
 */
export class BreakpointConstants {
  public static readonly BREAKPOINT_SM_MAX: number = 600;
  public static readonly BREAKPOINT_MD_MAX: number = 840;

  // AppStorage 状态持久化键
  public static readonly KEY_BREAKPOINT: string = 'currentBreakpoint';
  public static readonly KEY_WINDOW_WIDTH_VP: string = 'windowWidthVp';
  public static readonly KEY_WINDOW_HEIGHT_VP: string = 'windowHeightVp';
  public static readonly KEY_IS_FOLD_EXPANDED: string = 'isFoldExpanded';
  public static readonly KEY_FOLD_STATUS: string = 'foldStatus';
}

/**
 * 时光岛 - 鸿蒙全场景多屏尺寸与折叠屏自适应感知管理器
 * 职责:
 * 1. 窗口尺寸监听与 sm / md / lg 响应式断点自动计算；
 * 2. 折叠屏展开态、折叠态与悬停态 (Flex Mode) 原生感知；
 * 3. 驱动 AppStorage 状态流，赋能主页等核心容器无感切换单双栏布局。
 */
export class DisplayAdaptiveManager {
  private static instance: DisplayAdaptiveManager | null = null;
  private currentBreakpoint: BreakpointType = 'sm';
  private currentFoldStatus: FoldStatusType = 'UNKNOWN';
  private isFoldDevice: boolean = false;
  private mainWindow: window.Window | null = null;

  private constructor() {}

  public static getInstance(): DisplayAdaptiveManager {
    if (!DisplayAdaptiveManager.instance) {
      DisplayAdaptiveManager.instance = new DisplayAdaptiveManager();
    }
    return DisplayAdaptiveManager.instance;
  }

  /**
   * 初始化多屏与折叠屏自适应感知体系
   */
  public init(windowStage: window.WindowStage): void {
    try {
      this.mainWindow = windowStage.getMainWindowSync();
      if (!this.mainWindow) {
        hilog.warn(DOMAIN, TAG, 'MainWindow is null during init');
        return;
      }

      // 1. 获取初始窗口尺寸并计算断点
      const properties = this.mainWindow.getWindowProperties();
      this.updateWindowSize(properties.windowRect.width, properties.windowRect.height);

      // 2. 监听窗口尺寸动态变化 (如多任务分屏、自由窗口缩放、横竖屏切换)
      this.mainWindow.on('windowSizeChange', (size: window.Size): void => {
        this.updateWindowSize(size.width, size.height);
      });

      // 3. 探测折叠屏硬件并监听物理折叠状态
      this.initFoldStatusListener();
      hilog.info(DOMAIN, TAG, 'DisplayAdaptiveManager initialized successfully');
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize DisplayAdaptiveManager: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 监听折叠屏物理状态变更
   */
  private initFoldStatusListener(): void {
    try {
      if (canIUse('SystemCapability.WindowManager.WindowManager.Core')) {
        this.isFoldDevice = display.isFoldable();
        hilog.info(DOMAIN, TAG, 'Device is foldable: %{public}s', this.isFoldDevice ? 'true' : 'false');

        if (this.isFoldDevice) {
          const rawStatus = display.getFoldStatus();
          this.handleFoldStatusChange(rawStatus);

          display.on('foldStatusChange', (status: display.FoldStatus): void => {
            this.handleFoldStatusChange(status);
          });
        }
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Fold status listener exception (likely standard phone or emulator): %{public}s', JSON.stringify(err));
      this.isFoldDevice = false;
    }
  }

  /**
   * 解析折叠屏状态并同步至 AppStorage
   */
  private handleFoldStatusChange(rawStatus: display.FoldStatus): void {
    let statusText: FoldStatusType = 'UNKNOWN';
    let isExpanded = false;

    if (rawStatus === display.FoldStatus.FOLD_STATUS_EXPANDED) {
      statusText = 'EXPANDED';
      isExpanded = true;
    } else if (rawStatus === display.FoldStatus.FOLD_STATUS_FOLDED) {
      statusText = 'FOLDED';
      isExpanded = false;
    } else if (rawStatus === display.FoldStatus.FOLD_STATUS_HALF_FOLDED) {
      statusText = 'HALF_FOLDED';
      isExpanded = true;
    }

    this.currentFoldStatus = statusText;
    AppStorage.setOrCreate(BreakpointConstants.KEY_FOLD_STATUS, statusText);
    this.updateExpandedState();
    hilog.info(DOMAIN, TAG, 'Fold status updated: %{public}s', statusText);
  }

  /**
   * 根据窗口物理像素换算 VP 并更新断点
   */
  private updateWindowSize(pxWidth: number, pxHeight: number): void {
    try {
      const widthVp = px2vp(pxWidth);
      const heightVp = px2vp(pxHeight);

      let newBreakpoint: BreakpointType = 'sm';
      if (widthVp < BreakpointConstants.BREAKPOINT_SM_MAX) {
        newBreakpoint = 'sm';
      } else if (widthVp < BreakpointConstants.BREAKPOINT_MD_MAX) {
        newBreakpoint = 'md';
      } else {
        newBreakpoint = 'lg';
      }

      this.currentBreakpoint = newBreakpoint;

      AppStorage.setOrCreate(BreakpointConstants.KEY_WINDOW_WIDTH_VP, widthVp);
      AppStorage.setOrCreate(BreakpointConstants.KEY_WINDOW_HEIGHT_VP, heightVp);
      AppStorage.setOrCreate(BreakpointConstants.KEY_BREAKPOINT, newBreakpoint);

      this.updateExpandedState();

      hilog.info(
        DOMAIN,
        TAG,
        'Window size changed: w=%{public}d vp, h=%{public}d vp, breakpoint=%{public}s',
        Math.round(widthVp),
        Math.round(heightVp),
        newBreakpoint
      );
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to update window size: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 同步更新大画布/展开状态
   */
  private updateExpandedState(): void {
    const isExpanded = (this.currentBreakpoint !== 'sm') || (this.currentFoldStatus === 'EXPANDED');
    AppStorage.setOrCreate(BreakpointConstants.KEY_IS_FOLD_EXPANDED, isExpanded);
  }

  public getBreakpoint(): BreakpointType {
    return this.currentBreakpoint;
  }

  public getFoldStatus(): FoldStatusType {
    return this.currentFoldStatus;
  }

  public isExpanded(): boolean {
    return (this.currentBreakpoint !== 'sm') || (this.currentFoldStatus === 'EXPANDED');
  }

  /**
   * 页面或应用销毁时释放监听
   */
  public destroy(): void {
    try {
      if (this.mainWindow) {
        this.mainWindow.off('windowSizeChange');
        this.mainWindow = null;
      }
      if (this.isFoldDevice) {
        display.off('foldStatusChange');
      }
      hilog.info(DOMAIN, TAG, 'DisplayAdaptiveManager destroyed');
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Error during destroy: %{public}s', JSON.stringify(err));
    }
  }
}

export const displayAdaptiveManager = DisplayAdaptiveManager.getInstance();
