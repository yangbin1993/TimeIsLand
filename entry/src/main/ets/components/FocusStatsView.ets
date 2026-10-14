import { FocusStatsViewModel } from '../viewmodel/FocusStatsViewModel';
import { DayFocusSummary, TagFocusSummary, FocusRecordEntity, FocusState, FocusOverviewStat } from '../model/FocusTypes';

/**
 * 时光岛 - 心流气韵统计与分析看板组件 (主页顶级常驻 Tab 页面)
 */
@Component
export struct FocusStatsView {
  private vm: FocusStatsViewModel = new FocusStatsViewModel();
  @State private stats: FocusOverviewStat | null = null;
  @State private recentRecords: FocusRecordEntity[] = [];

  aboutToAppear(): void {
    this.loadData();
  }

  public async loadData(): Promise<void> {
    await this.vm.loadStats();
    this.stats = this.vm.state.stats;
    this.recentRecords = this.vm.state.recentRecords;
  }

  build() {
    Column({ space: 14 }) {

      // 2. 核心统计指标卡片组
      Row({ space: 12 }) {
        Column({ space: 6 }) {
          Text($r('app.string.timeisland_stats_all_time'))
            .fontSize(11)
            .fontColor($r('app.color.timeisland_text_secondary'))
          Row({ space: 4 }) {
            Text(this.stats ? this.stats.allTimeMinutes.toString() : '0')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.timeisland_lake_blue_light'))
            Text($r('app.string.timeisland_unit_minutes'))
              .fontSize(12)
              .fontColor($r('app.color.timeisland_text_muted'))
              .margin({ bottom: 3 })
          }
          .alignItems(VerticalAlign.Bottom)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding(14)
        .backgroundColor($r('app.color.timeisland_surface_card'))
        .borderRadius(16)
        .border({ width: 1, color: $r('app.color.timeisland_border_card') })

        Column({ space: 6 }) {
          Text($r('app.string.timeisland_stats_streak'))
            .fontSize(11)
            .fontColor($r('app.color.timeisland_text_secondary'))
          Row({ space: 4 }) {
            Text(this.stats ? this.stats.streakDays.toString() : '0')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.timeisland_emerald'))
            Text($r('app.string.timeisland_stats_unit_days'))
              .fontSize(12)
              .fontColor($r('app.color.timeisland_text_muted'))
              .margin({ bottom: 3 })
          }
          .alignItems(VerticalAlign.Bottom)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
        .padding(14)
        .backgroundColor($r('app.color.timeisland_surface_card'))
        .borderRadius(16)
        .border({ width: 1, color: $r('app.color.timeisland_border_card') })
      }
      .width('100%')

      // 3. 最近 7 天趋势条
      Column({ space: 12 }) {
        Text($r('app.string.timeisland_stats_7days_trend'))
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.timeisland_text_primary'))

        if (this.stats && this.stats.recentDailyStats.length > 0) {
          Row({ space: 6 }) {
            ForEach(this.stats.recentDailyStats, (day: DayFocusSummary) => {
              Column({ space: 6 }) {
                Text(`${day.totalMinutes}m`)
                  .fontSize(10)
                  .fontColor($r('app.color.timeisland_text_secondary'))

                // 柱状指示条
                Column()
                  .width(16)
                  .height(Math.min(90, Math.max(10, day.totalMinutes * 1.5)))
                  .backgroundColor(day.totalMinutes > 0 ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_border_subtle'))
                  .borderRadius(4)

                Text(day.dateString.substring(5))
                  .fontSize(10)
                  .fontColor($r('app.color.timeisland_text_muted'))
              }
              .layoutWeight(1)
              .alignItems(HorizontalAlign.Center)
            }, (day: DayFocusSummary) => day.dateString)
          }
          .width('100%')
          .alignItems(VerticalAlign.Bottom)
          .padding({ top: 8, bottom: 4 })
        }
      }
      .width('100%')
      .padding(14)
      .backgroundColor($r('app.color.timeisland_surface_card'))
      .borderRadius(16)
      .border({ width: 1, color: $r('app.color.timeisland_border_card') })

      // 4. 场景分布
      if (this.stats && this.stats.tagDistributions.length > 0) {
        Column({ space: 12 }) {
          Text($r('app.string.timeisland_stats_tag_distribution'))
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.timeisland_text_primary'))

          ForEach(this.stats.tagDistributions, (item: TagFocusSummary) => {
            Column({ space: 6 }) {
              Row() {
                Row({ space: 6 }) {
                  Row().width(6).height(6).borderRadius(3).backgroundColor(item.colorHex)
                  Text(item.tagName).fontSize(12).fontColor($r('app.color.timeisland_text_primary'))
                }
                Blank()
                Text(`${item.totalMinutes}m (${item.percentage}%)`)
                  .fontSize(11)
                  .fontColor($r('app.color.timeisland_text_secondary'))
              }
              .width('100%')

              Progress({ value: item.percentage, total: 100, type: ProgressType.Linear })
                .color(item.colorHex)
                .backgroundColor($r('app.color.timeisland_border_subtle'))
                .style({ strokeWidth: 5 })
            }
            .width('100%')
          }, (item: TagFocusSummary) => item.tagId.toString())
        }
        .width('100%')
        .padding(14)
        .backgroundColor($r('app.color.timeisland_surface_card'))
        .borderRadius(16)
        .border({ width: 1, color: $r('app.color.timeisland_border_card') })
      }

      // 5. 近期专注流水记录
      Column({ space: 12 }) {
        Text($r('app.string.timeisland_stats_recent_history'))
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.timeisland_text_primary'))

        if (this.recentRecords.length === 0) {
          Text($r('app.string.timeisland_stats_empty'))
            .fontSize(12)
            .fontColor($r('app.color.timeisland_text_muted'))
            .padding(20)
        } else {
          ForEach(this.recentRecords, (rec: FocusRecordEntity) => {
            Row() {
              Column({ space: 4 }) {
                Text(this.formatRecordDate(rec.startTime))
                  .fontSize(11)
                  .fontColor($r('app.color.timeisland_text_muted'))
                Row({ space: 2 }) {
                  Text(Math.floor(rec.actualSeconds / 60).toString())
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.timeisland_text_primary'))
                  Text($r('app.string.timeisland_record_minutes_focus'))
                    .fontSize(12)
                    .fontColor($r('app.color.timeisland_text_secondary'))
                }
              }
              .alignItems(HorizontalAlign.Start)

              Blank()

              Text(rec.state === FocusState.COMPLETED ? $r('app.string.timeisland_record_completed') : $r('app.string.timeisland_record_canceled'))
                .fontSize(11)
                .fontColor(rec.state === FocusState.COMPLETED ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_haven_amber'))
                .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                .backgroundColor(rec.state === FocusState.COMPLETED ? $r('app.color.timeisland_flow_bg') : $r('app.color.timeisland_haven_amber_bg'))
                .borderRadius(10)
                .border({ width: 1, color: rec.state === FocusState.COMPLETED ? $r('app.color.timeisland_emerald_border') : $r('app.color.timeisland_haven_amber_border') })
            }
            .width('100%')
            .padding({ top: 8, bottom: 8 })
            .border({ width: { bottom: 1 }, color: $r('app.color.timeisland_surface_indigo') })
          }, (rec: FocusRecordEntity) => (rec.id ? rec.id.toString() : rec.startTime.toString()))
        }
      }
      .width('100%')
      .padding(14)
      .backgroundColor($r('app.color.timeisland_surface_card'))
      .borderRadius(16)
      .border({ width: 1, color: $r('app.color.timeisland_border_card') })
    }
    .width('100%')
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
