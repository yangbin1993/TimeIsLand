import { authentication } from '@kit.AccountKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { preferences } from '@kit.ArkData';
import { UserAccount, GUEST_USER_ID } from '../model/UserModel';

const DOMAIN = 0x0000;
const TAG = 'AccountManager';
const PREF_ACCOUNT_STORE = 'timeisland_account_store';

/**
 * 账号与身份状态单例中枢管理器 (AccountManager)
 * 职责:
 * 1. 接管华为账号 (Huawei ID) 一键登录与静默免打扰授权；
 * 2. 维护本地沙箱访客 (Guest Mode) 与正式账号的平滑切换；
 * 3. 将 currentUserId、isLoggedIn 等关键身份状态驱动写入 AppStorage。
 */
export class AccountManager {
  private static instance: AccountManager | null = null;
  private prefStore: preferences.Preferences | null = null;
  private currentAccount: UserAccount = {
    userId: GUEST_USER_ID,
    displayName: 'Guest Voyager',
    isGuest: true,
    loginTime: Date.now()
  };

  private constructor() {}

  public static getInstance(): AccountManager {
    if (!AccountManager.instance) {
      AccountManager.instance = new AccountManager();
    }
    return AccountManager.instance;
  }

  /**
   * 初始化账号状态中心 (在 AppAbility onCreate / onWindowStageCreate 调用)
   */
  public async init(context: common.Context): Promise<void> {
    try {
      this.prefStore = await preferences.getPreferences(context, PREF_ACCOUNT_STORE);
      const savedUserId = await this.prefStore.get('active_user_id', GUEST_USER_ID) as string;
      const savedName = await this.prefStore.get('active_user_name', 'Guest Voyager') as string;

      this.currentAccount = {
        userId: savedUserId,
        displayName: savedName,
        isGuest: savedUserId === GUEST_USER_ID,
        loginTime: Date.now()
      };

      this.syncToAppStorage();
      hilog.info(DOMAIN, TAG, `AccountManager initialized: isGuest=${this.currentAccount.isGuest}`);

      // 若先前登录过华为账号，尝试异步静默刷新状态
      if (!this.currentAccount.isGuest) {
        this.silentLogin(context).catch((err: Error) => {
          hilog.info(DOMAIN, TAG, `Silent login background check skipped: ${err.message}`);
        });
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to initialize AccountManager preferences: %{public}s', JSON.stringify(err));
      this.syncToAppStorage();
    }
  }

  /**
   * 静默登录探测 (无界面弹窗打扰)
   */
  public async silentLogin(context: common.Context): Promise<boolean> {
    try {
      const provider = new authentication.HuaweiIDProvider();
      const request = provider.createLoginWithHuaweiIDRequest();
      request.forceLogin = false;

      const controller = new authentication.AuthenticationController(context);
      const response = await controller.executeRequest(request) as authentication.LoginWithHuaweiIDResponse;

      if (response?.data?.openID) {
        await this.handleLoginSuccess(response.data.openID);
        return true;
      }
    } catch (err) {
      hilog.info(DOMAIN, TAG, 'Silent login unavailable, remaining in current session.');
    }
    return false;
  }

  /**
   * 调起系统华为账号登录弹窗 (用户显式触发)
   */
  public async loginWithHuaweiID(context: common.Context): Promise<UserAccount> {
    try {
      const provider = new authentication.HuaweiIDProvider();
      const request = provider.createLoginWithHuaweiIDRequest();
      request.forceLogin = true;

      const controller = new authentication.AuthenticationController(context);
      const response = await controller.executeRequest(request) as authentication.LoginWithHuaweiIDResponse;

      if (!response?.data?.openID) {
        throw new Error('LoginWithHuaweiID returned empty credential.');
      }

      await this.handleLoginSuccess(response.data.openID);
      return this.currentAccount;
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to login with Huawei ID: %{public}s', JSON.stringify(err));
      throw new Error(err instanceof Error ? err.message : String(err));
    }
  }

  /**
   * 登出当前华为账号，安全平滑切回本地访客模式 (不删除本地数据)
   */
  public async logout(): Promise<void> {
    this.currentAccount = {
      userId: GUEST_USER_ID,
      displayName: 'Guest Voyager',
      isGuest: true,
      loginTime: Date.now()
    };

    if (this.prefStore) {
      try {
        await this.prefStore.put('active_user_id', GUEST_USER_ID);
        await this.prefStore.put('active_user_name', 'Guest Voyager');
        await this.prefStore.flush();
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'Failed to save logout state: %{public}s', JSON.stringify(err));
      }
    }

    this.syncToAppStorage();
    hilog.info(DOMAIN, TAG, 'User switched to guest mode.');
  }

  /**
   * 登录成功持久化与状态派发
   */
  private async handleLoginSuccess(openId: string): Promise<void> {
    const maskedSuffix = openId.length > 4 ? openId.slice(-4) : openId;
    const displayName = `Voyager_${maskedSuffix}`;

    this.currentAccount = {
      userId: openId,
      displayName: displayName,
      isGuest: false,
      loginTime: Date.now()
    };

    if (this.prefStore) {
      try {
        await this.prefStore.put('active_user_id', openId);
        await this.prefStore.put('active_user_name', displayName);
        await this.prefStore.flush();
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'Failed to save active user preference: %{public}s', JSON.stringify(err));
      }
    }

    this.syncToAppStorage();
    hilog.info(DOMAIN, TAG, `Huawei ID login completed successfully for user suffix ${maskedSuffix}`);
  }

  public getCurrentUserId(): string {
    return this.currentAccount.userId;
  }

  public isGuest(): boolean {
    return this.currentAccount.isGuest;
  }

  public getCurrentAccount(): UserAccount {
    return this.currentAccount;
  }

  private syncToAppStorage(): void {
    AppStorage.setOrCreate('currentUserId', this.currentAccount.userId);
    AppStorage.setOrCreate('isLoggedIn', !this.currentAccount.isGuest);
    AppStorage.setOrCreate('currentUserDisplayName', this.currentAccount.displayName);
  }
}

export const accountManager = AccountManager.getInstance();
