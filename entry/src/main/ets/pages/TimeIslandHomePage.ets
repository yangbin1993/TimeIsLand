import { common } from '@kit.AbilityKit';
import { DialogHelper, BreakpointType, DialogType } from '@app/common';
import { FocusState, FocusTag } from '../model/FocusTypes';
import { FocusTimerViewModel, FocusTimerIntent, FocusTimerEffect, FocusTimerState } from '../viewmodel/FocusTimerViewModel';
import { FocusRingView } from '../components/FocusRingView';
import { IslandBiomeView } from '../components/IslandBiomeView';
import { TagSelectorView } from '../components/TagSelectorView';
import { TimeDurationSelector } from '../components/TimeDurationSelector';
import { ThemeSelectorDialog } from '../components/ThemeSelectorDialog';
import { NearLinkSanctuaryView } from '../components/NearLinkSanctuaryDialog';
import { FocusStatsView } from '../components/FocusStatsView';
import { FocusReflectionDialog } from '../components/FocusReflectionDialog';
import { nearLinkSanctuaryManager, NearLinkSanctuaryState, PartnerIslandInfo, SanctuaryStateListener } from '../utils/NearLinkSanctuaryManager';
import { ThemePalette, ThemeMode } from '../theme/ThemeTypes';
import { themeManager } from '../theme/ThemeManager';
import { soundEffectManager, SoundEffectType } from '../utils/SoundEffectManager';
import { whiteNoiseManager } from '../utils/WhiteNoiseManager';
import { widgetSyncManager } from '../utils/WidgetSyncManager';
import { hapticFeedbackHelper } from '../utils/HapticFeedbackHelper';
import { zenFlipSensorManager, ZenFlipState, ZenFlipListener } from '../utils/ZenFlipSensorManager';
import { BiometricAuthManager } from '../utils/BiometricAuthManager';
import { calendarSyncManager } from '../utils/CalendarSyncManager';
import { timeIslandRepository } from '../data/TimeIslandRepository';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'TimeIslandHome';

/**
 * 路由分发器 Builder 声明
 */
@Builder
export function TimeIslandHomeBuilder() {
  TimeIslandHomePage()
}

/**
 * 时光岛 - 极简心流罗盘主页面 (基于 Stitch 设计稿高保真还原)
 */
@Entry
@Component
struct TimeIslandHomePage {
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('bottomNavHeight') bottomNavHeight: number = 0;
  @StorageProp('currentTheme') theme: ThemePalette = themeManager.getPaletteByMode(ThemeMode.DARK);
  @StorageProp('currentBreakpoint') currentBreakpoint: BreakpointType = 'sm';
  @StorageProp('isFoldExpanded') isFoldExpanded: boolean = false;
  private vm: FocusTimerViewModel = new FocusTimerViewModel();
  @State private state: FocusTimerState = this.vm.state;
  @StorageProp('isLiveViewEnabled') isLiveViewEnabled: boolean = true;
  @StorageProp('isGraceHavenEnabled') isGraceHavenEnabled: boolean = true;
  @StorageProp('graceHavenSeconds') graceHavenSeconds: number = 120;
  @StorageProp('isNearlinkEnabled') @Watch('onNearlinkConfigChanged') isNearlinkEnabled: boolean = true;
  @StorageProp('isHapticFeedbackEnabled') isHapticFeedbackEnabled: boolean = true;
  @StorageProp('isZenFlipEnabled') isZenFlipEnabled: boolean = true;
  @StorageProp('isBiometricEnabled') isBiometricEnabled: boolean = false;
  @StorageProp('isCalendarSyncEnabled') isCalendarSyncEnabled: boolean = true;
  @State private zenFlipState: ZenFlipState = ZenFlipState.IDLE;
  @State private activeTab: string = 'focus';

  private onNearlinkConfigChanged(): void {
    if (!this.isNearlinkEnabled && this.activeTab === 'nearlink') {
      this.activeTab = 'focus';
    }
  }
  @State private isSoundDrawerOpen: boolean = false;
  @State private currentSoundId: string = 'tide';
  @State private isThemeDialogOpen: boolean = false;
  @State private partnerInfo: PartnerIslandInfo | null = null;
  @State private nearLinkState: NearLinkSanctuaryState = nearLinkSanctuaryManager.getState();
  @State private dualPaneMode: string = 'compass';
  @State private isZenImmersive: boolean = false;
  @State private isReflectionDialogOpen: boolean = false;
  @State private completedRecordId: number = 0;

  private getCurrentSoundRes(): Resource {
    if (this.currentSoundId === 'moss_rain') {
      return $r('app.string.timeisland_sound_moss_rain');
    } else if (this.currentSoundId === 'forest_spring') {
      return $r('app.string.timeisland_sound_forest_spring');
    }
    return $r('app.string.timeisland_sound_tide');
  }

  @StorageProp('cardQuickStartMinutes') @Watch('onCardQuickStartChanged') cardQuickStartMinutes: number = 0;
  @StorageProp('isCardAutoNoiseEnabled') isCardAutoNoiseEnabled: boolean = true;
  @StorageProp('isWidgetSyncEnabled') isWidgetSyncEnabled: boolean = true;

  private onCardQuickStartChanged(): void {
    const quickMins = this.cardQuickStartMinutes;
    if (quickMins && quickMins > 0) {
      AppStorage.setOrCreate('cardQuickStartMinutes', 0);
      if (this.state.status === FocusState.RUNNING || this.state.status === FocusState.FLOW_DRIFT) {
        DialogHelper.showToast($r('app.string.widget_toast_already_focusing'));
        return;
      }
      this.vm.dispatch(FocusTimerIntent.selectDuration(quickMins));
      this.vm.dispatch(FocusTimerIntent.startTimer());
      if (this.isCardAutoNoiseEnabled) {
        whiteNoiseManager.playSound(this.vm.state.selectedNoiseId);
      }
      hapticFeedbackHelper.trigger('complete');
      DialogHelper.showToast($r('app.string.widget_quick_start_toast'));
    }
  }

  private sanctuaryStateListener: SanctuaryStateListener = (sanctuaryState: NearLinkSanctuaryState, partner: PartnerIslandInfo | null): void => {
    this.nearLinkState = sanctuaryState;
    this.partnerInfo = partner;
    if (this.isWidgetSyncEnabled) {
      const isNearLinkActive = sanctuaryState === NearLinkSanctuaryState.CONNECTED || sanctuaryState === NearLinkSanctuaryState.SIMULATED;
      widgetSyncManager.syncFocusDataToWidgets(
        this.getUIContext().getHostContext() as common.UIAbilityContext,
        this.state.todayTotalMinutes,
        this.state.todayCompletedCount,
        this.state.currentTag?.name || 'Flow',
        this.state.allTimeMinutes,
        0,
        isNearLinkActive
      ).catch(() => {});
    }
  };

  private zenFlipListener: ZenFlipListener = (flipState: ZenFlipState): void => {
    this.zenFlipState = flipState;
    if (flipState === ZenFlipState.SCREEN_DOWN) {
      if (this.state.status === FocusState.IDLE) {
        this.vm.dispatch(FocusTimerIntent.startTimer());
        whiteNoiseManager.playSound(this.currentSoundId);
        hapticFeedbackHelper.trigger('complete');
        DialogHelper.showToast($r('app.string.zen_flip_toast_armed'));
      } else if (this.state.status === FocusState.PAUSED) {
        this.vm.dispatch(FocusTimerIntent.resumeTimer());
        whiteNoiseManager.resume();
        hapticFeedbackHelper.trigger('tick');
        DialogHelper.showToast($r('app.string.zen_flip_toast_resumed'));
      }
    } else if (flipState === ZenFlipState.SCREEN_UP) {
      if (this.state.status === FocusState.RUNNING) {
        this.vm.dispatch(FocusTimerIntent.pauseTimer());
        whiteNoiseManager.pause();
        hapticFeedbackHelper.trigger('warning');
        DialogHelper.showToast($r('app.string.zen_flip_toast_interrupted'));
      }
    }
  };

  aboutToAppear(): void {
    // 监听 MVI 副作用流
    this.vm.observeEffect((effect: FocusTimerEffect): void => {
      this.handleEffect(effect);
    });
    // 触发数据初始化
    this.vm.dispatch(FocusTimerIntent.initData());

    // 监听星闪双子岛伴读状态
    this.nearLinkState = nearLinkSanctuaryManager.getState();
    this.partnerInfo = nearLinkSanctuaryManager.getPartner();
    nearLinkSanctuaryManager.addStateListener(this.sanctuaryStateListener);

    // 注册翻转静心真机传感器监听
    zenFlipSensorManager.addListener(this.zenFlipListener);
    this.zenFlipState = zenFlipSensorManager.getState();
  }

  onPageShow(): void {
    // 响应冷启动或热拉起桌面卡片一键起航
    this.onCardQuickStartChanged();
  }

  aboutToDisappear(): void {
    nearLinkSanctuaryManager.removeStateListener(this.sanctuaryStateListener);
    zenFlipSensorManager.removeListener(this.zenFlipListener);
    zenFlipSensorManager.disarmZenFlip();
    this.vm.onCleared();
  }

  private async confirmAbandonFocus(): Promise<void> {
    whiteNoiseManager.pause();
    let titleStr = '';
    let msgStr = '';
    let confirmStr = '';
    let cancelStr = '';

    try {
      const rm = (this.getUIContext().getHostContext() as common.UIAbilityContext).resourceManager;
      titleStr = rm.getStringSync($r('app.string.focus_dialog_abandon_title').id);
      msgStr = rm.getStringSync($r('app.string.focus_dialog_abandon_content').id);
      confirmStr = rm.getStringSync($r('app.string.focus_dialog_abandon_confirm').id);
      cancelStr = rm.getStringSync($r('app.string.focus_dialog_abandon_cancel').id);
    } catch (_err) {
      titleStr = 'Stop Focus';
      msgStr = 'Are you sure to abandon current flow?';
      confirmStr = 'Confirm';
      cancelStr = 'Cancel';
    }

    const result = await DialogHelper.showDialog({
      type: DialogType.CONFIRM,
      title: titleStr,
      message: msgStr,
      confirmText: confirmStr,
      cancelText: cancelStr,
      isDanger: true
    });

    if (!result.isConfirmed) {
      if (this.state.status === FocusState.RUNNING) {
        whiteNoiseManager.resume();
      }
      return;
    }

    if (this.isBiometricEnabled) {
      let promptStr = '';
      try {
        promptStr = (this.getUIContext().getHostContext() as common.UIAbilityContext).resourceManager.getStringSync($r('app.string.focus_auth_prompt').id);
      } catch (_e) {
        promptStr = 'Verify identity to abandon flow';
      }

      const passed = await BiometricAuthManager.getInstance().authenticate(promptStr);
      if (!passed) {
        DialogHelper.showToast($r('app.string.focus_auth_failed'));
        if (this.state.status === FocusState.RUNNING) {
          whiteNoiseManager.resume();
        }
        return;
      }
    }

    hapticFeedbackHelper.trigger('warning');
    zenFlipSensorManager.disarmZenFlip();
    this.isZenImmersive = false;
    this.vm.dispatch(FocusTimerIntent.giveUpTimer());
  }

  /**
   * 专注达成后异步同步单条心流记录至系统默认日历
   */
  private async syncRecordToCalendar(recordId: number, note?: string, rating?: number): Promise<void> {
    if (!this.isCalendarSyncEnabled || recordId <= 0) {
      return;
    }
    try {
      const record = await timeIslandRepository.getRecordById(recordId);
      if (record) {
        const tagName = this.state.currentTag?.name || 'Flow';
        await calendarSyncManager.syncFocusRecordToCalendar(
          this.getUIContext().getHostContext() as common.UIAbilityContext,
          record,
          tagName,
          note,
          rating
        );
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Calendar auto sync failed: %{public}s', JSON.stringify(err));
    }
  }

  private handleEffect(effect: FocusTimerEffect): void {
    if (effect.type === 'SHOW_TOAST') {
      if (effect.messageKey === 'timeisland_toast_focus_completed') {
        this.isZenImmersive = false;
        whiteNoiseManager.pause();
        DialogHelper.showToast($r('app.string.timeisland_toast_focus_completed'));
        if (this.isWidgetSyncEnabled) {
          const isNearLinkActive = this.nearLinkState === NearLinkSanctuaryState.CONNECTED || this.nearLinkState === NearLinkSanctuaryState.SIMULATED;
          widgetSyncManager.syncFocusDataToWidgets(
            this.getUIContext().getHostContext() as common.UIAbilityContext,
            this.state.todayTotalMinutes,
            this.state.todayCompletedCount,
            this.state.currentTag?.name || 'Flow',
            this.state.allTimeMinutes,
            0,
            isNearLinkActive
          ).catch(() => {});
        }
      } else if (effect.messageKey === 'timeisland_toast_give_up') {
        this.isZenImmersive = false;
        whiteNoiseManager.pause();
        DialogHelper.showToast($r('app.string.timeisland_toast_give_up'));
      } else if (effect.messageKey === 'timeisland_toast_cannot_change_duration') {
        DialogHelper.showToast($r('app.string.timeisland_toast_cannot_change_duration'));
      } else if (effect.messageKey === 'timeisland_toast_flow_drift_started') {
        DialogHelper.showToast($r('app.string.timeisland_toast_flow_drift_started'));
      } else if (effect.messageKey === 'timeisland_toast_grace_haven_returned') {
        DialogHelper.showToast($r('app.string.timeisland_toast_grace_haven_returned'));
      } else if (effect.messageKey === 'timeisland_toast_grace_haven_timeout') {
        DialogHelper.showToast($r('app.string.timeisland_toast_grace_haven_timeout'));
      } else if (effect.messageKey === 'reflection_dialog_toast_saved') {
        DialogHelper.showToast($r('app.string.reflection_dialog_toast_saved'));
      }
    } else if (effect.type === 'FOCUS_FINISHED') {
      if (effect.recordId && effect.recordId > 0) {
        this.completedRecordId = effect.recordId;
        this.isReflectionDialogOpen = true;
      }
    } else if (effect.type === 'FLOW_TARGET_REACHED') {
      soundEffectManager.play(SoundEffectType.BUBBLE);
    } else if (effect.type === 'GRACE_HAVEN_ENTERED') {
      whiteNoiseManager.pause();
    } else if (effect.type === 'GRACE_HAVEN_RESTORED') {
      soundEffectManager.play(SoundEffectType.BUBBLE);
      whiteNoiseManager.resume();
    } else if (effect.type === 'GRACE_HAVEN_TIMEOUT_DOCKED') {
      whiteNoiseManager.pause();
      soundEffectManager.play(SoundEffectType.SWITCH_CLOSE);
    } else if (effect.type === 'TRIGGER_HAPTIC') {
      const pattern = (effect.pattern as ('tick' | 'complete' | 'warning')) ?? 'tick';
      hapticFeedbackHelper.trigger(pattern);
    }
  }

  build() {
    Column() {
      // 1. 顶部 Header 与品牌标识 (全屏沉浸模式下自动隐藏，平滑释放垂直空间)
      if (!this.isZenImmersive) {
        this.buildTopHeader()
      }

      // 2. 主内容滚动视窗与底部常驻导航
      Stack({ alignContent: Alignment.Bottom }) {
        Scroll() {
          Column({ space: 14 }) {
            if (this.isFoldExpanded || this.currentBreakpoint !== 'sm') {
              // 折叠屏展开态 / 平板大屏：8 列双栏自适应心流大画布 (Stitch 1:1 还原)
              this.buildDualPaneLayout()
            } else {
              // 常规手机与折叠屏外屏：单列纵向沉浸流线
              this.buildSinglePaneLayout()
            }

            // 占位垫底，避免被底部导航遮挡 (全屏沉浸态下收缩垫底)
            Blank().height(this.isZenImmersive ? 20 : (80 + (this.bottomNavHeight > 0 ? this.bottomNavHeight : 0)))
          }
          .width('100%')
          .padding({
            left: (this.isFoldExpanded || this.currentBreakpoint !== 'sm') ? 20 : 16,
            right: (this.isFoldExpanded || this.currentBreakpoint !== 'sm') ? 20 : 16,
            top: this.isZenImmersive ? (this.statusBarHeight > 0 ? this.statusBarHeight + 8 : 16) : 8,
            bottom: 20
          })
        }
        .scrollBar(BarState.Off)
        .width('100%')
        .height('100%')

        // 9. 底部常驻禅意导航栏 (全屏沉浸模式下自动优雅隐退)
        if (!this.isZenImmersive) {
          this.buildBottomNavBar()
        }

        // 沉浸全屏微晶退出按钮 (右上方半透明悬浮微晶，极致轻量)
        if (this.isZenImmersive) {
          Row({ space: 5 }) {
            Image($r('app.media.ic_close'))
              .width(13)
              .height(13)
              .fillColor(this.theme.textSecondary)

            Text($r('app.string.timeisland_zen_immersive_exit'))
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textSecondary)
          }
          .padding({ left: 10, right: 12, top: 6, bottom: 6 })
          .backgroundColor(this.theme.surfaceCard)
          .borderRadius(16)
          .border({ width: 1, color: this.theme.borderSubtle, radius: 16 })
          .shadow({ radius: 12, color: this.theme.shadowCard, offsetY: 2 })
          .position({ x: '100%', y: (this.statusBarHeight > 0 ? this.statusBarHeight : 0) + 12 })
          .markAnchor({ x: '100%', y: 0 })
          .margin({ right: 16 })
          .onClick(() => {
            soundEffectManager.play(SoundEffectType.PEN_CLICK);
            hapticFeedbackHelper.trigger('tick');
            this.isZenImmersive = false;
            DialogHelper.showToast($r('app.string.timeisland_zen_immersive_toast_exit'));
          })
        }

        // 10. 生境主题流转切换弹窗
        ThemeSelectorDialog({
          visible: this.isThemeDialogOpen,
          onClose: () => {
            this.isThemeDialogOpen = false;
          }
        })

        // 11. 心流随笔与打卡复盘弹窗
        FocusReflectionDialog({
          visible: this.isReflectionDialogOpen,
          recordId: this.completedRecordId,
          onSave: (recordId: number, note: string, rating: number) => {
            this.isReflectionDialogOpen = false;
            this.vm.dispatch(FocusTimerIntent.saveReflection(recordId, note, rating));
            this.syncRecordToCalendar(recordId, note, rating);
          },
          onSkip: () => {
            this.isReflectionDialogOpen = false;
            this.syncRecordToCalendar(this.completedRecordId);
          }
        })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bgCanvas)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
    .animation({ duration: 250, curve: Curve.FastOutSlowIn })
  }

  /**
   * 直板手机与折叠屏外屏专属：单列纵向流线布局
   */
  @Builder
  private buildSinglePaneLayout() {
    Column({ space: 14 }) {
      if (this.activeTab === 'biome') {
        // 生态 Tab: 动态晨昏地貌与微缩生境群岛
        IslandBiomeView({
          allTimeMinutes: this.state.allTimeMinutes,
          todayMinutes: this.state.todayTotalMinutes,
          focusState: this.state.status,
          isFlowDrift: this.state.status === FocusState.FLOW_DRIFT
        })
      } else if (this.activeTab === 'stats') {
        // 气韵 Tab: 心流数据统计与时间能量看板
        FocusStatsView()
      } else if (this.activeTab === 'nearlink') {
        // 星闪 Tab: 星闪双子岛近场陪伴中枢
        NearLinkSanctuaryView({
          theme: this.theme
        })
      } else {
        // 专注 Tab: 核心罗盘与计时控制
        // 2. 状态微胶囊 (Flow Drift & 避风港守护)
        this.buildAmbientStatusPills()

        // 3. 核心罗盘刻度区
        FocusRingView({
          progress: this.state.progress,
          timeText: this.state.formattedTime,
          state: this.state.status,
          tagColor: this.state.currentTag ? this.state.currentTag.colorHex : this.theme.primaryAccent,
          tagName: this.state.currentTag ? this.state.currentTag.name : ''
        })
        .gesture(
          LongPressGesture({ repeat: false, duration: 800 })
            .onAction(() => {
              if (this.state.status === FocusState.RUNNING || this.state.status === FocusState.PAUSED) {
                hapticFeedbackHelper.trigger('tick');
                this.confirmAbandonFocus();
              }
            })
        )

        // 4. 时长选择胶囊与气韵标签 (全屏沉浸专注态下优雅隐去，留出极致通透的居中呼吸空间)
        if (!this.isZenImmersive || this.state.status === FocusState.IDLE) {
          TimeDurationSelector({
            selectedMinutes: this.state.selectedMinutes,
            disabled: this.state.status !== FocusState.IDLE,
            onSelectMinutes: (mins: number) => {
              this.vm.dispatch(FocusTimerIntent.selectDuration(mins));
            }
          })

          // 5. 心流气韵场域标签
          TagSelectorView({
            tags: this.state.tags,
            selectedTagId: this.state.currentTag ? this.state.currentTag.id : 1,
            onSelectTag: (tag: FocusTag) => {
              this.vm.dispatch(FocusTimerIntent.selectTag(tag));
            }
          })
        }

        // 6. 核心操作控制中枢 (启航心流 / 息心)
        this.buildActionControls()

        // 7. 白噪音快捷抽屉面板 (可折叠)
        if (this.isSoundDrawerOpen) {
          this.buildWhiteNoiseDrawer()
        }
      }
    }
    .width('100%')
  }

  /**
   * 折叠屏展开态与平板大屏专属：8 列双栏自适应心流大画布 (Stitch 1:1)
   */
  @Builder
  private buildDualPaneLayout() {
    if (this.activeTab === 'stats') {
      // 气韵 Tab: 双栏大画布展示心流统计
      FocusStatsView()
    } else if (this.activeTab === 'nearlink') {
      // 星闪 Tab: 左侧伴读生境 + 右侧星闪双子岛中枢
      Row({ space: 16 }) {
        Column({ space: 12 }) {
          IslandBiomeView({
            allTimeMinutes: this.state.allTimeMinutes,
            todayMinutes: this.state.todayTotalMinutes,
            focusState: this.state.status,
            isFlowDrift: this.state.status === FocusState.FLOW_DRIFT
          })
          this.buildNearLinkCompanionCard()
        }
        .layoutWeight(1)
        .padding(14)
        .backgroundColor(this.theme.surfaceLow)
        .borderRadius(20)
        .border({ width: 1, color: this.theme.borderSubtle })

        Column() {
          NearLinkSanctuaryView({
            theme: this.theme
          })
        }
        .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)
    } else {
      Row({ space: 16 }) {
        // === 左侧大画布 (Left Canvas: 沉浸心流与 2.5D 生境) ===
        Column({ space: 12 }) {
        // 左栏顶栏：模式切换微胶囊 (心流罗盘 / 微缩群岛) 与状态气泡
        Row() {
          Row({ space: 4 }) {
            Button({ type: ButtonType.Capsule, stateEffect: true }) {
              Text($r('app.string.foldable_mode_switch_compass'))
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.dualPaneMode === 'compass' ? this.theme.textInverse : this.theme.textSecondary)
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            }
            .backgroundColor(this.dualPaneMode === 'compass' ? this.theme.primaryAccent : this.theme.surfaceLowest)
            .onClick(() => {
              this.dualPaneMode = 'compass';
              soundEffectManager.play(SoundEffectType.PEN_CLICK);
            })

            Button({ type: ButtonType.Capsule, stateEffect: true }) {
              Text($r('app.string.foldable_mode_switch_biome'))
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.dualPaneMode === 'biome' ? this.theme.textInverse : this.theme.textSecondary)
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            }
            .backgroundColor(this.dualPaneMode === 'biome' ? this.theme.primaryAccent : this.theme.surfaceLowest)
            .onClick(() => {
              this.dualPaneMode = 'biome';
              soundEffectManager.play(SoundEffectType.PEN_CLICK);
            })
          }
          .padding(3)
          .backgroundColor(this.theme.surfaceLowest)
          .borderRadius(16)

          Blank()

          // 状态微胶囊 (Flow Drift & 避风港守护)
          this.buildAmbientStatusPills()
        }
        .width('100%')

        // 主体：微缩生境群岛或核心罗盘
        if (this.dualPaneMode === 'biome') {
          IslandBiomeView({
            allTimeMinutes: this.state.allTimeMinutes,
            todayMinutes: this.state.todayTotalMinutes,
            focusState: this.state.status,
            isFlowDrift: this.state.status === FocusState.FLOW_DRIFT
          })
        } else {
          Column() {
            FocusRingView({
              progress: this.state.progress,
              timeText: this.state.formattedTime,
              state: this.state.status,
              tagColor: this.state.currentTag ? this.state.currentTag.colorHex : this.theme.primaryAccent,
              tagName: this.state.currentTag ? this.state.currentTag.name : ''
            })
            .gesture(
              LongPressGesture({ repeat: false, duration: 800 })
                .onAction(() => {
                  if (this.state.status === FocusState.RUNNING || this.state.status === FocusState.PAUSED) {
                    hapticFeedbackHelper.trigger('tick');
                    this.confirmAbandonFocus();
                  }
                })
            )
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .padding({ top: 12, bottom: 12 })
        }

        // 左栏底部：星闪近场共鸣伙伴提示卡片
        this.buildNearLinkCompanionCard()
      }
      .layoutWeight(1)
      .padding(14)
      .backgroundColor(this.theme.surfaceLow)
      .borderRadius(20)
      .border({ width: 1, color: this.theme.borderSubtle })

      // === 右侧中枢控制台 (Right Control Deck: 调控专注律动与气韵声景) ===
      Column({ space: 12 }) {
        // 1. 顶部双列数据玻璃卡片 (今日专注 + 心流湖储水)
        this.buildFoldableDataCards()

        // 2. 专注时长阶梯选择胶囊
        TimeDurationSelector({
          selectedMinutes: this.state.selectedMinutes,
          disabled: this.state.status !== FocusState.IDLE,
          onSelectMinutes: (mins: number) => {
            this.vm.dispatch(FocusTimerIntent.selectDuration(mins));
          }
        })

        // 3. 气韵场域标签
        TagSelectorView({
          tags: this.state.tags,
          selectedTagId: this.state.currentTag ? this.state.currentTag.id : 1,
          onSelectTag: (tag: FocusTag) => {
            this.vm.dispatch(FocusTimerIntent.selectTag(tag));
          }
        })

        // 4. 核心三段式操作控制中枢 (启航 / 息心)
        this.buildActionControls()

        // 5. 白噪音控制抽屉 (展开态常驻展现)
        this.buildWhiteNoiseDrawer()
      }
      .layoutWeight(1)
      .padding(14)
      .backgroundColor(this.theme.surfaceLow)
      .borderRadius(20)
      .border({ width: 1, color: this.theme.borderSubtle })
    }
    .width('100%')
    .alignItems(VerticalAlign.Top)
    }
  }

  /**
   * 折叠屏左栏：星闪近场共鸣伙伴陪伴卡片
   */
  @Builder
  private buildNearLinkCompanionCard() {
    Row({ space: 10 }) {
      Image($r('app.media.ic_nearlink'))
        .width(20)
        .height(20)
        .fillColor(
          (this.nearLinkState === NearLinkSanctuaryState.CONNECTED || this.nearLinkState === NearLinkSanctuaryState.SIMULATED)
            ? this.theme.primaryAccent
            : (this.nearLinkState === NearLinkSanctuaryState.SCANNING || this.nearLinkState === NearLinkSanctuaryState.BROADCASTING
                ? this.theme.havenAmber
                : this.theme.textMuted)
        )

      Column({ space: 2 }) {
        Row({ space: 6 }) {
          Text(this.partnerInfo ? this.partnerInfo.islandName : $r('app.string.foldable_nearlink_companion'))
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.textPrimary)

          // 依据真实星闪近场连接状态展示动态微标
          Text(
            (this.nearLinkState === NearLinkSanctuaryState.CONNECTED || this.nearLinkState === NearLinkSanctuaryState.SIMULATED)
              ? (this.partnerInfo?.isPartnerFocusing ? $r('app.string.nearlink_partner_focusing') : $r('app.string.nearlink_status_resonating'))
              : (this.nearLinkState === NearLinkSanctuaryState.SCANNING
                  ? $r('app.string.nearlink_scanning')
                  : (this.nearLinkState === NearLinkSanctuaryState.BROADCASTING ? $r('app.string.nearlink_broadcasting') : $r('app.string.nearlink_connected')))
          )
            .fontSize(9)
            .fontColor(
              (this.nearLinkState === NearLinkSanctuaryState.CONNECTED || this.nearLinkState === NearLinkSanctuaryState.SIMULATED)
                ? this.theme.primaryAccent
                : this.theme.textSecondary
            )
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .backgroundColor(
              (this.nearLinkState === NearLinkSanctuaryState.CONNECTED || this.nearLinkState === NearLinkSanctuaryState.SIMULATED)
                ? this.theme.primaryAccentBg
                : this.theme.surfaceLowest
            )
            .borderRadius(4)
        }

        Text(
          this.partnerInfo
            ? $r('app.string.foldable_nearlink_companion_sub')
            : (this.nearLinkState === NearLinkSanctuaryState.SCANNING
                ? $r('app.string.timeisland_tab_nearlink_toast')
                : $r('app.string.nearlink_desc'))
        )
          .fontSize(10)
          .fontColor(this.theme.textMuted)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        Text(
          (this.nearLinkState === NearLinkSanctuaryState.CONNECTED || this.nearLinkState === NearLinkSanctuaryState.SIMULATED) && this.partnerInfo
            ? $r('app.string.nearlink_send_ripple')
            : $r('app.string.nearlink_title')
        )
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.primaryAccent)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      }
      .backgroundColor(this.theme.primaryAccentBg)
      .border({ width: 1, color: this.theme.primaryAccentGlow })
      .onClick(() => {
        if ((this.nearLinkState === NearLinkSanctuaryState.CONNECTED || this.nearLinkState === NearLinkSanctuaryState.SIMULATED) && this.partnerInfo) {
          soundEffectManager.play(SoundEffectType.BUBBLE);
          nearLinkSanctuaryManager.sendRippleToPartner();
          DialogHelper.showToast($r('app.string.nearlink_ripple_sent'));
        } else {
          soundEffectManager.play(SoundEffectType.BUBBLE);
          this.activeTab = 'nearlink';
        }
      })
    }
    .width('100%')
    .padding(10)
    .backgroundColor(this.theme.surfaceCard)
    .borderRadius(14)
    .border({ width: 1, color: this.theme.borderSubtle })
  }

  /**
   * 折叠屏右栏：双列数据玻璃卡片 (今日专注 + 心流湖蓄水容量)
   */
  @Builder
  private buildFoldableDataCards() {
    Row({ space: 10 }) {
      // 1. 今日专注时长卡片
      Column({ space: 4 }) {
        Text($r('app.string.foldable_stat_today'))
          .fontSize(11)
          .fontColor(this.theme.textMuted)

        Row({ space: 4 }) {
          Text(`${this.state.todayTotalMinutes}`)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.textPrimary)
          Text($r('app.string.timeisland_duration_minute'))
            .fontSize(11)
            .fontColor(this.theme.textSecondary)
            .alignSelf(ItemAlign.End)
            .margin({ bottom: 3 })
        }

        Row({ space: 4 }) {
          Text($r('app.string.foldable_stat_streak'))
            .fontSize(9)
            .fontColor(this.theme.textMuted)
          Text(`${this.state.todayCompletedCount} `)
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.primaryAccent)
          Text($r('app.string.foldable_stat_streak_unit'))
            .fontSize(9)
            .fontColor(this.theme.textMuted)
        }
      }
      .layoutWeight(1)
      .padding(10)
      .backgroundColor(this.theme.surfaceCard)
      .borderRadius(14)
      .border({ width: 1, color: this.theme.borderSubtle })
      .alignItems(HorizontalAlign.Start)

      // 2. 心流湖储水量卡片
      Column({ space: 4 }) {
        Text($r('app.string.foldable_stat_lake'))
          .fontSize(11)
          .fontColor(this.theme.textMuted)

        Row({ space: 4 }) {
          Text(`${this.state.todayTotalMinutes * 35}`)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.primaryAccent)
          Text($r('app.string.foldable_stat_lake_unit'))
            .fontSize(11)
            .fontColor(this.theme.textSecondary)
            .alignSelf(ItemAlign.End)
            .margin({ bottom: 3 })
        }

        Progress({ value: Math.min(100, Math.round((this.state.todayTotalMinutes / 60) * 100)), total: 100, type: ProgressType.Linear })
          .width('100%')
          .height(4)
          .color(this.theme.primaryAccent)
          .backgroundColor(this.theme.borderSubtle)
      }
      .layoutWeight(1)
      .padding(10)
      .backgroundColor(this.theme.surfaceCard)
      .borderRadius(14)
      .border({ width: 1, color: this.theme.borderSubtle })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
  }

  /**
   * 顶部品牌栏与统计入口 (Edge-to-Edge 状态栏动态避让)
   */
  @Builder
  private buildTopHeader() {
    Row() {
      Row({ space: 8 }) {
        Image($r('app.media.startIcon'))
          .width(28)
          .height(28)
          .borderRadius(14)

        Column({ space: 2 }) {
          Text($r('app.string.app_name'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.textPrimary)
          Text($r('app.string.timeisland_app_brand_en'))
            .fontSize(9)
            .fontWeight(FontWeight.Lighter)
            .fontColor(this.theme.textMuted)
            .letterSpacing(1.5)
        }
        .alignItems(HorizontalAlign.Start)

        if (this.isFoldExpanded || this.currentBreakpoint !== 'sm') {
          Row({ space: 4 }) {
            Row()
              .width(5)
              .height(5)
              .borderRadius(2.5)
              .backgroundColor(this.theme.primaryAccent)
            Text($r('app.string.foldable_badge_deck'))
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.primaryAccent)
          }
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor(this.theme.primaryAccentBg)
          .borderRadius(12)
          .border({ width: 1, color: this.theme.primaryAccentGlow })
        }
      }

      Blank()

      // 右侧：极简纯齿轮设置按钮 (去除外框与冗余文字，回归通透禅意)
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Image($r('app.media.ic_settings'))
          .width(20)
          .height(20)
          .fillColor(this.theme.textPrimary)
      }
      .width(36)
      .height(36)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        soundEffectManager.play(SoundEffectType.BUBBLE);
        try {
          this.getUIContext().getRouter().pushUrl({ url: 'pages/TimeIslandSettingsPage' }).catch((err: Error) => {
            hilog.error(DOMAIN, TAG, 'Failed to pushUrl asynchronously: %{public}s', err.message);
          });
        } catch (err) {
          hilog.error(DOMAIN, TAG, 'Failed to navigate to TimeIslandSettingsPage: %{public}s', JSON.stringify(err));
        }
      })
    }
    .width('100%')
    .padding({
      left: (this.isFoldExpanded || this.currentBreakpoint !== 'sm') ? 20 : 16,
      right: (this.isFoldExpanded || this.currentBreakpoint !== 'sm') ? 20 : 16,
      top: this.statusBarHeight > 0 ? this.statusBarHeight : 8,
      bottom: 6
    })
  }

  /**
   * 顶部双态氛围气泡 (心流微漾 + 避风港守护)
   */
  @Builder
  private buildAmbientStatusPills() {
    Row() {
      // 深潜心流态 / 无界延展态
      Row({ space: 6 }) {
        Row()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor(this.state.status === FocusState.FLOW_DRIFT ? this.theme.havenAmber : this.theme.primaryAccent)
          .shadow({ radius: 8, color: this.state.status === FocusState.FLOW_DRIFT ? this.theme.havenAmber : this.theme.primaryGlow, offsetY: 0 })
        Text(this.state.status === FocusState.FLOW_DRIFT ? $r('app.string.timeisland_drift_capsule_active') : $r('app.string.timeisland_status_flow_drift'))
          .fontSize(11)
          .fontColor(this.state.status === FocusState.FLOW_DRIFT ? this.theme.havenAmber : this.theme.primaryAccent)
          .fontWeight(FontWeight.Medium)
      }
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor(this.state.status === FocusState.FLOW_DRIFT ? this.theme.havenAmberBg : this.theme.primaryAccentBg)
      .borderRadius(14)
      .border({ width: 1, color: this.state.status === FocusState.FLOW_DRIFT ? this.theme.havenAmberBorder : this.theme.borderSubtle })

      Blank()

      // 3. 全屏沉浸微晶胶囊 (专注运行态下显现，支持一键隐去非核心元素)
      if (this.state.status !== FocusState.IDLE) {
        Row({ space: 4 }) {
          Image($r('app.media.ic_explore'))
            .width(12)
            .height(12)
            .fillColor(this.isZenImmersive ? this.theme.primaryAccent : this.theme.textSecondary)

          Text(this.isZenImmersive ? $r('app.string.timeisland_zen_immersive_exit') : $r('app.string.timeisland_zen_immersive_enter'))
            .fontSize(11)
            .fontColor(this.isZenImmersive ? this.theme.primaryAccent : this.theme.textSecondary)
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 8, right: 8, top: 5, bottom: 5 })
        .backgroundColor(this.isZenImmersive ? this.theme.primaryAccentBg : this.theme.surfaceLow)
        .borderRadius(14)
        .border({
          width: 1,
          color: this.isZenImmersive ? this.theme.primaryAccentGlow : this.theme.borderSubtle,
          radius: 14
        })
        .margin({ right: 6 })
        .onClick(() => {
          soundEffectManager.play(SoundEffectType.PEN_CLICK);
          hapticFeedbackHelper.trigger('tick');
          this.isZenImmersive = !this.isZenImmersive;
          DialogHelper.showToast(this.isZenImmersive ?
            $r('app.string.timeisland_zen_immersive_toast_enter') :
            $r('app.string.timeisland_zen_immersive_toast_exit'));
        })
      }

      // 避风港守护微胶囊 (支持活跃态倒计时脉动与静态展示)
      Row({ space: 5 }) {
        Image($r('app.media.ic_shield_check'))
          .width(13)
          .height(13)
          .fillColor(this.isGraceHavenEnabled ? this.theme.havenAmber : this.theme.textMuted)

        Text(this.state.isGraceHavenActive
          ? `${this.state.graceHavenRemainingSeconds}s`
          : (this.isGraceHavenEnabled ? $r('app.string.timeisland_status_grace_haven') : $r('app.string.timeisland_status_grace_haven_disabled')))
          .fontSize(11)
          .fontColor(this.isGraceHavenEnabled ? this.theme.havenAmber : this.theme.textMuted)
          .fontWeight(FontWeight.Medium)

        if (this.state.isGraceHavenActive) {
          Text($r('app.string.timeisland_grace_haven_remaining_sec'))
            .fontSize(10)
            .fontColor(this.theme.havenAmber)
            .fontWeight(FontWeight.Normal)
        }
      }
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor(this.state.isGraceHavenActive ? this.theme.havenAmberBg : (this.isGraceHavenEnabled ? this.theme.havenAmberBg : this.theme.surfaceLow))
      .borderRadius(14)
      .border({
        width: 1,
        color: this.isGraceHavenEnabled ? this.theme.havenAmberBorder : this.theme.borderSubtle
      })
      .shadow(this.state.isGraceHavenActive ? {
        radius: 10,
        color: this.theme.havenAmber,
        offsetY: 0
      } : { radius: 0, color: Color.Transparent })
    }
    .width('100%')
  }

  /**
   * 核心三段式操作控制中枢 (1:1 还原 Stitch 触感微拟物控制系统)
   */
  @Builder
  private buildActionControls() {
    Row({ space: 12 }) {
      // 1. 左侧双同心圆盘环境音按钮 (带 LED 状态呼吸微孔)
      Column({ space: 4 }) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          Stack({ alignContent: Alignment.Top }) {
            // LED 状态微孔指示灯
            Row()
              .width(5)
              .height(5)
              .borderRadius(2.5)
              .backgroundColor(this.isSoundDrawerOpen ? this.theme.primaryAccent : $r('app.color.timeisland_toggle_track_off'))
              .shadow(this.isSoundDrawerOpen ? { radius: 6, color: this.theme.primaryGlow, offsetY: 0 } : { radius: 0, color: Color.Transparent })
              .margin({ top: 5 })

            // 居中立体微浮雕图标
            Image($r('app.media.ic_air'))
              .width(22)
              .height(22)
              .fillColor(this.isSoundDrawerOpen ? this.theme.primaryAccent : this.theme.textSecondary)
              .margin({ top: 12 })
          }
          .width('100%')
          .height('100%')
        }
        .width(50)
        .height(50)
        .backgroundColor(this.theme.surfaceCard)
        .border({
          width: 1,
          color: this.isSoundDrawerOpen ? this.theme.primaryAccent : this.theme.borderSubtle
        })
        .shadow({
          radius: 14,
          color: this.isSoundDrawerOpen ? this.theme.primaryGlow : this.theme.shadowFloating,
          offsetY: 2
        })
        .onClick(() => {
          this.isSoundDrawerOpen = !this.isSoundDrawerOpen;
          soundEffectManager.play(SoundEffectType.SLIDE);
        })

        Text(this.getCurrentSoundRes())
          .fontSize(10)
          .fontColor(this.theme.textSecondary)
          .fontWeight(FontWeight.Medium)
      }

      // 2. 中间 Stitch 核心起航主胶囊 (双层流光 + 3D 发丝高光倒角 + 呼吸光晕)
      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        Stack({ alignContent: Alignment.Top }) {
          // 顶部 3D 镜面发丝高光线 (Specular Highlight Rim)
          Row()
            .width('80%')
            .height(1.5)
            .borderRadius(1)
            .backgroundColor($r('app.color.timeisland_overlay_capsule_bar'))
            .margin({ top: 1 })

          // 核心按键内容
          Row({ space: 10 }) {
            // 左侧微晶高光圆形图标底座
            Stack({ alignContent: Alignment.Center }) {
              Row()
                .width(32)
                .height(32)
                .borderRadius(16)
                .backgroundColor(this.state.status === FocusState.FLOW_DRIFT ? $r('app.color.timeisland_overlay_capsule_active') : (this.state.status === FocusState.RUNNING ? $r('app.color.timeisland_overlay_capsule_running') : $r('app.color.timeisland_overlay_capsule_idle')))

              Image(this.state.status === FocusState.FLOW_DRIFT ? $r('app.media.ic_check') : (this.state.status === FocusState.RUNNING ? $r('app.media.ic_pause') : $r('app.media.ic_explore')))
                .width(18)
                .height(18)
                .fillColor(this.state.status === FocusState.FLOW_DRIFT ? this.theme.textInverse : (this.state.status === FocusState.RUNNING ? this.theme.textPrimary : this.theme.textInverse))
            }

            // 右侧双行排版与极细微徽章
            Column({ space: 2 }) {
              Row({ space: 6 }) {
                Text(this.state.status === FocusState.FLOW_DRIFT ? $r('app.string.timeisland_btn_dock_drift') : (this.state.status === FocusState.RUNNING ? $r('app.string.timeisland_btn_dock') : $r('app.string.timeisland_btn_start')))
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.state.status === FocusState.RUNNING ? this.theme.textPrimary : this.theme.textInverse)

                Text(this.state.status === FocusState.FLOW_DRIFT ? $r('app.string.timeisland_theme_flow_drifting') : $r('app.string.timeisland_theme_touch_chip'))
                  .fontSize(8)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.state.status === FocusState.RUNNING ? this.theme.primaryAccent : this.theme.textInverse)
                  .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                  .backgroundColor(this.state.status === FocusState.RUNNING ? this.theme.surfaceLowest : $r('app.color.timeisland_overlay_capsule_idle'))
                  .borderRadius(4)
              }

              Text(this.state.status === FocusState.FLOW_DRIFT ? $r('app.string.timeisland_drift_active_subnote') : $r('app.string.timeisland_theme_flow_ready'))
                .fontSize(9)
                .fontColor(this.state.status === FocusState.RUNNING ? this.theme.textMuted : this.theme.textInverse)
                .opacity(0.85)
            }
            .alignItems(HorizontalAlign.Start)
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')
          .height('100%')
          .padding({ left: 16, right: 16 })
        }
        .width('100%')
        .height('100%')
      }
      .layoutWeight(1)
      .height(54)
      .backgroundColor(this.state.status === FocusState.FLOW_DRIFT ? this.theme.havenAmber : (this.state.status === FocusState.RUNNING ? this.theme.surfaceIndigo : this.theme.primaryAccent))
      .border({
        width: 1,
        color: this.state.status === FocusState.FLOW_DRIFT ? this.theme.havenAmberBorder : (this.state.status === FocusState.RUNNING ? this.theme.borderCard : this.theme.primaryAccentGlow)
      })
      .shadow({
        radius: 24,
        color: this.state.status === FocusState.FLOW_DRIFT ? this.theme.havenAmber : (this.state.status === FocusState.RUNNING ? this.theme.runningGlow : this.theme.primaryGlow),
        offsetY: 4
      })
      .onClick(() => {
        soundEffectManager.play(SoundEffectType.PEN_CLICK);
        if (this.state.status === FocusState.IDLE) {
          this.vm.dispatch(FocusTimerIntent.startTimer());
          whiteNoiseManager.playSound(this.currentSoundId);
        } else if (this.state.status === FocusState.RUNNING) {
          this.vm.dispatch(FocusTimerIntent.pauseTimer());
          whiteNoiseManager.pause();
        } else if (this.state.status === FocusState.PAUSED) {
          this.vm.dispatch(FocusTimerIntent.resumeTimer());
          whiteNoiseManager.resume();
        } else if (this.state.status === FocusState.FLOW_DRIFT) {
          this.vm.dispatch(FocusTimerIntent.completeTimer());
          whiteNoiseManager.pause();
        }
      })

      // 3. 右侧控制按钮：专注态为息心止浪(防误触鉴权)，空闲态为翻转静心
      if (this.state.status === FocusState.RUNNING || this.state.status === FocusState.PAUSED) {
        Column({ space: 4 }) {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            Stack({ alignContent: Alignment.Center }) {
              Image($r('app.media.ic_close'))
                .width(20)
                .height(20)
                .fillColor(this.theme.havenAmber)
            }
            .width('100%')
            .height('100%')
          }
          .width(50)
          .height(50)
          .backgroundColor(this.theme.surfaceCard)
          .border({ width: 1, color: this.theme.havenAmberBorder })
          .shadow({ radius: 10, color: this.theme.shadowFloating, offsetY: 2 })
          .onClick(() => {
            soundEffectManager.play(SoundEffectType.PEN_CLICK);
            this.confirmAbandonFocus();
          })

          Text($r('app.string.timeisland_btn_give_up'))
            .fontSize(10)
            .fontColor(this.theme.havenAmber)
            .fontWeight(FontWeight.Medium)
        }
      } else {
        Column({ space: 4 }) {
          Button({ type: ButtonType.Circle, stateEffect: true }) {
            Stack({ alignContent: Alignment.Top }) {
              // LED 待命小微孔 (就绪时呈现翡翠绿辉光)
              Row()
                .width(5)
                .height(5)
                .borderRadius(2.5)
                .backgroundColor(this.zenFlipState === ZenFlipState.ARMED ? this.theme.primaryAccent : $r('app.color.timeisland_toggle_track_off'))
                .shadow(this.zenFlipState === ZenFlipState.ARMED ? { radius: 6, color: this.theme.primaryGlow, offsetY: 0 } : { radius: 0, color: Color.Transparent })
                .margin({ top: 5 })

              Image($r('app.media.ic_screen_rotation'))
                .width(22)
                .height(22)
                .fillColor(this.zenFlipState === ZenFlipState.ARMED ? this.theme.primaryAccent : this.theme.textSecondary)
                .margin({ top: 12 })
            }
            .width('100%')
            .height('100%')
          }
          .width(50)
          .height(50)
          .backgroundColor(this.theme.surfaceCard)
          .border({ width: 1, color: this.zenFlipState === ZenFlipState.ARMED ? this.theme.primaryAccent : this.theme.borderSubtle })
          .shadow({ radius: 10, color: this.zenFlipState === ZenFlipState.ARMED ? this.theme.primaryGlow : this.theme.shadowFloating, offsetY: 2 })
          .onClick(() => {
            if (this.zenFlipState === ZenFlipState.ARMED) {
              soundEffectManager.play(SoundEffectType.SWITCH_CLOSE);
              zenFlipSensorManager.disarmZenFlip();
            } else {
              soundEffectManager.play(SoundEffectType.SWITCH_OPEN);
              const armed = zenFlipSensorManager.armZenFlip();
              if (armed) {
                hapticFeedbackHelper.trigger('tick');
                DialogHelper.showToast($r('app.string.zen_flip_toast_armed'));
              }
            }
          })

          Text(this.zenFlipState === ZenFlipState.ARMED ? $r('app.string.zen_flip_status_armed') : $r('app.string.timeisland_zen_flip'))
            .fontSize(10)
            .fontColor(this.zenFlipState === ZenFlipState.ARMED ? this.theme.primaryAccent : this.theme.textSecondary)
            .fontWeight(FontWeight.Medium)
        }
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: 4, bottom: 4 })
  }

  /**
   * 白噪音快捷选择抽屉 (1:1 还原 Stitch 触感卡片)
   */
  @Builder
  private buildWhiteNoiseDrawer() {
    Row({ space: 10 }) {
      // 1. 海潮晚风艺术卡片
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Stack({ alignContent: Alignment.Center }) {
          // 高清艺术封面底图
          Image($r('app.media.bg_sound_tide'))
            .width('100%')
            .height(68)
            .objectFit(ImageFit.Cover)
            .borderRadius(14)
          // 磨砂暗色渐变蒙层
          Column()
            .width('100%')
            .height(68)
            .borderRadius(14)
            .backgroundColor(this.currentSoundId === 'tide' ? $r('app.color.timeisland_sound_tide_bg') : $r('app.color.timeisland_sound_card_dark_mask'))

          Column({ space: 4 }) {
            Image($r('app.media.ic_water_drop'))
              .width(20)
              .height(20)
              .fillColor(this.currentSoundId === 'tide' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_text_primary'))
            Text($r('app.string.timeisland_sound_tide'))
              .fontSize(11)
              .fontColor($r('app.color.timeisland_text_primary'))
              .fontWeight(this.currentSoundId === 'tide' ? FontWeight.Bold : FontWeight.Medium)
              .shadow({ radius: 4, color: $r('app.color.timeisland_sound_text_shadow'), offsetY: 1 })
          }
        }
      }
      .layoutWeight(1)
      .height(68)
      .borderRadius(14)
      .border({
        width: this.currentSoundId === 'tide' ? 2 : 1,
        color: this.currentSoundId === 'tide' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_sound_border_idle')
      })
      .shadow(this.currentSoundId === 'tide' ? {
        radius: 12,
        color: $r('app.color.timeisland_sound_glow_active'),
        offsetY: 2
      } : { radius: 0, color: Color.Transparent })
      .onClick(() => {
        this.currentSoundId = 'tide';
        soundEffectManager.play(SoundEffectType.BUBBLE);
        if (this.state.status === FocusState.RUNNING || this.state.status === FocusState.FLOW_DRIFT) {
          whiteNoiseManager.playSound('tide');
        }
        DialogHelper.showToast($r('app.string.timeisland_sound_tide'));
      })

      // 2. 雨落青苔艺术卡片
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Stack({ alignContent: Alignment.Center }) {
          // 高清艺术封面底图
          Image($r('app.media.bg_sound_rain'))
            .width('100%')
            .height(68)
            .objectFit(ImageFit.Cover)
            .borderRadius(14)
          // 磨砂暗色渐变蒙层
          Column()
            .width('100%')
            .height(68)
            .borderRadius(14)
            .backgroundColor(this.currentSoundId === 'moss_rain' ? $r('app.color.timeisland_sound_rain_bg') : $r('app.color.timeisland_sound_card_dark_mask'))

          Column({ space: 4 }) {
            Image($r('app.media.ic_rain'))
              .width(20)
              .height(20)
              .fillColor(this.currentSoundId === 'moss_rain' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_text_primary'))
            Text($r('app.string.timeisland_sound_moss_rain'))
              .fontSize(11)
              .fontColor($r('app.color.timeisland_text_primary'))
              .fontWeight(this.currentSoundId === 'moss_rain' ? FontWeight.Bold : FontWeight.Medium)
              .shadow({ radius: 4, color: $r('app.color.timeisland_sound_text_shadow'), offsetY: 1 })
          }
        }
      }
      .layoutWeight(1)
      .height(68)
      .borderRadius(14)
      .border({
        width: this.currentSoundId === 'moss_rain' ? 2 : 1,
        color: this.currentSoundId === 'moss_rain' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_sound_border_idle')
      })
      .shadow(this.currentSoundId === 'moss_rain' ? {
        radius: 12,
        color: $r('app.color.timeisland_sound_glow_active'),
        offsetY: 2
      } : { radius: 0, color: Color.Transparent })
      .onClick(() => {
        this.currentSoundId = 'moss_rain';
        soundEffectManager.play(SoundEffectType.BUBBLE);
        if (this.state.status === FocusState.RUNNING || this.state.status === FocusState.FLOW_DRIFT) {
          whiteNoiseManager.playSound('moss_rain');
        }
        DialogHelper.showToast($r('app.string.timeisland_sound_moss_rain'));
      })

      // 3. 林涧清泉艺术卡片
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Stack({ alignContent: Alignment.Center }) {
          // 高清艺术封面底图
          Image($r('app.media.bg_sound_spring'))
            .width('100%')
            .height(68)
            .objectFit(ImageFit.Cover)
            .borderRadius(14)
          // 磨砂暗色渐变蒙层
          Column()
            .width('100%')
            .height(68)
            .borderRadius(14)
            .backgroundColor(this.currentSoundId === 'forest_spring' ? $r('app.color.timeisland_sound_spring_bg') : $r('app.color.timeisland_sound_card_dark_mask'))

          Column({ space: 4 }) {
            Image($r('app.media.ic_forest'))
              .width(20)
              .height(20)
              .fillColor(this.currentSoundId === 'forest_spring' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_text_primary'))
            Text($r('app.string.timeisland_sound_forest_spring'))
              .fontSize(11)
              .fontColor($r('app.color.timeisland_text_primary'))
              .fontWeight(this.currentSoundId === 'forest_spring' ? FontWeight.Bold : FontWeight.Normal)
              .shadow({ radius: 4, color: $r('app.color.timeisland_sound_text_shadow'), offsetY: 1 })
          }
        }
      }
      .layoutWeight(1)
      .height(68)
      .borderRadius(14)
      .border({
        width: this.currentSoundId === 'forest_spring' ? 2 : 1,
        color: this.currentSoundId === 'forest_spring' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_sound_border_idle')
      })
      .shadow(this.currentSoundId === 'forest_spring' ? {
        radius: 12,
        color: $r('app.color.timeisland_sound_glow_active'),
        offsetY: 2
      } : { radius: 0, color: Color.Transparent })
      .onClick(() => {
        this.currentSoundId = 'forest_spring';
        soundEffectManager.play(SoundEffectType.BUBBLE);
        if (this.state.status === FocusState.RUNNING || this.state.status === FocusState.FLOW_DRIFT) {
          whiteNoiseManager.playSound('forest_spring');
        }
        DialogHelper.showToast($r('app.string.timeisland_sound_forest_spring'));
      })
    }
    .width('100%')
    .padding(8)
    .backgroundColor($r('app.color.timeisland_surface_lowest'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.timeisland_border_drawer') })
  }

  /**
   * 底部四大禅意导航栏 (专注 / 生态 / 气韵 / 星闪) - 1:1 还原设计稿图标与胶囊底座
   */
  @Builder
  private buildBottomNavBar() {
    Row() {
      // 1. 专注 Tab
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Column({ space: 3 }) {
          Image($r('app.media.ic_timelapse'))
            .width(22)
            .height(22)
            .fillColor(this.activeTab === 'focus' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_text_muted'))
          Text($r('app.string.timeisland_tab_focus'))
            .fontSize(11)
            .fontColor(this.activeTab === 'focus' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_text_muted'))
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      }
      .backgroundColor(this.activeTab === 'focus' ? $r('app.color.timeisland_tab_active_bg') : Color.Transparent)
      .borderRadius(18)
      .onClick(() => {
        soundEffectManager.play(SoundEffectType.BUBBLE);
        this.activeTab = 'focus';
      })

      // 2. 生态 Tab
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Column({ space: 3 }) {
          Image($r('app.media.ic_landscape'))
            .width(22)
            .height(22)
            .fillColor(this.activeTab === 'biome' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_text_muted'))
          Text($r('app.string.timeisland_tab_biome'))
            .fontSize(11)
            .fontColor(this.activeTab === 'biome' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_text_muted'))
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      }
      .backgroundColor(this.activeTab === 'biome' ? $r('app.color.timeisland_tab_active_bg') : Color.Transparent)
      .borderRadius(18)
      .onClick(() => {
        soundEffectManager.play(SoundEffectType.BUBBLE);
        this.activeTab = 'biome';
      })

      // 3. 气韵 Tab (跳转统计分析页)
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Column({ space: 3 }) {
          Image($r('app.media.ic_analytics'))
            .width(22)
            .height(22)
            .fillColor(this.activeTab === 'stats' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_text_muted'))
          Text($r('app.string.timeisland_tab_stats'))
            .fontSize(11)
            .fontColor(this.activeTab === 'stats' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_text_muted'))
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 16, right: 16, top: 6, bottom: 6 })
      }
      .backgroundColor(this.activeTab === 'stats' ? $r('app.color.timeisland_tab_active_bg') : Color.Transparent)
      .borderRadius(18)
      .onClick(() => {
        soundEffectManager.play(SoundEffectType.BUBBLE);
        this.activeTab = 'stats';
      })

      // 4. 星闪 Tab (由设置中心 isNearlinkEnabled 联动控制)
      if (this.isNearlinkEnabled) {
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Column({ space: 3 }) {
            Image($r('app.media.ic_nearlink'))
              .width(22)
              .height(22)
              .fillColor(this.activeTab === 'nearlink' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_text_muted'))
            Text($r('app.string.timeisland_tab_nearlink'))
              .fontSize(11)
              .fontColor(this.activeTab === 'nearlink' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_text_muted'))
              .fontWeight(FontWeight.Medium)
          }
          .padding({ left: 16, right: 16, top: 6, bottom: 6 })
        }
        .backgroundColor(this.activeTab === 'nearlink' ? $r('app.color.timeisland_tab_active_bg') : Color.Transparent)
        .borderRadius(18)
        .onClick(() => {
          soundEffectManager.play(SoundEffectType.BUBBLE);
          this.activeTab = 'nearlink';
        })
      }
    }
    .width('100%')
    .height(68 + (this.bottomNavHeight > 0 ? this.bottomNavHeight : 0))
    .padding({ bottom: this.bottomNavHeight > 0 ? this.bottomNavHeight : 6 })
    .justifyContent(FlexAlign.SpaceAround)
    .backgroundColor(this.theme.bgCanvas)
    .shadow({ radius: 16, color: this.theme.shadowCard, offsetY: -4 })
  }
}

/**
 * 页面独立预览组件
 */
@Preview
@Component
struct TimeIslandHomePagePreview {
  build() {
    TimeIslandHomePage()
  }
}
