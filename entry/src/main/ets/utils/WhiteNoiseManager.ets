import { media } from '@kit.MediaKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'WhiteNoiseManager';

/**
 * 白噪音自然声景标识枚举
 */
export enum WhiteNoiseType {
  TIDE = 'tide',                     // 海潮晚风 (已导入首选 3 分钟高保真音频)
  MOSS_RAIN = 'moss_rain',           // 雨落青苔
  FOREST_SPRING = 'forest_spring'    // 林涧清泉
}

/**
 * 时光岛 - 自然白噪音伴随播放引擎 (WhiteNoiseManager)
 * 职责: 基于 HarmonyOS NEXT 原生 AVPlayer 引擎，提供无缝循环自然声景、平滑音量控制与专注起航停靠联动
 */
export class WhiteNoiseManager {
  private static instance: WhiteNoiseManager | null = null;
  private avPlayer: media.AVPlayer | null = null;
  private context: Context | null = null;
  private currentSoundId: string = WhiteNoiseType.TIDE;
  private isPlaying: boolean = false;
  private targetVolume: number = 0.8;
  private fadeIntervalId: number = -1;

  public static getInstance(): WhiteNoiseManager {
    if (!WhiteNoiseManager.instance) {
      WhiteNoiseManager.instance = new WhiteNoiseManager();
    }
    return WhiteNoiseManager.instance;
  }

  /**
   * 初始化播放引擎
   */
  public async init(context: Context): Promise<void> {
    this.context = context;
    try {
      if (!this.avPlayer) {
        this.avPlayer = await media.createAVPlayer();
        this.setupPlayerEvents();
        hilog.info(DOMAIN, TAG, 'WhiteNoise AVPlayer successfully created.');
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to create AVPlayer: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 注册 AVPlayer 生命周期与状态机事件
   */
  private setupPlayerEvents(): void {
    if (!this.avPlayer) {
      return;
    }

    this.avPlayer.on('stateChange', async (state: media.AVPlayerState) => {
      hilog.info(DOMAIN, TAG, 'AVPlayer state changed to: %{public}s', state);
      switch (state) {
        case 'initialized':
          if (this.avPlayer) {
            await this.avPlayer.prepare();
          }
          break;
        case 'prepared':
          if (this.avPlayer) {
            this.avPlayer.loop = true; // 开启无限无缝循环
            await this.avPlayer.setVolume(this.targetVolume);
            await this.avPlayer.play();
            this.isPlaying = true;
          }
          break;
        case 'playing':
          this.isPlaying = true;
          break;
        case 'paused':
        case 'stopped':
        case 'completed':
          this.isPlaying = false;
          break;
        case 'error':
          hilog.error(DOMAIN, TAG, 'AVPlayer error state encountered.');
          this.isPlaying = false;
          break;
      }
    });

    this.avPlayer.on('error', (err) => {
      hilog.error(DOMAIN, TAG, 'AVPlayer runtime error: %{public}s', JSON.stringify(err));
      this.isPlaying = false;
    });
  }

  /**
   * 播放指定声景 (支持平滑切换与 rawfile 自动读取)
   */
  public async playSound(soundId: string = WhiteNoiseType.TIDE): Promise<void> {
    if (!this.context) {
      hilog.warn(DOMAIN, TAG, 'Context not ready, cannot play white noise.');
      return;
    }

    this.currentSoundId = soundId;

    try {
      // 确保 AVPlayer 实例已就绪
      if (!this.avPlayer) {
        await this.init(this.context);
      }

      if (!this.avPlayer) {
        return;
      }

      // 重置播放器到 idle 态
      await this.avPlayer.reset();

      // 获取对应音频文件名 (海潮晚风: sound_tide.mp3, 雨落青苔: sound_rain.mp3, 林间清泉: sound_spring.mp3)
      let fileName = 'sound_tide.mp3';
      if (soundId === WhiteNoiseType.MOSS_RAIN) {
        fileName = 'sound_rain.mp3';
      } else if (soundId === WhiteNoiseType.FOREST_SPRING) {
        fileName = 'sound_spring.mp3';
      } else if (soundId === WhiteNoiseType.TIDE) {
        fileName = 'sound_tide.mp3';
      }
      const rawFd = await this.context.resourceManager.getRawFd(`audio/${fileName}`);

      // 赋值文件描述符，触发 initialized 状态流转
      this.avPlayer.fdSrc = rawFd;
      hilog.info(DOMAIN, TAG, 'Started loading white noise: %{public}s', fileName);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to play sound: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 暂停播放 (停靠息心时调用)
   */
  public async pause(): Promise<void> {
    if (this.avPlayer && this.isPlaying) {
      try {
        await this.avPlayer.pause();
        this.isPlaying = false;
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'Failed to pause AVPlayer: %{public}s', JSON.stringify(err));
      }
    }
  }

  /**
   * 恢复播放 (继续心流时调用)
   */
  public async resume(): Promise<void> {
    if (this.avPlayer && !this.isPlaying) {
      try {
        await this.avPlayer.play();
        this.isPlaying = true;
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'Failed to resume AVPlayer: %{public}s', JSON.stringify(err));
      }
    }
  }

  /**
   * 停止播放
   */
  public async stop(): Promise<void> {
    if (this.avPlayer) {
      try {
        await this.avPlayer.stop();
        this.isPlaying = false;
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'Failed to stop AVPlayer: %{public}s', JSON.stringify(err));
      }
    }
  }

  /**
   * 设置音量 (0.0 ~ 1.0)
   */
  public async setVolume(vol: number): Promise<void> {
    this.targetVolume = Math.max(0.0, Math.min(1.0, vol));
    if (this.avPlayer && this.isPlaying) {
      try {
        await this.avPlayer.setVolume(this.targetVolume);
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'Failed to set volume: %{public}s', JSON.stringify(err));
      }
    }
  }

  /**
   * 获取当前播放状态
   */
  public isAudioPlaying(): boolean {
    return this.isPlaying;
  }

  /**
   * 获取当前选中的声景 ID
   */
  public getCurrentSoundId(): string {
    return this.currentSoundId;
  }

  /**
   * 释放播放器资源
   */
  public async release(): Promise<void> {
    if (this.avPlayer) {
      try {
        await this.avPlayer.release();
        this.avPlayer = null;
        this.isPlaying = false;
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'Failed to release AVPlayer: %{public}s', JSON.stringify(err));
      }
    }
  }
}

export const whiteNoiseManager = WhiteNoiseManager.getInstance();
