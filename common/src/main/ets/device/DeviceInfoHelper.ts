import { deviceInfo } from '@kit.BasicServicesKit';
import { bundleManager, common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

const TAG: string = 'DeviceInfoHelper';
const DOMAIN: number = 0x0000;

/**
 * 应用程序元数据契约
 */
export interface AppMetadata {
  /**
   * 应用包名 (BundleName)
   */
  bundleName: string;

  /**
   * 业务对外展示版本名 (如 "1.0.0")
   */
  versionName: string;

  /**
   * 内部构建版本号 (如 1000000)
   */
  versionCode: number;

  /**
   * 应用名称
   */
  appName?: string;
}

/**
 * 生产级设备信息与系统环境感知服务 (DeviceInfoHelper)
 * 深度对标 Android DeviceUtils / AppUtils
 * 
 * 核心架构特性：
 * 1. 深度整合 HarmonyOS deviceInfo 系统级只读硬件属性；
 * 2. 结合 bundleManager 提供异步/同步应用包信息解析；
 * 3. 构造标准规范的 User-Agent 标头供 HttpClient 统一接入；
 * 4. 支持设备形态判定 (手机/平板/车机/智慧屏)，赋能大屏与折叠屏自适应。
 */
export class DeviceInfoHelper {
  private static instance: DeviceInfoHelper;
  private cachedMetadata?: AppMetadata;

  private constructor() {}

  /**
   * 获取 DeviceInfoHelper 全局统一单例
   */
  public static getInstance(): DeviceInfoHelper {
    if (!DeviceInfoHelper.instance) {
      DeviceInfoHelper.instance = new DeviceInfoHelper();
    }
    return DeviceInfoHelper.instance;
  }

  /**
   * 获取设备品牌 (如 "HUAWEI")
   */
  public getBrand(): string {
    return deviceInfo.brand || 'Unknown';
  }

  /**
   * 获取终端产品型号 (如 "ALN-AL00")
   */
  public getProductModel(): string {
    return deviceInfo.productModel || 'Unknown';
  }

  /**
   * 获取操作系统完整版本描述 (如 "OpenHarmony 5.0.0.120")
   */
  public getOsFullName(): string {
    return deviceInfo.osFullName || 'Unknown OS';
  }

  /**
   * 获取当前系统 SDK API 级别 (如 12)
   */
  public getSdkApiVersion(): number {
    return deviceInfo.sdkApiVersion;
  }

  /**
   * 获取设备物理类型 (phone / tablet / 2in1 / tv / wearable / car)
   */
  public getDeviceType(): string {
    return deviceInfo.deviceType || 'phone';
  }

  /**
   * 判断当前终端是否为平板电脑
   */
  public isTablet(): boolean {
    return this.getDeviceType().toLowerCase() === 'tablet';
  }

  /**
   * 判断当前终端是否为智能手机
   */
  public isPhone(): boolean {
    return this.getDeviceType().toLowerCase() === 'phone';
  }

  /**
   * 判断当前终端是否为 2in1 电脑形态
   */
  public is2in1(): boolean {
    return this.getDeviceType().toLowerCase() === '2in1';
  }

  /**
   * 获取当前应用安装包的元数据信息 (异步读取并内存缓存)
   *
   * @param context 应用上下文
   * @returns 强类型 AppMetadata 实体
   */
  public async getAppMetadata(context: common.Context): Promise<AppMetadata> {
    if (this.cachedMetadata) {
      return this.cachedMetadata;
    }

    try {
      const bundleFlags = bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT;
      const bundleInfo = await bundleManager.getBundleInfoForSelf(bundleFlags);

      this.cachedMetadata = {
        bundleName: bundleInfo.name,
        versionName: bundleInfo.versionName,
        versionCode: bundleInfo.versionCode
      };
      hilog.info(DOMAIN, TAG, `AppMetadata parsed: ${this.cachedMetadata.bundleName} v${this.cachedMetadata.versionName}`);
      return this.cachedMetadata;
    } catch (err) {
      hilog.error(DOMAIN, TAG, `Failed to get bundle info: ${(err as Error).message}`);
      return {
        bundleName: 'unknown.bundle',
        versionName: '1.0.0',
        versionCode: 1000000
      };
    }
  }

  /**
   * 构造符合标准的 HTTP Client User-Agent 字符串
   * 格式: AppName/Version (DeviceBrand; ProductModel; OSFullName; API/ApiVersion)
   *
   * @param appName 自定义应用名 (默认 HarmonyApp)
   * @param versionName 自定义版本名 (默认 1.0.0)
   */
  public buildUserAgent(appName: string = 'HarmonyApp', versionName: string = '1.0.0'): string {
    const brand = this.getBrand();
    const model = this.getProductModel();
    const os = this.getOsFullName();
    const api = this.getSdkApiVersion();

    return `${appName}/${versionName} (${brand}; ${model}; ${os}; API/${api})`;
  }
}

/**
 * 快捷导出全局设备信息门面单例
 */
export const deviceInfoHelper: DeviceInfoHelper = DeviceInfoHelper.getInstance();
