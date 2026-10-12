import { hilog } from '@kit.PerformanceAnalysisKit';
import { DataResult, DataResults } from './DataResult';
import { CommonStrings } from '../constants/CommonStrings';

const TAG = 'BaseListViewModel';
const DOMAIN = 0x0000;

/**
 * 分页列表请求标准参数契约
 */
export interface PageRequest {
  /**
   * 当前页码（从 1 开始）
   */
  page: number;

  /**
   * 每页数据条目数量
   */
  pageSize: number;
}

/**
 * 分页数据响应标准契约
 */
export interface PageResponse<T> {
  /**
   * 当前页业务数据列表
   */
  items: T[];

  /**
   * 数据总条目数（服务端提供，用于前端推断是否已加载完毕）
   */
  total: number;

  /**
   * 是否还有更多数据（优先级高于 total 推算）
   * 若服务端直接返回 hasMore 字段则以此为准
   */
  hasMore?: boolean;
}

/**
 * 生产级通用分页列表状态机基类 (BaseListViewModel<T>)
 * 基于 HarmonyOS ArkUI 状态管理 V2 (@ObservedV2/@Trace) 深度构建
 *
 * 封装了企业级分页列表开发中 90% 的重复样板逻辑：
 * - 首次加载（初始化骨架屏状态）
 * - 下拉刷新（重置分页、清空列表、重新加载第一页）
 * - 上拉加载更多（追加数据、更新分页指针、更新 hasMore 状态）
 * - 空态判断（成功但无数据）
 * - 并发防抖（加载中忽略重复触发）
 * - 加载失败状态收口（区分首次加载与加载更多的错误处理）
 *
 * @template T 列表单条目数据实体类型
 */
@ObservedV2
export abstract class BaseListViewModel<T extends Object> {
  /**
   * 当前渲染的完整列表数据
   */
  @Trace public items: T[] = [];

  /**
   * 是否正在执行首次加载（骨架屏状态控制）
   */
  @Trace public isInitialLoading: boolean = false;

  /**
   * 是否正在执行下拉刷新
   */
  @Trace public isRefreshing: boolean = false;

  /**
   * 是否正在加载更多（上拉加载状态，底部加载 Footer 显示控制）
   */
  @Trace public isLoadingMore: boolean = false;

  /**
   * 是否还有更多数据可供加载
   */
  @Trace public hasMore: boolean = true;

  /**
   * 列表数据为空时展示空态组件
   */
  @Trace public isEmpty: boolean = false;

  /**
   * 首次加载错误时的错误文案
   */
  @Trace public errorMessage: string = '';

  /**
   * 是否处于首次加载错误状态
   */
  @Trace public hasError: boolean = false;

  /**
   * 加载更多操作遭遇错误时的提示文案（区别于全屏 errorMessage）
   */
  @Trace public loadMoreErrorMessage: string = '';

  /**
   * 数据总条目数
   */
  @Trace public total: number = 0;

  // ==================== 分页状态（私有，不影响 UI 响应） ====================

  private currentPage: number = 1;
  private readonly pageSize: number;

  protected constructor(pageSize: number = 20) {
    this.pageSize = pageSize;
    hilog.info(DOMAIN, TAG, `${this.constructor.name} initialized with pageSize=${pageSize}`);
  }

  // ==================== 子类必须实现的数据加载抽象方法 ====================

  /**
   * 实际数据加载方法（由子类实现，对接 Repository 或 ApiService）
   *
   * @param request 标准分页请求参数（page + pageSize）
   * @returns 标准分页数据结果 DataResult<PageResponse<T>>
   */
  protected abstract fetchPage(request: PageRequest): Promise<DataResult<PageResponse<T>>>;

  // ==================== 公共调度方法 ====================

  /**
   * 执行首次初始化加载
   * 适用于页面 aboutToAppear / onInit 时触发首屏数据拉取
   */
  public async loadInitial(): Promise<void> {
    if (this.isInitialLoading) {
      return;
    }

    this.isInitialLoading = true;
    this.hasError = false;
    this.errorMessage = '';
    this.currentPage = 1;

    try {
      const result = await this.fetchPage({ page: 1, pageSize: this.pageSize });
      if (DataResults.isSuccess(result)) {
        const pageResp = result.data;
        this.items = [...pageResp.items];
        this.total = pageResp.total;
        this.hasMore = this.resolveHasMore(pageResp);
        this.isEmpty = this.items.length === 0;
        hilog.info(DOMAIN, TAG, `Initial load success: ${this.items.length} items, total=${this.total}`);
      } else {
        this.hasError = true;
        this.errorMessage = result.message;
        this.isEmpty = false;
        hilog.error(DOMAIN, TAG, `Initial load failed: ${result.message}`);
      }
    } catch (err) {
      this.hasError = true;
      this.errorMessage = (err as Error).message || CommonStrings.LIST_LOAD_FAILED;
      hilog.error(DOMAIN, TAG, `Initial load exception: ${this.errorMessage}`);
    } finally {
      this.isInitialLoading = false;
    }
  }

  /**
   * 执行下拉刷新
   * 重置分页指针、清空列表，重新加载第一页数据
   * 适用于 Refresh 组件的 onRefreshing 回调
   */
  public async refresh(): Promise<void> {
    if (this.isRefreshing || this.isLoadingMore) {
      return;
    }

    this.isRefreshing = true;
    this.hasError = false;
    this.errorMessage = '';
    this.loadMoreErrorMessage = '';
    this.currentPage = 1;

    try {
      const result = await this.fetchPage({ page: 1, pageSize: this.pageSize });
      if (DataResults.isSuccess(result)) {
        const pageResp = result.data;
        this.items = [...pageResp.items];
        this.total = pageResp.total;
        this.hasMore = this.resolveHasMore(pageResp);
        this.isEmpty = this.items.length === 0;
        hilog.info(DOMAIN, TAG, `Refresh success: ${this.items.length} items`);
      } else {
        // 刷新失败保留旧数据，仅更新错误提示
        this.errorMessage = result.message;
        hilog.warn(DOMAIN, TAG, `Refresh failed: ${result.message}`);
      }
    } catch (err) {
      this.errorMessage = (err as Error).message || CommonStrings.LIST_REFRESH_FAILED;
      hilog.error(DOMAIN, TAG, `Refresh exception: ${this.errorMessage}`);
    } finally {
      this.isRefreshing = false;
    }
  }

  /**
   * 执行上拉加载更多
   * 追加下一页数据到现有列表
   * 适用于 LazyForEach 底部触达 / List onReachEnd 回调
   */
  public async loadMore(): Promise<void> {
    if (!this.hasMore || this.isLoadingMore || this.isRefreshing || this.isInitialLoading) {
      return;
    }

    this.isLoadingMore = true;
    this.loadMoreErrorMessage = '';
    const nextPage = this.currentPage + 1;

    try {
      const result = await this.fetchPage({ page: nextPage, pageSize: this.pageSize });
      if (DataResults.isSuccess(result)) {
        const pageResp = result.data;
        // 追加模式：将新数据拼接至现有列表末尾
        this.items = [...this.items, ...pageResp.items];
        this.total = pageResp.total;
        this.hasMore = this.resolveHasMore(pageResp);
        this.currentPage = nextPage;
        hilog.info(DOMAIN, TAG, `LoadMore success: +${pageResp.items.length} items, page=${nextPage}, hasMore=${this.hasMore}`);
      } else {
        this.loadMoreErrorMessage = result.message;
        hilog.warn(DOMAIN, TAG, `LoadMore failed: ${result.message}`);
      }
    } catch (err) {
      this.loadMoreErrorMessage = (err as Error).message || CommonStrings.LIST_LOAD_MORE_FAILED;
      hilog.error(DOMAIN, TAG, `LoadMore exception: ${this.loadMoreErrorMessage}`);
    } finally {
      this.isLoadingMore = false;
    }
  }

  /**
   * 手动追加单条数据到列表头部（如实时推送场景）
   */
  public prependItem(item: T): void {
    this.items = [item, ...this.items];
    this.total += 1;
    this.isEmpty = false;
  }

  /**
   * 手动追加单条数据到列表尾部
   */
  public appendItem(item: T): void {
    this.items = [...this.items, item];
    this.total += 1;
    this.isEmpty = false;
  }

  /**
   * 按索引移除列表中的某一条目（如滑动删除场景）
   *
   * @param index 要移除的条目在当前 items 数组中的索引
   */
  public removeItemAt(index: number): void {
    if (index < 0 || index >= this.items.length) {
      return;
    }
    const newItems = [...this.items];
    newItems.splice(index, 1);
    this.items = newItems;
    this.total = Math.max(0, this.total - 1);
    this.isEmpty = this.items.length === 0;
  }

  /**
   * 获取当前已加载的页码
   */
  public getCurrentPage(): number {
    return this.currentPage;
  }

  /**
   * 获取当前配置的每页条目数
   */
  public getPageSize(): number {
    return this.pageSize;
  }

  /**
   * 重置列表至初始空状态（不触发网络请求，用于页面路由复用场景）
   */
  public reset(): void {
    this.items = [];
    this.currentPage = 1;
    this.hasMore = true;
    this.isEmpty = false;
    this.hasError = false;
    this.errorMessage = '';
    this.loadMoreErrorMessage = '';
    this.isInitialLoading = false;
    this.isRefreshing = false;
    this.isLoadingMore = false;
    this.total = 0;
  }

  /**
   * 推断是否还有更多数据
   * 优先使用服务端直接返回的 hasMore 字段；
   * 若无，则通过 total 与当前已加载条目数推算
   */
  private resolveHasMore(pageResp: PageResponse<T>): boolean {
    if (typeof pageResp.hasMore === 'boolean') {
      return pageResp.hasMore;
    }
    return this.items.length < pageResp.total;
  }
}
