// 首次使用 - 协议同意与权限获取页

import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../common/constants/AppConstants'
import { abilityAccessCtrl, Permissions } from '@kit.AbilityKit'
import { common } from '@kit.AbilityKit'
import { BusinessError } from '@kit.BasicServicesKit'

@Entry
@Component
struct WelcomePage {
  @State agreementChecked: boolean = false
  @State showAgreementDetail: boolean = false
  @State permissionGranted: boolean = false
  @State isLoading: boolean = false

  async requestPermissions(): Promise<void> {
    if (this.isLoading) {
      return
    }
    this.isLoading = true
    try {
      const atManager = abilityAccessCtrl.createAtManager()
      const context = getContext(this) as common.UIAbilityContext
      const permissions: Permissions[] = [
        'ohos.permission.CAMERA',
        'ohos.permission.APPROXIMATELY_LOCATION'
      ]
      const result = await atManager.requestPermissionsFromUser(context, permissions)
      this.permissionGranted = result.authResults.every(r => r === 0)
    } catch (err) {
      const e = err as BusinessError
      console.error('权限申请失败: ' + e.message)
      this.permissionGranted = false
    }
    this.navigateToNext()
  }

  navigateToNext(): void {
    this.isLoading = false
    AppState.agreementAccepted = true
    router.replaceUrl({ url: AppConstants.ROUTE_INDEX })
  }

  build() {
    Stack() {
      Column() {
        Column() {
          Image($r('app.media.startIcon'))
            .width(80)
            .height(80)
            .margin({ bottom: 16 })
          Text(AppConstants.APP_NAME)
            .fontSize(28)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text(AppConstants.APP_SUBTITLE)
            .fontSize(14)
            .fontColor('rgba(255,255,255,0.7)')
            .margin({ top: 4 })
        }
        .width('100%')
        .height('35%')
        .backgroundColor(AppConstants.COLOR_PRIMARY)
        .justifyContent(FlexAlign.Center)

        Column() {
          Text('为你护航求职之路')
            .fontSize(18)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
            .margin({ top: 32, bottom: 8 })
          Text('智能匹配 · 校友引路 · AI避坑')
            .fontSize(13)
            .fontColor(AppConstants.COLOR_TEXT_HINT)

          Blank()

          // 协议复选框
          Row() {
            Checkbox()
              .select(this.agreementChecked)
              .selectedColor('#4A90D9')
              .onChange((value: boolean) => { this.agreementChecked = value })

            Text('已阅读并同意')
              .fontSize(13)
              .fontColor('#666666')
              .margin({ left: 6 })

            Text('《用户协议》和《隐私政策》')
              .fontSize(13)
              .fontColor('#4A90D9')
              .onClick(() => { this.showAgreementDetail = true })

            Text('ⓘ')
              .fontSize(18)
              .fontColor('#999999')
              .margin({ left: 2 })
              .onClick(() => { this.showAgreementDetail = true })
          }
          .margin({ bottom: 16 })

          Button(this.isLoading ? '正在进入...' : '同意并开始使用')
            .width('85%')
            .height(48)
            .fontSize(16)
            .backgroundColor(this.agreementChecked ? '#4A90D9' : '#CCCCCC')
            .borderRadius(24)
            .enabled(this.agreementChecked && !this.isLoading)
            .onClick(() => { this.requestPermissions() })
            .margin({ bottom: 24 })
        }
        .width('100%')
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Center)
      }
      .width('100%')
      .height('100%')

      // 协议详情弹窗
      if (this.showAgreementDetail) {
        Column() {
          Column() {
            Row() {
              Text('用户协议与隐私政策')
                .fontSize(18)
                .fontWeight(FontWeight.Bold)
              Blank()
              Text('✕')
                .fontSize(20)
                .fontColor('#999999')
                .onClick(() => { this.showAgreementDetail = false })
            }
            .width('100%')
            .margin({ bottom: 16 })

            Scroll() {
              Column() {
                Text('一、总则\n本协议是您与"校招护航"平台之间关于使用本平台服务所订立的协议。请您仔细阅读本协议的全部内容。一旦您使用本平台服务，即视为您已阅读并同意接受本协议所有条款的约束。\n\n本平台有权根据需要不时修改协议条款，修改后的协议一经发布即生效。您继续使用本平台服务即表示您接受修改后的协议。')
                  .fontSize(13)
                  .fontColor('#666666')
                  .lineHeight(22)
                  .margin({ bottom: 16 })

                Text('二、隐私政策\n我们重视您的隐私。本隐私政策说明了我们如何收集、使用和保护您的个人信息。我们收集的信息包括但不限于：您主动提供的个人信息（姓名、手机号、学校等），以及您使用服务过程中自动产生的信息（浏览记录、投递记录等）。\n\n我们采用业界通行的安全措施保护您的数据安全，但无法保证100%的安全。未经您的明确同意，我们不会将您的个人信息出售或共享给第三方。')
                  .fontSize(13)
                  .fontColor('#666666')
                  .lineHeight(22)
                  .margin({ bottom: 16 })

                Text('三、数据安全\n我们采用加密传输、访问控制、数据脱敏等安全措施保护您的数据。您理解并同意，尽管我们采取了合理的技术手段，但由于互联网环境的复杂性，我们无法保证您的信息在传输和存储过程中的绝对安全。\n\n如发生个人信息安全事件，我们将按照法律法规的要求及时告知您。')
                  .fontSize(13)
                  .fontColor('#666666')
                  .lineHeight(22)
              }
              .padding({ left: 8, right: 8 })
            }
            .height(350)
          }
          .width('85%')
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .padding(20)
        }
        .width('100%')
        .height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }
}
