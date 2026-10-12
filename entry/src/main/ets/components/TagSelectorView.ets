import { FocusTag } from '../model/FocusTypes';

/**
 * 时光岛 - 心流场域与气韵标签选择器 (TagSelectorView)
 * 对齐 Stitch 设计稿: 暗夜微光卡片 + 发光呼吸状态指示点
 */
@Component
export struct TagSelectorView {
  @Prop tags: FocusTag[] = [];
  @Prop selectedTagId: number = 1;
  public onSelectTag: (tag: FocusTag) => void = () => {};

  build() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.timeisland_energy_field_title'))
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.timeisland_text_secondary'))

        Blank()

        Image($r('app.media.ic_spa'))
          .width(16)
          .height(16)
          .fillColor($r('app.color.timeisland_text_muted'))
      }
      .width('100%')
      .padding({ left: 4, right: 4 })

      List({ space: 8 }) {
        ForEach(this.tags, (tag: FocusTag) => {
          ListItem() {
            Row({ space: 6 }) {
              Circle()
                .width(6)
                .height(6)
                .fill(this.selectedTagId === tag.id ? tag.colorHex : $r('app.color.timeisland_text_muted'))
                .shadow(this.selectedTagId === tag.id ? { radius: 6, color: tag.colorHex, offsetY: 0 } : { radius: 0, color: Color.Transparent })

              Text(tag.name)
                .fontSize(12)
                .fontColor(this.selectedTagId === tag.id ? $r('app.color.timeisland_text_primary') : $r('app.color.timeisland_text_secondary'))
                .fontWeight(this.selectedTagId === tag.id ? FontWeight.Medium : FontWeight.Normal)
            }
            .padding({ left: 14, right: 14, top: 7, bottom: 7 })
            .borderRadius(16)
            .backgroundColor(this.selectedTagId === tag.id ? $r('app.color.timeisland_surface_indigo') : $r('app.color.timeisland_surface_low'))
            .border({ width: 1, color: this.selectedTagId === tag.id ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_border_subtle') })
            .animation({ duration: 250, curve: Curve.FastOutSlowIn })
            .onClick(() => {
              this.onSelectTag(tag);
            })
          }
        }, (tag: FocusTag) => tag.id.toString())
      }
      .listDirection(Axis.Horizontal)
      .edgeEffect(EdgeEffect.Spring)
      .width('100%')
      .height(40)
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
          { id: 1, name: '💻 深度编码', colorHex: '#4EDEA3', iconName: 'laptop', isSystem: true },
          { id: 2, name: '📖 哲学阅读', colorHex: '#60A5FA', iconName: 'book', isSystem: true },
          { id: 3, name: '🧘 呼吸冥想', colorHex: '#FBBF24', iconName: 'self_improvement', isSystem: true }
        ],
        selectedTagId: 1
      })
    }
    .padding(16)
    .backgroundColor($r('app.color.timeisland_bg_canvas'))
  }
}
