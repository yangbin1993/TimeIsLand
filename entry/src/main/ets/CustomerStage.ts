import { AbilityConstant, AbilityStage, Want } from '@kit.AbilityKit';
import { Configuration } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'CustomerStage';
const DOMAIN: number = 0x0000;

/**
 * 应用程序进程级生命周期管理器 (AbilityStage)
 * 负责整个 HAP 模块初始化、跨进程请求调度与低内存状态响应
 */
export default class CustomerStage extends AbilityStage {

  onCreate(): void {
    super.onCreate();
    hilog.info(DOMAIN, TAG, 'Process AbilityStage onCreate: module initialized');
  }

  onAcceptWant(want: Want): string {
    hilog.info(DOMAIN, TAG, 'onAcceptWant: %{public}s', want.abilityName ?? 'unknown');
    return super.onAcceptWant(want);
  }

  onNewProcessRequest(want: Want): string {
    hilog.info(DOMAIN, TAG, 'onNewProcessRequest: %{public}s', want.abilityName ?? 'unknown');
    return super.onNewProcessRequest(want);
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    super.onConfigurationUpdate(newConfig);
    hilog.info(DOMAIN, TAG, 'Process Configuration updated');
  }

  onMemoryLevel(level: AbilityConstant.MemoryLevel): void {
    super.onMemoryLevel(level);
    hilog.warn(DOMAIN, TAG, 'Low memory warning received: level=%{public}d', level);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'Process AbilityStage onDestroy');
    super.onDestroy();
  }

  onPrepareTermination(): AbilityConstant.PrepareTermination {
    return super.onPrepareTermination();
  }

  onPrepareTerminationAsync(): Promise<AbilityConstant.PrepareTermination> {
    return super.onPrepareTerminationAsync();
  }
}