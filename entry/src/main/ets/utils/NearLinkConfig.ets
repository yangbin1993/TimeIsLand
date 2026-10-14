import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'NearLinkConfig';

/**
 * 星闪双子岛近场通信专属配置管理器
 * 职责: 统一管理星闪 Service UUID、广播设备名及协议操作码，实现配置与业务逻辑彻底解耦
 */
export class NearLinkConfig {
  /**
   * 默认星闪服务专属契约 UUID (当未从资源配置读取时作为安全降级兜底)
   */
  public static readonly DEFAULT_SERVICE_UUID: string = '37B72000-0000-1000-8000-00805F9B34FB';

  /**
   * 星闪广播与近场扫描设备名称
   */
  public static readonly DEVICE_BROADCAST_NAME: string = 'TimeIsland';

  /**
   * 交互协议操作码: 微风涟漪
   */
  public static readonly OP_BREEZE_RIPPLE: number = 0x01;

  /**
   * 运行时缓存的已解析 Service UUID
   */
  private static serviceUuid: string = NearLinkConfig.DEFAULT_SERVICE_UUID;

  /**
   * 初始化星闪配置 (从系统资源配置文件读取)
   *
   * @param context 应用上下文
   */
  public static init(context: Context): void {
    try {
      if (context && context.resourceManager) {
        const configuredUuid = context.resourceManager.getStringSync($r('app.string.nearlink_service_uuid').id);
        if (configuredUuid && configuredUuid.trim().length > 0) {
          NearLinkConfig.serviceUuid = configuredUuid.trim();
          hilog.info(DOMAIN, TAG, 'NearLink service UUID loaded from config: %{public}s', NearLinkConfig.serviceUuid);
          return;
        }
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to load nearlink_service_uuid from resource, fallback to default: %{public}s', JSON.stringify(err));
    }
    NearLinkConfig.serviceUuid = NearLinkConfig.DEFAULT_SERVICE_UUID;
  }

  /**
   * 获取当前配置生效的星闪 Service UUID
   */
  public static getServiceUuid(): string {
    return NearLinkConfig.serviceUuid;
  }
}
