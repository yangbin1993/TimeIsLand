import { window } from '@kit.ArkUI';
import { preferences } from '@kit.ArkData';
import { ConfigurationConstant } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { ThemeMode, ThemePalette, ThemeOption } from './ThemeTypes';

const DOMAIN = 0x0000;
const TAG = 'ThemeManager';
const PREF_STORE_NAME = 'timeisland_theme_pref';
const PREF_KEY_THEME_MODE = 'timeisland_theme_mode';

/**
 * 时光岛 - 全局主题生境管理器单例 (ThemeManager)
 * 职责: 统一管理系统深浅色联动、自定义群岛生境皮肤流转、窗口状态栏沉浸协同与用户偏好持久化
 */
export class ThemeManager {
  private static instance: ThemeManager | null = null;
  private currentMode: ThemeMode = ThemeMode.DARK;
  private prefStore: preferences.Preferences | null = null;
  private mainWindow: window.Window | null = null;
  private context: Context | null = null;

  public static getInstance(): ThemeManager {
    if (!ThemeManager.instance) {
      ThemeManager.instance = new ThemeManager();
    }
    return ThemeManager.instance;
  }

  /**
   * 初始化主题管理器 (在 UIAbility onWindowStageCreate 中调用)
   */
  public async init(context: Context, win: window.Window): Promise<void> {
    this.context = context;
    this.mainWindow = win;
    try {
      this.prefStore = await preferences.getPreferences(context, PREF_STORE_NAME);
      const savedMode = await this.prefStore.get(PREF_KEY_THEME_MODE, ThemeMode.DARK) as string;
      this.currentMode = (savedMode as ThemeMode) || ThemeMode.DARK;
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to read theme preference: %{public}s', JSON.stringify(err));
      this.currentMode = ThemeMode.DARK;
    }

    await this.applyTheme(this.currentMode);
  }

  /**
   * 切换主题模式
   */
  public async setThemeMode(mode: ThemeMode): Promise<void> {
    this.currentMode = mode;
    try {
      if (this.prefStore) {
        await this.prefStore.put(PREF_KEY_THEME_MODE, mode);
        await this.prefStore.flush();
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to save theme preference: %{public}s', JSON.stringify(err));
    }

    await this.applyTheme(mode);
  }

  /**
   * 获取当前生效的主题模式
   */
  public getThemeMode(): ThemeMode {
    return this.currentMode;
  }

  /**
   * 响应系统深浅色模式切换事件 (在 UIAbility onConfigurationUpdate 中调用)
   */
  public async onSystemConfigurationUpdate(): Promise<void> {
    if (this.currentMode === ThemeMode.SYSTEM) {
      await this.applyTheme(ThemeMode.SYSTEM);
    }
  }

  /**
   * 获取可供选择的主题生境列表元数据
   */
  public getThemeOptions(): ThemeOption[] {
    return [
      {
        mode: ThemeMode.DARK,
        nameRes: $r('app.string.timeisland_theme_mode_dark'),
        descRes: $r('app.string.timeisland_theme_mode_dark_desc'),
        primaryPreviewColor: '#4EDEA3',
        canvasPreviewColor: '#0F131C'
      },
      {
        mode: ThemeMode.GOLD,
        nameRes: $r('app.string.timeisland_theme_mode_gold'),
        descRes: $r('app.string.timeisland_theme_mode_gold_desc'),
        primaryPreviewColor: '#F59E0B',
        canvasPreviewColor: '#14120E'
      },
      {
        mode: ThemeMode.MOSS,
        nameRes: $r('app.string.timeisland_theme_mode_moss'),
        descRes: $r('app.string.timeisland_theme_mode_moss_desc'),
        primaryPreviewColor: '#10B981',
        canvasPreviewColor: '#0D1714'
      },
      {
        mode: ThemeMode.LIGHT,
        nameRes: $r('app.string.timeisland_theme_mode_light'),
        descRes: $r('app.string.timeisland_theme_mode_light_desc'),
        primaryPreviewColor: '#059669',
        canvasPreviewColor: '#F8FAFC'
      },
      {
        mode: ThemeMode.SYSTEM,
        nameRes: $r('app.string.timeisland_theme_mode_system'),
        descRes: $r('app.string.timeisland_theme_mode_system_desc'),
        primaryPreviewColor: '#4A8FFC',
        canvasPreviewColor: '#181B25'
      }
    ];
  }

  /**
   * 核心应用主题变更
   */
  private async applyTheme(mode: ThemeMode): Promise<void> {
    const isLightMode = mode === ThemeMode.LIGHT;

    // 1. 系统级深浅色模式流转
    if (this.context) {
      try {
        const appCtx = this.context.getApplicationContext();
        if (mode === ThemeMode.SYSTEM) {
          appCtx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
        } else if (mode === ThemeMode.LIGHT) {
          appCtx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT);
        } else {
          appCtx.setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_DARK);
        }
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'Failed to update application color mode: %{public}s', JSON.stringify(err));
      }
    }

    // 2. 窗口级状态栏文本图标动态协同 (沉浸式 Edge-to-Edge 系统栏图标/文字反色)
    if (this.mainWindow) {
      try {
        await this.mainWindow.setWindowSystemBarProperties({
          statusBarColor: '#00000000',
          navigationBarColor: '#00000000',
          statusBarContentColor: isLightMode ? '#0F172A' : '#F8FAFC',
          navigationBarContentColor: isLightMode ? '#0F172A' : '#F8FAFC'
        });
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'Failed to update window system bar properties: %{public}s', JSON.stringify(err));
      }
    }

    // 2. 构造响应式色板并派发给 AppStorage
    const palette = this.getPaletteByMode(mode);
    AppStorage.setOrCreate<ThemePalette>('currentTheme', palette);
    AppStorage.setOrCreate<ThemeMode>('currentThemeMode', mode);

    hilog.info(DOMAIN, TAG, 'Successfully applied theme mode: %{public}s', mode);
  }

  /**
   * 根据生境主题模式构建强类型调色板
   */
  public getPaletteByMode(mode: ThemeMode): ThemePalette {
    switch (mode) {
      case ThemeMode.GOLD:
        return {
          bgCanvas: '#14120E',
          surfaceCard: '#1E1A14',
          surfaceLow: '#27221A',
          surfaceLowest: '#100E0A',
          surfaceIndigo: '#34291B',
          primaryAccent: '#F59E0B',
          primaryAccentGlow: '#FCD34D',
          primaryAccentBg: '#2E2210',
          secondaryAccent: '#FBBF24',
          havenAmber: '#FBBF24',
          havenAmberBg: '#221B10',
          havenAmberBorder: '#4E3A16',
          textPrimary: '#FFFBEB',
          textSecondary: '#FDE68A',
          textMuted: '#927B5E',
          textInverse: '#14120E',
          borderSubtle: '#33291B',
          borderCard: '#3A2E1F',
          tabActiveBg: '#2D2316',
          shadowFloating: '#30000000',
          shadowCard: '#40000000',
          shadowElevated: '#50000000',
          shadowModal: '#80000000',
          primaryGlow: '#50F59E0B',
          runningGlow: '#40FBBF24',
          secondaryGlow: '#40F59E0B',
          textClockGlow: '#30FFFBEB'
        };

      case ThemeMode.MOSS:
        return {
          bgCanvas: '#0D1714',
          surfaceCard: '#13231F',
          surfaceLow: '#18302A',
          surfaceLowest: '#0A1210',
          surfaceIndigo: '#1C3E34',
          primaryAccent: '#10B981',
          primaryAccentGlow: '#34D399',
          primaryAccentBg: '#102E24',
          secondaryAccent: '#2DD4BF',
          havenAmber: '#FBBF24',
          havenAmberBg: '#221B10',
          havenAmberBorder: '#4E3A16',
          textPrimary: '#ECFDF5',
          textSecondary: '#A7F3D0',
          textMuted: '#62897B',
          textInverse: '#0D1714',
          borderSubtle: '#1C3831',
          borderCard: '#24473E',
          tabActiveBg: '#18322B',
          shadowFloating: '#30000000',
          shadowCard: '#40000000',
          shadowElevated: '#50000000',
          shadowModal: '#80000000',
          primaryGlow: '#5010B981',
          runningGlow: '#402DD4BF',
          secondaryGlow: '#4010B981',
          textClockGlow: '#30ECFDF5'
        };

      case ThemeMode.LIGHT:
        return {
          bgCanvas: '#F8FAFC',
          surfaceCard: '#FFFFFF',
          surfaceLow: '#F1F5F9',
          surfaceLowest: '#E2E8F0',
          surfaceIndigo: '#E0E7FF',
          primaryAccent: '#059669',
          primaryAccentGlow: '#10B981',
          primaryAccentBg: '#D1FAE5',
          secondaryAccent: '#2563EB',
          havenAmber: '#D97706',
          havenAmberBg: '#FEF3C7',
          havenAmberBorder: '#FDE68A',
          textPrimary: '#0F172A',
          textSecondary: '#334155',
          textMuted: '#64748B',
          textInverse: '#FFFFFF',
          borderSubtle: '#E2E8F0',
          borderCard: '#CBD5E1',
          tabActiveBg: '#E2E8F0',
          shadowFloating: '#15000000',
          shadowCard: '#1A000000',
          shadowElevated: '#20000000',
          shadowModal: '#40000000',
          primaryGlow: '#30059669',
          runningGlow: '#252563EB',
          secondaryGlow: '#30059669',
          textClockGlow: '#200F172A'
        };

      case ThemeMode.DARK:
      case ThemeMode.SYSTEM:
      default:
        return {
          bgCanvas: $r('app.color.timeisland_bg_canvas'),
          surfaceCard: $r('app.color.timeisland_surface_card'),
          surfaceLow: $r('app.color.timeisland_surface_low'),
          surfaceLowest: $r('app.color.timeisland_surface_lowest'),
          surfaceIndigo: $r('app.color.timeisland_surface_indigo'),
          primaryAccent: $r('app.color.timeisland_emerald'),
          primaryAccentGlow: $r('app.color.timeisland_emerald_glow'),
          primaryAccentBg: $r('app.color.timeisland_emerald_bg'),
          secondaryAccent: $r('app.color.timeisland_lake_blue'),
          havenAmber: $r('app.color.timeisland_haven_amber'),
          havenAmberBg: $r('app.color.timeisland_haven_amber_bg'),
          havenAmberBorder: $r('app.color.timeisland_haven_amber_border'),
          textPrimary: $r('app.color.timeisland_text_primary'),
          textSecondary: $r('app.color.timeisland_text_secondary'),
          textMuted: $r('app.color.timeisland_text_muted'),
          textInverse: $r('app.color.timeisland_text_inverse'),
          borderSubtle: $r('app.color.timeisland_border_subtle'),
          borderCard: $r('app.color.timeisland_border_card'),
          tabActiveBg: $r('app.color.timeisland_tab_active_bg'),
          shadowFloating: $r('app.color.timeisland_shadow_floating'),
          shadowCard: $r('app.color.timeisland_shadow_card'),
          shadowElevated: $r('app.color.timeisland_shadow_elevated'),
          shadowModal: $r('app.color.timeisland_shadow_modal'),
          primaryGlow: $r('app.color.timeisland_glow_emerald'),
          runningGlow: $r('app.color.timeisland_glow_lake_blue'),
          secondaryGlow: $r('app.color.timeisland_glow_blue_pill'),
          textClockGlow: $r('app.color.timeisland_glow_text')
        };
    }
  }
}

export const themeManager = ThemeManager.getInstance();
