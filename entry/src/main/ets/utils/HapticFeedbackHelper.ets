import { vibrator } from '@kit.SensorServiceKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'HapticFeedbackHelper';

/**
 * 触感微拟物振动管理器 (HapticFeedbackHelper)
 * 职责: 基于 HarmonyOS NEXT 线性马达 Vibrator API，提供微弱机械滴答与节律性触感微振动反馈
 */
export class HapticFeedbackHelper {
  private static instance: HapticFeedbackHelper | null = null;
  private isSupported: boolean = false;

  private constructor() {
    this.checkCapability();
  }

  public static getInstance(): HapticFeedbackHelper {
    if (!HapticFeedbackHelper.instance) {
      HapticFeedbackHelper.instance = new HapticFeedbackHelper();
    }
    return HapticFeedbackHelper.instance;
  }

  /**
   * 运行时检测设备是否搭载线性振动马达
   */
  private checkCapability(): void {
    try {
      this.isSupported = canIUse('SystemCapability.Sensors.MiscDevice');
      hilog.info(DOMAIN, TAG, 'Vibrator capability support: %{public}s', this.isSupported ? 'true' : 'false');
    } catch (err) {
      this.isSupported = false;
      hilog.warn(DOMAIN, TAG, 'Failed to check vibrator capability: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 触发触感振动 (联动 isHapticFeedbackEnabled 用户配置)
   *
   * @param hapticType 'tick' | 'complete' | 'warning'
   */
  public trigger(hapticType: string = 'tick'): void {
    // 1. 检查用户全局触感开关配置 (AppStorage 响应式状态)
    const isHapticEnabled = AppStorage.get<boolean>('isHapticFeedbackEnabled') ?? true;
    if (!isHapticEnabled) {
      return;
    }

    if (!this.isSupported) {
      return;
    }

    try {
      let durationMs = 20; // 默认极轻微滴答
      if (hapticType === 'complete') {
        durationMs = 60;   // 达成结夏
      } else if (hapticType === 'warning') {
        durationMs = 100;  // 避风港告警或中断
      }

      const effect: vibrator.VibrateTime = {
        type: 'time',
        duration: durationMs
      };

      const attribute: vibrator.VibrateAttribute = {
        usage: 'touch'
      };

      vibrator.startVibration(effect, attribute).catch((err: Object) => {
        hilog.warn(DOMAIN, TAG, 'startVibration promise warning: %{public}s', JSON.stringify(err));
      });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'trigger haptic exception: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 立即停止任何正在进行的振动
   */
  public stop(): void {
    if (!this.isSupported) {
      return;
    }
    try {
      vibrator.stopVibration().catch(() => {});
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'stopVibration exception: %{public}s', JSON.stringify(err));
    }
  }
}

export const hapticFeedbackHelper = HapticFeedbackHelper.getInstance();
