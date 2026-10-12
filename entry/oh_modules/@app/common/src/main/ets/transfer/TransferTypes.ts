/**
 * 文件传输实时进度数据模型
 */
export interface TransferProgress {
  /**
   * 已传输字节数 (Bytes)
   */
  loadedBytes: number;

  /**
   * 文件总字节数 (Bytes)，若服务端未返回 Content-Length 则可能为 -1
   */
  totalBytes: number;

  /**
   * 进度百分比 (0 - 100)
   */
  percentage: number;
}

/**
 * 下载任务扩展选项配置
 */
export interface DownloadTaskOptions {
  /**
   * 自定义请求头（如 Authorization、Token）
   */
  header?: Record<string, string>;

  /**
   * 是否允许使用蜂窝移动网络下载（默认为 true）
   */
  enableMetered?: boolean;

  /**
   * 保存的子目录名称，默认为 'downloads'
   */
  subDir?: string;
}

/**
 * 上传任务扩展选项配置
 */
export interface UploadTaskOptions {
  /**
   * 自定义请求头
   */
  header?: Record<string, string>;

  /**
   * 上传表单字段名称，默认为 'file'
   */
  name?: string;

  /**
   * 伴随文件一同提交的文本键值对表单数据
   */
  data?: Record<string, string>;
}
