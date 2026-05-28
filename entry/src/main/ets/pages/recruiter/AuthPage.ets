// 招聘者 - 企业资质认证页

import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { UserProfile, VipLevel } from '../../model/UserModel'
import { UserDao } from '../../service/UserDao'

@Entry
@Component
struct AuthPage {
  @State hrRealName: string = ''
  @State hrIdCard: string = ''
  @State companyName: string = ''
  @State businessLicenseUploaded: boolean = false
  @State isSubmitting: boolean = false
  private userDao: UserDao = new UserDao()

  async handleSubmit(): Promise<void> {
    if (!this.hrRealName || !this.hrIdCard || !this.companyName) {
      AlertDialog.show({ message: '请填写完整信息' })
      return
    }
    if (!this.businessLicenseUploaded) {
      AlertDialog.show({ message: '请上传营业执照' })
      return
    }

    this.isSubmitting = true

    setTimeout(async () => {
      this.isSubmitting = false
      if (AppState.currentUser) {
        AppState.currentUser.hrRealName = this.hrRealName
        AppState.currentUser.idCard = this.hrIdCard
        AppState.currentUser.companyName = this.companyName
        AppState.currentUser.vipLevel = VipLevel.NORMAL
        AppState.currentUser.positionCount = 0
        await this.userDao.updateUser(AppState.currentUser)
      }
      AlertDialog.show({
        title: '认证提交成功',
        message: '您的企业资质已提交审核，预计1-2个工作日内完成。审核通过后即可发布岗位。',
        primaryButton: { value: '返回', action: () => router.back() }
      })
    }, 1500)
  }

  build() {
    Column() {
      // 顶部导航
      Row() {
        Button() {
          Image($r('sys.symbol.chevron_left'))
            .width(24)
            .height(24)
            .fillColor('#1A1A1A')
        }
        .backgroundColor('transparent')
        .onClick(() => router.back())

        Text('企业资质认证')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 28, bottom: 8 })

      Scroll() {
        Column() {
          // 说明
          Column() {
            Text('🔒')
              .fontSize(36)
              .margin({ bottom: 12 })
            Text('合规准入认证')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 8 })
            Text('为保障求职者安全，所有招聘者须完成企业资质认证后方可发布岗位。您提交的信息将严格保密。')
              .fontSize(13)
              .fontColor('#666666')
              .lineHeight(20)
              .textAlign(TextAlign.Center)
              .width('85%')
          }
          .width('100%')
          .padding(24)
          .margin({ bottom: 16 })
          .alignItems(HorizontalAlign.Center)

          // 表单
          Column() {
            Text('1. HR实名信息')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .alignSelf(ItemAlign.Start)

            this.FormInput('真实姓名', this.hrRealName, '请输入您的真实姓名', (v) => this.hrRealName = v)
            this.FormInput('身份证号', this.hrIdCard, '请输入身份证号码', (v) => this.hrIdCard = v)

            Divider().height(1).color('#F0F0F0').margin({ top: 8, bottom: 16 })

            Text('2. 企业信息')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .alignSelf(ItemAlign.Start)

            this.FormInput('企业全称', this.companyName, '请输入企业全称', (v) => this.companyName = v)

            // 营业执照上传
            Column() {
              Text('营业执照')
                .fontSize(13)
                .fontColor('#666666')
                .margin({ bottom: 8 })
                .alignSelf(ItemAlign.Start)

              Column() {
                if (this.businessLicenseUploaded) {
                  Text('✅')
                    .fontSize(32)
                    .margin({ bottom: 4 })
                  Text('营业执照已上传')
                    .fontSize(13)
                    .fontColor(AppConstants.COLOR_SUCCESS)
                } else {
                  Image($r('sys.symbol.camera'))
                    .width(32)
                    .height(32)
                    .fillColor('#4A90D9')
                    .margin({ bottom: 4 })
                  Text('拍照上传营业执照')
                    .fontSize(13)
                    .fontColor('#4A90D9')
                }
              }
              .width('100%')
              .height(100)
              .backgroundColor('#F0F7FF')
              .border({ width: 2, color: '#4A90D9', style: BorderStyle.Dashed, radius: 8 })
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .onClick(() => {
                this.businessLicenseUploaded = true
                AlertDialog.show({ message: '营业执照已上传，系统将自动进行法人及工商信息比对。' })
              })
            }
            .width('100%')
            .margin({ bottom: 24 })

            // 说明文字
            Row() {
              Image($r('sys.symbol.checkmark_shield'))
                .width(14)
                .height(14)
                .fillColor(AppConstants.COLOR_SUCCESS)
              Text('系统自动法人与工商信息比对，从源头封杀皮包公司')
                .fontSize(11)
                .fontColor('#999999')
                .margin({ left: 4 })
            }
            .width('100%')
            .margin({ bottom: 16 })

            // 提交按钮
            Button(this.isSubmitting ? '提交中...' : '提交认证')
              .width('90%')
              .height(48)
              .fontSize(16)
              .backgroundColor(AppConstants.COLOR_PRIMARY)
              .fontColor('#FFFFFF')
              .borderRadius(24)
              .enabled(!this.isSubmitting)
              .onClick(() => this.handleSubmit())
              .margin({ bottom: 16 })
          }
          .width('90%')
          .padding(20)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
        }
        .width('100%')
        .padding(16)
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  FormInput(label: string, value: string, placeholder: string, onChange: (v: string) => void) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('#666666')
        .width(80)
      TextInput({ text: value, placeholder: placeholder })
        .layoutWeight(1)
        .fontSize(13)
        .height(40)
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .padding({ left: 12 })
        .onChange(onChange)
    }
    .width('100%')
    .margin({ bottom: 12 })
  }
}
