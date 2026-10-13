import { userAuth } from '@kit.UserAuthenticationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'BiometricAuthManager';

/**
 * 生物识别及凭据能力状态契约
 */
export interface BiometricCapability {
  isSupported: boolean;
  hasFingerprint: boolean;
  hasFace: boolean;
  hasPin: boolean;
}

/**
 * 时光岛 - 生物特征识别与统一身份认证管理器 (BiometricAuthManager)
 * 职责: 封装 HarmonyOS NEXT 统一身份认证框架，支持指纹、人脸及锁屏密码多模态鉴权
 */
export class BiometricAuthManager {
  private static instance: BiometricAuthManager | null = null;

  public static getInstance(): BiometricAuthManager {
    if (!BiometricAuthManager.instance) {
      BiometricAuthManager.instance = new BiometricAuthManager();
    }
    return BiometricAuthManager.instance;
  }

  /**
   * 检查设备生物识别与安全凭据就绪状态
   */
  public checkCapability(): BiometricCapability {
    let hasFingerprint = false;
    let hasFace = false;
    let hasPin = false;

    try {
      userAuth.getAvailableStatus(userAuth.UserAuthType.FINGERPRINT, userAuth.AuthTrustLevel.ATL1);
      hasFingerprint = true;
    } catch (err) {
      hilog.info(DOMAIN, TAG, 'Fingerprint auth unavailable: %{public}s', JSON.stringify(err));
    }

    try {
      userAuth.getAvailableStatus(userAuth.UserAuthType.FACE, userAuth.AuthTrustLevel.ATL1);
      hasFace = true;
    } catch (err) {
      hilog.info(DOMAIN, TAG, 'Face auth unavailable: %{public}s', JSON.stringify(err));
    }

    try {
      userAuth.getAvailableStatus(userAuth.UserAuthType.PIN, userAuth.AuthTrustLevel.ATL1);
      hasPin = true;
    } catch (err) {
      hilog.info(DOMAIN, TAG, 'PIN auth unavailable: %{public}s', JSON.stringify(err));
    }

    const isSupported = hasFingerprint || hasFace || hasPin;
    return {
      isSupported: isSupported,
      hasFingerprint: hasFingerprint,
      hasFace: hasFace,
      hasPin: hasPin
    };
  }

  /**
   * 发起生物特征/锁屏凭据认证
   * @param title 认证控件提示标题
   * @returns Promise<boolean> 认证是否成功通过
   */
  public authenticate(title: string): Promise<boolean> {
    return new Promise<boolean>((resolve) => {
      try {
        const challenge = new Uint8Array([0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0]);
        const authType: userAuth.UserAuthType[] = [
          userAuth.UserAuthType.FINGERPRINT,
          userAuth.UserAuthType.FACE,
          userAuth.UserAuthType.PIN
        ];

        const authParam: userAuth.AuthParam = {
          challenge: challenge,
          authType: authType,
          authTrustLevel: userAuth.AuthTrustLevel.ATL1
        };

        const widgetParam: userAuth.WidgetParam = {
          title: title
        };

        const authInstance = userAuth.getUserAuthInstance(authParam, widgetParam);

        authInstance.on('result', {
          onResult(result: userAuth.UserAuthResult): void {
            hilog.info(DOMAIN, TAG, 'Auth result code: %{public}d', result.result);
            if (result.result === userAuth.UserAuthResultCode.SUCCESS) {
              resolve(true);
            } else {
              resolve(false);
            }
          }
        });

        authInstance.start();
      } catch (err) {
        hilog.error(DOMAIN, TAG, 'Failed to start user auth: %{public}s', JSON.stringify(err));
        resolve(false);
      }
    });
  }
}

export const biometricAuthManager = BiometricAuthManager.getInstance();
