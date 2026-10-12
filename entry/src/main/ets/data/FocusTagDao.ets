import { relationalStore } from '@kit.ArkData';
import { BaseDao, TableSchema, ColumnType } from '@app/common';
import { FocusTag } from '../model/FocusTypes';

/**
 * 标签表 Schema 定义
 */
const FOCUS_TAG_TABLE_SCHEMA: TableSchema = {
  tableName: 'focus_tags',
  columns: [
    { name: 'id', type: ColumnType.INTEGER, primaryKey: true },
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
    const isSystemVal = rs.getLong(rs.getColumnIndex('is_system'));
    const item: FocusTag = {
      id: rs.getLong(rs.getColumnIndex('id')),
      name: rs.getString(rs.getColumnIndex('name')),
      colorHex: rs.getString(rs.getColumnIndex('color_hex')),
      iconName: rs.getString(rs.getColumnIndex('icon_name')),
      isSystem: isSystemVal === 1
    };
    return item;
  }

  protected toValues(entity: FocusTag): relationalStore.ValuesBucket {
    const values: relationalStore.ValuesBucket = {
      name: entity.name,
      color_hex: entity.colorHex,
      icon_name: entity.iconName,
      is_system: entity.isSystem ? 1 : 0
    };
    return values;
  }

  /**
   * 初始化预置系统标签（若无记录则自动注入基础标签）
   */
  public async ensureDefaultTags(): Promise<FocusTag[]> {
    const existing = await this.findAll();
    if (existing.length > 0) {
      return existing;
    }

    const defaultTags: FocusTag[] = [
      { id: 1, name: '工作', colorHex: '#4A90E2', iconName: 'briefcase', isSystem: true },
      { id: 2, name: '学习', colorHex: '#50E3C2', iconName: 'book', isSystem: true },
      { id: 3, name: '阅读', colorHex: '#F5A623', iconName: 'reader', isSystem: true },
      { id: 4, name: '思考', colorHex: '#9013FE', iconName: 'brain', isSystem: true },
      { id: 5, name: '运动', colorHex: '#7ED321', iconName: 'sport', isSystem: true }
    ];

    await this.insertBatch(defaultTags);
    return await this.findAll();
  }
}

export const focusTagDao: FocusTagDao = new FocusTagDao();
