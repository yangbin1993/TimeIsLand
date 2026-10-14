import { hilog } from '@kit.PerformanceAnalysisKit';
import { BaseRepository, TaskDispatcher } from '@app/common';
import { FocusTag, FocusRecordEntity, FocusOverviewStat, DayFocusSummary, TagFocusSummary, FocusState } from '../model/FocusTypes';
import { focusTagDao, FocusTagDao } from './FocusTagDao';
import { focusRecordDao, FocusRecordDao } from './FocusRecordDao';

const TAG = 'TimeIslandRepository';
const DOMAIN = 0x0000;

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
}

export const timeIslandRepository: TimeIslandRepository = new TimeIslandRepository();
