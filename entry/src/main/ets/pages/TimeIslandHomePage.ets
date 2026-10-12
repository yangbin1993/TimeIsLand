import { AppRouter, DialogHelper } from '@app/common';
import { FocusState, FocusTag } from '../model/FocusTypes';
import { FocusTimerViewModel, FocusTimerEffect } from '../viewmodel/FocusTimerViewModel';
import { FocusRingView } from '../components/FocusRingView';
import { TagSelectorView } from '../components/TagSelectorView';
import { TimeDurationSelector } from '../components/TimeDurationSelector';
import { router } from '@kit.ArkUI';

/**
 * 路由分发器 Builder 声明
 */
@Builder
export function TimeIslandHomeBuilder() {
  TimeIslandHomePage()
}

/**
 * 时光岛 - 沉浸专注番茄钟主页面
 */
@Entry
@Component
export struct TimeIslandHomePage {
  @State private vm: FocusTimerViewModel = new FocusTimerViewModel();

  aboutToAppear(): void {
    // 监听 MVI 副作用流
    this.vm.observeEffect((effect: FocusTimerEffect): void => {
      this.handleEffect(effect);
    });
    // 触发数据初始化
    this.vm.dispatch({ type: 'INIT_DATA' });
  }

  aboutToDisappear(): void {
    this.vm.onCleared();
  }

  private handleEffect(effect: FocusTimerEffect): void {
    if (effect.type === 'SHOW_TOAST') {
      if (effect.messageKey === 'timeisland_toast_focus_completed') {
        DialogHelper.showToast($r('app.string.timeisland_toast_focus_completed'));
      } else if (effect.messageKey === 'timeisland_toast_give_up') {
        DialogHelper.showToast($r('app.string.timeisland_toast_give_up'));
      } else if (effect.messageKey === 'timeisland_toast_cannot_change_duration') {
        DialogHelper.showToast($r('app.string.timeisland_toast_cannot_change_duration'));
      }
    }
  }

  build() {
    NavDestination() {
      Column() {
        // 顶部导航栏
        Row() {
          Text($r('app.string.timeisland_nav_title'))
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1F2329')

          Blank()

          Button({ type: ButtonType.Normal, stateEffect: true }) {
            Row({ space: 4 }) {
              Text($r('app.string.timeisland_nav_stats'))
                .fontSize(14)
                .fontColor('#4A90E2')
                .fontWeight(FontWeight.Medium)
            }
          }
          .backgroundColor('#F0F5FF')
          .borderRadius(16)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .onClick(() => {
            router.pushUrl({ url: 'pages/FocusStatsPage' });
          })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 12, bottom: 8 })

        // 今日累计概览横幅
        Row({ space: 16 }) {
          Column({ space: 4 }) {
            Text($r('app.string.timeisland_today_focused'))
              .fontSize(12)
              .fontColor('#8F959E')
            Row({ space: 2 }) {
              Text(this.vm.state.todayTotalMinutes.toString())
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1F2329')
              Text($r('app.string.timeisland_unit_minutes'))
                .fontSize(12)
                .fontColor('#8F959E')
                .margin({ bottom: 2 })
            }
            .alignItems(VerticalAlign.Bottom)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .shadow({ radius: 8, color: '#0A000000', offsetY: 2 })

          Column({ space: 4 }) {
            Text($r('app.string.timeisland_today_pomodoro'))
              .fontSize(12)
              .fontColor('#8F959E')
            Row({ space: 2 }) {
              Text(this.vm.state.todayCompletedCount.toString())
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1F2329')
              Text($r('app.string.timeisland_unit_count'))
                .fontSize(12)
                .fontColor('#8F959E')
                .margin({ bottom: 2 })
            }
            .alignItems(VerticalAlign.Bottom)
          }
          .layoutWeight(1)
          .alignItems(HorizontalAlign.Start)
          .padding(14)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .shadow({ radius: 8, color: '#0A000000', offsetY: 2 })
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 8, bottom: 8 })

        // 核心专注动效圆环
        FocusRingView({
          progress: this.vm.state.progress,
          timeText: this.vm.state.formattedTime,
          state: this.vm.state.status,
          tagColor: this.vm.state.currentTag ? this.vm.state.currentTag.colorHex : '#4A90E2',
          tagName: this.vm.state.currentTag ? this.vm.state.currentTag.name : ''
        })

        // 操作控制核心按钮区
        this.buildActionControls()

        Blank()

        // 底部配置区：标签选择器与时长芯片
        Column({ space: 14 }) {
          TagSelectorView({
            tags: this.vm.state.tags,
            selectedTagId: this.vm.state.currentTag ? this.vm.state.currentTag.id : 1,
            onSelectTag: (tag: FocusTag) => {
              this.vm.dispatch({ type: 'SELECT_TAG', tag });
            }
          })

          TimeDurationSelector({
            selectedMinutes: this.vm.state.selectedMinutes,
            disabled: this.vm.state.status !== FocusState.IDLE,
            onSelectMinutes: (mins: number) => {
              this.vm.dispatch({ type: 'SELECT_DURATION', minutes: mins });
            }
          })
        }
        .width('100%')
        .margin({ bottom: 24 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FAFAFC')
    }
    .hideTitleBar(true)
  }

  @Builder
  private buildActionControls() {
    Row({ space: 16 }) {
      if (this.vm.state.status === FocusState.IDLE) {
        Button($r('app.string.timeisland_btn_start'), { type: ButtonType.Capsule, stateEffect: true })
          .width(200)
          .height(48)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor(this.vm.state.currentTag ? this.vm.state.currentTag.colorHex : '#4A90E2')
          .shadow({ radius: 10, color: '#404A90E2', offsetY: 4 })
          .onClick(() => {
            this.vm.dispatch({ type: 'START_TIMER' });
          })
      } else if (this.vm.state.status === FocusState.RUNNING) {
        Button($r('app.string.timeisland_btn_pause'), { type: ButtonType.Capsule, stateEffect: true })
          .width(130)
          .height(44)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor('#F5A623')
          .onClick(() => {
            this.vm.dispatch({ type: 'PAUSE_TIMER' });
          })

        Button($r('app.string.timeisland_btn_complete'), { type: ButtonType.Capsule, stateEffect: true })
          .width(130)
          .height(44)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor('#52C41A')
          .onClick(() => {
            this.vm.dispatch({ type: 'COMPLETE_TIMER' });
          })
      } else if (this.vm.state.status === FocusState.PAUSED) {
        Button($r('app.string.timeisland_btn_resume'), { type: ButtonType.Capsule, stateEffect: true })
          .width(130)
          .height(44)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor(this.vm.state.currentTag ? this.vm.state.currentTag.colorHex : '#4A90E2')
          .onClick(() => {
            this.vm.dispatch({ type: 'RESUME_TIMER' });
          })

        Button($r('app.string.timeisland_btn_give_up'), { type: ButtonType.Capsule, stateEffect: true })
          .width(130)
          .height(44)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .backgroundColor('#FF4D4F')
          .onClick(() => {
            this.vm.dispatch({ type: 'GIVE_UP_TIMER' });
          })
      }
    }
    .margin({ top: 8, bottom: 16 })
  }
}
