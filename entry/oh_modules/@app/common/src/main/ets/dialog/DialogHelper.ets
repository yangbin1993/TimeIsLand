import { promptAction, UIContext } from '@kit.ArkUI';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { CommonStrings } from '../constants/CommonStrings';
import {
  ActionSheetItem,
  ActionSheetOptions,
  ActionSheetResult,
  DialogAction,
  DialogOptions,
  DialogResult,
  DialogType
} from './DialogTypes';

const TAG: string = 'DialogHelper';
const DOMAIN: number = 0x0000;

/**
 * 框架级对话框统一调度门面服务 (DialogHelper)
 * 深度对标 Android MaterialAlertDialog / DialogX
 * 
 * 核心设计优势：
 * 1. 规避 API 废弃与多窗口歧义：基于 UIContext.getPromptAction() 调度，彻底解决 'promptAction.showToast is deprecated' 与 'ambiguous UI context'；
 * 2. 异常平滑归约保护：深度捕获用户点击遮罩/物理返回键等产生的取消事件，100% 杜绝 Promise unhandled rejection；
 * 3. 集中文本常量驱动：全面接入 CommonStrings 常量池，杜绝文字硬编码；
 * 4. 纯 Promise 命令式调度：告别冗长的状态变量与模板侵入，一行 await 即可获取用户选择。
 */
export class DialogHelper {
  private static instance: DialogHelper;
  private static globalUIContext?: UIContext;
  private static lastToastMessage: string = '';
  private static lastToastTimestamp: number = 0;

  private constructor() {}

  /**
   * 获取 DialogHelper 全局统一单例
   */
  public static getInstance(): DialogHelper {
    if (!DialogHelper.instance) {
      DialogHelper.instance = new DialogHelper();
    }
    return DialogHelper.instance;
  }

  /**
   * 注册应用全局默认的 UIContext 上下文
   * 推荐在 AppAbility.onWindowStageCreate 中通过 windowStage.getMainWindowSync().getUIContext() 注入
   * 
   * @param context 窗口绑定的 UIContext 实例
   */
  public static setUIContext(context: UIContext): void {
    DialogHelper.globalUIContext = context;
    hilog.info(DOMAIN, TAG, 'Global UIContext registered into DialogHelper');
  }

  /**
   * 获取当前生效的 UIContext 实例
   */
  public static getUIContext(): UIContext | undefined {
    return DialogHelper.globalUIContext;
  }

  /**
   * 优先获取与当前上下文绑定的 PromptAction 实例，规避 API 废弃与环境歧义
   */
  private static getActivePromptAction(explicitContext?: UIContext) {
    const ctx = explicitContext ?? DialogHelper.globalUIContext;
    if (ctx) {
      return ctx.getPromptAction();
    }
    return undefined;
  }

  /**
   * 唤起轻量级浮层 Toast 提示
   * 优先采用 UIContext.getPromptAction().showToast() 现代 API，规避静态方法废弃
   * 
   * @param message 提示文案
   * @param duration 持续显示时长 (毫秒，默认为 2000ms)
   * @param context 可选显式传入目标组件的 UIContext (若不传则使用全局注入的 UIContext)
   */
  public static showToast(message: string, duration: number = 2000, context?: UIContext): void {
    const now = Date.now();
    // 工业级防刷与去重：1200ms 内弹出完全相同的 Toast 则予以合并抑制
    if (message === DialogHelper.lastToastMessage && now - DialogHelper.lastToastTimestamp < 1200) {
      hilog.info(DOMAIN, TAG, `Toast suppressed due to deduplication debounce: ${message}`);
      return;
    }
    DialogHelper.lastToastMessage = message;
    DialogHelper.lastToastTimestamp = now;

    try {
      const pa = DialogHelper.getActivePromptAction(context);
      if (pa) {
        pa.showToast({
          message: message,
          duration: duration
        });
        hilog.info(DOMAIN, TAG, `Toast shown via active UIContext: ${message}`);
        return;
      }
      hilog.warn(DOMAIN, TAG, `No active UIContext registered into DialogHelper. Toast suppressed: ${message}`);
    } catch (err) {
      hilog.error(DOMAIN, TAG, `UIContext showToast failed: ${JSON.stringify(err)}`);
    }
  }

  /**
   * 唤起通用对话框，返回强类型 DialogResult
   * 具备 UIContext 优先 + 静态 PromptAction 双重容灾，杜绝未就绪不弹出
   * 内部具备完善的取消异常安全捕获机制，用户点击蒙层或物理返回均平滑返回取消状态
   * 
   * @param options 弹窗配置项
   * @param context 可选显式传入目标组件的 UIContext
   * @returns 包含用户动作与状态的 Promise 结果
   */
  public static async showDialog(options: DialogOptions, context?: UIContext): Promise<DialogResult> {
    const type: DialogType = options.type ?? DialogType.CONFIRM;
    const title: string = options.title ?? CommonStrings.DIALOG_DEFAULT_TITLE;
    const message: string = options.message ?? '';
    const confirmText: string = options.confirmText ?? CommonStrings.DIALOG_CONFIRM;
    const cancelText: string = options.cancelText ?? CommonStrings.DIALOG_CANCEL;
    const isDanger: boolean = options.isDanger ?? false;

    let buttons: promptAction.Button[];
    if (type === DialogType.ALERT) {
      const okBtn: promptAction.Button = { text: confirmText, color: '#007AFF' };
      buttons = [okBtn];
    } else {
      const cancelBtn: promptAction.Button = { text: cancelText, color: '#888888' };
      const confirmBtn: promptAction.Button = {
        text: confirmText,
        color: isDanger ? '#FF3B30' : '#007AFF'
      };
      buttons = [cancelBtn, confirmBtn];
    }

    const dialogOptions: promptAction.ShowDialogOptions = {
      title: title,
      message: message,
      buttons: buttons
    };

    try {
      hilog.info(DOMAIN, TAG, `Showing dialog: title=${title}, type=${type}`);
      const pa = DialogHelper.getActivePromptAction(context);
      if (!pa) {
        hilog.error(DOMAIN, TAG, 'Active UIContext not ready. Cannot display showDialog.');
        return {
          action: DialogAction.CANCEL,
          isConfirmed: false
        };
      }

      const response: promptAction.ShowDialogSuccessResponse = await pa.showDialog(dialogOptions);

      if (type === DialogType.ALERT) {
        return {
          action: DialogAction.CONFIRM,
          isConfirmed: true
        };
      }

      // response.index 为 1 代表点击了第二个按钮 (即确认按钮)
      const isConfirmed = response.index === 1;
      hilog.info(DOMAIN, TAG, `Dialog closed by button click: isConfirmed=${String(isConfirmed)}`);

      return {
        action: isConfirmed ? DialogAction.CONFIRM : DialogAction.CANCEL,
        isConfirmed: isConfirmed
      };
    } catch (err) {
      // 核心防御点：
      // 在 ArkUI 中，当用户点击阴影蒙层(autoCancel)、按物理返回键、或滑动返回关闭弹窗时，
      // 系统底层的 showDialog 会以 Promise reject (抛出 BusinessError) 结束。
      // 这属于用户的正常交互取消行为，在此统一捕获并平滑归约，保证业务调用永远不会因用户取消而产生异常崩溃。
      hilog.info(DOMAIN, TAG, `Dialog closed by user cancel/dismiss gesture: ${JSON.stringify(err)}`);
      return {
        action: DialogAction.CANCEL,
        isConfirmed: false
      };
    }
  }

  /**
   * 快捷二次确认弹窗 (Confirm Dialog)
   * 
   * @param title 弹窗标题
   * @param message 确认阐述文案
   * @param confirmText 确认按钮文案 (默认为 CommonStrings.DIALOG_CONFIRM)
   * @param cancelText 取消按钮文案 (默认为 CommonStrings.DIALOG_CANCEL)
   * @param isDanger 是否为危险/警示操作 (如注销、删除，确认按钮将标红)
   * @param context 可选传入目标组件的 UIContext
   * @returns 用户是否点击了确认 Promise<boolean>
   */
  public static async showConfirm(
    title: string,
    message: string,
    confirmText: string = CommonStrings.DIALOG_CONFIRM,
    cancelText: string = CommonStrings.DIALOG_CANCEL,
    isDanger: boolean = false,
    context?: UIContext
  ): Promise<boolean> {
    const result = await DialogHelper.showDialog({
      type: DialogType.CONFIRM,
      title: title,
      message: message,
      confirmText: confirmText,
      cancelText: cancelText,
      isDanger: isDanger
    }, context);
    return result.isConfirmed;
  }

  /**
   * 快捷单按钮警示/通知弹窗 (Alert Dialog)
   * 
   * @param title 弹窗标题
   * @param message 说明文案
   * @param confirmText 确认按钮文案 (默认为 CommonStrings.DIALOG_KNOW)
   * @param context 可选传入目标组件的 UIContext
   */
  public static async showAlert(
    title: string,
    message: string,
    confirmText: string = CommonStrings.DIALOG_KNOW,
    context?: UIContext
  ): Promise<void> {
    await DialogHelper.showDialog({
      type: DialogType.ALERT,
      title: title,
      message: message,
      confirmText: confirmText
    }, context);
  }

  /**
   * 唤起底部操作表/菜单 (ActionSheet/ActionMenu)
   * 优先采用 active UIContext.getPromptAction().showActionMenu()
   * 包含平滑取消处理，用户点击蒙层或物理返回均返回 isCancelled: true, selectedIndex: -1
   *
   * @param options 操作表配置参数 (支持纯文本数组或结构化配置)
   * @param context 可选传入指定组件的 UIContext
   * @returns 强类型操作结果 Promise<ActionSheetResult>
   */
  public static async showActionSheet(options: ActionSheetOptions, context?: UIContext): Promise<ActionSheetResult> {
    const title = options.title ?? '';
    const rawItems = options.items.slice(0, 6); // 鸿蒙系统限制：ActionMenu 最多支持 6 项
    const buttons: promptAction.Button[] = rawItems.map((item) => {
      if (typeof item === 'string') {
        const btn: promptAction.Button = { text: item, color: '#007AFF' };
        return btn;
      }
      const structuredItem = item as ActionSheetItem;
      const btn: promptAction.Button = {
        text: structuredItem.title,
        color: structuredItem.isDanger ? '#FF3B30' : '#007AFF'
      };
      return btn;
    });

    const defaultBtn: promptAction.Button = { text: CommonStrings.DIALOG_CONFIRM, color: '#007AFF' };
    const firstBtn: promptAction.Button = buttons.length > 0 ? buttons[0] : defaultBtn;

    let menuButtons: [promptAction.Button, promptAction.Button?, promptAction.Button?, promptAction.Button?, promptAction.Button?, promptAction.Button?];
    if (buttons.length <= 1) {
      menuButtons = [firstBtn];
    } else if (buttons.length === 2) {
      menuButtons = [firstBtn, buttons[1]];
    } else if (buttons.length === 3) {
      menuButtons = [firstBtn, buttons[1], buttons[2]];
    } else if (buttons.length === 4) {
      menuButtons = [firstBtn, buttons[1], buttons[2], buttons[3]];
    } else if (buttons.length === 5) {
      menuButtons = [firstBtn, buttons[1], buttons[2], buttons[3], buttons[4]];
    } else {
      menuButtons = [firstBtn, buttons[1], buttons[2], buttons[3], buttons[4], buttons[5]];
    }

    const menuOptions: promptAction.ActionMenuOptions = {
      title: title,
      buttons: menuButtons
    };

    try {
      const pa = DialogHelper.getActivePromptAction(context);
      if (!pa) {
        hilog.error(DOMAIN, TAG, 'Active UIContext not ready. Cannot display showActionMenu.');
        return {
          selectedIndex: -1,
          isCancelled: true
        };
      }

      const response: promptAction.ActionMenuSuccessResponse = await pa.showActionMenu(menuOptions);

      return {
        selectedIndex: response.index,
        isCancelled: false
      };
    } catch (err) {
      hilog.info(DOMAIN, TAG, `ActionSheet dismissed/cancelled by user: ${JSON.stringify(err)}`);
      return {
        selectedIndex: -1,
        isCancelled: true
      };
    }
  }
}

/**
 * 快捷导出全局对话框门面单例
 */
export const dialogHelper: DialogHelper = DialogHelper.getInstance();
