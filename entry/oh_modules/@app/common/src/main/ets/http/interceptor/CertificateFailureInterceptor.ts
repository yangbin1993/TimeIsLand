import { hilog } from '@kit.PerformanceAnalysisKit';
import { HttpInterceptor } from './Interceptor';
import { RequestContext, ResponseContext } from '../model/HttpOptions';
import { RcpPinningManager } from '../security/RcpPinningManager';

const TAG = 'CertificateFailureInterceptor';
const DOMAIN = 0x0000;

/**
 * 证书固定与安全自愈前置预检拦截器 (CertificateFailureInterceptor)
 * 对应 Android 架构中的 PinningFailureInterceptor.kt
 *
 * 核心逻辑：
 * 1. 全局预检：若 RcpPinningManager 处于降级状态（isPinningFallbackEnabled == true），
 *    自动在请求头装配 `X-Security-Fallback: 1` 标识，通知网关与监控端。
 * 2. 避免无谓重试：预先感知降级状态，避免请求重复经历"握手失败 -> 捕获异常 -> 逃生"的高延迟损耗。
 */
export class CertificateFailureInterceptor implements HttpInterceptor {
  private readonly pinningManager: RcpPinningManager;

  constructor(pinningManager?: RcpPinningManager) {
    this.pinningManager = pinningManager ?? RcpPinningManager.getInstance();
  }

  /**
   * 前置请求流转：预检安全降级状态
   */
  public async onRequest(context: RequestContext): Promise<RequestContext> {
    if (this.pinningManager.isPinningFallbackEnabled) {
      hilog.info(
        DOMAIN,
        TAG,
        'Global pre-check: network layer is in fallback mode (Soft Pinning), bypassing with system standard CA: %{public}s',
        context.url
      );
      // 注入请求头通知后端运维监控与风控系统，该客户端目前基于系统 CA 访问
      context.headers['X-Security-Fallback'] = '1';
    }
    return context;
  }

  /**
   * 后置响应流转：监听响应并记录安全状态
   */
  public async onResponse(response: ResponseContext): Promise<ResponseContext> {
    return response;
  }
}
