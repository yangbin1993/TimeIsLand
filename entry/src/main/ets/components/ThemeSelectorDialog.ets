import { DialogHelper } from '@app/common';
import { ThemeMode, ThemeOption } from '../theme/ThemeTypes';
import { themeManager } from '../theme/ThemeManager';

/**
 * 时光岛 - 生境主题流转切换弹窗面板 (ThemeSelectorDialog)
 * 极致禅意流光质感，支持深潜暗夜、晨曦浅金、青苔雨林、纯净晨曦与系统跟随
 */
@Component
export struct ThemeSelectorDialog {
  @StorageProp('currentThemeMode') currentMode: ThemeMode = ThemeMode.DARK;
  @Prop visible: boolean = false;
  onClose: () => void = () => {};

  private themeOptions: ThemeOption[] = themeManager.getThemeOptions();

  build() {
    if (this.visible) {
      Stack({ alignContent: Alignment.Bottom }) {
        // 半透明暗光遮罩
        Rect()
          .width('100%')
          .height('100%')
          .fill('#80000000')
          .onClick(() => {
            this.onClose();
          })

        // 浮层主卡片面板
        Column({ space: 16 }) {
          // 顶部拖拽手柄
          Column()
            .width(36)
            .height(4)
            .backgroundColor('#334155')
            .borderRadius(2)
            .margin({ top: 8, bottom: 4 })

          // 标题与关闭按钮
          Row() {
            Column({ space: 2 }) {
              Text($r('app.string.timeisland_theme_title'))
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.timeisland_text_primary'))
              Text('BIOME PALETTES')
                .fontSize(9)
                .fontWeight(FontWeight.Lighter)
                .fontColor($r('app.color.timeisland_text_muted'))
                .letterSpacing(1.5)
            }
            .alignItems(HorizontalAlign.Start)

            Blank()

            Button({ type: ButtonType.Circle, stateEffect: true }) {
              Image($r('app.media.ic_close'))
                .width(18)
                .height(18)
                .fillColor($r('app.color.timeisland_text_secondary'))
            }
            .width(32)
            .height(32)
            .backgroundColor($r('app.color.timeisland_surface_low'))
            .onClick(() => {
              this.onClose();
            })
          }
          .width('100%')
          .padding({ left: 4, right: 4 })

          // 主题选项列表
          Column({ space: 10 }) {
            ForEach(this.themeOptions, (opt: ThemeOption) => {
              Row() {
                // 1. 色彩双色意境微光圆球
                Stack({ alignContent: Alignment.Center }) {
                  Circle()
                    .width(36)
                    .height(36)
                    .fill(opt.canvasPreviewColor)
                    .border({ width: 1.5, color: '#334155' })

                  Circle()
                    .width(16)
                    .height(16)
                    .fill(opt.primaryPreviewColor)
                    .shadow({ radius: 8, color: opt.primaryPreviewColor, offsetY: 0 })
                }
                .margin({ right: 12 })

                // 2. 模式名称与诗意描述
                Column({ space: 3 }) {
                  Text(opt.nameRes)
                    .fontSize(14)
                    .fontWeight(FontWeight.Medium)
                    .fontColor(this.currentMode === opt.mode ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_text_primary'))

                  Text(opt.descRes)
                    .fontSize(11)
                    .fontColor($r('app.color.timeisland_text_muted'))
                }
                .alignItems(HorizontalAlign.Start)
                .layoutWeight(1)

                // 3. 选中指示态
                if (this.currentMode === opt.mode) {
                  Image($r('app.media.ic_check'))
                    .width(18)
                    .height(18)
                    .fillColor($r('app.color.timeisland_emerald'))
                }
              }
              .width('100%')
              .padding({ left: 14, right: 14, top: 12, bottom: 12 })
              .borderRadius(14)
              .backgroundColor(this.currentMode === opt.mode ? $r('app.color.timeisland_surface_indigo') : $r('app.color.timeisland_surface_low'))
              .border({
                width: 1,
                color: this.currentMode === opt.mode ? $r('app.color.timeisland_emerald') : $r('app.color.timeisland_border_subtle')
              })
              .onClick(async () => {
                await themeManager.setThemeMode(opt.mode);
                DialogHelper.showToast($r('app.string.timeisland_theme_switched_toast'));
              })
            }, (opt: ThemeOption) => opt.mode)
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 8, bottom: 28 })
        .backgroundColor($r('app.color.timeisland_surface_card'))
        .borderRadius({ topLeft: 24, topRight: 24 })
        .border({ width: { top: 1 }, color: $r('app.color.timeisland_border_card') })
        .shadow({ radius: 30, color: $r('app.color.timeisland_shadow_modal'), offsetY: -6 })
      }
      .width('100%')
      .height('100%')
      .animation({ duration: 250, curve: Curve.FastOutSlowIn })
    }
  }
}
