import { FocusStatsViewModel } from '../viewmodel/FocusStatsViewModel';
import { DayFocusSummary, TagFocusSummary, FocusRecordEntity, FocusState, FocusOverviewStat } from '../model/FocusTypes';
import { ThemePalette, ThemeMode } from '../theme/ThemeTypes';
import { themeManager } from '../theme/ThemeManager';

/**
 * 时光岛 - 心流气韵统计与分析看板组件 (主页常驻看板与独立页面通用容器)
 * 特性: 
 * 1. 深度适配 ThemeManager 生境主题动态热切换；
 * 2. 支持 BreakpointSystem 响应式断点：直板单列纵向流线 / 折叠屏与平板双栏大看板。
 */
@Component
export struct FocusStatsView {
  @StorageProp('currentTheme') theme: ThemePalette = themeManager.getPaletteByMode(ThemeMode.DARK);
  @StorageProp('currentBreakpoint') currentBreakpoint: string = 'sm';

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
      if (this.currentBreakpoint === 'md' || this.currentBreakpoint === 'lg') {
        // 折叠屏展开态与平板大画布: 左右 50:50 双栏并排布局
        Row({ space: 14 }) {
          // 左栏: 核心指标概览 + 7天趋势
          Column({ space: 14 }) {
            this.buildMetricsCard()
            this.buildTrendCard()
          }
          .layoutWeight(1)

          // 右栏: 场景标签分布 + 近期历史流水
          Column({ space: 14 }) {
            this.buildDistributionCard()
            this.buildHistoryCard()
          }
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      } else {
        // 直板手机单列纵向流线
        this.buildMetricsCard()
        this.buildTrendCard()
        this.buildDistributionCard()
        this.buildHistoryCard()
      }
    }
    .width('100%')
  }

  /**
   * 1. 核心统计指标卡片 (总专注时长 & 连续打卡天数)
   */
  @Builder
  private buildMetricsCard() {
    Row({ space: 12 }) {
      Column({ space: 6 }) {
        Text($r('app.string.timeisland_stats_all_time'))
          .fontSize(11)
          .fontColor(this.theme.textSecondary)
        Row({ space: 4 }) {
          Text(this.stats ? this.stats.allTimeMinutes.toString() : '0')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.primaryAccent)
          Text($r('app.string.timeisland_unit_minutes'))
            .fontSize(12)
            .fontColor(this.theme.textMuted)
            .margin({ bottom: 3 })
        }
        .alignItems(VerticalAlign.Bottom)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding(14)
      .backgroundColor(this.theme.surfaceCard)
      .borderRadius(16)
      .border({ width: 1, color: this.theme.borderCard })
      .shadow({ radius: 10, color: this.theme.shadowCard, offsetY: 2 })

      Column({ space: 6 }) {
        Text($r('app.string.timeisland_stats_streak'))
          .fontSize(11)
          .fontColor(this.theme.textSecondary)
        Row({ space: 4 }) {
          Text(this.stats ? this.stats.streakDays.toString() : '0')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.secondaryAccent)
          Text($r('app.string.timeisland_stats_unit_days'))
            .fontSize(12)
            .fontColor(this.theme.textMuted)
            .margin({ bottom: 3 })
        }
        .alignItems(VerticalAlign.Bottom)
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Start)
      .padding(14)
      .backgroundColor(this.theme.surfaceCard)
      .borderRadius(16)
      .border({ width: 1, color: this.theme.borderCard })
      .shadow({ radius: 10, color: this.theme.shadowCard, offsetY: 2 })
    }
    .width('100%')
  }

  /**
   * 2. 最近 7 天趋势柱状图卡片
   */
  @Builder
  private buildTrendCard() {
    Column({ space: 12 }) {
      Text($r('app.string.timeisland_stats_7days_trend'))
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textPrimary)

      if (this.stats && this.stats.recentDailyStats.length > 0) {
        Row({ space: 6 }) {
          ForEach(this.stats.recentDailyStats, (day: DayFocusSummary) => {
            Column({ space: 6 }) {
              Text(`${day.totalMinutes}m`)
                .fontSize(10)
                .fontColor(this.theme.textSecondary)

              // 动态柱状指示条
              Column()
                .width(16)
                .height(Math.min(90, Math.max(10, day.totalMinutes * 1.5)))
                .backgroundColor(day.totalMinutes > 0 ? this.theme.secondaryAccent : this.theme.borderSubtle)
                .borderRadius(4)

              Text(day.dateString.substring(5))
                .fontSize(10)
                .fontColor(this.theme.textMuted)
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
    .backgroundColor(this.theme.surfaceCard)
    .borderRadius(16)
    .border({ width: 1, color: this.theme.borderCard })
    .shadow({ radius: 10, color: this.theme.shadowCard, offsetY: 2 })
  }

  /**
   * 3. 场景标签占比分布卡片
   */
  @Builder
  private buildDistributionCard() {
    if (this.stats && this.stats.tagDistributions.length > 0) {
      Column({ space: 12 }) {
        Text($r('app.string.timeisland_stats_tag_distribution'))
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.textPrimary)

        ForEach(this.stats.tagDistributions, (item: TagFocusSummary) => {
          Column({ space: 6 }) {
            Row() {
              Row({ space: 6 }) {
                Row().width(6).height(6).borderRadius(3).backgroundColor(item.colorHex)
                Text(item.tagName).fontSize(12).fontColor(this.theme.textPrimary)
              }
              Blank()
              Text(`${item.totalMinutes}m (${item.percentage}%)`)
                .fontSize(11)
                .fontColor(this.theme.textSecondary)
            }
            .width('100%')

            Progress({ value: item.percentage, total: 100, type: ProgressType.Linear })
              .color(item.colorHex)
              .backgroundColor(this.theme.borderSubtle)
              .style({ strokeWidth: 5 })
          }
          .width('100%')
        }, (item: TagFocusSummary) => item.tagId.toString())
      }
      .width('100%')
      .padding(14)
      .backgroundColor(this.theme.surfaceCard)
      .borderRadius(16)
      .border({ width: 1, color: this.theme.borderCard })
      .shadow({ radius: 10, color: this.theme.shadowCard, offsetY: 2 })
    }
  }

  /**
   * 4. 近期专注流水记录卡片
   */
  @Builder
  private buildHistoryCard() {
    Column({ space: 12 }) {
      Text($r('app.string.timeisland_stats_recent_history'))
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textPrimary)

      if (this.recentRecords.length === 0) {
        Text($r('app.string.timeisland_stats_empty'))
          .fontSize(12)
          .fontColor(this.theme.textMuted)
          .padding(20)
      } else {
        ForEach(this.recentRecords, (rec: FocusRecordEntity) => {
          Column({ space: 6 }) {
            Row() {
              Column({ space: 4 }) {
                Text(this.formatRecordDate(rec.startTime))
                  .fontSize(11)
                  .fontColor(this.theme.textMuted)
                Row({ space: 2 }) {
                  Text(Math.floor(rec.actualSeconds / 60).toString())
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.theme.textPrimary)
                  Text($r('app.string.timeisland_record_minutes_focus'))
                    .fontSize(12)
                    .fontColor(this.theme.textSecondary)
                }
              }
              .alignItems(HorizontalAlign.Start)

              Blank()

              Row({ space: 6 }) {
                if (rec.rating && rec.rating > 0) {
                  Text(this.renderRatingStars(rec.rating))
                    .fontSize(12)
                    .fontColor(this.theme.primaryAccent)
                }

                Text(rec.state === FocusState.COMPLETED ? $r('app.string.timeisland_record_completed') : $r('app.string.timeisland_record_canceled'))
                  .fontSize(11)
                  .fontColor(rec.state === FocusState.COMPLETED ? this.theme.secondaryAccent : this.theme.havenAmber)
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
                  .backgroundColor(this.theme.surfaceLow)
                  .borderRadius(10)
                  .border({
                    width: 1,
                    color: rec.state === FocusState.COMPLETED ? this.theme.borderSubtle : this.theme.havenAmberBorder,
                    radius: 10
                  })
              }
            }
            .width('100%')

            if (rec.note && rec.note.length > 0 && !rec.note.startsWith('[FlowDrift') && !rec.note.startsWith('[GraceHaven')) {
              Row({ space: 6 }) {
                Text($r('app.string.timeisland_stats_note_tag'))
                  .fontSize(9)
                  .fontColor(this.theme.primaryAccent)
                  .padding({ left: 5, right: 5, top: 2, bottom: 2 })
                  .backgroundColor(this.theme.surfaceCard)
                  .borderRadius(4)
                  .border({ width: 0.5, color: this.theme.borderSubtle })

                Text(rec.note)
                  .fontSize(11)
                  .fontColor(this.theme.textSecondary)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .layoutWeight(1)
              }
              .width('100%')
              .padding({ left: 8, right: 8, top: 5, bottom: 5 })
              .backgroundColor(this.theme.surfaceLow)
              .borderRadius(8)
            }
          }
          .width('100%')
          .padding({ top: 8, bottom: 8 })
          .border({ width: { bottom: 1 }, color: this.theme.borderSubtle })
        }, (rec: FocusRecordEntity) => (rec.id ? rec.id.toString() : rec.startTime.toString()))
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor(this.theme.surfaceCard)
    .borderRadius(16)
    .border({ width: 1, color: this.theme.borderCard })
    .shadow({ radius: 10, color: this.theme.shadowCard, offsetY: 2 })
  }

  private renderRatingStars(rating: number): string {
    const clamped = Math.min(5, Math.max(1, rating));
    let stars = '';
    for (let i = 0; i < clamped; i++) {
      stars += '★';
    }
    return stars;
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
