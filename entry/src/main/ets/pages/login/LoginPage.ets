import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { StudentType, UserProfile, UserRole } from '../../model/UserModel'
import { SmsService } from '../../service/SmsService'
import { ThirdPartyAuthService } from '../../service/ThirdPartyAuthService'
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
  @State entryRole: UserRole = UserRole.JOB_SEEKER

  private userDao: UserDao = new UserDao()
  private smsService: SmsService = new SmsService()
  private thirdPartyAuthService: ThirdPartyAuthService = new ThirdPartyAuthService()

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>
    if (params && params['role'] === UserRole.RECRUITER) {
      this.entryRole = UserRole.RECRUITER
    }
  }

  async sendVerifyCode(): Promise<void> {
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
    const result = await this.smsService.sendVerifyCode(this.phoneNumber)
    if (!result.success) {
      clearInterval(timer)
      this.countDown = 0
      this.isSendingCode = false
      this.showToast(result.message)
    }
  }

  async handlePasswordLogin(): Promise<void> {
    if (!this.phoneNumber || !this.password) {
      this.showToast('请输入手机号和密码')
      return
    }
    const normalizedPhone = this.phoneNumber.trim()
    const normalizedPassword = this.password.trim()
    if (!normalizedPhone || !normalizedPassword) {
      this.showToast('请先输入手机号和密码')
      return
    }
    const user = await this.userDao.getUserByPhoneAndPassword(normalizedPhone, normalizedPassword)
    if (!user) {
      this.showToast('手机号或密码错误')
      return
    }
    if (this.entryRole === UserRole.RECRUITER && user.role !== UserRole.RECRUITER) {
      this.showToast('当前入口为招聘者登录，请使用 HR 账号')
      return
    }
    await this.loginSuccess(user)
  }

  async handleCodeLogin(): Promise<void> {
    if (!this.phoneNumber || !this.verifyCode) {
      this.showToast('请完整填写手机号和验证码')
      return
    }
    const normalizedPhone = this.phoneNumber.trim()
    const normalizedCode = this.verifyCode.trim()
    if (!normalizedPhone || !normalizedCode) {
      this.showToast('请完整填写手机号和验证码')
      return
    }
    const result = await this.smsService.verifyCode(normalizedPhone, normalizedCode)
    if (!result.success) {
      this.showToast(result.message)
      return
    }
    let user = await this.userDao.getUserByPhone(normalizedPhone)
    if (!user) {
      user = await this.autoRegisterByPhone(normalizedPhone)
    }
    if (this.entryRole === UserRole.RECRUITER && user.role !== UserRole.RECRUITER) {
      this.showToast('当前入口为招聘者登录，请使用 HR 账号')
      return
    }
    await this.loginSuccess(user)
  }

  async autoRegisterByPhone(phone: string): Promise<UserProfile> {
    const newUser: UserProfile = {
      userId: `${this.entryRole}_${phone}`,
      phone: phone,
      role: this.entryRole,
      isGuest: false,
      password: ''
    }
    await this.userDao.insertUser(newUser)
    const insertedUser = await this.userDao.getUserById(newUser.userId)
    return insertedUser || newUser
  }

  async handleThirdPartyLogin(platform: string): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext
      const authResult = await this.thirdPartyAuthService.authorize(platform, context)
      if (!authResult.success) {
        this.showToast('第三方授权失败，请稍后重试')
        return
      }
      router.pushUrl({
        url: AppConstants.ROUTE_BIND_PHONE,
        params: {
          platform: authResult.platform,
          openId: authResult.openId,
          nickname: authResult.nickname,
          avatar: authResult.avatar,
          authCode: authResult.authCode
        }
      })
    } catch (e) {
      this.showToast(e instanceof Error ? e.message : '第三方登录失败')
    }
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
    AppState.syncToStorage()
    router.replaceUrl({ url: AppConstants.ROUTE_JOB_SEEKER_MAIN })
  }

  async loginSuccess(user: UserProfile): Promise<void> {
    await this.userDao.logoutAll()
    await this.userDao.markUserLoggedIn(user.userId)
    let nextUser = await this.userDao.getUserById(user.userId)
    if (!nextUser) {
      nextUser = user
    }
    if (!nextUser.studentType) {
      const remembered = AppState.getRememberedStudentType(nextUser.phone || '')
      if (remembered === StudentType.CURRENT || remembered === StudentType.GRADUATING) {
        await this.userDao.updateStudentType(nextUser.userId, remembered as StudentType)
        const repairedUser = await this.userDao.getUserById(nextUser.userId)
        if (repairedUser) {
          nextUser = repairedUser
        } else {
          nextUser.studentType = remembered as StudentType
        }
      }
    }
    if (nextUser.studentType) {
      AppState.rememberStudentType(nextUser.phone || '', nextUser.studentType)
    }
    AppState.currentUser = nextUser
    AppState.isLoggedIn = true
    AppState.isGuest = false
    AppState.syncToStorage()
    if (nextUser.role === UserRole.RECRUITER) {
      router.replaceUrl({ url: AppConstants.ROUTE_RECRUITER_MAIN })
    } else if (!nextUser.studentType) {
      router.replaceUrl({ url: AppConstants.ROUTE_IDENTITY_GUIDE })
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
        Text(this.entryRole === UserRole.RECRUITER ? 'HR 登录' : '欢迎回来')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
        Text(this.entryRole === UserRole.RECRUITER ? '登录后即可发布职位与管理人才' : '登录以使用全部功能')
          .fontSize(14)
          .fontColor(AppConstants.COLOR_TEXT_HINT)
          .margin({ top: 8 })
      }
      .width('100%')
      .alignItems(HorizontalAlign.Start)
      .padding({ left: 32, top: 32, bottom: 32 })

      Row() {
        Column() {
          Text('手机号登录')
            .fontSize(15)
            .fontColor(this.loginType === 0 ? AppConstants.COLOR_PRIMARY : '#666666')
          if (this.loginType === 0) {
            Divider().width(60).height(2).color(AppConstants.COLOR_PRIMARY).margin({ top: 6 })
          }
        }
        .onClick(() => { this.loginType = 0 })

        Column() {
          Text('微信登录')
            .fontSize(15)
            .fontColor(this.loginType === 1 ? AppConstants.COLOR_PRIMARY : '#666666')
          if (this.loginType === 1) {
            Divider().width(60).height(2).color(AppConstants.COLOR_PRIMARY).margin({ top: 6 })
          }
        }
        .onClick(() => { this.loginType = 1 })

        Column() {
          Text('QQ 登录')
            .fontSize(15)
            .fontColor(this.loginType === 2 ? AppConstants.COLOR_PRIMARY : '#666666')
          if (this.loginType === 2) {
            Divider().width(60).height(2).color(AppConstants.COLOR_PRIMARY).margin({ top: 6 })
          }
        }
        .onClick(() => { this.loginType = 2 })
      }
      .width('80%')
      .justifyContent(FlexAlign.SpaceAround)
      .margin({ bottom: 24 })

      if (this.loginType === 0) {
        Column() {
          Row() {
            Text('+86')
              .fontSize(15)
              .fontColor('#1A1A1A')
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

          if (this.loginSubType === 0) {
            TextInput({ placeholder: '请输入密码', text: this.password })
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
              .fontColor(AppConstants.COLOR_PRIMARY)
              .alignSelf(ItemAlign.End)
              .margin({ right: '10%', bottom: 16 })
              .onClick(() => { this.loginSubType = 1 })

            Button('登录')
              .width('80%')
              .height(48)
              .fontSize(16)
              .backgroundColor(AppConstants.COLOR_PRIMARY)
              .borderRadius(24)
              .onClick(() => this.handlePasswordLogin())
          }

          if (this.loginSubType === 1) {
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
            .margin({ bottom: 4 })

            Text('密码登录')
              .fontSize(12)
              .fontColor(AppConstants.COLOR_PRIMARY)
              .alignSelf(ItemAlign.End)
              .margin({ right: '10%', bottom: 16 })
              .onClick(() => { this.loginSubType = 0 })

            Button('登录')
              .width('80%')
              .height(48)
              .fontSize(16)
              .backgroundColor(AppConstants.COLOR_PRIMARY)
              .borderRadius(24)
              .onClick(() => this.handleCodeLogin())
          }
        }
        .width('100%')
        .alignItems(HorizontalAlign.Center)
      }

      if (this.loginType === 1) {
        Column() {
          Text('使用微信授权后仍需绑定真实手机号')
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

      if (this.loginType === 2) {
        Column() {
          Text('使用 QQ 授权后仍需绑定真实手机号')
            .fontSize(14)
            .fontColor('#666666')
            .margin({ top: 40, bottom: 24 })
          Button('QQ 授权登录')
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

      if (this.entryRole === UserRole.JOB_SEEKER) {
        Text('游客模式浏览（仅限查看）')
          .fontSize(13)
          .fontColor(AppConstants.COLOR_PRIMARY)
          .onClick(() => this.handleGuestMode())
          .margin({ bottom: 32 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
