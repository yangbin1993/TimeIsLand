import { connection } from '@kit.NetworkKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { HttpInterceptor } from './Interceptor';
import { RequestContext } from '../model/HttpOptions';
import { NetworkError } from '../model/HttpErrors';
import { CommonStrings } from '../../constants/CommonStrings';

const TAG = 'NetworkStateInterceptor';
const DOMAIN = 0x0000;

/**
 * 鸿蒙专属网络状态感知与快速断网熔断拦截器 (NetworkStateInterceptor)
 * 深度融合鸿蒙系统级 @kit.NetworkKit 连接能力：
 * 
 * 核心机制：
 * 1. 毫秒级断网快速熔断：请求前通过 connection.hasDefaultNetSync() 同步检测系统是否有可用网络链路。
 *    若设备处于离线状态（如飞行模式或断网），0ms 瞬间拒绝并抛出 NetworkError，彻底规避长达 10 秒的底层握手超时，极大优化用户反馈体验与整机功耗。
 * 2. 蜂窝网络流量保护：针对配置了 options.wifiOnly 的敏感请求（如 OTA 升级、大文件同步），自动校验承载媒介类型，阻断蜂窝环境下的意外流量消耗。
 */
export class NetworkStateInterceptor implements HttpInterceptor {
  public onRequest(context: RequestContext): RequestContext {
    try {
      // 1. 快速检查系统是否存在激活的默认网络连接
      const hasNet = connection.hasDefaultNetSync();
      if (!hasNet) {
        hilog.warn(DOMAIN, TAG, `Fast-fail triggered: No active network for [${context.method}] ${context.url}`);
        throw new NetworkError(CommonStrings.NET_FAST_FAIL);
      }

      // 2. 蜂窝移动网络与 WiFi 流量保护拦截校验
      if (context.options?.wifiOnly) {
        const netHandle = connection.getDefaultNetSync();
        const netCapabilities = connection.getNetCapabilitiesSync(netHandle);

        // 检查网络承载媒介类型（WiFi / 蜂窝）
        const isWifi = netCapabilities.bearerTypes.some(
          (bearer) => bearer === connection.NetBearType.BEARER_WIFI
        );

        if (!isWifi) {
          hilog.warn(DOMAIN, TAG, `Traffic protection triggered: Request blocked on non-WiFi network for ${context.url}`);
          throw new NetworkError(CommonStrings.NET_WIFI_ONLY_BLOCK);
        }
      }
    } catch (error) {
      if (error instanceof NetworkError) {
        throw error;
      }
      // 如果处于权限未授予或特定轻量虚拟环境，打印警告并优雅放行，不阻断底层通信
      hilog.info(DOMAIN, TAG, 'NetworkState check bypassed due to environment: %{public}s', JSON.stringify(error));
    }

    return context;
  }
}
