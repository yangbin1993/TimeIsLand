/**
 * 请求已主动取消异常
 */
export class CancelledError extends Error {
  public readonly isCancelled: boolean = true;
  public readonly reason: string;

  constructor(reason?: string) {
    super(reason || 'Request was cancelled by user');
    this.name = 'CancelledError';
    this.reason = reason || 'Request was cancelled by user';
  }
}

/**
 * 监听取消事件的回调函数签名
 */
export type CancelListener = (reason?: string) => void;

/**
 * 请求取消令牌 (CancelToken)
 * 允许调用方跨组件/跨生命周期协作式中止正在进行的异步 HTTP 请求
 */
export class CancelToken {
  private _isCancelled: boolean = false;
  private _reason?: string;
  private listeners: CancelListener[] = [];

  /**
   * 是否已触发取消
   */
  public get isCancelled(): boolean {
    return this._isCancelled;
  }

  /**
   * 取消原因描述
   */
  public get reason(): string | undefined {
    return this._reason;
  }

  /**
   * 若当前令牌已被取消，则立即抛出 CancelledError
   */
  public throwIfCancelled(): void {
    if (this._isCancelled) {
      throw new CancelledError(this._reason);
    }
  }

  /**
   * 注册取消回调监听
   *
   * @param listener 取消时触发的回调
   * @returns 注销监听的解绑函数
   */
  public onCancel(listener: CancelListener): () => void {
    if (this._isCancelled) {
      listener(this._reason);
      return () => {};
    }
    this.listeners.push(listener);
    return () => {
      const idx = this.listeners.indexOf(listener);
      if (idx !== -1) {
        this.listeners.splice(idx, 1);
      }
    };
  }

  /**
   * 内部触发取消（由 CancelTokenSource 调用）
   */
  public _cancel(reason?: string): void {
    if (this._isCancelled) {
      return;
    }
    this._isCancelled = true;
    this._reason = reason;
    const callbacks = [...this.listeners];
    this.listeners = [];
    callbacks.forEach((cb) => {
      try {
        cb(reason);
      } catch (err) {
        // 捕获单个 listener 异常，保证其余正常回调
      }
    });
  }

  /**
   * 快速构造配对的 CancelTokenSource
   */
  public static source(): CancelTokenSource {
    const token = new CancelToken();
    return {
      token: token,
      cancel: (reason?: string) => {
        token._cancel(reason);
      }
    };
  }
}

/**
 * 取消控制器包装结构
 */
export interface CancelTokenSource {
  /**
   * 绑定的 CancelToken 实例
   */
  token: CancelToken;

  /**
   * 发起取消触发指令
   * @param reason 取消的原因描述
   */
  cancel: (reason?: string) => void;
}
