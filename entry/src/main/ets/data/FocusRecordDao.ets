import { relationalStore } from '@kit.ArkData';
import { BaseDao, TableSchema, ColumnType } from '@app/common';
import { FocusRecordEntity, FocusState } from '../model/FocusTypes';
import { GUEST_USER_ID } from '../model/UserModel';

/**
 * 专注历史记录表 Schema
 */
const FOCUS_RECORD_TABLE_SCHEMA: TableSchema = {
  tableName: 'focus_records',
  columns: [
    { name: 'id', type: ColumnType.INTEGER, primaryKey: true },
    { name: 'user_id', type: ColumnType.TEXT, nullable: false, defaultValue: "'guest_local'", indexed: true },
    { name: 'tag_id', type: ColumnType.INTEGER, nullable: false, defaultValue: '1', indexed: true },
    { name: 'target_minutes', type: ColumnType.INTEGER, nullable: false, defaultValue: '25' },
    { name: 'actual_seconds', type: ColumnType.INTEGER, nullable: false, defaultValue: '0' },
    { name: 'start_time', type: ColumnType.INTEGER, nullable: false, defaultValue: '0', indexed: true },
    { name: 'end_time', type: ColumnType.INTEGER, nullable: false, defaultValue: '0' },
    { name: 'state', type: ColumnType.TEXT, nullable: false, defaultValue: "'COMPLETED'" },
    { name: 'note', type: ColumnType.TEXT, nullable: true },
    { name: 'rating', type: ColumnType.INTEGER, nullable: true, defaultValue: '5' }
  ]
};

/**
 * 专注历史记录数据访问层 DAO
 */
export class FocusRecordDao extends BaseDao<FocusRecordEntity> {
  protected getTableSchema(): TableSchema {
    return FOCUS_RECORD_TABLE_SCHEMA;
  }

  protected toEntity(rs: relationalStore.ResultSet): FocusRecordEntity {
    try {
      const idColIndex = rs.getColumnIndex('id');
      const userColIndex = rs.getColumnIndex('user_id');
      const tagIdColIndex = rs.getColumnIndex('tag_id');
      const targetMinColIndex = rs.getColumnIndex('target_minutes');
      const actualSecColIndex = rs.getColumnIndex('actual_seconds');
      const startTimeColIndex = rs.getColumnIndex('start_time');
      const endTimeColIndex = rs.getColumnIndex('end_time');
      const stateColIndex = rs.getColumnIndex('state');
      const noteColIndex = rs.getColumnIndex('note');
      const ratingColIndex = rs.getColumnIndex('rating');

      const item: FocusRecordEntity = {
        id: idColIndex !== -1 ? rs.getLong(idColIndex) : 0,
        userId: userColIndex !== -1 && !rs.isColumnNull(userColIndex) ? rs.getString(userColIndex) : GUEST_USER_ID,
        tagId: tagIdColIndex !== -1 ? rs.getLong(tagIdColIndex) : 1,
        targetMinutes: targetMinColIndex !== -1 ? rs.getLong(targetMinColIndex) : 25,
        actualSeconds: actualSecColIndex !== -1 ? rs.getLong(actualSecColIndex) : 0,
        startTime: startTimeColIndex !== -1 ? rs.getLong(startTimeColIndex) : 0,
        endTime: endTimeColIndex !== -1 ? rs.getLong(endTimeColIndex) : 0,
        state: stateColIndex !== -1 ? (rs.getString(stateColIndex) as FocusState) : FocusState.COMPLETED,
        note: noteColIndex !== -1 && !rs.isColumnNull(noteColIndex) ? rs.getString(noteColIndex) : undefined,
        rating: ratingColIndex !== -1 && !rs.isColumnNull(ratingColIndex) ? rs.getLong(ratingColIndex) : undefined
      };
      return item;
    } catch (err) {
      const fallbackItem: FocusRecordEntity = {
        id: 0,
        userId: GUEST_USER_ID,
        tagId: 1,
        targetMinutes: 25,
        actualSeconds: 0,
        startTime: 0,
        endTime: 0,
        state: FocusState.COMPLETED
      };
      return fallbackItem;
    }
  }

  protected toValues(entity: FocusRecordEntity): relationalStore.ValuesBucket {
    const values: relationalStore.ValuesBucket = {
      user_id: entity.userId || GUEST_USER_ID,
      tag_id: entity.tagId,
      target_minutes: entity.targetMinutes,
      actual_seconds: entity.actualSeconds,
      start_time: entity.startTime,
      end_time: entity.endTime,
      state: entity.state,
      note: entity.note ?? '',
      rating: entity.rating ?? 5
    };
    return values;
  }

  /**
   * 按时间戳起止区间及用户查询历史记录 (按开始时间倒序)
   */
  public async queryByDateRange(startTime: number, endTime: number, userId?: string): Promise<FocusRecordEntity[]> {
    try {
      const predicates = new relationalStore.RdbPredicates('focus_records');
      if (userId) {
        predicates.equalTo('user_id', userId);
      }
      predicates.greaterThanOrEqualTo('start_time', startTime);
      predicates.lessThanOrEqualTo('start_time', endTime);
      predicates.orderByDesc('start_time');
      return await this.query(predicates);
    } catch (err) {
      return [];
    }
  }

  /**
   * 查询指定用户的最近 N 条专注记录
   */
  public async queryRecent(limitCount: number = 20, userId?: string): Promise<FocusRecordEntity[]> {
    try {
      const predicates = new relationalStore.RdbPredicates('focus_records');
      if (userId) {
        predicates.equalTo('user_id', userId);
      }
      predicates.orderByDesc('start_time');
      predicates.limitAs(limitCount);
      return await this.query(predicates);
    } catch (err) {
      return [];
    }
  }

  /**
   * 查询指定用户今日所有记录 (从今日 00:00:00 至 23:59:59)
   */
  public async queryTodayRecords(userId?: string): Promise<FocusRecordEntity[]> {
    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0).getTime();
    const endOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999).getTime();
    return this.queryByDateRange(startOfDay, endOfDay, userId);
  }

  /**
   * 将旧访客记录批量合并归属至目标账号
   */
  public async consolidateGuestRecords(targetUserId: string): Promise<number> {
    try {
      const store = await this.getStore();
      const predicates = new relationalStore.RdbPredicates('focus_records');
      predicates.equalTo('user_id', GUEST_USER_ID);
      const updateValues: relationalStore.ValuesBucket = {
        user_id: targetUserId
      };
      return await store.update(updateValues, predicates);
    } catch (err) {
      return 0;
    }
  }

  /**
   * 统计待合并的本地访客记录数
   */
  public async countGuestRecords(): Promise<number> {
    try {
      const predicates = new relationalStore.RdbPredicates('focus_records');
      predicates.equalTo('user_id', GUEST_USER_ID);
      const list = await this.query(predicates);
      return list.length;
    } catch (err) {
      return 0;
    }
  }

  /**
   * 统计当前用户或本地全表的总记录数
   */
  public async countAllRecords(userId?: string): Promise<number> {
    try {
      const predicates = new relationalStore.RdbPredicates('focus_records');
      if (userId) {
        predicates.equalTo('user_id', userId);
      }
      const list = await this.query(predicates);
      return list.length;
    } catch (err) {
      return 0;
    }
  }

  /**
   * 查询所有专注记录 (用于备份与导出)
   */
  public async queryAll(userId?: string): Promise<FocusRecordEntity[]> {
    try {
      const predicates = new relationalStore.RdbPredicates('focus_records');
      if (userId) {
        predicates.equalTo('user_id', userId);
      }
      predicates.orderByDesc('start_time');
      return await this.query(predicates);
    } catch (err) {
      return [];
    }
  }

  /**
   * 清空指定用户的所有专注记录 (若未传参则清空本地全表)
   */
  public async clearAllRecords(userId?: string): Promise<number> {
    try {
      const store = await this.getStore();
      const predicates = new relationalStore.RdbPredicates('focus_records');
      if (userId) {
        predicates.equalTo('user_id', userId);
      }
      return await store.delete(predicates);
    } catch (err) {
      return 0;
    }
  }

  /**
   * 更新指定记录的心流随笔心得与气韵评级
   */
  public async updateNoteAndRating(recordId: number, note: string, rating: number): Promise<boolean> {
    try {
      const store = await this.getStore();
      const predicates = new relationalStore.RdbPredicates('focus_records');
      predicates.equalTo('id', recordId);
      const values: relationalStore.ValuesBucket = {
        note: note,
        rating: rating
      };
      const updatedRows = await store.update(values, predicates);
      return updatedRows > 0;
    } catch (err) {
      return false;
    }
  }
}

export const focusRecordDao: FocusRecordDao = new FocusRecordDao();
