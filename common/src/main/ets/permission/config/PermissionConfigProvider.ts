import { common, Permissions } from '@kit.AbilityKit';
import { PermissionResult } from '../PermissionHelper';

/**
 * 权限使用阐释文案结构
 */
export interface PermissionRationale {
  /**
   * 提示弹窗标题 (如 '需要相机访问权限')
   */
  title?: string;

  /**
   * 申请权限的业务原因阐述 (如 '为了支持拍照上传头像与扫描二维码功能，应用需要访问您的相机')
   */
  message: string;

  /**
   * 确认/允许按钮文案 (默认为 '去授权' 或 '允许')
   */
  confirmText?: string;

  /**
   * 取消/暂不按钮文案 (默认为 '取消' 或 '暂不')
   */
  cancelText?: string;
}

/**
 * 权限体系依赖倒置契约接口 (PermissionConfigProvider)
 * 遵循依赖倒置原则 (DIP)，将业务侧专属的文案解释、弹窗样式、设置引导与埋点监听从基础设施抽离
 */
export interface PermissionConfigProvider {
  /**
   * 获取指定权限的业务阐释说明 (Rationale)
   * 
   * @param permission 目标系统权限标识
   * @returns 该权限对应的业务理由说明；若未配置则返回 undefined
   */
  getRationale(permission: Permissions): PermissionRationale | undefined;

  /**
   * 业务自定义：在唤起系统授权弹窗前，向用户弹出权限使用阐释弹窗 (Rationale Dialog)
   * 用户如果点击同意，则继续拉起系统授权弹窗；若取消则提前中止
   * 
   * @param context 当前 UIAbility 上下文
   * @param permissions 本次待申请的权限列表
   * @param rationale 建议的文案信息
   * @returns Promise<boolean> 用户是否同意继续申请
   */
  showRationaleDialog?(
    context: common.UIAbilityContext,
    permissions: Permissions[],
    rationale: PermissionRationale
  ): Promise<boolean>;

  /**
   * 业务自定义：当权限被用户拒绝后，弹窗引导用户前往系统设置页进行手动授权
   * 
   * @param context 当前 UIAbility 上下文
   * @param deniedPermissions 本次被拒绝的权限列表
   * @returns Promise<boolean> 用户是否同意前往系统设置
   */
  showDeniedGuideDialog?(
    context: common.UIAbilityContext,
    deniedPermissions: Permissions[]
  ): Promise<boolean>;

  /**
   * 权限请求全局事件监听回调（常用于业务层统一埋点、风控上报等）
   * 
   * @param result 最终的权限归约结果
   */
  onPermissionResult?(result: PermissionResult): void;
}
