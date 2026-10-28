import { DialogHelper } from '@app/common';
import { ThemeMode, ThemePalette } from '../theme/ThemeTypes';
import { themeManager } from '../theme/ThemeManager';
import { soundEffectManager, SoundEffectType } from '../utils/SoundEffectManager';
import { hapticFeedbackHelper } from '../utils/HapticFeedbackHelper';
import { timeIslandRepository, RestoreResult } from '../data/TimeIslandRepository';

/**
 * 时光岛 - 专注历史数据恢复弹窗 (DataRestoreDialog)
 * 职责: 支持用户粘贴此前导出的 JSON 备份，完成离线沙箱数据去重还原
 * 风格: 极简东方禅意微晶视窗、自适应主题与零权限合规安全粘贴
 */
@Component
export struct DataRestoreDialog {
  @StorageProp('currentTheme') theme: ThemePalette = themeManager.getPaletteByMode(ThemeMode.DARK);
  @StorageProp('currentThemeMode') currentMode: ThemeMode = ThemeMode.DARK;
  @Prop visible: boolean = false;
  onClose: () => void = () => {};
  onRestoreSuccess: (importedCount: number, skippedCount: number) => void = () => {};

  @State private jsonInput: string = '';
  @State private isProcessing: boolean = false;

  private handleClose(): void {
    soundEffectManager.play(SoundEffectType.SWITCH_CLOSE);
    this.jsonInput = '';
    this.isProcessing = false;
    this.onClose();
  }

  private async handleRestore(): Promise<void> {
    if (this.isProcessing) {
      return;
    }

    const trimmed = this.jsonInput.trim();
    if (trimmed.length === 0) {
      soundEffectManager.play(SoundEffectType.SWITCH_CLOSE);
      hapticFeedbackHelper.trigger('warning');
      DialogHelper.showToast($r('app.string.settings_data_import_err_empty'));
      return;
    }

    this.isProcessing = true;
    try {
      const res: RestoreResult = await timeIslandRepository.restoreRecordsFromJson(trimmed);
      if (!res.success) {
        soundEffectManager.play(SoundEffectType.SWITCH_CLOSE);
        hapticFeedbackHelper.trigger('warning');
        DialogHelper.showToast($r('app.string.settings_data_import_err_format'));
        return;
      }

      hapticFeedbackHelper.trigger('complete');
      soundEffectManager.play(SoundEffectType.BUBBLE);
      DialogHelper.showToast($r('app.string.settings_data_import_success'));
      this.onRestoreSuccess(res.importedCount, res.skippedCount);
      this.handleClose();
    } catch (_err) {
      DialogHelper.showToast($r('app.string.settings_data_import_err_format'));
    } finally {
      this.isProcessing = false;
    }
  }

  build() {
    if (this.visible) {
      Stack({ alignContent: Alignment.Center }) {
        // 1. 半透明微晶全屏遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.currentMode === ThemeMode.LIGHT ? $r('app.color.timeisland_dialog_mask_light') : $r('app.color.timeisland_dialog_mask_dark'))
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .onClick(() => {
            this.handleClose();
          })

        // 2. 居中东方禅意数据恢复卡片
        Column({ space: 16 }) {
          // 2.1 标题区
          Column({ space: 4 }) {
            Text($r('app.string.settings_data_import_dialog_title'))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.textPrimary)

            Text($r('app.string.settings_data_import_dialog_subtitle'))
              .fontSize(12)
              .fontColor(this.theme.textSecondary)
              .textAlign(TextAlign.Center)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          // 2.2 JSON 备份内容粘贴区
          Column({ space: 6 }) {
            TextArea({
              text: this.jsonInput,
              placeholder: $r('app.string.settings_data_import_dialog_placeholder')
            })
              .height(130)
              .width('100%')
              .fontSize(12)
              .fontColor(this.theme.textPrimary)
              .placeholderColor(this.theme.textMuted)
              .backgroundColor(this.theme.surfaceLow)
              .borderRadius(12)
              .border({ width: 1, color: this.theme.borderSubtle, radius: 12 })
              .padding(10)
              .onChange((val: string) => {
                this.jsonInput = val;
              })
          }
          .width('100%')

          // 2.3 操作按钮组 (取消 / 验证并恢复)
          Row({ space: 12 }) {
            // 取消按钮
            Row() {
              Text($r('app.string.settings_data_import_dialog_cancel'))
                .fontSize(14)
                .fontColor(this.theme.textSecondary)
            }
            .layoutWeight(1)
            .height(40)
            .justifyContent(FlexAlign.Center)
            .borderRadius(20)
            .border({ width: 1, color: this.theme.borderSubtle, radius: 20 })
            .backgroundColor(this.theme.surfaceLow)
            .onClick(() => {
              this.handleClose();
            })

            // 验证并恢复按钮
            Row() {
              Text(this.isProcessing ? '...' : $r('app.string.settings_data_import_dialog_confirm'))
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.textInverse)
            }
            .layoutWeight(1)
            .height(40)
            .justifyContent(FlexAlign.Center)
            .borderRadius(20)
            .backgroundColor(this.theme.primaryAccent)
            .shadow({ radius: 10, color: this.theme.primaryGlow, offsetY: 2 })
            .enabled(!this.isProcessing)
            .onClick(() => {
              this.handleRestore();
            })
          }
          .width('100%')
          .padding({ top: 4 })
        }
        .width('88%')
        .constraintSize({ maxWidth: 420 })
        .padding(20)
        .backgroundColor(this.theme.surfaceCard)
        .borderRadius(20)
        .border({ width: 1, color: this.theme.borderCard, radius: 20 })
        .shadow({ radius: 24, color: this.theme.shadowCard, offsetY: 6 })
      }
      .width('100%')
      .height('100%')
      .zIndex(999)
    }
  }
}
