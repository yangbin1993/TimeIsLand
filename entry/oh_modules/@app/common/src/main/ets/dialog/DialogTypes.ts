/**
 * 对话框模态类型
 */
export enum DialogType {
  /**
   * 单按钮提示通知弹窗 (仅确认关闭)
   */
  ALERT = 'ALERT',

  /**
   * 双按钮二次确认弹窗 (取消 / 确认)
   */
  CONFIRM = 'CONFIRM',

  /**
   * 交互式单行输入弹窗 (带 TextInput)
   */
  INPUT = 'INPUT',

  /**
   * 加载等待遮罩弹窗 (带 LoadingProgress 旋转动画)
   */
  LOADING = 'LOADING'
}

/**
 * 对话框用户操作动作
 */
export enum DialogAction {
  /**
   * 点击确认
   */
  CONFIRM = 'CONFIRM',

  /**
   * 点击取消或点击蒙层关闭
   */
  CANCEL = 'CANCEL'
}

/**
 * 对话框操作返回结果
 */
export interface DialogResult {
  /**
   * 用户操作动作 (CONFIRM / CANCEL)
   */
  action: DialogAction;

  /**
   * 是否点击了确认按钮
   */
  isConfirmed: boolean;

  /**
   * 输入弹窗模式下的用户输入文本内容
   */
  inputValue?: string;
}

/**
 * 对话框配置参数选项
 */
export interface DialogOptions {
  /**
   * 弹窗模态类型，默认为 CONFIRM
   */
  type?: DialogType;

  /**
   * 弹窗标题 (如 '操作确认')
   */
  title?: string;

  /**
   * 弹窗主体说明文本
   */
  message?: string;

  /**
   * 确认按钮文案 (默认为 '确定')
   */
  confirmText?: string;

  /**
   * 取消按钮文案 (默认为 '取消')
   */
  cancelText?: string;

  /**
   * 是否为危险/破坏性操作 (若为 true，确认按钮将高亮显示为警示红 #FF3B30)
   */
  isDanger?: boolean;

  /**
   * 点击遮罩阴影区域是否自动关闭弹窗 (默认为 true；Loading 模式下建议为 false)
   */
  autoCancel?: boolean;

  /**
   * 输入模式下的占位符提示文案
   */
  inputPlaceholder?: string;

  /**
   * 输入模式下的初始预填内容
   */
  initialValue?: string;
}

/**
 * 加载弹窗控制器接口 (用于外部主动控制关闭加载遮罩)
 */
export interface LoadingController {
  /**
   * 关闭并销毁加载弹窗
   */
  close: () => void;

  /**
   * 动态更新加载提示文案 (如 '正在上传 60%...')
   */
  updateMessage: (newMessage: string) => void;
}

/**
 * 底部操作表条目配置
 */
export interface ActionSheetItem {
  /**
   * 选项文案
   */
  title: string;

  /**
   * 可选图标资源路径
   */
  icon?: string;

  /**
   * 是否为危险操作 (例如：删除条目)
   */
  isDanger?: boolean;
}

/**
 * 底部操作表配置选项
 */
export interface ActionSheetOptions {
  /**
   * 主标题
   */
  title?: string;

  /**
   * 副标题或说明
   */
  subtitle?: string;

  /**
   * 选项列表 (支持纯字符串数组或结构化 ActionSheetItem 数组)
   */
  items: (string | ActionSheetItem)[];

  /**
   * 取消按钮文案 (默认为 '取消')
   */
  cancelText?: string;
}

/**
 * 底部操作表选择结果
 */
export interface ActionSheetResult {
  /**
   * 选中的选项索引 (若用户点击取消或蒙层关闭则为 -1)
   */
  selectedIndex: number;

  /**
   * 是否已取消关闭
   */
  isCancelled: boolean;
}
