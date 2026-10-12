import { router } from '@kit.ArkUI';
import { FocusStatsViewModel } from '../viewmodel/FocusStatsViewModel';
import { DayFocusSummary, TagFocusSummary, FocusRecordEntity, FocusState } from '../model/FocusTypes';

/**
 * 统计页面路由分发器 Builder 声明
 */
@Builder
export function FocusStatsPageBuilder() {
  FocusStatsPage()
}

/**
 * 时光岛 - 心流统计与历史流水页面
 */
@Entry
@Component
export struct FocusStatsPage {
  @State private vm: FocusStatsViewModel = new FocusStatsViewModel();

  aboutToAppear(): void {
    this.vm.loadStats();
  }

  build() {
    NavDestination() {
      Column() {
        // 顶部导航条
        Row() {
          Button({ type: ButtonType.Normal }) {
            Text('←')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1F2329')
          }
          .backgroundColor('#00000000')
          .width(40)
          .height(40)
          .onClick(() => {
            router.back();
          })

          Text($r('app.string.timeisland_nav_stats'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1F2329')
            .margin({ left: 8 })

          Blank()
        }
        .width('100%')
        .padding({ left: 12, right: 16, top: 12, bottom: 8 })

        Scroll() {
          Column({ space: 16 }) {
            // 核心统计卡片组
            Row({ space: 12 }) {
              Column({ space: 6 }) {
                Text($r('app.string.timeisland_stats_all_time'))
                  .fontSize(12)
                  .fontColor('#8F959E')
                Row({ space: 4 }) {
                  Text(this.vm.state.stats ? this.vm.state.stats.allTimeMinutes.toString() : '0')
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#4A90E2')
                  Text($r('app.string.timeisland_unit_minutes'))
                    .fontSize(12)
                    .fontColor('#8F959E')
                    .margin({ bottom: 3 })
                }
                .alignItems(VerticalAlign.Bottom)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .padding(16)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .shadow({ radius: 8, color: '#0A000000', offsetY: 2 })

              Column({ space: 6 }) {
                Text($r('app.string.timeisland_stats_streak'))
                  .fontSize(12)
                  .fontColor('#8F959E')
                Row({ space: 4 }) {
                  Text(this.vm.state.stats ? this.vm.state.stats.streakDays.toString() : '0')
                    .fontSize(24)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#52C41A')
                  Text($r('app.string.timeisland_stats_unit_days'))
                    .fontSize(12)
                    .fontColor('#8F959E')
                    .margin({ bottom: 3 })
                }
                .alignItems(VerticalAlign.Bottom)
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Start)
              .padding(16)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .shadow({ radius: 8, color: '#0A000000', offsetY: 2 })
            }
            .width('100%')

            // 最近 7 天趋势条
            Column({ space: 12 }) {
              Text($r('app.string.timeisland_stats_7days_trend'))
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1F2329')

              if (this.vm.state.stats && this.vm.state.stats.recentDailyStats.length > 0) {
                Row({ space: 6 }) {
                  ForEach(this.vm.state.stats.recentDailyStats, (day: DayFocusSummary) => {
                    Column({ space: 6 }) {
                      Text(`${day.totalMinutes}m`)
                        .fontSize(10)
                        .fontColor('#8F959E')

                      // 柱状指示条
                      Column()
                        .width(18)
                        .height(Math.min(100, Math.max(10, day.totalMinutes * 1.5)))
                        .backgroundColor(day.totalMinutes > 0 ? '#4A90E2' : '#E5E6EB')
                        .borderRadius(4)

                      Text(day.dateString.substring(5))
                        .fontSize(10)
                        .fontColor('#666666')
                    }
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Center)
                  }, (day: DayFocusSummary) => day.dateString)
                }
                .width('100%')
                .alignItems(VerticalAlign.Bottom)
                .padding({ top: 12, bottom: 8 })
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .shadow({ radius: 8, color: '#0A000000', offsetY: 2 })

            // 场景分布
            if (this.vm.state.stats && this.vm.state.stats.tagDistributions.length > 0) {
              Column({ space: 12 }) {
                Text($r('app.string.timeisland_stats_tag_distribution'))
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1F2329')

                ForEach(this.vm.state.stats.tagDistributions, (item: TagFocusSummary) => {
                  Column({ space: 6 }) {
                    Row() {
                      Row({ space: 6 }) {
                        Circle().width(8).height(8).fill(item.colorHex)
                        Text(item.tagName).fontSize(13).fontColor('#333333')
                      }
                      Blank()
                      Text(`${item.totalMinutes}m (${item.percentage}%)`)
                        .fontSize(12)
                        .fontColor('#8F959E')
                    }
                    .width('100%')

                    Progress({ value: item.percentage, total: 100, type: ProgressType.Linear })
                      .color(item.colorHex)
                      .backgroundColor('#F2F4F7')
                      .style({ strokeWidth: 6 })
                  }
                  .width('100%')
                }, (item: TagFocusSummary) => item.tagId.toString())
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .shadow({ radius: 8, color: '#0A000000', offsetY: 2 })
            }

            // 近期专注流水记录
            Column({ space: 12 }) {
              Text($r('app.string.timeisland_stats_recent_history'))
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1F2329')

              if (this.vm.state.recentRecords.length === 0) {
                Text($r('app.string.timeisland_stats_empty'))
                  .fontSize(13)
                  .fontColor('#999999')
                  .padding(24)
              } else {
                ForEach(this.vm.state.recentRecords, (rec: FocusRecordEntity) => {
                  Row() {
                    Column({ space: 4 }) {
                      Text(this.formatRecordDate(rec.startTime))
                        .fontSize(12)
                        .fontColor('#8F959E')
                      Text(`${Math.floor(rec.actualSeconds / 60)} 分钟专注`)
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                        .fontColor('#1F2329')
                    }
                    .alignItems(HorizontalAlign.Start)

                    Blank()

                    Text(rec.state === FocusState.COMPLETED ? '已达成' : '提前结束')
                      .fontSize(12)
                      .fontColor(rec.state === FocusState.COMPLETED ? '#52C41A' : '#FF4D4F')
                      .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                      .backgroundColor(rec.state === FocusState.COMPLETED ? '#F6FFED' : '#FFF1F0')
                      .borderRadius(4)
                  }
                  .width('100%')
                  .padding({ top: 8, bottom: 8 })
                  .border({ width: { bottom: 1 }, color: '#F2F4F7' })
                }, (rec: FocusRecordEntity) => (rec.id ? rec.id.toString() : rec.startTime.toString()))
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .shadow({ radius: 8, color: '#0A000000', offsetY: 2 })
          }
          .padding({ left: 16, right: 16, bottom: 24 })
        }
        .layoutWeight(1)
        .edgeEffect(EdgeEffect.Spring)
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FAFAFC')
    }
    .hideTitleBar(true)
  }

  private formatRecordDate(timestamp: number): string {
    const d = new Date(timestamp);
    const m = (d.getMonth() + 1).toString().padStart(2, '0');
    const day = d.getDate().toString().padStart(2, '0');
    const h = d.getHours().toString().padStart(2, '0');
    const min = d.getMinutes().toString().padStart(2, '0');
    return `${m}-${day} ${h}:${min}`;
  }
}
