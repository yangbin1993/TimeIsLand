import { nearLinkSanctuaryManager, NearLinkSanctuaryState, PartnerIslandInfo, SanctuaryStateListener, RippleReceivedListener } from '../utils/NearLinkSanctuaryManager';
import { soundEffectManager, SoundEffectType } from '../utils/SoundEffectManager';
import { ThemePalette } from '../theme/ThemeTypes';
import { DialogHelper } from '@app/common';

/**
 * 时光岛 - 星闪近场双子岛伴读视图 (主页顶级常驻 Tab 页面)
 */
@Component
export struct NearLinkSanctuaryView {
  @Prop theme: ThemePalette;

  @State private sanctuaryState: NearLinkSanctuaryState = NearLinkSanctuaryState.IDLE;
  @State private partnerInfo: PartnerIslandInfo | null = null;
  @State private rippleAnimScale: number = 1.0;
  @State private rippleNotice: ResourceStr = '';

  private stateListener: SanctuaryStateListener = (state: NearLinkSanctuaryState, partner: PartnerIslandInfo | null): void => {
    this.sanctuaryState = state;
    this.partnerInfo = partner;
  };

  private rippleListener: RippleReceivedListener = (_fromName: string): void => {
    soundEffectManager.play(SoundEffectType.BUBBLE);
    this.rippleNotice = $r('app.string.nearlink_notice_breeze_received');
    this.rippleAnimScale = 1.25;
    setTimeout(() => {
      this.rippleAnimScale = 1.0;
    }, 500);
    setTimeout(() => {
      this.rippleNotice = '';
    }, 3500);
  };

  aboutToAppear(): void {
    this.sanctuaryState = nearLinkSanctuaryManager.getState();
    this.partnerInfo = nearLinkSanctuaryManager.getPartner();

    nearLinkSanctuaryManager.addStateListener(this.stateListener);
    nearLinkSanctuaryManager.addRippleListener(this.rippleListener);
  }

  aboutToDisappear(): void {
    nearLinkSanctuaryManager.removeStateListener(this.stateListener);
    nearLinkSanctuaryManager.removeRippleListener(this.rippleListener);
  }

  private triggerTouchSearch(): void {
    const isEnabled = AppStorage.get<boolean>('isNearlinkEnabled') ?? true;
    if (!isEnabled) {
      DialogHelper.showToast($r('app.string.timeisland_toast_nearlink_disabled'));
      return;
    }
    soundEffectManager.play(SoundEffectType.PEN_CLICK);
    nearLinkSanctuaryManager.startTouchAndSanctuary();
  }

  private sendBreeze(): void {
    soundEffectManager.play(SoundEffectType.BUBBLE);
    nearLinkSanctuaryManager.sendRippleToPartner();
    this.rippleNotice = $r('app.string.nearlink_notice_breeze_sent');
    setTimeout(() => {
      this.rippleNotice = '';
    }, 2500);
  }

  private disconnect(): void {
    soundEffectManager.play(SoundEffectType.SWITCH_CLOSE);
    nearLinkSanctuaryManager.disconnectSanctuary();
  }

  build() {
    Column() {
      // 1. 硬件引擎状态胶囊
      Row({ space: 6 }) {
        Row()
          .width(6)
          .height(6)
          .borderRadius(3)
          .backgroundColor(nearLinkSanctuaryManager.isHardwareSupported() ? this.theme.primaryAccent : this.theme.havenAmber)

        Text(nearLinkSanctuaryManager.isHardwareSupported() ? $r('app.string.nearlink_hw_ready') : $r('app.string.nearlink_sandbox_mode'))
          .fontSize(11)
          .fontColor(this.theme.textSecondary)
      }
      .padding({ left: 12, right: 12, top: 4, bottom: 4 })
      .backgroundColor(this.theme.surfaceLow)
      .borderRadius(12)
      .margin({ top: 14, bottom: 16 })

      // 2. 中间交互视窗
      if (this.sanctuaryState === NearLinkSanctuaryState.IDLE) {
        Column({ space: 14 }) {
          Image($r('app.media.ic_nearlink'))
            .width(64)
            .height(64)
            .fillColor(this.theme.primaryAccent)
            .opacity(0.85)

          Text($r('app.string.nearlink_desc'))
            .fontSize(13)
            .fontColor(this.theme.textMuted)
            .textAlign(TextAlign.Center)
            .padding({ left: 24, right: 24 })

          Button({ type: ButtonType.Capsule, stateEffect: true }) {
            Row({ space: 6 }) {
              Image($r('app.media.ic_nearlink'))
                .width(16)
                .height(16)
                .fillColor(this.theme.textInverse)
              Text($r('app.string.nearlink_btn_touch_start'))
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.textInverse)
            }
            .padding({ left: 18, right: 18, top: 10, bottom: 10 })
          }
          .backgroundColor(this.theme.primaryAccent)
          .onClick(() => {
            this.triggerTouchSearch();
          })
          .margin({ top: 8 })
        }
        .width('100%')
        .padding(20)
        .alignItems(HorizontalAlign.Center)
      } else if (this.sanctuaryState === NearLinkSanctuaryState.SCANNING) {
        Column({ space: 16 }) {
          Stack({ alignContent: Alignment.Center }) {
            Row()
              .width(90)
              .height(90)
              .borderRadius(45)
              .backgroundColor(this.theme.primaryAccent)
              .opacity(0.15)
              .scale({ x: this.rippleAnimScale, y: this.rippleAnimScale })

            Row()
              .width(60)
              .height(60)
              .borderRadius(30)
              .backgroundColor(this.theme.primaryAccent)
              .opacity(0.25)

            Image($r('app.media.ic_nearlink'))
              .width(32)
              .height(32)
              .fillColor(this.theme.primaryAccent)
          }

          Text($r('app.string.nearlink_scanning'))
            .fontSize(13)
            .fontColor(this.theme.textSecondary)
        }
        .width('100%')
        .padding(28)
        .alignItems(HorizontalAlign.Center)
      } else {
        // CONNECTED or SIMULATED 态
        Column({ space: 14 }) {
          // 双子岛对照视图
          Row({ space: 16 }) {
            // 本机岛
            Column({ space: 6 }) {
              Text('🏝️')
                .fontSize(36)
              Text($r('app.string.nearlink_my_island'))
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.textPrimary)
              Text($r('app.string.nearlink_status_focusing'))
                .fontSize(10)
                .fontColor(this.theme.primaryAccent)
            }
            .padding(12)
            .backgroundColor(this.theme.surfaceLow)
            .borderRadius(14)
            .layoutWeight(1)

            // 中间星闪脉冲
            Column({ space: 2 }) {
              Image($r('app.media.ic_nearlink'))
                .width(24)
                .height(24)
                .fillColor(this.theme.primaryAccent)
              Text($r('app.string.nearlink_status_resonating'))
                .fontSize(10)
                .fontColor(this.theme.textMuted)
            }

            // 伴读岛
            Column({ space: 6 }) {
              Text('🏝️')
                .fontSize(36)
              Text(this.partnerInfo?.islandName ? this.partnerInfo.islandName : $r('app.string.nearlink_partner_default_name'))
                .fontSize(12)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.textPrimary)
              Row({ space: 2 }) {
                Text(this.partnerInfo?.currentTag ? this.partnerInfo.currentTag : $r('app.string.timeisland_tag_read'))
                  .fontSize(10)
                  .fontColor(this.theme.primaryAccent)
                Text(` · ${this.partnerInfo?.partnerFocusMinutes || 25}m`)
                  .fontSize(10)
                  .fontColor(this.theme.primaryAccent)
              }
            }
            .padding(12)
            .backgroundColor(this.theme.surfaceLow)
            .borderRadius(14)
            .layoutWeight(1)
          }
          .width('100%')
          .padding({ left: 16, right: 16 })

          // 微风提示条
          if (this.rippleNotice) {
            Text(this.rippleNotice)
              .fontSize(11)
              .fontColor(this.theme.primaryAccent)
              .padding({ left: 12, right: 12, top: 6, bottom: 6 })
              .backgroundColor(this.theme.surfaceLow)
              .borderRadius(10)
          }

          // 互动按钮条
          Row({ space: 12 }) {
            Button({ type: ButtonType.Capsule, stateEffect: true }) {
              Row({ space: 4 }) {
                Image($r('app.media.ic_air'))
                  .width(14)
                  .height(14)
                  .fillColor(this.theme.textPrimary)
                Text($r('app.string.nearlink_send_ripple'))
                  .fontSize(12)
                  .fontColor(this.theme.textPrimary)
              }
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            }
            .backgroundColor(this.theme.surfaceLow)
            .onClick(() => {
              this.sendBreeze();
            })

            Button({ type: ButtonType.Capsule, stateEffect: true }) {
              Text($r('app.string.nearlink_btn_disconnect'))
                .fontSize(12)
                .fontColor($r('app.color.timeisland_status_danger'))
                .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            }
            .backgroundColor($r('app.color.timeisland_status_danger_bg'))
            .onClick(() => {
              this.disconnect();
            })
          }
          .margin({ top: 8 })
        }
        .width('100%')
        .padding(14)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .backgroundColor(this.theme.surfaceCard)
    .borderRadius(20)
    .border({ width: 1, color: this.theme.borderSubtle })
    .padding({ bottom: 16 })
  }
}
