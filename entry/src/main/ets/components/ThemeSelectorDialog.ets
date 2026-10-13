import { DialogHelper } from '@app/common';
import { ThemeMode, ThemeOption } from '../theme/ThemeTypes';
import { themeManager } from '../theme/ThemeManager';
import { soundEffectManager, SoundEffectType } from '../utils/SoundEffectManager';

/**
 * 时光岛 - 生境主题工坊与触感按键选择面板 (ThemeSelectorDialog)
 * 1:1 还原 Stitch 高保真设计: 奢华磨砂玻璃卡片、双色流体发光微球与按键质感色彩矩阵
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
        // 半透明暗夜微光遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor('#99050810')
          .onClick(() => {
            this.onClose();
          })

        // 浮层主工坊卡片面板
        Column({ space: 14 }) {
          // 顶部阻尼手柄
          Column()
            .width(40)
            .height(4)
            .backgroundColor('#334155')
            .borderRadius(2)
            .margin({ top: 8, bottom: 2 })

          // 标题栏与关闭触发钮
          Row() {
            Column({ space: 3 }) {
              Row({ space: 6 }) {
                Text($r('app.string.timeisland_theme_title'))
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#F8FAFC')
                Text('BIOME PALETTES')
                  .fontSize(9)
                  .fontWeight(FontWeight.Lighter)
                  .fontColor('#38BDF8')
                  .letterSpacing(1.2)
                  .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                  .backgroundColor('#1038BDF8')
                  .borderRadius(6)
              }

              Text($r('app.string.timeisland_theme_preview_subtitle'))
                .fontSize(11)
                .fontColor('#94A3B8')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Button({ type: ButtonType.Circle, stateEffect: true }) {
              Image($r('app.media.ic_close'))
                .width(18)
                .height(18)
                .fillColor('#94A3B8')
            }
            .width(32)
            .height(32)
            .backgroundColor('#1E293B')
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
        .padding({ left: 16, right: 16, top: 6, bottom: 24 })
        .backgroundColor('#0D1322')
        .borderRadius({ topLeft: 24, topRight: 24 })
        .border({ width: { top: 1 }, color: 'rgba(255, 255, 255, 0.12)' })
        .shadow({ radius: 36, color: 'rgba(0, 0, 0, 0.85)', offsetY: -8 })
      }
      .width('100%')
      .height('100%')
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
              .border({ width: 1, color: this.currentMode === opt.mode ? opt.primaryPreviewColor : 'rgba(255, 255, 255, 0.1)' })

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
              .fontColor(this.currentMode === opt.mode ? opt.primaryPreviewColor : '#F8FAFC')

            Text(opt.descRes)
              .fontSize(11)
              .fontColor('#94A3B8')
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
            .fontColor('#64748B')
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
              .backgroundColor('#101626')
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
        .backgroundColor('#080D1A')
        .borderRadius(10)
        .border({ width: 1, color: 'rgba(255, 255, 255, 0.05)' })
      }
      .width('100%')
      .padding(14)
      .borderRadius(16)
      .backgroundColor(this.currentMode === opt.mode ? '#131B2E' : '#0F1524')
      .border({
        width: 1,
        color: this.currentMode === opt.mode ? opt.primaryPreviewColor : 'rgba(255, 255, 255, 0.08)'
      })
      .shadow({
        radius: this.currentMode === opt.mode ? 20 : 8,
        color: this.currentMode === opt.mode ? opt.primaryPreviewColor : 'rgba(0, 0, 0, 0.4)',
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
            .fillColor('#070A12')
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

