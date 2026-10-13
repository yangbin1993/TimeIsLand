import { DialogHelper, BreakpointType } from '@app/common';
import { FocusState, FocusTag } from '../model/FocusTypes';
import { FocusTimerViewModel, FocusTimerIntent, FocusTimerEffect, FocusTimerState } from '../viewmodel/FocusTimerViewModel';
import { FocusRingView } from '../components/FocusRingView';
import { IslandBiomeView } from '../components/IslandBiomeView';
import { TagSelectorView } from '../components/TagSelectorView';
import { TimeDurationSelector } from '../components/TimeDurationSelector';
import { ThemeSelectorDialog } from '../components/ThemeSelectorDialog';
import { NearLinkSanctuaryDialog } from '../components/NearLinkSanctuaryDialog';
import { nearLinkSanctuaryManager, NearLinkSanctuaryState, PartnerIslandInfo } from '../utils/NearLinkSanctuaryManager';
import { ThemePalette, ThemeMode } from '../theme/ThemeTypes';
import { themeManager } from '../theme/ThemeManager';
import { router } from '@kit.ArkUI';
import { soundEffectManager, SoundEffectType } from '../utils/SoundEffectManager';
import { whiteNoiseManager, WhiteNoiseType } from '../utils/WhiteNoiseManager';
import { widgetSyncManager } from '../utils/WidgetSyncManager';

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
  @State private activeTab: string = 'focus';
  @State private isSoundDrawerOpen: boolean = false;
  @State private currentSoundId: string = 'tide';
  @State private isThemeDialogOpen: boolean = false;
  @State private isNearLinkDialogOpen: boolean = false;
  @State private partnerInfo: PartnerIslandInfo | null = null;
  @State private dualPaneMode: string = 'compass';

  private getCurrentSoundRes(): Resource {
    if (this.currentSoundId === 'moss_rain') {
      return $r('app.string.timeisland_sound_moss_rain');
    } else if (this.currentSoundId === 'forest_spring') {
      return $r('app.string.timeisland_sound_forest_spring');
    }
    return $r('app.string.timeisland_sound_tide');
  }

  aboutToAppear(): void {
    // 监听 MVI 副作用流
    this.vm.observeEffect((effect: FocusTimerEffect): void => {
      this.handleEffect(effect);
    });
    // 触发数据初始化
    this.vm.dispatch(FocusTimerIntent.initData());

    // 监听星闪双子岛伴读状态
    this.partnerInfo = nearLinkSanctuaryManager.getPartner();
    nearLinkSanctuaryManager.addStateListener((state: NearLinkSanctuaryState, partner: PartnerIslandInfo | null): void => {
      this.partnerInfo = partner;
    });
  }

  onPageShow(): void {
    // 响应来自桌面原子化卡片的一键起航参数
    const quickMins = AppStorage.get<number>('cardQuickStartMinutes');
    if (quickMins && quickMins > 0) {
      AppStorage.setOrCreate('cardQuickStartMinutes', 0);
      this.vm.dispatch(FocusTimerIntent.selectDuration(quickMins));
      this.vm.dispatch(FocusTimerIntent.startTimer());
      whiteNoiseManager.playSound(this.vm.state.selectedNoiseId);
    }
  }

  aboutToDisappear(): void {
    this.vm.onCleared();
  }

  private handleEffect(effect: FocusTimerEffect): void {
    if (effect.type === 'SHOW_TOAST') {
      if (effect.messageKey === 'timeisland_toast_focus_completed') {
        whiteNoiseManager.pause();
        DialogHelper.showToast($r('app.string.timeisland_toast_focus_completed'));
        // 实时触发桌面元服务原子化卡片数据同步跳变
        widgetSyncManager.syncFocusDataToWidgets(
          getContext(this),
          this.state.todayTotalMinutes,
          this.state.todayCompletedCount,
          this.state.currentTag?.name || 'Flow'
        ).catch(() => {});
      } else if (effect.messageKey === 'timeisland_toast_give_up') {
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
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 主内容滚动视窗
      Scroll() {
        Column({ space: 14 }) {
          // 1. 顶部 Header 与品牌标识
          this.buildTopHeader()

          if (this.isFoldExpanded || this.currentBreakpoint !== 'sm') {
            // 折叠屏展开态 / 平板大屏：8 列双栏自适应心流大画布 (Stitch 1:1 还原)
            this.buildDualPaneLayout()
          } else {
            // 常规手机与折叠屏外屏：单列纵向沉浸流线
            this.buildSinglePaneLayout()
          }

          // 占位垫底，避免被底部导航遮挡 (动态避让手势安全区)
          Blank().height(80 + (this.bottomNavHeight > 0 ? this.bottomNavHeight : 0))
        }
        .width('100%')
        .padding({
          left: (this.isFoldExpanded || this.currentBreakpoint !== 'sm') ? 20 : 16,
          right: (this.isFoldExpanded || this.currentBreakpoint !== 'sm') ? 20 : 16,
          top: 12,
          bottom: 20
        })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .height('100%')

      // 9. 底部常驻禅意导航栏
      this.buildBottomNavBar()

      // 10. 生境主题流转切换弹窗
      ThemeSelectorDialog({
        visible: this.isThemeDialogOpen,
        onClose: () => {
          this.isThemeDialogOpen = false;
        }
      })

      // 11. 星闪近场双子岛伴读弹窗
      if (this.isNearLinkDialogOpen) {
        Column() {
          Blank()
            .onClick(() => {
              this.isNearLinkDialogOpen = false;
            })
          NearLinkSanctuaryDialog({
            theme: this.theme,
            isOpen: $isNearLinkDialogOpen
          })
        }
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .zIndex(99)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bgCanvas)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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
          todayMinutes: this.state.todayTotalMinutes,
          focusState: this.state.status,
          isFlowDrift: this.state.status === FocusState.FLOW_DRIFT
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

        // 4. 时长选择胶囊
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

  /**
   * 折叠屏左栏：星闪近场共鸣伙伴陪伴卡片
   */
  @Builder
  private buildNearLinkCompanionCard() {
    Row({ space: 10 }) {
      Image($r('app.media.ic_nearlink'))
        .width(20)
        .height(20)
        .fillColor(this.partnerInfo ? this.theme.primaryAccent : this.theme.textMuted)

      Column({ space: 2 }) {
        Row({ space: 6 }) {
          Text(this.partnerInfo ? this.partnerInfo.islandName : $r('app.string.foldable_nearlink_companion'))
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.textPrimary)

          Text(this.partnerInfo ? $r('app.string.nearlink_partner_focusing') : $r('app.string.timeisland_tag_read'))
            .fontSize(9)
            .fontColor(this.theme.primaryAccent)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .backgroundColor(this.theme.primaryAccentBg)
            .borderRadius(4)
        }

        Text(this.partnerInfo ? $r('app.string.foldable_nearlink_companion_sub') : $r('app.string.nearlink_desc'))
          .fontSize(10)
          .fontColor(this.theme.textMuted)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)

      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        Text(this.partnerInfo ? $r('app.string.nearlink_send_ripple') : $r('app.string.nearlink_title'))
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.primaryAccent)
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
      }
      .backgroundColor(this.theme.primaryAccentBg)
      .border({ width: 1, color: this.theme.primaryAccentGlow })
      .onClick(() => {
        if (this.partnerInfo) {
          soundEffectManager.play(SoundEffectType.BUBBLE);
          nearLinkSanctuaryManager.sendRippleToPartner();
          DialogHelper.showToast($r('app.string.nearlink_ripple_sent'));
        } else {
          this.isNearLinkDialogOpen = true;
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
            Circle({ width: 5, height: 5 })
              .fill(this.theme.primaryAccent)
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

      Row({ space: 8 }) {
        // 星闪近场双子岛入口
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          Image($r('app.media.ic_nearlink'))
            .width(18)
            .height(18)
            .fillColor(this.theme.primaryAccent)
        }
        .width(32)
        .height(32)
        .backgroundColor(this.theme.surfaceLow)
        .border({ width: 1, color: this.theme.borderSubtle })
        .onClick(() => {
          soundEffectManager.play(SoundEffectType.PEN_CLICK);
          this.isNearLinkDialogOpen = true;
        })

        // 生境主题切换入口
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          Image($r('app.media.ic_palette'))
            .width(18)
            .height(18)
            .fillColor(this.theme.primaryAccent)
        }
        .width(32)
        .height(32)
        .backgroundColor(this.theme.surfaceLow)
        .border({ width: 1, color: this.theme.borderSubtle })
        .onClick(() => {
          this.isThemeDialogOpen = true;
        })

        // 系统生态偏好设置入口
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          Image($r('app.media.ic_settings'))
            .width(18)
            .height(18)
            .fillColor(this.theme.textSecondary)
        }
        .width(32)
        .height(32)
        .backgroundColor(this.theme.surfaceLow)
        .border({ width: 1, color: this.theme.borderSubtle })
        .onClick(() => {
          router.pushUrl({ url: 'pages/TimeIslandSettingsPage' });
        })

        // 右侧气韵历史入口
        Button({ type: ButtonType.Normal, stateEffect: true }) {
          Row({ space: 4 }) {
            Text($r('app.string.timeisland_tab_stats'))
              .fontSize(12)
              .fontColor(this.theme.textSecondary)
              .fontWeight(FontWeight.Medium)
          }
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
        }
        .backgroundColor(this.theme.surfaceLow)
        .borderRadius(16)
        .border({ width: 1, color: this.theme.borderSubtle })
        .onClick(() => {
          router.pushUrl({ url: 'pages/FocusStatsPage' });
        })
      }
    }
    .width('100%')
    .padding({ top: this.statusBarHeight > 0 ? this.statusBarHeight : 8, bottom: 4 })
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
              .backgroundColor(this.isSoundDrawerOpen ? this.theme.primaryAccent : '#475569')
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
            .backgroundColor('rgba(255, 255, 255, 0.45)')
            .margin({ top: 1 })

          // 核心按键内容
          Row({ space: 10 }) {
            // 左侧微晶高光圆形图标底座
            Stack({ alignContent: Alignment.Center }) {
              Row()
                .width(32)
                .height(32)
                .borderRadius(16)
                .backgroundColor(this.state.status === FocusState.FLOW_DRIFT ? 'rgba(255, 255, 255, 0.25)' : (this.state.status === FocusState.RUNNING ? 'rgba(255, 255, 255, 0.15)' : 'rgba(0, 0, 0, 0.2)'))

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
                  .backgroundColor(this.state.status === FocusState.RUNNING ? this.theme.surfaceLowest : 'rgba(0, 0, 0, 0.2)')
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

      // 3. 右侧双同心圆盘翻转勿扰按钮
      Column({ space: 4 }) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          Stack({ alignContent: Alignment.Top }) {
            // LED 待命小微孔
            Row()
              .width(5)
              .height(5)
              .borderRadius(2.5)
              .backgroundColor('#475569')
              .margin({ top: 5 })

            Image($r('app.media.ic_screen_rotation'))
              .width(22)
              .height(22)
              .fillColor(this.theme.textSecondary)
              .margin({ top: 12 })
          }
          .width('100%')
          .height('100%')
        }
        .width(50)
        .height(50)
        .backgroundColor(this.theme.surfaceCard)
        .border({ width: 1, color: this.theme.borderSubtle })
        .shadow({ radius: 10, color: this.theme.shadowFloating, offsetY: 2 })
        .onClick(() => {
          soundEffectManager.play(SoundEffectType.SWITCH_OPEN);
          DialogHelper.showToast($r('app.string.timeisland_zen_flip'));
        })

        Text($r('app.string.timeisland_zen_flip'))
          .fontSize(10)
          .fontColor(this.theme.textSecondary)
          .fontWeight(FontWeight.Medium)
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
      // 1. 海潮晚风
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Column({ space: 4 }) {
          Image($r('app.media.ic_water'))
            .width(20)
            .height(20)
            .fillColor(this.currentSoundId === 'tide' ? this.theme.primaryAccent : this.theme.textMuted)
          Text($r('app.string.timeisland_sound_tide'))
            .fontSize(11)
            .fontColor(this.currentSoundId === 'tide' ? this.theme.primaryAccent : this.theme.textMuted)
            .fontWeight(this.currentSoundId === 'tide' ? FontWeight.Bold : FontWeight.Normal)
        }
        .padding({ top: 8, bottom: 8 })
      }
      .layoutWeight(1)
      .backgroundColor(this.currentSoundId === 'tide' ? this.theme.surfaceIndigo : this.theme.surfaceCard)
      .borderRadius(14)
      .border({
        width: 1,
        color: this.currentSoundId === 'tide' ? this.theme.primaryAccent : this.theme.borderSubtle
      })
      .shadow(this.currentSoundId === 'tide' ? {
        radius: 10,
        color: this.theme.primaryGlow,
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

      // 2. 雨落青苔
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Column({ space: 4 }) {
          Image($r('app.media.ic_rain'))
            .width(20)
            .height(20)
            .fillColor(this.currentSoundId === 'moss_rain' ? this.theme.primaryAccent : this.theme.textMuted)
          Text($r('app.string.timeisland_sound_moss_rain'))
            .fontSize(11)
            .fontColor(this.currentSoundId === 'moss_rain' ? this.theme.primaryAccent : this.theme.textMuted)
            .fontWeight(this.currentSoundId === 'moss_rain' ? FontWeight.Bold : FontWeight.Normal)
        }
        .padding({ top: 8, bottom: 8 })
      }
      .layoutWeight(1)
      .backgroundColor(this.currentSoundId === 'moss_rain' ? this.theme.surfaceIndigo : this.theme.surfaceCard)
      .borderRadius(14)
      .border({
        width: 1,
        color: this.currentSoundId === 'moss_rain' ? this.theme.primaryAccent : this.theme.borderSubtle
      })
      .shadow(this.currentSoundId === 'moss_rain' ? {
        radius: 10,
        color: this.theme.primaryGlow,
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

      // 3. 林涧清泉
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Column({ space: 4 }) {
          Image($r('app.media.ic_forest'))
            .width(20)
            .height(20)
            .fillColor(this.currentSoundId === 'forest_spring' ? this.theme.primaryAccent : this.theme.textMuted)
          Text($r('app.string.timeisland_sound_forest_spring'))
            .fontSize(11)
            .fontColor(this.currentSoundId === 'forest_spring' ? this.theme.primaryAccent : this.theme.textMuted)
            .fontWeight(this.currentSoundId === 'forest_spring' ? FontWeight.Bold : FontWeight.Normal)
        }
        .padding({ top: 8, bottom: 8 })
      }
      .layoutWeight(1)
      .backgroundColor(this.currentSoundId === 'forest_spring' ? this.theme.surfaceIndigo : this.theme.surfaceCard)
      .borderRadius(14)
      .border({
        width: 1,
        color: this.currentSoundId === 'forest_spring' ? this.theme.primaryAccent : this.theme.borderSubtle
      })
      .shadow(this.currentSoundId === 'forest_spring' ? {
        radius: 10,
        color: this.theme.primaryGlow,
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
      .backgroundColor(this.activeTab === 'focus' ? $r('app.color.timeisland_tab_active_bg') : '#00000000')
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
      .backgroundColor(this.activeTab === 'biome' ? $r('app.color.timeisland_tab_active_bg') : '#00000000')
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
      .backgroundColor(this.activeTab === 'stats' ? $r('app.color.timeisland_tab_active_bg') : '#00000000')
      .borderRadius(18)
      .onClick(() => {
        router.pushUrl({ url: 'pages/FocusStatsPage' });
      })

      // 4. 星闪 Tab
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
      .backgroundColor(this.activeTab === 'nearlink' ? $r('app.color.timeisland_tab_active_bg') : '#00000000')
      .borderRadius(18)
      .onClick(() => {
        soundEffectManager.play(SoundEffectType.PEN_CLICK);
        this.isNearLinkDialogOpen = true;
      })
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
