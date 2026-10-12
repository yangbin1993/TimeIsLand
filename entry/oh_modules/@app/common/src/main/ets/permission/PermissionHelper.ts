import { abilityAccessCtrl, bundleManager, common, Permissions } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { PermissionConfigProvider, PermissionRationale } from './config/PermissionConfigProvider';
import { CommonStrings } from '../constants/CommonStrings';

const TAG: string = 'PermissionHelper';
const DOMAIN: number = 0x0000;

/**
 * 权限请求响应状态契约
 */
export interface PermissionResult {
  /**
   * 是否全部申请通过
   */
  allGranted: boolean;

  /**
   * 已成功授予的权限列表
   */
  grantedList: Permissions[];

  /**
   * 被用户拒绝的权限列表
   */
  deniedList: Permissions[];
}

/**
 * 鸿蒙生产级应用权限统一管理辅助套件 (PermissionHelper)
 * 深度对标 Android 架构中的 PermissionX / XXPermissions
 * 
 * 核心架构职责：
 * 1. 动静权限分离检测：提供同步/异步系统级权限状态自检 (checkPermission)；
 * 2. 运行时批量动态申请：基于 Promise 封装 requestPermissionsFromUser 弹窗逻辑；
 * 3. 细粒度归约与分流：清晰归约通过列表 (grantedList) 与被拒列表 (deniedList)；
 * 4. 依赖倒置文案与交互：面向 PermissionConfigProvider 契约，支持业务定制 Rationale 弹窗与设置页引导挽回；
 * 5. 永久拒绝二次挽回：支持直接调用 requestPermissionOnSetting 或安全跳转至系统应用详情设置页。
 */
export class PermissionHelper {
  private static instance: PermissionHelper;
  private atManager: abilityAccessCtrl.AtManager;
  private configProvider?: PermissionConfigProvider;

  private constructor() {
    this.atManager = abilityAccessCtrl.createAtManager();
    hilog.info(DOMAIN, TAG, 'PermissionHelper instance initialized');
  }

  /**
   * 依赖倒置：注入业务宿主层实现的权限配置提供者 (PermissionConfigProvider)
   * 
   * @param provider 宿主实现的权限配置提供者
   */
  public setConfigProvider(provider: PermissionConfigProvider): void {
    this.configProvider = provider;
    hilog.info(DOMAIN, TAG, 'PermissionConfigProvider injected successfully into PermissionHelper');
  }

  /**
   * 获取当前生效的权限配置提供者
   */
  public getConfigProvider(): PermissionConfigProvider | undefined {
    return this.configProvider;
  }

  /**
   * 获取 PermissionHelper 全局统一单例
   */
  public static getInstance(): PermissionHelper {
    if (!PermissionHelper.instance) {
      PermissionHelper.instance = new PermissionHelper();
    }
    return PermissionHelper.instance;
  }

  /**
   * 检查应用当前是否已获得指定权限 (AccessToken 校验)
   * 
   * @param permission 待检测的系统权限标识 (如 'ohos.permission.LOCATION')
   * @returns 是否已被授予权限 Promise<boolean>
   */
  public async checkPermission(permission: Permissions): Promise<boolean> {
    try {
      // 1. 获取本应用自身的 AccessTokenID
      const bundleInfo: bundleManager.BundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_WITH_APPLICATION
      );
      const tokenId: number = bundleInfo.appInfo.accessTokenId;

      // 2. 校验权限授权状态 (0: 允许 PERMISSION_GRANTED, -1: 拒绝 PERMISSION_DENIED)
      const grantStatus: abilityAccessCtrl.GrantStatus = this.atManager.checkAccessTokenSync(tokenId, permission);
      const isGranted = grantStatus === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED;
      hilog.info(DOMAIN, TAG, `Permission [${permission}] check result: ${String(isGranted)}`);
      return isGranted;
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `Failed to check permission [${permission}]: ${error.message}`);
      return false;
    }
  }

  /**
   * 检查多个权限是否已全部授予
   * 
   * @param permissions 待检测权限数组
   * @returns 是否全部授予 Promise<boolean>
   */
  public async checkAllPermissions(permissions: Permissions[]): Promise<boolean> {
    for (const perm of permissions) {
      const granted = await this.checkPermission(perm);
      if (!granted) {
        return false;
      }
    }
    return true;
  }

  /**
   * 动态向用户申请运行时权限 (User-Grant 弹窗)
   * 
   * @param context 当前 UIAbility 上下文组件
   * @param permissions 待申请权限列表 (注意：必须已在 module.json5 中完成声明)
   * @returns 强类型授权统计结果 Promise<PermissionResult>
   */
  public async requestPermissions(
    context: common.UIAbilityContext,
    permissions: Permissions[]
  ): Promise<PermissionResult> {
    const grantedList: Permissions[] = [];
    const deniedList: Permissions[] = [];

    // 1. 过滤已授权的权限，仅对未获得的权限发起弹窗
    const pendingPermissions: Permissions[] = [];
    for (const perm of permissions) {
      const alreadyGranted = await this.checkPermission(perm);
      if (alreadyGranted) {
        grantedList.push(perm);
      } else {
        pendingPermissions.push(perm);
      }
    }

    if (pendingPermissions.length === 0) {
      return {
        allGranted: true,
        grantedList: grantedList,
        deniedList: deniedList
      };
    }

    hilog.info(DOMAIN, TAG, `Requesting permissions: ${JSON.stringify(pendingPermissions)}`);

    try {
      // 2. 唤起鸿蒙系统级授权交互弹窗
      const result = await this.atManager.requestPermissionsFromUser(
        context,
        pendingPermissions
      );

      // 3. 统计并归约每个权限的授权判定
      for (let i = 0; i < result.permissions.length; i++) {
        const perm = result.permissions[i] as Permissions;
        const authStatus = result.authResults[i];

        if (authStatus === 0) {
          // 0 代表用户同意授予 (PERMISSION_GRANTED)
          grantedList.push(perm);
        } else {
          // -1 代表被用户拒绝，2 代表系统未声明或无效
          deniedList.push(perm);
        }
      }

      const allGranted = deniedList.length === 0;
      hilog.info(
        DOMAIN,
        TAG,
        `Permission request finished: allGranted=${String(allGranted)}, granted=${grantedList.length}, denied=${deniedList.length}`
      );

      const res: PermissionResult = {
        allGranted: allGranted,
        grantedList: grantedList,
        deniedList: deniedList
      };
      this.configProvider?.onPermissionResult?.(res);
      return res;
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `Failed to request permissions: ${error.message}`);
      const errRes: PermissionResult = {
        allGranted: false,
        grantedList: grantedList,
        deniedList: pendingPermissions
      };
      this.configProvider?.onPermissionResult?.(errRes);
      return errRes;
    }
  }

  /**
   * 智能化全流程权限申请（结合业务倒置契约：申请前 Rationale 阐释 + 系统授权弹窗 + 被拒后二次挽回引导）
   * 深度对标 Android PermissionX 的 .explainReasonBeforeRequest() 与 .onForwardToSettings()
   * 
   * @param context 当前 UIAbility 上下文
   * @param permissions 待申请权限列表
   * @returns 强类型授权统计结果
   */
  public async requestWithGuide(
    context: common.UIAbilityContext,
    permissions: Permissions[]
  ): Promise<PermissionResult> {
    // 1. 过滤已授权的权限
    const pendingPermissions: Permissions[] = [];
    const alreadyGrantedList: Permissions[] = [];
    for (const perm of permissions) {
      const granted = await this.checkPermission(perm);
      if (granted) {
        alreadyGrantedList.push(perm);
      } else {
        pendingPermissions.push(perm);
      }
    }

    if (pendingPermissions.length === 0) {
      const quickResult: PermissionResult = {
        allGranted: true,
        grantedList: alreadyGrantedList,
        deniedList: []
      };
      this.configProvider?.onPermissionResult?.(quickResult);
      return quickResult;
    }

    // 2. 申请前业务 Rationale 阐释弹窗（若契约支持并配置）
    if (this.configProvider?.showRationaleDialog) {
      // 获取首个未授权权限的说明或通用说明
      const firstPerm = pendingPermissions[0];
      const rationale: PermissionRationale = this.configProvider.getRationale(firstPerm) ?? {
        message: CommonStrings.PERM_DEFAULT_RATIONALE_MSG
      };

      const userAgreed = await this.configProvider.showRationaleDialog(context, pendingPermissions, rationale);
      if (!userAgreed) {
        // 用户在 Rationale 阶段取消申请
        const cancelResult: PermissionResult = {
          allGranted: false,
          grantedList: alreadyGrantedList,
          deniedList: pendingPermissions
        };
        this.configProvider?.onPermissionResult?.(cancelResult);
        return cancelResult;
      }
    }

    // 3. 执行系统级授权申请
    const result = await this.requestPermissions(context, pendingPermissions);
    const finalResult: PermissionResult = {
      allGranted: result.allGranted && (alreadyGrantedList.length + result.grantedList.length === permissions.length),
      grantedList: [...alreadyGrantedList, ...result.grantedList],
      deniedList: result.deniedList
    };

    // 4. 若存在被拒权限且契约配置了二次挽回引导，则弹出引导弹窗
    if (!finalResult.allGranted && finalResult.deniedList.length > 0 && this.configProvider?.showDeniedGuideDialog) {
      const shouldGoSettings = await this.configProvider.showDeniedGuideDialog(context, finalResult.deniedList);
      if (shouldGoSettings) {
        await this.openAppSettings(context, finalResult.deniedList);
      }
    }

    return finalResult;
  }

  /**
   * 在权限被永久拒绝或二次弹窗无法呼出时，弹窗引导用户跳转至系统的“应用设置页面”进行手动授权
   * 优先采用 HarmonyOS API 12+ 官方标准的 requestPermissionOnSetting 体系
   * 对应 Android 中的 Settings.ACTION_APPLICATION_DETAILS_SETTINGS
   * 
   * @param context 当前 UIAbility 上下文
   * @param permissions 可选被拒绝的权限列表 (用于定向精准设置)
   */
  public async openAppSettings(context: common.UIAbilityContext, permissions?: Permissions[]): Promise<void> {
    // 1. 优先使用 HarmonyOS API 12+ 官方标准能力 requestPermissionOnSetting
    if (permissions && permissions.length > 0) {
      try {
        hilog.info(DOMAIN, TAG, 'Opening settings via atManager.requestPermissionOnSetting...');
        await this.atManager.requestPermissionOnSetting(context, permissions);
        return;
      } catch (reqSettingErr) {
        hilog.warn(DOMAIN, TAG, `requestPermissionOnSetting fallback to startAbility: ${JSON.stringify(reqSettingErr)}`);
      }
    }

    // 2. 传统通用 Ability 跳转降级兜底方案
    try {
      const bundleInfo: bundleManager.BundleInfo = await bundleManager.getBundleInfoForSelf(
        bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT
      );
      const bundleName: string = bundleInfo.name;

      hilog.info(DOMAIN, TAG, `Navigating to system settings for bundle: ${bundleName}`);

      // 启动系统级设置应用中的应用详情与权限配置面板
      await context.startAbility({
        bundleName: 'com.huawei.hmos.settings',
        abilityName: 'com.huawei.hmos.settings.MainAbility',
        uri: 'application_info_entry',
        parameters: {
          pushParams: bundleName
        }
      });
    } catch (err) {
      const error = err as BusinessError;
      hilog.error(DOMAIN, TAG, `Failed to launch app settings page: ${error.message}`);
    }
  }
}

/**
 * 快捷导出全局权限管理单例
 */
export const permissionHelper: PermissionHelper = PermissionHelper.getInstance();
