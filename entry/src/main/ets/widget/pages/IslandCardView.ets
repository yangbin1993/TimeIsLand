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
  private getBackgroundGradient(): Resource[] {
    if (this.biomeSlot === 'DAWN') {
      return [$r('app.color.timeisland_widget_dawn_bg_start'), $r('app.color.timeisland_widget_dawn_bg_end')];
    } else if (this.biomeSlot === 'DAY') {
      return [$r('app.color.timeisland_widget_day_bg_start'), $r('app.color.timeisland_widget_day_bg_end')];
    } else if (this.biomeSlot === 'DUSK') {
      return [$r('app.color.timeisland_widget_dusk_bg_start'), $r('app.color.timeisland_widget_dusk_bg_end')];
    }
    // NIGHT
    return [$r('app.color.timeisland_widget_night_bg_start'), $r('app.color.timeisland_widget_night_bg_end')];
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
        .fill(this.biomeSlot === 'NIGHT' ? $r('app.color.timeisland_widget_glow_night') : $r('app.color.timeisland_widget_glow_day'))
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
    .backgroundColor($r('app.color.timeisland_widget_bg_base'))
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
            .fill(this.biomeSlot === 'DAWN' ? $r('app.color.timeisland_widget_dawn_dot') : (this.biomeSlot === 'DAY' ? $r('app.color.timeisland_widget_day_dot') : $r('app.color.timeisland_widget_dusk_dot')))
          Text(this.biomeTitle)
            .fontSize(11)
            .fontColor($r('app.color.timeisland_widget_text_high'))
            .fontWeight(FontWeight.Medium)
        }
        .padding({ left: 8, right: 8, top: 4, bottom: 4 })
        .backgroundColor($r('app.color.timeisland_widget_pill_bg'))
        .borderRadius(12)

        Blank()

        // 节气朱红印徽章
        if (this.solarTermName) {
          Text(this.solarTermName)
            .fontSize(10)
            .fontColor($r('app.color.timeisland_seal_gold'))
            .fontWeight(FontWeight.Bold)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor($r('app.color.timeisland_seal_cinnabar'))
            .borderRadius(4)
            .border({ width: 1, color: $r('app.color.timeisland_seal_gold_border') })
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
              .fontColor($r('app.color.timeisland_pure_white'))
              .fontWeight(FontWeight.Bold)
            Text($r('app.string.widget_minutes_unit'))
              .fontSize(11)
              .fontColor($r('app.color.timeisland_widget_text_mid'))
              .alignSelf(ItemAlign.End)
              .margin({ bottom: 5 })
          }

          // 生境境界微晶文字
          if (this.realmName) {
            Text(`Lv.${this.realmLevel} ${this.realmName}`)
              .fontSize(10)
              .fontColor($r('app.color.timeisland_emerald'))
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
            .color($r('app.color.timeisland_emerald'))
            .backgroundColor($r('app.color.timeisland_widget_pill_bg_subtle'))
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
              .fontColor($r('app.color.timeisland_pure_black'))
              .fontWeight(FontWeight.Bold)
          }
          .padding({ left: 8, right: 8, top: 5, bottom: 5 })
        }
        .layoutWeight(1)
        .backgroundColor($r('app.color.timeisland_emerald'))
        .onClick(() => {
          this.startQuickFocus(15);
        })

        Button({ type: ButtonType.Capsule, stateEffect: true }) {
          Row({ space: 3 }) {
            Text('🎯')
              .fontSize(11)
            Text($r('app.string.widget_start_25m'))
              .fontSize(11)
              .fontColor($r('app.color.timeisland_pure_white'))
              .fontWeight(FontWeight.Medium)
          }
          .padding({ left: 8, right: 8, top: 5, bottom: 5 })
        }
        .layoutWeight(1)
        .backgroundColor($r('app.color.timeisland_widget_pill_bg_active'))
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
              .fill(this.biomeSlot === 'DAWN' ? $r('app.color.timeisland_widget_dawn_dot') : (this.biomeSlot === 'DAY' ? $r('app.color.timeisland_widget_day_dot') : $r('app.color.timeisland_widget_dusk_dot')))
            Text(this.biomeTitle)
              .fontSize(11)
              .fontColor($r('app.color.timeisland_widget_text_high'))
              .fontWeight(FontWeight.Medium)
          }
          .padding({ left: 6, right: 6, top: 3, bottom: 3 })
          .backgroundColor($r('app.color.timeisland_widget_pill_bg'))
          .borderRadius(10)

          Blank()

          // 境界等级勋章
          if (this.realmName) {
            Text(`Lv.${this.realmLevel} ${this.realmName}`)
              .fontSize(10)
              .fontColor($r('app.color.timeisland_emerald'))
              .fontWeight(FontWeight.Bold)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor($r('app.color.timeisland_widget_quick_start_bg'))
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
              .fontColor($r('app.color.timeisland_pure_white'))
              .fontWeight(FontWeight.Bold)
            Text($r('app.string.widget_minutes_unit'))
              .fontSize(11)
              .fontColor($r('app.color.timeisland_widget_text_mid'))
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
                .fontColor($r('app.color.timeisland_widget_streak_text'))
              Text($r('app.string.widget_streak_days'))
                .fontSize(9)
                .fontColor($r('app.color.timeisland_widget_text_high'))
            }
            .padding({ left: 6, right: 6, top: 3, bottom: 3 })
            .backgroundColor($r('app.color.timeisland_widget_streak_chip_bg'))
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
              .fontColor($r('app.color.timeisland_widget_text_mid'))
            Blank()
            Text(`${this.lakeStoragePercent}%`)
              .fontSize(10)
              .fontColor($r('app.color.timeisland_emerald'))
              .fontWeight(FontWeight.Medium)
          }
          .width('100%')

          Progress({ value: this.lakeStoragePercent, total: 100, type: ProgressType.Linear })
            .width('100%')
            .color($r('app.color.timeisland_emerald'))
            .backgroundColor($r('app.color.timeisland_widget_pill_bg'))
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
        .backgroundColor($r('app.color.timeisland_widget_pill_bg'))
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
                .fontColor($r('app.color.timeisland_seal_gold'))
              Text(this.solarTermSeal || this.solarTermName)
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.timeisland_seal_gold'))
                .letterSpacing(1)
            }
            .padding({ left: 6, right: 6, top: 3, bottom: 3 })
            .backgroundColor($r('app.color.timeisland_seal_cinnabar'))
            .borderRadius(4)
            .border({ width: 1, color: $r('app.color.timeisland_seal_gold_border') })
          }

          Blank()

          // 星闪万物互联状态芯片
          Row({ space: 4 }) {
            Circle()
              .width(5)
              .height(5)
              .fill(this.isNearLinkActive ? $r('app.color.timeisland_widget_nearlink_active_dot') : $r('app.color.timeisland_widget_nearlink_idle_dot'))
            Text(this.isNearLinkActive ? $r('app.string.widget_nearlink_ready') : $r('app.string.widget_nearlink_idle'))
              .fontSize(9)
              .fontColor(this.isNearLinkActive ? $r('app.color.timeisland_widget_nearlink_active_text') : $r('app.color.timeisland_widget_nearlink_idle_text'))
              .fontWeight(FontWeight.Medium)
          }
          .padding({ left: 6, right: 6, top: 3, bottom: 3 })
          .backgroundColor($r('app.color.timeisland_widget_nearlink_chip_bg'))
          .borderRadius(10)
          .border({ width: 1, color: this.isNearLinkActive ? $r('app.color.timeisland_widget_nearlink_border_active') : $r('app.color.timeisland_widget_nearlink_border_idle') })
        }
        .width('100%')

        Blank()

        // 标签胶囊指示
        Row() {
          if (this.currentTag) {
            Text(this.currentTag)
              .fontSize(10)
              .fontColor($r('app.color.timeisland_emerald'))
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor($r('app.color.timeisland_widget_quick_start_bg'))
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
              .fontColor($r('app.color.timeisland_pure_black'))
              .fontWeight(FontWeight.Bold)
              .padding({ left: 6, right: 6, top: 6, bottom: 6 })
          }
          .layoutWeight(1)
          .backgroundColor($r('app.color.timeisland_emerald'))
          .onClick(() => {
            this.startQuickFocus(15);
          })

          Button({ type: ButtonType.Capsule, stateEffect: true }) {
            Text($r('app.string.widget_start_25m'))
              .fontSize(10)
              .fontColor($r('app.color.timeisland_pure_white'))
              .fontWeight(FontWeight.Medium)
              .padding({ left: 6, right: 6, top: 6, bottom: 6 })
          }
          .layoutWeight(1)
          .backgroundColor($r('app.color.timeisland_widget_pill_bg_active'))
          .onClick(() => {
            this.startQuickFocus(25);
          })

          Button({ type: ButtonType.Capsule, stateEffect: true }) {
            Text($r('app.string.widget_start_45m'))
              .fontSize(10)
              .fontColor($r('app.color.timeisland_pure_white'))
              .fontWeight(FontWeight.Medium)
              .padding({ left: 6, right: 6, top: 6, bottom: 6 })
          }
          .layoutWeight(1)
          .backgroundColor($r('app.color.timeisland_widget_pill_bg_active'))
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

