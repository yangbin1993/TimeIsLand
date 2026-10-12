import { FocusTag } from '../model/FocusTypes';

/**
 * 专注标签横向胶囊切换选择器
 */
@Component
export struct TagSelectorView {
  @Prop tags: FocusTag[] = [];
  @Prop selectedTagId: number = 1;
  public onSelectTag: (tag: FocusTag) => void = () => {};

  build() {
    Column({ space: 8 }) {
      Row() {
        Text($r('app.string.timeisland_tag_title'))
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
      }
      .width('100%')
      .padding({ left: 16, right: 16 })

      List({ space: 10 }) {
        ForEach(this.tags, (tag: FocusTag) => {
          ListItem() {
            Row({ space: 6 }) {
              Circle()
                .width(8)
                .height(8)
                .fill(tag.colorHex)

              Text(tag.name)
                .fontSize(13)
                .fontColor(this.selectedTagId === tag.id ? '#FFFFFF' : '#333333')
                .fontWeight(this.selectedTagId === tag.id ? FontWeight.Bold : FontWeight.Regular)
            }
            .padding({ left: 14, right: 14, top: 8, bottom: 8 })
            .borderRadius(18)
            .backgroundColor(this.selectedTagId === tag.id ? tag.colorHex : '#F2F4F7')
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
      .height(44)
      .padding({ left: 16, right: 16 })
    }
    .width('100%')
  }
}
