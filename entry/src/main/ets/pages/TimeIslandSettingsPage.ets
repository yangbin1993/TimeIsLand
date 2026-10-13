import { router } from '@kit.ArkUI';
import { common } from '@kit.AbilityKit';
import { DialogHelper, DialogAction } from '@app/common';
import { ThemePalette, ThemeMode } from '../theme/ThemeTypes';
import { themeManager } from '../theme/ThemeManager';
import { settingsManager } from '../data/SettingsManager';
import { ThemeSelectorDialog } from '../components/ThemeSelectorDialog';
import { soundEffectManager, SoundEffectType } from '../utils/SoundEffectManager';
import { biometricAuthManager, BiometricCapability } from '../utils/BiometricAuthManager';
import { FeedbackHelper } from '../utils/FeedbackHelper';
import { accountManager } from '../utils/AccountManager';
import { timeIslandRepository } from '../data/TimeIslandRepository';
import { GUEST_USER_ID } from '../model/UserModel';

/**
 * 路由分发器 Builder 声明
 */
@Builder
export function TimeIslandSettingsBuilder() {
  TimeIslandSettingsPage()
}

/**
 * 时光岛 - 心流与系统生态偏好设置页面 (TimeIslandSettingsPage)
 * 职责: 汇聚 HarmonyOS NEXT 实况窗、星闪近场感知、避风港缓冲、翻转勿扰、触感振动与生境主题配置
 */
@Entry
@Component
struct TimeIslandSettingsPage {
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('bottomNavHeight') bottomNavHeight: number = 0;
  @StorageProp('currentTheme') theme: ThemePalette = themeManager.getPaletteByMode(ThemeMode.DARK);

  // 账号身份状态
  @StorageProp('isLoggedIn') isLoggedIn: boolean = false;
  @StorageProp('currentUserId') currentUserId: string = GUEST_USER_ID;
  @StorageProp('currentUserDisplayName') currentUserDisplayName: string = 'Guest Voyager';
  @State private isLoggingIn: boolean = false;

  // 偏好配置项响应式状态绑定
  @StorageProp('isLiveViewEnabled') isLiveView: boolean = true;
  @StorageProp('isNearlinkEnabled') isNearlink: boolean = true;
  @StorageProp('isGraceHavenEnabled') isGraceHaven: boolean = true;
  @StorageProp('graceHavenSeconds') graceHavenSecs: number = 120;
  @StorageProp('isZenFlipEnabled') isZenFlip: boolean = true;
  @StorageProp('isHapticFeedbackEnabled') isHaptic: boolean = true;
  @StorageProp('isSoundAlertEnabled') isSoundAlert: boolean = true;
  @StorageProp('isBiometricEnabled') isBiometric: boolean = false;

  @State private isThemeDialogOpen: boolean = false;
  @State private biometricCapability: BiometricCapability = {
    isSupported: false,
    hasFingerprint: false,
    hasFace: false,
    hasPin: false
  };

  aboutToAppear(): void {
    this.biometricCapability = biometricAuthManager.checkCapability();
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        // 1. 顶部 Header 导航条 (动态避让状态栏)
        this.buildHeader()

        // 2. 设置项滚动主体视窗
        Scroll() {
          Column({ space: 16 }) {
            // 分组零: 账号与数据归属中心 (华为账号 / 访客数据绑定)
            this.buildAccountGroup()

            // 分组一: HarmonyOS NEXT 生态联动
            this.buildEcosystemGroup()

            // 分组二: 心流专注体验
            this.buildFocusExperienceGroup()

            // 分组三: 心流守护与安全凭据
            this.buildSecurityGroup()

            // 分组四: 触感与声音反馈
            this.buildFeedbackGroup()

            // 分组五: 生境外观与主题
            this.buildThemeGroup()

            // 分组六: 关于时光岛
            this.buildAboutGroup()

            // 底部安全避让垫底
            Blank().height(32 + (this.bottomNavHeight > 0 ? this.bottomNavHeight : 0))
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 20 })
        }
        .scrollBar(BarState.Off)
        .layoutWeight(1)
        .width('100%')
      }
      .width('100%')
      .height('100%')

      // 生境主题流转切换弹窗
      ThemeSelectorDialog({
        visible: this.isThemeDialogOpen,
        onClose: () => {
          this.isThemeDialogOpen = false;
        }
      })
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bgCanvas)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  /**
   * 顶部沉浸式导航栏
   */
  @Builder
  private buildHeader() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Image($r('app.media.ic_arrow_back'))
          .width(18)
          .height(18)
          .fillColor(this.theme.textPrimary)
      }
      .width(36)
      .height(36)
      .backgroundColor(this.theme.surfaceLow)
      .border({ width: 1, color: this.theme.borderSubtle })
      .onClick(() => {
        router.back();
      })

      Text($r('app.string.timeisland_settings_title'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textPrimary)
        .margin({ left: 12 })

      Blank()
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: this.statusBarHeight > 0 ? this.statusBarHeight : 12,
      bottom: 12
    })
  }

  /**
   * 分组零: 账号与数据归属中心 (华为账号 / 访客数据绑定)
   */
  @Builder
  private buildAccountGroup() {
    Column({ space: 12 }) {
      Text($r('app.string.timeisland_settings_group_account'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textSecondary)
        .letterSpacing(1)
        .padding({ left: 4 })

      Column() {
        Row() {
          // 用户头像微视窗
          Stack() {
            Circle({ width: 44, height: 44 })
              .fill(this.isLoggedIn ? this.theme.primaryAccent : this.theme.surfaceLow)
            Image($r('app.media.ic_account'))
              .width(22)
              .height(22)
              .fillColor(this.isLoggedIn ? '#FFFFFF' : this.theme.textSecondary)
          }
          .margin({ right: 14 })

          // 账号名称与状态
          Column({ space: 4 }) {
            Row({ space: 8 }) {
              Text(this.isLoggedIn ? this.currentUserDisplayName : $r('app.string.settings_account_guest_title'))
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.textPrimary)

              // 状态微徽章
              Text(this.isLoggedIn ? $r('app.string.settings_account_status_linked') : $r('app.string.settings_account_status_guest'))
                .fontSize(10)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.isLoggedIn ? this.theme.primaryAccent : this.theme.textMuted)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor(this.isLoggedIn ? this.theme.surfaceLow : this.theme.surfaceCard)
                .borderRadius(6)
                .border({ width: 1, color: this.isLoggedIn ? this.theme.primaryAccent : this.theme.borderSubtle })
            }
            .alignItems(VerticalAlign.Center)

            if (this.isLoggedIn) {
              Row({ space: 2 }) {
                Text($r('app.string.settings_account_uid_prefix'))
                  .fontSize(11)
                  .fontColor(this.theme.textMuted)
                Text(this.currentUserId.length > 14 ? this.currentUserId.slice(0, 10) + '...' : this.currentUserId)
                  .fontSize(11)
                  .fontColor(this.theme.textSecondary)
              }
            } else {
              Text($r('app.string.settings_account_guest_desc'))
                .fontSize(11)
                .fontColor(this.theme.textMuted)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ right: 8 })

          // 交互按钮
          if (!this.isLoggedIn) {
            Button({ type: ButtonType.Capsule, stateEffect: true }) {
              Row({ space: 4 }) {
                if (this.isLoggingIn) {
                  LoadingProgress()
                    .width(14)
                    .height(14)
                    .color('#FFFFFF')
                }
                Text($r('app.string.settings_account_btn_login'))
                  .fontSize(12)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#FFFFFF')
              }
            }
            .height(32)
            .backgroundColor(this.theme.primaryAccent)
            .padding({ left: 12, right: 12 })
            .enabled(!this.isLoggingIn)
            .onClick(() => {
              soundEffectManager.play(SoundEffectType.PEN_CLICK);
              this.handleHuaweiLogin();
            })
          } else {
            Button({ type: ButtonType.Capsule, stateEffect: true }) {
              Text($r('app.string.settings_account_btn_logout'))
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.textSecondary)
            }
            .height(32)
            .backgroundColor(this.theme.surfaceLow)
            .border({ width: 1, color: this.theme.borderSubtle })
            .padding({ left: 12, right: 12 })
            .onClick(() => {
              soundEffectManager.play(SoundEffectType.SWITCH_CLOSE);
              this.handleLogout();
            })
          }
        }
        .width('100%')
        .padding(16)
      }
      .backgroundColor(this.theme.surfaceCard)
      .borderRadius(16)
      .border({ width: 1, color: this.theme.borderCard })
      .shadow({ radius: 12, color: this.theme.shadowCard, offsetY: 2 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 调起华为账号系统级登录授权
   */
  private async handleHuaweiLogin(): Promise<void> {
    if (this.isLoggingIn) {
      return;
    }
    this.isLoggingIn = true;
    try {
      const user = await accountManager.loginWithHuaweiID(getContext(this) as common.UIAbilityContext);
      DialogHelper.showToast($r('app.string.settings_account_login_success'));

      // 检查是否存在待合并的本地访客历史专注记录
      const guestRecordsCount = await timeIslandRepository.countGuestRecords();
      if (guestRecordsCount > 0) {
        const resMgr = getContext(this).resourceManager;
        const res = await DialogHelper.showDialog({
          title: resMgr.getStringSync($r('app.string.settings_account_merge_title').id),
          message: resMgr.getStringSync($r('app.string.settings_account_merge_message').id),
          confirmText: resMgr.getStringSync($r('app.string.settings_account_merge_confirm').id),
          cancelText: resMgr.getStringSync($r('app.string.settings_account_merge_skip').id)
        });
        if (res.action === DialogAction.CONFIRM) {
          await timeIslandRepository.migrateGuestDataToUser(user.userId);
          DialogHelper.showToast($r('app.string.settings_account_merge_success'));
        }
      }
    } catch (err) {
      DialogHelper.showToast($r('app.string.settings_account_login_failed'));
    } finally {
      this.isLoggingIn = false;
    }
  }

  /**
   * 退出当前账号，切回本地访客态
   */
  private async handleLogout(): Promise<void> {
    await accountManager.logout();
    DialogHelper.showToast($r('app.string.settings_account_logout_success'));
  }

  /**
   * 分组一: HarmonyOS NEXT 生态联动
   */
  @Builder
  private buildEcosystemGroup() {
    Column({ space: 12 }) {
      Text($r('app.string.timeisland_settings_group_ecosystem'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textSecondary)
        .margin({ left: 4 })

      Column({ space: 0 }) {
        // 1. 实况窗水滴胶囊开关
        this.buildSwitchItem(
          $r('app.string.timeisland_settings_live_view'),
          $r('app.string.timeisland_settings_live_view_desc'),
          this.isLiveView,
          (val: boolean) => {
            settingsManager.setBoolean('is_live_view', val, 'isLiveViewEnabled');
          },
          true
        )

        // 2. NearLink 星闪近场感应开关
        this.buildSwitchItem(
          $r('app.string.timeisland_settings_nearlink'),
          $r('app.string.timeisland_settings_nearlink_desc'),
          this.isNearlink,
          (val: boolean) => {
            settingsManager.setBoolean('is_nearlink', val, 'isNearlinkEnabled');
          },
          false
        )
      }
      .backgroundColor(this.theme.surfaceCard)
      .borderRadius(16)
      .border({ width: 1, color: this.theme.borderCard })
      .shadow({ radius: 12, color: this.theme.shadowCard, offsetY: 2 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 分组二: 心流专注体验
   */
  @Builder
  private buildFocusExperienceGroup() {
    Column({ space: 12 }) {
      Text($r('app.string.timeisland_settings_group_focus'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textSecondary)
        .margin({ left: 4 })

      Column({ space: 0 }) {
        // 1. 避风港守护开关
        this.buildSwitchItem(
          $r('app.string.timeisland_settings_grace_haven'),
          $r('app.string.timeisland_settings_grace_haven_desc'),
          this.isGraceHaven,
          (val: boolean) => {
            settingsManager.setBoolean('is_grace_haven', val, 'isGraceHavenEnabled');
          },
          true
        )

        // 2. 避风港缓冲时长调节
        Row() {
          Column({ space: 3 }) {
            Text($r('app.string.timeisland_settings_grace_haven_duration'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textPrimary)
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Row({ space: 6 }) {
            ForEach([60, 120, 180], (secs: number) => {
              Button(`${secs}s`, { type: ButtonType.Capsule, stateEffect: true })
                .fontSize(11)
                .fontWeight(this.graceHavenSecs === secs ? FontWeight.Bold : FontWeight.Normal)
                .fontColor(this.graceHavenSecs === secs ? this.theme.textPrimary : this.theme.textSecondary)
                .backgroundColor(this.graceHavenSecs === secs ? this.theme.primaryAccent : this.theme.surfaceLow)
                .border({
                  width: 1,
                  color: this.graceHavenSecs === secs ? this.theme.primaryAccentGlow : this.theme.borderSubtle
                })
                .height(28)
                .padding({ left: 10, right: 10 })
                .onClick(() => {
                  soundEffectManager.play(SoundEffectType.PEN_CLICK);
                  settingsManager.setNumber('grace_haven_seconds', secs, 'graceHavenSeconds');
                })
            }, (secs: number) => secs.toString())
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .border({ width: { bottom: 1 }, color: this.theme.borderSubtle })

        // 3. 翻转勿扰自动感应
        this.buildSwitchItem(
          $r('app.string.timeisland_settings_zen_flip'),
          $r('app.string.timeisland_settings_zen_flip_desc'),
          this.isZenFlip,
          (val: boolean) => {
            settingsManager.setBoolean('is_zen_flip', val, 'isZenFlipEnabled');
          },
          false
        )
      }
      .backgroundColor(this.theme.surfaceCard)
      .borderRadius(16)
      .border({ width: 1, color: this.theme.borderCard })
      .shadow({ radius: 12, color: this.theme.shadowCard, offsetY: 2 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 分组三: 心流守护与安全凭据 (生物特征解锁)
   */
  @Builder
  private buildSecurityGroup() {
    Column({ space: 12 }) {
      Text($r('app.string.timeisland_settings_group_security'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textSecondary)
        .margin({ left: 4 })

      Column({ space: 0 }) {
        // 1. 生物特征心流锁主开关行
        Row() {
          Column({ space: 3 }) {
            Text($r('app.string.timeisland_settings_biometric_lock'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textPrimary)
            Text($r('app.string.timeisland_settings_biometric_lock_desc'))
              .fontSize(11)
              .fontColor(this.theme.textMuted)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ right: 12 })

          Toggle({ type: ToggleType.Switch, isOn: this.isBiometric })
            .selectedColor(this.theme.primaryAccent)
            .switchPointColor(this.theme.textPrimary)
            .onChange((val: boolean) => {
              this.handleBiometricToggle(val);
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .border({ width: { bottom: 1 }, color: this.theme.borderSubtle })

        // 2. 生物特征硬件与系统凭据就绪详情微晶卡片
        Column({ space: 10 }) {
          Row() {
            Image($r('app.media.ic_shield_check'))
              .width(14)
              .height(14)
              .fillColor(this.isBiometric ? this.theme.primaryAccent : this.theme.textMuted)

            Text($r('app.string.timeisland_settings_biometric_details'))
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.isBiometric ? this.theme.primaryAccent : this.theme.textSecondary)
              .margin({ left: 6 })

            Blank()

            Text(this.biometricCapability.isSupported ? $r('app.string.timeisland_settings_biometric_status_supported') : $r('app.string.timeisland_settings_biometric_status_unsupported'))
              .fontSize(10)
              .fontColor(this.biometricCapability.isSupported ? this.theme.primaryAccent : this.theme.textMuted)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(this.biometricCapability.isSupported ? this.theme.primaryAccentBg : this.theme.surfaceLow)
              .borderRadius(6)
          }
          .width('100%')

          // 三项安全能力阵列 (指纹 / 面容 / 锁屏凭据)
          Row({ space: 8 }) {
            this.buildCredentialPill(
              $r('app.string.timeisland_settings_biometric_fingerprint'),
              this.biometricCapability.hasFingerprint
            )

            this.buildCredentialPill(
              $r('app.string.timeisland_settings_biometric_face'),
              this.biometricCapability.hasFace
            )

            this.buildCredentialPill(
              $r('app.string.timeisland_settings_biometric_pin'),
              this.biometricCapability.hasPin
            )
          }
          .width('100%')

          // 生效场景防护说明标签
          if (this.isBiometric) {
            Row({ space: 6 }) {
              Text($r('app.string.timeisland_settings_biometric_scope_quit'))
                .fontSize(9)
                .fontColor(this.theme.textSecondary)
                .padding({ left: 6, right: 6, top: 3, bottom: 3 })
                .backgroundColor(this.theme.surfaceLow)
                .borderRadius(4)

              Text($r('app.string.timeisland_settings_biometric_scope_stats'))
                .fontSize(9)
                .fontColor(this.theme.textSecondary)
                .padding({ left: 6, right: 6, top: 3, bottom: 3 })
                .backgroundColor(this.theme.surfaceLow)
                .borderRadius(4)
            }
            .width('100%')
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 12 })
        .backgroundColor(this.theme.surfaceLowest)
      }
      .backgroundColor(this.theme.surfaceCard)
      .borderRadius(16)
      .border({ width: 1, color: this.theme.borderCard })
      .shadow({ radius: 12, color: this.theme.shadowCard, offsetY: 2 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 凭据能力状态胶囊
   */
  @Builder
  private buildCredentialPill(name: Resource, isReady: boolean) {
    Row({ space: 4 }) {
      Row()
        .width(5)
        .height(5)
        .borderRadius(2.5)
        .backgroundColor(isReady ? this.theme.primaryAccent : '#64748b')

      Text(name)
        .fontSize(10)
        .fontColor(isReady ? this.theme.textPrimary : this.theme.textMuted)

      Text(isReady ? $r('app.string.timeisland_settings_biometric_status_supported') : $r('app.string.timeisland_settings_biometric_status_unsupported'))
        .fontSize(8)
        .fontColor(isReady ? this.theme.primaryAccent : this.theme.textMuted)
    }
    .layoutWeight(1)
    .padding({ left: 6, right: 6, top: 5, bottom: 5 })
    .backgroundColor(this.theme.surfaceCard)
    .borderRadius(8)
    .border({ width: 1, color: isReady ? this.theme.borderSubtle : '#00000000' })
  }

  /**
   * 生物特征锁 Switch 开关变更处理 (防破防双向身份鉴权)
   */
  private async handleBiometricToggle(val: boolean): Promise<void> {
    if (val === this.isBiometric) {
      return;
    }

    if (val) {
      this.biometricCapability = biometricAuthManager.checkCapability();
      if (!this.biometricCapability.isSupported) {
        soundEffectManager.play(SoundEffectType.SWITCH_CLOSE);
        DialogHelper.showToast($r('app.string.timeisland_toast_biometric_no_credentials'));
        AppStorage.setOrCreate('isBiometricEnabled', false);
        return;
      }

      const verifyTitle = getContext(this).resourceManager.getStringSync($r('app.string.timeisland_settings_biometric_verify_title'));
      const isSuccess = await biometricAuthManager.authenticate(verifyTitle);
      if (isSuccess) {
        soundEffectManager.play(SoundEffectType.SWITCH_OPEN);
        settingsManager.setBoolean('is_biometric_lock', true, 'isBiometricEnabled');
        DialogHelper.showToast($r('app.string.timeisland_toast_biometric_enabled'));
      } else {
        soundEffectManager.play(SoundEffectType.SWITCH_CLOSE);
        DialogHelper.showToast($r('app.string.timeisland_toast_biometric_failed'));
        AppStorage.setOrCreate('isBiometricEnabled', false);
      }
    } else {
      const verifyTitle = getContext(this).resourceManager.getStringSync($r('app.string.timeisland_settings_biometric_verify_close_title'));
      const isSuccess = await biometricAuthManager.authenticate(verifyTitle);
      if (isSuccess) {
        soundEffectManager.play(SoundEffectType.SWITCH_CLOSE);
        settingsManager.setBoolean('is_biometric_lock', false, 'isBiometricEnabled');
        DialogHelper.showToast($r('app.string.timeisland_toast_biometric_disabled'));
      } else {
        soundEffectManager.play(SoundEffectType.SWITCH_OPEN);
        DialogHelper.showToast($r('app.string.timeisland_toast_biometric_failed'));
        AppStorage.setOrCreate('isBiometricEnabled', true);
      }
    }
  }

  /**
   * 分组四: 触感与声音反馈
   */
  @Builder
  private buildFeedbackGroup() {
    Column({ space: 12 }) {
      Text($r('app.string.timeisland_settings_group_feedback'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textSecondary)
        .margin({ left: 4 })

      Column({ space: 0 }) {
        // 1. 触觉线性马达振感
        this.buildSwitchItem(
          $r('app.string.timeisland_settings_haptic'),
          $r('app.string.timeisland_settings_haptic_desc'),
          this.isHaptic,
          (val: boolean) => {
            settingsManager.setBoolean('is_haptic', val, 'isHapticFeedbackEnabled');
          },
          true
        )

        // 2. 禅意编钟落音提醒
        this.buildSwitchItem(
          $r('app.string.timeisland_settings_bell'),
          $r('app.string.timeisland_settings_bell_desc'),
          this.isSoundAlert,
          (val: boolean) => {
            settingsManager.setBoolean('is_sound_alert', val, 'isSoundAlertEnabled');
          },
          false
        )
      }
      .backgroundColor(this.theme.surfaceCard)
      .borderRadius(16)
      .border({ width: 1, color: this.theme.borderCard })
      .shadow({ radius: 12, color: this.theme.shadowCard, offsetY: 2 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 分组四: 生境外观与主题
   */
  @Builder
  private buildThemeGroup() {
    Column({ space: 12 }) {
      Text($r('app.string.timeisland_settings_group_theme'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textSecondary)
        .margin({ left: 4 })

      Row() {
        Column({ space: 3 }) {
          Text($r('app.string.timeisland_settings_current_theme'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(this.theme.textPrimary)
          Text($r('app.string.timeisland_theme_title'))
            .fontSize(11)
            .fontColor(this.theme.textMuted)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Row({ space: 6 }) {
          Circle()
            .width(14)
            .height(14)
            .fill(this.theme.primaryAccent)
            .shadow({ radius: 6, color: this.theme.primaryGlow, offsetY: 0 })

          Image($r('app.media.ic_palette'))
            .width(18)
            .height(18)
            .fillColor(this.theme.primaryAccent)
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .backgroundColor(this.theme.surfaceCard)
      .borderRadius(16)
      .border({ width: 1, color: this.theme.borderCard })
      .shadow({ radius: 12, color: this.theme.shadowCard, offsetY: 2 })
      .onClick(() => {
        this.isThemeDialogOpen = true;
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 分组六: 关于时光岛
   */
  @Builder
  private buildAboutGroup() {
    Column({ space: 12 }) {
      Text($r('app.string.timeisland_settings_group_about'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textSecondary)
        .margin({ left: 4 })

      Column({ space: 0 }) {
        // 1. 应用品牌信息
        Row() {
          Row({ space: 12 }) {
            Image($r('app.media.startIcon'))
              .width(40)
              .height(40)
              .borderRadius(20)

            Column({ space: 3 }) {
              Text($r('app.string.app_name'))
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.textPrimary)
              Text($r('app.string.timeisland_settings_app_desc'))
                .fontSize(11)
                .fontColor(this.theme.textMuted)
            }
            .alignItems(HorizontalAlign.Start)
          }

          Blank()

          Text('v1.0.0')
            .fontSize(12)
            .fontColor(this.theme.textSecondary)
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor(this.theme.surfaceLow)
            .borderRadius(10)
        }
        .width('100%')
        .padding(16)
        .border({ width: { bottom: 1 }, color: this.theme.borderSubtle })

        // 2. 意见与灵感反馈入口 (Task 2.4 原生邮件直投/剪贴板平滑降级)
        Row() {
          Column({ space: 3 }) {
            Text($r('app.string.timeisland_settings_feedback_title'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textPrimary)
            Text($r('app.string.timeisland_settings_feedback_desc'))
              .fontSize(11)
              .fontColor(this.theme.textMuted)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ right: 12 })

          Button({ type: ButtonType.Circle, stateEffect: true }) {
            Image($r('app.media.ic_arrow_back'))
              .width(16)
              .height(16)
              .fillColor(this.theme.textSecondary)
              .rotate({ angle: 180 })
          }
          .width(32)
          .height(32)
          .backgroundColor(this.theme.surfaceLow)
          .onClick(() => {
            soundEffectManager.play(SoundEffectType.PEN_CLICK);
            FeedbackHelper.sendFeedback(getContext(this) as common.UIAbilityContext);
          })
        }
        .width('100%')
        .padding(16)
        .onClick(() => {
          soundEffectManager.play(SoundEffectType.PEN_CLICK);
          FeedbackHelper.sendFeedback(getContext(this) as common.UIAbilityContext);
        })
      }
      .backgroundColor(this.theme.surfaceCard)
      .borderRadius(16)
      .border({ width: 1, color: this.theme.borderCard })
      .shadow({ radius: 12, color: this.theme.shadowCard, offsetY: 2 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 通用 Switch 设置行抽取组件
   */
  @Builder
  private buildSwitchItem(
    title: Resource,
    desc: Resource,
    isOn: boolean,
    onChange: (val: boolean) => void,
    hasDivider: boolean
  ) {
    Row() {
      Column({ space: 3 }) {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textPrimary)
        Text(desc)
          .fontSize(11)
          .fontColor(this.theme.textMuted)
          .maxLines(2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .margin({ right: 12 })

      Toggle({ type: ToggleType.Switch, isOn: isOn })
        .selectedColor(this.theme.primaryAccent)
        .switchPointColor(this.theme.textPrimary)
        .onChange((val: boolean) => {
          val ? soundEffectManager.play(SoundEffectType.SWITCH_OPEN) : soundEffectManager.play(SoundEffectType.SWITCH_CLOSE);
          onChange(val);
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 14, bottom: 14 })
    .border(hasDivider ? { width: { bottom: 1 }, color: this.theme.borderSubtle } : {})
  }
}

/**
 * 偏好设置独立预览组件
 */
@Preview
@Component
struct TimeIslandSettingsPagePreview {
  build() {
    TimeIslandSettingsPage()
  }
}
