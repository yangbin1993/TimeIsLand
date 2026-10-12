import { userAuth } from '@kit.UserAuthenticationKit';
import { CommonStrings } from '../constants/CommonStrings';

/**
 * 生物识别与设备解锁模式枚举
 */
export enum BiometricMode {
  /**
   * 仅生物识别 (强安全级别：指纹或 3D 人脸)
   */
  BIOMETRIC_ONLY = 'BIOMETRIC_ONLY',

  /**
   * 多模态混合：生物识别优先，支持降级为锁屏密码/PIN (对标 Android BIOMETRIC_STRONG or DEVICE_CREDENTIAL)
   */
  BIOMETRIC_OR_CREDENTIAL = 'BIOMETRIC_OR_CREDENTIAL',

  /**
   * 仅设备凭据：锁屏 PIN 密码 / 混合密码
   */
  CREDENTIAL_ONLY = 'CREDENTIAL_ONLY'
}

/**
 * 认证成功结果契约
 */
export interface BiometricSuccess {
  status: 'SUCCESS';
  authType: userAuth.UserAuthType;
  authTypeName: string;
  token?: Uint8Array;
}

/**
 * 认证未匹配失败（如指纹或人脸不匹配）
 */
export interface BiometricFailed {
  status: 'FAILED';
  message: string;
  code: number;
}

/**
 * 用户主动取消或返回
 */
export interface BiometricCanceled {
  status: 'CANCELED';
  message: string;
}

/**
 * 连续多次尝试失败导致硬件临时安全锁定
 */
export interface BiometricLocked {
  status: 'LOCKED';
  message: string;
  remainSeconds?: number;
}

/**
 * 设备未录入生物识别信息或未设置锁屏密码
 */
export interface BiometricNotEnrolled {
  status: 'NOT_ENROLLED';
  message: string;
}

/**
 * 系统或硬件异常错误
 */
export interface BiometricError {
  status: 'ERROR';
  errorCode: number;
  message: string;
}

/**
 * 强类型生物识别认证结果密封联合类型 (BiometricAuthResult)
 * 严格遵循 ArkTS 强类型约束，彻底杜绝 any 与匿名对象字面量
 */
export type BiometricAuthResult =
  | BiometricSuccess
  | BiometricFailed
  | BiometricCanceled
  | BiometricLocked
  | BiometricNotEnrolled
  | BiometricError;

/**
 * 生物识别结果静态工厂助手类
 */
export class BiometricResults {
  public static success(authType: userAuth.UserAuthType, token?: Uint8Array): BiometricSuccess {
    let typeName = CommonStrings.BIO_TYPE_CREDENTIAL;
    if (authType === userAuth.UserAuthType.FINGERPRINT) {
      typeName = CommonStrings.BIO_TYPE_FINGERPRINT;
    } else if (authType === userAuth.UserAuthType.FACE) {
      typeName = CommonStrings.BIO_TYPE_FACE;
    } else if (authType === userAuth.UserAuthType.PIN) {
      typeName = CommonStrings.BIO_TYPE_PIN;
    }

    const res: BiometricSuccess = {
      status: 'SUCCESS',
      authType: authType,
      authTypeName: typeName,
      token: token
    };
    return res;
  }

  public static failed(message: string = CommonStrings.BIO_FAILED_DEFAULT, code: number = -1): BiometricFailed {
    const res: BiometricFailed = {
      status: 'FAILED',
      message: message,
      code: code
    };
    return res;
  }

  public static canceled(message: string = CommonStrings.BIO_CANCELED): BiometricCanceled {
    const res: BiometricCanceled = {
      status: 'CANCELED',
      message: message
    };
    return res;
  }

  public static locked(message: string = CommonStrings.BIO_LOCKED, remainSeconds?: number): BiometricLocked {
    const res: BiometricLocked = {
      status: 'LOCKED',
      message: message,
      remainSeconds: remainSeconds
    };
    return res;
  }

  public static notEnrolled(message: string = CommonStrings.BIO_NOT_ENROLLED): BiometricNotEnrolled {
    const res: BiometricNotEnrolled = {
      status: 'NOT_ENROLLED',
      message: message
    };
    return res;
  }

  public static error(errorCode: number, message: string): BiometricError {
    const res: BiometricError = {
      status: 'ERROR',
      errorCode: errorCode,
      message: message
    };
    return res;
  }
}

/**
 * 认证唤起提示配置参数
 */
export interface BiometricPromptOptions {
  /**
   * 认证主标题（例如：“请验证指纹以解锁”）
   */
  title: string;

  /**
   * 认证副标题/描述信息
   */
  subtitle?: string;

  /**
   * 导航/取消按键文字（默认：“取消”）
   */
  navigationButtonText?: string;

  /**
   * 认证模式（默认：BIOMETRIC_OR_CREDENTIAL）
   */
  mode?: BiometricMode;

  /**
   * 期望的认证信任等级（默认：ATL3，高安全性）
   */
  authTrustLevel?: userAuth.AuthTrustLevel;

  /**
   * 自定义防重放安全挑战值（如不提供则由 BiometricHelper 自动生成 16 字节随机数）
   */
  challenge?: Uint8Array;
}

/**
 * 设备认证能力可用性检查报告
 */
export interface BiometricCapabilityStatus {
  /**
   * 当前请求的认证模式下是否具备可认证能力
   */
  canAuthenticate: boolean;

  /**
   * 设备是否支持并已录入指纹识别
   */
  isFingerprintSupported: boolean;

  /**
   * 设备是否支持并已录入面部识别
   */
  isFaceSupported: boolean;

  /**
   * 设备是否已设置锁屏密码 (PIN)
   */
  isPinSupported: boolean;

  /**
   * 不可用时的明确原因解释
   */
  unsupportedReason?: string;
}
