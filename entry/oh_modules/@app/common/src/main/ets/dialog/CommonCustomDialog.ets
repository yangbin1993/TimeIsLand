import { CommonStrings } from '../constants/CommonStrings';
import { DialogAction, DialogType } from './DialogTypes';

/**
 * 生产级通用自定义对话框组件 (CommonCustomDialog)
 * 采用 ArkUI @CustomDialog 装饰器构建，适配 Alert / Confirm / Input / Loading 全场景
 */
@CustomDialog
export struct CommonCustomDialog {
  // 必须持有的自定义弹窗控制器 (由外部 CustomDialogController 自动注入绑定)
  controller?: CustomDialogController;

  // 对话框模式，默认为确认模式
  type: DialogType = DialogType.CONFIRM;

  // 标题文本
  title: string = CommonStrings.DIALOG_DEFAULT_TITLE;

  // 描述消息文本
  message: string = '';

  // 确认按钮文本
  confirmText: string = CommonStrings.DIALOG_CONFIRM;

  // 取消按钮文本
  cancelText: string = CommonStrings.DIALOG_CANCEL;

  // 是否为警示/危险操作 (确认按钮标红)
  isDanger: boolean = false;

  // 输入模式下的占位符
  inputPlaceholder: string = CommonStrings.DIALOG_INPUT_PLACEHOLDER;

  // 输入模式下的受控文本状态
  @State inputValue: string = '';

  // 确认回调
  onConfirm: (inputValue?: string) => void = (): void => {};

  // 取消回调
  onCancel: () => void = (): void => {};

  build() {
    Column() {
      // 1. Loading 加载模式视图
      if (this.type === DialogType.LOADING) {
        Column({ space: 14 }) {
          LoadingProgress()
            .width(44)
            .height(44)
            .color('#007AFF')

          Text(this.message || CommonStrings.DIALOG_LOADING)
            .fontSize(15)
            .fontColor('#555555')
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ top: 24, bottom: 24, left: 20, right: 20 })
        .alignItems(HorizontalAlign.Center)
      } else {
        // 2. Alert / Confirm / Input 模式视图
        Column() {
          // 标题区
          if (this.title && this.title.length > 0) {
            Text(this.title)
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
              .textAlign(TextAlign.Center)
              .width('100%')
              .margin({ bottom: 10 })
          }

          // 消息内容区
          if (this.message && this.message.length > 0) {
            Text(this.message)
              .fontSize(14)
              .fontColor('#666666')
              .lineHeight(20)
              .textAlign(TextAlign.Center)
              .width('100%')
              .margin({ bottom: this.type === DialogType.INPUT ? 12 : 20 })
          }

          // Input 输入框区 (仅 INPUT 模式呈现)
          if (this.type === DialogType.INPUT) {
            TextInput({
              text: this.inputValue,
              placeholder: this.inputPlaceholder
            })
              .width('100%')
              .height(44)
              .borderRadius(8)
              .backgroundColor('#F5F5F5')
              .padding({ left: 14, right: 14 })
              .fontSize(15)
              .fontColor('#333333')
              .margin({ bottom: 20 })
              .onChange((val: string): void => {
                this.inputValue = val;
              })
          }
        }
        .padding({ top: 24, bottom: 4, left: 24, right: 24 })
        .width('100%')

        // 水平分割线
        Divider()
          .color('#F0F0F0')
          .height(1)
          .width('100%')

        // 底部按钮操作区
        if (this.type === DialogType.ALERT) {
          // 单按钮模式 (ALERT)
          Button(this.confirmText || CommonStrings.DIALOG_KNOW)
            .width('100%')
            .height(50)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#007AFF')
            .backgroundColor('transparent')
            .onClick((): void => {
              this.controller?.close();
              this.onConfirm();
            })
        } else {
          // 双按钮模式 (CONFIRM / INPUT)
          Row() {
            // 取消按钮
            Button(this.cancelText || CommonStrings.DIALOG_CANCEL)
              .layoutWeight(1)
              .height(50)
              .fontSize(16)
              .fontColor('#888888')
              .backgroundColor('transparent')
              .onClick((): void => {
                this.controller?.close();
                this.onCancel();
              })

            // 按钮垂直分割线
            Divider()
              .vertical(true)
              .height(24)
              .color('#F0F0F0')

            // 确认按钮
            Button(this.confirmText || CommonStrings.DIALOG_CONFIRM)
              .layoutWeight(1)
              .height(50)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.isDanger ? '#FF3B30' : '#007AFF')
              .backgroundColor('transparent')
              .onClick((): void => {
                this.controller?.close();
                this.onConfirm(this.inputValue);
              })
          }
          .width('100%')
          .height(50)
        }
      }
    }
    .width('85%')
    .borderRadius(18)
    .backgroundColor('#FFFFFF')
    .clip(true)
    .shadow({ radius: 24, color: '#26000000', offsetY: 6 })
  }
}
