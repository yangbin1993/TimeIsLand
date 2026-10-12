import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo } from '@kit.CoreFileKit';
import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { MediaItem, MediaPickerResult, MediaSelectOptions, MediaSelectType } from './MediaPickerTypes';

const TAG: string = 'MediaPickerHelper';
const DOMAIN: number = 0x0000;

/**
 * 生产级系统相册与媒体选择门面 (MediaPickerHelper)
 * 深度对标 Android MediaPickerLauncher / PhotoPicker
 * 
 * 核心架构特性：
 * 1. 零权限弹窗体系：深度基于 HarmonyOS photoAccessHelper.PhotoViewPicker 系统独立进程，无需向用户索取权限；
 * 2. 强类型聚合契约：统一收口单选、多选、视频与图视混选，规避底层枚举参数错误；
 * 3. 自动沙箱缓存固化 (copyToSandbox)：自动将受限相册 URI 拷贝至应用沙箱 Cache 目录，彻底消除三方 SDK 权限失效问题；
 * 4. 异常平滑归约保护：完整捕获用户取消返回、文件读取中断等场景，保证 100% 杜绝 Promise unhandled rejection。
 */
export class MediaPickerHelper {
  private static instance: MediaPickerHelper;
  private appContext?: common.Context;

  private constructor() {}

  /**
   * 获取 MediaPickerHelper 统一单例
   */
  public static getInstance(): MediaPickerHelper {
    if (!MediaPickerHelper.instance) {
      MediaPickerHelper.instance = new MediaPickerHelper();
    }
    return MediaPickerHelper.instance;
  }

  /**
   * 初始化注入上下文 (用于沙箱路径解析与本地拷贝)
   * 建议在 AppAbility.onCreate 注入应用上下文
   *
   * @param context 应用上下文
   */
  public initialize(context: common.Context): void {
    this.appContext = context;
    hilog.info(DOMAIN, TAG, 'MediaPickerHelper initialized with application context');
  }

  /**
   * 快捷拉起相册选择单张图片
   *
   * @param copyToSandbox 是否自动拷贝至应用沙箱 cache (默认 true)
   * @returns 选中的媒体项，用户取消时返回 null
   */
  public async pickSingleImage(copyToSandbox: boolean = true): Promise<MediaItem | null> {
    const result = await this.pickMedia({
      type: MediaSelectType.IMAGE,
      maxSelectNumber: 1,
      copyToSandbox: copyToSandbox
    });
    return result.items.length > 0 ? result.items[0] : null;
  }

  /**
   * 快捷拉起相册批量选择多张图片
   *
   * @param maxCount 最大选择张数 (默认 9)
   * @param copyToSandbox 是否自动拷贝至沙箱 (默认 true)
   * @returns 选中的图片集合
   */
  public async pickImages(maxCount: number = 9, copyToSandbox: boolean = true): Promise<MediaItem[]> {
    const result = await this.pickMedia({
      type: MediaSelectType.IMAGE,
      maxSelectNumber: maxCount,
      copyToSandbox: copyToSandbox
    });
    return result.items;
  }

  /**
   * 快捷拉起相册批量选择视频
   *
   * @param maxCount 最大选择个数 (默认 1)
   * @param copyToSandbox 是否自动拷贝至沙箱 (默认 true)
   * @returns 选中的视频集合
   */
  public async pickVideos(maxCount: number = 1, copyToSandbox: boolean = true): Promise<MediaItem[]> {
    const result = await this.pickMedia({
      type: MediaSelectType.VIDEO,
      maxSelectNumber: maxCount,
      copyToSandbox: copyToSandbox
    });
    return result.items;
  }

  /**
   * 通用媒体选择核心驱动方法
   *
   * @param options 选择配置选项
   * @returns 统一结果结构 MediaPickerResult
   */
  public async pickMedia(options?: MediaSelectOptions): Promise<MediaPickerResult> {
    const type: MediaSelectType = options?.type ?? MediaSelectType.IMAGE;
    const maxSelectNumber: number = Math.max(1, Math.min(options?.maxSelectNumber ?? 1, 50));
    const copyToSandbox: boolean = options?.copyToSandbox ?? true;

    try {
      const picker = new photoAccessHelper.PhotoViewPicker();
      const selectOptions = new photoAccessHelper.PhotoSelectOptions();

      // 配置 MIME 筛选类型
      if (type === MediaSelectType.IMAGE) {
        selectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      } else if (type === MediaSelectType.VIDEO) {
        selectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.VIDEO_TYPE;
      } else {
        selectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_VIDEO_TYPE;
      }

      selectOptions.maxSelectNumber = maxSelectNumber;

      hilog.info(DOMAIN, TAG, `Launching PhotoViewPicker: type=${type}, maxCount=${maxSelectNumber}`);
      const pickerResult = await picker.select(selectOptions);

      if (!pickerResult || !pickerResult.photoUris || pickerResult.photoUris.length === 0) {
        hilog.info(DOMAIN, TAG, 'PhotoViewPicker closed with no items selected (cancelled)');
        return {
          items: [],
          isSuccess: false,
          isCancelled: true
        };
      }

      const mediaItems: MediaItem[] = [];
      for (let i = 0; i < pickerResult.photoUris.length; i++) {
        const uri = pickerResult.photoUris[i];
        const fileName = this.extractFileName(uri, type);
        let sandboxPath: string | undefined = undefined;

        if (copyToSandbox && this.appContext) {
          sandboxPath = this.copyUriToSandbox(uri, fileName);
        }

        mediaItems.push({
          uri: uri,
          sandboxPath: sandboxPath,
          fileName: fileName
        });
      }

      hilog.info(DOMAIN, TAG, `Successfully selected ${mediaItems.length} media items`);
      return {
        items: mediaItems,
        isSuccess: true,
        isCancelled: false
      };
    } catch (err) {
      hilog.warn(DOMAIN, TAG, `PhotoViewPicker operation cancelled or failed: ${JSON.stringify(err)}`);
      return {
        items: [],
        isSuccess: false,
        isCancelled: true
      };
    }
  }

  /**
   * 将系统相册 URI 拷贝至应用沙箱 Cache 目录，获取可长期读取的本地绝对路径
   */
  private copyUriToSandbox(uri: string, targetFileName: string): string | undefined {
    let srcFile: fileIo.File | null = null;
    let destFile: fileIo.File | null = null;
    try {
      const cacheDir = this.appContext!.cacheDir;
      const destPath = `${cacheDir}/${targetFileName}`;

      // 打开系统相册 URI 只读流
      srcFile = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
      // 创建或覆盖目标沙箱文件
      destFile = fileIo.openSync(destPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE);

      fileIo.copyFileSync(srcFile.fd, destFile.fd);
      hilog.info(DOMAIN, TAG, `Copied media URI to sandbox: ${destPath}`);
      return destPath;
    } catch (copyErr) {
      hilog.error(DOMAIN, TAG, `Failed to copy URI to sandbox: ${(copyErr as Error).message}`);
      return undefined;
    } finally {
      if (srcFile !== null) {
        try {
          fileIo.closeSync(srcFile);
        } catch (e) {
          // 容错
        }
      }
      if (destFile !== null) {
        try {
          fileIo.closeSync(destFile);
        } catch (e) {
          // 容错
        }
      }
    }
  }

  /**
   * 从 URI 中提取或自动生成唯一规范文件名
   */
  private extractFileName(uri: string, type: MediaSelectType): string {
    const timestamp = Date.now();
    const randomSuffix = Math.floor(Math.random() * 10000);
    const ext = type === MediaSelectType.VIDEO ? 'mp4' : 'jpg';

    const lastSlashIndex = uri.lastIndexOf('/');
    if (lastSlashIndex !== -1 && lastSlashIndex < uri.length - 1) {
      const rawName = uri.substring(lastSlashIndex + 1);
      if (rawName.includes('.')) {
        return `${timestamp}_${rawName}`;
      }
    }
    return `media_${timestamp}_${randomSuffix}.${ext}`;
  }
}

/**
 * 快捷导出全局媒体选择器门面单例
 */
export const mediaPickerHelper: MediaPickerHelper = MediaPickerHelper.getInstance();
