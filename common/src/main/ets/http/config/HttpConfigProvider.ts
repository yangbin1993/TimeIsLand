/**
 * 网络客户端动态配置提供者抽象契约 (HttpConfigProvider)
 * 核心设计遵循 SOLID 中的依赖倒置原则 (DIP - Dependency Inversion Principle)
 * 
 * 核心架构职责：
 * 1. 抽象基础配置：common 基础设施库不硬编码任何具体业务域名、环境参数或业务头；
 * 2. 控制权反转 (IoC)：基础库定义配置规范，由具体的业务宿主模块 (entry 或多应用) 在启动时实现并注入；
 * 3. 动态多环境自适应：支持业务层在运行时根据 Debug/Release、租户或灰度动态提供不同的 BaseUrl 与超时设置。
 */
export interface HttpConfigProvider {
  /**
   * 获取当前网络请求的基础服务器域名 (BaseUrl)
   * 示例：'https://api.example.com' 或 'https://dev-api.example.com'
   */
  getBaseUrl(): string;

  /**
   * 获取全局业务请求头集合 (如客户端版本号、渠道号、设备唯一标识等)
   * 每次请求时动态计算，支持动态凭据追加
   */
  getCommonHeaders?(): Record<string, string>;

  /**
   * 连接建立超时时间 (毫秒)
   */
  getConnectTimeoutMs?(): number;

  /**
   * 数据传输与响应读取超时时间 (毫秒)
   */
  getTransferTimeoutMs?(): number;

  /**
   * 当前是否处于调试模式 (用于控制全量日志打印、Mock 拦截等)
   */
  isDebug?(): boolean;
}
