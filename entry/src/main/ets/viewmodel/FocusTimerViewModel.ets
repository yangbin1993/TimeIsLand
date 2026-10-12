import { hilog } from '@kit.PerformanceAnalysisKit';
import { BaseMviViewModel } from '@app/common';
import { FocusState, FocusTag, FocusRecordEntity } from '../model/FocusTypes';
import { timeIslandRepository, TimeIslandRepository } from '../data/TimeIslandRepository';

const TAG = 'FocusTimerViewModel';
const DOMAIN = 0x0000;

/**
 * 专注计时器单一可信状态模型
 */
@ObservedV2
export class FocusTimerState {
  @Trace public status: FocusState = FocusState.IDLE;
  @Trace public selectedMinutes: number = 25;
  @Trace public remainingSeconds: number = 25 * 60;
  @Trace public actualFocusedSeconds: number = 0;
  @Trace public currentTag: FocusTag | null = null;
  @Trace public tags: FocusTag[] = [];
  @Trace public isWhiteNoisePlaying: boolean = false;
  @Trace public selectedNoiseId: string = 'forest';
  @Trace public todayTotalMinutes: number = 0;
  @Trace public todayCompletedCount: number = 0;

  /**
   * 格式化展示剩余时间 MM:SS
   */
  public get formattedTime(): string {
    const mins = Math.floor(this.remainingSeconds / 60);
    const secs = this.remainingSeconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }

  /**
   * 当前进度比例 (0.0 ~ 1.0)
   */
  public get progress(): number {
    const totalSecs = this.selectedMinutes * 60;
    if (totalSecs <= 0) {
      return 0;
    }
    const elapsed = totalSecs - this.remainingSeconds;
    return Math.min(1.0, Math.max(0.0, elapsed / totalSecs));
  }
}

/**
 * 专注交互意图联合定义 (Intent)
 */
export type FocusTimerIntent =
  | { type: 'INIT_DATA' }
  | { type: 'SELECT_DURATION'; minutes: number }
  | { type: 'SELECT_TAG'; tag: FocusTag }
  | { type: 'START_TIMER' }
  | { type: 'PAUSE_TIMER' }
  | { type: 'RESUME_TIMER' }
  | { type: 'GIVE_UP_TIMER' }
  | { type: 'COMPLETE_TIMER' }
  | { type: 'TOGGLE_WHITE_NOISE'; noiseId?: string };

/**
 * 专注一次性副作用定义 (Side Effect)
 */
export type FocusTimerEffect =
  | { type: 'SHOW_TOAST'; messageKey: string }
  | { type: 'TRIGGER_HAPTIC'; pattern: 'tick' | 'complete' | 'warning' }
  | { type: 'FOCUS_FINISHED'; recordId: number };

/**
 * 时光岛专注计时器 MVI 控制中心
 */
export class FocusTimerViewModel extends BaseMviViewModel<FocusTimerState, FocusTimerIntent, FocusTimerEffect> {
  public state: FocusTimerState = new FocusTimerState();
  private repository: TimeIslandRepository;
  private timerId: number = -1;
  private focusStartTime: number = 0;

  constructor(repository: TimeIslandRepository = timeIslandRepository) {
    super();
    this.repository = repository;
  }

  protected handleIntent(intent: FocusTimerIntent): void {
    switch (intent.type) {
      case 'INIT_DATA':
        this.loadInitialData();
        break;
      case 'SELECT_DURATION':
        this.selectDuration(intent.minutes);
        break;
      case 'SELECT_TAG':
        this.selectTag(intent.tag);
        break;
      case 'START_TIMER':
        this.startTimer();
        break;
      case 'PAUSE_TIMER':
        this.pauseTimer();
        break;
      case 'RESUME_TIMER':
        this.resumeTimer();
        break;
      case 'GIVE_UP_TIMER':
        this.giveUpTimer();
        break;
      case 'COMPLETE_TIMER':
        this.completeTimer();
        break;
      case 'TOGGLE_WHITE_NOISE':
        this.toggleWhiteNoise(intent.noiseId);
        break;
    }
  }

  /**
   * 初始化加载标签与今日概览
   */
  private async loadInitialData(): Promise<void> {
    try {
      const tags = await this.repository.getTags();
      this.state.tags = tags;
      if (tags.length > 0 && !this.state.currentTag) {
        this.state.currentTag = tags[0];
      }

      const overview = await this.repository.computeOverviewStats();
      this.state.todayTotalMinutes = overview.todayMinutes;
      this.state.todayCompletedCount = overview.todayCompletedCount;
    } catch (err) {
      hilog.error(DOMAIN, TAG, `loadInitialData failed: ${(err as Error).message}`);
    }
  }

  /**
   * 选择目标专注分钟数
   */
  private selectDuration(minutes: number): void {
    if (this.state.status === FocusState.RUNNING || this.state.status === FocusState.PAUSED) {
      this.emitEffect({ type: 'SHOW_TOAST', messageKey: 'timeisland_toast_cannot_change_duration' });
      return;
    }
    this.state.selectedMinutes = minutes;
    this.state.remainingSeconds = minutes * 60;
    this.state.actualFocusedSeconds = 0;
  }

  /**
   * 切换当前专注所属标签
   */
  private selectTag(tag: FocusTag): void {
    this.state.currentTag = tag;
    this.emitEffect({ type: 'TRIGGER_HAPTIC', pattern: 'tick' });
  }

  /**
   * 启动专注倒计时
   */
  private startTimer(): void {
    if (this.state.status === FocusState.RUNNING) {
      return;
    }
    this.clearTimer();
    this.focusStartTime = Date.now();
    this.state.status = FocusState.RUNNING;
    this.state.actualFocusedSeconds = 0;
    this.state.remainingSeconds = this.state.selectedMinutes * 60;

    this.emitEffect({ type: 'TRIGGER_HAPTIC', pattern: 'tick' });
    this.runTickLoop();
  }

  /**
   * 暂停计时
   */
  private pauseTimer(): void {
    if (this.state.status !== FocusState.RUNNING) {
      return;
    }
    this.clearTimer();
    this.state.status = FocusState.PAUSED;
    this.emitEffect({ type: 'TRIGGER_HAPTIC', pattern: 'tick' });
  }

  /**
   * 恢复计时
   */
  private resumeTimer(): void {
    if (this.state.status !== FocusState.PAUSED) {
      return;
    }
    this.state.status = FocusState.RUNNING;
    this.emitEffect({ type: 'TRIGGER_HAPTIC', pattern: 'tick' });
    this.runTickLoop();
  }

  /**
   * 放弃或提前取消
   */
  private async giveUpTimer(): Promise<void> {
    this.clearTimer();
    const actualSecs = this.state.actualFocusedSeconds;
    const tagId = this.state.currentTag ? this.state.currentTag.id : 1;
    const startTime = this.focusStartTime;
    const endTime = Date.now();

    this.state.status = FocusState.IDLE;
    this.state.remainingSeconds = this.state.selectedMinutes * 60;
    this.state.actualFocusedSeconds = 0;

    // 若专注时长超过 60 秒，依然记录一条 CANCELED 历史
    if (actualSecs >= 60) {
      const record: FocusRecordEntity = {
        tagId: tagId,
        targetMinutes: this.state.selectedMinutes,
        actualSeconds: actualSecs,
        startTime: startTime,
        endTime: endTime,
        state: FocusState.CANCELED
      };
      await this.repository.saveFocusRecord(record);
    }

    this.emitEffect({ type: 'SHOW_TOAST', messageKey: 'timeisland_toast_give_up' });
    this.emitEffect({ type: 'TRIGGER_HAPTIC', pattern: 'warning' });
  }

  /**
   * 正常或提前达成完成
   */
  private async completeTimer(): Promise<void> {
    this.clearTimer();
    this.state.status = FocusState.COMPLETED;

    const actualSecs = this.state.actualFocusedSeconds > 0
      ? this.state.actualFocusedSeconds
      : this.state.selectedMinutes * 60;
    const tagId = this.state.currentTag ? this.state.currentTag.id : 1;

    const record: FocusRecordEntity = {
      tagId: tagId,
      targetMinutes: this.state.selectedMinutes,
      actualSeconds: actualSecs,
      startTime: this.focusStartTime > 0 ? this.focusStartTime : Date.now() - actualSecs * 1000,
      endTime: Date.now(),
      state: FocusState.COMPLETED
    };

    let recordId = 0;
    try {
      recordId = await this.repository.saveFocusRecord(record);
      // 累加今日指标
      const addedMins = Math.floor(actualSecs / 60);
      this.state.todayTotalMinutes += addedMins;
      this.state.todayCompletedCount += 1;
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Failed to save completed record: ${(err as Error).message}`);
    }

    this.emitEffect({ type: 'TRIGGER_HAPTIC', pattern: 'complete' });
    this.emitEffect({ type: 'SHOW_TOAST', messageKey: 'timeisland_toast_focus_completed' });
    this.emitEffect({ type: 'FOCUS_FINISHED', recordId: recordId });

    // 重置为待命状态准备下一次
    this.state.status = FocusState.IDLE;
    this.state.remainingSeconds = this.state.selectedMinutes * 60;
    this.state.actualFocusedSeconds = 0;
  }

  /**
   * 开启或切换白噪音
   */
  private toggleWhiteNoise(noiseId?: string): void {
    if (noiseId) {
      this.state.selectedNoiseId = noiseId;
      this.state.isWhiteNoisePlaying = true;
    } else {
      this.state.isWhiteNoisePlaying = !this.state.isWhiteNoisePlaying;
    }
    this.emitEffect({ type: 'TRIGGER_HAPTIC', pattern: 'tick' });
  }

  /**
   * 每秒循环调度步进
   */
  private runTickLoop(): void {
    this.timerId = setInterval((): void => {
      if (this.state.status !== FocusState.RUNNING) {
        return;
      }

      this.state.actualFocusedSeconds += 1;

      if (this.state.remainingSeconds > 0) {
        this.state.remainingSeconds -= 1;
      }

      // 倒计时归零，完成专注
      if (this.state.remainingSeconds <= 0) {
        this.dispatch({ type: 'COMPLETE_TIMER' });
      }
    }, 1000);
  }

  private clearTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  public onCleared(): void {
    this.clearTimer();
    super.onCleared();
  }
}
