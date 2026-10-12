/**
 * 目标时长快捷切换组件
 */
@Component
export struct TimeDurationSelector {
  @Prop selectedMinutes: number = 25;
  @Prop disabled: boolean = false;
  public onSelectMinutes: (minutes: number) => void = () => {};

  private readonly durations: number[] = [15, 25, 35, 45, 60];

  build() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.timeisland_duration_title'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      Row({ space: 8 }) {
        ForEach(this.durations, (mins: number) => {
          Button(`${mins}m`, { type: ButtonType.Capsule, stateEffect: !this.disabled })
            .fontSize(13)
            .fontWeight(this.selectedMinutes === mins ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.selectedMinutes === mins ? '#FFFFFF' : '#666666')
            .backgroundColor(this.selectedMinutes === mins ? '#2B303A' : '#F2F4F7')
            .height(34)
            .layoutWeight(1)
            .opacity(this.disabled ? 0.5 : 1.0)
            .onClick(() => {
              if (!this.disabled) {
                this.onSelectMinutes(mins);
              }
            })
        }, (mins: number) => mins.toString())
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
  }
}
