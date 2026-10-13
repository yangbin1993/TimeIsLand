let cardLocalStorage = new LocalStorage();

/**
 * 时光岛 - 桌面元服务原子化卡片 (2x2 / 2x4 自适应)
 * 职责: 桌面免开应用透视岛屿晨昏微气候、今日心流储水量，支持一键 15min/25min 极速起航
 */
@Entry(cardLocalStorage)
@Component
struct IslandCardView {
  @LocalStorageProp('todayMinutes') todayMinutes: number = 45;
  @LocalStorageProp('currentTag') currentTag: string = '';
  @LocalStorageProp('biomeSlot') biomeSlot: string = 'DAY';
  @LocalStorageProp('biomeTitle') biomeTitle: string = '';
  @LocalStorageProp('lakeStoragePercent') lakeStoragePercent: number = 60;

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

  build() {
    Stack({ alignContent: Alignment.TopStart }) {
      // 1. 晨昏岛屿微气候氛围渐变背景
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

      // 2. 岛屿微缩装饰发光圆晕
      Circle()
        .width(160)
        .height(160)
        .fill(this.biomeSlot === 'NIGHT' ? '#1A3350' : '#2A4A68')
        .opacity(0.35)
        .blur(40)
        .position({ x: -20, y: -20 })

      // 3. 卡片主内容区
      Column() {
        // 顶部行：生境时段徽章与标签胶囊
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

          // 标签胶囊
          Text(this.currentTag)
            .fontSize(10)
            .fontColor('#4EDEA3')
            .padding({ left: 6, right: 6, top: 3, bottom: 3 })
            .backgroundColor('#1A4EDEA3')
            .borderRadius(8)
        }
        .width('100%')

        Blank()

        // 中间行：今日心流核心数据与湖泊能量
        Row() {
          Column({ space: 2 }) {
            Row({ space: 4 }) {
              Text(`${this.todayMinutes}`)
                .fontSize(32)
                .fontColor('#FFFFFF')
                .fontWeight(FontWeight.Bold)
              Text($r('app.string.widget_minutes_unit'))
                .fontSize(12)
                .fontColor('#80FFFFFF')
                .alignSelf(ItemAlign.End)
                .margin({ bottom: 6 })
            }

            Row({ space: 2 }) {
              Text($r('app.string.widget_lake_storage_text'))
                .fontSize(11)
                .fontColor('#99FFFFFF')
              Text(` ${this.lakeStoragePercent}%`)
                .fontSize(11)
                .fontColor('#99FFFFFF')
            }
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          // 微缩水滴储水进度指示
          Stack({ alignContent: Alignment.Center }) {
            Progress({ value: this.lakeStoragePercent, total: 100, type: ProgressType.Ring })
              .width(44)
              .height(44)
              .color('#4EDEA3')
              .backgroundColor('#20FFFFFF')
              .style({ strokeWidth: 4 })

            Text('🌊')
              .fontSize(14)
          }
        }
        .width('100%')

        Blank()

        // 底部行：一键免开 App 快速起航胶囊按钮
        Row({ space: 8 }) {
          // 15分钟心流按钮
          Button({ type: ButtonType.Capsule, stateEffect: true }) {
            Row({ space: 4 }) {
              Text('⏱️')
                .fontSize(12)
              Text($r('app.string.widget_start_15m'))
                .fontSize(12)
                .fontColor('#0A1520')
                .fontWeight(FontWeight.Bold)
            }
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          }
          .backgroundColor('#4EDEA3')
          .onClick(() => {
            this.startQuickFocus(15);
          })

          // 25分钟经典专注按钮
          Button({ type: ButtonType.Capsule, stateEffect: true }) {
            Text($r('app.string.widget_start_25m'))
              .fontSize(12)
              .fontColor('#FFFFFF')
              .fontWeight(FontWeight.Medium)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          }
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
    .width('100%')
    .height('100%')
    .backgroundColor('#0F172A')
  }
}
