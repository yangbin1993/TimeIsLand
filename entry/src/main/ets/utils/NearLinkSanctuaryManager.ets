import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { advertising, scan, dataTransfer, constant } from '@kit.NearLinkKit';
import { permissionHelper } from '@app/common';
import { NearLinkConfig } from './NearLinkConfig';

const DOMAIN = 0x0000;
const TAG = 'NearLinkSanctuary';

/**
 * 星闪双子岛连接状态枚举
 */
export enum NearLinkSanctuaryState {
  IDLE = 'IDLE',
  SCANNING = 'SCANNING',
  BROADCASTING = 'BROADCASTING',
  CONNECTED = 'CONNECTED',
  SIMULATED = 'SIMULATED'
}

/**
 * 伴读岛屿实体
 */
export class PartnerIslandInfo {
  public partnerId: string;
  public islandName: string;
  public currentTag: string;
  public partnerFocusMinutes: number;
  public isPartnerFocusing: boolean;
  public lastRippleTimestamp: number;

  constructor(
    partnerId: string = 'island_peer_001',
    islandName: string = 'PineListeningIsland',
    currentTag: string = 'Philosophy',
    partnerFocusMinutes: number = 25,
    isPartnerFocusing: boolean = true,
    lastRippleTimestamp: number = 0
  ) {
    this.partnerId = partnerId;
    this.islandName = islandName;
    this.currentTag = currentTag;
    this.partnerFocusMinutes = partnerFocusMinutes;
    this.isPartnerFocusing = isPartnerFocusing;
    this.lastRippleTimestamp = lastRippleTimestamp;
  }
}

export type SanctuaryStateListener = (state: NearLinkSanctuaryState, partner: PartnerIslandInfo | null) => void;
export type RippleReceivedListener = (fromName: string) => void;

/**
 * 时光岛 - 星闪近场双子岛无声陪伴自习室管理器 (NearLink Sanctuary)
 * 职责: 手机背靠背“碰一碰”近场组网，建立同频无声自习室，支持真实星闪微风涟漪互送
 */
export class NearLinkSanctuaryManager {
  private static instance: NearLinkSanctuaryManager | null = null;
  private isNearLinkHardwareSupported: boolean = false;
  private currentState: NearLinkSanctuaryState = NearLinkSanctuaryState.IDLE;
  private currentPartner: PartnerIslandInfo | null = null;
  private activeAdvertiseId: number = -1;
  private activePartnerAddress: string = '';
  private isPortCreated: boolean = false;

  private stateListeners: SanctuaryStateListener[] = [];
  private rippleListeners: RippleReceivedListener[] = [];

  // 保存固定的事件监听回调引用，便于生命周期精确解绑
  private deviceFoundCallback = (results: Array<scan.ScanResults>): void => {
    this.handleDeviceFound(results);
  };

  private dataReadCallback = (params: dataTransfer.DataParams): void => {
    this.handleIncomingData(params);
  };

  private connectionStateCallback = (res: dataTransfer.ConnectionResult): void => {
    this.handleConnectionStateChanged(res);
  };

  public static getInstance(): NearLinkSanctuaryManager {
    if (!NearLinkSanctuaryManager.instance) {
      NearLinkSanctuaryManager.instance = new NearLinkSanctuaryManager();
    }
    return NearLinkSanctuaryManager.instance;
  }

  constructor() {
    this.detectHardware();
  }

  /**
   * 运行时检测设备是否搭载星闪硬件与底层通信能力
   */
  private detectHardware(): void {
    try {
      this.isNearLinkHardwareSupported = canIUse('SystemCapability.Communication.NearLink.Core');
      hilog.info(DOMAIN, TAG, 'NearLink hardware support: %{public}s', this.isNearLinkHardwareSupported ? 'true' : 'false');
    } catch (err) {
      this.isNearLinkHardwareSupported = false;
      hilog.warn(DOMAIN, TAG, 'NearLink detection error: %{public}s', JSON.stringify(err));
    }
  }

  public isHardwareSupported(): boolean {
    return this.isNearLinkHardwareSupported;
  }

  /**
   * 动态申请星闪近场通信权限（支持被拒后引导弹窗并跳转系统设置页）
   */
  public async requestNearLinkPermission(context: common.UIAbilityContext): Promise<boolean> {
    const result = await permissionHelper.requestWithGuide(context, ['ohos.permission.ACCESS_NEARLINK']);
    return result.allGranted;
  }

  public getState(): NearLinkSanctuaryState {
    return this.currentState;
  }

  public getPartner(): PartnerIslandInfo | null {
    return this.currentPartner;
  }

  public addStateListener(listener: SanctuaryStateListener): void {
    this.stateListeners.push(listener);
  }

  public removeStateListener(listener: SanctuaryStateListener): void {
    this.stateListeners = this.stateListeners.filter(l => l !== listener);
  }

  public addRippleListener(listener: RippleReceivedListener): void {
    this.rippleListeners.push(listener);
  }

  public removeRippleListener(listener: RippleReceivedListener): void {
    this.rippleListeners = this.rippleListeners.filter(l => l !== listener);
  }

  private notifyStateChanged(): void {
    this.stateListeners.forEach(l => l(this.currentState, this.currentPartner));
  }

  private notifyRippleReceived(fromName: string): void {
    this.rippleListeners.forEach(l => l(fromName));
  }

  /**
   * 启动星闪近场广播与扫描 (碰一碰感应与真机组网握手)
   */
  public async startTouchAndSanctuary(): Promise<void> {
    const isAppNearlinkEnabled = AppStorage.get<boolean>('isNearlinkEnabled') ?? true;
    if (!isAppNearlinkEnabled) {
      hilog.info(DOMAIN, TAG, 'NearLink skipped: disabled in application settings by user');
      return;
    }

    if (!this.isNearLinkHardwareSupported) {
      hilog.info(DOMAIN, TAG, 'No NearLink chip detected. Switching to Sanctuary Sandbox Simulation mode.');
      this.startSandboxSimulation();
      return;
    }

    // 检查星闪运行时权限 (ACCESS_NEARLINK)
    const hasNearlinkPerm = await permissionHelper.checkPermission('ohos.permission.ACCESS_NEARLINK');
    if (!hasNearlinkPerm) {
      hilog.info(DOMAIN, TAG, 'NearLink permission not granted. Gracefully degrading to Sanctuary Sandbox Simulation mode.');
      this.startSandboxSimulation();
      return;
    }

    const serviceUuid = NearLinkConfig.getServiceUuid();

    try {
      this.currentState = NearLinkSanctuaryState.SCANNING;
      this.notifyStateChanged();

      // 1. 初始化星闪点对点数据传输端口 (dataTransfer)
      if (!this.isPortCreated) {
        try {
          dataTransfer.createPort(serviceUuid);
          this.isPortCreated = true;
          dataTransfer.on('connectionStateChanged', this.connectionStateCallback);
          dataTransfer.on('readData', this.dataReadCallback);
          hilog.info(DOMAIN, TAG, 'NearLink dataTransfer port created for UUID: %{public}s', serviceUuid);
        } catch (portErr) {
          hilog.warn(DOMAIN, TAG, 'NearLink dataTransfer createPort error: %{public}s', JSON.stringify(portErr));
        }
      }

      // 2. 发射星闪近场广播 (携带有独立配置的 Service UUID 与设备名称)
      try {
        const settings: advertising.AdvertisingSettings = {
          interval: 5000,
          isConnectable: true
        };
        const advData: advertising.AdvertisingData = {
          serviceUuids: [serviceUuid],
          includeDeviceName: true
        };
        const params: advertising.AdvertisingParams = {
          advertisingSettings: settings,
          advertisingData: advData
        };

        this.activeAdvertiseId = await advertising.startAdvertising(params);
        hilog.info(DOMAIN, TAG, 'NearLink advertising started, id: %{public}d', this.activeAdvertiseId);
      } catch (advErr) {
        hilog.warn(DOMAIN, TAG, 'NearLink advertising warning (permission or state): %{public}s', JSON.stringify(advErr));
      }

      // 3. 启动星闪近场扫描并注册真实设备发现回调
      try {
        scan.on('deviceFound', this.deviceFoundCallback);
        const filters: scan.ScanFilters[] = [{
          deviceName: NearLinkConfig.DEVICE_BROADCAST_NAME
        }];
        await scan.startScan(filters);
        hilog.info(DOMAIN, TAG, 'NearLink scanning started with filter: %{public}s', NearLinkConfig.DEVICE_BROADCAST_NAME);
      } catch (scanErr) {
        hilog.warn(DOMAIN, TAG, 'NearLink scan warning: %{public}s', JSON.stringify(scanErr));
      }

    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'startTouchAndSanctuary hardware exception, falling back to sandbox: %{public}s', JSON.stringify(err));
      this.startSandboxSimulation();
    }
  }

  /**
   * 处理星闪扫描到的物理设备
   */
  private handleDeviceFound(results: Array<scan.ScanResults>): void {
    if (this.currentState !== NearLinkSanctuaryState.SCANNING || !results || results.length === 0) {
      return;
    }

    const target = results[0];
    if (!target || !target.address) {
      return;
    }

    hilog.info(DOMAIN, TAG, 'Discovered NearLink companion target: %{public}s, rssi: %{public}d', target.address, target.rssi);
    this.activePartnerAddress = target.address;

    // 发现目标后停止扫描，减少射频开销与功耗
    try {
      scan.off('deviceFound', this.deviceFoundCallback);
      scan.stopScan().catch(() => {});
    } catch (scanErr) {
      hilog.warn(DOMAIN, TAG, 'Failed to stop scan after device found: %{public}s', JSON.stringify(scanErr));
    }

    // 建立星闪点对点数据连接
    try {
      const connParams: dataTransfer.ConnectionParams = {
        address: target.address,
        uuid: NearLinkConfig.getServiceUuid()
      };
      dataTransfer.connect(connParams).catch((err: Object) => {
        hilog.warn(DOMAIN, TAG, 'dataTransfer connect error: %{public}s', JSON.stringify(err));
      });
    } catch (connErr) {
      hilog.warn(DOMAIN, TAG, 'dataTransfer connect exception: %{public}s', JSON.stringify(connErr));
    }

    // 构建伴读岛屿实体并进入连接态
    const companionName = target.deviceName || 'PineListeningIsland';
    this.currentPartner = new PartnerIslandInfo(
      target.address,
      companionName,
      'PhilosophyReading',
      25,
      true,
      Date.now()
    );
    this.currentState = NearLinkSanctuaryState.CONNECTED;
    this.notifyStateChanged();
  }

  /**
   * 处理对端设备发来的星闪二进制数据包
   */
  private handleIncomingData(params: dataTransfer.DataParams): void {
    try {
      if (!params || !params.data) {
        return;
      }
      const bytes = new Uint8Array(params.data);
      if (bytes.length > 0 && bytes[0] === NearLinkConfig.OP_BREEZE_RIPPLE) {
        hilog.info(DOMAIN, TAG, 'Received remote NearLink breeze ripple from address: %{public}s', params.address);
        const fromName = this.currentPartner ? this.currentPartner.islandName : 'CompanionIsland';
        this.notifyRippleReceived(fromName);
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'Failed to parse incoming NearLink data: %{public}s', JSON.stringify(err));
    }
  }

  /**
   * 监听对端连接状态变更
   */
  private handleConnectionStateChanged(res: dataTransfer.ConnectionResult): void {
    hilog.info(DOMAIN, TAG, 'NearLink connection state changed: address=%{public}s, state=%{public}d', res.address, res.state);
    if (res.state === constant.ConnectionState.STATE_DISCONNECTED) {
      if (this.currentPartner && this.currentPartner.partnerId === res.address) {
        this.currentState = NearLinkSanctuaryState.IDLE;
        this.currentPartner = null;
        this.activePartnerAddress = '';
        this.notifyStateChanged();
      }
    }
  }

  /**
   * 沙盒仿真模式 (用于虚拟机、旧款机型或开发者快速演示碰一碰无声自习室)
   */
  public startSandboxSimulation(): void {
    this.currentState = NearLinkSanctuaryState.SCANNING;
    this.notifyStateChanged();

    // 模拟 1.5 秒后近场“碰一碰”成功发现伴读岛屿
    setTimeout(() => {
      this.currentPartner = new PartnerIslandInfo(
        'island_companion_998',
        'TideHearingIsland',
        'PhilosophyReading',
        35,
        true,
        Date.now()
      );
      this.currentState = NearLinkSanctuaryState.SIMULATED;
      this.notifyStateChanged();
      hilog.info(DOMAIN, TAG, 'Sanctuary sandbox paired: %{public}s', this.currentPartner.islandName);
    }, 1500);
  }

  /**
   * 向伴读岛屿发送“一阵微风” (真机通过 dataTransfer 发送，沙盒模式延时响应)
   */
  public sendRippleToPartner(): boolean {
    if (!this.currentPartner) {
      return false;
    }

    // 1. 若为真实星闪硬件直连态且获取到对端物理地址，通过 dataTransfer 真正发送二进制微风数据帧
    if (this.isNearLinkHardwareSupported && this.currentState === NearLinkSanctuaryState.CONNECTED && this.activePartnerAddress) {
      try {
        const buffer = new ArrayBuffer(1);
        const view = new Uint8Array(buffer);
        view[0] = NearLinkConfig.OP_BREEZE_RIPPLE;

        const writeParams: dataTransfer.DataParams = {
          address: this.activePartnerAddress,
          uuid: NearLinkConfig.getServiceUuid(),
          data: buffer
        };
        dataTransfer.writeData(writeParams).then(() => {
          hilog.info(DOMAIN, TAG, 'Real NearLink breeze ripple sent to target: %{public}s', this.activePartnerAddress);
        }).catch((err: Object) => {
          hilog.warn(DOMAIN, TAG, 'Failed to write NearLink data: %{public}s', JSON.stringify(err));
        });
        return true;
      } catch (err) {
        hilog.warn(DOMAIN, TAG, 'sendRippleToPartner write exception: %{public}s', JSON.stringify(err));
      }
    }

    // 2. 沙盒模拟模式兜底：模拟对方在 3 秒后回赠微风
    hilog.info(DOMAIN, TAG, 'Breeze ripple sent to partner in sandbox: %{public}s', this.currentPartner.islandName);
    setTimeout(() => {
      if (this.currentPartner) {
        this.notifyRippleReceived(this.currentPartner.islandName);
      }
    }, 3000);

    return true;
  }

  /**
   * 断开双子岛连接并释放所有星闪射频与端口资源
   */
  public async disconnectSanctuary(): Promise<void> {
    const serviceUuid = NearLinkConfig.getServiceUuid();

    try {
      if (this.isNearLinkHardwareSupported) {
        if (this.activeAdvertiseId !== -1) {
          await advertising.stopAdvertising(this.activeAdvertiseId);
          this.activeAdvertiseId = -1;
        }

        try {
          scan.off('deviceFound', this.deviceFoundCallback);
          await scan.stopScan();
        } catch (scanErr) {
          hilog.warn(DOMAIN, TAG, 'Failed to cleanup scan: %{public}s', JSON.stringify(scanErr));
        }

        if (this.isPortCreated) {
          if (this.activePartnerAddress) {
            try {
              const connParams: dataTransfer.ConnectionParams = {
                address: this.activePartnerAddress,
                uuid: serviceUuid
              };
              await dataTransfer.disconnect(connParams);
            } catch (discErr) {
              hilog.warn(DOMAIN, TAG, 'Failed to disconnect dataTransfer: %{public}s', JSON.stringify(discErr));
            }
            this.activePartnerAddress = '';
          }

          try {
            dataTransfer.off('readData', this.dataReadCallback);
            dataTransfer.off('connectionStateChanged', this.connectionStateCallback);
            dataTransfer.destroyPort(serviceUuid);
          } catch (portErr) {
            hilog.warn(DOMAIN, TAG, 'Failed to destroyPort: %{public}s', JSON.stringify(portErr));
          }
          this.isPortCreated = false;
        }
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'disconnectSanctuary cleanup error: %{public}s', JSON.stringify(err));
    }

    this.currentState = NearLinkSanctuaryState.IDLE;
    this.currentPartner = null;
    this.activePartnerAddress = '';
    this.notifyStateChanged();
    hilog.info(DOMAIN, TAG, 'NearLink Sanctuary disconnected and resources fully released');
  }
}

export const nearLinkSanctuaryManager = NearLinkSanctuaryManager.getInstance();
