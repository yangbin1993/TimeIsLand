import { huks } from '@kit.UniversalKeystoreKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { util } from '@kit.ArkTS';
import { EncryptedPayload, HuksKeyConfig } from './CryptoTypes';

const TAG = 'HuksHelper';
const DOMAIN = 0x0000;

/**
 * 主密钥默认别名（应用级唯一主密钥，由 HUKS 硬件安全元件托管）
 */
const DEFAULT_KEY_ALIAS = 'app_master_key_v1';

/**
 * AES-GCM 初始化向量长度（字节）
 */
const GCM_IV_LENGTH = 12;

/**
 * AES-GCM 认证标签长度（位）
 */
const GCM_AUTH_TAG_LENGTH = 128;

/**
 * HUKS 密钥操作工具类
 *
 * 核心能力：
 * 1. 基于 HUKS（Hardware Universal Key Store）硬件安全元件托管 AES-256 对称密钥，
 *    密钥材料永不离开 TEE，即便设备被 root 也无法提取明文密钥；
 * 2. 采用 AES-256-GCM 认证加密，提供机密性 + 完整性双重保护；
 * 3. 每次加密随机生成 12 字节 IV，杜绝密文重放攻击；
 * 4. 应用卸载时 HUKS 密钥自动销毁，旧密文无法被解密（自动降级返回 null）。
 */
export class HuksHelper {
  private static instance: HuksHelper;
  private readonly keyAlias: string;
  private readonly aad: string;

  private constructor(config?: HuksKeyConfig) {
    this.keyAlias = config?.keyAlias ?? DEFAULT_KEY_ALIAS;
    // AAD 使用密钥别名作为应用标识，防止跨应用密文复用攻击
    this.aad = `harmony_secure_store_${this.keyAlias}`;
  }

  /**
   * 获取全局单例实例
   */
  public static getInstance(config?: HuksKeyConfig): HuksHelper {
    if (!HuksHelper.instance) {
      HuksHelper.instance = new HuksHelper(config);
    }
    return HuksHelper.instance;
  }

  // ==================== 密钥管理 ====================

  /**
   * 生成或确认主密钥存在性
   * 若密钥已存在则跳过生成，保障幂等性
   */
  public async ensureKeyExists(): Promise<void> {
    const exists = await this.keyExists();
    if (!exists) {
      await this.generateKey();
      hilog.info(DOMAIN, TAG, `HUKS master key [${this.keyAlias}] generated.`);
    } else {
      hilog.info(DOMAIN, TAG, `HUKS master key [${this.keyAlias}] already exists, skipping generation.`);
    }
  }

  /**
   * 检查主密钥是否已存在于 HUKS 密钥库中
   */
  private async keyExists(): Promise<boolean> {
    const options: huks.HuksOptions = {
      properties: this.buildKeyProperties()
    };
    try {
      const result = await huks.isKeyItemExist(this.keyAlias, options);
      return result;
    } catch {
      return false;
    }
  }

  /**
   * 在 HUKS 中生成 AES-256 对称密钥
   * 密钥材料由 TEE 硬件生成并永久托管，不以任何形式暴露至应用层
   */
  private async generateKey(): Promise<void> {
    const properties: huks.HuksParam[] = [
      ...this.buildKeyProperties(),
      {
        tag: huks.HuksTag.HUKS_TAG_PURPOSE,
        value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT | huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT
      },
      { tag: huks.HuksTag.HUKS_TAG_KEY_SIZE, value: huks.HuksKeySize.HUKS_AES_KEY_SIZE_256 }
    ];

    const options: huks.HuksOptions = { properties };

    await huks.generateKeyItem(this.keyAlias, options);
  }

  /**
   * 删除 HUKS 中的主密钥（用于测试或安全注销场景）
   */
  public async deleteKey(): Promise<void> {
    const options: huks.HuksOptions = { properties: this.buildKeyProperties() };
    try {
      await huks.deleteKeyItem(this.keyAlias, options);
      hilog.info(DOMAIN, TAG, `HUKS master key [${this.keyAlias}] deleted.`);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Failed to delete HUKS key: ${(err as Error).message}`);
    }
  }

  // ==================== 加密 ====================

  /**
   * 使用 AES-256-GCM 加密任意字符串数据
   *
   * @param plaintext 待加密的明文字符串
   * @returns 包含密文、IV 和 AAD 的加密封包
   */
  public async encrypt(plaintext: string): Promise<EncryptedPayload> {
    await this.ensureKeyExists();

    // 随机生成 12 字节 GCM IV（每次加密唯一，防重放攻击）
    const iv = this.generateRandomIv();
    const aadBytes = new util.TextEncoder().encodeInto(this.aad);
    const plaintextBytes = new util.TextEncoder().encodeInto(plaintext);

    // 初始化加密操作（HUKS 三段式：init → update → finish）
    const initOptions = this.buildEncryptOptions(iv, aadBytes);
    const initResult = await huks.initSession(this.keyAlias, initOptions);
    const handle = initResult.handle;

    // 执行加密（update + finish）
    const updateOptions: huks.HuksOptions = {
      properties: initOptions.properties,
      inData: plaintextBytes
    };
    const finishOptions: huks.HuksOptions = {
      properties: initOptions.properties,
      inData: new Uint8Array(0)
    };

    try {
      await huks.updateSession(handle, updateOptions);
      const finishResult = await huks.finishSession(handle, finishOptions);

      if (!finishResult.outData) {
        throw new Error('HUKS encrypt finishSession returned empty outData.');
      }

      const base64 = new util.Base64Helper();
      return {
        ciphertext: base64.encodeToStringSync(finishResult.outData),
        iv: base64.encodeToStringSync(iv),
        aad: this.aad
      };
    } catch (err) {
      // 加密失败时主动废弃会话，防止 HUKS 资源泄漏
      await huks.abortSession(handle, { properties: [] }).catch(() => {});
      throw err;
    }
  }

  // ==================== 解密 ====================

  /**
   * 使用 AES-256-GCM 解密加密封包
   *
   * @param payload 加密封包（包含密文、IV 与 AAD）
   * @returns 解密后的明文字符串，解密失败返回 null
   */
  public async decrypt(payload: EncryptedPayload): Promise<string | null> {
    try {
      const base64 = new util.Base64Helper();
      const ciphertextBytes = base64.decodeSync(payload.ciphertext);
      const ivBytes = base64.decodeSync(payload.iv);
      const aadBytes = new util.TextEncoder().encodeInto(payload.aad);

      const initOptions = this.buildDecryptOptions(ivBytes, aadBytes);
      const initResult = await huks.initSession(this.keyAlias, initOptions);
      const handle = initResult.handle;

      const updateOptions: huks.HuksOptions = {
        properties: initOptions.properties,
        inData: ciphertextBytes
      };
      const finishOptions: huks.HuksOptions = {
        properties: initOptions.properties,
        inData: new Uint8Array(0)
      };

      try {
        await huks.updateSession(handle, updateOptions);
        const finishResult = await huks.finishSession(handle, finishOptions);

        if (!finishResult.outData) {
          return null;
        }

        const decoder = new util.TextDecoder();
        return decoder.decode(finishResult.outData);
      } catch (err) {
        await huks.abortSession(handle, { properties: [] }).catch(() => {});
        throw err;
      }
    } catch (err) {
      // 解密失败（密钥不存在、密文损坏等）返回 null，由调用方执行降级策略
      hilog.warn(DOMAIN, TAG, `Decryption failed, returning null: ${(err as Error).message}`);
      return null;
    }
  }

  // ==================== 私有工具方法 ====================

  /**
   * 构建 HUKS AES-256-GCM 基础密钥属性
   */
  private buildKeyProperties(): huks.HuksParam[] {
    return [
      { tag: huks.HuksTag.HUKS_TAG_ALGORITHM, value: huks.HuksKeyAlg.HUKS_ALG_AES },
      { tag: huks.HuksTag.HUKS_TAG_BLOCK_MODE, value: huks.HuksCipherMode.HUKS_MODE_GCM },
      { tag: huks.HuksTag.HUKS_TAG_PADDING, value: huks.HuksKeyPadding.HUKS_PADDING_NONE }
    ];
  }

  /**
   * 构建加密操作初始化选项
   */
  private buildEncryptOptions(iv: Uint8Array, aad: Uint8Array): huks.HuksOptions {
    return {
      properties: [
        ...this.buildKeyProperties(),
        { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_ENCRYPT },
        { tag: huks.HuksTag.HUKS_TAG_NONCE, value: iv },
        { tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: aad },
        { tag: huks.HuksTag.HUKS_TAG_AUTH_STORAGE_LEVEL, value: huks.HuksAuthStorageLevel.HUKS_AUTH_STORAGE_LEVEL_DE }
      ]
    };
  }

  /**
   * 构建解密操作初始化选项
   */
  private buildDecryptOptions(iv: Uint8Array, aad: Uint8Array): huks.HuksOptions {
    return {
      properties: [
        ...this.buildKeyProperties(),
        { tag: huks.HuksTag.HUKS_TAG_PURPOSE, value: huks.HuksKeyPurpose.HUKS_KEY_PURPOSE_DECRYPT },
        { tag: huks.HuksTag.HUKS_TAG_NONCE, value: iv },
        { tag: huks.HuksTag.HUKS_TAG_ASSOCIATED_DATA, value: aad },
        { tag: huks.HuksTag.HUKS_TAG_AUTH_STORAGE_LEVEL, value: huks.HuksAuthStorageLevel.HUKS_AUTH_STORAGE_LEVEL_DE }
      ]
    };
  }

  /**
   * 生成随机 GCM IV（12 字节）
   */
  private generateRandomIv(): Uint8Array {
    const iv = new Uint8Array(GCM_IV_LENGTH);
    for (let i = 0; i < GCM_IV_LENGTH; i++) {
      iv[i] = Math.floor(Math.random() * 256);
    }
    return iv;
  }
}

export { GCM_AUTH_TAG_LENGTH };
