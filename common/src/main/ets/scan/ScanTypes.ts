/**
 * 统一扫码套件类型与契约定义 (ScanTypes)
 * 基于 HarmonyOS Scan Kit 设计，规范扫码入参、码制格式与结果响应模型
 */

/**
 * 扫码目标码制格式枚举
 */
export enum ScanCodeFormat {
  /**
   * 支持所有常见码制 (包含一维条形码与二维矩阵码)
   */
  ALL = 'ALL',

  /**
   * 仅二维码 (QR Code)
   */
  QR_CODE = 'QR_CODE',

  /**
   * 仅常见一维条形码 (EAN-13, Code 128, Code 39 等)
   */
  BARCODE_1D = 'BARCODE_1D'
}

/**
 * 统一扫码调度配置项 (ScanOptions)
 */
export interface ScanOptions {
  /**
   * 目标码制过滤类型，默认为 ScanCodeFormat.ALL
   */
  format?: ScanCodeFormat;

  /**
   * 界面提示文案
   */
  title?: string;
}

/**
 * 统一扫码响应结果模型 (ScanResult)
 */
export interface ScanResult {
  /**
   * 是否成功识别到码内容
   */
  isSuccess: boolean;

  /**
   * 用户是否主动取消了本次扫码 (例如点击返回键或侧滑退出)
   */
  isCanceled: boolean;

  /**
   * 识别出的原始码文本数据
   */
  originalValue: string;

  /**
   * 识别出的码类型名称 (如 QR_CODE, EAN_13, CODE_128 等)
   */
  scanType: string;

  /**
   * 异常或失败提示描述
   */
  errorMessage?: string;
}

/**
 * 动态二维码位图生成配置项 (QrGenerateOptions)
 */
export interface QrGenerateOptions {
  /**
   * 二维码位图宽度 (像素，默认为 300)
   */
  width?: number;

  /**
   * 二维码位图高度 (像素，默认为 300)
   */
  height?: number;

  /**
   * 纠错级别等级
   */
  margin?: number;
}
