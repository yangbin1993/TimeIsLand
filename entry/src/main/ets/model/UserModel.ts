/**
 * 用户身份模型与常量定义
 */

/**
 * 默认本地访客模式虚拟用户唯一标识
 */
export const GUEST_USER_ID = 'guest_local';

/**
 * 用户账号身份实体接口
 */
export interface UserAccount {
  /**
   * 应用维度匿名唯一凭据 (华为账号 openID 或 'guest_local')
   */
  userId: string;
  /**
   * 华为同一开发者跨应用统一标识 (可选)
   */
  unionId?: string;
  /**
   * 界面展示昵称
   */
  displayName: string;
  /**
   * 用户头像资源或路径
   */
  avatarUrl?: string;
  /**
   * 是否处于未登录的本地访客态
   */
  isGuest: boolean;
  /**
   * 登录成功毫秒时间戳
   */
  loginTime: number;
}
