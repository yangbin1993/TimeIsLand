import { hilog } from '@kit.PerformanceAnalysisKit';
import { EncryptedPayload } from '../crypto/CryptoTypes';
import { HuksHelper } from '../crypto/HuksHelper';
import { StorageManager, StorageValue, PreferencesStorage } from './StorageManager';
import { common } from '@kit.AbilityKit';

const TAG = 'SecureStorageManager';
const DOMAIN = 0x0000;

/**
 * 安全加密存储管理器 (SecureStorageManager)
 *
 * 架构设计：
 *   明文数据 → HUKS AES-256-GCM 加密 → Base64 密文 → PreferencesStorage 落盘
 *   落盘密文 → PreferencesStorage 读取 → Base64 → HUKS 解密 → 明文数据
 *
 * 核心特性：
 * 1. 完全实现 StorageManager 接口，与 PreferencesStorage 可无缝替换，业务层零感知；
 * 2. 密钥由 HUKS 硬件安全元件托管，密钥材料永不离开 TEE；
 * 3. 应用卸载后 HUKS 密钥自动销毁，旧密文无法解密，自动返回 defaultValue 降级；
 * 4. 非敏感数据（如 UI 偏好）请使用 PreferencesStorage 以避免不必要的加密开销。
 *
 * 适用场景：
 * - Access Token / Refresh Token
 * - 用户密码/凭证缓存
 * - 业务级敏感配置
 */
export class SecureStorageManager implements StorageManager {
  private readonly inner: PreferencesStorage;
  private readonly huks: HuksHelper;

  /**
   * @param context 应用上下文
   * @param storeName 底层 Preferences 存储文件名（建议使用 'secure_store' 等独立域名）
   */
  constructor(context: common.Context, storeName: string = 'secure_store') {
    this.inner = new PreferencesStorage(context, storeName);
    this.huks = HuksHelper.getInstance();
  }

  // ==================== 内部加密工具 ====================

  /**
   * 加密任意字符串并序列化为可存储的 JSON 字符串
   */
  private async encryptValue(plaintext: string): Promise<string> {
    const payload: EncryptedPayload = await this.huks.encrypt(plaintext);
    return JSON.stringify(payload);
  }

  /**
   * 从 Preferences 读取序列化密文，解密并返回明文字符串
   * 若密钥不存在或密文损坏，返回 null（调用方自行处理降级）
   */
  private async decryptValue(key: string): Promise<string | null> {
    const raw = await this.inner.getString(key, '');
    if (!raw) {
      return null;
    }
    try {
      const payload: EncryptedPayload = JSON.parse(raw) as EncryptedPayload;
      return await this.huks.decrypt(payload);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Failed to parse encrypted payload for key [${key}]: ${(err as Error).message}`);
      return null;
    }
  }

  // ==================== StorageManager 接口实现 ====================

  /**
   * 加密存储键值对
   * 内部将 value 转换为字符串后进行 AES-256-GCM 加密，落盘时为密文
   */
  public async set(key: string, value: StorageValue): Promise<void> {
    try {
      const plaintext = typeof value === 'string' ? value : JSON.stringify(value);
      const encrypted = await this.encryptValue(plaintext);
      await this.inner.set(key, encrypted);
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Failed to securely set [${key}]: ${(err as Error).message}`);
      throw err;
    }
  }

  public async setObject<T extends object>(key: string, value: T): Promise<void> {
    return this.set(key, JSON.stringify(value));
  }

  public async getString(key: string, defaultValue: string = ''): Promise<string> {
    const plaintext = await this.decryptValue(key);
    return plaintext ?? defaultValue;
  }

  public async getNumber(key: string, defaultValue: number = 0): Promise<number> {
    const plaintext = await this.decryptValue(key);
    if (plaintext === null) {
      return defaultValue;
    }
    const num = Number(plaintext);
    return isNaN(num) ? defaultValue : num;
  }

  public async getBoolean(key: string, defaultValue: boolean = false): Promise<boolean> {
    const plaintext = await this.decryptValue(key);
    if (plaintext === null) {
      return defaultValue;
    }
    return plaintext === 'true';
  }

  public async getStringArray(key: string, defaultValue: string[] = []): Promise<string[]> {
    const plaintext = await this.decryptValue(key);
    if (plaintext === null) {
      return defaultValue;
    }
    try {
      return JSON.parse(plaintext) as string[];
    } catch {
      return defaultValue;
    }
  }

  public async getObject<T extends object>(key: string, defaultValue?: T): Promise<T | null> {
    const plaintext = await this.decryptValue(key);
    if (plaintext === null) {
      return defaultValue ?? null;
    }
    try {
      return JSON.parse(plaintext) as T;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Failed to parse decrypted JSON for [${key}]: ${(err as Error).message}`);
      return defaultValue ?? null;
    }
  }

  public async has(key: string): Promise<boolean> {
    return this.inner.has(key);
  }

  public async remove(key: string): Promise<void> {
    return this.inner.remove(key);
  }

  public async clear(): Promise<void> {
    return this.inner.clear();
  }

  public async flush(): Promise<void> {
    return this.inner.flush();
  }
}
