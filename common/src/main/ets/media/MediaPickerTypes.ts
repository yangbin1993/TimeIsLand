/**
 * 媒体文件筛选类型
 */
export enum MediaSelectType {
  /**
   * 仅选择图片
   */
  IMAGE = 'IMAGE',

  /**
   * 仅选择视频
   */
  VIDEO = 'VIDEO',

  /**
   * 图片与视频混合选择
   */
  ALL = 'ALL'
}

/**
 * 选中的单个媒体项实体
 */
export interface MediaItem {
  /**
   * 系统相册安全授权 URI
   */
  uri: string;

  /**
   * 拷贝至应用沙箱 cache 目录后的本地真实文件路径 (若开启 copyToSandbox)
   */
  sandboxPath?: string;

  /**
   * 媒体文件名称
   */
  fileName?: string;
}

/**
 * 相册选择配置选项
 */
export interface MediaSelectOptions {
  /**
   * 媒体类型约束，默认为 IMAGE
   */
  type?: MediaSelectType;

  /**
   * 最大允许选择的媒体数量 (1~50，默认为 1)
   */
  maxSelectNumber?: number;

  /**
   * 是否自动将选中媒体拷贝至应用沙箱 Cache 目录
   * 开启后可避免第三方 SDK 或自定义上传组件无法直接访问系统相册 URI 协议的问题
   * 默认为 true
   */
  copyToSandbox?: boolean;
}

/**
 * 媒体选择操作结果
 */
export interface MediaPickerResult {
  /**
   * 选中的媒体集合
   */
  items: MediaItem[];

  /**
   * 是否成功获取媒体
   */
  isSuccess: boolean;

  /**
   * 用户是否主动放弃选择 (点击关闭/返回)
   */
  isCancelled: boolean;
}
