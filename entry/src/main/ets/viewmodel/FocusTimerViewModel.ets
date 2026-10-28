import { hilog } from '@kit.PerformanceAnalysisKit';
import { BaseMviViewModel, AppLifecycleManager, AppForegroundState, ForegroundListener } from '@app/common';
import {
  FocusState,
  FocusTag,
  FocusRecordEntity,
  TAG_COLOR_WORK,
  TAG_COLOR_STUDY,
  TAG_COLOR_READING,
  TAG_COLOR_THINKING,
  TAG_COLOR_SPORT,
  TAG_COLOR_MEDITATION,
  TAG_COLOR_CREATIVE
} from '../model/FocusTypes';
import { timeIslandRepository, TimeIslandRepository } from '../data/TimeIslandRepository';
import { liveViewHelper } from '../utils/LiveViewHelper';

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
  public flowDriftSeconds: number = 0;
  public isGraceHavenActive: boolean = false;
  public graceHavenRemainingSeconds: number = 120;
  public isGracePeriodUsed: boolean = false;
  public currentTag: FocusTag | null = null;
  public tags: FocusTag[] = [];
  public isWhiteNoisePlaying: boolean = false;
  public selectedNoiseId: string = 'forest';
  public todayTotalMinutes: number = 0;
  public todayCompletedCount: number = 0;
  public allTimeMinutes: number = 0;

  /**
   * 格式化展示时间 (倒计时 MM:SS 或 心流延展 +MM:SS)
   */
  public get formattedTime(): string {
    if (this.status === FocusState.FLOW_DRIFT) {
      const mins = Math.floor(this.flowDriftSeconds / 60);
      const secs = this.flowDriftSeconds % 60;
      return `+${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
    }
    const mins = Math.floor(this.remainingSeconds / 60);
    const secs = this.remainingSeconds % 60;
    return `${mins.toString().padStart(2, '0')}:${secs.toString().padStart(2, '0')}`;
  }

  /**
   * 当前进度比例 (0.0 ~ 1.0)
   */
  public get progress(): number {
    if (this.status === FocusState.FLOW_DRIFT) {
      return 1.0;
    }
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
  public recordId?: number;
  public note?: string;
  public rating?: number;

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

  public static saveReflection(recordId: number, note: string, rating: number): FocusTimerIntent {
    const intent = new FocusTimerIntent('SAVE_REFLECTION');
    intent.recordId = recordId;
    intent.note = note;
    intent.rating = rating;
    return intent;
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
  public lastCompletedRecordId: number = 0;
  private repository: TimeIslandRepository;
  private timerId: number = -1;
  private focusStartTime: number = 0;
  private pausedFromState: FocusState = FocusState.RUNNING;
  private graceStartTime: number = 0;
  private graceHavenDuration: number = 120;
  private graceTimerId: number = -1;
  private foregroundListener: ForegroundListener | null = null;

  constructor(repository: TimeIslandRepository = timeIslandRepository) {
    super();
    this.repository = repository;
    this.foregroundListener = (appState: AppForegroundState): void => {
      this.handleAppForegroundChange(appState);
    };
    AppLifecycleManager.getInstance().addForegroundListener(this.foregroundListener);
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
      case 'SAVE_REFLECTION':
        if (intent.recordId !== undefined && intent.rating !== undefined) {
          this.saveReflection(intent.recordId, intent.note || '', intent.rating);
        }
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
      this.state.allTimeMinutes = overview.allTimeMinutes;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `loadInitialData running in previewer or uninitialized: ${(err as Error).message}`);
      // 预览器环境优雅降级：注入默认展示数据，避免Node服务崩溃
      if (this.state.tags.length === 0) {
        const defaultTags: FocusTag[] = [
          { id: 1, name: '工作', colorHex: TAG_COLOR_WORK, iconName: 'code', isSystem: true },
          { id: 2, name: '学习', colorHex: TAG_COLOR_STUDY, iconName: 'book', isSystem: true },
          { id: 3, name: '阅读', colorHex: TAG_COLOR_READING, iconName: 'reader', isSystem: true },
          { id: 4, name: '思考', colorHex: TAG_COLOR_THINKING, iconName: 'brain', isSystem: true },
          { id: 5, name: '运动', colorHex: TAG_COLOR_SPORT, iconName: 'sport', isSystem: true },
          { id: 6, name: '冥想', colorHex: TAG_COLOR_MEDITATION, iconName: 'spa', isSystem: true },
          { id: 7, name: '创作', colorHex: TAG_COLOR_CREATIVE, iconName: 'brush', isSystem: true }
        ];
        this.state.tags = defaultTags;
        this.state.currentTag = defaultTags[0];
      }
      this.state.todayTotalMinutes = 50;
      this.state.todayCompletedCount = 2;
      this.state.allTimeMinutes = 320;
    }
  }

  /**
   * 选择目标专注分钟数
   */
  private selectDuration(minutes: number): void {
    if (this.state.status === FocusState.RUNNING || this.state.status === FocusState.FLOW_DRIFT || this.state.status === FocusState.PAUSED) {
      this.emitEffect(new FocusTimerEffect('SHOW_TOAST', 'timeisland_toast_cannot_change_duration'));
      return;
    }
    this.state.selectedMinutes = minutes;
    this.state.remainingSeconds = minutes * 60;
    this.state.actualFocusedSeconds = 0;
    this.state.flowDriftSeconds = 0;
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
    if (this.state.status === FocusState.RUNNING || this.state.status === FocusState.FLOW_DRIFT) {
      return;
    }
    this.clearTimer();
    this.focusStartTime = Date.now();
    this.state.status = FocusState.RUNNING;
    this.state.actualFocusedSeconds = 0;
    this.state.flowDriftSeconds = 0;
    this.state.remainingSeconds = this.state.selectedMinutes * 60;

    this.emitEffect(new FocusTimerEffect('TRIGGER_HAPTIC', undefined, 'tick'));
    liveViewHelper.startLiveView(this.state.currentTag?.name || '', this.state.remainingSeconds);
    this.runTickLoop();
  }

  /**
   * 暂停计时 (支持普通专注或心流延展态下暂停)
   */
  private pauseTimer(): void {
    if (this.state.status !== FocusState.RUNNING && this.state.status !== FocusState.FLOW_DRIFT) {
      return;
    }
    this.clearTimer();
    this.pausedFromState = this.state.status;
    this.state.status = FocusState.PAUSED;
    this.emitEffect(new FocusTimerEffect('TRIGGER_HAPTIC', undefined, 'tick'));
    liveViewHelper.updateLiveView(this.state.remainingSeconds, true, this.pausedFromState === FocusState.FLOW_DRIFT, this.state.flowDriftSeconds);
  }

  /**
   * 恢复计时 (精准恢复至暂停前的状态)
   */
  private resumeTimer(): void {
    if (this.state.status !== FocusState.PAUSED) {
      return;
    }
    this.state.status = this.pausedFromState;
    this.emitEffect(new FocusTimerEffect('TRIGGER_HAPTIC', undefined, 'tick'));
    liveViewHelper.updateLiveView(this.state.remainingSeconds, false, this.state.status === FocusState.FLOW_DRIFT, this.state.flowDriftSeconds);
    this.runTickLoop();
  }

  /**
   * 放弃或提前取消
   */
  private async giveUpTimer(): Promise<void> {
    this.clearTimer();
    liveViewHelper.stopLiveView();
    const actualSecs = this.state.actualFocusedSeconds;
    const tagId = this.state.currentTag ? this.state.currentTag.id : 1;
    const startTime = this.focusStartTime;
    const endTime = Date.now();

    this.state.status = FocusState.IDLE;
    this.state.remainingSeconds = this.state.selectedMinutes * 60;
    this.state.actualFocusedSeconds = 0;
    this.state.flowDriftSeconds = 0;

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
   * 达成或主动完成心流结夏
   */
  private async completeTimer(): Promise<void> {
    this.clearTimer();
    liveViewHelper.stopLiveView();
    const wasDrifting = this.state.status === FocusState.FLOW_DRIFT || this.state.flowDriftSeconds > 0;
    const driftSecs = this.state.flowDriftSeconds;
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
      state: FocusState.COMPLETED,
      isFlowDrift: wasDrifting,
      driftSeconds: driftSecs,
      isGracePeriodUsed: this.state.isGracePeriodUsed,
      note: driftSecs > 0 ? `[FlowDrift: +${driftSecs}s]` : (this.state.isGracePeriodUsed ? '[GraceHaven: Protected]' : undefined)
    };

    let recordId = 0;
    try {
      recordId = await this.repository.saveFocusRecord(record);
      this.lastCompletedRecordId = recordId;
      // 累加今日指标
      const addedMins = Math.floor(actualSecs / 60);
      this.state.todayTotalMinutes += addedMins;
      this.state.allTimeMinutes += addedMins;
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
    this.state.flowDriftSeconds = 0;
    this.state.isGraceHavenActive = false;
    this.state.isGracePeriodUsed = false;
  }

  /**
   * 保存专注随笔心得与气韵星级
   */
  public async saveReflection(recordId: number, note: string, rating: number): Promise<void> {
    try {
      await this.repository.updateFocusRecordReflection(recordId, note, rating);
      this.emitEffect(new FocusTimerEffect('SHOW_TOAST', 'reflection_dialog_toast_saved'));
      this.emitEffect(new FocusTimerEffect('TRIGGER_HAPTIC', undefined, 'tick'));
      this.emitEffect(new FocusTimerEffect('REFLECTION_SAVED', undefined, undefined, recordId));
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Failed to save reflection for record #${recordId}: ${(err as Error).message}`);
    }
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
   * 每秒循环调度步进 (支持无界心流延展)
   */
  private runTickLoop(): void {
    this.timerId = setInterval((): void => {
      if (this.state.status !== FocusState.RUNNING && this.state.status !== FocusState.FLOW_DRIFT) {
        return;
      }

      this.state.actualFocusedSeconds += 1;

      if (this.state.status === FocusState.RUNNING) {
        if (this.state.remainingSeconds > 0) {
          this.state.remainingSeconds -= 1;
        }

        // 核心无界心流延展：倒计时归零，不暴力打断，自动转入心流漫游正向累加态
        if (this.state.remainingSeconds <= 0) {
          this.state.status = FocusState.FLOW_DRIFT;
          this.state.flowDriftSeconds = 0;
          this.emitEffect(new FocusTimerEffect('FLOW_TARGET_REACHED'));
          this.emitEffect(new FocusTimerEffect('SHOW_TOAST', 'timeisland_toast_flow_drift_started'));
          this.emitEffect(new FocusTimerEffect('TRIGGER_HAPTIC', undefined, 'complete'));
          liveViewHelper.updateLiveView(0, false, true, 0);
        }
      } else if (this.state.status === FocusState.FLOW_DRIFT) {
        // 心流延展增量每秒累加
        this.state.flowDriftSeconds += 1;
        if (this.state.flowDriftSeconds % 10 === 0) {
          liveViewHelper.updateLiveView(0, false, true, this.state.flowDriftSeconds);
        }
      }
    }, 1000);
  }

  private clearTimer(): void {
    if (this.timerId !== -1) {
      clearInterval(this.timerId);
      this.timerId = -1;
    }
  }

  /**
   * 前后台生命周期变化事件处理
   */
  private handleAppForegroundChange(appState: AppForegroundState): void {
    hilog.info(DOMAIN, TAG, `App lifecycle state changed: ${appState}`);
    if (appState === AppForegroundState.BACKGROUND) {
      this.onEnterBackground();
    } else if (appState === AppForegroundState.FOREGROUND) {
      this.onEnterForeground();
    }
  }

  /**
   * 切入后台：激活心流避风港缓冲倒计时
   */
  private onEnterBackground(): void {
    if (this.state.status !== FocusState.RUNNING && this.state.status !== FocusState.FLOW_DRIFT) {
      return;
    }

    const isGraceHavenEnabled = AppStorage.get<boolean>('isGraceHavenEnabled') ?? true;
    if (!isGraceHavenEnabled) {
      return;
    }

    const graceDuration = AppStorage.get<number>('graceHavenSeconds') ?? 120;
    this.graceHavenDuration = graceDuration;
    this.graceStartTime = Date.now();
    this.state.isGraceHavenActive = true;
    this.state.graceHavenRemainingSeconds = graceDuration;

    this.emitEffect(new FocusTimerEffect('GRACE_HAVEN_ENTERED'));

    this.clearGraceTimer();
    this.graceTimerId = setInterval((): void => {
      const elapsedSecs = Math.floor((Date.now() - this.graceStartTime) / 1000);
      const remaining = Math.max(0, this.graceHavenDuration - elapsedSecs);
      this.state.graceHavenRemainingSeconds = remaining;

      if (remaining <= 0) {
        this.clearGraceTimer();
        this.handleGraceTimeoutDocking();
      }
    }, 1000);
  }

  /**
   * 返回前台：检查是否在避风港缓冲期内
   */
  private onEnterForeground(): void {
    if (!this.state.isGraceHavenActive) {
      return;
    }

    this.clearGraceTimer();
    const elapsedSecs = Math.floor((Date.now() - this.graceStartTime) / 1000);

    if (elapsedSecs < this.graceHavenDuration) {
      // 成功在安全缓冲期内归岛：心流完好无损，纯度继续守护！
      this.state.isGraceHavenActive = false;
      this.state.isGracePeriodUsed = true;
      this.emitEffect(new FocusTimerEffect('GRACE_HAVEN_RESTORED'));
      this.emitEffect(new FocusTimerEffect('SHOW_TOAST', 'timeisland_toast_grace_haven_returned'));
      this.emitEffect(new FocusTimerEffect('TRIGGER_HAPTIC', undefined, 'complete'));
    } else {
      // 超时返回
      this.handleGraceTimeoutDocking();
    }
  }

  /**
   * 避风港超时收官归档 (不暴力打断抹除，优雅保存已专注成果)
   */
  private async handleGraceTimeoutDocking(): Promise<void> {
    this.clearTimer();
    this.clearGraceTimer();
    this.state.isGraceHavenActive = false;
    liveViewHelper.stopLiveView();

    const actualSecs = this.state.actualFocusedSeconds;
    const tagId = this.state.currentTag ? this.state.currentTag.id : 1;
    const targetMins = this.state.selectedMinutes;
    const startTime = this.focusStartTime > 0 ? this.focusStartTime : Date.now() - actualSecs * 1000;
    const endTime = Date.now();

    if (actualSecs >= 30) {
      const record: FocusRecordEntity = {
        tagId: tagId,
        targetMinutes: targetMins,
        actualSeconds: actualSecs,
        startTime: startTime,
        endTime: endTime,
        state: FocusState.COMPLETED,
        isGracePeriodUsed: true,
        graceOvertimeDocked: true,
        note: `[GraceHaven Timeout: Docked ${actualSecs}s]`
      };

      try {
        await this.repository.saveFocusRecord(record);
        const addedMins = Math.floor(actualSecs / 60);
        this.state.todayTotalMinutes += addedMins;
        this.state.todayCompletedCount += 1;
      } catch (err) {
        hilog.error(DOMAIN, TAG, `Failed to save grace timeout record: ${(err as Error).message}`);
      }
    }

    this.state.status = FocusState.IDLE;
    this.state.remainingSeconds = this.state.selectedMinutes * 60;
    this.state.actualFocusedSeconds = 0;
    this.state.flowDriftSeconds = 0;

    this.emitEffect(new FocusTimerEffect('GRACE_HAVEN_TIMEOUT_DOCKED'));
    this.emitEffect(new FocusTimerEffect('SHOW_TOAST', 'timeisland_toast_grace_haven_timeout'));
    this.emitEffect(new FocusTimerEffect('TRIGGER_HAPTIC', undefined, 'warning'));
  }

  private clearGraceTimer(): void {
    if (this.graceTimerId !== -1) {
      clearInterval(this.graceTimerId);
      this.graceTimerId = -1;
    }
  }

  public onCleared(): void {
    this.clearTimer();
    this.clearGraceTimer();
    if (this.foregroundListener) {
      AppLifecycleManager.getInstance().removeForegroundListener(this.foregroundListener);
      this.foregroundListener = null;
    }
    super.onCleared();
  }
}
