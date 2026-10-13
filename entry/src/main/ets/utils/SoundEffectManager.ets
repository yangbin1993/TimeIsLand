import { media } from '@kit.MediaKit';
import { audio } from '@kit.AudioKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'SoundEffectManager';

/**
 * 触感微拟物按键音效类型
 */
export enum SoundEffectType {
  PEN_CLICK = 'yuan_zhu_bi_sound.mp3',      // 圆珠笔微动机械按压 (起航胶囊/时长挡位)
  SWITCH_OPEN = 'kai_guan_sound_open.mp3',  // 开关开启 (设置页 Toggle 开)
  SWITCH_CLOSE = 'kai_guan_sound_close.mp3',// 开关关闭 (设置页 Toggle 关)
  BUBBLE = 'pao_pao_sound.mp3',            // 空灵气泡水滴 (主题/标签切换)
  SLIDE = 'hua_shou_ji_sound.mp3'           // 抽屉滑动摩擦 (白噪音抽屉展开)
}

/**
 * 时光岛 - 触感微拟物按键音效管理器 (SoundEffectManager)
 * 职责: 基于 HarmonyOS SoundPool 高并发低延迟音效池，提供毫秒级机械按键点击反馈
 */
export class SoundEffectManager {
  private static instance: SoundEffectManager | null = null;
  private soundPool: media.SoundPool | null = null;
  private soundIdMap: Map<SoundEffectType, number> = new Map();
  private isLoaded: boolean = false;
  private context: Context | null = null;

  public static getInstance(): SoundEffectManager {
    if (!SoundEffectManager.instance) {
      SoundEffectManager.instance = new SoundEffectManager();
    }
    return SoundEffectManager.instance;
  }

  /**
   * 初始化音效池并预加载 rawfile 音效资源
   */
  public async init(context: Context): Promise<void> {
    this.context = context;
    try {
      const audioRendererInfo: audio.AudioRendererInfo = {
        usage: audio.StreamUsage.STREAM_USAGE_NOTIFICATION,
        rendererFlags: 0
      };

      // 创建最大 4 通道并发的 SoundPool
      this.soundPool = await media.createSoundPool(4, audioRendererInfo);

      // 预加载所有按键短音效
      await this.loadAllSounds();
      this.isLoaded = true;
      hilog.info(DOMAIN, TAG, 'SoundPool successfully initialized and audio effects loaded.');
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to initialize SoundPool: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 预载所有短音频文件
   */
  private async loadAllSounds(): Promise<void> {
    if (!this.soundPool || !this.context) {
      return;
    }

    const soundTypes: SoundEffectType[] = [
      SoundEffectType.PEN_CLICK,
      SoundEffectType.SWITCH_OPEN,
      SoundEffectType.SWITCH_CLOSE,
      SoundEffectType.BUBBLE,
      SoundEffectType.SLIDE
    ];

    for (const type of soundTypes) {
      try {
        const rawFd = await this.context.resourceManager.getRawFd(`audio/effect/${type}`);
        const soundId = await this.soundPool.load(rawFd.fd, rawFd.offset, rawFd.length);
        this.soundIdMap.set(type, soundId);
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'Failed to load sound %{public}s: %{public}s', type, JSON.stringify(err));
      }
    }
  }

  /**
   * 播放触感按键音效 (检查用户全局声音开关)
   */
  public play(type: SoundEffectType): void {
    // 检查用户声音反馈配置 (AppStorage 响应式属性)
    const isSoundEnabled = AppStorage.get<boolean>('isSoundAlertEnabled') ?? true;
    if (!isSoundEnabled) {
      return;
    }

    if (!this.soundPool || !this.isLoaded) {
      return;
    }

    const soundId = this.soundIdMap.get(type);
    if (soundId !== undefined) {
      try {
        const playParameters: media.PlayParameters = {
          loop: 0,        // 不循环，仅单次触发
          rate: 1,        // 正常速率
          leftVolume: 0.8,
          rightVolume: 0.8,
          priority: 0
        };
        this.soundPool.play(soundId, playParameters);
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'Failed to play sound effect: %{public}s', JSON.stringify(err));
      }
    }
  }

  /**
   * 释放音效池资源
   */
  public async release(): Promise<void> {
    if (this.soundPool) {
      try {
        await this.soundPool.release();
        this.soundPool = null;
        this.soundIdMap.clear();
        this.isLoaded = false;
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'Failed to release SoundPool: %{public}s', JSON.stringify(err));
      }
    }
  }
}

export const soundEffectManager = SoundEffectManager.getInstance();
