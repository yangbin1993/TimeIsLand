import { ThemePalette, ThemeMode } from '../theme/ThemeTypes';
import { themeManager } from '../theme/ThemeManager';
import { FocusState } from '../model/FocusTypes';
import { soundEffectManager, SoundEffectType } from '../utils/SoundEffectManager';
import { hapticFeedbackHelper } from '../utils/HapticFeedbackHelper';
import { SolarTermHelper, SolarTermItem, BiomeRealmInfo } from '../utils/SolarTermHelper';
import { SolarTermSealDialog } from './SolarTermSealDialog';

/**
 * 岛屿微气候时间阶段枚举
 */
export enum BiomeTimeSlot {
  AUTO = 'AUTO',   // 跟随现实物理时间
  DAWN = 'DAWN',   // 晨曦 05:00 ~ 09:00
  DAY = 'DAY',     // 白昼 09:00 ~ 17:00
  DUSK = 'DUSK',   // 黄昏 17:00 ~ 19:30
  NIGHT = 'NIGHT'  // 子夜 19:30 ~ 05:00
}

/**
 * 微气候配色契约
 */
interface BiomeColorScheme {
  skyTop: string;
  skyBottom: string;
  seaBase: string;
  seaWave: string;
  sandBase: string;
  sandHighlight: string;
  mountainBase: string;
  mountainPeak: string;
  treeColor: string;
  lakeColor: string;
  celestialColor: string;
  glowColor: string;
  hasStars: boolean;
  isNight: boolean;
}

/**
 * 树木偏移契约
 */
interface TreeOffset {
  dx: number;
  dy: number;
  r: number;
}

/**
 * 时光岛 - 动态晨昏地貌与二十四节气生境组件 (IslandBiomeView)
 * 职责: 依据历史累计心流时长动态演化四大生境境界，并展示东方二十四节气朱印图鉴
 * 风格: 东方禅意微晶视窗、程序化 Canvas 仙岛地貌与朱砂篆刻图鉴
 */
@Component
export struct IslandBiomeView {
  @StorageProp('currentTheme') theme: ThemePalette = themeManager.getPaletteByMode(ThemeMode.DARK);
  @Prop allTimeMinutes: number = 0;
  @Prop todayMinutes: number = 0;
  @Prop focusState: FocusState = FocusState.IDLE;
  @Prop isFlowDrift: boolean = false;

  @State private activeTabSegment: string = 'biome'; // 'biome' | 'seals'
  @State private selectedSlot: BiomeTimeSlot = BiomeTimeSlot.AUTO;
  @State private effectiveSlot: BiomeTimeSlot = BiomeTimeSlot.DAY;

  // 节气图鉴状态
  @State private allTerms: SolarTermItem[] = SolarTermHelper.getAllTerms();
  @State private currentTermId: number = SolarTermHelper.getCurrentTermId();
  @State private selectedSealItem: SolarTermItem | null = null;
  @State private isSealDialogOpen: boolean = false;

  // 2.5D 视差互动偏移量 (带阻尼与平滑回弹)
  @State private dragOffsetX: number = 0;
  @State private dragOffsetY: number = 0;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private canvasWidth: number = 360;
  private canvasHeight: number = 340;

  private get realmInfo(): BiomeRealmInfo {
    return SolarTermHelper.computeRealm(this.allTimeMinutes);
  }

  aboutToAppear(): void {
    this.updateEffectiveSlot();
    this.currentTermId = SolarTermHelper.getCurrentTermId();
  }

  /**
   * 计算当前有效时段
   */
  private updateEffectiveSlot(): void {
    if (this.selectedSlot !== BiomeTimeSlot.AUTO) {
      this.effectiveSlot = this.selectedSlot;
      return;
    }

    const currentHour = new Date().getHours();
    if (currentHour >= 5 && currentHour < 9) {
      this.effectiveSlot = BiomeTimeSlot.DAWN;
    } else if (currentHour >= 9 && currentHour < 17) {
      this.effectiveSlot = BiomeTimeSlot.DAY;
    } else if (currentHour >= 17 && currentHour < 20) {
      this.effectiveSlot = BiomeTimeSlot.DUSK;
    } else {
      this.effectiveSlot = BiomeTimeSlot.NIGHT;
    }
  }

  /**
   * 获取当前气候配色方案
   */
  private getColorScheme(): BiomeColorScheme {
    switch (this.effectiveSlot) {
      case BiomeTimeSlot.DAWN:
        return {
          skyTop: '#1e1b4b',
          skyBottom: '#fda4af',
          seaBase: '#334155',
          seaWave: '#fb7185',
          sandBase: '#fed7aa',
          sandHighlight: '#ffedd5',
          mountainBase: '#15803d',
          mountainPeak: '#34d399',
          treeColor: '#059669',
          lakeColor: '#38bdf8',
          celestialColor: '#fef08a',
          glowColor: 'rgba(253, 164, 175, 0.4)',
          hasStars: false,
          isNight: false
        };
      case BiomeTimeSlot.DUSK:
        return {
          skyTop: '#3b0764',
          skyBottom: '#ea580c',
          seaBase: '#1e1b4b',
          seaWave: '#fb923c',
          sandBase: '#fdba74',
          sandHighlight: '#fed7aa',
          mountainBase: '#064e3b',
          mountainPeak: '#047857',
          treeColor: '#065f46',
          lakeColor: '#38bdf8',
          celestialColor: '#fb923c',
          glowColor: 'rgba(251, 146, 60, 0.4)',
          hasStars: false,
          isNight: false
        };
      case BiomeTimeSlot.NIGHT:
        return {
          skyTop: '#020617',
          skyBottom: '#0f172a',
          seaBase: '#020617',
          seaWave: '#38bdf8',
          sandBase: '#475569',
          sandHighlight: '#64748b',
          mountainBase: '#022c22',
          mountainPeak: '#064e3b',
          treeColor: '#064e3b',
          lakeColor: '#0284c7',
          celestialColor: '#f8fafc',
          glowColor: 'rgba(56, 189, 248, 0.25)',
          hasStars: true,
          isNight: true
        };
      case BiomeTimeSlot.DAY:
      default:
        return {
          skyTop: '#0284c7',
          skyBottom: '#bae6fd',
          seaBase: '#0369a1',
          seaWave: '#e0f2fe',
          sandBase: '#fde047',
          sandHighlight: '#fef08a',
          mountainBase: '#15803d',
          mountainPeak: '#4ade80',
          treeColor: '#16a34a',
          lakeColor: '#0284c7',
          celestialColor: '#ffffff',
          glowColor: 'rgba(255, 255, 255, 0.6)',
          hasStars: false,
          isNight: false
        };
    }
  }

  /**
   * 核心 Canvas 程序化生境地貌渲染管线 (结合境界演化)
   */
  private renderBiome(): void {
    const ctx = this.canvasContext;
    if (!ctx) {
      return;
    }

    const w = this.canvasWidth;
    const h = this.canvasHeight;
    const scheme = this.getColorScheme();
    const realm = this.realmInfo;

    // 视差因子微调
    const px = this.dragOffsetX * 0.15;
    const py = this.dragOffsetY * 0.15;

    ctx.clearRect(0, 0, w, h);

    // 1. 绘制天空背景渐变 (Sky Canvas)
    const skyGrad = ctx.createLinearGradient(0, 0, 0, h * 0.7);
    skyGrad.addColorStop(0, scheme.skyTop);
    skyGrad.addColorStop(1, scheme.skyBottom);
    ctx.fillStyle = skyGrad;
    ctx.fillRect(0, 0, w, h);

    // 2. 星辰微闪 (夜间渲染)
    if (scheme.hasStars) {
      ctx.fillStyle = 'rgba(255, 255, 255, 0.75)';
      const stars: number[][] = [
        [30, 25, 1.2], [70, 50, 1.5], [120, 20, 1.0], [180, 45, 1.8],
        [240, 25, 1.2], [290, 60, 1.4], [330, 35, 1.6], [85, 90, 1.0], [210, 80, 1.2]
      ];
      for (let i = 0; i < stars.length; i++) {
        ctx.beginPath();
        ctx.arc(stars[i][0] + px * 0.3, stars[i][1] + py * 0.3, stars[i][2], 0, Math.PI * 2);
        ctx.fill();
      }
    }

    // 3. 日月天象与光晕 (Celestial Object)
    const celX = (scheme.isNight ? w * 0.25 : w * 0.75) + px * 0.5;
    const celY = h * 0.22 + py * 0.5;
    const celR = scheme.isNight ? 18 : 24;

    const celestialGlow = ctx.createRadialGradient(celX, celY, celR * 0.5, celX, celY, celR * 2.2);
    celestialGlow.addColorStop(0, scheme.glowColor);
    celestialGlow.addColorStop(1, 'rgba(0, 0, 0, 0)');
    ctx.fillStyle = celestialGlow;
    ctx.beginPath();
    ctx.arc(celX, celY, celR * 2.2, 0, Math.PI * 2);
    ctx.fill();

    ctx.fillStyle = scheme.celestialColor;
    ctx.beginPath();
    ctx.arc(celX, celY, celR, 0, Math.PI * 2);
    ctx.fill();

    // 4. 心流延展态下绘制极光波浪 (Aurora Wave)
    if (this.isFlowDrift) {
      const auroraGrad = ctx.createLinearGradient(0, 40, 0, 160);
      auroraGrad.addColorStop(0, 'rgba(78, 222, 163, 0)');
      auroraGrad.addColorStop(0.5, 'rgba(78, 222, 163, 0.45)');
      auroraGrad.addColorStop(1, 'rgba(56, 189, 248, 0)');
      ctx.fillStyle = auroraGrad;
      ctx.beginPath();
      ctx.moveTo(0, 100);
      ctx.bezierCurveTo(w * 0.3, 70, w * 0.7, 130, w, 90);
      ctx.lineTo(w, 160);
      ctx.bezierCurveTo(w * 0.7, 180, w * 0.3, 120, 0, 160);
      ctx.closePath();
      ctx.fill();
    }

    // 5. 绘制大海基座与起伏海面 (Ocean Base)
    const seaY = h * 0.52;
    const seaGrad = ctx.createLinearGradient(0, seaY, 0, h);
    seaGrad.addColorStop(0, scheme.seaBase);
    seaGrad.addColorStop(1, '#020617');
    ctx.fillStyle = seaGrad;
    ctx.fillRect(0, seaY, w, h - seaY);

    // 海面微澜波纹线
    ctx.strokeStyle = scheme.seaWave;
    ctx.lineWidth = 1.2;
    ctx.globalAlpha = 0.5;
    for (let i = 0; i < 4; i++) {
      const lineY = seaY + 12 + i * 22;
      ctx.beginPath();
      ctx.moveTo(20 + i * 15 + px, lineY);
      ctx.bezierCurveTo(w * 0.3, lineY - 3, w * 0.7, lineY + 3, w - 20 - i * 15 + px, lineY);
      ctx.stroke();
    }
    ctx.globalAlpha = 1.0;

    // 6. 绘制主岛环礁沙滩 (Sand Island Base)
    const islandCenterX = w * 0.5 + px;
    const islandCenterY = h * 0.68 + py;
    const islandRadiusX = w * 0.42;
    const islandRadiusY = h * 0.18;

    ctx.fillStyle = scheme.sandBase;
    ctx.beginPath();
    ctx.ellipse(islandCenterX, islandCenterY, islandRadiusX, islandRadiusY, 0, 0, Math.PI * 2);
    ctx.fill();

    // 顶部高光沙滩层
    ctx.fillStyle = scheme.sandHighlight;
    ctx.beginPath();
    ctx.ellipse(islandCenterX, islandCenterY - 4, islandRadiusX * 0.94, islandRadiusY * 0.92, 0, 0, Math.PI * 2);
    ctx.fill();

    // 7. 绘制山峦地貌 (根据境界演变动态调整高度与峰数)
    const mountainGrad = ctx.createLinearGradient(0, islandCenterY - 60, 0, islandCenterY);
    mountainGrad.addColorStop(0, scheme.mountainPeak);
    mountainGrad.addColorStop(1, scheme.mountainBase);
    ctx.fillStyle = mountainGrad;

    // 左主峰
    ctx.beginPath();
    ctx.moveTo(islandCenterX - islandRadiusX * 0.65, islandCenterY);
    ctx.bezierCurveTo(
      islandCenterX - islandRadiusX * 0.4, islandCenterY - 55,
      islandCenterX - islandRadiusX * 0.2, islandCenterY - 65,
      islandCenterX - islandRadiusX * 0.05, islandCenterY - 10
    );
    ctx.closePath();
    ctx.fill();

    // 右主峰
    ctx.beginPath();
    ctx.moveTo(islandCenterX - islandRadiusX * 0.1, islandCenterY - 10);
    ctx.bezierCurveTo(
      islandCenterX + islandRadiusX * 0.2, islandCenterY - 75,
      islandCenterX + islandRadiusX * 0.45, islandCenterY - 60,
      islandCenterX + islandRadiusX * 0.7, islandCenterY
    );
    ctx.closePath();
    ctx.fill();

    // 蓬莱雪境特权：雪峰白雪与仙雾
    if (realm.hasSnowPeak) {
      ctx.fillStyle = '#FFFFFF';
      ctx.beginPath();
      ctx.moveTo(islandCenterX + islandRadiusX * 0.1, islandCenterY - 58);
      ctx.bezierCurveTo(
        islandCenterX + islandRadiusX * 0.2, islandCenterY - 77,
        islandCenterX + islandRadiusX * 0.35, islandCenterY - 70,
        islandCenterX + islandRadiusX * 0.42, islandCenterY - 56
      );
      ctx.closePath();
      ctx.fill();

      // 仙雾流云
      const mistGrad = ctx.createLinearGradient(0, islandCenterY - 30, 0, islandCenterY + 10);
      mistGrad.addColorStop(0, 'rgba(255, 255, 255, 0.4)');
      mistGrad.addColorStop(1, 'rgba(255, 255, 255, 0)');
      ctx.fillStyle = mistGrad;
      ctx.fillRect(islandCenterX - islandRadiusX * 0.5, islandCenterY - 20, islandRadiusX, 30);
    }

    // 8. 绘制心流湖泊 (Flow Lake)
    const lakeRatio = Math.min(1.0, Math.max(0.15, this.todayMinutes / 60));
    const lakeW = islandRadiusX * 0.42 * lakeRatio;
    const lakeH = islandRadiusY * 0.38 * lakeRatio;
    const lakeX = islandCenterX - islandRadiusX * 0.05;
    const lakeY = islandCenterY + 10;

    const lakeGrad = ctx.createLinearGradient(0, lakeY - lakeH, 0, lakeY + lakeH);
    lakeGrad.addColorStop(0, scheme.lakeColor);
    lakeGrad.addColorStop(1, '#0284c7');
    ctx.fillStyle = lakeGrad;
    ctx.beginPath();
    ctx.ellipse(lakeX, lakeY, lakeW, lakeH, 0, 0, Math.PI * 2);
    ctx.fill();

    // 9. 绘制生境植被树木 (根据境界与今日时长演进)
    const treeCount = Math.min(10, realm.treeBaseCount);
    const treeOffsets: TreeOffset[] = [
      { dx: -0.52, dy: -18, r: 16 },
      { dx: -0.38, dy: -28, r: 15 },
      { dx: 0.32, dy: -24, r: 14 },
      { dx: 0.48, dy: -14, r: 13 },
      { dx: -0.24, dy: -12, r: 11 },
      { dx: 0.20, dy: -10, r: 12 },
      { dx: -0.58, dy: -6, r: 10 },
      { dx: 0.56, dy: -4, r: 10 },
      { dx: -0.12, dy: 18, r: 8 },
      { dx: 0.16, dy: 16, r: 8 }
    ];

    ctx.fillStyle = realm.hasBambooForest ? '#047857' : scheme.treeColor;
    for (let i = 0; i < treeCount; i++) {
      const tree = treeOffsets[i];
      const tx = islandCenterX + islandRadiusX * tree.dx;
      const ty = islandCenterY + tree.dy;
      ctx.beginPath();
      ctx.arc(tx, ty, tree.r, 0, Math.PI * 2);
      ctx.fill();

      // 树顶微光
      ctx.fillStyle = 'rgba(255, 255, 255, 0.22)';
      ctx.beginPath();
      ctx.arc(tx - tree.r * 0.2, ty - tree.r * 0.2, tree.r * 0.4, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = realm.hasBambooForest ? '#047857' : scheme.treeColor;
    }

    // 10. 温暖避风港小灯塔 (Haven Beacon)
    if (scheme.isNight || this.effectiveSlot === BiomeTimeSlot.DUSK) {
      const beaconX = islandCenterX + islandRadiusX * 0.1;
      const beaconY = islandCenterY - 42;

      const beaconGlow = ctx.createRadialGradient(beaconX, beaconY, 1, beaconX, beaconY, 20);
      beaconGlow.addColorStop(0, 'rgba(251, 191, 36, 0.85)');
      beaconGlow.addColorStop(1, 'rgba(251, 191, 36, 0)');
      ctx.fillStyle = beaconGlow;
      ctx.beginPath();
      ctx.arc(beaconX, beaconY, 20, 0, Math.PI * 2);
      ctx.fill();

      ctx.fillStyle = '#fef08a';
      ctx.beginPath();
      ctx.arc(beaconX, beaconY, 3.5, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  build() {
    Column({ space: 14 }) {
      // 1. 顶栏：分段切换器 (生境演化 vs 二十四节气图鉴)
      Row() {
        Row({ space: 4 }) {
          // 生境演化 Tab
          Button({ type: ButtonType.Capsule, stateEffect: true }) {
            Text($r('app.string.biome_tab_biome'))
              .fontSize(12)
              .fontWeight(this.activeTabSegment === 'biome' ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.activeTabSegment === 'biome' ? this.theme.textInverse : this.theme.textSecondary)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          }
          .backgroundColor(this.activeTabSegment === 'biome' ? this.theme.primaryAccent : this.theme.surfaceLow)
          .onClick(() => {
            soundEffectManager.play(SoundEffectType.BUBBLE);
            hapticFeedbackHelper.trigger('tick');
            this.activeTabSegment = 'biome';
          })

          // 二十四节气图鉴 Tab
          Button({ type: ButtonType.Capsule, stateEffect: true }) {
            Text($r('app.string.biome_tab_seals'))
              .fontSize(12)
              .fontWeight(this.activeTabSegment === 'seals' ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(this.activeTabSegment === 'seals' ? this.theme.textInverse : this.theme.textSecondary)
              .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          }
          .backgroundColor(this.activeTabSegment === 'seals' ? this.theme.primaryAccent : this.theme.surfaceLow)
          .onClick(() => {
            soundEffectManager.play(SoundEffectType.BUBBLE);
            hapticFeedbackHelper.trigger('tick');
            this.activeTabSegment = 'seals';
          })
        }
        .padding(3)
        .backgroundColor(this.theme.surfaceCard)
        .borderRadius(20)
        .border({ width: 1, color: this.theme.borderCard })

        Blank()
      }
      .width('100%')

      if (this.activeTabSegment === 'biome') {
        this.buildBiomeLandscapeView()
      } else {
        this.buildSealsGridView()
      }

      // 节气朱砂印章物候详情弹窗
      SolarTermSealDialog({
        visible: this.isSealDialogOpen,
        item: this.selectedSealItem,
        isCurrentTerm: this.selectedSealItem !== null && this.selectedSealItem.id === this.currentTermId,
        isUnlocked: true,
        onClose: () => {
          this.isSealDialogOpen = false;
        }
      })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 16 })
  }

  /**
   * 视图分支 A：生境地貌与四大境界演化视图
   */
  @Builder
  private buildBiomeLandscapeView() {
    Column({ space: 12 }) {
      // 1. 生境四大境界演进状态卡片
      Column({ space: 8 }) {
        Row() {
          Row({ space: 6 }) {
            Image($r('app.media.ic_landscape'))
              .width(14)
              .height(14)
              .fillColor(this.theme.primaryAccent)

            Text(this.realmInfo.nameRes)
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.theme.textPrimary)
          }

          Blank()

          Text(this.realmInfo.level === 4 ?
            $r('app.string.biome_realm_max_level') :
            `${this.allTimeMinutes}/${this.realmInfo.nextThresholdMinutes}m`)
            .fontSize(11)
            .fontColor(this.theme.textMuted)
        }
        .width('100%')

        // 境界进度条
        Progress({ value: this.realmInfo.progressPercent, total: 100, type: ProgressType.Linear })
          .color(this.theme.primaryAccent)
          .backgroundColor(this.theme.borderSubtle)
          .style({ strokeWidth: 5 })

        Text(this.realmInfo.descRes)
          .fontSize(11)
          .fontColor(this.theme.textSecondary)
          .fontStyle(FontStyle.Italic)
      }
      .width('100%')
      .padding(14)
      .backgroundColor(this.theme.surfaceCard)
      .borderRadius(16)
      .border({ width: 1, color: this.theme.borderCard })
      .shadow({ radius: 10, color: this.theme.shadowCard, offsetY: 2 })

      // 2. 晨昏时段微晶切换胶囊栏
      Row({ space: 4 }) {
        this.buildSlotPill(BiomeTimeSlot.AUTO, $r('app.string.timeisland_biome_auto_time'))
        this.buildSlotPill(BiomeTimeSlot.DAWN, $r('app.string.timeisland_biome_slot_dawn'))
        this.buildSlotPill(BiomeTimeSlot.DAY, $r('app.string.timeisland_biome_slot_day'))
        this.buildSlotPill(BiomeTimeSlot.DUSK, $r('app.string.timeisland_biome_slot_dusk'))
        this.buildSlotPill(BiomeTimeSlot.NIGHT, $r('app.string.timeisland_biome_slot_night'))
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      // 3. 核心 2.5D Canvas 岛屿生境画布容器 (支持触控微视差与物理阻尼)
      Stack({ alignContent: Alignment.Bottom }) {
        Canvas(this.canvasContext)
          .width('100%')
          .height(300)
          .borderRadius(20)
          .onReady(() => {
            this.renderBiome();
          })

        // 底部微视差轻抚手势提示
        Row({ space: 4 }) {
          Image($r('app.media.ic_motion_blur'))
            .width(12)
            .height(12)
            .fillColor(this.theme.textSecondary)

          Text($r('app.string.timeisland_biome_touch_hint'))
            .fontSize(10)
            .fontColor(this.theme.textSecondary)
        }
        .padding({ left: 12, right: 12, top: 4, bottom: 4 })
        .backgroundColor('rgba(0, 0, 0, 0.4)')
        .borderRadius(12)
        .margin({ bottom: 10 })
      }
      .width('100%')
      .height(300)
      .borderRadius(20)
      .border({ width: 1, color: this.theme.borderCard })
      .shadow({ radius: 18, color: this.theme.shadowElevated, offsetY: 4 })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Move && event.touches.length > 0) {
          const touch = event.touches[0];
          this.dragOffsetX = Math.max(-40, Math.min(40, touch.x - this.canvasWidth / 2));
          this.dragOffsetY = Math.max(-30, Math.min(30, touch.y - this.canvasHeight / 2));
          this.renderBiome();
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          animateTo({ duration: 350, curve: Curve.EaseOut }, () => {
            this.dragOffsetX = 0;
            this.dragOffsetY = 0;
            this.renderBiome();
          });
        }
      })

      // 4. 生态指标三维卡片矩阵 (湖泊储水 / 繁茂度 / 心流纯度)
      Row({ space: 10 }) {
        this.buildStatTile(
          $r('app.string.timeisland_biome_stat_lake'),
          `${Math.min(100, Math.round((this.todayMinutes / 60) * 100))}%`,
          this.theme.secondaryAccent
        )

        this.buildStatTile(
          $r('app.string.timeisland_biome_stat_vegetation'),
          `Lv.${this.realmInfo.level}`,
          this.theme.primaryAccent
        )

        this.buildStatTile(
          $r('app.string.timeisland_biome_stat_purity'),
          this.isFlowDrift ? $r('app.string.biome_flow_drift_extended') : (this.todayMinutes > 0 ? '98%' : '100%'),
          this.theme.havenAmber
        )
      }
      .width('100%')
    }
    .width('100%')
  }

  /**
   * 视图分支 B：二十四节气朱印图鉴视窗
   */
  @Builder
  private buildSealsGridView() {
    Column({ space: 12 }) {
      // 节气说明栏
      Row() {
        Text($r('app.string.biome_seal_dialog_title'))
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.theme.textPrimary)

        Blank()

        Text(`24 / 24`)
          .fontSize(11)
          .fontColor(this.theme.primaryAccent)
          .fontWeight(FontWeight.Bold)
      }
      .width('100%')
      .padding({ left: 4, right: 4 })

      // 24 节气朱砂印章网格流 (3 列排布)
      GridRow({ columns: 3, gutter: { x: 8, y: 8 } }) {
        ForEach(this.allTerms, (item: SolarTermItem) => {
          GridCol() {
            Column({ space: 6 }) {
              // 朱红篆刻印章方块
              Stack({ alignContent: Alignment.TopEnd }) {
                Column() {
                  Text(item.nameRes)
                    .fontSize(14)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#FDE047')
                    .letterSpacing(1)
                }
                .width(48)
                .height(48)
                .justifyContent(FlexAlign.Center)
                .backgroundColor('#991B1B')
                .borderRadius(8)
                .border({ width: 1.5, color: '#FBBF24', radius: 8 })

                // 当令节气高光标识
                if (item.id === this.currentTermId) {
                  Row()
                    .width(8)
                    .height(8)
                    .borderRadius(4)
                    .backgroundColor(this.theme.primaryAccent)
                    .margin({ top: -2, right: -2 })
                }
              }

              Text(item.nameRes)
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.theme.textPrimary)

              Text(SolarTermHelper.getMonthResource(item.month))
                .fontSize(10)
                .fontColor(this.theme.textMuted)
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
            .backgroundColor(this.theme.surfaceCard)
            .borderRadius(14)
            .border({
              width: 1,
              color: item.id === this.currentTermId ? this.theme.primaryAccent : this.theme.borderSubtle
            })
            .shadow({ radius: 8, color: this.theme.shadowCard, offsetY: 2 })
            .onClick(() => {
              soundEffectManager.play(SoundEffectType.PEN_CLICK);
              hapticFeedbackHelper.trigger('tick');
              this.selectedSealItem = item;
              this.isSealDialogOpen = true;
            })
          }
        }, (item: SolarTermItem) => item.id.toString())
      }
      .width('100%')
    }
    .width('100%')
  }

  /**
   * 气候时段切换药丸按键
   */
  @Builder
  private buildSlotPill(slot: BiomeTimeSlot, label: Resource) {
    Button({ type: ButtonType.Capsule, stateEffect: true }) {
      Text(label)
        .fontSize(10)
        .fontWeight(this.selectedSlot === slot ? FontWeight.Bold : FontWeight.Normal)
        .fontColor(this.selectedSlot === slot ? this.theme.textPrimary : this.theme.textSecondary)
        .padding({ left: 6, right: 6, top: 4, bottom: 4 })
    }
    .backgroundColor(this.selectedSlot === slot ? this.theme.surfaceIndigo : this.theme.surfaceLow)
    .border({
      width: 1,
      color: this.selectedSlot === slot ? this.theme.primaryAccent : this.theme.borderSubtle
    })
    .onClick(() => {
      soundEffectManager.play(SoundEffectType.BUBBLE);
      this.selectedSlot = slot;
      this.updateEffectiveSlot();
      this.renderBiome();
    })
  }

  /**
   * 生态数据统计卡片单元
   */
  @Builder
  private buildStatTile(label: Resource, value: ResourceStr, accentColor: ResourceColor) {
    Column({ space: 4 }) {
      Text(label)
        .fontSize(10)
        .fontColor(this.theme.textMuted)

      Text(value)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(accentColor)
    }
    .layoutWeight(1)
    .padding({ top: 10, bottom: 10, left: 8, right: 8 })
    .backgroundColor(this.theme.surfaceCard)
    .borderRadius(14)
    .border({ width: 1, color: this.theme.borderSubtle })
    .alignItems(HorizontalAlign.Center)
  }
}
