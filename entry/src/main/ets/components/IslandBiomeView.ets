import { ThemePalette, ThemeMode } from '../theme/ThemeTypes';
import { themeManager } from '../theme/ThemeManager';
import { FocusState } from '../model/FocusTypes';
import { soundEffectManager, SoundEffectType } from '../utils/SoundEffectManager';

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
 * 星辰种子契约
 */
interface StarSeed {
  x: number;
  y: number;
  r: number;
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
 * 时光岛 - 动态晨昏地貌与微缩生境组件 (IslandBiomeView)
 * 职责: 基于 ArkUI Canvas 纯原生程序化渲染，依据物理时间与专注纯度动态演化心流湖泊、植被与天象
 */
@Component
export struct IslandBiomeView {
  @StorageProp('currentTheme') theme: ThemePalette = themeManager.getPaletteByMode(ThemeMode.DARK);
  @Prop todayMinutes: number = 0;
  @Prop focusState: FocusState = FocusState.IDLE;
  @Prop isFlowDrift: boolean = false;

  @State private selectedSlot: BiomeTimeSlot = BiomeTimeSlot.AUTO;
  @State private effectiveSlot: BiomeTimeSlot = BiomeTimeSlot.DAY;

  // 2.5D 视差互动偏移量 (带阻尼与平滑回弹)
  @State private dragOffsetX: number = 0;
  @State private dragOffsetY: number = 0;

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private canvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private canvasWidth: number = 360;
  private canvasHeight: number = 380;

  aboutToAppear(): void {
    this.updateEffectiveSlot();
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
   * 核心 Canvas 程序化生境地貌渲染管线
   */
  private renderBiome(): void {
    const ctx = this.canvasContext;
    if (!ctx) {
      return;
    }

    const w = this.canvasWidth;
    const h = this.canvasHeight;
    const scheme = this.getColorScheme();

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

    // 2. 绘制星空繁星 (夜间)
    if (scheme.hasStars) {
      ctx.fillStyle = '#ffffff';
      const starSeeds: StarSeed[] = [
        { x: 30, y: 30, r: 1.2 }, { x: 80, y: 55, r: 0.9 },
        { x: 140, y: 25, r: 1.5 }, { x: 220, y: 40, r: 1.1 },
        { x: 290, y: 20, r: 1.4 }, { x: 330, y: 65, r: 0.8 },
        { x: 60, y: 90, r: 1.0 }, { x: 190, y: 80, r: 1.3 },
        { x: 270, y: 95, r: 1.0 }, { x: 310, y: 120, r: 0.7 }
      ];
      starSeeds.forEach((star) => {
        ctx.beginPath();
        ctx.arc(star.x + px * 0.3, star.y + py * 0.3, star.r, 0, Math.PI * 2);
        ctx.fill();
      });
    }

    // 3. 绘制天体 (太阳 / 月亮与放射光晕)
    const celX = (scheme.isNight ? w * 0.8 : w * 0.25) + px * 0.4;
    const celY = h * 0.22 + py * 0.4;
    const celR = scheme.isNight ? 22 : 28;

    // 外层弥散光晕
    const glowGrad = ctx.createRadialGradient(celX, celY, celR * 0.5, celX, celY, celR * 2.5);
    glowGrad.addColorStop(0, scheme.glowColor);
    glowGrad.addColorStop(1, 'rgba(255, 255, 255, 0)');
    ctx.fillStyle = glowGrad;
    ctx.beginPath();
    ctx.arc(celX, celY, celR * 2.5, 0, Math.PI * 2);
    ctx.fill();

    // 天体本体
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

    // 7. 绘制主峰山峦地貌 (Mountain Ridge)
    const mountainGrad = ctx.createLinearGradient(0, islandCenterY - 60, 0, islandCenterY);
    mountainGrad.addColorStop(0, scheme.mountainPeak);
    mountainGrad.addColorStop(1, scheme.mountainBase);
    ctx.fillStyle = mountainGrad;

    // 左峰
    ctx.beginPath();
    ctx.moveTo(islandCenterX - islandRadiusX * 0.65, islandCenterY);
    ctx.bezierCurveTo(
      islandCenterX - islandRadiusX * 0.4, islandCenterY - 55,
      islandCenterX - islandRadiusX * 0.2, islandCenterY - 65,
      islandCenterX - islandRadiusX * 0.05, islandCenterY - 10
    );
    ctx.closePath();
    ctx.fill();

    // 右峰
    ctx.beginPath();
    ctx.moveTo(islandCenterX - islandRadiusX * 0.1, islandCenterY - 10);
    ctx.bezierCurveTo(
      islandCenterX + islandRadiusX * 0.2, islandCenterY - 75,
      islandCenterX + islandRadiusX * 0.45, islandCenterY - 60,
      islandCenterX + islandRadiusX * 0.7, islandCenterY
    );
    ctx.closePath();
    ctx.fill();

    // 8. 绘制心流湖泊 (Flow Lake - 随今日专注分钟数丰盈)
    const lakeGrowth = Math.min(1.0, Math.max(0.15, this.todayMinutes / 60));
    const lakeRx = islandRadiusX * 0.32 * lakeGrowth;
    const lakeRy = islandRadiusY * 0.38 * lakeGrowth;
    const lakeY = islandCenterY + 6;

    const lakeGrad = ctx.createRadialGradient(islandCenterX, lakeY, 2, islandCenterX, lakeY, lakeRx);
    lakeGrad.addColorStop(0, '#38bdf8');
    lakeGrad.addColorStop(1, scheme.lakeColor);
    ctx.fillStyle = lakeGrad;
    ctx.beginPath();
    ctx.ellipse(islandCenterX, lakeY, lakeRx, lakeRy, 0, 0, Math.PI * 2);
    ctx.fill();

    // 湖光粼粼小高光
    ctx.fillStyle = 'rgba(255, 255, 255, 0.7)';
    ctx.beginPath();
    ctx.ellipse(islandCenterX - lakeRx * 0.25, lakeY - 2, lakeRx * 0.35, lakeRy * 0.25, -0.2, 0, Math.PI * 2);
    ctx.fill();

    // 9. 绘制生境植被树木簇群 (Trees)
    // 根据专注分钟数动态增生 (从 3 棵到 10 棵)
    const treeCount = Math.min(10, Math.max(3, Math.floor(this.todayMinutes / 12) + 3));
    const treeOffsets: TreeOffset[] = [
      { dx: -0.52, dy: -18, r: 12 },
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

    ctx.fillStyle = scheme.treeColor;
    for (let i = 0; i < treeCount; i++) {
      const tree = treeOffsets[i];
      const tx = islandCenterX + islandRadiusX * tree.dx;
      const ty = islandCenterY + tree.dy;
      // 树冠圆形微叠
      ctx.beginPath();
      ctx.arc(tx, ty, tree.r, 0, Math.PI * 2);
      ctx.fill();

      // 高光树顶
      ctx.fillStyle = 'rgba(255, 255, 255, 0.25)';
      ctx.beginPath();
      ctx.arc(tx - tree.r * 0.2, ty - tree.r * 0.2, tree.r * 0.4, 0, Math.PI * 2);
      ctx.fill();
      ctx.fillStyle = scheme.treeColor;
    }

    // 10. 夜间 / 黄昏：岛心温暖避风港小灯塔 (Haven Beacon)
    if (scheme.isNight || this.effectiveSlot === BiomeTimeSlot.DUSK) {
      const beaconX = islandCenterX + islandRadiusX * 0.1;
      const beaconY = islandCenterY - 42;

      // 温暖琥珀金光晕
      const beaconGlow = ctx.createRadialGradient(beaconX, beaconY, 1, beaconX, beaconY, 20);
      beaconGlow.addColorStop(0, 'rgba(251, 191, 36, 0.85)');
      beaconGlow.addColorStop(1, 'rgba(251, 191, 36, 0)');
      ctx.fillStyle = beaconGlow;
      ctx.beginPath();
      ctx.arc(beaconX, beaconY, 20, 0, Math.PI * 2);
      ctx.fill();

      // 小灯火点
      ctx.fillStyle = '#fef08a';
      ctx.beginPath();
      ctx.arc(beaconX, beaconY, 3.5, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  build() {
    Column({ space: 14 }) {
      // 1. 顶部 Header 标题与微气候时段切换器
      Row() {
        Column({ space: 3 }) {
          Text($r('app.string.timeisland_biome_title'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.theme.textPrimary)

          Text($r('app.string.timeisland_biome_subtitle'))
            .fontSize(11)
            .fontColor(this.theme.textMuted)
        }
        .alignItems(HorizontalAlign.Start)

        Blank()
      }
      .width('100%')

      // 2. 晨昏时段微晶切换胶囊栏
      Row({ space: 6 }) {
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
          .height(340)
          .borderRadius(24)
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
        .backgroundColor('rgba(0, 0, 0, 0.35)')
        .borderRadius(12)
        .margin({ bottom: 12 })
      }
      .width('100%')
      .height(340)
      .borderRadius(24)
      .border({ width: 1, color: this.theme.borderCard })
      .shadow({ radius: 20, color: this.theme.shadowElevated, offsetY: 4 })
      .onTouch((event: TouchEvent) => {
        if (event.type === TouchType.Move && event.touches.length > 0) {
          const touch = event.touches[0];
          this.dragOffsetX = Math.max(-40, Math.min(40, touch.x - this.canvasWidth / 2));
          this.dragOffsetY = Math.max(-30, Math.min(30, touch.y - this.canvasHeight / 2));
          this.renderBiome();
        } else if (event.type === TouchType.Up || event.type === TouchType.Cancel) {
          // 物理弹性归中
          animateTo({ duration: 350, curve: Curve.EaseOut }, () => {
            this.dragOffsetX = 0;
            this.dragOffsetY = 0;
            this.renderBiome();
          });
        }
      })

      // 4. 生态指标三维卡片矩阵 (湖泊储水 / 繁茂度 / 心流纯度)
      Row({ space: 10 }) {
        // 心流湖储水
        this.buildStatTile(
          $r('app.string.timeisland_biome_stat_lake'),
          `${Math.min(100, Math.round((this.todayMinutes / 60) * 100))}%`,
          this.theme.secondaryAccent
        )

        // 生境繁茂度
        this.buildStatTile(
          $r('app.string.timeisland_biome_stat_vegetation'),
          `Lv.${Math.min(10, Math.floor(this.todayMinutes / 12) + 3)}`,
          this.theme.primaryAccent
        )

        // 心流纯度
        this.buildStatTile(
          $r('app.string.timeisland_biome_stat_purity'),
          this.isFlowDrift ? $r('app.string.biome_flow_drift_extended') : (this.todayMinutes > 0 ? '96%' : '100%'),
          this.theme.havenAmber
        )
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 16 })
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
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
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
