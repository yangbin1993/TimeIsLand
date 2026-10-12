/**
 * Common 模块基础设施层统一文本常量池 (CommonStrings)
 * 对应多模块架构中的 Framework/common 模块层级
 * 集中管理通用网络、SSL 证书自愈、文件传输、生物识别、数据仓库等基础能力相关文本
 */
export class CommonStrings {
  // ==================== 网络状态与通用网络通信 ====================
  public static readonly NET_NONE = '网络不可用，请检查网络设置';
  public static readonly NET_ERROR = '网络连接失败，请检查网络';
  public static readonly NET_TIMEOUT = '网络连接超时，请稍后重试';
  public static readonly NET_FAST_FAIL = '当前设备处于离线状态，网络不可达（已触发快速熔断保护）';
  public static readonly NET_WIFI_ONLY_BLOCK = '当前网络处于蜂窝数据状态，已根据配置拦截非 WiFi 请求';
  public static readonly NET_DEFAULT_FAILURE = '网络连接异常，请检查网络设置';
  public static readonly NET_TOKEN_EXPIRED = '登录信息已过期，请重新登录';
  public static readonly NET_BUSINESS_FAILED = '业务请求失败';
  public static readonly HTTP_STATUS_PREFIX = 'HTTP 协议状态异常: ';

  // ==================== SSL 与证书安全自愈 ====================
  public static readonly SSL_SECURITY_INTERCEPT = '网络安全证书校验失败，连接已被安全机制拦截';
  public static readonly SSL_EXPIRED = '服务端安全证书已过期，无法建立安全连接';
  public static readonly SSL_PINNING_MISMATCH = '服务端证书公钥指纹不匹配，可能存在中间人攻击或证书已变更';
  public static readonly SSL_FALLBACK_REASON = '逃生通道自愈失败，客户端已开启全局系统 CA 降级退守';
  public static readonly SSL_EXPIRED_TIP = '服务器安全证书已过期，正在紧急修复中';
  public static readonly SSL_MISMATCH_TIP = '安全证书校验失败，请检查网络环境或系统时间';

  // ==================== 文件传输 (上传/下载) ====================
  public static readonly DOWNLOAD_INIT = '正在发起下载任务...';
  public static readonly DOWNLOAD_SAVED_PREFIX = '下载完成，已保存至: ';
  public static readonly DOWNLOAD_DEMO_DONE = '下载演示完成 (沙箱保存已就绪)';
  public static readonly UPLOAD_PREPARING = '正在准备上传数据...';
  public static readonly UPLOAD_SUCCESS = '上传成功完成！服务端已接收附件';
  public static readonly CANNOT_GET_SIZE = '无法获取文件尺寸大小';
  public static readonly FILE_NOT_FOUND_PREFIX = '本地文件不存在: ';
  public static readonly FILE_EMPTY = '无法上传空文件';

  // ==================== 生物识别与多模态解锁 ====================
  public static readonly BIO_TITLE_DEFAULT = '验证身份以开启安全权限';
  public static readonly BIO_TITLE_BIO_ONLY = '验证指纹或面部信息';
  public static readonly BIO_SUBTITLE_DEFAULT = '请验证指纹、面部或锁屏密码以继续操作';
  public static readonly BIO_CANCEL_TEXT = '取消认证';
  public static readonly BIO_TYPE_CREDENTIAL = '设备凭据';
  public static readonly BIO_TYPE_FINGERPRINT = '指纹识别';
  public static readonly BIO_TYPE_FACE = '面部识别';
  public static readonly BIO_TYPE_PIN = '锁屏密码';
  public static readonly BIO_SUCCESS_PREFIX = '认证成功！通过方式: ';
  public static readonly BIO_FAILED_DEFAULT = '身份认证未匹配';
  public static readonly BIO_CANCELED = '用户主动取消了身份认证';
  public static readonly BIO_LOCKED = '尝试次数过多，生物识别已暂时锁定';
  public static readonly BIO_NOT_ENROLLED = '设备未录入生物识别信息或未设置锁屏密码';
  public static readonly BIO_UNSUPPORTED_BIO = '设备未录入人脸或指纹等生物识别信息';
  public static readonly BIO_UNSUPPORTED_PIN = '设备未设置锁屏密码或 PIN 码';
  public static readonly BIO_UNSUPPORTED_ALL = '设备未录入生物识别且未设置锁屏密码';
  public static readonly BIO_UNSUPPORTED_DEVICE = '当前设备不支持所选认证方式';
  public static readonly BIO_LAUNCH_FAILED = '启动系统身份认证失败';

  // ==================== 数据仓库与异常封装 ====================
  public static readonly REPO_NET_ERROR = '当前网络不可用，请检查网络连接';
  public static readonly REPO_HTTP_ERROR_PREFIX = '服务器通信异常';
  public static readonly REPO_BUSINESS_ERROR_DEFAULT = '业务请求失败';
  public static readonly REPO_UNKNOWN_ERROR = '未知数据异常，请稍后重试';

  // ==================== 基础分页与列表 ViewModel ====================
  public static readonly LIST_LOAD_FAILED = '加载失败，请稍后重试';
  public static readonly LIST_REFRESH_FAILED = '刷新失败，请稍后重试';
  public static readonly LIST_LOAD_MORE_FAILED = '加载更多失败';

  // ==================== 通用对话框组件文本 ====================
  public static readonly DIALOG_DEFAULT_TITLE = '操作提示';
  public static readonly DIALOG_CONFIRM = '确定';
  public static readonly DIALOG_CANCEL = '取消';
  public static readonly DIALOG_KNOW = '我知道了';
  public static readonly DIALOG_LOADING = '加载中...';
  public static readonly DIALOG_INPUT_PLACEHOLDER = '请输入内容';
  public static readonly DIALOG_LOGOUT_TITLE = '确认退出登录';
  public static readonly DIALOG_LOGOUT_MESSAGE = '退出登录后将清除本地会话状态，您需要重新输入凭证。确定要继续吗？';
  public static readonly DIALOG_LOGOUT_CONFIRM = '确认退出';
  public static readonly DIALOG_SHOWCASE_TITLE = '通用对话框体验中心';
  public static readonly DIALOG_SHOWCASE_SUBTITLE = '集成 DialogHelper 纯命令式调度与 CommonCustomDialog 声明式组件，具备完备的取消异常平滑拦截与端侧行为特征感知。';
  public static readonly DIALOG_TOAST_DEMO = '这是一条轻量级全局 Toast 浮层提示';
  public static readonly DIALOG_ALERT_TITLE = '系统维护通知';
  public static readonly DIALOG_ALERT_MSG = '核心网络基座与安全自愈机制已完成升级，各项能力运行正常。';
  public static readonly DIALOG_CONFIRM_TITLE = '清空本地数据缓存';
  public static readonly DIALOG_CONFIRM_MSG = '将清空临时沙箱文件与已下载的附件，本地未保存草稿可能丢失。确定要继续吗？';
  public static readonly DIALOG_DANGER_TITLE = '注销账户警告';
  public static readonly DIALOG_DANGER_MSG = '此操作将彻底删除您的用户身份凭证与生物识别记录，且不可恢复！确定注销吗？';
  public static readonly DIALOG_DANGER_CONFIRM = '确认彻底注销';
  public static readonly DIALOG_INPUT_TITLE = '输入个性签名';
  public static readonly DIALOG_INPUT_MSG = '请输入您的个性签名，将展示在个人中心。';
  public static readonly DIALOG_LOADING_MSG = '正在提交请求并同步远端数据...';
  public static readonly DIALOG_RESULT_PREFIX = '交互响应结果: ';
  public static readonly DIALOG_RESULT_CONFIRMED = '用户点击了【确认】';
  public static readonly DIALOG_RESULT_CANCELED = '用户点击了【取消】或通过蒙层/返回手势关闭';
  public static readonly DIALOG_RESULT_INPUT = '用户提交输入内容: ';


  // ==================== 权限管理与二次挽回文本 ====================
  public static readonly PERM_AUTH_GOTO = '去授权';
  public static readonly PERM_AUTH_ALLOW = '允许';
  public static readonly PERM_NAME_LOCATION = '位置权限';
  public static readonly PERM_NAME_CAMERA = '相机权限';
  public static readonly PERM_NAME_MIC = '麦克风权限';
  public static readonly PERM_NAME_MEDIA = '相册媒体权限';
  public static readonly PERM_NAME_DEFAULT = '相关功能权限';
  public static readonly PERM_RATIONALE_TITLE_DEFAULT = '权限申请说明';
  public static readonly PERM_DEFAULT_RATIONALE_MSG = '为了给您提供完整的业务功能与服务，需要获取相关系统权限。';
  public static readonly PERM_RATIONALE_CONFIRM = '继续授权';
  public static readonly PERM_RATIONALE_CANCEL = '暂不';
  public static readonly PERM_DENIED_TITLE = '权限已被关闭';
  public static readonly PERM_DENIED_PREFIX = '您已关闭【';
  public static readonly PERM_DENIED_SUFFIX = '】，相关核心功能已受限。如需继续使用，请前往系统“设置”页手动开启。';
  public static readonly PERM_GO_SETTINGS = '前往设置';
  public static readonly PERM_LOCATION_TITLE = '需要精准位置权限';
  public static readonly PERM_LOCATION_MSG = '为了向您推荐周边的实时商户信息、导航路线与本地化特色内容，应用需要获取您的精确位置。';
  public static readonly PERM_APPROX_LOCATION_TITLE = '需要模糊位置权限';
  public static readonly PERM_APPROX_LOCATION_MSG = '为了根据您的大致城市与区域提供天气预报和本地化信息，应用需要获取您的模糊位置。';
  public static readonly PERM_CAMERA_TITLE = '需要相机访问权限';
  public static readonly PERM_CAMERA_MSG = '为了支持拍摄照片、更新个人头像以及扫描二维码功能，应用需要访问您的设备相机。';
  public static readonly PERM_MIC_TITLE = '需要麦克风访问权限';
  public static readonly PERM_MIC_MSG = '为了支持语音输入、录音留言与语音搜索功能，应用需要访问您的麦克风。';
  public static readonly PERM_MEDIA_TITLE = '需要多媒体访问权限';
  public static readonly PERM_MEDIA_MSG = '为了支持从系统相册选取并上传照片与视频附件，应用需要读取您的多媒体文件。';
  public static readonly PERM_NAME_PASTEBOARD = '剪贴板权限';
  public static readonly PERM_PASTEBOARD_TITLE = '需要读取剪贴板权限';
  public static readonly PERM_PASTEBOARD_MSG = '为了提供快速粘贴、口令识别与快捷搜索服务，应用需要读取您的剪贴板内容。';

  // ==================== 统一扫码套件文本 ====================
  public static readonly SCAN_DEFAULT_TITLE = '扫一扫';
  public static readonly SCAN_SUCCESS = '扫码识别成功';
  public static readonly SCAN_CANCELED = '用户取消了本次扫码';
  public static readonly SCAN_FAILED = '扫码服务调用失败，请检查系统服务状态';
  public static readonly SCAN_NO_RESULT = '未识别到有效的二维码或条形码';
  public static readonly SCAN_GENERATE_EMPTY = '生成二维码内容不能为空';
  public static readonly SCAN_GENERATE_SUCCESS = '二维码已成功生成';
  public static readonly SCAN_GENERATE_FAILED = '生成二维码位图失败';
  public static readonly SCAN_UNSUPPORTED_DEVICE = '当前终端硬件形态不支持扫码识别能力';
  public static readonly SCAN_GENERATE_UNSUPPORTED = '当前终端硬件形态不支持码制生成能力';
}


