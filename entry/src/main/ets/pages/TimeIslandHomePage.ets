import { DialogHelper } from '@app/common';
import { FocusState, FocusTag } from '../model/FocusTypes';
import { FocusTimerViewModel, FocusTimerIntent, FocusTimerEffect, FocusTimerState } from '../viewmodel/FocusTimerViewModel';
import { FocusRingView } from '../components/FocusRingView';
import { TagSelectorView } from '../components/TagSelectorView';
import { TimeDurationSelector } from '../components/TimeDurationSelector';
import { ThemeSelectorDialog } from '../components/ThemeSelectorDialog';
import { ThemePalette, ThemeMode } from '../theme/ThemeTypes';
import { themeManager } from '../theme/ThemeManager';
import { router } from '@kit.ArkUI';

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
  private vm: FocusTimerViewModel = new FocusTimerViewModel();
  @State private state: FocusTimerState = this.vm.state;
  @State private isLiveViewEnabled: boolean = true;
  @State private activeTab: string = 'focus';
  @State private isSoundDrawerOpen: boolean = false;
  @State private currentSoundId: string = 'tide';
  @State private isThemeDialogOpen: boolean = false;

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
  }

  aboutToDisappear(): void {
    this.vm.onCleared();
  }

  private handleEffect(effect: FocusTimerEffect): void {
    if (effect.type === 'SHOW_TOAST') {
      if (effect.messageKey === 'timeisland_toast_focus_completed') {
        DialogHelper.showToast($r('app.string.timeisland_toast_focus_completed'));
      } else if (effect.messageKey === 'timeisland_toast_give_up') {
        DialogHelper.showToast($r('app.string.timeisland_toast_give_up'));
      } else if (effect.messageKey === 'timeisland_toast_cannot_change_duration') {
        DialogHelper.showToast($r('app.string.timeisland_toast_cannot_change_duration'));
      }
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      // 主内容滚动视窗
      Scroll() {
        Column({ space: 14 }) {
          // 1. 顶部 Header 与品牌标识
          this.buildTopHeader()

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

          // 8. 实况窗生态联动卡片
          this.buildLiveViewCard()

          // 占位垫底，避免被底部导航遮挡 (动态避让手势安全区)
          Blank().height(80 + (this.bottomNavHeight > 0 ? this.bottomNavHeight : 0))
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 20 })
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
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bgCanvas)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
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
      }

      Blank()

      Row({ space: 8 }) {
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
      // 深潜心流态
      Row({ space: 6 }) {
        Circle()
          .width(6)
          .height(6)
          .fill($r('app.color.timeisland_emerald'))
          .shadow({ radius: 8, color: this.theme.primaryGlow, offsetY: 0 })
        Text($r('app.string.timeisland_status_flow_drift'))
          .fontSize(11)
          .fontColor($r('app.color.timeisland_emerald'))
          .fontWeight(FontWeight.Medium)
      }
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor($r('app.color.timeisland_flow_bg'))
      .borderRadius(14)
      .border({ width: 1, color: $r('app.color.timeisland_emerald_border') })

      Blank()

      // 120s 避风港守护
      Row({ space: 5 }) {
        Image($r('app.media.ic_shield_check'))
          .width(13)
          .height(13)
          .fillColor($r('app.color.timeisland_haven_amber'))
        Text($r('app.string.timeisland_status_grace_haven'))
          .fontSize(11)
          .fontColor($r('app.color.timeisland_haven_amber'))
          .fontWeight(FontWeight.Medium)
      }
      .padding({ left: 10, right: 10, top: 5, bottom: 5 })
      .backgroundColor($r('app.color.timeisland_haven_amber_bg'))
      .borderRadius(14)
      .border({ width: 1, color: $r('app.color.timeisland_haven_amber_border') })
    }
    .width('100%')
  }

  /**
   * 核心三段式操作控制中枢 (1:1 还原 Stitch 设计稿)
   */
  @Builder
  private buildActionControls() {
    Row({ space: 14 }) {
      // 1. 左侧环境音按钮 (带抽屉切换)
      Column({ space: 4 }) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          Image($r('app.media.ic_air'))
            .width(22)
            .height(22)
            .fillColor(this.isSoundDrawerOpen ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_text_secondary'))
        }
        .width(48)
        .height(48)
        .backgroundColor($r('app.color.timeisland_surface_low'))
        .border({ width: 1, color: this.isSoundDrawerOpen ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_border_subtle') })
        .shadow({ radius: 10, color: this.theme.shadowFloating, offsetY: 2 })
        .onClick(() => {
          this.isSoundDrawerOpen = !this.isSoundDrawerOpen;
        })

        Text(this.getCurrentSoundRes())
          .fontSize(11)
          .fontColor($r('app.color.timeisland_text_secondary'))
      }

      // 2. 中间巨幅流光主胶囊按钮 (启航心流 / 停靠息心)
      Button({ type: ButtonType.Capsule, stateEffect: true }) {
        Row({ space: 8 }) {
          Image(this.state.status === FocusState.RUNNING ? $r('app.media.ic_pause') : $r('app.media.ic_explore'))
            .width(22)
            .height(22)
            .fillColor(this.state.status === FocusState.RUNNING ? $r('app.color.timeisland_text_primary') : $r('app.color.timeisland_text_inverse'))

          Text(this.state.status === FocusState.RUNNING ? $r('app.string.timeisland_btn_dock') : $r('app.string.timeisland_btn_start'))
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.state.status === FocusState.RUNNING ? $r('app.color.timeisland_text_primary') : $r('app.color.timeisland_text_inverse'))
        }
        .justifyContent(FlexAlign.Center)
        .width('100%')
      }
      .layoutWeight(1)
      .height(52)
      .backgroundColor(this.state.status === FocusState.RUNNING ? $r('app.color.timeisland_surface_indigo') : $r('app.color.timeisland_emerald'))
      .border({ width: 1, color: this.state.status === FocusState.RUNNING ? $r('app.color.timeisland_lake_blue_border') : $r('app.color.timeisland_emerald_glow') })
      .shadow({
        radius: 20,
        color: this.state.status === FocusState.RUNNING ? this.theme.runningGlow : this.theme.primaryGlow,
        offsetY: 4
      })
      .onClick(() => {
        if (this.state.status === FocusState.IDLE) {
          this.vm.dispatch(FocusTimerIntent.startTimer());
        } else if (this.state.status === FocusState.RUNNING) {
          this.vm.dispatch(FocusTimerIntent.pauseTimer());
        } else if (this.state.status === FocusState.PAUSED) {
          this.vm.dispatch(FocusTimerIntent.resumeTimer());
        }
      })

      // 3. 右侧翻转勿扰按钮
      Column({ space: 4 }) {
        Button({ type: ButtonType.Circle, stateEffect: true }) {
          Image($r('app.media.ic_screen_rotation'))
            .width(22)
            .height(22)
            .fillColor($r('app.color.timeisland_text_secondary'))
        }
        .width(48)
        .height(48)
        .backgroundColor($r('app.color.timeisland_surface_low'))
        .border({ width: 1, color: $r('app.color.timeisland_border_subtle') })
        .shadow({ radius: 10, color: this.theme.shadowFloating, offsetY: 2 })
        .onClick(() => {
          DialogHelper.showToast($r('app.string.timeisland_zen_flip'));
        })

        Text($r('app.string.timeisland_zen_flip'))
          .fontSize(11)
          .fontColor($r('app.color.timeisland_text_secondary'))
      }
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ top: 4, bottom: 4 })
  }

  /**
   * 白噪音快捷选择抽屉 (1:1 还原设计稿 Discreet Zen Drawer)
   */
  @Builder
  private buildWhiteNoiseDrawer() {
    Row({ space: 12 }) {
      // 1. 海潮晚风
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Column({ space: 4 }) {
          Image($r('app.media.ic_water'))
            .width(20)
            .height(20)
            .fillColor(this.currentSoundId === 'tide' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_text_muted'))
          Text($r('app.string.timeisland_sound_tide'))
            .fontSize(11)
            .fontColor(this.currentSoundId === 'tide' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_text_muted'))
        }
        .padding({ top: 8, bottom: 8 })
      }
      .layoutWeight(1)
      .backgroundColor(this.currentSoundId === 'tide' ? $r('app.color.timeisland_surface_indigo') : $r('app.color.timeisland_surface_card'))
      .borderRadius(14)
      .border({ width: 1, color: this.currentSoundId === 'tide' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_drawer_item_border') })
      .onClick(() => {
        this.currentSoundId = 'tide';
        DialogHelper.showToast($r('app.string.timeisland_sound_tide'));
      })

      // 2. 雨落青苔
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Column({ space: 4 }) {
          Image($r('app.media.ic_rain'))
            .width(20)
            .height(20)
            .fillColor(this.currentSoundId === 'moss_rain' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_text_muted'))
          Text($r('app.string.timeisland_sound_moss_rain'))
            .fontSize(11)
            .fontColor(this.currentSoundId === 'moss_rain' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_text_muted'))
        }
        .padding({ top: 8, bottom: 8 })
      }
      .layoutWeight(1)
      .backgroundColor(this.currentSoundId === 'moss_rain' ? $r('app.color.timeisland_surface_indigo') : $r('app.color.timeisland_surface_card'))
      .borderRadius(14)
      .border({ width: 1, color: this.currentSoundId === 'moss_rain' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_drawer_item_border') })
      .onClick(() => {
        this.currentSoundId = 'moss_rain';
        DialogHelper.showToast($r('app.string.timeisland_sound_moss_rain'));
      })

      // 3. 林涧清泉
      Button({ type: ButtonType.Normal, stateEffect: true }) {
        Column({ space: 4 }) {
          Image($r('app.media.ic_forest'))
            .width(20)
            .height(20)
            .fillColor(this.currentSoundId === 'forest_spring' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_text_muted'))
          Text($r('app.string.timeisland_sound_forest_spring'))
            .fontSize(11)
            .fontColor(this.currentSoundId === 'forest_spring' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_text_muted'))
        }
        .padding({ top: 8, bottom: 8 })
      }
      .layoutWeight(1)
      .backgroundColor(this.currentSoundId === 'forest_spring' ? $r('app.color.timeisland_surface_indigo') : $r('app.color.timeisland_surface_card'))
      .borderRadius(14)
      .border({ width: 1, color: this.currentSoundId === 'forest_spring' ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_drawer_item_border') })
      .onClick(() => {
        this.currentSoundId = 'forest_spring';
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
   * 实况窗联动预览卡片 (1:1 还原设计稿 HarmonyOS NEXT Live View Droplet)
   */
  @Builder
  private buildLiveViewCard() {
    Row() {
      Row({ space: 12 }) {
        Stack({ alignContent: Alignment.Center }) {
          Circle()
            .width(36)
            .height(36)
            .fill($r('app.color.timeisland_live_icon_bg'))
          Image($r('app.media.ic_motion_blur'))
            .width(20)
            .height(20)
            .fillColor($r('app.color.timeisland_lake_blue_light'))
        }

        Column({ space: 3 }) {
          Row({ space: 6 }) {
            Text($r('app.string.timeisland_live_view_title'))
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.timeisland_text_primary'))
            Text($r('app.string.timeisland_live_view_tag'))
              .fontSize(9)
              .fontColor($r('app.color.timeisland_emerald'))
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor($r('app.color.timeisland_emerald_bg'))
              .borderRadius(8)
          }
          Text($r('app.string.timeisland_live_view_desc'))
            .fontSize(11)
            .fontColor($r('app.color.timeisland_text_muted'))
        }
        .alignItems(HorizontalAlign.Start)
      }

      Blank()

      // 切换指示微圆角开关胶囊
      Row() {
        Circle()
          .width(16)
          .height(16)
          .fill(this.isLiveViewEnabled ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_text_muted'))
          .shadow(this.isLiveViewEnabled ? { radius: 6, color: this.theme.primaryGlow, offsetY: 0 } : { radius: 0, color: Color.Transparent })
      }
      .width(36)
      .height(20)
      .borderRadius(10)
      .backgroundColor(this.isLiveViewEnabled ? $r('app.color.timeisland_emerald_bg') : $r('app.color.timeisland_surface_low'))
      .border({ width: 1, color: this.isLiveViewEnabled ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_border_subtle') })
      .justifyContent(this.isLiveViewEnabled ? FlexAlign.End : FlexAlign.Start)
      .padding(2)
      .onClick(() => {
        this.isLiveViewEnabled = !this.isLiveViewEnabled;
      })
    }
    .width('100%')
    .padding(14)
    .backgroundColor($r('app.color.timeisland_surface_card'))
    .borderRadius(16)
    .border({ width: 1, color: $r('app.color.timeisland_border_card') })
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
        DialogHelper.showToast($r('app.string.timeisland_tab_biome_toast'));
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
        DialogHelper.showToast($r('app.string.timeisland_tab_nearlink_toast'));
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
