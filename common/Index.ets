/**
 * @app/common 基础设施层公共导出统一出口
 */

// 路由调度（含 NavigationGuard 路由守卫、NavRoute 强类型契约与全自动 Destination 分发）
export { AppRouter, AppRouterDestination } from './src/main/ets/router/AppRouter';
export { NavRoute } from './src/main/ets/router/NavRoute';
export { RouteRegistry } from './src/main/ets/router/RouteRegistry';
export { NavigationContext, GuardDecision, NavigationGuard } from './src/main/ets/router/AppRouter';

// 依赖注入容器（含类型安全 InjectionKey）
export { Container, container, sl, Factory, InjectionKey } from './src/main/ets/di/Container';

// 基础基类与状态定义
export { BaseViewModel, UIState } from './src/main/ets/base/BaseViewModel';
export { BaseRepository } from './src/main/ets/base/BaseRepository';
export { DataResult, DataResultSuccess, DataResultError, DataResults } from './src/main/ets/base/DataResult';
export { BaseListViewModel, PageRequest, PageResponse } from './src/main/ets/base/BaseListViewModel';

// 网络层核心与模型
export { ApiResponse, isBusinessSuccess } from './src/main/ets/http/model/ApiResponse';
export { AppHttpError, NetworkError, HttpStatusError, BusinessError } from './src/main/ets/http/model/HttpErrors';
export { SslCertificateError, SslErrorInfo } from './src/main/ets/http/model/SslCertificateError';
export { RequestOptions, RequestContext, ResponseContext, HttpMethod } from './src/main/ets/http/model/HttpOptions';
export { CancelToken, CancelTokenSource, CancelledError, CancelListener } from './src/main/ets/http/model/CancelToken';

// 拦截器体系（含指数退避自动重试）
export { HttpInterceptor } from './src/main/ets/http/interceptor/Interceptor';
export { NetworkStateInterceptor } from './src/main/ets/http/interceptor/NetworkStateInterceptor';
export { HeaderInterceptor } from './src/main/ets/http/interceptor/HeaderInterceptor';
export { AuthInterceptor, UnauthorizedHandler } from './src/main/ets/http/interceptor/AuthInterceptor';
export { LoggingInterceptor } from './src/main/ets/http/interceptor/LoggingInterceptor';
export { CertificateFailureInterceptor } from './src/main/ets/http/interceptor/CertificateFailureInterceptor';
export { RetryInterceptor, RetryConfig } from './src/main/ets/http/interceptor/RetryInterceptor';

// HTTPS 安全与证书自愈体系 (对标 Android OkHttpPinningManager)
export { RcpPinningManager, CertificateAlertListener } from './src/main/ets/http/security/RcpPinningManager';

// 双令牌生命周期管理器 (Access + Refresh Token 自动刷新)
export { TokenManager, tokenManager, TokenPair, TokenRefreshAction, TokenChangeListener } from './src/main/ets/http/security/TokenManager';

// HTTP 核心门面客户端与网络服务基类
export { HttpClient, httpClient, TimeoutConfig } from './src/main/ets/http/HttpClient';
export { BaseApiService } from './src/main/ets/http/BaseApiService';
export { HttpConfigProvider } from './src/main/ets/http/config/HttpConfigProvider';

// 本地持久化存储统一抽象门面
export { StorageManager, PreferencesStorage, StorageValue } from './src/main/ets/storage/StorageManager';

// 安全加密存储套件 (HUKS AES-256-GCM + Preferences 双层透明加密，对标 Android EncryptedSharedPreferences)
export { SecureStorageManager } from './src/main/ets/storage/SecureStorageManager';
export { HuksHelper } from './src/main/ets/crypto/HuksHelper';
export { EncryptedPayload, HuksKeyConfig, CryptoSession } from './src/main/ets/crypto/CryptoTypes';

// 系统级文件上传与下载体系 (基于 ohos.request)
export { FileTransferManager, fileTransferManager } from './src/main/ets/transfer/FileTransferManager';
export { TransferProgress, DownloadTaskOptions, UploadTaskOptions } from './src/main/ets/transfer/TransferTypes';

// MVI 架构核心套件
export { BaseMviViewModel } from './src/main/ets/mvi/BaseMviViewModel';
export { EffectListener, BaseIntent, BaseEffect } from './src/main/ets/mvi/MviTypes';

// 生物识别与多模态安全解锁套件 (对标 Android BiometricHelper)
export { BiometricHelper, biometricHelper } from './src/main/ets/biometric/BiometricHelper';
export {
  BiometricMode,
  BiometricAuthResult,
  BiometricSuccess,
  BiometricFailed,
  BiometricCanceled,
  BiometricLocked,
  BiometricNotEnrolled,
  BiometricError,
  BiometricResults,
  BiometricPromptOptions,
  BiometricCapabilityStatus
} from './src/main/ets/biometric/BiometricTypes';

// 系统权限管理套件 (对标 Android PermissionX)
export { PermissionHelper, permissionHelper, PermissionResult } from './src/main/ets/permission/PermissionHelper';
export { PermissionConfigProvider, PermissionRationale } from './src/main/ets/permission/config/PermissionConfigProvider';

// 统一依赖倒置契约门面 (Unified Dependency Inversion Facade)
export { FrameworkFacade, frameworkFacade, FrameworkContracts } from './src/main/ets/facade/FrameworkFacade';

// 框架通用对话框组件与门面调度套件
export { CommonCustomDialog } from './src/main/ets/dialog/CommonCustomDialog';
export { DialogHelper, dialogHelper } from './src/main/ets/dialog/DialogHelper';
export {
  DialogType,
  DialogAction,
  DialogOptions,
  DialogResult,
  LoadingController,
  ActionSheetItem,
  ActionSheetOptions,
  ActionSheetResult
} from './src/main/ets/dialog/DialogTypes';

// Common 基础设施层统一文本常量池
export { CommonStrings, AppStrings } from './src/main/ets/constants/AppStrings';

// 全局事件打点与端侧行为感知追踪套件 (基于 hiAppEvent 与 ArkUI uiObserver)
export { AppEventTracker, appEventTracker } from './src/main/ets/tracker/AppEventTracker';
export { BehaviorEventType, BehaviorSequenceItem, TrackerConfigProvider, TrackerEventParams } from './src/main/ets/tracker/TrackerTypes';

// 应用生命周期统一事件管理器 (前后台切换 + 网络状态感知分发)
export { AppLifecycleManager, appLifecycleManager, AppForegroundState, NetworkState, ForegroundListener, NetworkStateListener } from './src/main/ets/lifecycle/AppLifecycleManager';

// 生产级全局未捕获异常与崩溃守卫 (基于 errorManager)
export { CrashHandler, crashHandler, CrashInfo, CrashListener } from './src/main/ets/crash/CrashHandler';

// 生产级统一扫码与二维码套件 (基于 HarmonyOS NEXT 官方 Scan Kit)
export { ScanHelper, scanHelper } from './src/main/ets/scan/ScanHelper';
export { ScanCodeFormat, ScanOptions, ScanResult, QrGenerateOptions } from './src/main/ets/scan/ScanTypes';// 生产级相册与媒体安全选择器 (对标 Android MediaPickerLauncher)
export { MediaPickerHelper, mediaPickerHelper } from './src/main/ets/media/MediaPickerHelper';
export { MediaSelectType, MediaItem, MediaSelectOptions, MediaPickerResult } from './src/main/ets/media/MediaPickerTypes';

// 生产级系统剪贴板安全操作门面 (对标 Android ClipboardManager)
export { ClipboardHelper, clipboardHelper } from './src/main/ets/clipboard/ClipboardHelper';

// 生产级终端设备信息与环境感知服务 (对标 Android DeviceUtils)
export { DeviceInfoHelper, deviceInfoHelper, AppMetadata } from './src/main/ets/device/DeviceInfoHelper';

// 生产级跨组件强类型事件总线 (对标 Android EventBus)
export { AppEventBus, appEventBus, EventCallback } from './src/main/ets/event/AppEventBus';

// 关系型数据库套件 (SQLite 引擎, 对标 Android Room)
export { RdbManager, rdbManager } from './src/main/ets/database/RdbManager';
export { BaseDao } from './src/main/ets/database/BaseDao';
export { RdbConfig, Migration, RdbPageRequest, RdbPageResponse, ColumnType, ColumnDefinition, TableSchema } from './src/main/ets/database/RdbTypes';

// 生产级后台任务并发调度门面 (对标 Android Coroutines Dispatchers.IO)
export { TaskDispatcher, taskDispatcher } from './src/main/ets/concurrent/TaskDispatcher';
export { TaskPriority, TaskExecutionOptions, TaskItem, TaskPair, TaskTriple } from './src/main/ets/concurrent/TaskTypes';

// 鸿蒙全场景多屏尺寸与折叠屏自适应感知管理器 (对标 Android WindowManager/FoldableState)
export {
  DisplayAdaptiveManager,
  displayAdaptiveManager,
  BreakpointType,
  FoldStatusType,
  BreakpointConstants
} from './src/main/ets/device/BreakpointSystem';


