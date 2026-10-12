import { pasteboard } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DialogHelper } from '../dialog/DialogHelper';
import { CommonStrings } from '../constants/CommonStrings';

const TAG: string = 'ClipboardHelper';
const DOMAIN: number = 0x0000;

/**
 * 生产级系统剪贴板统一门面服务 (ClipboardHelper)
 * 深度对标 Android ClipboardManager
 * 
 * 核心架构特性：
 * 1. 纯 Promise 异步 API：封装鸿蒙系统级 pasteboard.SystemPasteboard；
 * 2. 交互式 Toast 联动：支持复制成功自动唤起去重 Toast 提示，消除业务重复弹窗；
 * 3. 强容错防崩溃保护：捕获安全沙箱、进程隔离及受限权限异常，保证 100% 杜绝 Promise unhandled rejection；
 * 4. 文本常量驱动：提示文案统一接入常量池与资源隔离。
 */
export class ClipboardHelper {
  private static instance: ClipboardHelper;

  private constructor() {}

  /**
   * 获取 ClipboardHelper 全局统一单例
   */
  public static getInstance(): ClipboardHelper {
    if (!ClipboardHelper.instance) {
      ClipboardHelper.instance = new ClipboardHelper();
    }
    return ClipboardHelper.instance;
  }

  /**
   * 将指定文本写入系统剪贴板
   *
   * @param text 要复制的纯文本字符串
   * @param showToastTip 是否在复制成功后自动弹出 Toast 提示 (默认 true)
   * @param customToastMsg 自定义提示文案 (可选，默认使用系统通用常量)
   * @returns 是否复制成功 Promise<boolean>
   */
  public async copyText(
    text: string,
    showToastTip: boolean = true,
    customToastMsg?: string
  ): Promise<boolean> {
    if (text === undefined || text === null) {
      hilog.warn(DOMAIN, TAG, 'Attempted to copy null or undefined text to clipboard');
      return false;
    }

    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
      await systemPasteboard.setData(pasteData);
      hilog.info(DOMAIN, TAG, `Text copied to system clipboard: length=${text.length}`);

      if (showToastTip) {
        const tip = customToastMsg ?? CommonStrings.DIALOG_CONFIRM;
        DialogHelper.showToast(tip);
      }
      return true;
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Failed to copy text to pasteboard: ${(err as Error).message}`);
      return false;
    }
  }

  /**
   * 从系统剪贴板异步读取纯文本内容
   *
   * @returns 剪贴板中的纯文本字符串 (若为空或非文本则返回空字符串)
   */
  public async readText(): Promise<string> {
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const pasteData = await systemPasteboard.getData();
      if (!pasteData) {
        return '';
      }
      const primaryText = pasteData.getPrimaryText();
      return primaryText ?? '';
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Failed to read text from pasteboard: ${(err as Error).message}`);
      return '';
    }
  }

  /**
   * 检查系统剪贴板当前是否包含有效文本数据
   *
   * @returns 是否含有文本内容 Promise<boolean>
   */
  public async hasText(): Promise<boolean> {
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      const pasteData = await systemPasteboard.getData();
      if (!pasteData) {
        return false;
      }
      return pasteData.hasType(pasteboard.MIMETYPE_TEXT_PLAIN);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `Failed to check pasteboard text: ${(err as Error).message}`);
      return false;
    }
  }

  /**
   * 安全清空系统剪贴板数据
   */
  public async clear(): Promise<void> {
    try {
      const systemPasteboard = pasteboard.getSystemPasteboard();
      await systemPasteboard.clearData();
      hilog.info(DOMAIN, TAG, 'System clipboard cleared successfully');
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Failed to clear system pasteboard: ${(err as Error).message}`);
    }
  }
}

/**
 * 快捷导出全局剪贴板门面单例
 */
export const clipboardHelper: ClipboardHelper = ClipboardHelper.getInstance();
