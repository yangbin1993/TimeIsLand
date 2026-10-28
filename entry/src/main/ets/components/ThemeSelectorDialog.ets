import { DialogHelper } from '@app/common';
import { ThemeMode, ThemeOption, ThemePalette } from '../theme/ThemeTypes';
import { themeManager } from '../theme/ThemeManager';
import { soundEffectManager, SoundEffectType } from '../utils/SoundEffectManager';

/**
 * 时光岛 - 生境主题工坊与触感按键选择面板 (ThemeSelectorDialog)
 * 1:1 还原 Stitch 高保真设计: 奢华磨砂玻璃卡片、双色流体发光微球与按键质感色彩矩阵
 */
@Component
export struct ThemeSelectorDialog {
  @StorageProp('currentTheme') theme: ThemePalette = themeManager.getPaletteByMode(ThemeMode.DARK);
  @StorageProp('currentThemeMode') currentMode: ThemeMode = ThemeMode.DARK;
  @StorageProp('bottomNavHeight') bottomNavHeight: number = 0;
  @Prop visible: boolean = false;
  onClose: () => void = () => {};

  private themeOptions: ThemeOption[] = themeManager.getThemeOptions();

  build() {
    if (this.visible) {
      Stack({ alignContent: Alignment.Bottom }) {
        // 半透明微光全屏遮罩 (无缝覆盖整屏包括顶部状态栏与底部手势条)
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.currentMode === ThemeMode.LIGHT ? $r('app.color.timeisland_dialog_mask_light') : $r('app.color.timeisland_dialog_mask_dark'))
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .onClick(() => {
            this.onClose();
          })

        // 浮层主工坊卡片面板 (跟随当前 theme 响应式实时换肤)
        Column({ space: 14 }) {
          // 顶部阻尼手柄
          Column()
            .width(40)
            .height(4)
            .backgroundColor(this.theme.borderSubtle)
            .borderRadius(2)
            .margin({ top: 8, bottom: 2 })

          // 标题栏与关闭触发钮
          Row() {
            Column({ space: 3 }) {
              Row({ space: 6 }) {
                Text($r('app.string.timeisland_theme_title'))
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.theme.textPrimary)
                Text($r('app.string.timeisland_theme_badge'))
                  .fontSize(10)
                  .fontWeight(FontWeight.Normal)
                  .fontColor(this.theme.primaryAccent)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .backgroundColor(this.theme.primaryAccentBg)
                  .borderRadius(6)
              }

              Text($r('app.string.timeisland_theme_preview_subtitle'))
                .fontSize(11)
                .fontColor(this.theme.textMuted)
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Button({ type: ButtonType.Circle, stateEffect: true }) {
              Image($r('app.media.ic_close'))
                .width(18)
                .height(18)
                .fillColor(this.theme.textSecondary)
            }
            .width(32)
            .height(32)
            .backgroundColor(this.theme.surfaceLow)
            .border({ width: 1, color: this.theme.borderSubtle })
            .onClick(() => {
              this.onClose();
            })
          }
          .width('100%')
          .padding({ left: 4, right: 4 })

          // 主题奢华卡片列表 (按 Stitch 规范重构)
          Scroll() {
            Column({ space: 10 }) {
              ForEach(this.themeOptions, (opt: ThemeOption) => {
                this.buildThemeCard(opt)
              }, (opt: ThemeOption) => opt.mode)
            }
            .width('100%')
          }
          .scrollBar(BarState.Off)
          .constraintSize({ maxHeight: '60%' })
        }
        .width('100%')
        .padding({
          left: 16,
          right: 16,
          top: 6,
          bottom: 24 + (this.bottomNavHeight > 0 ? this.bottomNavHeight : 0)
        })
        .backgroundColor(this.theme.surfaceCard)
        .borderRadius({ topLeft: 24, topRight: 24 })
        .border({ width: { top: 1 }, color: this.theme.borderCard })
        .shadow({ radius: 36, color: this.theme.shadowModal, offsetY: -8 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      }
      .width('100%')
      .height('100%')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
      .animation({ duration: 250, curve: Curve.FastOutSlowIn })
    }
  }

  /**
   * Stitch 奢华磨砂玻璃生境主题卡片
   */
  @Builder
  private buildThemeCard(opt: ThemeOption) {
    Stack({ alignContent: Alignment.TopEnd }) {
      Column({ space: 10 }) {
        // 卡片上半部: 发光微球 + 文字说明
        Row() {
          // 1. 双色流体发光微球 (Dual-tone Bioluminescent Liquid Orb)
          Stack({ alignContent: Alignment.Center }) {
            // 微球底槽
            Row()
              .width(42)
              .height(42)
              .borderRadius(14)
              .backgroundColor(opt.canvasPreviewColor)
              .border({ width: 1, color: this.currentMode === opt.mode ? opt.primaryPreviewColor : this.theme.borderSubtle })

            // 外晕层
            Row()
              .width(22)
              .height(22)
              .borderRadius(11)
              .backgroundColor(opt.secondaryPreviewColor)
              .opacity(0.4)
              .margin({ left: 6, top: 6 })

            // 核心发光珠
            Row()
              .width(18)
              .height(18)
              .borderRadius(9)
              .backgroundColor(opt.primaryPreviewColor)
              .shadow({ radius: 10, color: opt.primaryPreviewColor, offsetY: 0 })
          }
          .margin({ right: 12 })

          // 2. 主题标题与诗意注脚
          Column({ space: 3 }) {
            Text(opt.nameRes)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.currentMode === opt.mode ? opt.primaryPreviewColor : this.theme.textPrimary)

            Text(opt.descRes)
              .fontSize(11)
              .fontColor(this.theme.textMuted)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
        }
        .width('100%')

        // 卡片下半部: Stitch 按键质感色彩矩阵 (Texture Swatches)
        Row() {
          Text($r('app.string.timeisland_theme_swatches_label'))
            .fontSize(10)
            .fontColor(this.theme.textMuted)
            .fontWeight(FontWeight.Medium)

          Blank()

          Row({ space: 8 }) {
            // 胶囊主按键微缩渐变条
            Row()
              .width(26)
              .height(10)
              .borderRadius(5)
              .linearGradient({
                angle: 90,
                colors: [[opt.swatchGradientStart, 0.0], [opt.swatchGradientEnd, 1.0]]
              })
              .shadow({ radius: 6, color: opt.primaryPreviewColor, offsetY: 0 })

            // 圆盘按键边缘环
            Row()
              .width(12)
              .height(12)
              .borderRadius(6)
              .backgroundColor(opt.canvasPreviewColor)
              .border({ width: 1.5, color: opt.dialDiscBorder })

            // 核心微亮点
            Row()
              .width(8)
              .height(8)
              .borderRadius(4)
              .backgroundColor(opt.coreToneColor)
          }
        }
        .width('100%')
        .padding({ left: 10, right: 10, top: 6, bottom: 6 })
        .backgroundColor(this.theme.surfaceLow)
        .borderRadius(10)
        .border({ width: 1, color: this.theme.borderSubtle })
      }
      .width('100%')
      .padding(14)
      .borderRadius(16)
      .backgroundColor(this.currentMode === opt.mode ? this.theme.surfaceIndigo : this.theme.surfaceLowest)
      .border({
        width: 1,
        color: this.currentMode === opt.mode ? opt.primaryPreviewColor : this.theme.borderSubtle
      })
      .shadow({
        radius: this.currentMode === opt.mode ? 16 : 4,
        color: this.currentMode === opt.mode ? opt.primaryPreviewColor : this.theme.shadowCard,
        offsetY: 2
      })
      .onClick(async () => {
        soundEffectManager.play(SoundEffectType.BUBBLE);
        await themeManager.setThemeMode(opt.mode);
        DialogHelper.showToast($r('app.string.timeisland_theme_switched_toast'));
      })

      // 右上角激活态发光微徽章
      if (this.currentMode === opt.mode) {
        Row() {
          Image($r('app.media.ic_check'))
            .width(12)
            .height(12)
            .fillColor(this.theme.textInverse)
        }
        .width(20)
        .height(20)
        .borderRadius(10)
        .backgroundColor(opt.primaryPreviewColor)
        .justifyContent(FlexAlign.Center)
        .margin({ top: 12, right: 12 })
        .shadow({ radius: 8, color: opt.primaryPreviewColor, offsetY: 0 })
      }
    }
    .width('100%')
  }
}

