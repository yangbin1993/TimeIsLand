import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'SettingsManager';
const PREF_NAME = 'timeisland_user_settings';

/**
 * 用户全局偏好配置数据管理器
 */
export class SettingsManager {
  private static instance: SettingsManager | null = null;
  private prefStore: preferences.Preferences | null = null;

  public static getInstance(): SettingsManager {
    if (!SettingsManager.instance) {
      SettingsManager.instance = new SettingsManager();
    }
    return SettingsManager.instance;
  }

  /**
   * 初始化偏好设置并载入 AppStorage
   */
  public async init(context: Context): Promise<void> {
    try {
      this.prefStore = await preferences.getPreferences(context, PREF_NAME);

      const isLiveView = await this.prefStore.get('is_live_view', true) as boolean;
      const isNearlink = await this.prefStore.get('is_nearlink', true) as boolean;
      const isGraceHaven = await this.prefStore.get('is_grace_haven', true) as boolean;
      const graceHavenSecs = await this.prefStore.get('grace_haven_seconds', 120) as number;
      const isZenFlip = await this.prefStore.get('is_zen_flip', true) as boolean;
      const isHaptic = await this.prefStore.get('is_haptic', true) as boolean;
      const isSoundAlert = await this.prefStore.get('is_sound_alert', true) as boolean;
      const isBiometric = await this.prefStore.get('is_biometric_lock', false) as boolean;

      AppStorage.setOrCreate('isLiveViewEnabled', isLiveView);
      AppStorage.setOrCreate('isNearlinkEnabled', isNearlink);
      AppStorage.setOrCreate('isGraceHavenEnabled', isGraceHaven);
      AppStorage.setOrCreate('graceHavenSeconds', graceHavenSecs);
      AppStorage.setOrCreate('isZenFlipEnabled', isZenFlip);
      AppStorage.setOrCreate('isHapticFeedbackEnabled', isHaptic);
      AppStorage.setOrCreate('isSoundAlertEnabled', isSoundAlert);
      AppStorage.setOrCreate('isBiometricEnabled', isBiometric);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to load preferences: %{public}s', JSON.stringify(err));
      // 降级兜底默认值
      AppStorage.setOrCreate('isLiveViewEnabled', true);
      AppStorage.setOrCreate('isNearlinkEnabled', true);
      AppStorage.setOrCreate('isGraceHavenEnabled', true);
      AppStorage.setOrCreate('graceHavenSeconds', 120);
      AppStorage.setOrCreate('isZenFlipEnabled', true);
      AppStorage.setOrCreate('isHapticFeedbackEnabled', true);
      AppStorage.setOrCreate('isSoundAlertEnabled', true);
      AppStorage.setOrCreate('isBiometricEnabled', false);
    }
  }

  /**
   * 写入配置项
   */
  public async setBoolean(key: string, value: boolean, storageKey: string): Promise<void> {
    AppStorage.setOrCreate(storageKey, value);
    if (this.prefStore) {
      try {
        await this.prefStore.put(key, value);
        await this.prefStore.flush();
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'Failed to persist boolean key %{public}s: %{public}s', key, JSON.stringify(err));
      }
    }
  }

  /**
   * 写入数值项
   */
  public async setNumber(key: string, value: number, storageKey: string): Promise<void> {
    AppStorage.setOrCreate(storageKey, value);
    if (this.prefStore) {
      try {
        await this.prefStore.put(key, value);
        await this.prefStore.flush();
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'Failed to persist number key %{public}s: %{public}s', key, JSON.stringify(err));
      }
    }
  }
}

export const settingsManager = SettingsManager.getInstance();
