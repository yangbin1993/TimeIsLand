import { common, Want } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DialogHelper } from '@app/common';

const DOMAIN = 0x0000;
const TAG = 'FeedbackHelper';

const FEEDBACK_EMAIL = 'timeisland_feedback@163.com';

/**
 * 时光岛 - 用户禅意反馈与灵感直投助手 (FeedbackHelper)
 * 职责: 支持拉起系统邮件直投与免权限剪贴板复制平滑降级，零自建后台成本倾听用户心声
 */
export class FeedbackHelper {
  /**
   * 唤起用户反馈通道
   * 优先尝试唤起系统邮件客户端；若无邮件应用则自动将开发者邮箱写入剪贴板并弹窗提示
   */
  public static async sendFeedback(context: common.UIAbilityContext): Promise<void> {
    let subject = 'TimeIsland Feedback';
    let body = 'TimeIsland Feedback Template';
    try {
      subject = context.resourceManager.getStringSync($r('app.string.feedback_email_subject').id);
      body = context.resourceManager.getStringSync($r('app.string.feedback_email_template').id);
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to fetch localized email content');
    }

    try {
      const emailUri = `mailto:${FEEDBACK_EMAIL}?subject=${encodeURIComponent(subject)}&body=${encodeURIComponent(body)}`;
      const want: Want = {
        action: 'ohos.want.action.sendData',
        uri: emailUri
      };

      await context.startAbility(want);
      DialogHelper.showToast($r('app.string.timeisland_feedback_open_mail_toast'));
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to launch system mail client, fallback to pasteboard: %{public}s', JSON.stringify(err));
      // 优雅降级：直接将开发者反馈邮箱写入系统剪贴板 (无需 READ 权限)
      try {
        const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, FEEDBACK_EMAIL);
        const systemPasteboard = pasteboard.getSystemPasteboard();
        await systemPasteboard.setData(pasteData);
        DialogHelper.showToast($r('app.string.timeisland_feedback_mail_copied_toast'));
      } catch (pasteErr) {
        hilog.error(DOMAIN, TAG, 'Failed to copy to pasteboard: %{public}s', JSON.stringify(pasteErr));
        DialogHelper.showToast($r('app.string.timeisland_feedback_mail_copied_toast'));
      }
    }
  }
}
