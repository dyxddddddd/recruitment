// 登录页面 - 手机号（密码/验证码）/微信/QQ + 游客模式

import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { UserProfile, UserRole } from '../../model/UserModel'
import { UserDao } from '../../service/UserDao'

@Entry
@Component
struct LoginPage {
  @State phoneNumber: string = ''
  @State password: string = ''
  @State verifyCode: string = ''
  @State isSendingCode: boolean = false
  @State countDown: number = 0
  @State loginType: number = 0
  @State loginSubType: number = 0
  private userDao: UserDao = new UserDao()

  sendVerifyCode(): void {
    if (this.phoneNumber.length < 11) {
      this.showToast('请输入正确的手机号')
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
  }

  async handlePasswordLogin(): Promise<void> {
    if (!this.phoneNumber || !this.password) {
      this.showToast('请输入手机号和密码')
      return
    }
    const user = await this.userDao.getUserByPhoneAndPassword(this.phoneNumber, this.password)
    if (!user) {
      this.showToast('手机号或密码错误')
      return
    }
    await this.loginSuccess(user)
  }

  async handleCodeLogin(): Promise<void> {
    if (!this.phoneNumber || !this.verifyCode) {
      this.showToast('请完整填写手机号和验证码')
      return
    }
    const user = await this.userDao.getUserByPhone(this.phoneNumber)
    if (!user) {
      this.showToast('该手机号未注册，请先绑定手机号')
      return
    }
    await this.loginSuccess(user)
  }

  async handleThirdPartyLogin(platform: string): Promise<void> {
    router.pushUrl({
      url: AppConstants.ROUTE_BIND_PHONE,
      params: { platform: platform }
    })
  }

  async handleGuestMode(): Promise<void> {
    const guest: UserProfile = {
      userId: `guest_${Date.now()}`,
      phone: '',
      role: UserRole.JOB_SEEKER,
      isGuest: true
    }
    AppState.currentUser = guest
    AppState.isGuest = true
    AppState.isLoggedIn = false
    router.replaceUrl({ url: AppConstants.ROUTE_JOB_SEEKER_MAIN })
  }

  async loginSuccess(user: UserProfile): Promise<void> {
    await this.userDao.logoutAll()
    AppState.currentUser = user
    AppState.isLoggedIn = true
    AppState.isGuest = false

    if (user.role === UserRole.RECRUITER) {
      router.replaceUrl({ url: AppConstants.ROUTE_RECRUITER_MAIN })
    } else {
      router.replaceUrl({ url: AppConstants.ROUTE_JOB_SEEKER_MAIN })
    }
  }

  showToast(msg: string): void {
    AlertDialog.show({ message: msg })
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
        Text('欢迎回来')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
        Text('登录以使用全部功能')
          .fontSize(14)
          .fontColor(AppConstants.COLOR_TEXT_HINT)
          .margin({ top: 8 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 32, top: 32, bottom: 32 })

      // 登录方式切换
      Row() {
        Column() {
          Text('手机号登录')
            .fontSize(15)
            .fontColor(this.loginType === 0 ? '#4A90D9' : '#666666')
          if (this.loginType === 0) {
            Divider().width(60).height(2).color('#4A90D9').margin({ top: 6 })
          }
        }
        .onClick(() => { this.loginType = 0 })

        Column() {
          Text('微信登录')
            .fontSize(15)
            .fontColor(this.loginType === 1 ? '#4A90D9' : '#666666')
          if (this.loginType === 1) {
            Divider().width(60).height(2).color('#4A90D9').margin({ top: 6 })
          }
        }
        .onClick(() => { this.loginType = 1 })

        Column() {
          Text('QQ登录')
            .fontSize(15)
            .fontColor(this.loginType === 2 ? '#4A90D9' : '#666666')
          if (this.loginType === 2) {
            Divider().width(60).height(2).color('#4A90D9').margin({ top: 6 })
          }
        }
        .onClick(() => { this.loginType = 2 })
      }
      .width('80%')
      .justifyContent(FlexAlign.SpaceAround)
      .margin({ bottom: 24 })

      // 手机号登录表单
      if (this.loginType === 0) {
        Column() {
          // 手机号输入
          Row() {
            Text('+86')
              .fontSize(15)
              .fontColor('#1A1A1A')
              .padding({ right: 8 })
              .border({ width: { right: 1 }, color: '#E5E5E5' })
            TextInput({ placeholder: '请输入手机号' })
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

          // 密码登录
          if (this.loginSubType === 0) {
            TextInput({ placeholder: '请输入密码' })
              .width('80%')
              .height(48)
              .fontSize(15)
              .type(InputType.Password)
              .maxLength(20)
              .onChange((value: string) => { this.password = value })
              .padding({ left: 12, right: 12 })
              .border({ width: 1, color: '#E5E5E5', radius: 8 })
              .margin({ bottom: 4 })

            Text('验证码登录')
              .fontSize(12)
              .fontColor('#4A90D9')
              .alignSelf(ItemAlign.End)
              .margin({ right: '10%', bottom: 16 })
              .onClick(() => { this.loginSubType = 1 })

            Button('登录')
              .width('80%')
              .height(48)
              .fontSize(16)
              .backgroundColor('#4A90D9')
              .borderRadius(24)
              .onClick(() => this.handlePasswordLogin())
          }

          // 验证码登录
          if (this.loginSubType === 1) {
            Row() {
              TextInput({ placeholder: '验证码' })
                .layoutWeight(1)
                .fontSize(15)
                .type(InputType.Number)
                .maxLength(6)
                .onChange((value: string) => { this.verifyCode = value })
                .padding({ left: 12 })
              Button(this.isSendingCode ? `${this.countDown}s` : '获取验证码')
                .fontSize(12)
                .height(32)
                .backgroundColor(this.isSendingCode ? '#E5E5E5' : '#4A90D9')
                .fontColor(this.isSendingCode ? '#999999' : '#FFFFFF')
                .borderRadius(16)
                .enabled(!this.isSendingCode)
                .onClick(() => this.sendVerifyCode())
            }
            .width('80%')
            .height(48)
            .border({ width: 1, color: '#E5E5E5', radius: 8 })
            .padding({ left: 12, right: 12 })
            .margin({ bottom: 4 })

            Text('密码登录')
              .fontSize(12)
              .fontColor('#4A90D9')
              .alignSelf(ItemAlign.End)
              .margin({ right: '10%', bottom: 16 })
              .onClick(() => { this.loginSubType = 0 })

            Button('登录')
              .width('80%')
              .height(48)
              .fontSize(16)
              .backgroundColor('#4A90D9')
              .borderRadius(24)
              .onClick(() => this.handleCodeLogin())
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }

      // 微信登录
      if (this.loginType === 1) {
        Column() {
          Text('使用微信一键登录')
            .fontSize(14)
            .fontColor('#666666')
            .margin({ top: 40, bottom: 24 })
          Button('微信授权登录')
            .width('80%')
            .height(48)
            .fontSize(16)
            .backgroundColor('#07C160')
            .borderRadius(24)
            .onClick(() => this.handleThirdPartyLogin('wechat'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }

      // QQ登录
      if (this.loginType === 2) {
        Column() {
          Text('使用QQ一键登录')
            .fontSize(14)
            .fontColor('#666666')
            .margin({ top: 40, bottom: 24 })
          Button('QQ授权登录')
            .width('80%')
            .height(48)
            .fontSize(16)
            .backgroundColor('#12B7F5')
            .borderRadius(24)
            .onClick(() => this.handleThirdPartyLogin('qq'))
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }

      Blank()

      Text('游客模式浏览（仅限查看）')
        .fontSize(13)
        .fontColor('#4A90D9')
        .onClick(() => this.handleGuestMode())
        .margin({ bottom: 32 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
