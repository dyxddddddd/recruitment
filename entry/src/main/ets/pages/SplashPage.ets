// 启动广告页 - 全屏展示品牌图，3秒倒计时或点击跳过

import { router, window } from '@kit.ArkUI'
import { AppConstants } from '../common/constants/AppConstants'

@Entry
@Component
struct SplashPage {
  @State countDown: number = 3
  private timerId: number = -1

  aboutToAppear(): void {
    const win = window.getLastWindow(getContext(this))
    win.then((w: window.Window) => {
      w.setWindowLayoutFullScreen(true)
    })

    this.timerId = setInterval(() => {
      this.countDown--
      if (this.countDown <= 0) {
        this.goToNext()
      }
    }, 1000)
  }

  aboutToDisappear(): void {
    clearInterval(this.timerId)
  }

  goToNext(): void {
    clearInterval(this.timerId)
    router.replaceUrl({ url: AppConstants.ROUTE_WELCOME })
  }

  build() {
    Stack() {
      Image($r('app.media.splash_image'))
        .width('100%')
        .height('100%')
        .objectFit(ImageFit.Fill)

      Column() {
        Row() {
          Blank()
          Button(`跳过 ${this.countDown}s`)
            .fontSize(12)
            .height(30)
            .backgroundColor('rgba(0,0,0,0.4)')
            .fontColor('#FFFFFF')
            .borderRadius(15)
            .padding({ left: 14, right: 14 })
            .onClick(() => this.goToNext())
        }
        .width('100%')
        .padding({ right: 16, top: 48 })

        Blank()
      }
      .width('100%')
      .height('100%')
    }
    .width('100%')
    .height('100%')
    .clip(true)
  }
}
