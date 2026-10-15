import { userAuth } from '@kit.UserAuthenticationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const DOMAIN = 0x0000;
const TAG = 'BiometricAuthManager';

/**
 * 凭据模式类型枚举
 */
export enum BiometricModeType {
  FACE = 'FACE',               // 面容识别 (极速首选)
  FINGERPRINT = 'FINGERPRINT', // 指纹识别 (触感交互)
  PIN = 'PIN',                 // 锁屏凭据 (系统兜底)
  NONE = 'NONE'                // 未就绪
}

/**
 * 降级链路节点数据模型
 */
export interface CredentialChainNode {
  type: BiometricModeType;
  nameRes: Resource;
  badgeRes: Resource;
  iconRes: Resource;
  isPrimary: boolean;
}

/**
 * 生物识别及凭据能力状态契约
 */
export interface BiometricCapability {
  isSupported: boolean;
  hasFingerprint: boolean;
  hasFace: boolean;
  hasPin: boolean;
  primaryMode: BiometricModeType;
  chainNodes: CredentialChainNode[];
}

/**
 * 时光岛 - 生物特征识别与统一身份认证管理器 (BiometricAuthManager)
 * 职责: 封装 HarmonyOS NEXT 统一身份认证框架，支持人脸优先、指纹协同、锁屏密码兜底的智能降级鉴权
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
   * 检查设备生物识别与安全凭据就绪状态，并动态构建智能降级链路
   */
  public checkCapability(): BiometricCapability {
    let hasFingerprint = false;
    let hasFace = false;
    let hasPin = false;

    // 1. 检测面容能力 (ATL1 基础信任级)
    try {
      userAuth.getAvailableStatus(userAuth.UserAuthType.FACE, userAuth.AuthTrustLevel.ATL1);
      hasFace = true;
    } catch (err) {
      hilog.info(DOMAIN, TAG, 'Face auth unavailable: %{public}s', JSON.stringify(err));
    }

    // 2. 检测指纹能力
    try {
      userAuth.getAvailableStatus(userAuth.UserAuthType.FINGERPRINT, userAuth.AuthTrustLevel.ATL1);
      hasFingerprint = true;
    } catch (err) {
      hilog.info(DOMAIN, TAG, 'Fingerprint auth unavailable: %{public}s', JSON.stringify(err));
    }

    // 3. 检测系统锁屏密码/PIN能力
    try {
      userAuth.getAvailableStatus(userAuth.UserAuthType.PIN, userAuth.AuthTrustLevel.ATL1);
      hasPin = true;
    } catch (err) {
      hilog.info(DOMAIN, TAG, 'PIN auth unavailable: %{public}s', JSON.stringify(err));
    }

    const isSupported = hasFace || hasFingerprint || hasPin;
    const chainNodes: CredentialChainNode[] = [];

    // 优先层: 面容识别 (无感极速首选)
    if (hasFace) {
      chainNodes.push({
        type: BiometricModeType.FACE,
        nameRes: $r('app.string.timeisland_settings_biometric_face'),
        badgeRes: $r('app.string.timeisland_settings_biometric_badge_primary'),
        iconRes: $r('app.media.ic_shield_check'),
        isPrimary: true
      });
    }

    // 次级层: 指纹识别 (触控感应降级)
    if (hasFingerprint) {
      const isPrimary = chainNodes.length === 0;
      chainNodes.push({
        type: BiometricModeType.FINGERPRINT,
        nameRes: $r('app.string.timeisland_settings_biometric_fingerprint'),
        badgeRes: isPrimary ? $r('app.string.timeisland_settings_biometric_badge_primary') : $r('app.string.timeisland_settings_biometric_badge_fallback'),
        iconRes: $r('app.media.ic_shield_check'),
        isPrimary: isPrimary
      });
    }

    // 兜底层: 锁屏凭据/PIN (系统密码兜底)
    if (hasPin) {
      const isPrimary = chainNodes.length === 0;
      chainNodes.push({
        type: BiometricModeType.PIN,
        nameRes: $r('app.string.timeisland_settings_biometric_pin'),
        badgeRes: isPrimary ? $r('app.string.timeisland_settings_biometric_badge_primary') : $r('app.string.timeisland_settings_biometric_badge_last'),
        iconRes: $r('app.media.ic_shield_check'),
        isPrimary: isPrimary
      });
    }

    const primaryMode = chainNodes.length > 0 ? chainNodes[0].type : BiometricModeType.NONE;

    return {
      isSupported: isSupported,
      hasFingerprint: hasFingerprint,
      hasFace: hasFace,
      hasPin: hasPin,
      primaryMode: primaryMode,
      chainNodes: chainNodes
    };
  }

  /**
   * 发起生物特征/锁屏凭据认证 (自适应动态组织多模态安全参数)
   * @param title 认证控件提示标题
   * @returns Promise<boolean> 认证是否成功通过
   */
  public authenticate(title: string): Promise<boolean> {
    return new Promise<boolean>((resolve) => {
      try {
        const capability = this.checkCapability();
        if (!capability.isSupported) {
          hilog.warn(DOMAIN, TAG, 'No authentication credentials available on this device');
          resolve(false);
          return;
        }

        // 动态组织当前设备已就绪的认证模态，严格按 [FACE, FINGERPRINT, PIN] 降级顺序调度
        const authTypes: userAuth.UserAuthType[] = [];
        if (capability.hasFace) {
          authTypes.push(userAuth.UserAuthType.FACE);
        }
        if (capability.hasFingerprint) {
          authTypes.push(userAuth.UserAuthType.FINGERPRINT);
        }
        if (capability.hasPin) {
          authTypes.push(userAuth.UserAuthType.PIN);
        }

        const challenge = new Uint8Array([0x12, 0x34, 0x56, 0x78, 0x9a, 0xbc, 0xde, 0xf0]);
        const authParam: userAuth.AuthParam = {
          challenge: challenge,
          authType: authTypes,
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
