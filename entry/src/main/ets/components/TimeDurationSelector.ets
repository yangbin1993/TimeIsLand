import { ThemePalette, ThemeMode } from '../theme/ThemeTypes';
import { themeManager } from '../theme/ThemeManager';
import { soundEffectManager, SoundEffectType } from '../utils/SoundEffectManager';

interface DurationItem {
  mins: number;
  labelRes: Resource;
}

/**
 * 时光岛 - 水滴鹅卵石心流挡位选择器 (TimeDurationSelector)
 * 1:1 还原 Stitch 设计稿: 鹅卵石水滴胶囊 (Duration Pebbles) + 触感微晶高光
 */
@Component
export struct TimeDurationSelector {
  @StorageProp('currentTheme') theme: ThemePalette = themeManager.getPaletteByMode(ThemeMode.DARK);
  @Prop selectedMinutes: number = 25;
  @Prop disabled: boolean = false;
  public onSelectMinutes: (minutes: number) => void = () => {};

  private readonly durationItems: DurationItem[] = [
    { mins: 15, labelRes: $r('app.string.timeisland_duration_15_label') },
    { mins: 25, labelRes: $r('app.string.timeisland_duration_25_label') },
    { mins: 45, labelRes: $r('app.string.timeisland_duration_45_label') },
    { mins: 60, labelRes: $r('app.string.timeisland_duration_60_label') }
  ];

  build() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.timeisland_duration_title'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textSecondary)

        Blank()

        Text($r('app.string.timeisland_duration_cycle'))
          .fontSize(11)
          .fontColor(this.theme.textMuted)
      }
      .width('100%')
      .padding({ left: 4, right: 4 })

      Row({ space: 6 }) {
        ForEach(this.durationItems, (item: DurationItem) => {
          Button({ type: ButtonType.Normal, stateEffect: !this.disabled }) {
            Column({ space: 1 }) {
              Text(`${item.mins}m`)
                .fontSize(13)
                .fontWeight(this.selectedMinutes === item.mins ? FontWeight.Bold : FontWeight.Medium)
                .fontColor(this.selectedMinutes === item.mins ? this.theme.textPrimary : this.theme.textSecondary)

              Text(item.labelRes)
                .fontSize(9)
                .fontColor(this.selectedMinutes === item.mins ? this.theme.primaryAccent : this.theme.textMuted)
            }
            .justifyContent(FlexAlign.Center)
            .width('100%')
            .height('100%')
          }
          .layoutWeight(1)
          .height(42)
          .borderRadius(14)
          .backgroundColor(this.selectedMinutes === item.mins ? this.theme.surfaceIndigo : this.theme.surfaceCard)
          .border({
            width: this.selectedMinutes === item.mins ? 1.5 : 1,
            color: this.selectedMinutes === item.mins ? this.theme.primaryAccent : this.theme.borderSubtle
          })
          .shadow(this.selectedMinutes === item.mins ? {
            radius: 12,
            color: this.theme.primaryGlow,
            offsetY: 2
          } : { radius: 0, color: Color.Transparent })
          .opacity(this.disabled ? 0.4 : 1.0)
          .onClick(() => {
            if (!this.disabled) {
              soundEffectManager.play(SoundEffectType.PEN_CLICK);
              this.onSelectMinutes(item.mins);
            }
          })
        }, (item: DurationItem) => item.mins.toString())

        // 自定义刻度按钮
        Button({ type: ButtonType.Normal, stateEffect: !this.disabled }) {
          Column({ space: 2 }) {
            Image($r('app.media.ic_tune'))
              .width(14)
              .height(14)
              .fillColor(this.theme.textSecondary)
            Text($r('app.string.timeisland_duration_custom'))
              .fontSize(9)
              .fontColor(this.theme.textSecondary)
          }
          .justifyContent(FlexAlign.Center)
          .width('100%')
          .height('100%')
        }
        .layoutWeight(0.9)
        .height(42)
        .borderRadius(14)
        .backgroundColor(this.theme.surfaceCard)
        .border({ width: 1, color: this.theme.borderSubtle })
        .opacity(this.disabled ? 0.4 : 1.0)
      }
      .width('100%')
      .padding(4)
      .backgroundColor(this.theme.surfaceLowest)
      .borderRadius(18)
      .border({ width: 1, color: this.theme.borderSubtle })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }
}

/**
 * 专注刻度胶囊选择器独立预览组件
 */
@Preview
@Component
struct TimeDurationSelectorPreview {
  build() {
    Column() {
      TimeDurationSelector({
        selectedMinutes: 25,
        disabled: false
      })
    }
    .padding(16)
    .backgroundColor($r('app.color.timeisland_bg_canvas'))
  }
}
