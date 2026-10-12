import { request } from '@kit.BasicServicesKit';
import { fileIo } from '@kit.CoreFileKit';
import { Context } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { DownloadTaskOptions, TransferProgress, UploadTaskOptions } from './TransferTypes';

const TAG = 'FileTransferManager';
const DOMAIN = 0x0000;

/**
 * 鸿蒙系统级文件传输调度管理器 (FileTransferManager)
 * 深度封装自 HarmonyOS 官方系统级能力 @kit.BasicServicesKit 中的 request 模块 (request.agent)
 * 
 * 核心特性：
 * 1. 系统级代理服务托管：任务由系统传输代理 (FileTransferAgent) 执行，高吞吐低功耗
 * 2. 精确全生命周期进度回调：实时计算传输已处理字节、总大小与百分比
 * 3. 自动沙箱路径创建：结合 @kit.CoreFileKit 的 fileIo，自动规整并创建目标沙箱目录
 * 4. 健壮的异常与失败事件捕获，避免文件句柄泄露
 */
export class FileTransferManager {
  private static instance: FileTransferManager;

  private constructor() {}

  /**
   * 获取单例实例
   */
  public static getInstance(): FileTransferManager {
    if (!FileTransferManager.instance) {
      FileTransferManager.instance = new FileTransferManager();
    }
    return FileTransferManager.instance;
  }

  /**
   * 确保指定本地沙箱目录存在，若不存在则递归创建
   */
  private ensureDirectoryExists(dirPath: string): void {
    try {
      if (!fileIo.accessSync(dirPath)) {
        fileIo.mkdirSync(dirPath, true);
        hilog.info(DOMAIN, TAG, `Created directory: ${dirPath}`);
      }
    } catch (e) {
      hilog.warn(DOMAIN, TAG, 'Directory check/create warning: %{public}s', JSON.stringify(e));
    }
  }

  /**
   * 基于 ohos.request (request.agent) 发起文件下载任务
   * 
   * @param context UIAbility 或上下文对象 Context
   * @param url 文件下载目标远程绝对 URL
   * @param saveFileName 保存至沙箱中的文件名（如 'sample.pdf' 或 'avatar.png'）
   * @param onProgress 传输进度实时监听回调 (0 - 100%)
   * @param options 下载个性化配置（子目录、请求头、网络类型等）
   * @returns 下载成功后的本地沙箱绝对路径
   */
  public async downloadFile(
    context: Context,
    url: string,
    saveFileName: string,
    onProgress?: (progress: TransferProgress) => void,
    options?: DownloadTaskOptions
  ): Promise<string> {
    const subDirName = options?.subDir ?? 'downloads';
    const targetDir = `${context.cacheDir}/${subDirName}`;
    this.ensureDirectoryExists(targetDir);

    const fullSavePath = `${targetDir}/${saveFileName}`;
    hilog.info(DOMAIN, TAG, `Initiating download -> URL: ${url}, Target: ${fullSavePath}`);

    return new Promise<string>((resolve, reject) => {
      // 配置 request.agent 下载任务
      const downloadConfig: request.agent.Config = {
        action: request.agent.Action.DOWNLOAD,
        url: url,
        title: saveFileName,
        description: 'HarmonyOS File Download Task',
        mode: request.agent.Mode.FOREGROUND,
        network: options?.enableMetered === false ? request.agent.Network.WIFI : request.agent.Network.ANY,
        saveas: `${subDirName}/${saveFileName}`,
        headers: options?.header
      };

      request.agent.create(context, downloadConfig).then((task: request.agent.Task) => {
        const cleanupListeners = (): void => {
          try {
            task.off('progress');
            task.off('completed');
            task.off('failed');
          } catch (e) {
            // 容错防崩
          }
        };

        // 注册进度事件监听
        task.on('progress', (progress: request.agent.Progress) => {
          const total = (progress.sizes && progress.sizes.length > 0 && progress.sizes[0] > 0) 
            ? progress.sizes[0] 
            : -1;
          const processed = progress.processed;
          const percentage = total > 0 ? Math.min(100, Math.floor((processed / total) * 100)) : 0;

          if (onProgress) {
            onProgress({
              loadedBytes: processed,
              totalBytes: total,
              percentage: percentage
            });
          }
        });

        // 注册完成事件监听
        task.on('completed', () => {
          cleanupListeners();
          hilog.info(DOMAIN, TAG, `Download task completed: ${fullSavePath}`);
          resolve(fullSavePath);
        });

        // 注册失败事件监听
        task.on('failed', () => {
          cleanupListeners();
          const errorMsg = `Download failed for URL: ${url}`;
          hilog.error(DOMAIN, TAG, '%{public}s', errorMsg);
          reject(new Error(errorMsg));
        });

        // 启动下载任务
        task.start().catch((startErr: Error) => {
          cleanupListeners();
          hilog.error(DOMAIN, TAG, 'Failed to start download task: %{public}s', startErr.message);
          reject(startErr);
        });
      }).catch((createErr: Error) => {
        hilog.error(DOMAIN, TAG, 'Failed to create download task: %{public}s', createErr.message);
        reject(createErr);
      });
    });
  }

  /**
   * 基于 ohos.request (request.agent) 发起文件上传任务
   * 
   * @param context UIAbility 或上下文对象 Context
   * @param url 文件上传服务端接收接口 URL
   * @param localFilePath 待上传的本地沙箱文件绝对路径
   * @param onProgress 传输进度实时监听回调 (0 - 100%)
   * @param options 上传个性化配置（表单字段名、附加键值对数据等）
   * @returns 上传是否成功
   */
  public async uploadFile(
    context: Context,
    url: string,
    localFilePath: string,
    onProgress?: (progress: TransferProgress) => void,
    options?: UploadTaskOptions
  ): Promise<boolean> {
    hilog.info(DOMAIN, TAG, `Initiating upload -> URL: ${url}, File: ${localFilePath}`);

    try {
      // 检查本地待上传文件是否存在
      if (!fileIo.accessSync(localFilePath)) {
        throw new Error(`Upload file not found at path: ${localFilePath}`);
      }
    } catch (e) {
      throw new Error(`Invalid local file path: ${localFilePath}`);
    }

    return new Promise<boolean>((resolve, reject) => {
      const fieldName = options?.name ?? 'file';

      // 组装上传表单文件项与文本字段
      const formItems: request.agent.FormItem[] = [
        {
          name: fieldName,
          value: {
            path: localFilePath
          }
        }
      ];

      // 注入附加的表单键值对数据
      if (options?.data) {
        const extraKeys = Object.keys(options.data);
        for (let i = 0; i < extraKeys.length; i++) {
          const key = extraKeys[i];
          formItems.push({
            name: key,
            value: options.data[key]
          });
        }
      }

      // 配置 request.agent 上传任务
      const uploadConfig: request.agent.Config = {
        action: request.agent.Action.UPLOAD,
        url: url,
        title: 'HarmonyOS File Upload Task',
        mode: request.agent.Mode.FOREGROUND,
        network: request.agent.Network.ANY,
        headers: options?.header,
        data: formItems
      };

      request.agent.create(context, uploadConfig).then((task: request.agent.Task) => {
        const cleanupListeners = (): void => {
          try {
            task.off('progress');
            task.off('completed');
            task.off('failed');
          } catch (e) {
            // 容错防崩
          }
        };

        // 监听上传进度
        task.on('progress', (progress: request.agent.Progress) => {
          const total = (progress.sizes && progress.sizes.length > 0 && progress.sizes[0] > 0) 
            ? progress.sizes[0] 
            : -1;
          const processed = progress.processed;
          const percentage = total > 0 ? Math.min(100, Math.floor((processed / total) * 100)) : 0;

          if (onProgress) {
            onProgress({
              loadedBytes: processed,
              totalBytes: total,
              percentage: percentage
            });
          }
        });

        // 监听上传成功完成
        task.on('completed', () => {
          cleanupListeners();
          hilog.info(DOMAIN, TAG, `Upload task completed successfully: ${localFilePath}`);
          resolve(true);
        });

        // 监听上传失败
        task.on('failed', () => {
          cleanupListeners();
          const errorMsg = `Upload failed for URL: ${url}`;
          hilog.error(DOMAIN, TAG, '%{public}s', errorMsg);
          reject(new Error(errorMsg));
        });

        // 启动上传任务
        task.start().catch((startErr: Error) => {
          cleanupListeners();
          hilog.error(DOMAIN, TAG, 'Failed to start upload task: %{public}s', startErr.message);
          reject(startErr);
        });
      }).catch((createErr: Error) => {
        hilog.error(DOMAIN, TAG, 'Failed to create upload task: %{public}s', createErr.message);
        reject(createErr);
      });
    });
  }
}

/**
 * 快捷导出全局默认单例
 */
export const fileTransferManager = FileTransferManager.getInstance();
