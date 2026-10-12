/**
 * 加密模块核心类型定义
 * 对标 Android Keystore + AES-GCM 加密模型，适配鸿蒙 HUKS 接口规范
 */

/**
 * AES-GCM 加密结果封包
 * 包含密文、初始化向量（IV）与认证标签（AAD），三者共同存储以保障解密完整性
 */
export interface EncryptedPayload {
  /**
   * Base64 编码的密文数据
   */
  ciphertext: string;

  /**
   * Base64 编码的 GCM 初始化向量（12 字节随机值，每次加密唯一生成）
   */
  iv: string;

  /**
   * 附加认证数据（Additional Authenticated Data），用于完整性校验
   * 格式为应用包名，防止跨应用密文复用攻击
   */
  aad: string;
}

/**
 * HUKS 密钥配置选项
 */
export interface HuksKeyConfig {
  /**
   * 密钥别名（全局唯一标识，对应 HUKS 密钥库中的存储键）
   */
  keyAlias: string;

  /**
   * GCM 认证标签长度（位），推荐使用 128 位
   */
  authTagLength?: number;
}

/**
 * 加密操作句柄（HUKS 三段式操作的上下文）
 */
export interface CryptoSession {
  handle: number;
}
