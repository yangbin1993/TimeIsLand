import { FocusState } from '../model/FocusTypes';

/**
 * 时光岛 - 环形心流罗盘核心组件 (FocusRingView)
 * 深度复刻 Stitch 设计稿: 暗夜心流流光发光球体 + 天球同心刻度环
 */
@Component
export struct FocusRingView {
  @Prop progress: number = 0.0;
  @Prop timeText: string = '25:00';
  @Prop state: FocusState = FocusState.IDLE;
  @Prop tagColor: ResourceColor = $r('app.color.timeisland_emerald');
  @Prop tagName: string = '';

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 1. 底层环境泛光光晕 (在充足的 100% 容器内自然柔和发散，绝无切边)
      Row()
        .width(210)
        .height(210)
        .borderRadius(105)
        .backgroundColor(this.state === FocusState.FLOW_DRIFT ? $r('app.color.timeisland_haven_amber') : $r('app.color.timeisland_lake_blue_deep'))
        .opacity(this.state === FocusState.FLOW_DRIFT ? 0.38 : (this.state === FocusState.RUNNING ? 0.28 : 0.12))
        .blur(32)
        .animation({ duration: 1500, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate })

      // 2. 外圈天球罗盘精密虚线刻度环 (Outer Celestial Dashed Ring)
      Row()
        .width(250)
        .height(250)
        .borderRadius(125)
        .border({
          width: 1.5,
          color: this.state === FocusState.FLOW_DRIFT ? $r('app.color.timeisland_haven_amber') : $r('app.color.timeisland_lake_blue'),
          style: BorderStyle.Dashed
        })
        .opacity(this.state === FocusState.FLOW_DRIFT ? 0.65 : 0.45)

      // 3. 次圈破晓碧绿心流点阵刻度环 (Inner Emerald Flow Ticks)
      Row()
        .width(238)
        .height(238)
        .borderRadius(119)
        .border({
          width: 1,
          color: $r('app.color.timeisland_emerald'),
          style: BorderStyle.Dashed
        })
        .opacity(0.38)

      // 4. 外圈同心刻度轨道底环
      Progress({ value: 100, total: 100, type: ProgressType.Ring })
        .width(226)
        .height(226)
        .color($r('app.color.timeisland_compass_ring_track'))
        .style({ strokeWidth: 4 })

      // 5. 动态高光进度环 (湖蓝至破晓碧绿渐变感，心流延展时呈现流金辉光)
      Progress({ value: Math.round(this.progress * 100), total: 100, type: ProgressType.Ring })
        .width(226)
        .height(226)
        .color(this.state === FocusState.FLOW_DRIFT ? $r('app.color.timeisland_haven_amber') : (this.state === FocusState.RUNNING ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_lake_blue')))
        .style({ strokeWidth: 5 })
        .animation({ duration: 500, curve: Curve.FastOutSlowIn })

      // 6. 中心深蓝靛黑玻璃微透核心球体 (Center Glow Glass Sphere)
      Stack({ alignContent: Alignment.Center }) {
        // Stitch 原版晶莹微透水滴微光层 (Water-Drop Zen Aperture)
        Image($r('app.media.ic_water_drop'))
          .width(130)
          .height(130)
          .opacity(0.10)
          .fillColor(this.state === FocusState.FLOW_DRIFT ? $r('app.color.timeisland_haven_amber') : $r('app.color.timeisland_lake_blue_light'))
          .hitTestBehavior(HitTestMode.None)

        Column({ space: 6 }) {
          // 指南针微小定位发光点
          Row()
            .width(6)
            .height(6)
            .borderRadius(3)
            .backgroundColor(this.state === FocusState.FLOW_DRIFT ? $r('app.color.timeisland_haven_amber') : (this.state === FocusState.RUNNING ? this.tagColor : $r('app.color.timeisland_lake_blue')))
            .shadow({ radius: 8, color: this.state === FocusState.FLOW_DRIFT ? $r('app.color.timeisland_haven_amber') : this.tagColor, offsetY: 0 })

          // 巨幅数字计时展示
          Text(this.timeText)
            .fontSize(50)
            .fontWeight(FontWeight.Lighter)
            .fontColor($r('app.color.timeisland_text_primary'))
            .fontFamily('HarmonyOS Sans')
            .shadow({ radius: 16, color: this.state === FocusState.FLOW_DRIFT ? $r('app.color.timeisland_haven_amber') : $r('app.color.timeisland_glow_text'), offsetY: 2 })

          // 能量汇聚与心流纯度胶囊
          Row({ space: 5 }) {
            Image(this.state === FocusState.FLOW_DRIFT ? $r('app.media.ic_motion_blur') : $r('app.media.ic_water_drop'))
              .width(13)
              .height(13)
              .fillColor(this.state === FocusState.FLOW_DRIFT ? $r('app.color.timeisland_haven_amber') : $r('app.color.timeisland_emerald'))
            Text(this.state === FocusState.FLOW_DRIFT ? $r('app.string.timeisland_drift_capsule_active') : $r('app.string.timeisland_focus_purity_note'))
              .fontSize(11)
              .fontColor(this.state === FocusState.FLOW_DRIFT ? $r('app.color.timeisland_haven_amber') : $r('app.color.timeisland_text_secondary'))
              .fontWeight(FontWeight.Medium)
          }
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor($r('app.color.timeisland_surface_low'))
          .borderRadius(10)

          // 禅意温和说明
          Text(this.state === FocusState.FLOW_DRIFT ? $r('app.string.timeisland_drift_active_subnote') : $r('app.string.timeisland_drift_subnote'))
            .fontSize(10)
            .fontColor($r('app.color.timeisland_text_muted'))
            .textAlign(TextAlign.Center)
            .margin({ top: 2 })
            .width(160)
        }
        .alignItems(HorizontalAlign.Center)
        .justifyContent(FlexAlign.Center)
      }
      .width(194)
      .height(194)
      .borderRadius(97)
      .backgroundColor($r('app.color.timeisland_sphere_bg'))
      .border({ width: 1, color: $r('app.color.timeisland_border_subtle') })
      .shadow({ radius: 24, color: $r('app.color.timeisland_shadow_elevated'), offsetY: 8 })
    }
    .width('100%')
    .height(272)
    .margin({ top: 4, bottom: 4 })
  }
}

/**
 * 环形心流罗盘独立预览组件
 */
@Preview
@Component
struct FocusRingViewPreview {
  build() {
    FocusRingView({
      progress: 0.65,
      timeText: '16:15',
      state: FocusState.RUNNING,
      tagColor: $r('app.color.timeisland_emerald'),
      tagName: ''
    })
  }
}
