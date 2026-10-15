import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DialogHelper } from '@app/common';
import { ThemePalette, ThemeMode } from '../theme/ThemeTypes';
import { themeManager } from '../theme/ThemeManager';
import { soundEffectManager, SoundEffectType } from '../utils/SoundEffectManager';
import { hapticFeedbackHelper } from '../utils/HapticFeedbackHelper';
import { FeedbackHelper, FeedbackSubmitParams } from '../utils/FeedbackHelper';

const DOMAIN = 0x0000;
const TAG = 'FeedbackPage';

interface FeedbackTagOption {
  id: string;
  labelRes: Resource;
}

/**
 * 路由分发器 Builder 声明
 */
@Builder
export function FeedbackWebPageBuilder() {
  FeedbackWebPage()
}

/**
 * 时光岛 - 用户心声与禅意灵感直投页面 (FeedbackWebPage)
 * 职责: 100% 原生免登录直连 PushPlus 开发者个人微信，支持分类标签、微晶文本框与邮件自动平滑降级
 */
@Entry
@Component
struct FeedbackWebPage {
  @StorageProp('statusBarHeight') statusBarHeight: number = 0;
  @StorageProp('bottomNavHeight') bottomNavHeight: number = 0;
  @StorageProp('currentTheme') theme: ThemePalette = themeManager.getPaletteByMode(ThemeMode.DARK);

  @State private selectedTagId: string = 'feature';
  @State private content: string = '';
  @State private contact: string = '';
  @State private isSubmitting: boolean = false;

  private readonly tagOptions: FeedbackTagOption[] = [
    { id: 'feature', labelRes: $r('app.string.timeisland_feedback_tag_feature') },
    { id: 'bug', labelRes: $r('app.string.timeisland_feedback_tag_bug') },
    { id: 'theme', labelRes: $r('app.string.timeisland_feedback_tag_theme') },
    { id: 'chat', labelRes: $r('app.string.timeisland_feedback_tag_chat') }
  ];

  build() {
    Column() {
      // 1. 顶部 Header 导航条 (无框返回键 + 靠左标题，沉浸避让)
      this.buildHeader()

      // 2. 表单主体滚动视窗 (分类标签与输入卡片同流，6vp紧密咬合，消除一切多余空白)
      Scroll() {
        Column({ space: 6 }) {
          // 4 分类标签微晶阵列 (置于Scroll顶部，与输入框同属一个Column)
          this.buildCategorySelector()

          // 核心建议多行输入卡片 (紧贴分类按钮正下方，6vp精致小上间距)
          this.buildInputArea()

          // 选填联系方式输入行 (6vp微间距)
          this.buildContactInput()

          // 投递心声大操作按钮 (8vp舒适操作间距)
          this.buildSubmitButton()

          // 底部物理避让垫底 (避让底部手势横条)
          Blank().height(16 + (this.bottomNavHeight > 0 ? this.bottomNavHeight : 0))
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 2, bottom: 20 })
      }
      .scrollBar(BarState.Off)
      .width('100%')
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.theme.bgCanvas)
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP, SafeAreaEdge.BOTTOM])
  }

  /**
   * 顶部沉浸式导航条 (严格对齐设置页标准规范：无框返回键 + 靠左标题)
   */
  @Builder
  private buildHeader() {
    Row() {
      Button({ type: ButtonType.Circle, stateEffect: true }) {
        Image($r('app.media.ic_arrow_back'))
          .width(20)
          .height(20)
          .fillColor(this.theme.textPrimary)
      }
      .width(36)
      .height(36)
      .backgroundColor(Color.Transparent)
      .onClick(() => {
        soundEffectManager.play(SoundEffectType.PEN_CLICK);
        this.getUIContext().getRouter().back();
      })

      Text($r('app.string.timeisland_feedback_native_title'))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.theme.textPrimary)
        .margin({ left: 10 })

      Blank()
    }
    .width('100%')
    .padding({
      left: 16,
      right: 16,
      top: (this.statusBarHeight > 0 ? this.statusBarHeight : 0) + 10,
      bottom: 6
    })
  }

  /**
   * 4 分类标签微晶阵列 (半高圆角胶囊Pill设计，显式radius: 17杜绝任何直角边框)
   */
  @Builder
  private buildCategorySelector() {
    Row({ space: 6 }) {
      ForEach(this.tagOptions, (tag: FeedbackTagOption) => {
        Row() {
          Text(tag.labelRes)
            .fontSize(12)
            .fontWeight(this.selectedTagId === tag.id ? FontWeight.Medium : FontWeight.Normal)
            .fontColor(this.selectedTagId === tag.id ? Color.White : this.theme.textSecondary)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .justifyContent(FlexAlign.Center)
        .layoutWeight(1)
        .height(34)
        .borderRadius(17)
        .clip(true)
        .backgroundColor(this.selectedTagId === tag.id ? Color.Transparent : this.theme.surfaceCard)
        .linearGradient(this.selectedTagId === tag.id ? {
          angle: 90,
          colors: [[this.theme.secondaryAccent, 0.0], [this.theme.primaryAccent, 1.0]]
        } : undefined)
        .border({
          width: 1,
          color: this.selectedTagId === tag.id ? this.theme.primaryAccentGlow : this.theme.borderCard,
          radius: 17 // 显式声明边框半高圆角，百分之百杜绝任何直角边框线
        })
        .shadow(this.selectedTagId === tag.id ? {
          radius: 10,
          color: this.theme.primaryAccentGlow,
          offsetY: 2
        } : { radius: 0, color: Color.Transparent })
        .onClick(() => {
          soundEffectManager.play(SoundEffectType.PEN_CLICK);
          hapticFeedbackHelper.trigger('tick');
          this.selectedTagId = tag.id;
        })
      }, (tag: FeedbackTagOption) => tag.id)
    }
    .width('100%')
  }

  /**
   * 核心多行建议输入框卡片 (放置于4个胶囊按钮下部，6vp小上间距紧密咬合)
   */
  @Builder
  private buildInputArea() {
    Column({ space: 0 }) {
      TextArea({
        text: this.content,
        placeholder: $r('app.string.timeisland_feedback_input_placeholder')
      })
        .width('100%')
        .height(125)
        .fontSize(14)
        .fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textMuted)
        .backgroundColor(Color.Transparent)
        .maxLength(300)
        .showCounter(false)
        .padding({ left: 14, right: 14, top: 8, bottom: 4 })
        .onChange((val: string) => {
          this.content = val;
        })

      // 底部字数实时计数
      Row() {
        Blank()
        Text(`${this.content.length} / 300`)
          .fontSize(11)
          .fontColor(this.content.length > 0 ? this.theme.primaryAccent : this.theme.textMuted)
      }
      .width('100%')
      .padding({ left: 14, right: 14, bottom: 6 })
    }
    .width('100%')
    .backgroundColor(this.theme.surfaceCard)
    .borderRadius(14)
    .border({
      width: 1,
      color: this.theme.borderCard,
      radius: 14
    })
    .shadow({ radius: 10, color: this.theme.shadowCard, offsetY: 2 })
  }

  /**
   * 选填联系方式输入行 (紧贴建议卡片)
   */
  @Builder
  private buildContactInput() {
    Row({ space: 8 }) {
      Image($r('app.media.ic_account'))
        .width(16)
        .height(16)
        .fillColor(this.theme.textMuted)

      TextInput({
        text: this.contact,
        placeholder: $r('app.string.timeisland_feedback_contact_placeholder')
      })
        .layoutWeight(1)
        .height(42)
        .fontSize(13)
        .fontColor(this.theme.textPrimary)
        .placeholderColor(this.theme.textMuted)
        .backgroundColor(Color.Transparent)
        .padding({ left: 4, right: 6 })
        .onChange((val: string) => {
          this.contact = val;
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12 })
    .backgroundColor(this.theme.surfaceCard)
    .borderRadius(12)
    .border({
      width: 1,
      color: this.theme.borderCard,
      radius: 12
    })
  }

  /**
   * 投递心声大操作按钮 (Stitch生境微光渐变与流光投影)
   */
  @Builder
  private buildSubmitButton() {
    Button({ type: ButtonType.Normal, stateEffect: !this.isSubmitting }) {
      Row({ space: 8 }) {
        if (this.isSubmitting) {
          LoadingProgress()
            .width(18)
            .height(18)
            .color(Color.White)
        }

        Text(this.isSubmitting ? $r('app.string.timeisland_feedback_submitting') : $r('app.string.timeisland_feedback_submit_btn'))
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
      }
      .width('100%')
      .height(46)
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
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
    .shadow({ radius: 16, color: this.theme.primaryAccentGlow, offsetY: 3 })
    .margin({ top: 4 })
    .onClick(() => {
      this.handleSubmit();
    })
  }

  /**
   * 执行投递提交与自适应降级处理
   */
  private async handleSubmit(): Promise<void> {
    if (this.isSubmitting) {
      return;
    }

    if (this.content.trim().length === 0) {
      soundEffectManager.play(SoundEffectType.PEN_CLICK);
      hapticFeedbackHelper.trigger('warning');
      DialogHelper.showToast($r('app.string.timeisland_feedback_empty_toast'));
      return;
    }

    this.isSubmitting = true;
    soundEffectManager.play(SoundEffectType.SWITCH_OPEN);

    // 解析当前选中的分类标签显示文本
    let categoryName = 'Feature';
    try {
      const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
      const matched = this.tagOptions.find(t => t.id === this.selectedTagId);
      if (matched) {
        categoryName = context.resourceManager.getStringSync(matched.labelRes.id);
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to resolve category name: %{public}s', JSON.stringify(err));
    }

    const themeName: string = themeManager.getThemeMode().toString();
    const params: FeedbackSubmitParams = {
      category: categoryName,
      content: this.content.trim(),
      contact: this.contact.trim(),
      themeName: themeName
    };

    const isSuccess = await FeedbackHelper.sendPushPlusFeedback(params);
    this.isSubmitting = false;

    if (isSuccess) {
      soundEffectManager.play(SoundEffectType.BUBBLE);
      hapticFeedbackHelper.trigger('complete');
      DialogHelper.showToast($r('app.string.timeisland_feedback_success_toast'));
      setTimeout(() => {
        this.getUIContext().getRouter().back();
      }, 500);
    } else {
      // 优雅降级：若 PushPlus 直推暂时失败 (如接口鉴权/弱网)，自动唤起邮件兜底通道
      soundEffectManager.play(SoundEffectType.PEN_CLICK);
      DialogHelper.showToast($r('app.string.timeisland_feedback_fallback_toast'));
      const fallbackBody = `[${categoryName}]\n\n${this.content.trim()}\n\nContact: ${this.contact.trim()}`;
      FeedbackHelper.sendEmailFeedback(this.getUIContext().getHostContext() as common.UIAbilityContext, fallbackBody);
    }
  }
}
