let cardLocalStorage = new LocalStorage();

/**
 * 时光岛 - 桌面万物互联原子化元服务卡片 (2x2 / 2x4 自适应)
 * 职责:
 * 1. 桌面免开应用透视晨昏微气候、生境境界阶梯与当令节气朱砂印；
 * 2. 感知星闪 NearLink 万物互联伴读状态；
 * 3. 2x2 方卡提供 15m / 25m 双档极速起航；2x4 宽卡提供 15m / 25m / 45m 全景多档起航中枢。
 */
@Entry(cardLocalStorage)
@Component
struct IslandCardView {
  @LocalStorageProp('formDimension') formDimension: number = 2; // 2: 2x2, 3: 2x4
  @LocalStorageProp('todayMinutes') todayMinutes: number = 45;
  @LocalStorageProp('allTimeMinutes') allTimeMinutes: number = 180;
  @LocalStorageProp('currentTag') currentTag: string = '';
  @LocalStorageProp('biomeSlot') biomeSlot: string = 'DAY';
  @LocalStorageProp('biomeTitle') biomeTitle: string = '';
  @LocalStorageProp('lakeStoragePercent') lakeStoragePercent: number = 60;
  @LocalStorageProp('realmName') realmName: string = '';
  @LocalStorageProp('realmLevel') realmLevel: number = 1;
  @LocalStorageProp('solarTermName') solarTermName: string = '';
  @LocalStorageProp('solarTermSeal') solarTermSeal: string = '';
  @LocalStorageProp('isNearLinkActive') isNearLinkActive: boolean = false;
  @LocalStorageProp('streakDays') streakDays: number = 0;

  /**
   * 依据晨昏获取卡片微气候渐变色
   */
  private getBackgroundGradient(): string[] {
    if (this.biomeSlot === 'DAWN') {
      return ['#1F1A2C', '#332438'];
    } else if (this.biomeSlot === 'DAY') {
      return ['#132438', '#1D3B54'];
    } else if (this.biomeSlot === 'DUSK') {
      return ['#2B1B2A', '#3D253B'];
    }
    // NIGHT
    return ['#0D131F', '#161F30'];
  }

  /**
   * 触发一键起航并拉起时光岛主应用
   */
  private startQuickFocus(targetMinutes: number): void {
    postCardAction(this, {
      action: 'router',
      abilityName: 'AppAbility',
      params: {
        quickStartMinutes: targetMinutes,
        source: 'desktop_card'
      }
    });
  }

  /**
   * 打开时光岛主页
   */
  private openAppHome(): void {
    postCardAction(this, {
      action: 'router',
      abilityName: 'AppAbility',
      params: {
        source: 'desktop_card'
      }
    });
  }

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 晨昏微气候沉浸式背景渐变
      Column()
        .width('100%')
        .height('100%')
        .linearGradient({
          angle: 160,
          colors: [
            [this.getBackgroundGradient()[0], 0.0],
            [this.getBackgroundGradient()[1], 1.0]
          ]
        })

      // 2. 岛屿微气候发光圆晕
      Circle()
        .width(180)
        .height(180)
        .fill(this.biomeSlot === 'NIGHT' ? '#1A3350' : '#2A4A68')
        .opacity(0.3)
        .blur(40)
        .position({ x: -20, y: -20 })

      // 3. 依据卡片尺寸渲染对应规格
      if (this.formDimension === 3) {
        this.buildWide2x4Layout()
      } else {
        this.buildSquare2x2Layout()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#0F172A')
  }

  /**
   * 2x2 规格紧凑微晶方卡
   */
  @Builder
  private buildSquare2x2Layout() {
    Column() {
      // 顶部行：晨昏时段徽标与节气朱印
      Row() {
        Row({ space: 4 }) {
          Circle()
            .width(6)
            .height(6)
            .fill(this.biomeSlot === 'DAWN' ? '#FBBF24' : (this.biomeSlot === 'DAY' ? '#38BDF8' : '#A78BFA'))
          Text(this.biomeTitle)
            .fontSize(11)
            .fontColor('#CCFFFFFF')
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor('#22FFFFFF')
        .borderRadius(12)

        Blank()

        // 节气朱红印徽章
        if (this.solarTermName) {
          Text(this.solarTermName)
            .fontSize(10)
            .fontColor('#FDE047')
            .fontWeight(FontWeight.Bold)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor('#991B1B')
            .borderRadius(4)
            .border({ width: 1, color: '#FBBF24' })
        }
      }
      .width('100%')

      Blank()

      // 中间行：今日心流核心数据与湖泊水库
      Row() {
        Column({ space: 2 }) {
          Row({ space: 4 }) {
            Text(`${this.todayMinutes}`)
              .fontSize(30)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Bold)
            Text($r('app.string.widget_minutes_unit'))
              .fontSize(11)
              .fontColor('#80FFFFFF')
              .alignSelf(ItemAlign.End)
              .margin({ bottom: 5 })
          }

          // 生境境界微晶文字
          if (this.realmName) {
            Text(`Lv.${this.realmLevel} ${this.realmName}`)
              .fontSize(10)
              .fontColor('#4EDEA3')
              .fontWeight(FontWeight.Medium)
          }
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        // 微缩水滴储水环
        Stack({ alignContent: Alignment.Center }) {
          Progress({ value: this.lakeStoragePercent, total: 100, type: ProgressType.Ring })
            .width(42)
            .height(42)
            .color('#4EDEA3')
            .backgroundColor('#20FFFFFF')
            .style({ strokeWidth: 4 })

          Text('🌊')
            .fontSize(13)
        }
      }
      .width('100%')

      Blank()

      // 底部行：一键免开 App 快速起航双键
      Row({ space: 8 }) {
        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          Row({ space: 3 }) {
            Text('⚡')
              .fontSize(11)
            Text($r('app.string.widget_start_15m'))
              .fontSize(11)
              .fontColor('#0A1520')
              .fontWeight(FontWeight.Bold)
          }
          .padding({ left: 8, right: 8, top: 5, bottom: 5 })
        }
        .layoutWeight(1)
        .backgroundColor('#4EDEA3')
        .onClick(() => {
          this.startQuickFocus(15);
        })

        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          Row({ space: 3 }) {
            Text('🎯')
              .fontSize(11)
            Text($r('app.string.widget_start_25m'))
              .fontSize(11)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
          }
          .padding({ left: 8, right: 8, top: 5, bottom: 5 })
        }
        .layoutWeight(1)
        .backgroundColor('#26FFFFFF')
        .onClick(() => {
          this.startQuickFocus(25);
        })
      }
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding(14)
    .justifyContent(FlexAlign.SpaceBetween)
  }

  /**
   * 2x4 规格全景万物互联宽卡
   */
  @Builder
  private buildWide2x4Layout() {
    Row({ space: 14 }) {
      // 1. 左侧生境与境界视窗 (50%)
      Column() {
        Row() {
          Row({ space: 4 }) {
            Circle()
              .width(6)
              .height(6)
              .fill(this.biomeSlot === 'DAWN' ? '#FBBF24' : (this.biomeSlot === 'DAY' ? '#38BDF8' : '#A78BFA'))
            Text(this.biomeTitle)
              .fontSize(11)
              .fontColor('#CCFFFFFF')
              .fontWeight(FontWeight.Medium)
          }
          .padding({ left: 6, right: 6, top: 3, bottom: 3 })
          .backgroundColor('#22FFFFFF')
          .borderRadius(10)

          Blank()

          // 境界等级勋章
          if (this.realmName) {
            Text(`Lv.${this.realmLevel} ${this.realmName}`)
              .fontSize(10)
              .fontColor('#4EDEA3')
              .fontWeight(FontWeight.Bold)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor('#1A4EDEA3')
              .borderRadius(6)
          }
        }
        .width('100%')

        Blank()

        // 核心时间与打卡天数
        Row({ space: 6 }) {
          Row({ space: 3 }) {
            Text(`${this.todayMinutes}`)
              .fontSize(28)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Bold)
            Text($r('app.string.widget_minutes_unit'))
              .fontSize(11)
              .fontColor('#80FFFFFF')
              .alignSelf(ItemAlign.End)
              .margin({ bottom: 4 })
          }

          Blank()

          if (this.streakDays > 0) {
            Row({ space: 2 }) {
              Text('🔥')
                .fontSize(11)
              Text(`${this.streakDays}`)
                .fontSize(11)
                .fontWeight(FontWeight.Bold)
                .fontColor('#F59E0B')
              Text($r('app.string.widget_streak_days'))
                .fontSize(9)
                .fontColor('#CCFFFFFF')
            }
            .padding({ left: 6, right: 6, top: 3, bottom: 3 })
            .backgroundColor('#1AF59E0B')
            .borderRadius(8)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Bottom)

        Blank()

        // 湖泊储水进度条
        Column({ space: 3 }) {
          Row() {
            Text($r('app.string.widget_lake_storage_text'))
              .fontSize(10)
              .fontColor('#80FFFFFF')
            Blank()
            Text(`${this.lakeStoragePercent}%`)
              .fontSize(10)
              .fontColor('#4EDEA3')
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')

          Progress({ value: this.lakeStoragePercent, total: 100, type: ProgressType.Linear })
            .width('100%')
            .color('#4EDEA3')
            .backgroundColor('#22FFFFFF')
            .style({ strokeWidth: 4 })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .onClick(() => {
        this.openAppHome();
      })

      // 微晶半透明分割线
      Column()
        .width(1)
        .height('85%')
        .backgroundColor('#22FFFFFF')
        .alignSelf(ItemAlign.Center)

      // 2. 右侧万物互联与多档起航中枢 (50%)
      Column() {
        // 顶部行：节气朱砂篆刻印章与星闪万物互联徽标
        Row() {
          // 节气朱砂篆刻印
          if (this.solarTermSeal || this.solarTermName) {
            Row({ space: 4 }) {
              Text('❖')
                .fontSize(8)
                .fontColor('#FDE047')
              Text(this.solarTermSeal || this.solarTermName)
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FDE047')
                .letterSpacing(1)
            }
            .padding({ left: 6, right: 6, top: 3, bottom: 3 })
            .backgroundColor('#991B1B')
            .borderRadius(4)
            .border({ width: 1, color: '#FBBF24' })
          }

          Blank()

          // 星闪万物互联状态芯片
          Row({ space: 4 }) {
            Circle()
              .width(5)
              .height(5)
              .fill(this.isNearLinkActive ? '#10B981' : '#60A5FA')
            Text(this.isNearLinkActive ? $r('app.string.widget_nearlink_ready') : $r('app.string.widget_nearlink_idle'))
              .fontSize(9)
              .fontColor(this.isNearLinkActive ? '#34D399' : '#93C5FD')
              .fontWeight(FontWeight.Medium)
          }
          .padding({ left: 6, right: 6, top: 3, bottom: 3 })
          .backgroundColor('#1A0F172A')
          .borderRadius(10)
          .border({ width: 1, color: this.isNearLinkActive ? 'rgba(16, 185, 129, 0.4)' : 'rgba(96, 165, 250, 0.3)' })
        }
        .width('100%')

        Blank()

        // 标签胶囊指示
        Row() {
          if (this.currentTag) {
            Text(this.currentTag)
              .fontSize(10)
              .fontColor('#4EDEA3')
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor('#1A4EDEA3')
              .borderRadius(6)
          }
        }
        .width('100%')

        Blank()

        // 底部三列万物互联起航按钮阵列
        Row({ space: 6 }) {
          Button({ type: ButtonType.Capsule, stateEffect: true }) {
            Text($r('app.string.widget_start_15m'))
              .fontSize(10)
              .fontColor('#0A1520')
              .fontWeight(FontWeight.Bold)
              .padding({ left: 6, right: 6, top: 6, bottom: 6 })
          }
          .layoutWeight(1)
          .backgroundColor('#4EDEA3')
          .onClick(() => {
            this.startQuickFocus(15);
          })

          Button({ type: ButtonType.Capsule, stateEffect: true }) {
            Text($r('app.string.widget_start_25m'))
              .fontSize(10)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
              .padding({ left: 6, right: 6, top: 6, bottom: 6 })
          }
          .layoutWeight(1)
          .backgroundColor('#26FFFFFF')
          .onClick(() => {
            this.startQuickFocus(25);
          })

          Button({ type: ButtonType.Capsule, stateEffect: true }) {
            Text($r('app.string.widget_start_45m'))
              .fontSize(10)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
              .padding({ left: 6, right: 6, top: 6, bottom: 6 })
          }
          .layoutWeight(1)
          .backgroundColor('#26FFFFFF')
          .onClick(() => {
            this.startQuickFocus(45);
          })
        }
        .width('100%')
      }
      .layoutWeight(1)
      .height('100%')
      .justifyContent(FlexAlign.SpaceBetween)
    }
    .width('100%')
    .height('100%')
    .padding(14)
  }
}

