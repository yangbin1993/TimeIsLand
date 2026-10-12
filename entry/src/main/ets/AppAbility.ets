import { UIAbility, AbilityConstant, Want } from '@kit.AbilityKit';
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

  onWindowStageCreate(windowStage: window.WindowStage): void {
    hilog.info(DOMAIN, TAG, 'TimeIsland AppAbility onWindowStageCreate');

    try {
      const uiContext = windowStage.getMainWindowSync().getUIContext();
      DialogHelper.setUIContext(uiContext);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to set global UIContext: %{public}s', JSON.stringify(err));
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