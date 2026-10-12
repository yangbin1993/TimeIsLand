import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { scanBarcode, generateBarcode, scanCore } from '@kit.ScanKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { CommonStrings } from '../constants/CommonStrings';
import { AppEventTracker } from '../tracker/AppEventTracker';
import { QrGenerateOptions, ScanCodeFormat, ScanOptions, ScanResult } from './ScanTypes';

const TAG: string = 'ScanHelper';
const DOMAIN: number = 0x0000;

/**
 * 生产级统一扫码与二维码调度门面 (ScanHelper)
 * 基于 HarmonyOS NEXT 官方 Scan Kit 封装，深度对标 Android ZXing / CameraX
 * 
 * 核心设计优势：
 * 1. 零权限系统级安全扫码：采用 scanBarcode.startScanForResult，由系统沙箱独立托管相机界面，应用无需索取敏感的 Camera 运行时权限；
 * 2. 异常平滑归约保护：用户点击返回或侧滑关闭扫码面板时，精准拦截底层 Reject，平滑归约为 isCanceled: true，杜绝未捕获崩溃；
 * 3. 动态二维码位图生成：集成 generateBarcode.createBarcode，毫秒级输出高质量 PixelMap；
 * 4. 全生命周期行为感知：自动联动 AppEventTracker 记录 scan_start、scan_success 与 scan_cancel 行为时序；
 * 5. 集中文本常量驱动：全面由 CommonStrings 提供规范文案，无文字硬编码。
 */
export class ScanHelper {
  private static instance: ScanHelper;

  private constructor() {}

  /**
   * 获取 ScanHelper 全局统一单例
   */
  public static getInstance(): ScanHelper {
    if (!ScanHelper.instance) {
      ScanHelper.instance = new ScanHelper();
    }
    return ScanHelper.instance;
  }

  /**
   * 映射业务码制格式至系统 ScanKit 码制枚举
   */
  private static mapScanTypes(format?: ScanCodeFormat): scanCore.ScanType[] {
    switch (format) {
      case ScanCodeFormat.QR_CODE:
        return [scanCore.ScanType.QR_CODE];
      case ScanCodeFormat.BARCODE_1D:
        return [scanCore.ScanType.ONE_D_CODE];
      case ScanCodeFormat.ALL:
      default:
        return [scanCore.ScanType.ALL];
    }
  }

  /**
   * 一键呼起系统级原生扫码面板 (默认视图 / 免相机权限)
   * 
   * @param context UIAbility 上下文
   * @param options 可选扫码过滤配置
   * @returns 包含原始文本与状态的 Promise<ScanResult>
   */
  public static async startScan(
    context: common.UIAbilityContext,
    options?: ScanOptions
  ): Promise<ScanResult> {
    AppEventTracker.track('scan_start');

    // 硬件能力防御性探测：确保设备搭载 ScanBarcode 系统能力
    if (!canIUse('SystemCapability.Multimedia.Scan.ScanBarcode')) {
      hilog.warn(DOMAIN, TAG, 'SystemCapability.Multimedia.Scan.ScanBarcode is not supported on current device hardware.');
      AppEventTracker.track('scan_unsupported');
      return {
        isSuccess: false,
        isCanceled: false,
        originalValue: '',
        scanType: '',
        errorMessage: CommonStrings.SCAN_UNSUPPORTED_DEVICE
      };
    }

    hilog.info(DOMAIN, TAG, 'Starting scanBarcode.startScanForResult...');

    try {
      const scanOptions: scanBarcode.ScanOptions = {
        scanTypes: ScanHelper.mapScanTypes(options?.format)
      };

      const systemResult: scanBarcode.ScanResult = await scanBarcode.startScanForResult(context, scanOptions);

      const content = systemResult.originalValue ?? '';
      const scanTypeDesc = `${systemResult.scanType ?? 'UNKNOWN'}`;

      hilog.info(DOMAIN, TAG, `Scan succeeded: type=${scanTypeDesc}, length=${content.length}`);
      AppEventTracker.track('scan_success');

      return {
        isSuccess: true,
        isCanceled: false,
        originalValue: content,
        scanType: scanTypeDesc
      };
    } catch (err) {
      const error = err as BusinessError;
      // 核心防御点：
      // 当用户点击系统扫码界面的返回按钮、物理返回键或手势侧滑退出时，
      // 系统会以 Promise reject (如错误码 1000500001) 结束。
      // 此处统一平滑归约，返回 isCanceled=true，保证业务调用安全无崩溃。
      hilog.info(DOMAIN, TAG, `Scan dismissed or canceled by user: ${JSON.stringify(error)}`);
      AppEventTracker.track('scan_cancel');

      return {
        isSuccess: false,
        isCanceled: true,
        originalValue: '',
        scanType: '',
        errorMessage: CommonStrings.SCAN_CANCELED
      };
    }
  }

  /**
   * 动态生成指定文本内容的二维码位图 (PixelMap)
   * 
   * @param content 待编码的字符串内容
   * @param options 生成配置项 (长宽尺寸与边距)
   * @returns 成功返回 image.PixelMap，失败返回 undefined
   */
  public static async generateQrCode(
    content: string,
    options?: QrGenerateOptions
  ): Promise<image.PixelMap | undefined> {
    if (!content || content.trim().length === 0) {
      hilog.warn(DOMAIN, TAG, 'Cannot generate QR code: content is empty');
      return undefined;
    }

    if (!canIUse('SystemCapability.Multimedia.Scan.GenerateBarcode')) {
      hilog.warn(DOMAIN, TAG, 'SystemCapability.Multimedia.Scan.GenerateBarcode is not supported on current device hardware.');
      return undefined;
    }

    try {
      const width = options?.width ?? 300;
      const height = options?.height ?? 300;
      const margin = options?.margin ?? 1;

      hilog.info(DOMAIN, TAG, `Generating QR code: width=${width}, height=${height}`);

      const createOptions: generateBarcode.CreateOptions = {
        scanType: scanCore.ScanType.QR_CODE,
        height: height,
        width: width,
        margin: margin
      };

      const pixelMap: image.PixelMap = await generateBarcode.createBarcode(content, createOptions);
      hilog.info(DOMAIN, TAG, 'QR code PixelMap generated successfully.');
      return pixelMap;
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Failed to generate QR code: ${JSON.stringify(err)}`);
      return undefined;
    }
  }
}

/**
 * 快捷导出全局扫码门面单例
 */
export const scanHelper: ScanHelper = ScanHelper.getInstance();
