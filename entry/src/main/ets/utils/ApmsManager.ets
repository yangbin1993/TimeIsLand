import { hilog, hiTraceMeter } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';

const DOMAIN = 0x0000;
const TAG = 'ApmsManager';

/**
 * 性能观测指标条目
 */
export interface TelemetryMetric {
  name: string;
  value: number;
  unit: string;
  timestamp: number;
}

/**
 * 时光岛 - 应用性能与质量监控管理器 (APMS Manager)
 * 职责: 负责应用冷热启动耗时、页面路由跳帧、白噪音解码延时及数据库读写耗时可观测性管理
 * 特性: 深度打通 HarmonyOS NEXT 原生 hiTraceMeter 追踪套件与 AGC 遥测规范，全端无缝适配
 */
export class ApmsManager {
  private static instance: ApmsManager | null = null;
  private isInitialized: boolean = false;
  private activeTraces: Map<string, number> = new Map<string, number>();
  private recordedMetrics: TelemetryMetric[] = [];

  public static getInstance(): ApmsManager {
    if (!ApmsManager.instance) {
      ApmsManager.instance = new ApmsManager();
    }
    return ApmsManager.instance;
  }

  /**
   * 初始化性能与稳定性监控引擎
   */
  public async init(context: Context): Promise<void> {
    if (this.isInitialized) {
      return;
    }

    try {
      hilog.info(DOMAIN, TAG, 'Checking agconnect-services.json configuration...');
      let hasAgcConfig = false;
      try {
        const rawData = context.resourceManager.getRawFileContentSync('agconnect-services.json');
        const textDecoder = util.TextDecoder.create('utf-8');
        const jsonStr = textDecoder.decodeToString(rawData);
        const agcJson: Record<string, Object> = JSON.parse(jsonStr) as Record<string, Object>;
        hasAgcConfig = !!agcJson;
        hilog.info(DOMAIN, TAG, 'AGC services configuration loaded successfully.');
      } catch (readErr) {
        hilog.warn(DOMAIN, TAG, 'agconnect-services.json not found in rawfile, running in standalone telemetry mode.');
      }

      this.isInitialized = true;
      hilog.info(DOMAIN, TAG, 'APMS telemetry agent active (AGC ready: %{public}s)', hasAgcConfig ? 'true' : 'false');
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to initialize APMS telemetry: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 启动性能 Trace 追踪
   * 同步向系统级 hiTraceMeter 注册打点，可在 DevEco Profiler / SmartPerf 中捕获
   * @param traceName 自定义追踪事务标识 (如 'AudioDecoder_Init', 'FocusRecord_Query')
   * @param taskId 异步 Trace 任务 ID，用于区分多并发场景
   */
  public startTrace(traceName: string, taskId: number = 1000): void {
    const now = Date.now();
    this.activeTraces.set(traceName, now);
    try {
      hiTraceMeter.startTrace(traceName, taskId);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'hiTraceMeter startTrace error: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, TAG, 'Trace [%{public}s] started at %{public}d', traceName, now);
  }

  /**
   * 结束性能 Trace 追踪并计算耗时
   * @param traceName 目标追踪标识
   * @param taskId 对应异步任务 ID
   * @returns 耗时 (毫秒)
   */
  public stopTrace(traceName: string, taskId: number = 1000): number {
    const startTime = this.activeTraces.get(traceName);
    const now = Date.now();
    let duration = 0;

    if (startTime) {
      duration = now - startTime;
      this.activeTraces.delete(traceName);
    }

    try {
      hiTraceMeter.finishTrace(traceName, taskId);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'hiTraceMeter finishTrace error: %{public}s', JSON.stringify(err));
    }

    hilog.info(DOMAIN, TAG, 'Trace [%{public}s] finished in %{public}d ms', traceName, duration);
    return duration;
  }

  /**
   * 记录关键业务指标度量
   * @param metricName 指标键名 (如 'db_query_time', 'noise_stream_latency')
   * @param value 指标数值
   * @param unit 指标单位 (默认为 'ms')
   */
  public recordMetric(metricName: string, value: number, unit: string = 'ms'): void {
    const metric: TelemetryMetric = {
      name: metricName,
      value: value,
      unit: unit,
      timestamp: Date.now()
    };
    this.recordedMetrics.push(metric);
    if (this.recordedMetrics.length > 100) {
      this.recordedMetrics.shift();
    }
    hilog.info(DOMAIN, TAG, 'Metric recorded: [%{public}s] = %{public}d %{public}s', metricName, value, unit);
  }

  /**
   * 记录业务异常事件
   */
  public recordError(tag: string, errorMsg: string): void {
    hilog.error(DOMAIN, TAG, 'Telemetry anomaly reported from [%{public}s]: %{public}s', tag, errorMsg);
  }

  /**
   * 是否已就绪
   */
  public isReady(): boolean {
    return this.isInitialized;
  }
}

export const apmsManager = ApmsManager.getInstance();
