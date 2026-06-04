import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { UserProfile, UserRole } from '../../model/UserModel'
import { SmsService } from '../../service/SmsService'
import { UserDao } from '../../service/UserDao'

@Entry
@Component
struct BindPhonePage {
  @State phoneNumber: string = ''
  @State verifyCode: string = ''
  @State password: string = ''
  @State isSendingCode: boolean = false
  @State countDown: number = 0
  @State platform: string = ''
  @State openId: string = ''
  @State nickname: string = ''
  @State avatar: string = ''

  private userDao: UserDao = new UserDao()
  private smsService: SmsService = new SmsService()

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>
    if (params) {
      this.platform = (params['platform'] as string) || ''
      this.openId = (params['openId'] as string) || ''
      this.nickname = (params['nickname'] as string) || ''
      this.avatar = (params['avatar'] as string) || ''
    }
  }

  async sendVerifyCode(): Promise<void> {
    if (this.phoneNumber.length < 11) {
      AlertDialog.show({ message: '请输入正确的手机号' })
      return
    }
    this.isSendingCode = true
    this.countDown = 60
    const timer = setInterval(() => {
      this.countDown--
      if (this.countDown <= 0) {
        clearInterval(timer)
        this.isSendingCode = false
      }
    }, 1000)
    const result = await this.smsService.sendVerifyCode(this.phoneNumber)
    if (!result.success) {
      clearInterval(timer)
      this.countDown = 0
      this.isSendingCode = false
      AlertDialog.show({ message: result.message })
    }
  }

  async bindAndLogin(): Promise<void> {
    if (!this.phoneNumber || !this.verifyCode) {
      AlertDialog.show({ message: '请完整填写手机号和验证码' })
      return
    }
    if (!this.password || this.password.length < 6) {
      AlertDialog.show({ message: '请设置至少 6 位密码' })
      return
    }
    const verifyResult = await this.smsService.verifyCode(this.phoneNumber, this.verifyCode)
    if (!verifyResult.success) {
      AlertDialog.show({ message: verifyResult.message })
      return
    }
    const isBound = await this.userDao.isPhoneBound(this.phoneNumber)
    if (isBound) {
      AlertDialog.show({ message: '该手机号已绑定其他账号' })
      return
    }

    const user: UserProfile = {
      userId: this.openId ? `${this.platform}_${this.openId}` : `phone_${this.phoneNumber}`,
      phone: this.phoneNumber,
      password: this.password,
      role: UserRole.JOB_SEEKER,
      isGuest: false,
      realName: this.nickname || '',
      avatar: this.avatar || ''
    }

    await this.userDao.logoutAll()
    await this.userDao.insertUser(user)
    AppState.currentUser = user
    AppState.isLoggedIn = true
    AppState.isGuest = false
    router.replaceUrl({ url: AppConstants.ROUTE_IDENTITY_GUIDE })
  }

  build() {
    Column() {
      Row() {
        Button() {
          Image($r('sys.symbol.chevron_left'))
            .width(24)
            .height(24)
            .fillColor('#1A1A1A')
        }
        .backgroundColor('transparent')
        .onClick(() => router.back())
        Blank()
      }
      .width('100%')
      .padding(16)
      .margin({ top: 28 })

      Column() {
        Text('绑定手机号')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 8 })
        Text(`为确保平台真实可信，${this.platform === 'wechat' ? '微信' : 'QQ'}登录后仍需绑定真实手机号`)
          .fontSize(13)
          .fontColor('#999999')
          .textAlign(TextAlign.Center)
          .width('80%')
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 48, bottom: 32 })

      Column() {
        Row() {
          Text('+86')
            .fontSize(15)
            .padding({ right: 8 })
            .border({ width: { right: 1 }, color: '#E5E5E5' })
          TextInput({ placeholder: '请输入手机号', text: this.phoneNumber })
            .layoutWeight(1)
            .fontSize(15)
            .type(InputType.Number)
            .maxLength(11)
            .onChange((value: string) => { this.phoneNumber = value })
            .padding({ left: 12 })
        }
        .width('80%')
        .height(48)
        .border({ width: 1, color: '#E5E5E5', radius: 8 })
        .padding({ left: 12, right: 12 })
        .margin({ bottom: 16 })

        Row() {
          TextInput({ placeholder: '验证码', text: this.verifyCode })
            .layoutWeight(1)
            .fontSize(15)
            .type(InputType.Number)
            .maxLength(6)
            .onChange((value: string) => { this.verifyCode = value })
            .padding({ left: 12 })

          Button(this.isSendingCode ? `${this.countDown}s` : '获取验证码')
            .fontSize(12)
            .height(32)
            .backgroundColor(this.isSendingCode ? '#E5E5E5' : AppConstants.COLOR_PRIMARY)
            .fontColor(this.isSendingCode ? '#999999' : '#FFFFFF')
            .borderRadius(16)
            .enabled(!this.isSendingCode)
            .onClick(() => this.sendVerifyCode())
        }
        .width('80%')
        .height(48)
        .border({ width: 1, color: '#E5E5E5', radius: 8 })
        .padding({ left: 12, right: 12 })
        .margin({ bottom: 16 })

        Row() {
          TextInput({ placeholder: '设置登录密码（至少 6 位）', text: this.password })
            .layoutWeight(1)
            .fontSize(15)
            .type(InputType.Password)
            .maxLength(20)
            .onChange((value: string) => { this.password = value })
            .padding({ left: 12 })
        }
        .width('80%')
        .height(48)
        .border({ width: 1, color: '#E5E5E5', radius: 8 })
        .padding({ left: 12, right: 12 })
        .margin({ bottom: 32 })

        Button('完成绑定并继续')
          .width('80%')
          .height(48)
          .fontSize(16)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .borderRadius(24)
          .onClick(() => this.bindAndLogin())
      }
      .width('100%')
      .alignItems(HorizontalAlign.Center)

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
