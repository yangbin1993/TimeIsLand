import { formBindingData, formProvider } from '@kit.FormKit';
import { preferences } from '@kit.ArkData';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { Configuration } from '@kit.AbilityKit';
import { SolarTermHelper } from './SolarTermHelper';

const DOMAIN = 0x0000;
const TAG = 'WidgetSyncManager';
const PREF_WIDGET_SYNC = 'timeisland_widget_sync';
const KEY_ACTIVE_FORMS = 'active_forms';
const KEY_TODAY_MINUTES = 'today_minutes';
const KEY_TODAY_COUNT = 'today_count';
const KEY_ALL_TIME_MINUTES = 'all_time_minutes';
const KEY_STREAK_DAYS = 'streak_days';
const KEY_CURRENT_TAG = 'current_tag';
const KEY_IS_NEARLINK_ACTIVE = 'is_nearlink_active';

/**
 * 晨昏槽位与多语言标题模型
 */
export interface BiomeSlotInfo {
  slot: string;
  title: string;
}

/**
 * 桌面卡片绑定的强类型数据结构 (全面支持万物互联、生境境界与节气朱印)
 */
export class IslandCardFormData {
  public formDimension: number = 2; // 2: 2x2, 3: 2x4
  public todayMinutes: number = 0;
  public todayCompletedCount: number = 0;
  public allTimeMinutes: number = 0;
  public currentTag: string = '';
  public biomeSlot: string = 'DAY';
  public biomeTitle: string = '';
  public lakeStoragePercent: number = 50;
  public realmName: string = '';
  public realmLevel: number = 1;
  public solarTermName: string = '';
  public solarTermSeal: string = '';
  public isNearLinkActive: boolean = false;
  public streakDays: number = 0;
  public defaultDuration: number = 15;

  constructor(
    todayMinutes: number = 0,
    todayCompletedCount: number = 0,
    currentTag: string = '',
    biomeSlot: string = 'DAY',
    biomeTitle: string = '',
    lakeStoragePercent: number = 50,
    defaultDuration: number = 15
  ) {
    this.todayMinutes = todayMinutes;
    this.todayCompletedCount = todayCompletedCount;
    this.currentTag = currentTag;
    this.biomeSlot = biomeSlot;
    this.biomeTitle = biomeTitle;
    this.lakeStoragePercent = lakeStoragePercent;
    this.defaultDuration = defaultDuration;
  }
}

/**
 * 桌面原子化元服务卡片同步与生命周期中枢管理器
 */
export class WidgetSyncManager {
  private static instance: WidgetSyncManager | null = null;

  public static getInstance(): WidgetSyncManager {
    if (!WidgetSyncManager.instance) {
      WidgetSyncManager.instance = new WidgetSyncManager();
    }
    return WidgetSyncManager.instance;
  }

  /**
   * 推断当前现实自然时间的岛屿晨昏槽位与多语言标题
   */
  public getBiomeSlotAndTitle(context: Context): BiomeSlotInfo {
    const hour = new Date().getHours();
    let slot = 'DAY';
    let resId = $r('app.string.biome_day_title').id;

    if (hour >= 5 && hour < 9) {
      slot = 'DAWN';
      resId = $r('app.string.biome_dawn_title').id;
    } else if (hour >= 9 && hour < 17) {
      slot = 'DAY';
      resId = $r('app.string.biome_day_title').id;
    } else if (hour >= 17 && hour < 20) {
      slot = 'DUSK';
      resId = $r('app.string.biome_dusk_title').id;
    } else {
      slot = 'NIGHT';
      resId = $r('app.string.biome_night_title').id;
    }

    let title = '';
    try {
      title = context.resourceManager.getStringSync(resId);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to resolve biome title resource: %{public}s', JSON.stringify(err));
    }
    const result: BiomeSlotInfo = {
      slot: slot,
      title: title
    };
    return result;
  }

  /**
   * 构造最新的卡片视图绑定数据实体
   */
  public async buildLatestFormData(context: Context, dimension: number = 2): Promise<IslandCardFormData> {
    const biomeInfo = this.getBiomeSlotAndTitle(context);
    const biomeSlot = biomeInfo.slot;
    const biomeTitle = biomeInfo.title;

    let todayMins = 0;
    let todayCount = 0;
    let allTimeMins = 0;
    let streakDays = 0;
    let currentTag = '';
    let isNearLinkActive = false;

    try {
      const pref = await preferences.getPreferences(context, PREF_WIDGET_SYNC);
      todayMins = await pref.get(KEY_TODAY_MINUTES, 0) as number;
      todayCount = await pref.get(KEY_TODAY_COUNT, 0) as number;
      allTimeMins = await pref.get(KEY_ALL_TIME_MINUTES, 0) as number;
      streakDays = await pref.get(KEY_STREAK_DAYS, 0) as number;
      currentTag = await pref.get(KEY_CURRENT_TAG, '') as string;
      isNearLinkActive = await pref.get(KEY_IS_NEARLINK_ACTIVE, false) as boolean;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to read widget sync preference: %{public}s', JSON.stringify(err));
    }

    if (!currentTag) {
      try {
        currentTag = context.resourceManager.getStringSync($r('app.string.tag_name_code').id);
      } catch (err) {
        currentTag = 'Flow';
      }
    }

    // 节气与印章推算
    let solarTermName = '';
    let solarTermSeal = '';
    try {
      const termId = SolarTermHelper.getCurrentTermId();
      const allTerms = SolarTermHelper.getAllTerms();
      const currentTerm = allTerms.find(t => t.id === termId);
      if (currentTerm) {
        solarTermName = context.resourceManager.getStringSync(currentTerm.nameRes.id);
        solarTermSeal = context.resourceManager.getStringSync(currentTerm.sealRes.id);
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to resolve solar term strings: %{public}s', JSON.stringify(err));
    }

    // 生境四大境界计算
    let realmName = '';
    let realmLevel = 1;
    try {
      const realmInfo = SolarTermHelper.computeRealm(allTimeMins);
      realmName = context.resourceManager.getStringSync(realmInfo.nameRes.id);
      realmLevel = realmInfo.level;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to resolve realm strings: %{public}s', JSON.stringify(err));
    }

    // 湖泊水位：基准 120 分钟满蓄 (10% ~ 100%)
    const lakeStoragePercent = Math.min(100, Math.max(10, Math.round((todayMins / 120) * 100)));

    const formData = new IslandCardFormData(
      todayMins,
      todayCount,
      currentTag,
      biomeSlot,
      biomeTitle,
      lakeStoragePercent,
      15
    );
    formData.formDimension = dimension;
    formData.allTimeMinutes = allTimeMins;
    formData.realmName = realmName;
    formData.realmLevel = realmLevel;
    formData.solarTermName = solarTermName;
    formData.solarTermSeal = solarTermSeal;
    formData.isNearLinkActive = isNearLinkActive;
    formData.streakDays = streakDays;

    return formData;
  }

  /**
   * 注册活跃的桌面卡片 ID 及其规格
   */
  public async addActiveFormId(context: Context, formId: string, dimension: number = 2): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, PREF_WIDGET_SYNC);
      const rawList = await pref.get(KEY_ACTIVE_FORMS, '[]') as string;
      const ids: string[] = JSON.parse(rawList) as string[];
      if (!ids.includes(formId)) {
        ids.push(formId);
        await pref.put(KEY_ACTIVE_FORMS, JSON.stringify(ids));
      }
      await pref.put(`form_dim_${formId}`, dimension);
      await pref.flush();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to add active form ID: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 移除销毁的桌面卡片 ID
   */
  public async removeActiveFormId(context: Context, formId: string): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, PREF_WIDGET_SYNC);
      const rawList = await pref.get(KEY_ACTIVE_FORMS, '[]') as string;
      let ids: string[] = JSON.parse(rawList) as string[];
      ids = ids.filter(id => id !== formId);
      await pref.put(KEY_ACTIVE_FORMS, JSON.stringify(ids));
      await pref.delete(`form_dim_${formId}`);
      await pref.flush();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to remove active form ID: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 获取所有已添加到桌面的活跃卡片 ID 列表
   */
  public async getActiveFormIds(context: Context): Promise<string[]> {
    try {
      const pref = await preferences.getPreferences(context, PREF_WIDGET_SYNC);
      const rawList = await pref.get(KEY_ACTIVE_FORMS, '[]') as string;
      return JSON.parse(rawList) as string[];
    } catch (err) {
      return [];
    }
  }

  /**
   * 刷新指定的单一桌面卡片
   */
  public async updateSingleForm(context: Context, formId: string): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, PREF_WIDGET_SYNC);
      const dimension = await pref.get(`form_dim_${formId}`, 2) as number;
      const formData = await this.buildLatestFormData(context, dimension);
      const binding = formBindingData.createFormBindingData(formData);
      await formProvider.updateForm(formId, binding);
      hilog.info(DOMAIN, TAG, `Form updated: id=${formId}, dim=${dimension}, slot=${formData.biomeSlot}, mins=${formData.todayMinutes}`);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to update form %{public}s: %{public}s', formId, JSON.stringify(err));
    }
  }

  /**
   * 广播刷新所有桌面卡片 (语言变化、深浅主题流转、系统时间跨度时调用)
   */
  public async refreshAllWidgets(context: Context, newConfig?: Configuration): Promise<void> {
    if (newConfig) {
      hilog.info(
        DOMAIN,
        TAG,
        'Applying system configuration change to widgets: language=%{public}s, colorMode=%{public}s',
        newConfig.language ?? 'system',
        String(newConfig.colorMode ?? -1)
      );
    }
    const ids = await this.getActiveFormIds(context);
    hilog.info(DOMAIN, TAG, `Refreshing all widgets count: ${ids.length}`);
    for (const formId of ids) {
      await this.updateSingleForm(context, formId);
    }
  }

  /**
   * 主应用在专注完成时同步持久化并实时通知所有桌面卡片跳变数据
   */
  public async syncFocusDataToWidgets(
    context: Context,
    todayMinutes: number,
    todayCount: number,
    currentTagName: string,
    allTimeMinutes: number = 0,
    streakDays: number = 0,
    isNearLinkActive: boolean = false
  ): Promise<void> {
    try {
      const pref = await preferences.getPreferences(context, PREF_WIDGET_SYNC);
      await pref.put(KEY_TODAY_MINUTES, todayMinutes);
      await pref.put(KEY_TODAY_COUNT, todayCount);
      await pref.put(KEY_CURRENT_TAG, currentTagName);
      if (allTimeMinutes > 0) {
        await pref.put(KEY_ALL_TIME_MINUTES, allTimeMinutes);
      }
      if (streakDays > 0) {
        await pref.put(KEY_STREAK_DAYS, streakDays);
      }
      await pref.put(KEY_IS_NEARLINK_ACTIVE, isNearLinkActive);
      await pref.flush();
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to persist focus data to widget preference: %{public}s', JSON.stringify(err));
    }

    await this.refreshAllWidgets(context);
  }
}

export const widgetSyncManager = WidgetSyncManager.getInstance();
