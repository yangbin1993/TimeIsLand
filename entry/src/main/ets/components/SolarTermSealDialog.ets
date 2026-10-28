import { ThemeMode, ThemePalette } from '../theme/ThemeTypes';
import { themeManager } from '../theme/ThemeManager';
import { soundEffectManager, SoundEffectType } from '../utils/SoundEffectManager';
import { hapticFeedbackHelper } from '../utils/HapticFeedbackHelper';
import { SolarTermItem } from '../utils/SolarTermHelper';

/**
 * 时光岛 - 节气朱印物候详情弹窗 (SolarTermSealDialog)
 * 职责: 展现东方二十四节气朱砂篆刻印章、岁时物候箴言与打卡点亮纪念
 * 风格: 极简东方微晶卡片、朱红印泥印章质感与禅意物候阅读
 */
@Component
export struct SolarTermSealDialog {
  @StorageProp('currentTheme') theme: ThemePalette = themeManager.getPaletteByMode(ThemeMode.DARK);
  @StorageProp('currentThemeMode') currentMode: ThemeMode = ThemeMode.DARK;
  @Prop visible: boolean = false;
  @Prop item: SolarTermItem | null = null;
  @Prop isCurrentTerm: boolean = false;
  @Prop isUnlocked: boolean = false;
  onClose: () => void = () => {};

  private handleClose(): void {
    soundEffectManager.play(SoundEffectType.SWITCH_CLOSE);
    hapticFeedbackHelper.trigger('tick');
    this.onClose();
  }

  build() {
    if (this.visible && this.item) {
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

        // 2. 居中东方朱印卡片
        Column({ space: 16 }) {
          // 2.1 当令标识与节气名称
          Row({ space: 8 }) {
            Text(this.item.nameRes)
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.textPrimary)

            if (this.isCurrentTerm) {
              Text($r('app.string.biome_seal_current_term'))
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.primaryAccent)
                .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                .backgroundColor(this.theme.surfaceLow)
                .borderRadius(6)
                .border({ width: 1, color: this.theme.primaryAccent })
            }
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)

          // 2.2 核心朱红篆刻印章实体 (Square Cinnabar Seal)
          Stack() {
            Column({ space: 4 }) {
              Text(this.item.sealRes)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.timeisland_seal_gold'))
                .letterSpacing(4)
                .textAlign(TextAlign.Center)
            }
            .width(130)
            .height(130)
            .justifyContent(FlexAlign.Center)
            .backgroundColor($r('app.color.timeisland_seal_cinnabar'))
            .borderRadius(14)
            .border({ width: 3, color: $r('app.color.timeisland_seal_gold_border'), radius: 14 })
            .shadow({ radius: 16, color: $r('app.color.timeisland_seal_shadow'), offsetY: 4 })
          }
          .padding({ top: 6, bottom: 6 })

          // 2.3 物候诗语典籍
          Column({ space: 6 }) {
            Text(this.item.poemRes)
              .fontSize(13)
              .fontColor(this.theme.textSecondary)
              .lineHeight(20)
              .textAlign(TextAlign.Center)
              .fontStyle(FontStyle.Italic)
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .backgroundColor(this.theme.surfaceLow)
          .borderRadius(12)
          .border({ width: 1, color: this.theme.borderSubtle })

          // 2.4 点亮状态指示
          Row({ space: 6 }) {
            Text(this.isUnlocked ? '★' : '☆')
              .fontSize(14)
              .fontColor(this.isUnlocked ? this.theme.primaryAccent : this.theme.textMuted)

            Text(this.isUnlocked ? $r('app.string.biome_seal_dialog_unlocked') : $r('app.string.biome_seal_dialog_locked'))
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.isUnlocked ? this.theme.primaryAccent : this.theme.textMuted)
          }
          .padding({ left: 12, right: 12, top: 4, bottom: 4 })
          .backgroundColor(this.theme.surfaceLowest)
          .borderRadius(12)

          // 2.5 封存印记按钮
          Button({ type: ButtonType.Capsule, stateEffect: true }) {
            Text($r('app.string.biome_seal_dialog_btn_close'))
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.theme.textInverse)
          }
          .width('100%')
          .height(40)
          .backgroundColor(this.theme.primaryAccent)
          .shadow({ radius: 10, color: this.theme.primaryGlow, offsetY: 2 })
          .onClick(() => {
            this.handleClose();
          })
        }
        .width('85%')
        .constraintSize({ maxWidth: 360 })
        .padding(22)
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
