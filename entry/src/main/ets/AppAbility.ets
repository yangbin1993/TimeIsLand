import { UIAbility, AbilityConstant, Want, Configuration } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  RdbManager,
  DialogHelper,
  CrashHandler,
  AppLifecycleManager,
  displayAdaptiveManager
} from '@app/common';
import { focusTagDao } from './data/FocusTagDao';
import { focusRecordDao } from './data/FocusRecordDao';
import { themeManager } from './theme/ThemeManager';
import { settingsManager } from './data/SettingsManager';
import { soundEffectManager } from './utils/SoundEffectManager';
import { whiteNoiseManager } from './utils/WhiteNoiseManager';
import { liveViewHelper } from './utils/LiveViewHelper';
import { apmsManager } from './utils/ApmsManager';
import { accountManager } from './utils/AccountManager';

const DOMAIN = 0x0000;
const TAG = 'TimeIslandAppAbility';

/**
 * 时光岛应用主 EntryAbility
 */
export default class AppAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'TimeIsland AppAbility onCreate');
    this.handleCardQuickStart(want);
    this.initInfrastructure();
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'TimeIsland AppAbility onNewWant');
    this.handleCardQuickStart(want);
  }

  private handleCardQuickStart(want: Want): void {
    if (want?.parameters?.quickStartMinutes) {
      const minutes = Number(want.parameters.quickStartMinutes);
      hilog.info(DOMAIN, TAG, 'Quick start requested from desktop card: %{public}d min', minutes);
      AppStorage.setOrCreate('cardQuickStartMinutes', minutes);
    }
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'TimeIsland AppAbility onDestroy');
    displayAdaptiveManager.destroy();
    CrashHandler.getInstance().unregister();
    AppLifecycleManager.getInstance().destroy();
    soundEffectManager.release();
    whiteNoiseManager.release();
    RdbManager.getInstance().close().catch(() => {});
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    hilog.info(DOMAIN, TAG, 'TimeIsland AppAbility onWindowStageCreate');

    try {
      const mainWindow = windowStage.getMainWindowSync();
      const uiContext = mainWindow.getUIContext();
      DialogHelper.setUIContext(uiContext);

      // 0. 初始化多屏与折叠屏响应式断点感知体系
      displayAdaptiveManager.init(windowStage);

      // 1. 初始化并应用生境主题管理器 (自动接管窗口色调与系统栏反色)
      await themeManager.init(this.context, mainWindow);

      // 2. 初始化用户偏好配置项 (实况窗、星闪、避风港守护等)
      await settingsManager.init(this.context);

      // 2.1 初始化用户账号中枢 (加载当前活跃账号态)
      await accountManager.init(this.context);

      // 3. 初始化触感按键微拟物音效池
      await soundEffectManager.init(this.context);

      // 4. 初始化白噪音自然声景播放引擎
      await whiteNoiseManager.init(this.context);

      // 5. 初始化实况窗本地化资源解析器
      liveViewHelper.init(this.context);

      // 6. 开启 Edge-to-Edge 全屏沉浸式窗口
      mainWindow.setWindowLayoutFullScreen(true);

      // 3. 读取初始状态栏与底部手势导航条避让高度 (px 转 vp)
      const topAvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_SYSTEM);
      const bottomAvoidArea = mainWindow.getWindowAvoidArea(window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR);
      const density = uiContext.getHostContext()?.resourceManager ? 1 : 1;
      
      const statusBarPx = topAvoidArea.topRect.height;
      const bottomNavPx = bottomAvoidArea.bottomRect.height;
      
      // 写入全局 AppStorage 供各页面组件无缝响应式避让
      AppStorage.setOrCreate('statusBarHeight', px2vp(statusBarPx));
      AppStorage.setOrCreate('bottomNavHeight', px2vp(bottomNavPx));

      // 4. 监听屏幕旋转与系统避让区动态变化 (Window Insets 响应式联动)
      mainWindow.on('avoidAreaChange', (data) => {
        if (data.type === window.AvoidAreaType.TYPE_SYSTEM) {
          AppStorage.setOrCreate('statusBarHeight', px2vp(data.area.topRect.height));
        } else if (data.type === window.AvoidAreaType.TYPE_NAVIGATION_INDICATOR) {
          AppStorage.setOrCreate('bottomNavHeight', px2vp(data.area.bottomRect.height));
        }
      });
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to configure immersive Edge-to-Edge window: %{public}s', JSON.stringify(err));
    }

    // 默认直接加载时光岛主页面
    windowStage.loadContent('pages/TimeIslandHomePage', (err) => {
      if (err.code) {
        hilog.error(DOMAIN, TAG, 'Failed to load content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, TAG, 'Succeeded in loading TimeIslandHomePage.');
    });
  }

  onWindowStageDestroy(): void {
    hilog.info(DOMAIN, TAG, 'TimeIsland AppAbility onWindowStageDestroy');
  }

  onForeground(): void {
    hilog.info(DOMAIN, TAG, 'TimeIsland AppAbility onForeground');
    AppLifecycleManager.getInstance().notifyForeground();
  }

  onBackground(): void {
    hilog.info(DOMAIN, TAG, 'TimeIsland AppAbility onBackground');
    AppLifecycleManager.getInstance().notifyBackground();
  }

  onConfigurationUpdate(newConfig: Configuration): void {
    hilog.info(DOMAIN, TAG, 'TimeIsland AppAbility onConfigurationUpdate: %{public}s', JSON.stringify(newConfig));
    themeManager.onSystemConfigurationUpdate();
  }

  private initInfrastructure(): void {
    hilog.info(DOMAIN, TAG, 'Initializing TimeIsland infrastructure...');

    // 注册全局未捕获异常监控
    CrashHandler.getInstance().register();

    // 初始化生命周期管理器
    AppLifecycleManager.getInstance().initialize(this.context);

    // 初始化 SQLite RDB 本地数据库并注册表结构 (全新开发直接一次性就绪最新表结构)
    RdbManager.getInstance().initialize(
      this.context,
      {
        name: 'timeisland.db',
        version: 1,
        migrations: []
      },
      [
        focusTagDao.getSchema(),
        focusRecordDao.getSchema()
      ]
    );

    // 启动华为 AGC APMS 性能与质量监控服务
    apmsManager.init(this.context);

    hilog.info(DOMAIN, TAG, 'TimeIsland infrastructure initialized.');
  }
}