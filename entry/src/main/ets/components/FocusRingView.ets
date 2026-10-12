import { FocusState } from '../model/FocusTypes';

/**
 * 环形专注计时核心动效组件
 */
@Component
export struct FocusRingView {
  @Prop progress: number = 0.0;
  @Prop timeText: string = '25:00';
  @Prop state: FocusState = FocusState.IDLE;
  @Prop tagColor: string = '#4A90E2';
  @Prop tagName: string = '';

  private getStatusLabel(): Resource {
    switch (this.state) {
      case FocusState.RUNNING:
        return $r('app.string.timeisland_status_running');
      case FocusState.PAUSED:
        return $r('app.string.timeisland_status_paused');
      default:
        return $r('app.string.timeisland_status_idle');
    }
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 底层呼吸光晕背景
      Circle()
        .width(260)
        .height(260)
        .fill(this.state === FocusState.RUNNING ? this.tagColor : '#00000000')
        .opacity(this.state === FocusState.RUNNING ? 0.08 : 0)
        .animation({ duration: 1200, curve: Curve.EaseInOut, iterations: -1, playMode: PlayMode.Alternate })

      // 外圈静态底轨
      Progress({ value: 100, total: 100, type: ProgressType.Ring })
        .width(240)
        .height(240)
        .color('#F0F2F5')
        .style({ strokeWidth: 12 })

      // 动态高光进度环
      Progress({ value: Math.round(this.progress * 100), total: 100, type: ProgressType.Ring })
        .width(240)
        .height(240)
        .color(this.tagColor)
        .style({ strokeWidth: 12 })
        .animation({ duration: 500, curve: Curve.FastOutSlowIn })

      // 环内时间与状态核心内容
      Column({ space: 10 }) {
        if (this.tagName) {
          Row({ space: 6 }) {
            Circle()
              .width(8)
              .height(8)
              .fill(this.tagColor)
            Text(this.tagName)
              .fontSize(14)
              .fontColor('#666666')
              .fontWeight(FontWeight.Medium)
          }
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor('#F7F8FA')
          .borderRadius(12)
        }

        Text(this.timeText)
          .fontSize(52)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1F2329')
          .fontFamily('HarmonyOS Sans')

        Text(this.getStatusLabel())
          .fontSize(13)
          .fontColor(this.state === FocusState.RUNNING ? this.tagColor : '#999999')
          .fontWeight(FontWeight.Regular)
      }
    }
    .width(280)
    .height(280)
    .margin({ top: 16, bottom: 16 })
  }
}
