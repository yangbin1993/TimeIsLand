import { ThemeMode, ThemePalette } from '../theme/ThemeTypes';
import { themeManager } from '../theme/ThemeManager';
import { soundEffectManager, SoundEffectType } from '../utils/SoundEffectManager';
import { hapticFeedbackHelper } from '../utils/HapticFeedbackHelper';

/**
 * 气韵星级选项模型
 */
interface RatingOption {
  level: number;
  labelRes: Resource;
}

/**
 * 时光岛 - 心流随笔与打卡复盘弹窗 (FocusReflectionDialog)
 * 职责: 专注结夏归零或心流漫游结束时唤起，支持一句话记录灵感与心流气韵自评
 * 风格: 东方禅意微晶卡片，气韵五星律动，极简磨砂视窗
 */
@Component
export struct FocusReflectionDialog {
  @StorageProp('currentTheme') theme: ThemePalette = themeManager.getPaletteByMode(ThemeMode.DARK);
  @StorageProp('currentThemeMode') currentMode: ThemeMode = ThemeMode.DARK;
  @StorageProp('bottomNavHeight') bottomNavHeight: number = 0;
  @Prop visible: boolean = false;
  @Prop recordId: number = 0;
  onSave: (recordId: number, note: string, rating: number) => void = () => {};
  onSkip: () => void = () => {};

  @State private selectedRating: number = 5;
  @State private noteText: string = '';

  private readonly ratingOptions: RatingOption[] = [
    { level: 1, labelRes: $r('app.string.reflection_dialog_rating_1') },
    { level: 2, labelRes: $r('app.string.reflection_dialog_rating_2') },
    { level: 3, labelRes: $r('app.string.reflection_dialog_rating_3') },
    { level: 4, labelRes: $r('app.string.reflection_dialog_rating_4') },
    { level: 5, labelRes: $r('app.string.reflection_dialog_rating_5') }
  ];

  private getRatingLabel(level: number): Resource {
    for (let i = 0; i < this.ratingOptions.length; i++) {
      if (this.ratingOptions[i].level === level) {
        return this.ratingOptions[i].labelRes;
      }
    }
    return $r('app.string.reflection_dialog_rating_5');
  }

  private handleSelectRating(level: number): void {
    this.selectedRating = level;
    soundEffectManager.play(SoundEffectType.PEN_CLICK);
    hapticFeedbackHelper.trigger('tick');
  }

  private handleSave(): void {
    soundEffectManager.play(SoundEffectType.SWITCH_CLOSE);
    hapticFeedbackHelper.trigger('complete');
    this.onSave(this.recordId, this.noteText.trim(), this.selectedRating);
    this.noteText = '';
    this.selectedRating = 5;
  }

  private handleSkip(): void {
    soundEffectManager.play(SoundEffectType.SWITCH_CLOSE);
    this.onSkip();
    this.noteText = '';
    this.selectedRating = 5;
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
            this.handleSkip();
          })

        // 2. 居中东方禅意微晶复盘卡片
        Column({ space: 16 }) {
          // 2.1 标题区
          Column({ space: 4 }) {
            Text($r('app.string.reflection_dialog_title'))
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.textPrimary)

            Text($r('app.string.reflection_dialog_subtitle'))
              .fontSize(12)
              .fontColor(this.theme.textSecondary)
          }
          .width('100%')
          .alignItems(HorizontalAlign.Center)

          // 2.2 心流气韵评分 (五星连珠 + 意象词)
          Column({ space: 8 }) {
            Row() {
              Text($r('app.string.reflection_dialog_rating_label'))
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.textPrimary)
              Blank()
              Text(this.getRatingLabel(this.selectedRating))
                .fontSize(13)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.theme.primaryAccent)
            }
            .width('100%')

            Row({ space: 12 }) {
              ForEach(this.ratingOptions, (item: RatingOption) => {
                Column({ space: 4 }) {
                  Text(item.level <= this.selectedRating ? '★' : '☆')
                    .fontSize(28)
                    .fontColor(item.level <= this.selectedRating ? this.theme.primaryAccent : this.theme.borderSubtle)
                    .animation({ duration: 200 })

                  Text(item.labelRes)
                    .fontSize(10)
                    .fontColor(item.level === this.selectedRating ? this.theme.primaryAccent : this.theme.textMuted)
                }
                .layoutWeight(1)
                .alignItems(HorizontalAlign.Center)
                .onClick(() => {
                  this.handleSelectRating(item.level);
                })
              }, (item: RatingOption) => item.level.toString())
            }
            .width('100%')
            .padding({ top: 4, bottom: 4 })
          }
          .width('100%')
          .padding(12)
          .backgroundColor(this.theme.surfaceLow)
          .borderRadius(14)
          .border({ width: 1, color: this.theme.borderSubtle })

          // 2.3 当下一悟 · 随笔输入区
          Column({ space: 6 }) {
            Row() {
              Text($r('app.string.reflection_dialog_note_label'))
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.textPrimary)
              Blank()
              Text(`${this.noteText.length}/100`)
                .fontSize(11)
                .fontColor(this.theme.textMuted)
            }
            .width('100%')

            TextArea({
              text: this.noteText,
              placeholder: $r('app.string.reflection_dialog_note_placeholder')
            })
              .height(84)
              .width('100%')
              .fontSize(13)
              .maxLength(100)
              .fontColor(this.theme.textPrimary)
              .placeholderColor(this.theme.textMuted)
              .backgroundColor(this.theme.surfaceLow)
              .borderRadius(12)
              .border({ width: 1, color: this.theme.borderSubtle, radius: 12 })
              .padding(10)
              .onChange((val: string) => {
                this.noteText = val;
              })
          }
          .width('100%')

          // 2.4 操作按钮组 (稍后再记 / 封存心流)
          Row({ space: 12 }) {
            // 稍后再记
            Row() {
              Text($r('app.string.reflection_dialog_btn_skip'))
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
              this.handleSkip();
            })

            // 封存心流
            Row() {
              Text($r('app.string.reflection_dialog_btn_save'))
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
            .onClick(() => {
              this.handleSave();
            })
          }
          .width('100%')
          .padding({ top: 4 })
        }
        .width('88%')
        .constraintSize({ maxWidth: 400 })
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
