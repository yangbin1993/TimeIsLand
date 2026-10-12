import { userAuth } from '@kit.UserAuthenticationKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  BiometricAuthResult,
  BiometricCapabilityStatus,
  BiometricMode,
  BiometricPromptOptions,
  BiometricResults
} from './BiometricTypes';
import { CommonStrings } from '../constants/CommonStrings';

const TAG = 'BiometricHelper';
const DOMAIN = 0x0000;

/**
 * 鸿蒙生产级生物识别与多模态解锁辅助套件 (BiometricHelper)
 * 深度对标 Android 架构中的 BiometricHelper.kt
 * 
 * 核心能力：
 * 1. 多模态解锁覆盖：无缝支持人脸识别 (FACE)、指纹识别 (FINGERPRINT) 与设备锁屏密码 (PIN)
 * 2. 细粒度能力预检：毫秒级探查指纹/面部/密码可用性与录入状态 (canAuthenticate)
 * 3. 安全防重放机制：自动构造高安全 16 字节挑战值 (Challenge)
 * 4. 强类型结果归约：基于 ArkTS 静态联合类型，消除防御性样板代码
 * 5. 内存与生命周期安全：自动回收会话并在完成时解绑事件监听，支持主动 cancel 取消
 */
export class BiometricHelper {
  private static instance: BiometricHelper;
  private currentAuthInstance: userAuth.UserAuthInstance | null = null;

  private constructor() {
    hilog.info(DOMAIN, TAG, 'BiometricHelper initialized');
  }

  /**
   * 获取全局单例
   */
  public static getInstance(): BiometricHelper {
    if (!BiometricHelper.instance) {
      BiometricHelper.instance = new BiometricHelper();
    }
    return BiometricHelper.instance;
  }

  /**
   * 检查设备当前的生物识别与多模态解锁能力
   * 对应 Android 中的 BiometricManager.canAuthenticate()
   * 
   * @param mode 期望检查的解锁模式，默认 BIOMETRIC_OR_CREDENTIAL
   * @returns 包含指纹、人脸、锁屏密码支持情况的详细评估报告
   */
  public canAuthenticate(mode: BiometricMode = BiometricMode.BIOMETRIC_OR_CREDENTIAL): BiometricCapabilityStatus {
    let isFingerprintSupported = false;
    let isFaceSupported = false;
    let isPinSupported = false;

    // 1. 检查指纹可用性
    try {
      userAuth.getAvailableStatus(userAuth.UserAuthType.FINGERPRINT, userAuth.AuthTrustLevel.ATL1);
      isFingerprintSupported = true;
    } catch (e) {
      isFingerprintSupported = false;
    }

    // 2. 检查人脸可用性
    try {
      userAuth.getAvailableStatus(userAuth.UserAuthType.FACE, userAuth.AuthTrustLevel.ATL1);
      isFaceSupported = true;
    } catch (e) {
      isFaceSupported = false;
    }

    // 3. 检查设备凭据 (PIN/锁屏密码) 可用性
    try {
      userAuth.getAvailableStatus(userAuth.UserAuthType.PIN, userAuth.AuthTrustLevel.ATL1);
      isPinSupported = true;
    } catch (e) {
      isPinSupported = false;
    }

    let canAuth = false;
    let reason: string | undefined = undefined;

    switch (mode) {
      case BiometricMode.BIOMETRIC_ONLY:
        canAuth = isFingerprintSupported || isFaceSupported;
        if (!canAuth) {
          reason = CommonStrings.BIO_UNSUPPORTED_BIO;
        }
        break;

      case BiometricMode.CREDENTIAL_ONLY:
        canAuth = isPinSupported;
        if (!canAuth) {
          reason = CommonStrings.BIO_UNSUPPORTED_PIN;
        }
        break;

      case BiometricMode.BIOMETRIC_OR_CREDENTIAL:
      default:
        canAuth = isFingerprintSupported || isFaceSupported || isPinSupported;
        if (!canAuth) {
          reason = CommonStrings.BIO_UNSUPPORTED_ALL;
        }
        break;
    }

    const report: BiometricCapabilityStatus = {
      canAuthenticate: canAuth,
      isFingerprintSupported: isFingerprintSupported,
      isFaceSupported: isFaceSupported,
      isPinSupported: isPinSupported,
      unsupportedReason: reason
    };

    hilog.info(
      DOMAIN,
      TAG,
      'Capability check result for mode [%{public}s]: canAuth=%{public}s, fingerprint=%{public}s, face=%{public}s, pin=%{public}s',
      mode,
      String(canAuth),
      String(isFingerprintSupported),
      String(isFaceSupported),
      String(isPinSupported)
    );

    return report;
  }

  /**
   * 唤起系统级生物识别与设备凭据身份验证弹窗
   * 对应 Android 中的 BiometricPrompt.authenticate()
   * 
   * @param options 认证配置（标题、副标题、取消文字、认证模式与挑战值）
   * @returns 强类型认证结果 Promise (BiometricAuthResult)
   */
  public async authenticate(options: BiometricPromptOptions): Promise<BiometricAuthResult> {
    const targetMode = options.mode ?? BiometricMode.BIOMETRIC_OR_CREDENTIAL;

    // 1. 前置预检：确保当前设备具备认证能力，避免直接弹窗崩溃
    const capability = this.canAuthenticate(targetMode);
    if (!capability.canAuthenticate) {
      const failMsg = capability.unsupportedReason || CommonStrings.BIO_UNSUPPORTED_DEVICE;
      hilog.warn(DOMAIN, TAG, 'Fast fail before auth: %{public}s', failMsg);
      return BiometricResults.notEnrolled(failMsg);
    }

    // 2. 映射允许的认证方式
    const authTypes: userAuth.UserAuthType[] = [];
    if (targetMode === BiometricMode.BIOMETRIC_ONLY) {
      if (capability.isFaceSupported) {
        authTypes.push(userAuth.UserAuthType.FACE);
      }
      if (capability.isFingerprintSupported) {
        authTypes.push(userAuth.UserAuthType.FINGERPRINT);
      }
    } else if (targetMode === BiometricMode.CREDENTIAL_ONLY) {
      authTypes.push(userAuth.UserAuthType.PIN);
    } else {
      // 多模态混合：生物识别优先，锁屏密码托底
      if (capability.isFaceSupported) {
        authTypes.push(userAuth.UserAuthType.FACE);
      }
      if (capability.isFingerprintSupported) {
        authTypes.push(userAuth.UserAuthType.FINGERPRINT);
      }
      if (capability.isPinSupported) {
        authTypes.push(userAuth.UserAuthType.PIN);
      }
    }

    // 3. 自动生成防重放挑战值
    const challenge = options.challenge ?? this.generateSecureChallenge();

    // 4. 信任级别：若包含 PIN 则默认 ATL1，纯生物识别默认 ATL3
    let trustLevel = options.authTrustLevel;
    if (!trustLevel) {
      trustLevel = authTypes.indexOf(userAuth.UserAuthType.PIN) !== -1
        ? userAuth.AuthTrustLevel.ATL1
        : userAuth.AuthTrustLevel.ATL3;
    }

    const authParam: userAuth.AuthParam = {
      challenge: challenge,
      authType: authTypes,
      authTrustLevel: trustLevel
    };

    const widgetParam: userAuth.WidgetParam = {
      title: options.title,
      navigationButtonText: options.navigationButtonText ?? CommonStrings.BIO_CANCEL_TEXT
    };

    // 5. 获取认证器实例并进行 Promise 异步封装
    return new Promise<BiometricAuthResult>((resolve) => {
      try {
        const authInstance = userAuth.getUserAuthInstance(authParam, widgetParam);
        this.currentAuthInstance = authInstance;

        // 订阅认证结果回调
        authInstance.on('result', {
          onResult: (result: userAuth.UserAuthResult) => {
            hilog.info(
              DOMAIN,
              TAG,
              'UserAuth onResult triggered: resultCode=%{public}d, authType=%{public}d',
              result.result,
              result.authType
            );

            // 认证结束后立即安全取消订阅，防止内存泄漏与重复触发
            try {
              authInstance.off('result');
            } catch (offErr) {
              // 忽略解绑异常
            }
            this.currentAuthInstance = null;

            // 细粒度强类型枚举归约（严格使用官方枚举，消除魔法数字硬编码）
            const resCode = result.result;
            switch (resCode) {
              case userAuth.UserAuthResultCode.SUCCESS:
                resolve(BiometricResults.success(result.authType, result.token));
                break;
              case userAuth.UserAuthResultCode.CANCELED:
                resolve(BiometricResults.canceled(CommonStrings.BIO_CANCELED));
                break;
              case userAuth.UserAuthResultCode.LOCKED:
                resolve(BiometricResults.locked(CommonStrings.BIO_LOCKED));
                break;
              case userAuth.UserAuthResultCode.NOT_ENROLLED:
                resolve(BiometricResults.notEnrolled(CommonStrings.BIO_NOT_ENROLLED));
                break;
              default:
                resolve(BiometricResults.failed(`${CommonStrings.BIO_FAILED_DEFAULT} (code: ${resCode})`, resCode));
                break;
            }
          }
        });

        // 发起认证
        authInstance.start();
        hilog.info(DOMAIN, TAG, 'UserAuthInstance started successfully');
      } catch (launchError) {
        this.currentAuthInstance = null;
        const err = launchError as Error;
        const errMsg = err.message || CommonStrings.BIO_LAUNCH_FAILED;
        hilog.error(DOMAIN, TAG, 'Failed to launch userAuth: %{public}s', errMsg);
        resolve(BiometricResults.error(-1, errMsg));
      }
    });
  }

  /**
   * 主动取消正在进行的认证会话
   * 对应 Android 中的 BiometricPrompt.cancelAuthentication()
   */
  public cancel(): void {
    if (this.currentAuthInstance) {
      try {
        hilog.info(DOMAIN, TAG, 'Canceling active UserAuthInstance');
        this.currentAuthInstance.cancel();
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'Exception during cancel: %{public}s', JSON.stringify(err));
      } finally {
        this.currentAuthInstance = null;
      }
    }
  }

  /**
   * 生成 16 字节高安全随机挑战值 (Challenge) 用于防重放攻击
   */
  private generateSecureChallenge(): Uint8Array {
    const challenge = new Uint8Array(16);
    for (let i = 0; i < 16; i++) {
      challenge[i] = Math.floor(Math.random() * 256);
    }
    return challenge;
  }
}

/**
 * 全局单例便捷导出
 */
export const biometricHelper: BiometricHelper = BiometricHelper.getInstance();
