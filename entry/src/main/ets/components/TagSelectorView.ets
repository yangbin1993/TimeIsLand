import { FocusTag } from '../model/FocusTypes';
import { ThemePalette, ThemeMode } from '../theme/ThemeTypes';
import { themeManager } from '../theme/ThemeManager';
import { soundEffectManager, SoundEffectType } from '../utils/SoundEffectManager';

/**
 * 时光岛 - 心流场域与气韵标签选择器 (TagSelectorView)
 * 1:1 还原 Stitch 触感按键系统: 触感微晶水滴胶囊 + 呼吸状态发光点
 */
@Component
export struct TagSelectorView {
  @StorageProp('currentTheme') theme: ThemePalette = themeManager.getPaletteByMode(ThemeMode.DARK);
  @Prop tags: FocusTag[] = [];
  @Prop selectedTagId: number = 1;
  public onSelectTag: (tag: FocusTag) => void = () => {};

  build() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.timeisland_energy_field_title'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.theme.textSecondary)

        Blank()

        Image($r('app.media.ic_spa'))
          .width(16)
          .height(16)
          .fillColor(this.theme.textMuted)
      }
      .width('100%')
      .padding({ left: 4, right: 4 })

      List({ space: 8 }) {
        ForEach(this.tags, (tag: FocusTag) => {
          ListItem() {
            Row({ space: 6 }) {
              // 状态微光呼吸点 (避免 Circle.fill API 警告)
              Row()
                .width(6)
                .height(6)
                .borderRadius(3)
                .backgroundColor(this.selectedTagId === tag.id ? tag.colorHex : this.theme.textMuted)
                .shadow(this.selectedTagId === tag.id ? { radius: 8, color: tag.colorHex, offsetY: 0 } : { radius: 0, color: Color.Transparent })

              Text(tag.name)
                .fontSize(12)
                .fontColor(this.selectedTagId === tag.id ? this.theme.textPrimary : this.theme.textSecondary)
                .fontWeight(this.selectedTagId === tag.id ? FontWeight.Bold : FontWeight.Normal)
            }
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .borderRadius(16)
            .backgroundColor(this.selectedTagId === tag.id ? this.theme.surfaceIndigo : this.theme.surfaceCard)
            .border({
              width: 1,
              color: this.selectedTagId === tag.id ? tag.colorHex : this.theme.borderSubtle
            })
            .shadow(this.selectedTagId === tag.id ? {
              radius: 12,
              color: this.theme.primaryGlow,
              offsetY: 2
            } : { radius: 0, color: Color.Transparent })
            .animation({ duration: 250, curve: Curve.FastOutSlowIn })
            .onClick(() => {
              soundEffectManager.play(SoundEffectType.BUBBLE);
              this.onSelectTag(tag);
            })
          }
        }, (tag: FocusTag) => tag.id.toString())
      }
      .listDirection(Axis.Horizontal)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .height(42)
    }
    .width('100%')
  }
}

/**
 * 心流场域标签独立预览组件
 */
@Preview
@Component
struct TagSelectorViewPreview {
  build() {
    Column() {
      TagSelectorView({
        tags: [
          { id: 1, name: '💻 工作', colorHex: '#4EDEA3', iconName: 'laptop', isSystem: true },
          { id: 2, name: '📖 阅读', colorHex: '#60A5FA', iconName: 'book', isSystem: true },
          { id: 3, name: '🧘 冥想', colorHex: '#FBBF24', iconName: 'self_improvement', isSystem: true }
        ],
        selectedTagId: 1
      })
    }
    .padding(16)
    .backgroundColor($r('app.color.timeisland_bg_canvas'))
  }
}
