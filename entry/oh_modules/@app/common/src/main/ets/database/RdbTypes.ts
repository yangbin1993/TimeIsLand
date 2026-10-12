import { relationalStore } from '@kit.ArkData';

/**
 * 数据库初始化配置契约
 */
export interface RdbConfig {
  /**
   * 数据库文件名（如 'app.db'）
   */
  name: string;

  /**
   * 当前数据库版本号（每次结构变更需递增）
   */
  version: number;

  /**
   * 数据库版本升级迁移策略列表（按 from -> to 升序排列）
   */
  migrations?: Migration[];

  /**
   * 数据库安全级别，默认 S1
   */
  securityLevel?: relationalStore.SecurityLevel;
}

/**
 * 数据库版本迁移契约
 * 框架在检测到版本号升级时，按照 from -> to 顺序依次执行对应迁移
 */
export interface Migration {
  /**
   * 迁移起始版本号
   */
  from: number;

  /**
   * 迁移目标版本号
   */
  to: number;

  /**
   * 迁移执行函数（在事务中调用，异常自动回滚）
   *
   * @param rdb 当前 RdbStore 实例
   */
  migrate: (rdb: relationalStore.RdbStore) => Promise<void>;
}

/**
 * 通用分页请求参数（RDB 层，避免与 BaseListViewModel 的 PageRequest 冲突）
 */
export interface RdbPageRequest {
  /**
   * 页码（从 1 开始）
   */
  pageNum: number;

  /**
   * 每页条数
   */
  pageSize: number;
}

/**
 * 通用分页响应封包（RDB 层，避免与 BaseListViewModel 的 PageResponse 冲突）
 */
export interface RdbPageResponse<T> {
  /**
   * 当前页数据列表
   */
  list: T[];

  /**
   * 总记录数
   */
  total: number;

  /**
   * 当前页码
   */
  pageNum: number;

  /**
   * 每页条数
   */
  pageSize: number;

  /**
   * 总页数
   */
  totalPages: number;

  /**
   * 是否有下一页
   */
  hasNext: boolean;
}

/**
 * 列字段类型枚举（驱动 TableSchema 自动生成 CREATE TABLE SQL）
 */
export const enum ColumnType {
  INTEGER = 'INTEGER',
  REAL = 'REAL',
  TEXT = 'TEXT',
  BLOB = 'BLOB'
}

/**
 * 表列定义描述符
 */
export interface ColumnDefinition {
  /**
   * 列名
   */
  name: string;

  /**
   * 数据类型
   */
  type: ColumnType;

  /**
   * 是否为主键（仅支持单一主键，INTEGER 类型自动为 AUTOINCREMENT）
   */
  primaryKey?: boolean;

  /**
   * 是否可为 NULL（默认 false，即 NOT NULL）
   */
  nullable?: boolean;

  /**
   * 默认值（SQL 字面量字符串，如 "''"、"0"、"CURRENT_TIMESTAMP"）
   */
  defaultValue?: string;

  /**
   * 是否建立索引
   */
  indexed?: boolean;
}

/**
 * 表结构 Schema 描述符
 */
export interface TableSchema {
  /**
   * 表名
   */
  tableName: string;

  /**
   * 列定义列表（第一个 primaryKey=true 的列为主键）
   */
  columns: ColumnDefinition[];
}
