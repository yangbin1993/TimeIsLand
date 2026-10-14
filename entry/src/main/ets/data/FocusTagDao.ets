import { relationalStore } from '@kit.ArkData';
import { BaseDao, TableSchema, ColumnType } from '@app/common';
import { FocusTag } from '../model/FocusTypes';
import { GUEST_USER_ID } from '../model/UserModel';

/**
 * 标签表 Schema 定义
 */
const FOCUS_TAG_TABLE_SCHEMA: TableSchema = {
  tableName: 'focus_tags',
  columns: [
    { name: 'id', type: ColumnType.INTEGER, primaryKey: true },
    { name: 'user_id', type: ColumnType.TEXT, nullable: false, defaultValue: "'guest_local'", indexed: true },
    { name: 'name', type: ColumnType.TEXT, nullable: false, defaultValue: "''" },
    { name: 'color_hex', type: ColumnType.TEXT, nullable: false, defaultValue: "'#4A90E2'" },
    { name: 'icon_name', type: ColumnType.TEXT, nullable: false, defaultValue: "'app.media.ic_tag'" },
    { name: 'is_system', type: ColumnType.INTEGER, nullable: false, defaultValue: '0' }
  ]
};

/**
 * 专注标签数据访问层 DAO
 */
export class FocusTagDao extends BaseDao<FocusTag> {
  protected getTableSchema(): TableSchema {
    return FOCUS_TAG_TABLE_SCHEMA;
  }

  protected toEntity(rs: relationalStore.ResultSet): FocusTag {
    try {
      const idColIndex = rs.getColumnIndex('id');
      const userColIndex = rs.getColumnIndex('user_id');
      const nameColIndex = rs.getColumnIndex('name');
      const colorColIndex = rs.getColumnIndex('color_hex');
      const iconColIndex = rs.getColumnIndex('icon_name');
      const isSystemColIndex = rs.getColumnIndex('is_system');

      const isSystemVal = isSystemColIndex !== -1 ? rs.getLong(isSystemColIndex) : 0;
      const item: FocusTag = {
        id: idColIndex !== -1 ? rs.getLong(idColIndex) : 0,
        userId: userColIndex !== -1 && !rs.isColumnNull(userColIndex) ? rs.getString(userColIndex) : GUEST_USER_ID,
        name: nameColIndex !== -1 ? rs.getString(nameColIndex) : '',
        colorHex: colorColIndex !== -1 ? rs.getString(colorColIndex) : '#4A90E2',
        iconName: iconColIndex !== -1 ? rs.getString(iconColIndex) : 'app.media.ic_tag',
        isSystem: isSystemVal === 1
      };
      return item;
    } catch (err) {
      const fallbackTag: FocusTag = {
        id: 0,
        userId: GUEST_USER_ID,
        name: '',
        colorHex: '#4A90E2',
        iconName: 'app.media.ic_tag',
        isSystem: false
      };
      return fallbackTag;
    }
  }

  protected toValues(entity: FocusTag): relationalStore.ValuesBucket {
    const values: relationalStore.ValuesBucket = {
      user_id: entity.userId || GUEST_USER_ID,
      name: entity.name,
      color_hex: entity.colorHex,
      icon_name: entity.iconName,
      is_system: entity.isSystem ? 1 : 0
    };
    return values;
  }

  /**
   * 初始化预置系统标签（直接翻译为中文，并自动迁移历史英文数据）
   */
  public async ensureDefaultTags(): Promise<FocusTag[]> {
    const translationMap: Record<string, string> = {
      'Work': '工作',
      'Study': '学习',
      'Reading': '阅读',
      'Thinking': '思考',
      'Sport': '运动',
      'Coding': '编程',
      'Meditation': '冥想',
      'Creative': '创作'
    };

    const defaultTags: FocusTag[] = [
      { id: 1, userId: 'system_global', name: '工作', colorHex: '#4A90E2', iconName: 'briefcase', isSystem: true },
      { id: 2, userId: 'system_global', name: '学习', colorHex: '#50E3C2', iconName: 'book', isSystem: true },
      { id: 3, userId: 'system_global', name: '阅读', colorHex: '#F5A623', iconName: 'reader', isSystem: true },
      { id: 4, userId: 'system_global', name: '思考', colorHex: '#9013FE', iconName: 'brain', isSystem: true },
      { id: 5, userId: 'system_global', name: '运动', colorHex: '#7ED321', iconName: 'sport', isSystem: true },
      { id: 6, userId: 'system_global', name: '冥想', colorHex: '#FBBF24', iconName: 'spa', isSystem: true },
      { id: 7, userId: 'system_global', name: '创作', colorHex: '#ACC7FF', iconName: 'brush', isSystem: true }
    ];

    const existing = await this.findAll();
    if (existing.length === 0) {
      await this.insertBatch(defaultTags);
      return await this.findAll();
    }

    // 自动检查并迁移历史老数据中的英文字符至中文，并差量补齐缺失的系统标签
    try {
      const store = await this.getStore();
      for (const item of existing) {
        const targetCn = translationMap[item.name];
        if (targetCn) {
          const pred = new relationalStore.RdbPredicates('focus_tags');
          pred.equalTo('id', item.id);
          const val: relationalStore.ValuesBucket = { 'name': targetCn };
          await store.update(val, pred);
          item.name = targetCn;
        }
      }

      // 差量补齐缺失的系统标签 (冥想、创作等)
      const existingNames = new Set(existing.map(t => t.name));
      const missingTags: FocusTag[] = [];
      for (const dt of defaultTags) {
        if (!existingNames.has(dt.name)) {
          // 清空固定id，交由自增主键自动生成，避免与用户已有自定义标签id冲突
          missingTags.push({
            id: 0,
            userId: dt.userId,
            name: dt.name,
            colorHex: dt.colorHex,
            iconName: dt.iconName,
            isSystem: true
          });
        }
      }

      if (missingTags.length > 0) {
        await this.insertBatch(missingTags);
      }
    } catch (e) {
      // 忽略非关键迁移异常
    }

    return await this.findAll();
  }

  /**
   * 将旧访客自定义标签合并归属至目标账号
   */
  public async consolidateGuestTags(targetUserId: string): Promise<number> {
    try {
      const store = await this.getStore();
      const predicates = new relationalStore.RdbPredicates('focus_tags');
      predicates.equalTo('user_id', GUEST_USER_ID);
      const updateValues: relationalStore.ValuesBucket = {
        user_id: targetUserId
      };
      return await store.update(updateValues, predicates);
    } catch (err) {
      return 0;
    }
  }
}

export const focusTagDao: FocusTagDao = new FocusTagDao();
