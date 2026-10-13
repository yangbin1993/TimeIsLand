import { hilog } from '@kit.PerformanceAnalysisKit';
import { advertising, scan, manager, constant } from '@kit.NearLinkKit';

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
 * 职责: 手机背靠背“碰一碰”近场组网，建立同频无声自习室，支持微风涟漪互送
 */
export class NearLinkSanctuaryManager {
  private static instance: NearLinkSanctuaryManager | null = null;
  private isNearLinkHardwareSupported: boolean = false;
  private currentState: NearLinkSanctuaryState = NearLinkSanctuaryState.IDLE;
  private currentPartner: PartnerIslandInfo | null = null;
  private activeAdvertiseId: number = -1;

  private stateListeners: SanctuaryStateListener[] = [];
  private rippleListeners: RippleReceivedListener[] = [];

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
   * 启动星闪近场广播与扫描 (碰一碰感应)
   */
  public async startTouchAndSanctuary(myIslandName: string, myCurrentTag: string): Promise<void> {
    if (!this.isNearLinkHardwareSupported) {
      hilog.info(DOMAIN, TAG, 'No NearLink chip detected. Switching to Sanctuary Sandbox Simulation mode.');
      this.startSandboxSimulation();
      return;
    }

    try {
      this.currentState = NearLinkSanctuaryState.SCANNING;
      this.notifyStateChanged();

      // 1. 尝试发射星闪广播 (若权限满足)
      try {
        const settings: advertising.AdvertisingSettings = {
          interval: 5000,
          isConnectable: true
        };
        const advData: advertising.AdvertisingData = {
          serviceUuids: ['37B72000-0000-1000-8000-00805F9B34FB']
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

      // 2. 尝试启动近场扫描
      try {
        const filters: scan.ScanFilters[] = [{
          deviceName: 'TimeIsland'
        }];
        await scan.startScan(filters);
        hilog.info(DOMAIN, TAG, 'NearLink scanning started');
      } catch (scanErr) {
        hilog.warn(DOMAIN, TAG, 'NearLink scan warning: %{public}s', JSON.stringify(scanErr));
      }

    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'startTouchAndSanctuary fallback: %{public}s', JSON.stringify(err));
      this.startSandboxSimulation();
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
   * 向伴读岛屿发送“一阵微风”
   */
  public sendRippleToPartner(): boolean {
    if (!this.currentPartner) {
      return false;
    }

    hilog.info(DOMAIN, TAG, 'Breeze ripple sent to partner: %{public}s', this.currentPartner.islandName);

    // 模拟对方在 3 秒后投桃报李，回赠一阵微风
    setTimeout(() => {
      if (this.currentPartner) {
        this.notifyRippleReceived(this.currentPartner.islandName);
      }
    }, 3000);

    return true;
  }

  /**
   * 断开双子岛连接
   */
  public async disconnectSanctuary(): Promise<void> {
    try {
      if (this.isNearLinkHardwareSupported && this.activeAdvertiseId !== -1) {
        await advertising.stopAdvertising(this.activeAdvertiseId);
        await scan.stopScan();
        this.activeAdvertiseId = -1;
      }
    } catch (err) {
      hilog.warn(DOMAIN, TAG, 'disconnectSanctuary cleanup: %{public}s', JSON.stringify(err));
    }

    this.currentState = NearLinkSanctuaryState.IDLE;
    this.currentPartner = null;
    this.notifyStateChanged();
    hilog.info(DOMAIN, TAG, 'NearLink Sanctuary disconnected');
  }
}

export const nearLinkSanctuaryManager = NearLinkSanctuaryManager.getInstance();
