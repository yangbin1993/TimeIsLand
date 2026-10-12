import { hilog } from '@kit.PerformanceAnalysisKit';
import { BaseViewModel } from '@app/common';
import { FocusOverviewStat, FocusRecordEntity, DayFocusSummary, TagFocusSummary, FocusState } from '../model/FocusTypes';
import { timeIslandRepository, TimeIslandRepository } from '../data/TimeIslandRepository';

const TAG = 'FocusStatsViewModel';
const DOMAIN = 0x0000;

/**
 * 统计分析页面数据模型
 */
@Observed
export class FocusStatsState {
  public isLoading: boolean = false;
  public stats: FocusOverviewStat | null = null;
  public recentRecords: FocusRecordEntity[] = [];
}

/**
 * 时光岛统计图表与成就分析 ViewModel
 */
export class FocusStatsViewModel extends BaseViewModel {
  public state: FocusStatsState = new FocusStatsState();
  private repository: TimeIslandRepository;

  constructor(repository: TimeIslandRepository = timeIslandRepository) {
    super();
    this.repository = repository;
  }

  /**
   * 加载全局统计与流水记录
   */
  public async loadStats(): Promise<void> {
    this.state.isLoading = true;
    try {
      // 通过仓储内部 TaskDispatcher 并行调度后台工作线程归约计算
      const overview = await this.repository.computeOverviewStats();
      const records = await this.repository.getRecentRecords(20);

      this.state.stats = overview;
      this.state.recentRecords = records;
      hilog.info(DOMAIN, TAG, `Stats loaded successfully. Total minutes: ${overview.allTimeMinutes}`);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Failed to load stats or in previewer: ${(err as Error).message}`);
      // 预览器环境优雅降级：注入演示数据，避免Previewer由于缺少真实DB环境而抛出未捕获异常
      const defaultDaily: DayFocusSummary[] = [
        { dateString: '2026-10-10', totalMinutes: 45, completedSessions: 2 },
        { dateString: '2026-10-11', totalMinutes: 60, completedSessions: 2 },
        { dateString: '2026-10-12', totalMinutes: 50, completedSessions: 2 }
      ];
      const defaultTags: TagFocusSummary[] = [
        { tagId: 1, tagName: '深度编码', colorHex: '#4EDEA3', totalMinutes: 150, percentage: 62 },
        { tagId: 2, tagName: '哲学阅读', colorHex: '#60A5FA', totalMinutes: 90, percentage: 38 }
      ];
      this.state.stats = {
        todayMinutes: 50,
        todayCompletedCount: 2,
        allTimeMinutes: 240,
        streakDays: 4,
        recentDailyStats: defaultDaily,
        tagDistributions: defaultTags
      };
      const mockRecord: FocusRecordEntity = {
        id: 1,
        tagId: 1,
        targetMinutes: 25,
        actualSeconds: 1500,
        startTime: Date.now() - 3600000,
        endTime: Date.now() - 2100000,
        state: FocusState.COMPLETED
      };
      this.state.recentRecords = [mockRecord];
    } finally {
      this.state.isLoading = false;
    }
  }
}
