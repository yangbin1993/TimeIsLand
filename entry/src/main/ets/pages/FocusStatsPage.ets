import { FocusStatsView } from '../components/FocusStatsView';

/**
 * 统计页面路由分发器 Builder 声明
 */
@Builder
export function FocusStatsPageBuilder() {
  FocusStatsPage()
}

/**
 * 时光岛 - 心流统计与历史流水独立页面 (备用独立路由容器)
 */
@Entry
@Component
struct FocusStatsPage {
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;

  build() {
    Column() {
      // 独立页面顶部返回导航条
      Row() {
        Button({ type: ButtonType.Circle }) {
          Image($r('app.media.ic_arrow_back'))
            .width(18)
            .height(18)
            .fillColor($r('app.color.timeisland_text_primary'))
        }
        .backgroundColor($r('app.color.timeisland_surface_low'))
        .border({ width: 1, color: $r('app.color.timeisland_border_subtle') })
        .width(36)
        .height(36)
        .onClick(() => {
          this.getUIContext().getRouter().back();
        })

        Text($r('app.string.timeisland_nav_stats'))
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.timeisland_text_primary'))
          .margin({ left: 12 })

        Blank()
      }
      .width('100%')
      .padding({
        left: 16,
        right: 16,
        top: this.statusBarHeight > 0 ? this.statusBarHeight : 12,
        bottom: 8
      })

      Scroll() {
        FocusStatsView()
          .padding({ left: 16, right: 16, bottom: 20 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.timeisland_bg_canvas'))
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }
}

/**
 * 统计页面独立预览组件
 */
@Preview
@Component
struct FocusStatsPagePreview {
  build() {
    FocusStatsPage()
  }
}
