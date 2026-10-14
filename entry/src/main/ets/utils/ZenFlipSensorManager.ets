import { sensor } from '@kit.SensorServiceKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'ZenFlipSensorManager';

/**
 * 翻转静心状态枚举
 */
export enum ZenFlipState {
  DISABLED = 'DISABLED',
  IDLE = 'IDLE',
  ARMED = 'ARMED',
  SCREEN_DOWN = 'SCREEN_DOWN',
  SCREEN_UP = 'SCREEN_UP'
}

export type ZenFlipListener = (state: ZenFlipState) => void;

/**
 * 时光岛 - 翻转静心 (Zen Flip) 真实传感器融合管理器
 * 职责: 监听鸿蒙重力加速度传感器，实现扣放专注与翻起打断/暂停的完整物理交互闭环
 */
export class ZenFlipSensorManager {
  private static instance: ZenFlipSensorManager | null = null;
  private isSupported: boolean = false;
  private isListening: boolean = false;
  private currentState: ZenFlipState = ZenFlipState.IDLE;
  private listeners: ZenFlipListener[] = [];

  // 防抖滤波计数
  private consecutiveDownCount: number = 0;
  private consecutiveUpCount: number = 0;
  private readonly TRIGGER_THRESHOLD_COUNT: number = 2;

  private sensorCallback = (data: sensor.AccelerometerResponse): void => {
    this.handleAccelerometerData(data);
  };

  public static getInstance(): ZenFlipSensorManager {
    if (!ZenFlipSensorManager.instance) {
      ZenFlipSensorManager.instance = new ZenFlipSensorManager();
    }
    return ZenFlipSensorManager.instance;
  }

  constructor() {
    this.checkCapability();
  }

  private checkCapability(): void {
    try {
      this.isSupported = canIUse('SystemCapability.Sensors.Sensor');
      hilog.info(DOMAIN, TAG, 'Sensor capability support: %{public}s', this.isSupported ? 'true' : 'false');
    } catch (err) {
      this.isSupported = false;
      hilog.warn(DOMAIN, TAG, 'Sensor capability check failed: %{public}s', JSON.stringify(err));
    }
  }

  public getState(): ZenFlipState {
    return this.currentState;
  }

  public isSensorSupported(): boolean {
    return this.isSupported;
  }

  public addListener(listener: ZenFlipListener): void {
    this.listeners.push(listener);
  }

  public removeListener(listener: ZenFlipListener): void {
    this.listeners = this.listeners.filter(l => l !== listener);
  }

  private notifyStateChanged(): void {
    this.listeners.forEach(l => l(this.currentState));
  }

  /**
   * 就绪翻转静心监听 (等待扣放)
   */
  public armZenFlip(): boolean {
    const isEnabled = AppStorage.get<boolean>('isZenFlipEnabled') ?? true;
    if (!isEnabled) {
      this.currentState = ZenFlipState.DISABLED;
      this.notifyStateChanged();
      return false;
    }

    if (!this.isSupported) {
      hilog.warn(DOMAIN, TAG, 'Sensor not supported on device');
      return false;
    }

    this.consecutiveDownCount = 0;
    this.consecutiveUpCount = 0;
    this.currentState = ZenFlipState.ARMED;
    this.notifyStateChanged();
    this.startSensorSubscription();
    return true;
  }

  /**
   * 解除翻转静心监听并归正状态
   */
  public disarmZenFlip(): void {
    this.stopSensorSubscription();
    this.currentState = ZenFlipState.IDLE;
    this.consecutiveDownCount = 0;
    this.consecutiveUpCount = 0;
    this.notifyStateChanged();
  }

  private startSensorSubscription(): void {
    if (this.isListening) {
      return;
    }

    try {
      // 采样周期 200,000,000 ns (200ms)
      sensor.on(sensor.SensorId.ACCELEROMETER, this.sensorCallback, { interval: 200000000 });
      this.isListening = true;
      hilog.info(DOMAIN, TAG, 'Accelerometer subscription started for Zen Flip');
    } catch (err) {
      this.isListening = false;
      hilog.error(DOMAIN, TAG, 'Failed to subscribe accelerometer: %{public}s', JSON.stringify(err));
    }
  }

  private stopSensorSubscription(): void {
    if (!this.isListening) {
      return;
    }

    try {
      sensor.off(sensor.SensorId.ACCELEROMETER, this.sensorCallback);
      this.isListening = false;
      hilog.info(DOMAIN, TAG, 'Accelerometer subscription stopped');
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to unsubscribe accelerometer: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 空间姿态动力学判定：
   * 屏幕朝下水平扣放: z < -7.0 m/s^2 且水平加速度分量 |x| < 4.0 且 |y| < 4.0
   * 翻起屏幕朝上: z > -3.0 m/s^2
   */
  private handleAccelerometerData(data: sensor.AccelerometerResponse): void {
    const isScreenDown = data.z < -7.0 && Math.abs(data.x) < 4.0 && Math.abs(data.y) < 4.0;
    const isScreenUp = data.z > -3.0;

    if (isScreenDown) {
      this.consecutiveUpCount = 0;
      this.consecutiveDownCount++;

      if (this.consecutiveDownCount >= this.TRIGGER_THRESHOLD_COUNT) {
        if (this.currentState === ZenFlipState.ARMED || this.currentState === ZenFlipState.SCREEN_UP) {
          hilog.info(DOMAIN, TAG, 'Phone flipped face-down. Triggering SCREEN_DOWN.');
          this.currentState = ZenFlipState.SCREEN_DOWN;
          this.notifyStateChanged();
        }
      }
    } else if (isScreenUp) {
      this.consecutiveDownCount = 0;
      this.consecutiveUpCount++;

      if (this.consecutiveUpCount >= this.TRIGGER_THRESHOLD_COUNT) {
        if (this.currentState === ZenFlipState.SCREEN_DOWN) {
          hilog.info(DOMAIN, TAG, 'Phone flipped face-up. Triggering SCREEN_UP.');
          this.currentState = ZenFlipState.SCREEN_UP;
          this.notifyStateChanged();
        }
      }
    } else {
      this.consecutiveDownCount = 0;
      this.consecutiveUpCount = 0;
    }
  }
}

export const zenFlipSensorManager = ZenFlipSensorManager.getInstance();
