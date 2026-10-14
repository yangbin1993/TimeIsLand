import { liveViewManager } from '@kit.LiveViewKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'LiveViewHelper';
const LIVE_VIEW_ID = 1001;

/**
 * 时光岛 - 鸿蒙实况窗 (Live View) 胶囊与锁屏水滴协同管理器
 * 职责: 将专注倒计时、心流漫游态以状态栏胶囊与锁屏常显形式向系统下发
 */
export class LiveViewHelper {
  private static instance: LiveViewHelper | null = null;
  private isSupported: boolean = false;
  private isActive: boolean = false;
  private currentSequence: number = 1;
  private currentTag: string = 'FlowFocus';
  private resContext: Context | null = null;

  public static getInstance(): LiveViewHelper {
    if (!LiveViewHelper.instance) {
      LiveViewHelper.instance = new LiveViewHelper();
    }
    return LiveViewHelper.instance;
  }

  constructor() {
    this.checkCapability();
  }

  public init(context: Context): void {
    this.resContext = context;
  }

  private getString(res: Resource, fallback: string): string {
    if (this.resContext) {
      try {
        return this.resContext.resourceManager.getStringSync(res.id);
      } catch (err) {
        return fallback;
      }
    }
    return fallback;
  }

  /**
   * 运行时检测设备是否具备实况窗系统能力
   */
  private checkCapability(): void {
    try {
      this.isSupported = canIUse('SystemCapability.LiveView.LiveViewService');
      hilog.info(DOMAIN, TAG, 'LiveView capability support: %{public}s', this.isSupported ? 'true' : 'false');
    } catch (err) {
      this.isSupported = false;
      hilog.warn(DOMAIN, TAG, 'Failed to check LiveView capability: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 启动实况窗 (状态栏胶囊 + 锁屏通知水滴卡片)
   */
  public async startLiveView(tagTitle: string, remainingSeconds: number): Promise<void> {
    const defaultTagStr = this.getString($r('app.string.liveview_default_tag'), 'FlowFocus');
    this.currentTag = tagTitle || defaultTagStr;
    this.currentSequence = 1;

    if (!this.isSupported) {
      hilog.info(DOMAIN, TAG, 'LiveView skipped: capability not supported on current device/emulator');
      return;
    }

    const isAppLiveViewEnabled = AppStorage.get<boolean>('isLiveViewEnabled') ?? true;
    if (!isAppLiveViewEnabled) {
      hilog.info(DOMAIN, TAG, 'LiveView skipped: disabled in application settings by user');
      return;
    }

    try {
      const isEnabled = await liveViewManager.isLiveViewEnabled();
      if (!isEnabled) {
        hilog.info(DOMAIN, TAG, 'LiveView skipped: disabled in system settings by user');
        return;
      }

      const timerCapsule: liveViewManager.TimerCapsule = {
        type: liveViewManager.CapsuleType.CAPSULE_TYPE_TIMER,
        status: 1,
        time: remainingSeconds * 1000,
        isCountdown: true,
        isPaused: false,
        content: this.currentTag
      };

      const calmDesc = this.getString($r('app.string.liveview_calm_desc'), 'Flow Sanctuary');
      const contentItem: liveViewManager.RichText = {
        text: calmDesc
      };

      const primaryData: liveViewManager.PrimaryData = {
        title: this.currentTag,
        content: [contentItem],
        keepTime: 15
      };

      const liveViewData: liveViewManager.LiveViewData = {
        primary: primaryData,
        capsule: timerCapsule
      };

      const liveView: liveViewManager.LiveView = {
        id: LIVE_VIEW_ID,
        event: 'TIMER',
        sequence: this.currentSequence,
        isMute: true,
        liveViewData: liveViewData
      };

      const res = await liveViewManager.startLiveView(liveView);
      this.isActive = (res.resultCode === 0);
      hilog.info(DOMAIN, TAG, 'startLiveView executed, result: %{public}d', res.resultCode);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'startLiveView exception: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 更新实况窗进度 (暂停、继续、或切换为 Flow Drift 心流漫游)
   */
  public async updateLiveView(remainingSeconds: number, isPaused: boolean, isFlowDrift: boolean, driftSeconds: number = 0): Promise<void> {
    if (!this.isSupported || !this.isActive) {
      return;
    }

    try {
      this.currentSequence += 1;

      const isCountdown = !isFlowDrift;
      const displaySeconds = isFlowDrift ? driftSeconds : remainingSeconds;
      const driftSuffix = this.getString($r('app.string.liveview_drift_suffix'), 'Flow Drift');
      const displayTitle = isFlowDrift ? `${this.currentTag} · ${driftSuffix}` : this.currentTag;

      let descText = this.getString($r('app.string.liveview_calm_desc'), 'Flow Sanctuary');
      if (isPaused) {
        descText = this.getString($r('app.string.liveview_pause_desc'), 'Paused');
      } else if (isFlowDrift) {
        descText = this.getString($r('app.string.liveview_drift_desc'), 'Flow Drift');
      }

      const timerCapsule: liveViewManager.TimerCapsule = {
        type: liveViewManager.CapsuleType.CAPSULE_TYPE_TIMER,
        status: 1,
        time: displaySeconds * 1000,
        isCountdown: isCountdown,
        isPaused: isPaused,
        content: displayTitle
      };

      const contentItem: liveViewManager.RichText = {
        text: descText
      };

      const primaryData: liveViewManager.PrimaryData = {
        title: displayTitle,
        content: [contentItem],
        keepTime: 15
      };

      const liveViewData: liveViewManager.LiveViewData = {
        primary: primaryData,
        capsule: timerCapsule
      };

      const liveView: liveViewManager.LiveView = {
        id: LIVE_VIEW_ID,
        event: 'TIMER',
        sequence: this.currentSequence,
        isMute: true,
        liveViewData: liveViewData
      };

      await liveViewManager.updateLiveView(liveView);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'updateLiveView exception: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 结束并归档实况窗
   */
  public async stopLiveView(): Promise<void> {
    if (!this.isSupported || !this.isActive) {
      return;
    }

    try {
      this.currentSequence += 1;

      const completedDesc = this.getString($r('app.string.liveview_completed_desc'), 'Session Completed');
      const completedTitle = this.getString($r('app.string.liveview_completed_title'), 'Completed');

      const contentItem: liveViewManager.RichText = {
        text: completedDesc
      };

      const primaryData: liveViewManager.PrimaryData = {
        title: `${this.currentTag} · ${completedTitle}`,
        content: [contentItem],
        keepTime: 5
      };

      const liveViewData: liveViewManager.LiveViewData = {
        primary: primaryData
      };

      const liveView: liveViewManager.LiveView = {
        id: LIVE_VIEW_ID,
        event: 'TIMER',
        sequence: this.currentSequence,
        isMute: true,
        liveViewData: liveViewData
      };

      await liveViewManager.stopLiveView(liveView);
      this.isActive = false;
      hilog.info(DOMAIN, TAG, 'stopLiveView completed');
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'stopLiveView exception: %{public}s', JSON.stringify(err));
      this.isActive = false;
    }
  }
}

export const liveViewHelper = LiveViewHelper.getInstance();
