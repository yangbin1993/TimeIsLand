import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { DialogHelper, DialogAction, DialogType } from '@app/common';
import { ThemePalette, ThemeMode } from '../theme/ThemeTypes';
import { themeManager } from '../theme/ThemeManager';
import { settingsManager } from '../data/SettingsManager';
import { ThemeSelectorDialog } from '../components/ThemeSelectorDialog';
import { soundEffectManager, SoundEffectType } from '../utils/SoundEffectManager';
import { biometricAuthManager, BiometricCapability, BiometricModeType, CredentialChainNode } from '../utils/BiometricAuthManager';
import { FeedbackHelper } from '../utils/FeedbackHelper';
import { accountManager } from '../utils/AccountManager';
import { timeIslandRepository } from '../data/TimeIslandRepository';
import { GUEST_USER_ID } from '../model/UserModel';
import { hapticFeedbackHelper } from '../utils/HapticFeedbackHelper';
import { LegalNoticeDialog, LegalNoticeType } from '../components/LegalNoticeDialog';
import { DataRestoreDialog } from '../components/DataRestoreDialog';
import { calendarSyncManager } from '../utils/CalendarSyncManager';
import { nearLinkSanctuaryManager } from '../utils/NearLinkSanctuaryManager';

const DOMAIN = 0x0000;
const TAG = 'TimeIslandSettings';

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
  @StorageProp('isCloudSyncEnabled') isCloudSync: boolean = true;
  @StorageProp('isWidgetSyncEnabled') isWidgetSync: boolean = true;
  @StorageProp('isCardAutoNoiseEnabled') isCardAutoNoise: boolean = true;
  @StorageProp('isSolarTermNoticeEnabled') isSolarTermNotice: boolean = true;
  @StorageProp('isCalendarSyncEnabled') isCalendarSync: boolean = true;

  @State private isThemeDialogOpen: boolean = false;
  @State private isLegalDialogOpen: boolean = false;
  @State private activeLegalType: LegalNoticeType = LegalNoticeType.PRIVACY;
  @State private localRecordCount: number = 0;
  @State private isRestoreDialogOpen: boolean = false;
  @State private biometricCapability: BiometricCapability = {
    isSupported: false,
    hasFingerprint: false,
    hasFace: false,
    hasPin: false,
    primaryMode: BiometricModeType.NONE,
    chainNodes: []
  };

  aboutToAppear(): void {
    this.biometricCapability = biometricAuthManager.checkCapability();
    this.loadRecordCount();
  }

  private async loadRecordCount(): Promise<void> {
    try {
      this.localRecordCount = await timeIslandRepository.getTotalRecordCount();
    } catch (_err) {
      this.localRecordCount = 0;
    }
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

            // 分组一: 生境外观与心流气韵 (主页生境入口深度整合归集)
            this.buildThemeGroup()

            // 分组二: HarmonyOS NEXT 生态联动
            this.buildEcosystemGroup()

            // 分组三: 心流专注体验
            this.buildFocusExperienceGroup()

            // 分组四: 心流守护与安全凭据
            this.buildSecurityGroup()

            // 分组五: 触感与声音反馈
            this.buildFeedbackGroup()

            // 分组五点五: 数据管理与存储 (闭环隐私承诺与数据自主权)
            this.buildDataManagementGroup()

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
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 生境主题流转切换弹窗
      ThemeSelectorDialog({
        visible: this.isThemeDialogOpen,
        onClose: () => {
          this.isThemeDialogOpen = false;
        }
      })
      .width('100%')
      .height(this.isThemeDialogOpen ? '100%' : 0)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 华为应用市场合规套件: 法务与隐私保护政策弹窗
      LegalNoticeDialog({
        visible: this.isLegalDialogOpen,
        activeType: this.activeLegalType,
        onClose: () => {
          this.isLegalDialogOpen = false;
        }
      })
      .width('100%')
      .height(this.isLegalDialogOpen ? '100%' : 0)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])

      // 数据导入恢复弹窗
      DataRestoreDialog({
        visible: this.isRestoreDialogOpen,
        onClose: () => {
          this.isRestoreDialogOpen = false;
        },
        onRestoreSuccess: (_imported: number, _skipped: number) => {
          this.loadRecordCount();
        }
      })
      .width('100%')
      .height(this.isRestoreDialogOpen ? '100%' : 0)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Image($r('app.media.ic_arrow_back'))
          .width(20)
          .height(20)
          .fillColor(this.theme.textPrimary)
      }
      .width(36)
      .height(36)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        try {
          this.getUIContext().getRouter().back();
        } catch (err) {
          hilog.error(DOMAIN, TAG, 'Failed to navigate back: %{public}s', JSON.stringify(err));
        }
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
      top: (this.statusBarHeight > 0 ? this.statusBarHeight : 0) + 12,
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

      Column({ space: 14 }) {
        // 1. 用户身份基础信息行
        Row() {
          // 用户头像微视窗
          Stack() {
            Row()
              .width(44)
              .height(44)
              .borderRadius(22)
              .backgroundColor(this.isLoggedIn ? this.theme.primaryAccent : this.theme.surfaceLow)
            Image($r('app.media.ic_account'))
              .width(22)
              .height(22)
              .fillColor(this.isLoggedIn ? this.theme.textInverse : this.theme.textSecondary)
          }
          .margin({ right: 14 })

          // 账号名称与状态徽章
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
                .backgroundColor(this.isLoggedIn ? this.theme.surfaceLow : this.theme.surfaceLowest)
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
                .lineHeight(16)
            }
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          // 已登录态下的退出登录按钮 (紧凑放置在右上角)
          if (this.isLoggedIn) {
            Button({ type: ButtonType.Capsule, stateEffect: true }) {
              Text($r('app.string.settings_account_btn_logout'))
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.textSecondary)
            }
            .height(30)
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
        .alignItems(VerticalAlign.Center)

        // 2. 未登录态下的独立醒目行动按钮 (整行舒展，彻底消除横向挤压与遮挡)
        if (!this.isLoggedIn) {
          Button({ type: ButtonType.Capsule, stateEffect: true }) {
            Row({ space: 6 }) {
              if (this.isLoggingIn) {
                LoadingProgress()
                  .width(16)
                  .height(16)
                  .color(this.theme.textInverse)
              }
              Text($r('app.string.settings_account_btn_login'))
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.textInverse)
            }
            .width('100%')
            .justifyContent(FlexAlign.Center)
          }
          .width('100%')
          .height(36)
          .backgroundColor(this.theme.primaryAccent)
          .shadow({ radius: 8, color: this.theme.primaryAccentGlow, offsetY: 2 })
          .enabled(!this.isLoggingIn)
          .onClick(() => {
            soundEffectManager.play(SoundEffectType.PEN_CLICK);
            this.handleHuaweiLogin();
          })
        }
      }
      .width('100%')
      .padding(16)
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
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const user = await accountManager.loginWithHuaweiID(context);
      DialogHelper.showToast($r('app.string.settings_account_login_success'));

      // 检查是否存在待合并的本地访客历史专注记录
      const guestRecordsCount = await timeIslandRepository.countGuestRecords();
      if (guestRecordsCount > 0) {
        const resMgr = context.resourceManager;
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
          async (val: boolean) => {
            if (val && nearLinkSanctuaryManager.isHardwareSupported()) {
              const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
              const granted = await nearLinkSanctuaryManager.requestNearLinkPermission(context);
              if (granted) {
                settingsManager.setBoolean('is_nearlink', true, 'isNearlinkEnabled');
              } else {
                AppStorage.setOrCreate('isNearlinkEnabled', false);
              }
            } else {
              settingsManager.setBoolean('is_nearlink', val, 'isNearlinkEnabled');
            }
          },
          true
        )

        // 3. 桌面卡片万物互联协同
        this.buildSwitchItem(
          $r('app.string.settings_widget_sync'),
          $r('app.string.settings_widget_sync_desc'),
          this.isWidgetSync,
          (val: boolean) => {
            settingsManager.setBoolean('is_widget_sync', val, 'isWidgetSyncEnabled');
          },
          true
        )

        // 4. 卡片起航伴随自然白噪音
        this.buildSwitchItem(
          $r('app.string.settings_card_auto_noise'),
          $r('app.string.settings_card_auto_noise_desc'),
          this.isCardAutoNoise,
          (val: boolean) => {
            settingsManager.setBoolean('is_card_auto_noise', val, 'isCardAutoNoiseEnabled');
          },
          true
        )

        // 5. 二十四节气岁时物候提醒
        this.buildSwitchItem(
          $r('app.string.settings_solar_term_notice'),
          $r('app.string.settings_solar_term_notice_desc'),
          this.isSolarTermNotice,
          (val: boolean) => {
            settingsManager.setBoolean('is_solar_term_notice', val, 'isSolarTermNoticeEnabled');
          },
          true
        )

        // 6. 系统日历心流日程同步
        this.buildSwitchItem(
          $r('app.string.settings_calendar_sync'),
          $r('app.string.settings_calendar_sync_desc'),
          this.isCalendarSync,
          async (val: boolean) => {
            if (val) {
              const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
              const granted = await calendarSyncManager.requestPermission(context);
              if (granted) {
                settingsManager.setBoolean('is_calendar_sync', true, 'isCalendarSyncEnabled');
              } else {
                DialogHelper.showToast($r('app.string.settings_calendar_permission_denied'));
                AppStorage.setOrCreate('isCalendarSyncEnabled', false);
              }
            } else {
              settingsManager.setBoolean('is_calendar_sync', false, 'isCalendarSyncEnabled');
            }
          },
          true
        )

        // 7. 将历史记录同步至系统日历
        this.buildActionItem(
          $r('app.string.settings_calendar_export'),
          $r('app.string.settings_calendar_export_desc'),
          () => {
            this.handleExportAllToCalendar();
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
            Row({ space: 6 }) {
              Text($r('app.string.timeisland_settings_biometric_lock'))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.textPrimary)

              if (!this.biometricCapability.isSupported) {
                Text($r('app.string.timeisland_settings_biometric_status_unsupported'))
                  .fontSize(9)
                  .fontColor(this.theme.textMuted)
                  .padding({ left: 5, right: 5, top: 1, bottom: 1 })
                  .backgroundColor(this.theme.surfaceLow)
                  .borderRadius(4)
              }
            }

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
        .border({ width: { bottom: this.isBiometric ? 1 : 0 }, color: this.theme.borderSubtle })

        // 2. 仅在开关开启后展开：生物特征硬件与系统凭据智能降级链路微晶卡片
        if (this.isBiometric) {
          Column({ space: 10 }) {
            Row() {
              Image($r('app.media.ic_shield_check'))
                .width(14)
                .height(14)
                .fillColor(this.theme.primaryAccent)

              Text($r('app.string.timeisland_settings_biometric_chain_title'))
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.primaryAccent)
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

            // 3. 智能降级链条节点流程 (首选 -> 降级 -> 兜底)
            if (this.biometricCapability.chainNodes.length > 0) {
              Row({ space: 4 }) {
                ForEach(this.biometricCapability.chainNodes, (node: CredentialChainNode, index: number) => {
                  this.buildChainNodePill(node)

                  if (index < this.biometricCapability.chainNodes.length - 1) {
                    Text('→')
                      .fontSize(10)
                      .fontColor(this.theme.textMuted)
                      .width(12)
                      .textAlign(TextAlign.Center)
                  }
                }, (node: CredentialChainNode) => node.type)
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
            } else {
              Text($r('app.string.timeisland_settings_biometric_none_desc'))
                .fontSize(10)
                .fontColor(this.theme.textMuted)
                .padding({ top: 2, bottom: 2 })
            }

            // 4. 降级机制安全与生态底座说明
            Text($r('app.string.timeisland_settings_biometric_chain_desc'))
              .fontSize(10)
              .fontColor(this.theme.textMuted)
              .lineHeight(14)

            // 5. 生效场景防护说明标签
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
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 12 })
          .backgroundColor(this.theme.surfaceLowest)
        }
      }
      .backgroundColor(this.theme.surfaceCard)
      .borderRadius(16)
      .border({ width: 1, color: this.theme.borderCard })
      .shadow({ radius: 12, color: this.theme.shadowCard, offsetY: 2 })
      .animation({ duration: 250, curve: Curve.FastOutSlowIn })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 凭据降级链路节点胶囊
   */
  @Builder
  private buildChainNodePill(node: CredentialChainNode) {
    Row({ space: 4 }) {
      Row()
        .width(5)
        .height(5)
        .borderRadius(2.5)
        .backgroundColor(node.isPrimary ? this.theme.primaryAccent : this.theme.textMuted)

      Text(node.nameRes)
        .fontSize(10)
        .fontWeight(node.isPrimary ? FontWeight.Medium : FontWeight.Normal)
        .fontColor(node.isPrimary ? this.theme.textPrimary : this.theme.textSecondary)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })

      Text(node.badgeRes)
        .fontSize(8)
        .fontColor(node.isPrimary ? this.theme.primaryAccent : this.theme.textMuted)
        .padding({ left: 4, right: 4, top: 1, bottom: 1 })
        .backgroundColor(node.isPrimary ? this.theme.primaryAccentBg : this.theme.surfaceLow)
        .borderRadius(4)
    }
    .layoutWeight(1)
    .padding({ left: 4, right: 4, top: 6, bottom: 6 })
    .justifyContent(FlexAlign.Center)
    .backgroundColor(this.theme.surfaceCard)
    .borderRadius(8)
    .border({ width: 1, color: node.isPrimary ? this.theme.borderSubtle : Color.Transparent })
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

      let verifyTitle: string = 'Verify Identity';
      try {
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        verifyTitle = context.resourceManager.getStringSync($r('app.string.timeisland_settings_biometric_verify_title').id);
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'Failed to resolve biometric verify title: %{public}s', JSON.stringify(err));
      }

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
      let verifyTitle: string = 'Verify Identity to Close';
      try {
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        verifyTitle = context.resourceManager.getStringSync($r('app.string.timeisland_settings_biometric_verify_close_title').id);
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'Failed to resolve biometric verify close title: %{public}s', JSON.stringify(err));
      }

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
        .letterSpacing(1)
        .margin({ left: 4 })

      Row() {
        Column({ space: 4 }) {
          Row({ space: 6 }) {
            Text($r('app.string.timeisland_settings_current_theme'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textPrimary)

            Text($r('app.string.timeisland_theme_badge'))
              .fontSize(10)
              .fontColor(this.theme.primaryAccent)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(this.theme.primaryAccentBg)
              .borderRadius(6)
          }

          Text($r('app.string.timeisland_theme_preview_subtitle'))
            .fontSize(11)
            .fontColor(this.theme.textMuted)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .margin({ right: 12 })

        Row({ space: 8 }) {
          // 四色生境微晶色彩原石
          Row({ space: 4 }) {
            Row().width(7).height(7).borderRadius(3.5).backgroundColor($r('app.color.timeisland_gem_green'))
            Row().width(7).height(7).borderRadius(3.5).backgroundColor($r('app.color.timeisland_gem_blue'))
            Row().width(7).height(7).borderRadius(3.5).backgroundColor($r('app.color.timeisland_gem_amber'))
            Row().width(7).height(7).borderRadius(3.5).backgroundColor($r('app.color.timeisland_gem_purple'))
          }
          .padding({ left: 6, right: 6, top: 4, bottom: 4 })
          .backgroundColor(this.theme.surfaceLowest)
          .borderRadius(8)

          Image($r('app.media.ic_palette'))
            .width(18)
            .height(18)
            .fillColor(this.theme.primaryAccent)

          Image($r('app.media.ic_arrow_back'))
            .width(12)
            .height(12)
            .fillColor(this.theme.textMuted)
            .rotate({ angle: 180 })
        }
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .backgroundColor(this.theme.surfaceCard)
      .borderRadius(16)
      .border({ width: 1, color: this.theme.borderCard })
      .shadow({ radius: 12, color: this.theme.shadowCard, offsetY: 2 })
      .clip(true)
      .onClick(() => {
        soundEffectManager.play(SoundEffectType.BUBBLE);
        this.isThemeDialogOpen = true;
      })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }

  /**
   * 分组五点五: 数据管理与存储 (闭环隐私承诺与数据自主权)
   */
  @Builder
  private buildDataManagementGroup() {
    Column({ space: 12 }) {
      Text($r('app.string.settings_group_data_management'))
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textSecondary)
        .margin({ left: 4 })

      Column({ space: 0 }) {
        // 1. 本地存储概览行
        Row() {
          Column({ space: 3 }) {
            Text($r('app.string.settings_data_storage_title'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textPrimary)

            Text(this.localRecordCount > 0 ?
              $r('app.string.settings_data_storage_count_desc', this.localRecordCount) :
              $r('app.string.settings_data_storage_empty'))
              .fontSize(11)
              .fontColor(this.theme.textMuted)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)

          Text(`${this.localRecordCount}`)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.primaryAccent)
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor(this.theme.primaryAccentBg)
            .borderRadius(8)
        }
        .width('100%')
        .padding(16)
        .border({ width: { bottom: 1 }, color: this.theme.borderSubtle })

        // 2. 华为云空间端云同步漫游开关
        this.buildSwitchItem(
          $r('app.string.settings_cloud_sync_title'),
          $r('app.string.settings_cloud_sync_desc'),
          this.isCloudSync,
          (val: boolean) => {
            if (val && !this.isLoggedIn) {
              DialogHelper.showToast($r('app.string.settings_cloud_sync_require_login'));
            }
            settingsManager.setBoolean('is_cloud_sync', val, 'isCloudSyncEnabled');
            if (val) {
              DialogHelper.showToast($r('app.string.settings_cloud_sync_toast_enabled'));
              timeIslandRepository.triggerCloudSync().catch(() => {});
            } else {
              DialogHelper.showToast($r('app.string.settings_cloud_sync_toast_disabled'));
            }
          },
          true
        )

        // 3. 导出心流数据
        this.buildActionItem(
          $r('app.string.settings_data_export_title'),
          $r('app.string.settings_data_export_desc'),
          () => {
            this.handleExportData();
          },
          true
        )

        // 3. 从备份恢复数据
        this.buildActionItem(
          $r('app.string.settings_data_import_title'),
          $r('app.string.settings_data_import_desc'),
          () => {
            this.isRestoreDialogOpen = true;
          },
          true
        )

        // 4. 安全抹除所有数据 (警戒红/橙强调色)
        Row() {
          Column({ space: 3 }) {
            Text($r('app.string.settings_data_wipe_title'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.havenAmber)

            Text($r('app.string.settings_data_wipe_desc'))
              .fontSize(11)
              .fontColor(this.theme.textMuted)
              .maxLines(2)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .margin({ right: 12 })

          Image($r('app.media.ic_chevron_right'))
            .width(18)
            .height(18)
            .fillColor(this.theme.havenAmber)
        }
        .width('100%')
        .padding(16)
        .onClick(() => {
          soundEffectManager.play(SoundEffectType.PEN_CLICK);
          hapticFeedbackHelper.trigger('tick');
          this.handleWipeData();
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
   * 导出心流备份数据至剪贴板
   */
  private async handleExportData(): Promise<void> {
    try {
      if (this.localRecordCount === 0) {
        DialogHelper.showToast($r('app.string.settings_data_export_empty'));
        return;
      }
      const jsonStr = await timeIslandRepository.exportAllRecordsJson();
      const pData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, jsonStr);
      const pb = pasteboard.getSystemPasteboard();
      await pb.setData(pData);
      hapticFeedbackHelper.trigger('complete');
      soundEffectManager.play(SoundEffectType.BUBBLE);
      DialogHelper.showToast($r('app.string.settings_data_export_success'));
    } catch (_err) {
      DialogHelper.showToast($r('app.string.settings_data_export_empty'));
    }
  }

  /**
   * 将本地沙箱所有历史记录批量同步写入 HarmonyOS 原生系统日历
   */
  private async handleExportAllToCalendar(): Promise<void> {
    if (this.localRecordCount === 0) {
      DialogHelper.showToast($r('app.string.settings_data_export_empty'));
      return;
    }

    let confirmTitle = 'Sync to Calendar';
    let confirmMsg = 'Sync all records to system calendar?';
    let confirmText = 'Confirm';
    let cancelText = 'Cancel';
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const rm = context.resourceManager;
      confirmTitle = rm.getStringSync($r('app.string.settings_calendar_export_confirm_title').id);
      confirmMsg = rm.getStringSync($r('app.string.settings_calendar_export_confirm_msg').id);
      confirmText = rm.getStringSync($r('app.string.settings_data_wipe_dialog_confirm').id);
      cancelText = rm.getStringSync($r('app.string.settings_data_wipe_dialog_cancel').id);
    } catch (_e) {}

    const res = await DialogHelper.showDialog({
      type: DialogType.CONFIRM,
      title: confirmTitle,
      message: confirmMsg,
      confirmText: confirmText,
      cancelText: cancelText,
      isDanger: false
    });

    if (res.action === DialogAction.CONFIRM) {
      try {
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        const result = await calendarSyncManager.syncAllRecordsToCalendar(context);
        if (result.synced > 0) {
          hapticFeedbackHelper.trigger('complete');
          soundEffectManager.play(SoundEffectType.BUBBLE);
          DialogHelper.showToast($r('app.string.settings_calendar_export_success'));
        } else {
          DialogHelper.showToast($r('app.string.settings_data_export_empty'));
        }
      } catch (_err) {
        DialogHelper.showToast($r('app.string.settings_calendar_permission_denied'));
      }
    }
  }

  /**
   * 安全抹除本地所有专注历史数据 (强身份鉴权 + 危险二次弹窗)
   */
  private async handleWipeData(): Promise<void> {
    if (this.localRecordCount === 0) {
      DialogHelper.showToast($r('app.string.settings_data_export_empty'));
      return;
    }

    // 若开启了生物特征保护，执行人脸/指纹安全鉴权
    if (this.isBiometric) {
      let authTitle = 'Verify Identity';
      try {
        const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
        authTitle = context.resourceManager.getStringSync($r('app.string.settings_data_wipe_auth_prompt').id);
      } catch (_e) {
        authTitle = 'Verify Identity';
      }
      const passed = await biometricAuthManager.authenticate(authTitle);
      if (!passed) {
        DialogHelper.showToast($r('app.string.timeisland_toast_biometric_failed'));
        return;
      }
    }

    let confirmTitle = 'Clear Data';
    let confirmMsg = 'Are you sure?';
    let confirmText = 'Confirm';
    let cancelText = 'Cancel';
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const rm = context.resourceManager;
      confirmTitle = rm.getStringSync($r('app.string.settings_data_wipe_dialog_title').id);
      confirmMsg = rm.getStringSync($r('app.string.settings_data_wipe_dialog_msg').id);
      confirmText = rm.getStringSync($r('app.string.settings_data_wipe_dialog_confirm').id);
      cancelText = rm.getStringSync($r('app.string.settings_data_wipe_dialog_cancel').id);
    } catch (_e) {}

    const res = await DialogHelper.showDialog({
      type: DialogType.CONFIRM,
      title: confirmTitle,
      message: confirmMsg,
      confirmText: confirmText,
      cancelText: cancelText,
      isDanger: true
    });

    if (res.action === DialogAction.CONFIRM) {
      await timeIslandRepository.wipeAllRecords();
      this.localRecordCount = 0;
      hapticFeedbackHelper.trigger('warning');
      soundEffectManager.play(SoundEffectType.SWITCH_CLOSE);
      DialogHelper.showToast($r('app.string.settings_data_wipe_success'));
    }
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
        // 1. 应用品牌与版本信息 (极致纯净规范)
        Row() {
          Row({ space: 12 }) {
            Image($r('app.media.startIcon'))
              .width(36)
              .height(36)
              .borderRadius(18)

            Text($r('app.string.app_name'))
              .fontSize(15)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textPrimary)
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

        // 2. 建议与灵感反馈入口
        this.buildActionItem(
          $r('app.string.timeisland_settings_feedback_title'),
          $r('app.string.timeisland_settings_feedback_desc'),
          () => {
            FeedbackHelper.openFeedback(this.getUIContext());
          },
          true
        )

        // 3. 用户服务协议
        this.buildActionItem(
          $r('app.string.timeisland_settings_user_agreement_title'),
          $r('app.string.timeisland_settings_user_agreement_desc'),
          () => {
            this.activeLegalType = LegalNoticeType.AGREEMENT;
            this.isLegalDialogOpen = true;
          },
          true
        )

        // 4. 隐私保护政策 (华为应用市场重点合规项)
        this.buildActionItem(
          $r('app.string.timeisland_settings_privacy_policy_title'),
          $r('app.string.timeisland_settings_privacy_policy_desc'),
          () => {
            this.activeLegalType = LegalNoticeType.PRIVACY;
            this.isLegalDialogOpen = true;
          },
          true
        )

        // 5. 开源许可与致谢
        this.buildActionItem(
          $r('app.string.timeisland_settings_open_source_title'),
          $r('app.string.timeisland_settings_open_source_desc'),
          () => {
            this.activeLegalType = LegalNoticeType.OPEN_SOURCE;
            this.isLegalDialogOpen = true;
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
   * 通用导航跳转条目抽取组件
   */
  @Builder
  private buildActionItem(
    title: Resource,
    desc: Resource,
    onClick: () => void,
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

      Image($r('app.media.ic_chevron_right'))
        .width(18)
        .height(18)
        .fillColor(this.theme.textSecondary)
    }
    .width('100%')
    .padding(16)
    .border(hasDivider ? { width: { bottom: 1 }, color: this.theme.borderSubtle } : undefined)
    .onClick(() => {
      soundEffectManager.play(SoundEffectType.PEN_CLICK);
      hapticFeedbackHelper.trigger('tick');
      onClick();
    })
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
