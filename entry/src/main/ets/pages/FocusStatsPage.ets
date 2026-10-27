import { FocusStatsView } from '../components/FocusStatsView';
import { ThemePalette, ThemeMode } from '../theme/ThemeTypes';
import { themeManager } from '../theme/ThemeManager';
import { soundEffectManager, SoundEffectType } from '../utils/SoundEffectManager';

/**
 * 统计页面路由分发器 Builder 声明
 */
@Builder
export function FocusStatsPageBuilder() {
  FocusStatsPage()
}

/**
 * 时光岛 - 心流统计与历史流水独立页面 (FocusStatsPage)
 * 职责: 承载全场景心流气韵看板，对齐全局无框返回与生境主题自适应
 */
@Entry
@Component
struct FocusStatsPage {
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('bottomNavHeight') bottomNavHeight: number = 0;
  @StorageProp('currentTheme') theme: ThemePalette = themeManager.getPaletteByMode(ThemeMode.DARK);

  build() {
    Column() {
      // 1. 顶部沉浸式导航条 (严格对齐全局规范：无框返回键 + 靠左标题)
      this.buildHeader()

      // 2. 统计看板主体滚动视窗
      Scroll() {
        Column() {
          FocusStatsView()
          Blank().height(16 + (this.bottomNavHeight > 0 ? this.bottomNavHeight : 0))
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 4, bottom: 20 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring)
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
          .width(20)
          .height(20)
          .fillColor(this.theme.textPrimary)
      }
      .width(36)
      .height(36)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        soundEffectManager.play(SoundEffectType.PEN_CLICK);
        this.getUIContext().getRouter().back();
      })

      Text($r('app.string.timeisland_nav_stats'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textPrimary)
        .margin({ left: 10 })

      Blank()
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: (this.statusBarHeight > 0 ? this.statusBarHeight : 0) + 10,
      bottom: 8
    })
  }
}
