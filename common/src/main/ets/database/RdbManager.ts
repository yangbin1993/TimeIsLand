import { relationalStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { common } from '@kit.AbilityKit';
import { RdbConfig, Migration, TableSchema, ColumnDefinition } from './RdbTypes';

const TAG = 'RdbManager';
const DOMAIN = 0x0000;

/**
 * 关系型数据库单例管理器 (RdbManager)
 *
 * 核心能力：
 * 1. 单例 RdbStore 懒加载：首次调用 getStore() 时异步建库，并发调用复用同一 Promise；
 * 2. 版本号驱动的自动 Migration：检测到版本升级时，按 from→to 顺序在事务中依次执行迁移，
 *    任意迁移步骤失败自动回滚，保障数据完整性；
 * 3. TableSchema 自动建表：通过 Schema 描述符自动生成 CREATE TABLE IF NOT EXISTS SQL，
 *    无需手写 DDL，减少拼写错误；
 * 4. 安全关闭：应用退出时调用 close() 释放数据库连接句柄，防止 FD 泄漏。
 */
export class RdbManager {
  private static instance: RdbManager;
  private rdbStore: relationalStore.RdbStore | null = null;
  private initPromise: Promise<relationalStore.RdbStore> | null = null;
  private config: RdbConfig | null = null;
  private context: common.Context | null = null;
  private schemas: TableSchema[] = [];

  private constructor() {}

  /**
   * 获取全局单例实例
   */
  public static getInstance(): RdbManager {
    if (!RdbManager.instance) {
      RdbManager.instance = new RdbManager();
    }
    return RdbManager.instance;
  }

  // ==================== 初始化与配置 ====================

  /**
   * 初始化数据库配置（必须在调用 getStore() 之前完成）
   *
   * @param context 应用上下文
   * @param config 数据库配置（名称、版本、迁移策略）
   * @param schemas 需要自动建表的表结构描述符列表
   */
  public initialize(context: common.Context, config: RdbConfig, schemas: TableSchema[] = []): void {
    this.context = context;
    this.config = config;
    this.schemas = schemas;
    hilog.info(DOMAIN, TAG, `RdbManager configured: ${config.name} v${config.version}`);
  }

  /**
   * 注册额外的表结构 Schema（需在 getStore() 调用前完成）
   */
  public registerSchema(schema: TableSchema): void {
    this.schemas.push(schema);
  }

  // ==================== 数据库访问 ====================

  /**
   * 获取 RdbStore 实例（懒加载，并发调用自动合并为同一 Promise）
   */
  public async getStore(): Promise<relationalStore.RdbStore> {
    if (this.rdbStore) {
      return this.rdbStore;
    }
    if (!this.initPromise) {
      this.initPromise = this.doOpen();
    }
    try {
      this.rdbStore = await this.initPromise;
      return this.rdbStore;
    } finally {
      this.initPromise = null;
    }
  }

  /**
   * 关闭数据库连接（在 AppAbility.onDestroy 中调用以释放 FD 句柄）
   */
  public async close(): Promise<void> {
    if (this.rdbStore) {
      await this.rdbStore.close();
      this.rdbStore = null;
      hilog.info(DOMAIN, TAG, 'RdbStore closed.');
    }
  }

  // ==================== 事务工具 ====================

  /**
   * 在事务中执行一组数据库操作（任意步骤异常自动回滚）
   *
   * @param action 事务执行函数
   */
  public async inTransaction(action: (store: relationalStore.RdbStore) => Promise<void>): Promise<void> {
    const store = await this.getStore();
    await store.beginTransaction();
    try {
      await action(store);
      await store.commit();
    } catch (err) {
      await store.rollBack();
      hilog.error(DOMAIN, TAG, `Transaction rolled back: ${(err as Error).message}`);
      throw err;
    }
  }

  /**
   * 触发端云增量同步 (当登录华为账号且网络就绪时由上层调度)
   */
  public async syncCloud(mode: relationalStore.SyncMode = relationalStore.SyncMode.SYNC_MODE_TIME_FIRST): Promise<boolean> {
    try {
      if (!this.rdbStore) {
        return false;
      }
      if (typeof this.rdbStore.cloudSync === 'function') {
        await this.rdbStore.cloudSync(mode, (progressDetails: relationalStore.ProgressDetails) => {
          hilog.info(DOMAIN, TAG, `Cloud sync progress: ${JSON.stringify(progressDetails)}`);
        });
        return true;
      }
      return false;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Cloud sync skipped or running in mock environment: ${(err as Error).message}`);
      return false;
    }
  }

  // ==================== 私有初始化方法 ====================

  /**
   * 执行数据库开启与版本升级流程
   */
  private async doOpen(): Promise<relationalStore.RdbStore> {
    if (!this.context || !this.config) {
      throw new Error('RdbManager: initialize() must be called before getStore().');
    }

    const storeConfig: relationalStore.StoreConfig = {
      name: this.config.name,
      securityLevel: this.config.securityLevel ?? relationalStore.SecurityLevel.S1
    };

    const store = await relationalStore.getRdbStore(this.context, storeConfig);
    hilog.info(DOMAIN, TAG, `RdbStore opened: ${this.config.name}, isCloudSync=${this.config.isCloudSync}`);

    // 执行版本管理（建表 + Migration）
    const currentVersion = store.version;
    const targetVersion = this.config.version;

    hilog.info(DOMAIN, TAG, `DB version: current=${currentVersion}, target=${targetVersion}`);

    if (currentVersion === 0) {
      // 全新安装：执行初始建表
      await this.createTables(store);
      store.version = targetVersion;
      hilog.info(DOMAIN, TAG, `Initial tables created, version set to ${targetVersion}.`);
    } else if (currentVersion < targetVersion) {
      // 版本升级：先建表（确保新表存在），再执行 Migration
      await this.createTables(store);
      await this.runMigrations(store, currentVersion, targetVersion);
      store.version = targetVersion;
      hilog.info(DOMAIN, TAG, `Migration completed: v${currentVersion} -> v${targetVersion}.`);
    }

    return store;
  }

  /**
   * 基于 TableSchema 批量执行 CREATE TABLE IF NOT EXISTS
   */
  private async createTables(store: relationalStore.RdbStore): Promise<void> {
    for (const schema of this.schemas) {
      const sql = this.buildCreateTableSql(schema);
      hilog.info(DOMAIN, TAG, `Creating table: ${schema.tableName}`);
      await store.executeSql(sql);

      // 为标记 indexed=true 的列创建索引
      for (const col of schema.columns) {
        if (col.indexed && !col.primaryKey) {
          const indexSql = `CREATE INDEX IF NOT EXISTS idx_${schema.tableName}_${col.name} ON ${schema.tableName}(${col.name});`;
          await store.executeSql(indexSql);
        }
      }
    }
  }

  /**
   * 按 from→to 顺序依次执行版本迁移步骤
   */
  private async runMigrations(
    store: relationalStore.RdbStore,
    fromVersion: number,
    toVersion: number
  ): Promise<void> {
    const migrations: Migration[] = this.config?.migrations ?? [];

    // 筛选出当前需要执行的迁移步骤（在 fromVersion 与 toVersion 范围内）
    const pending = migrations
      .filter(m => m.from >= fromVersion && m.to <= toVersion)
      .sort((a, b) => a.from - b.from);

    for (const migration of pending) {
      hilog.info(DOMAIN, TAG, `Running migration: v${migration.from} -> v${migration.to}`);
      await store.beginTransaction();
      try {
        await migration.migrate(store);
        await store.commit();
        hilog.info(DOMAIN, TAG, `Migration v${migration.from} -> v${migration.to} completed.`);
      } catch (err) {
        await store.rollBack();
        hilog.error(DOMAIN, TAG, `Migration v${migration.from} -> v${migration.to} failed: ${(err as Error).message}`);
        throw err;
      }
    }
  }

  /**
   * 根据 TableSchema 描述符生成 CREATE TABLE IF NOT EXISTS SQL
   */
  private buildCreateTableSql(schema: TableSchema): string {
    const colDefs = schema.columns.map((col: ColumnDefinition) => {
      let def = `${col.name} ${col.type}`;
      if (col.primaryKey) {
        def += ' PRIMARY KEY';
        if (col.type === 'INTEGER') {
          def += ' AUTOINCREMENT';
        }
      }
      if (!col.nullable && !col.primaryKey) {
        def += ' NOT NULL';
      }
      if (col.defaultValue !== undefined) {
        def += ` DEFAULT ${col.defaultValue}`;
      }
      return def;
    });
    return `CREATE TABLE IF NOT EXISTS ${schema.tableName} (${colDefs.join(', ')});`;
  }
}

/**
 * 全局 RdbManager 单例快捷引用
 */
export const rdbManager: RdbManager = RdbManager.getInstance();
