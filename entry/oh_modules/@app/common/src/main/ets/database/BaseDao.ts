import { relationalStore } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { RdbManager } from './RdbManager';
import { RdbPageRequest, RdbPageResponse, TableSchema } from './RdbTypes';

const DOMAIN = 0x0000;

/**
 * 通用 DAO 泛型基类 (BaseDao<T>)
 *
 * 封装了针对单一数据表的标准 CRUD 操作、分页查询与事务支持。
 * 子类只需实现三个抽象方法即可获得完整的数据访问能力：
 *   - getTableSchema()：提供表结构 Schema 描述
 *   - toEntity()：将数据库行记录映射为业务实体对象
 *   - toValues()：将业务实体对象转换为数据库 ValuesBucket
 *
 * 设计原则：
 * 1. 泛型约束：`T` 必须是具有 `id?: number` 字段的对象，主键列固定为 'id'；
 * 2. 防御性容错：查询结果集严格进行空指针防御，任何异常均通过 hilog 记录并上浮；
 * 3. 事务委托：批量操作（insertBatch、deleteBatch）内部自动开启事务保障原子性；
 * 4. 排序策略：通过 RdbPredicates.orderByAsc / orderByDesc 控制，不依赖字符串传参。
 */
export abstract class BaseDao<T extends { id?: number }> {
  protected readonly TAG: string;

  constructor() {
    this.TAG = `BaseDao[${this.getTableSchema().tableName}]`;
  }

  // ==================== 子类抽象实现契约 ====================

  /**
   * 返回当前 DAO 对应的表结构 Schema 描述符
   */
  protected abstract getTableSchema(): TableSchema;

  /**
   * 将数据库查询结果行（ResultSet 当前行）映射为业务实体对象
   *
   * @param rs 当前已定位到目标行的 ResultSet 实例
   */
  protected abstract toEntity(rs: relationalStore.ResultSet): T;

  /**
   * 将业务实体对象转换为数据库写入所需的 ValuesBucket
   * 注意：id 字段为自增主键，insert 时通常应省略
   */
  protected abstract toValues(entity: T): relationalStore.ValuesBucket;

  // ==================== 基础工具 ====================

  /**
   * 获取表名（从 Schema 描述符读取）
   */
  protected get tableName(): string {
    return this.getTableSchema().tableName;
  }

  /**
   * 公开暴露 Schema，供 AppAbility 初始化时注册自动建表
   */
  public getSchema(): TableSchema {
    return this.getTableSchema();
  }

  /**
   * 获取 RdbStore 实例（委托给 RdbManager 懒加载获取）
   */
  protected async getStore(): Promise<relationalStore.RdbStore> {
    return RdbManager.getInstance().getStore();
  }

  /**
   * 将 ResultSet 的所有行映射为实体列表（自动关闭 ResultSet）
   */
  protected collectEntities(rs: relationalStore.ResultSet): T[] {
    const result: T[] = [];
    try {
      while (rs.goToNextRow()) {
        result.push(this.toEntity(rs));
      }
    } finally {
      rs.close();
    }
    return result;
  }

  // ==================== 写入操作 ====================

  /**
   * 插入单条实体记录
   *
   * @param entity 待插入的实体（id 字段会被忽略，由数据库自增分配）
   * @returns 插入成功后数据库分配的自增 ID（rowId），失败返回 -1
   */
  public async insert(entity: T): Promise<number> {
    const store = await this.getStore();
    const values = this.toValues(entity);
    try {
      const rowId = await store.insert(this.tableName, values);
      hilog.info(DOMAIN, this.TAG, `insert() -> rowId: ${rowId}`);
      return rowId;
    } catch (err) {
      hilog.error(DOMAIN, this.TAG, `insert() failed: ${(err as Error).message}`);
      throw err;
    }
  }

  /**
   * 批量插入实体列表（事务保障，任意失败全量回滚）
   *
   * @param entities 待批量插入的实体列表
   */
  public async insertBatch(entities: T[]): Promise<void> {
    if (entities.length === 0) {
      return;
    }
    const store = await this.getStore();
    await store.beginTransaction();
    try {
      for (const entity of entities) {
        await store.insert(this.tableName, this.toValues(entity));
      }
      await store.commit();
      hilog.info(DOMAIN, this.TAG, `insertBatch() -> ${entities.length} records inserted.`);
    } catch (err) {
      await store.rollBack();
      hilog.error(DOMAIN, this.TAG, `insertBatch() rolled back: ${(err as Error).message}`);
      throw err;
    }
  }

  /**
   * 更新指定 ID 的实体记录（匹配 id 字段）
   *
   * @param entity 包含 id 字段的完整实体（id 用于定位，其余字段全量更新）
   * @returns 实际更新的行数
   */
  public async update(entity: T): Promise<number> {
    if (entity.id === undefined) {
      throw new Error(`${this.TAG}: update() requires entity.id to be set.`);
    }
    const store = await this.getStore();
    const predicates = new relationalStore.RdbPredicates(this.tableName);
    predicates.equalTo('id', entity.id);
    const rowsAffected = await store.update(this.toValues(entity), predicates);
    hilog.info(DOMAIN, this.TAG, `update(id=${entity.id}) -> ${rowsAffected} row(s) affected.`);
    return rowsAffected;
  }

  /**
   * 删除指定 ID 的实体记录
   *
   * @param id 目标记录的自增主键
   * @returns 实际删除的行数
   */
  public async delete(id: number): Promise<number> {
    const store = await this.getStore();
    const predicates = new relationalStore.RdbPredicates(this.tableName);
    predicates.equalTo('id', id);
    const rowsAffected = await store.delete(predicates);
    hilog.info(DOMAIN, this.TAG, `delete(id=${id}) -> ${rowsAffected} row(s) affected.`);
    return rowsAffected;
  }

  /**
   * 批量删除指定 ID 列表的记录
   *
   * @param ids 待删除的主键 ID 列表
   */
  public async deleteBatch(ids: number[]): Promise<void> {
    if (ids.length === 0) {
      return;
    }
    const store = await this.getStore();
    const predicates = new relationalStore.RdbPredicates(this.tableName);
    predicates.in('id', ids.map(id => id as relationalStore.ValueType));
    await store.delete(predicates);
    hilog.info(DOMAIN, this.TAG, `deleteBatch() -> ${ids.length} records deleted.`);
  }

  /**
   * 清空整张表的所有记录（谨慎使用）
   */
  public async deleteAll(): Promise<void> {
    const store = await this.getStore();
    const predicates = new relationalStore.RdbPredicates(this.tableName);
    await store.delete(predicates);
    hilog.info(DOMAIN, this.TAG, 'deleteAll() executed.');
  }

  // ==================== 查询操作 ====================

  /**
   * 根据主键 ID 查询单条记录
   *
   * @param id 目标记录的自增主键
   * @returns 实体对象，不存在则返回 null
   */
  public async findById(id: number): Promise<T | null> {
    const store = await this.getStore();
    const predicates = new relationalStore.RdbPredicates(this.tableName);
    predicates.equalTo('id', id);
    const rs = await store.query(predicates);
    const entities = this.collectEntities(rs);
    return entities.length > 0 ? entities[0] : null;
  }

  /**
   * 查询全表所有记录
   *
   * @param orderColumn 排序列名，默认为 'id'
   * @param ascending 是否升序排列，默认 true
   * @returns 实体列表
   */
  public async findAll(orderColumn: string = 'id', ascending: boolean = true): Promise<T[]> {
    const store = await this.getStore();
    const predicates = new relationalStore.RdbPredicates(this.tableName);
    if (ascending) {
      predicates.orderByAsc(orderColumn);
    } else {
      predicates.orderByDesc(orderColumn);
    }
    const rs = await store.query(predicates);
    return this.collectEntities(rs);
  }

  /**
   * 基于自定义谓词条件查询记录列表
   * 排序/Limit/Offset 等条件请在传入前通过 predicates 链式设置
   *
   * @param predicates 查询谓词（由子类或业务层构建，含排序/过滤条件）
   * @returns 符合条件的实体列表
   */
  public async query(predicates: relationalStore.RdbPredicates): Promise<T[]> {
    const store = await this.getStore();
    const rs = await store.query(predicates);
    return this.collectEntities(rs);
  }

  /**
   * 分页查询（基于 RdbPredicates limitAs / offsetAs 实现）
   *
   * @param request 分页请求（pageNum 从 1 开始，pageSize 每页条数）
   * @param predicates 过滤条件谓词（可选），排序请在此处通过 orderByAsc/Desc 设置
   * @returns 分页响应封包（含当前页列表、总数、总页数等元数据）
   */
  public async queryPage(
    request: RdbPageRequest,
    predicates?: relationalStore.RdbPredicates
  ): Promise<RdbPageResponse<T>> {
    const store = await this.getStore();

    // 查询当前表总记录数
    const countRs = await store.querySql(`SELECT COUNT(*) AS cnt FROM ${this.tableName}`);
    let total = 0;
    if (countRs.goToNextRow()) {
      total = countRs.getLong(countRs.getColumnIndex('cnt'));
    }
    countRs.close();

    // 分页数据查询（在谓词上设置 LIMIT / OFFSET）
    const pred = predicates ?? new relationalStore.RdbPredicates(this.tableName);
    const offset = (request.pageNum - 1) * request.pageSize;
    pred.limitAs(request.pageSize).offsetAs(offset);

    const rs = await store.query(pred);
    const list = this.collectEntities(rs);

    const totalPages = total > 0 ? Math.ceil(total / request.pageSize) : 0;

    return {
      list,
      total,
      pageNum: request.pageNum,
      pageSize: request.pageSize,
      totalPages,
      hasNext: request.pageNum < totalPages
    };
  }

  /**
   * 统计当前表的记录总数
   */
  public async count(): Promise<number> {
    const store = await this.getStore();
    const rs = await store.querySql(`SELECT COUNT(*) AS cnt FROM ${this.tableName}`);
    let total = 0;
    if (rs.goToNextRow()) {
      total = rs.getLong(rs.getColumnIndex('cnt'));
    }
    rs.close();
    return total;
  }

  // ==================== 事务委托 ====================

  /**
   * 在事务中执行一组操作（委托给 RdbManager.inTransaction，异常自动回滚）
   *
   * @param action 事务函数
   */
  public async inTransaction(action: (store: relationalStore.RdbStore) => Promise<void>): Promise<void> {
    return RdbManager.getInstance().inTransaction(action);
  }
}
