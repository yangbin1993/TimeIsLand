import { hilog } from '@kit.PerformanceAnalysisKit';
import { BaseViewModel } from '@app/common';
import { FocusOverviewStat, FocusRecordEntity } from '../model/FocusTypes';
import { timeIslandRepository, TimeIslandRepository } from '../data/TimeIslandRepository';

const TAG = 'FocusStatsViewModel';
const DOMAIN = 0x0000;

/**
 * 统计分析页面数据模型
 */
@ObservedV2
export class FocusStatsState {
  @Trace public isLoading: boolean = false;
  @Trace public stats: FocusOverviewStat | null = null;
  @Trace public recentRecords: FocusRecordEntity[] = [];
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
      hilog.error(DOMAIN, TAG, `Failed to load stats: ${(err as Error).message}`);
    } finally {
      this.state.isLoading = false;
    }
  }
}
