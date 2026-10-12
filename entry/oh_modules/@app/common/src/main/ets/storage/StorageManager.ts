import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';

const TAG = 'PreferencesStorage';
const DOMAIN = 0x0000;

/**
 * 基础值类型联合约束（与鸿蒙 Preferences 支持的存储类型对齐）
 */
export type StorageValue = string | number | boolean | string[] | Uint8Array | object | null;

/**
 * 统一本地持久化存储抽象接口 (StorageManager)
 * 屏蔽 Preferences / RDB 底层细节，向上提供干净的键值存取契约
 */
export interface StorageManager {
  /**
   * 存储一个键值对
   *
   * @param key 存储键
   * @param value 存储值（支持基础类型、数组与 JSON 对象）
   */
  set(key: string, value: StorageValue): Promise<void>;

  /**
   * 读取字符串值
   *
   * @param key 存储键
   * @param defaultValue 键不存在时的默认回落值
   */
  getString(key: string, defaultValue?: string): Promise<string>;

  /**
   * 读取数值
   */
  getNumber(key: string, defaultValue?: number): Promise<number>;

  /**
   * 读取布尔值
   */
  getBoolean(key: string, defaultValue?: boolean): Promise<boolean>;

  /**
   * 读取字符串数组
   */
  getStringArray(key: string, defaultValue?: string[]): Promise<string[]>;

  /**
   * 以 JSON 序列化形式存储对象，并在读取时自动反序列化
   *
   * @param key 存储键
   * @param value 任意可 JSON 序列化的对象
   */
  setObject<T extends object>(key: string, value: T): Promise<void>;

  /**
   * 读取并反序列化 JSON 对象
   *
   * @param key 存储键
   * @param defaultValue 键不存在或解析失败时的默认值
   */
  getObject<T extends object>(key: string, defaultValue?: T): Promise<T | null>;

  /**
   * 检查指定键是否存在
   */
  has(key: string): Promise<boolean>;

  /**
   * 删除指定键
   */
  remove(key: string): Promise<void>;

  /**
   * 清空当前存储域的所有键值对
   */
  clear(): Promise<void>;

  /**
   * 将内存中的变更强制刷新持久化到磁盘（Preferences 的 flush 语义）
   */
  flush(): Promise<void>;
}

/**
 * 基于鸿蒙 Preferences (用户首选项) 的 StorageManager 生产实现
 *
 * 核心特性：
 * 1. 统一异步 API：封装鸿蒙 Preferences 的 callback 风格为现代 Promise/async，
 *    彻底消除嵌套回调地狱；
 * 2. 对象序列化透明：setObject/getObject 自动完成 JSON 序列化，支持任意可序列化数据类型；
 * 3. 防御性默认值：所有读取方法均提供默认值回落，规避 null 解引用崩溃；
 * 4. 多域隔离：构造时指定 storeName，不同业务域使用独立的 Preferences 文件互不干扰；
 * 5. 懒加载初始化：首次访问时自动完成 Preferences 实例创建，无需手动初始化。
 */
export class PreferencesStorage implements StorageManager {
  private prefsInstance: preferences.Preferences | null = null;
  private readonly storeName: string;
  private initPromise: Promise<void> | null = null;

  /**
   * @param context 应用上下文（用于 Preferences 文件路径解析）
   * @param storeName 存储文件名（不同业务域隔离，如 'user_prefs', 'app_config'）
   */
  constructor(private readonly context: common.Context, storeName: string) {
    this.storeName = storeName;
  }

  /**
   * 懒加载初始化 Preferences 实例（线程安全：并发调用复用同一 Promise）
   */
  private async ensureInitialized(): Promise<void> {
    if (this.prefsInstance) {
      return;
    }
    if (!this.initPromise) {
      this.initPromise = this.doInit();
    }
    await this.initPromise;
  }

  private async doInit(): Promise<void> {
    try {
      const options: preferences.Options = { name: this.storeName };
      this.prefsInstance = await preferences.getPreferences(this.context, options);
      hilog.info(DOMAIN, TAG, `Preferences [${this.storeName}] initialized successfully.`);
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Failed to initialize Preferences [${this.storeName}]: ${(err as Error).message}`);
      throw err;
    } finally {
      this.initPromise = null;
    }
  }

  // ==================== 写入操作 ====================

  public async set(key: string, value: StorageValue): Promise<void> {
    await this.ensureInitialized();
    try {
      await this.prefsInstance!.put(key, value as preferences.ValueType);
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Failed to set [${this.storeName}/${key}]: ${(err as Error).message}`);
      throw err;
    }
  }

  public async setObject<T extends object>(key: string, value: T): Promise<void> {
    const json = JSON.stringify(value);
    await this.set(key, json);
  }

  // ==================== 读取操作 ====================

  public async getString(key: string, defaultValue: string = ''): Promise<string> {
    await this.ensureInitialized();
    try {
      const val = await this.prefsInstance!.get(key, defaultValue);
      return val as string;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Failed to get string [${this.storeName}/${key}], returning default.`);
      return defaultValue;
    }
  }

  public async getNumber(key: string, defaultValue: number = 0): Promise<number> {
    await this.ensureInitialized();
    try {
      const val = await this.prefsInstance!.get(key, defaultValue);
      return val as number;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Failed to get number [${this.storeName}/${key}], returning default.`);
      return defaultValue;
    }
  }

  public async getBoolean(key: string, defaultValue: boolean = false): Promise<boolean> {
    await this.ensureInitialized();
    try {
      const val = await this.prefsInstance!.get(key, defaultValue);
      return val as boolean;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Failed to get boolean [${this.storeName}/${key}], returning default.`);
      return defaultValue;
    }
  }

  public async getStringArray(key: string, defaultValue: string[] = []): Promise<string[]> {
    await this.ensureInitialized();
    try {
      const val = await this.prefsInstance!.get(key, defaultValue);
      return val as string[];
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Failed to get string[] [${this.storeName}/${key}], returning default.`);
      return defaultValue;
    }
  }

  public async getObject<T extends object>(key: string, defaultValue?: T): Promise<T | null> {
    const json = await this.getString(key, '');
    if (!json) {
      return defaultValue ?? null;
    }
    try {
      return JSON.parse(json) as T;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Failed to parse JSON for [${this.storeName}/${key}], returning default.`);
      return defaultValue ?? null;
    }
  }

  // ==================== 管理操作 ====================

  public async has(key: string): Promise<boolean> {
    await this.ensureInitialized();
    try {
      return await this.prefsInstance!.has(key);
    } catch (err) {
      return false;
    }
  }

  public async remove(key: string): Promise<void> {
    await this.ensureInitialized();
    try {
      await this.prefsInstance!.delete(key);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Failed to remove [${this.storeName}/${key}]: ${(err as Error).message}`);
    }
  }

  public async clear(): Promise<void> {
    await this.ensureInitialized();
    try {
      await this.prefsInstance!.clear();
      hilog.info(DOMAIN, TAG, `Preferences [${this.storeName}] cleared.`);
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Failed to clear [${this.storeName}]: ${(err as Error).message}`);
      throw err;
    }
  }

  public async flush(): Promise<void> {
    await this.ensureInitialized();
    try {
      await this.prefsInstance!.flush();
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Failed to flush [${this.storeName}]: ${(err as Error).message}`);
      throw err;
    }
  }
}
