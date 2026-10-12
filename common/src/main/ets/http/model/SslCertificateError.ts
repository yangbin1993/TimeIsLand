import { NetworkError } from './HttpErrors';
import { CommonStrings } from '../../constants/CommonStrings';

/**
 * SSL/TLS 安全证书异常结构化信息契约
 */
export interface SslErrorInfo {
  errorCode: number;
  isExpired: boolean;
  isPinningMismatch: boolean;
  targetDomain?: string;
}

/**
 * SSL/TLS 证书与安全握手异常 (SslCertificateError)
 * 产生场景：
 * 1. 服务端 HTTPS 证书过期 (Certificate Expired)
 * 2. 证书锁定 (Certificate Pinning) 公钥指纹与服务器证书链不匹配
 * 3. 自签名证书不受信任、证书吊销或握手协议不兼容（如 RCP 错误码 2300060）
 */
export class SslCertificateError extends NetworkError {
  /**
   * 底层网络/安全套件错误代码（如 RCP 2300060）
   */
  public readonly sslErrorCode: number;

  /**
   * 是否明确判定为证书过期
   */
  public readonly isExpired: boolean;

  /**
   * 是否为证书锁定 (Pinning) 公钥指纹不匹配
   */
  public readonly isPinningMismatch: boolean;

  /**
   * 触发异常的目标域名
   */
  public readonly targetDomain: string;

  constructor(
    message: string,
    sslErrorCode: number = 2300060,
    isExpired: boolean = false,
    isPinningMismatch: boolean = false,
    targetDomain: string = '',
    raw?: Object
  ) {
    super(message, raw);
    this.name = 'SslCertificateError';
    this.sslErrorCode = sslErrorCode;
    this.isExpired = isExpired;
    this.isPinningMismatch = isPinningMismatch;
    this.targetDomain = targetDomain;
  }

  /**
   * 静态检测函数：智能识别是否属于 SSL 证书/指纹/握手异常
   * 
   * @param error 捕获到的异常对象
   * @returns 是否为 SSL/证书相关错误
   */
  public static isSslOrCertError(error: Object | Error): boolean {
    if (error instanceof SslCertificateError) {
      return true;
    }

    // 检查是否具备错误代码属性
    const errObj = error as Record<string, Object>;
    if (errObj && typeof errObj['code'] === 'number') {
      const code = errObj['code'] as number;
      // 鸿蒙 RCP 典型证书/安全错误码：2300060 (CURLE_PEER_FAILED_VERIFICATION), 2300035 (SSL connect error)
      if (code === 2300060 || code === 2300035 || code === 2300058 || code === 2300077) {
        return true;
      }
    }

    // 检查错误文本特征关键字
    const msg = (error instanceof Error ? error.message : String(error)).toLowerCase();
    const sslKeywords: string[] = [
      'ssl',
      'certificate',
      'peer certificate',
      'cert',
      'expired',
      'pinning',
      'handshake',
      'unverified',
      '2300060'
    ];

    for (let i = 0; i < sslKeywords.length; i++) {
      if (msg.indexOf(sslKeywords[i]) !== -1) {
        return true;
      }
    }

    return false;
  }

  /**
   * 静态工厂：从底层未知异常解析并构建强类型 SslCertificateError
   * 
   * @param error 底层捕获异常
   * @param targetDomain 目标访问域名
   */
  public static fromError(error: Object | Error, targetDomain: string = ''): SslCertificateError {
    if (error instanceof SslCertificateError) {
      return error;
    }

    const errObj = error as Record<string, Object>;
    let code = 2300060;
    if (errObj && typeof errObj['code'] === 'number') {
      code = errObj['code'] as number;
    }

    const msg = error instanceof Error ? error.message : String(error);
    const lowerMsg = msg.toLowerCase();
    const isExpired = lowerMsg.indexOf('expired') !== -1 || lowerMsg.indexOf('date') !== -1;
    const isPinningMismatch = lowerMsg.indexOf('pin') !== -1 || lowerMsg.indexOf('peer certificate') !== -1 || code === 2300060;

    let friendlyMsg = CommonStrings.SSL_SECURITY_INTERCEPT;
    if (isExpired) {
      friendlyMsg = CommonStrings.SSL_EXPIRED;
    } else if (isPinningMismatch) {
      friendlyMsg = CommonStrings.SSL_PINNING_MISMATCH;
    }

    return new SslCertificateError(
      `${friendlyMsg} (${msg})`,
      code,
      isExpired,
      isPinningMismatch,
      targetDomain,
      error
    );
  }
}
