/**
 * 时光岛 - 主题模式枚举与色彩契约规范 (ThemeTypes)
 */

/**
 * 主题生境模式
 */
export enum ThemeMode {
  SYSTEM = 'SYSTEM', // 跟随系统深浅色模式
  DARK = 'DARK',     // 深潜暗夜 (默认 Stitch 经典黑青流光)
  GOLD = 'GOLD',     // 晨曦浅金 (和煦晨光暖金)
  MOSS = 'MOSS',     // 青苔雨林 (静谧幽林竹翠)
  LIGHT = 'LIGHT'    // 纯净晨曦 (极简清爽明澈白)
}

/**
 * 语义化主题色彩契约接口 (Design Token 映射契约)
 */
export interface ThemePalette {
  bgCanvas: ResourceColor;          // 画布底层深空背景
  surfaceCard: ResourceColor;       // 浮层卡片底色
  surfaceLow: ResourceColor;        // 次级功能按钮底色
  surfaceLowest: ResourceColor;     // 折叠抽屉/最深底层色
  surfaceIndigo: ResourceColor;     // 选中高亮状态卡片底色
  primaryAccent: ResourceColor;     // 核心主强调色 (破晓绿/晨曦金/雨林翠)
  primaryAccentGlow: ResourceColor; // 核心主强调发光态 (描边或流光阴影)
  primaryAccentBg: ResourceColor;   // 核心主强调微胶囊浅底
  secondaryAccent: ResourceColor;   // 次级点缀色 (罗盘湖蓝)
  havenAmber: ResourceColor;        // 避风港守护金色
  havenAmberBg: ResourceColor;      // 避风港微胶囊衬底
  havenAmberBorder: ResourceColor;  // 避风港描边
  textPrimary: ResourceColor;       // 主层级文字
  textSecondary: ResourceColor;     // 次层级文字
  textMuted: ResourceColor;         // 弱化说明/占位文字
  textInverse: ResourceColor;       // 反色文字 (高亮按钮前景)
  borderSubtle: ResourceColor;      // 微妙轮廓线描边
  borderCard: ResourceColor;        // 核心卡片描边
  tabActiveBg: ResourceColor;       // 底部常驻导航激活底色
  shadowFloating: ResourceColor;    // 悬浮功能按钮阴影
  shadowCard: ResourceColor;        // 底部导航/卡片投影
  shadowElevated: ResourceColor;    // 中心罗盘球体浮动投影
  shadowModal: ResourceColor;       // 弹窗模态投影
  primaryGlow: ResourceColor;       // 核心启航按钮与高光微球光韵
  runningGlow: ResourceColor;       // 息心状态流光阴影
  secondaryGlow: ResourceColor;     // 刻度与药丸流光阴影
  textClockGlow: ResourceColor;     // 巨幅数字时钟高光
}

/**
 * 主题菜单项选择器元数据
 */
export interface ThemeOption {
  mode: ThemeMode;
  nameRes: Resource;
  descRes: Resource;
  primaryPreviewColor: string;
  canvasPreviewColor: string;
}
