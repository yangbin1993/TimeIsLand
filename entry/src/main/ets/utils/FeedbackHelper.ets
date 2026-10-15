import { common, Want } from '@kit.AbilityKit';
import { pasteboard } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { http } from '@kit.NetworkKit';
import { DialogHelper } from '@app/common';

const DOMAIN = 0x0000;
const TAG = 'FeedbackHelper';

export const PUSHPLUS_TOKEN = 'ae0192279ba04f4885ca669519db8efb';
const FEEDBACK_EMAIL = 'timeisland_feedback@163.com';

/**
 * 反馈提交参数契约
 */
export interface FeedbackSubmitParams {
  category: string;
  content: string;
  contact?: string;
  themeName: string;
}

/**
 * PushPlus 响应格式契约
 */
interface PushPlusResponse {
  code: number;
  msg: string;
  data?: string;
}

/**
 * PushPlus 请求体契约
 */
interface PushPlusPayload {
  token: string;
  title: string;
  content: string;
  template: string;
}

/**
 * 时光岛 - 用户禅意反馈与灵感直投助手 (FeedbackHelper)
 * 职责: 驱动原生免登录直推至开发者个人微信 (PushPlus)，并具备系统邮件与剪贴板双重平滑降级
 */
export class FeedbackHelper {
  /**
   * 唤起应用内原生免登录反馈页面
   */
  public static openFeedback(uiContext: UIContext): void {
    try {
      uiContext.getRouter().pushUrl({ url: 'pages/FeedbackWebPage' }).catch((err: Error) => {
        hilog.error(DOMAIN, TAG, 'Failed to pushUrl FeedbackPage: %{public}s', err.message);
      });
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to navigate to FeedbackPage: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 原生免登录直投: 发送用户反馈至 PushPlus 微信通道
   * @param params 反馈入参模型
   * @returns Promise<boolean> 是否投递成功
   */
  public static async sendPushPlusFeedback(params: FeedbackSubmitParams): Promise<boolean> {
    const httpRequest = http.createHttp();
    try {
      const nowStr = new Date().toLocaleString();
      const contentHtml = `
        <div style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; padding: 12px; background: #f8fafc; border-radius: 8px;">
          <h3 style="color: #0ea5e9; margin-top: 0;">🏝️【时光岛】用户心流灵感直投</h3>
          <p><b>🏷️ 反馈分类</b>：<span style="color: #6366f1;">${params.category}</span></p>
          <p><b>📝 反馈内容</b>：</p>
          <div style="background: #ffffff; padding: 12px; border-radius: 6px; border-left: 4px solid #0ea5e9; margin: 8px 0; font-size: 14px; line-height: 1.6; color: #1e293b;">
            ${params.content.replace(/\n/g, '<br/>')}
          </div>
          <p><b>📬 联系方式</b>：${params.contact && params.contact.trim().length > 0 ? params.contact : '用户未填写'}</p>
          <p><b>🎨 当前生境</b>：${params.themeName}</p>
          <p><b>📱 设备系统</b>：HarmonyOS NEXT (v1.0.0)</p>
          <p style="font-size: 12px; color: #94a3b8; margin-bottom: 0;">⏰ 投递时间：${nowStr}</p>
        </div>
      `;

      const requestPayload: PushPlusPayload = {
        token: PUSHPLUS_TOKEN,
        title: `[TimeIsland] ${params.category}: ${params.content.slice(0, 20)}`,
        content: contentHtml,
        template: 'html'
      };

      const reqHeaders: Record<string, string> = {
        'Content-Type': 'application/json'
      };

      const response = await httpRequest.request('http://www.pushplus.plus/send', {
        method: http.RequestMethod.POST,
        header: reqHeaders,
        extraData: JSON.stringify(requestPayload),
        connectTimeout: 8000,
        readTimeout: 8000
      });

      if (response.responseCode === 200) {
        let resultStr = '';
        if (typeof response.result === 'string') {
          resultStr = response.result;
        } else {
          resultStr = JSON.stringify(response.result);
        }
        const resObj = JSON.parse(resultStr) as PushPlusResponse;
        if (resObj.code === 200) {
          hilog.info(DOMAIN, TAG, 'PushPlus feedback sent successfully');
          return true;
        } else {
          hilog.warn(DOMAIN, TAG, 'PushPlus rejected with code: %{public}d, msg: %{public}s', resObj.code, resObj.msg);
          return false;
        }
      } else {
        hilog.error(DOMAIN, TAG, 'PushPlus HTTP error: %{public}d', response.responseCode);
        return false;
      }
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'Failed to send feedback via PushPlus: %{public}s', JSON.stringify(err));
      return false;
    } finally {
      httpRequest.destroy();
    }
  }

  /**
   * 兜底渠道: 唤起系统邮件客户端或复制邮箱
   */
  public static async sendEmailFeedback(context: common.UIAbilityContext, fallbackContent?: string): Promise<void> {
    let subject = 'TimeIsland Feedback';
    let body = fallbackContent ?? 'TimeIsland Feedback Template';
    try {
      subject = context.resourceManager.getStringSync($r('app.string.feedback_email_subject').id);
      if (!fallbackContent) {
        body = context.resourceManager.getStringSync($r('app.string.feedback_email_template').id);
      }
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
      try {
        const pasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, `${FEEDBACK_EMAIL}\n\n${body}`);
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
