/**
 * 节气元数据契约
 */
export interface SolarTermItem {
  id: number;
  nameRes: Resource;
  sealRes: Resource;
  poemRes: Resource;
  month: number;
  dayApprox: number;
  seasonColor: Resource;
}

/**
 * 生境境界演进契约
 */
export interface BiomeRealmInfo {
  level: number;
  nameRes: Resource;
  descRes: Resource;
  minMinutes: number;
  nextThresholdMinutes: number;
  progressPercent: number;
  mountainPillars: number;
  treeBaseCount: number;
  hasSnowPeak: boolean;
  hasBambooForest: boolean;
}

/**
 * 东方二十四节气与禅意生境演变辅助管理器
 */
export class SolarTermHelper {
  private static readonly TERMS: SolarTermItem[] = [
    // 春季 (青绿生发)
    { id: 1, nameRes: $r('app.string.solar_term_1_name'), sealRes: $r('app.string.solar_term_1_seal'), poemRes: $r('app.string.solar_term_1_poem'), month: 2, dayApprox: 4, seasonColor: $r('app.color.timeisland_season_spring') },
    { id: 2, nameRes: $r('app.string.solar_term_2_name'), sealRes: $r('app.string.solar_term_2_seal'), poemRes: $r('app.string.solar_term_2_poem'), month: 2, dayApprox: 19, seasonColor: $r('app.color.timeisland_season_spring') },
    { id: 3, nameRes: $r('app.string.solar_term_3_name'), sealRes: $r('app.string.solar_term_3_seal'), poemRes: $r('app.string.solar_term_3_poem'), month: 3, dayApprox: 5, seasonColor: $r('app.color.timeisland_season_spring') },
    { id: 4, nameRes: $r('app.string.solar_term_4_name'), sealRes: $r('app.string.solar_term_4_seal'), poemRes: $r('app.string.solar_term_4_poem'), month: 3, dayApprox: 20, seasonColor: $r('app.color.timeisland_season_spring') },
    { id: 5, nameRes: $r('app.string.solar_term_5_name'), sealRes: $r('app.string.solar_term_5_seal'), poemRes: $r('app.string.solar_term_5_poem'), month: 4, dayApprox: 4, seasonColor: $r('app.color.timeisland_season_spring') },
    { id: 6, nameRes: $r('app.string.solar_term_6_name'), sealRes: $r('app.string.solar_term_6_seal'), poemRes: $r('app.string.solar_term_6_poem'), month: 4, dayApprox: 20, seasonColor: $r('app.color.timeisland_season_spring') },
    // 夏季 (朱火纯茂)
    { id: 7, nameRes: $r('app.string.solar_term_7_name'), sealRes: $r('app.string.solar_term_7_seal'), poemRes: $r('app.string.solar_term_7_poem'), month: 5, dayApprox: 5, seasonColor: $r('app.color.timeisland_season_summer') },
    { id: 8, nameRes: $r('app.string.solar_term_8_name'), sealRes: $r('app.string.solar_term_8_seal'), poemRes: $r('app.string.solar_term_8_poem'), month: 5, dayApprox: 21, seasonColor: $r('app.color.timeisland_season_summer') },
    { id: 9, nameRes: $r('app.string.solar_term_9_name'), sealRes: $r('app.string.solar_term_9_seal'), poemRes: $r('app.string.solar_term_9_poem'), month: 6, dayApprox: 5, seasonColor: $r('app.color.timeisland_season_summer') },
    { id: 10, nameRes: $r('app.string.solar_term_10_name'), sealRes: $r('app.string.solar_term_10_seal'), poemRes: $r('app.string.solar_term_10_poem'), month: 6, dayApprox: 21, seasonColor: $r('app.color.timeisland_season_summer') },
    { id: 11, nameRes: $r('app.string.solar_term_11_name'), sealRes: $r('app.string.solar_term_11_seal'), poemRes: $r('app.string.solar_term_11_poem'), month: 7, dayApprox: 7, seasonColor: $r('app.color.timeisland_season_summer') },
    { id: 12, nameRes: $r('app.string.solar_term_12_name'), sealRes: $r('app.string.solar_term_12_seal'), poemRes: $r('app.string.solar_term_12_poem'), month: 7, dayApprox: 22, seasonColor: $r('app.color.timeisland_season_summer') },
    // 秋季 (金风玉露)
    { id: 13, nameRes: $r('app.string.solar_term_13_name'), sealRes: $r('app.string.solar_term_13_seal'), poemRes: $r('app.string.solar_term_13_poem'), month: 8, dayApprox: 7, seasonColor: $r('app.color.timeisland_season_autumn') },
    { id: 14, nameRes: $r('app.string.solar_term_14_name'), sealRes: $r('app.string.solar_term_14_seal'), poemRes: $r('app.string.solar_term_14_poem'), month: 8, dayApprox: 23, seasonColor: $r('app.color.timeisland_season_autumn') },
    { id: 15, nameRes: $r('app.string.solar_term_15_name'), sealRes: $r('app.string.solar_term_15_seal'), poemRes: $r('app.string.solar_term_15_poem'), month: 9, dayApprox: 7, seasonColor: $r('app.color.timeisland_season_autumn') },
    { id: 16, nameRes: $r('app.string.solar_term_16_name'), sealRes: $r('app.string.solar_term_16_seal'), poemRes: $r('app.string.solar_term_16_poem'), month: 9, dayApprox: 23, seasonColor: $r('app.color.timeisland_season_autumn') },
    { id: 17, nameRes: $r('app.string.solar_term_17_name'), sealRes: $r('app.string.solar_term_17_seal'), poemRes: $r('app.string.solar_term_17_poem'), month: 10, dayApprox: 8, seasonColor: $r('app.color.timeisland_season_autumn') },
    { id: 18, nameRes: $r('app.string.solar_term_18_name'), sealRes: $r('app.string.solar_term_18_seal'), poemRes: $r('app.string.solar_term_18_poem'), month: 10, dayApprox: 23, seasonColor: $r('app.color.timeisland_season_autumn') },
    // 冬季 (玄冰积素)
    { id: 19, nameRes: $r('app.string.solar_term_19_name'), sealRes: $r('app.string.solar_term_19_seal'), poemRes: $r('app.string.solar_term_19_poem'), month: 11, dayApprox: 7, seasonColor: $r('app.color.timeisland_season_winter') },
    { id: 20, nameRes: $r('app.string.solar_term_20_name'), sealRes: $r('app.string.solar_term_20_seal'), poemRes: $r('app.string.solar_term_20_poem'), month: 11, dayApprox: 22, seasonColor: $r('app.color.timeisland_season_winter') },
    { id: 21, nameRes: $r('app.string.solar_term_21_name'), sealRes: $r('app.string.solar_term_21_seal'), poemRes: $r('app.string.solar_term_21_poem'), month: 12, dayApprox: 7, seasonColor: $r('app.color.timeisland_season_winter') },
    { id: 22, nameRes: $r('app.string.solar_term_22_name'), sealRes: $r('app.string.solar_term_22_seal'), poemRes: $r('app.string.solar_term_22_poem'), month: 12, dayApprox: 21, seasonColor: $r('app.color.timeisland_season_winter') },
    { id: 23, nameRes: $r('app.string.solar_term_23_name'), sealRes: $r('app.string.solar_term_23_seal'), poemRes: $r('app.string.solar_term_23_poem'), month: 1, dayApprox: 5, seasonColor: $r('app.color.timeisland_season_winter') },
    { id: 24, nameRes: $r('app.string.solar_term_24_name'), sealRes: $r('app.string.solar_term_24_seal'), poemRes: $r('app.string.solar_term_24_poem'), month: 1, dayApprox: 20, seasonColor: $r('app.color.timeisland_season_winter') }
  ];

  /**
   * 获取全部 24 节气列表
   */
  public static getAllTerms(): SolarTermItem[] {
    return SolarTermHelper.TERMS;
  }

  /**
   * 推算当前公历时间所处的节气 ID (1~24)
   * 依据阳历自然年时间轴顺序进行精确匹配
   */
  public static getCurrentTermId(): number {
    const now = new Date();
    const month = now.getMonth() + 1; // 1~12
    const day = now.getDate();
    const dateKey = month * 100 + day;

    // 阳历自然年升序节气表 (dateKey: MMDD, termId)
    const timeline: number[][] = [
      [105, 23], // 小寒
      [120, 24], // 大寒
      [204, 1],  // 立春
      [219, 2],  // 雨水
      [305, 3],  // 惊蛰
      [320, 4],  // 春分
      [404, 5],  // 清明
      [420, 6],  // 谷雨
      [505, 7],  // 立夏
      [521, 8],  // 小满
      [605, 9],  // 芒种
      [621, 10], // 夏至
      [707, 11], // 小暑
      [722, 12], // 大暑
      [807, 13], // 立秋
      [823, 14], // 处暑
      [907, 15], // 白露
      [923, 16], // 秋分
      [1008, 17],// 寒露
      [1023, 18],// 霜降
      [1107, 19],// 立冬
      [1122, 20],// 小雪
      [1207, 21],// 大雪
      [1221, 22] // 冬至
    ];

    let matchedId = 22; // 跨年阶段 (1月1日~1月4日) 承接上一年度冬至
    for (let i = 0; i < timeline.length; i++) {
      if (dateKey >= timeline[i][0]) {
        matchedId = timeline[i][1];
      } else {
        break;
      }
    }
    return matchedId;
  }

  /**
   * 获取月份多语言资源映射
   */
  public static getMonthResource(month: number): Resource {
    switch (month) {
      case 1: return $r('app.string.biome_month_1');
      case 2: return $r('app.string.biome_month_2');
      case 3: return $r('app.string.biome_month_3');
      case 4: return $r('app.string.biome_month_4');
      case 5: return $r('app.string.biome_month_5');
      case 6: return $r('app.string.biome_month_6');
      case 7: return $r('app.string.biome_month_7');
      case 8: return $r('app.string.biome_month_8');
      case 9: return $r('app.string.biome_month_9');
      case 10: return $r('app.string.biome_month_10');
      case 11: return $r('app.string.biome_month_11');
      case 12: return $r('app.string.biome_month_12');
      default: return $r('app.string.biome_month_1');
    }
  }

  /**
   * 根据历史累计专注分钟数推算生境演进四大境界
   */
  public static computeRealm(allTimeMinutes: number): BiomeRealmInfo {
    if (allTimeMinutes < 120) {
      // 境界一: 初生 · 荒渚微澜 (0 ~ 120 分钟)
      const pct = Math.min(100, Math.round((allTimeMinutes / 120) * 100));
      return {
        level: 1,
        nameRes: $r('app.string.biome_realm_1_name'),
        descRes: $r('app.string.biome_realm_1_desc'),
        minMinutes: 0,
        nextThresholdMinutes: 120,
        progressPercent: pct,
        mountainPillars: 1,
        treeBaseCount: 3,
        hasSnowPeak: false,
        hasBambooForest: false
      };
    } else if (allTimeMinutes < 600) {
      // 境界二: 筑基 · 空山幽径 (120 ~ 600 分钟 / 10小时)
      const range = 600 - 120;
      const progress = allTimeMinutes - 120;
      const pct = Math.min(100, Math.round((progress / range) * 100));
      return {
        level: 2,
        nameRes: $r('app.string.biome_realm_2_name'),
        descRes: $r('app.string.biome_realm_2_desc'),
        minMinutes: 120,
        nextThresholdMinutes: 600,
        progressPercent: pct,
        mountainPillars: 2,
        treeBaseCount: 6,
        hasSnowPeak: false,
        hasBambooForest: false
      };
    } else if (allTimeMinutes < 1800) {
      // 境界三: 聚气 · 幽篁深境 (600 ~ 1800 分钟 / 30小时)
      const range = 1800 - 600;
      const progress = allTimeMinutes - 600;
      const pct = Math.min(100, Math.round((progress / range) * 100));
      return {
        level: 3,
        nameRes: $r('app.string.biome_realm_3_name'),
        descRes: $r('app.string.biome_realm_3_desc'),
        minMinutes: 600,
        nextThresholdMinutes: 1800,
        progressPercent: pct,
        mountainPillars: 3,
        treeBaseCount: 10,
        hasSnowPeak: false,
        hasBambooForest: true
      };
    } else {
      // 境界四: 合道 · 蓬莱雪境 (1800+ 分钟)
      return {
        level: 4,
        nameRes: $r('app.string.biome_realm_4_name'),
        descRes: $r('app.string.biome_realm_4_desc'),
        minMinutes: 1800,
        nextThresholdMinutes: 1800,
        progressPercent: 100,
        mountainPillars: 3,
        treeBaseCount: 12,
        hasSnowPeak: true,
        hasBambooForest: true
      };
    }
  }
}
