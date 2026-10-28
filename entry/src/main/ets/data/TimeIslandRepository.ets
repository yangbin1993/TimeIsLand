import { hilog } from '@kit.PerformanceAnalysisKit';
import { BaseRepository, TaskDispatcher, RdbManager } from '@app/common';
import { FocusTag, FocusRecordEntity, FocusOverviewStat, DayFocusSummary, TagFocusSummary, FocusState, TAG_COLOR_CUSTOM } from '../model/FocusTypes';
import { GUEST_USER_ID } from '../model/UserModel';
import { focusTagDao, FocusTagDao } from './FocusTagDao';
import { focusRecordDao, FocusRecordDao } from './FocusRecordDao';

const TAG = 'TimeIslandRepository';
const DOMAIN = 0x0000;

export interface ExportRecordItem {
  id: number;
  tag: string;
  targetMinutes: number;
  actualSeconds: number;
  actualMinutes: number;
  startTime: string;
  endTime: string;
  state: string;
  note: string;
  rating?: number;
  startTimestamp?: number;
  endTimestamp?: number;
}

export interface RestoreResult {
  success: boolean;
  totalInPayload: number;
  importedCount: number;
  skippedCount: number;
  errorMessage?: string;
}

export interface ExportDataPayload {
  appName: string;
  version: string;
  exportTimestamp: number;
  exportTime: string;
  userId: string;
  totalCount: number;
  records: ExportRecordItem[];
}

interface ComputeStatPayload {
  records: FocusRecordEntity[];
  tags: FocusTag[];
}

/**
 * 顶层并发计算概览统计指标函数
 * 在 TaskPool 工作线程中高效归约海量历史记录，规避 UI 主线程运算卡顿
 */
@Concurrent
function concurrentComputeFocusStats(payload: ComputeStatPayload): FocusOverviewStat {
  const records = payload.records;
  const tags = payload.tags;

  let totalMinutes = 0;
  let todayMinutes = 0;
  let todayCount = 0;

  const now = new Date();
  const todayStart = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, 0, 0).getTime();
  const todayEnd = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 23, 59, 59, 999).getTime();

  // 标签时长累加映射
  const tagMinutesMap: Record<number, number> = {};
  // 日期归约映射 (YYYY-MM-DD -> minutes)
  const dailyMinutesMap: Record<string, number> = {};
  const dailyCountMap: Record<string, number> = {};

  for (let i = 0; i < records.length; i++) {
    const rec = records[i];
    if (rec.state !== FocusState.COMPLETED) {
      continue;
    }

    const minutes = Math.floor(rec.actualSeconds / 60);
    totalMinutes += minutes;

    // 今日过滤
    if (rec.startTime >= todayStart && rec.startTime <= todayEnd) {
      todayMinutes += minutes;
      todayCount++;
    }

    // 标签统计
    const currentTagMinutes = tagMinutesMap[rec.tagId] || 0;
    tagMinutesMap[rec.tagId] = currentTagMinutes + minutes;

    // 日期统计
    const recDate = new Date(rec.startTime);
    const yearStr = recDate.getFullYear();
    const monthStr = (recDate.getMonth() + 1).toString().padStart(2, '0');
    const dayStr = recDate.getDate().toString().padStart(2, '0');
    const dateKey = `${yearStr}-${monthStr}-${dayStr}`;

    dailyMinutesMap[dateKey] = (dailyMinutesMap[dateKey] || 0) + minutes;
    dailyCountMap[dateKey] = (dailyCountMap[dateKey] || 0) + 1;
  }

  // 构造最近 7 天的每日趋势
  const recentDays: DayFocusSummary[] = [];
  for (let d = 6; d >= 0; d--) {
    const targetDate = new Date(now.getTime() - d * 24 * 60 * 60 * 1000);
    const y = targetDate.getFullYear();
    const m = (targetDate.getMonth() + 1).toString().padStart(2, '0');
    const day = targetDate.getDate().toString().padStart(2, '0');
    const dKey = `${y}-${m}-${day}`;

    recentDays.push({
      dateString: dKey,
      totalMinutes: dailyMinutesMap[dKey] || 0,
      completedSessions: dailyCountMap[dKey] || 0
    });
  }

  // 构造标签分布
  const tagDistributions: TagFocusSummary[] = [];
  for (let t = 0; t < tags.length; t++) {
    const tag = tags[t];
    const mins = tagMinutesMap[tag.id] || 0;
    const percentage = totalMinutes > 0 ? Math.round((mins / totalMinutes) * 100) : 0;

    tagDistributions.push({
      tagId: tag.id,
      tagName: tag.name,
      colorHex: tag.colorHex,
      totalMinutes: mins,
      percentage: percentage
    });
  }

  // 计算连续打卡坚持天数 (简单递减探测)
  let streak = 0;
  let checkTime = now.getTime();
  while (true) {
    const chk = new Date(checkTime);
    const key = `${chk.getFullYear()}-${(chk.getMonth() + 1).toString().padStart(2, '0')}-${chk.getDate().toString().padStart(2, '0')}`;
    if ((dailyMinutesMap[key] || 0) > 0) {
      streak++;
      checkTime -= 24 * 60 * 60 * 1000;
    } else {
      break;
    }
  }

  const stat: FocusOverviewStat = {
    todayMinutes: todayMinutes,
    todayCompletedCount: todayCount,
    allTimeMinutes: totalMinutes,
    streakDays: streak,
    recentDailyStats: recentDays,
    tagDistributions: tagDistributions
  };

  return stat;
}

/**
 * 时光岛业务数据仓储中心
 */
export class TimeIslandRepository extends BaseRepository {
  private tagDao: FocusTagDao;
  private recordDao: FocusRecordDao;

  constructor(tagDao: FocusTagDao = focusTagDao, recordDao: FocusRecordDao = focusRecordDao) {
    super();
    this.tagDao = tagDao;
    this.recordDao = recordDao;
  }

  /**
   * 初始化基础标签并返回标签列表
   */
  public async getTags(): Promise<FocusTag[]> {
    return this.tagDao.ensureDefaultTags();
  }

  /**
   * 创建新的自定义标签
   */
  public async addTag(name: string, colorHex: string, iconName: string): Promise<number> {
    const newTag: FocusTag = {
      id: 0,
      name,
      colorHex,
      iconName,
      isSystem: false
    };
    return this.tagDao.insert(newTag);
  }

  /**
   * 保存完成或中止的专注记录
   */
  public async saveFocusRecord(record: FocusRecordEntity): Promise<number> {
    const currentUserId = AppStorage.get<string>('currentUserId') || 'guest_local';
    if (!record.userId) {
      record.userId = currentUserId;
    }
    hilog.info(DOMAIN, TAG, `Saving focus record: user=${record.userId}, actualSeconds=${record.actualSeconds}, state=${record.state}`);
    return this.recordDao.insert(record);
  }

  /**
   * 根据主键 ID 查询单条专注记录
   */
  public async getRecordById(id: number): Promise<FocusRecordEntity | null> {
    return this.recordDao.findById(id);
  }

  /**
   * 查询最近专注流水记录
   */
  public async getRecentRecords(limit: number = 20, userId?: string): Promise<FocusRecordEntity[]> {
    const targetUser = userId || AppStorage.get<string>('currentUserId') || 'guest_local';
    return this.recordDao.queryRecent(limit, targetUser);
  }

  /**
   * 统计待合并的本地访客记录数
   */
  public async countGuestRecords(): Promise<number> {
    return this.recordDao.countGuestRecords();
  }

  /**
   * 将本地访客数据一键合并归属至当前登录的华为账号
   */
  public async migrateGuestDataToUser(targetUserId: string): Promise<number> {
    hilog.info(DOMAIN, TAG, `Migrating guest records to target user: ${targetUserId}`);
    const updatedCount = await this.recordDao.consolidateGuestRecords(targetUserId);
    await this.tagDao.consolidateGuestTags(targetUserId);
    return updatedCount;
  }

  /**
   * 调度后台 TaskDispatcher 并行计算全局统计概览
   */
  public async computeOverviewStats(): Promise<FocusOverviewStat> {
    const currentUserId = AppStorage.get<string>('currentUserId') || 'guest_local';
    const tags = await this.tagDao.findAll();
    const records = await this.recordDao.findAll('start_time', false);

    // 优先聚合当前用户与系统共享标签的记录
    const userRecords = records.filter(r => !r.userId || r.userId === currentUserId || r.userId === 'guest_local');

    const payload: ComputeStatPayload = {
      records: userRecords,
      tags: tags
    };

    // 使用 TaskDispatcher 在 TaskPool 工作线程中并发计算
    return TaskDispatcher.execute<FocusOverviewStat, ComputeStatPayload>(
      concurrentComputeFocusStats,
      payload,
      { name: 'ComputeFocusStatsTask' }
    );
  }

  /**
   * 统计当前用户或本地所有专注记录条数
   */
  public async getTotalRecordCount(userId?: string): Promise<number> {
    const uid: string = (userId && userId.length > 0) ? userId : (AppStorage.get<string>('currentUserId') || GUEST_USER_ID);
    return await this.recordDao.countAllRecords(uid);
  }

  /**
   * 导出所有专注记录结构化数据为 JSON 字符串
   */
  public async exportAllRecordsJson(userId?: string): Promise<string> {
    const uid: string = (userId && userId.length > 0) ? userId : (AppStorage.get<string>('currentUserId') || GUEST_USER_ID);
    const records: FocusRecordEntity[] = await this.recordDao.queryAll(uid);
    const tags: FocusTag[] = await this.getTags();
    const tagMap: Map<number, string> = new Map<number, string>();
    tags.forEach((t: FocusTag) => {
      tagMap.set(t.id, t.name);
    });

    const items: ExportRecordItem[] = records.map((r: FocusRecordEntity): ExportRecordItem => {
      const item: ExportRecordItem = {
        id: r.id || 0,
        tag: tagMap.get(r.tagId) || 'Flow',
        targetMinutes: r.targetMinutes,
        actualSeconds: r.actualSeconds,
        actualMinutes: Math.floor(r.actualSeconds / 60),
        startTime: new Date(r.startTime).toLocaleString(),
        endTime: new Date(r.endTime).toLocaleString(),
        startTimestamp: r.startTime,
        endTimestamp: r.endTime,
        state: r.state,
        note: r.note || '',
        rating: r.rating !== undefined ? r.rating : 5
      };
      return item;
    });

    const exportPayload: ExportDataPayload = {
      appName: 'TimeIsland',
      version: '1.0.0',
      exportTimestamp: Date.now(),
      exportTime: new Date().toLocaleString(),
      userId: uid,
      totalCount: records.length,
      records: items
    };

    return JSON.stringify(exportPayload, null, 2);
  }

  /**
   * 从 JSON 备份文本恢复专注历史记录 (支持防重合并与标签自动补全)
   */
  public async restoreRecordsFromJson(jsonStr: string, userId?: string): Promise<RestoreResult> {
    const uid: string = (userId && userId.length > 0) ? userId : (AppStorage.get<string>('currentUserId') || GUEST_USER_ID);
    if (!jsonStr || jsonStr.trim().length === 0) {
      return { success: false, totalInPayload: 0, importedCount: 0, skippedCount: 0, errorMessage: 'Empty payload' };
    }

    let payload: ExportDataPayload;
    try {
      payload = JSON.parse(jsonStr) as ExportDataPayload;
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Failed to parse restore payload JSON: ${(err as Error).message}`);
      return { success: false, totalInPayload: 0, importedCount: 0, skippedCount: 0, errorMessage: 'Invalid JSON format' };
    }

    if (!payload || !Array.isArray(payload.records) || payload.records.length === 0) {
      return { success: false, totalInPayload: 0, importedCount: 0, skippedCount: 0, errorMessage: 'No records found' };
    }

    // 1. 获取已有全部记录建立去重哈希集 (以 startTime 与 actualSeconds 联合去重)
    const existingRecords: FocusRecordEntity[] = await this.recordDao.queryAll(uid);
    const existingKeySet: Set<string> = new Set<string>();
    existingRecords.forEach((r: FocusRecordEntity) => {
      existingKeySet.add(`${r.startTime}_${r.actualSeconds}`);
    });

    // 2. 获取并映射标签列表 (名称 -> tagId)
    const tags: FocusTag[] = await this.getTags();
    const tagMapByName: Map<string, number> = new Map<string, number>();
    tags.forEach((t: FocusTag) => {
      tagMapByName.set(t.name, t.id);
    });

    let importedCount = 0;
    let skippedCount = 0;

    for (let i = 0; i < payload.records.length; i++) {
      const item: ExportRecordItem = payload.records[i];
      let startTime = 0;
      if (item.startTimestamp && item.startTimestamp > 0) {
        startTime = item.startTimestamp;
      } else if (item.startTime) {
        const parsed = Date.parse(item.startTime);
        startTime = !isNaN(parsed) && parsed > 0 ? parsed : Date.now() - (item.actualSeconds || 0) * 1000;
      } else {
        startTime = Date.now() - (item.actualSeconds || 0) * 1000;
      }

      const actualSecs = item.actualSeconds || 0;
      const dedupeKey = `${startTime}_${actualSecs}`;

      if (existingKeySet.has(dedupeKey)) {
        skippedCount++;
        continue;
      }

      let endTime = 0;
      if (item.endTimestamp && item.endTimestamp > 0) {
        endTime = item.endTimestamp;
      } else if (item.endTime) {
        const parsedEnd = Date.parse(item.endTime);
        endTime = !isNaN(parsedEnd) && parsedEnd > 0 ? parsedEnd : startTime + actualSecs * 1000;
      } else {
        endTime = startTime + actualSecs * 1000;
      }

      // 处理标签匹配与自动补全
      const tagName = item.tag || 'Flow';
      let tagId = tagMapByName.get(tagName);
      if (!tagId) {
        tagId = await this.addTag(tagName, TAG_COLOR_CUSTOM, 'tag_custom');
        tagMapByName.set(tagName, tagId);
      }

      const state = item.state === 'COMPLETED' ? FocusState.COMPLETED : FocusState.CANCELED;

      const record: FocusRecordEntity = {
        userId: uid,
        tagId: tagId,
        targetMinutes: item.targetMinutes || 25,
        actualSeconds: actualSecs,
        startTime: startTime,
        endTime: endTime,
        state: state,
        note: item.note || undefined,
        rating: item.rating !== undefined ? item.rating : 5
      };

      await this.recordDao.insert(record);
      existingKeySet.add(dedupeKey);
      importedCount++;
    }

    hilog.info(DOMAIN, TAG, `Restore completed: imported=${importedCount}, skipped=${skippedCount}, total=${payload.records.length}`);
    return {
      success: true,
      totalInPayload: payload.records.length,
      importedCount: importedCount,
      skippedCount: skippedCount
    };
  }

  /**
   * 安全抹除所有本地历史专注记录 (清空数据库)
   */
  public async wipeAllRecords(userId?: string): Promise<number> {
    const uid: string = (userId && userId.length > 0) ? userId : (AppStorage.get<string>('currentUserId') || GUEST_USER_ID);
    hilog.warn(DOMAIN, TAG, `Wiping all focus records for user: ${uid}`);
    return await this.recordDao.clearAllRecords(uid);
  }

  /**
   * 更新专注记录的心流随笔心得与气韵评级
   */
  public async updateFocusRecordReflection(recordId: number, note: string, rating: number): Promise<boolean> {
    hilog.info(DOMAIN, TAG, `Updating reflection for record #${recordId}: rating=${rating}, noteLength=${note.length}`);
    return await this.recordDao.updateNoteAndRating(recordId, note, rating);
  }

  /**
   * 触发 ArkData 原生端云协同增量同步
   */
  public async triggerCloudSync(): Promise<boolean> {
    const isCloudEnabled = AppStorage.get<boolean>('isCloudSyncEnabled') ?? true;
    const isLoggedIn = AppStorage.get<boolean>('isLoggedIn') ?? false;
    if (!isCloudEnabled || !isLoggedIn) {
      hilog.info(DOMAIN, TAG, 'Cloud sync skipped: disabled or not logged in.');
      return false;
    }
    hilog.info(DOMAIN, TAG, 'Triggering ArkData native cloud sync for focus records...');
    return await RdbManager.getInstance().syncCloud();
  }
}

export const timeIslandRepository: TimeIslandRepository = new TimeIslandRepository();
