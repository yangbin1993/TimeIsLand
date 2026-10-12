import { UIAbility, AbilityConstant, Want, Configuration } from '@kit.AbilityKit';
import { window } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import {
  RdbManager,
  DialogHelper,
  CrashHandler,
  AppLifecycleManager
} from '@app/common';
import { focusTagDao } from './data/FocusTagDao';
import { focusRecordDao } from './data/FocusRecordDao';
import { themeManager } from './theme/ThemeManager';

const DOMAIN = 0x0000;
const TAG = 'TimeIslandAppAbility';

/**
 * 时光岛应用主 EntryAbility
 */
export default class AppAbility extends UIAbility {
  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    hilog.info(DOMAIN, TAG, 'TimeIsland AppAbility onCreate');
    this.initInfrastructure();
  }

  onDestroy(): void {
    hilog.info(DOMAIN, TAG, 'TimeIsland AppAbility onDestroy');
    CrashHandler.getInstance().unregister();
    AppLifecycleManager.getInstance().destroy();
    RdbManager.getInstance().close().catch(() => {});
  }

  async onWindowStageCreate(windowStage: window.WindowStage): Promise<void> {
    hilog.info(DOMAIN, TAG, 'TimeIsland AppAbility onWindowStageCreate');

    try {
      const mainWindow = windowStage.getMainWindowSync();
      const uiContext = mainWindow.getUIContext();
      DialogHelper.setUIContext(uiContext);

      // 1. 初始化并应用生境主题管理器 (自动接管窗口色调与系统栏反色)
      await themeManager.init(this.context, mainWindow);

      // 2. 开启 Edge-to-Edge 全屏沉浸式窗口
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

    // 初始化 SQLite RDB 本地数据库并注册表结构
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

    hilog.info(DOMAIN, TAG, 'TimeIsland infrastructure initialized.');
  }
}