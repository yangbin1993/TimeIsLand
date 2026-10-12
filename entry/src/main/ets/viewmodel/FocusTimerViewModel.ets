import { hilog } from '@kit.PerformanceAnalysisKit';
import { BaseMviViewModel } from '@app/common';
import { FocusState, FocusTag, FocusRecordEntity } from '../model/FocusTypes';
import { timeIslandRepository, TimeIslandRepository } from '../data/TimeIslandRepository';

const TAG = 'FocusTimerViewModel';
const DOMAIN = 0x0000;

/**
 * 专注计时器单一可信状态模型
 */
@Observed
export class FocusTimerState {
  public status: FocusState = FocusState.IDLE;
  public selectedMinutes: number = 25;
  public remainingSeconds: number = 25 * 60;
  public actualFocusedSeconds: number = 0;
  public currentTag: FocusTag | null = null;
  public tags: FocusTag[] = [];
  public isWhiteNoisePlaying: boolean = false;
  public selectedNoiseId: string = 'forest';
  public todayTotalMinutes: number = 0;
  public todayCompletedCount: number = 0;

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
 * 专注交互意图强类型契约 (Intent)
 */
export class FocusTimerIntent {
  public type: string;
  public minutes?: number;
  public tag?: FocusTag;
  public noiseId?: string;

  constructor(type: string, minutes?: number, tag?: FocusTag, noiseId?: string) {
    this.type = type;
    this.minutes = minutes;
    this.tag = tag;
    this.noiseId = noiseId;
  }

  public static initData(): FocusTimerIntent {
    return new FocusTimerIntent('INIT_DATA');
  }

  public static selectDuration(minutes: number): FocusTimerIntent {
    return new FocusTimerIntent('SELECT_DURATION', minutes);
  }

  public static selectTag(tag: FocusTag): FocusTimerIntent {
    return new FocusTimerIntent('SELECT_TAG', undefined, tag);
  }

  public static startTimer(): FocusTimerIntent {
    return new FocusTimerIntent('START_TIMER');
  }

  public static pauseTimer(): FocusTimerIntent {
    return new FocusTimerIntent('PAUSE_TIMER');
  }

  public static resumeTimer(): FocusTimerIntent {
    return new FocusTimerIntent('RESUME_TIMER');
  }

  public static giveUpTimer(): FocusTimerIntent {
    return new FocusTimerIntent('GIVE_UP_TIMER');
  }

  public static completeTimer(): FocusTimerIntent {
    return new FocusTimerIntent('COMPLETE_TIMER');
  }

  public static toggleWhiteNoise(noiseId?: string): FocusTimerIntent {
    return new FocusTimerIntent('TOGGLE_WHITE_NOISE', undefined, undefined, noiseId);
  }
}

/**
 * 专注一次性副作用强类型契约 (Side Effect)
 */
export class FocusTimerEffect {
  public type: string;
  public messageKey?: string;
  public pattern?: string;
  public recordId?: number;

  constructor(type: string, messageKey?: string, pattern?: string, recordId?: number) {
    this.type = type;
    this.messageKey = messageKey;
    this.pattern = pattern;
    this.recordId = recordId;
  }
}

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
        if (intent.minutes !== undefined) {
          this.selectDuration(intent.minutes);
        }
        break;
      case 'SELECT_TAG':
        if (intent.tag !== undefined) {
          this.selectTag(intent.tag);
        }
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
      hilog.warn(DOMAIN, TAG, `loadInitialData running in previewer or uninitialized: ${(err as Error).message}`);
      // 预览器环境优雅降级：注入默认展示数据，避免Node服务崩溃
      if (this.state.tags.length === 0) {
        const defaultTags: FocusTag[] = [
          { id: 1, name: '深度编码', colorHex: '#4EDEA3', iconName: 'code', isSystem: true },
          { id: 2, name: '哲学阅读', colorHex: '#60A5FA', iconName: 'book', isSystem: true },
          { id: 3, name: '呼吸冥想', colorHex: '#FBBF24', iconName: 'spa', isSystem: true },
          { id: 4, name: '界面创作', colorHex: '#ACC7FF', iconName: 'brush', isSystem: true }
        ];
        this.state.tags = defaultTags;
        this.state.currentTag = defaultTags[0];
      }
      this.state.todayTotalMinutes = 50;
      this.state.todayCompletedCount = 2;
    }
  }

  /**
   * 选择目标专注分钟数
   */
  private selectDuration(minutes: number): void {
    if (this.state.status === FocusState.RUNNING || this.state.status === FocusState.PAUSED) {
      this.emitEffect(new FocusTimerEffect('SHOW_TOAST', 'timeisland_toast_cannot_change_duration'));
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
    this.emitEffect(new FocusTimerEffect('TRIGGER_HAPTIC', undefined, 'tick'));
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

    this.emitEffect(new FocusTimerEffect('TRIGGER_HAPTIC', undefined, 'tick'));
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
    this.emitEffect(new FocusTimerEffect('TRIGGER_HAPTIC', undefined, 'tick'));
  }

  /**
   * 恢复计时
   */
  private resumeTimer(): void {
    if (this.state.status !== FocusState.PAUSED) {
      return;
    }
    this.state.status = FocusState.RUNNING;
    this.emitEffect(new FocusTimerEffect('TRIGGER_HAPTIC', undefined, 'tick'));
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

    this.emitEffect(new FocusTimerEffect('SHOW_TOAST', 'timeisland_toast_give_up'));
    this.emitEffect(new FocusTimerEffect('TRIGGER_HAPTIC', undefined, 'warning'));
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

    this.emitEffect(new FocusTimerEffect('TRIGGER_HAPTIC', undefined, 'complete'));
    this.emitEffect(new FocusTimerEffect('SHOW_TOAST', 'timeisland_toast_focus_completed'));
    this.emitEffect(new FocusTimerEffect('FOCUS_FINISHED', undefined, undefined, recordId));

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
    this.emitEffect(new FocusTimerEffect('TRIGGER_HAPTIC', undefined, 'tick'));
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
        this.dispatch(FocusTimerIntent.completeTimer());
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
