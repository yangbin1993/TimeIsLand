import { ThemeMode, ThemePalette } from '../theme/ThemeTypes';
import { themeManager } from '../theme/ThemeManager';
import { soundEffectManager, SoundEffectType } from '../utils/SoundEffectManager';
import { hapticFeedbackHelper } from '../utils/HapticFeedbackHelper';

/**
 * 法务与合规文档类型枚举
 */
export enum LegalNoticeType {
  AGREEMENT = 'agreement',
  PRIVACY = 'privacy',
  OPEN_SOURCE = 'opensource'
}

/**
 * 标签选项模型契约
 */
interface LegalTabOption {
  type: LegalNoticeType;
  titleRes: Resource;
}

/**
 * 时光岛 - 法务合规与隐私保护政策弹窗 (LegalNoticeDialog)
 * 职责: 为华为应用市场 (AppGallery) 审核与工信部合规提供常驻可查的《用户协议》《隐私政策》与《开源许可》
 * 风格: 极简东方禅意磨砂卡片、胶囊分段切换与沉浸式阅读视窗
 */
@Component
export struct LegalNoticeDialog {
  @StorageProp('currentTheme') theme: ThemePalette = themeManager.getPaletteByMode(ThemeMode.DARK);
  @StorageProp('currentThemeMode') currentMode: ThemeMode = ThemeMode.DARK;
  @StorageProp('bottomNavHeight') bottomNavHeight: number = 0;
  @Prop visible: boolean = false;
  @Prop activeType: LegalNoticeType = LegalNoticeType.PRIVACY;
  onClose: () => void = () => {};

  @State private selectedType: LegalNoticeType = LegalNoticeType.PRIVACY;

  private readonly tabOptions: LegalTabOption[] = [
    { type: LegalNoticeType.PRIVACY, titleRes: $r('app.string.timeisland_legal_tab_privacy') },
    { type: LegalNoticeType.AGREEMENT, titleRes: $r('app.string.timeisland_legal_tab_agreement') },
    { type: LegalNoticeType.OPEN_SOURCE, titleRes: $r('app.string.timeisland_legal_tab_opensource') }
  ];

  aboutToAppear(): void {
    this.selectedType = this.activeType;
  }

  build() {
    if (this.visible) {
      Stack({ alignContent: Alignment.Bottom }) {
        // 1. 半透明微光全屏遮罩
        Column()
          .width('100%')
          .height('100%')
          .backgroundColor(this.currentMode === ThemeMode.LIGHT ? $r('app.color.timeisland_dialog_mask_light') : $r('app.color.timeisland_dialog_mask_dark'))
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
          .onClick(() => {
            soundEffectManager.play(SoundEffectType.PEN_CLICK);
            this.onClose();
          })

        // 2. 浮层主工坊卡片面板
        Column({ space: 10 }) {
          // 顶部阻尼手柄
          Column()
            .width(40)
            .height(4)
            .backgroundColor(this.theme.borderSubtle)
            .borderRadius(2)
            .margin({ top: 6, bottom: 2 })

          // 标题栏与关闭触发钮
          this.buildTitleHeader()

          // 3 项胶囊分段选择栏
          this.buildSegmentedTabs()

          // 核心政策文档滚动视窗
          this.buildContentScrollView()

          // 底部操作确认按钮
          this.buildConfirmButton()

          // 底部物理避让安全区垫底
          Blank().height(8 + (this.bottomNavHeight > 0 ? this.bottomNavHeight : 0))
        }
        .width('100%')
        .padding({
          left: 16,
          right: 16,
          top: 6,
          bottom: 12
        })
        .backgroundColor(this.theme.surfaceLowest)
        .borderRadius({ topLeft: 24, topRight: 24 })
        .border({ width: { top: 1 }, color: this.theme.borderSubtle })
        .shadow({ radius: 32, color: this.theme.shadowCard, offsetY: -4 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      }
      .width('100%')
      .height('100%')
    }
  }

  /**
   * 标题栏与关闭无框圆形按钮
   */
  @Builder
  private buildTitleHeader() {
    Row() {
      Column({ space: 2 }) {
        Text($r('app.string.timeisland_legal_dialog_title'))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.textPrimary)

        Text($r('app.string.timeisland_legal_update_time'))
          .fontSize(11)
          .fontColor(this.theme.textMuted)
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
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        soundEffectManager.play(SoundEffectType.PEN_CLICK);
        this.onClose();
      })
    }
    .width('100%')
    .padding({ left: 4, right: 4 })
  }

  /**
   * 3 项胶囊分段选择栏 (严格对齐 Pill 半高圆角与 clip 裁切)
   */
  @Builder
  private buildSegmentedTabs() {
    Row({ space: 8 }) {
      ForEach(this.tabOptions, (item: LegalTabOption) => {
        Row() {
          Text(item.titleRes)
            .fontSize(12)
            .fontWeight(this.selectedType === item.type ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.selectedType === item.type ? Color.White : this.theme.textSecondary)
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .height(32)
        .borderRadius(16)
        .clip(true)
        .backgroundColor(this.selectedType === item.type ? Color.Transparent : this.theme.surfaceCard)
        .linearGradient(this.selectedType === item.type ? {
          angle: 90,
          colors: [[this.theme.secondaryAccent, 0.0], [this.theme.primaryAccent, 1.0]]
        } : undefined)
        .border({
          width: 1,
          color: this.selectedType === item.type ? this.theme.primaryAccentGlow : this.theme.borderCard,
          radius: 16
        })
        .onClick(() => {
          soundEffectManager.play(SoundEffectType.PEN_CLICK);
          hapticFeedbackHelper.trigger('tick');
          this.selectedType = item.type;
        })
      }, (item: LegalTabOption) => item.type)
    }
    .width('100%')
    .padding({ top: 2, bottom: 4 })
  }

  /**
   * 政策正文滚动视窗 (排版优雅的结构化条文卡片)
   */
  @Builder
  private buildContentScrollView() {
    Scroll() {
      Column({ space: 8 }) {
        Text(this.getContentText())
          .fontSize(13)
          .fontColor(this.theme.textSecondary)
          .lineHeight(22)
          .width('100%')
      }
      .width('100%')
      .padding(14)
      .backgroundColor(this.theme.surfaceCard)
      .borderRadius(16)
      .border({ width: 1, color: this.theme.borderCard })
    }
    .width('100%')
    .constraintSize({ maxHeight: '52%' })
    .scrollBar(BarState.Auto)
    .edgeEffect(EdgeEffect.Spring)
  }

  /**
   * 获取当前选中政策文本
   */
  private getContentText(): Resource {
    if (this.selectedType === LegalNoticeType.AGREEMENT) {
      return $r('app.string.timeisland_agreement_content');
    }
    if (this.selectedType === LegalNoticeType.OPEN_SOURCE) {
      return $r('app.string.timeisland_opensource_content');
    }
    return $r('app.string.timeisland_privacy_content');
  }

  /**
   * 底部「已充分阅读并知晓」胶囊大操作按钮
   */
  @Builder
  private buildConfirmButton() {
    Button({ type: ButtonType.Normal, stateEffect: true }) {
      Text($r('app.string.timeisland_legal_btn_confirm'))
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .fontColor(Color.White)
    }
    .width('100%')
    .height(44)
    .borderRadius(14)
    .clip(true)
    .linearGradient({
      angle: 90,
      colors: [[this.theme.secondaryAccent, 0.0], [this.theme.primaryAccent, 1.0]]
    })
    .border({
      width: 1,
      color: this.theme.primaryAccentGlow,
      radius: 14
    })
    .shadow({ radius: 14, color: this.theme.primaryAccentGlow, offsetY: 2 })
    .margin({ top: 4 })
    .onClick(() => {
      soundEffectManager.play(SoundEffectType.PEN_CLICK);
      hapticFeedbackHelper.trigger('complete');
      this.onClose();
    })
  }
}
