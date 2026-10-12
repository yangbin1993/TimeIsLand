/**
 * 时光岛 - 专注刻度胶囊切换器 (TimeDurationSelector)
 * 对齐 Stitch 设计稿: 暗夜毛玻璃底座 + 渐变高光胶囊
 */
@Component
export struct TimeDurationSelector {
  @Prop selectedMinutes: number = 25;
  @Prop disabled: boolean = false;
  public onSelectMinutes: (minutes: number) => void = () => {};

  private readonly durations: number[] = [15, 25, 45, 60];

  build() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.timeisland_duration_title'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.timeisland_text_secondary'))

        Blank()

        Text($r('app.string.timeisland_duration_cycle'))
          .fontSize(11)
          .fontColor($r('app.color.timeisland_text_muted'))
      }
      .width('100%')
      .padding({ left: 4, right: 4 })

      Row({ space: 6 }) {
        ForEach(this.durations, (mins: number) => {
          Button(`${mins}m`, { type: ButtonType.Capsule, stateEffect: !this.disabled })
            .fontSize(13)
            .fontWeight(this.selectedMinutes === mins ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.selectedMinutes === mins ? $r('app.color.timeisland_text_primary') : $r('app.color.timeisland_text_secondary'))
            .backgroundColor(this.selectedMinutes === mins ? $r('app.color.timeisland_lake_blue_deep') : Color.Transparent)
            .height(34)
            .padding({ left: 2, right: 2 })
            .labelStyle({ maxLines: 1 })
            .layoutWeight(1)
            .opacity(this.disabled ? 0.4 : 1.0)
            .shadow(this.selectedMinutes === mins ? { radius: 8, color: $r('app.color.timeisland_glow_blue_pill'), offsetY: 2 } : { radius: 0, color: Color.Transparent })
            .onClick(() => {
              if (!this.disabled) {
                this.onSelectMinutes(mins);
              }
            })
        }, (mins: number) => mins.toString())

        Button({ type: ButtonType.Capsule, stateEffect: !this.disabled }) {
          Row({ space: 4 }) {
            Image($r('app.media.ic_tune'))
              .width(13)
              .height(13)
              .fillColor($r('app.color.timeisland_text_secondary'))
            Text($r('app.string.timeisland_duration_custom'))
              .fontSize(12)
              .fontColor($r('app.color.timeisland_text_secondary'))
          }
        }
        .backgroundColor(Color.Transparent)
        .height(34)
        .padding({ left: 4, right: 4 })
        .layoutWeight(1)
        .opacity(this.disabled ? 0.4 : 1.0)
      }
      .width('100%')
      .padding(4)
      .backgroundColor($r('app.color.timeisland_surface_low'))
      .borderRadius(20)
      .border({ width: 1, color: $r('app.color.timeisland_border_subtle') })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}

/**
 * 专注刻度胶囊选择器独立预览组件
 */
@Preview
@Component
struct TimeDurationSelectorPreview {
  build() {
    Column() {
      TimeDurationSelector({
        selectedMinutes: 25,
        disabled: false
      })
    }
    .padding(16)
    .backgroundColor($r('app.color.timeisland_bg_canvas'))
  }
}
