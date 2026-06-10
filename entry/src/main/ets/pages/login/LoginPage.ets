import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { StudentType, UserProfile, UserRole } from '../../model/UserModel'
import { EmailAuthService } from '../../service/EmailAuthService'
import { SmsService } from '../../service/SmsService'
import { ThirdPartyAuthService } from '../../service/ThirdPartyAuthService'
import { UserDao } from '../../service/UserDao'

@Entry
@Component
struct LoginPage {
  @State phoneNumber: string = ''
  @State phonePassword: string = ''
  @State phoneVerifyCode: string = ''
  @State emailAddress: string = ''
  @State emailPassword: string = ''
  @State emailVerifyCode: string = ''
  @State isSendingPhoneCode: boolean = false
  @State isSendingEmailCode: boolean = false
  @State phoneCountDown: number = 0
  @State emailCountDown: number = 0
  @State loginType: number = 0
  @State phoneLoginSubType: number = 0
  @State emailLoginSubType: number = 0
  @State entryRole: UserRole = UserRole.JOB_SEEKER

  private userDao: UserDao = new UserDao()
  private smsService: SmsService = new SmsService()
  private emailAuthService: EmailAuthService = new EmailAuthService()
  private thirdPartyAuthService: ThirdPartyAuthService = new ThirdPartyAuthService()

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>
    if (params && params['role'] === UserRole.RECRUITER) {
      this.entryRole = UserRole.RECRUITER
    }
  }

  async sendPhoneVerifyCode(): Promise<void> {
    if (this.phoneNumber.trim().length !== 11) {
      this.showToast('请输入正确的手机号')
      return
    }
    this.isSendingPhoneCode = true
    this.phoneCountDown = 60
    const timer = setInterval(() => {
      this.phoneCountDown--
      if (this.phoneCountDown <= 0) {
        clearInterval(timer)
        this.isSendingPhoneCode = false
      }
    }, 1000)
    const result = await this.smsService.sendVerifyCode(this.phoneNumber.trim())
    if (!result.success) {
      clearInterval(timer)
      this.phoneCountDown = 0
      this.isSendingPhoneCode = false
    }
    this.showToast(result.message)
  }

  async sendEmailVerifyCode(): Promise<void> {
    const normalizedEmail = this.emailAddress.trim().toLowerCase()
    if (!this.emailAuthService.isValidEmail(normalizedEmail)) {
      this.showToast('请输入正确的邮箱地址')
      return
    }
    this.isSendingEmailCode = true
    this.emailCountDown = 60
    const timer = setInterval(() => {
      this.emailCountDown--
      if (this.emailCountDown <= 0) {
        clearInterval(timer)
        this.isSendingEmailCode = false
      }
    }, 1000)
    const result = await this.emailAuthService.sendVerifyCode(normalizedEmail)
    if (!result.success) {
      clearInterval(timer)
      this.emailCountDown = 0
      this.isSendingEmailCode = false
    }
    this.showToast(result.message)
  }

  async handlePhonePasswordLogin(): Promise<void> {
    const normalizedPhone = this.phoneNumber.trim()
    const normalizedPassword = this.phonePassword.trim()
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

  async handlePhoneCodeLogin(): Promise<void> {
    const normalizedPhone = this.phoneNumber.trim()
    const normalizedCode = this.phoneVerifyCode.trim()
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
    const needsPasswordSetup = !user.password || user.password.trim().length === 0
    await this.loginSuccess(user, needsPasswordSetup)
  }

  async handleEmailPasswordLogin(): Promise<void> {
    const normalizedEmail = this.emailAddress.trim().toLowerCase()
    const normalizedPassword = this.emailPassword.trim()
    if (!normalizedEmail || !normalizedPassword) {
      this.showToast('请先输入邮箱和密码')
      return
    }
    if (!this.emailAuthService.isValidEmail(normalizedEmail)) {
      this.showToast('请输入正确的邮箱地址')
      return
    }
    const user = await this.userDao.getUserByEmailAndPassword(normalizedEmail, normalizedPassword)
    if (!user) {
      this.showToast('邮箱或密码错误')
      return
    }
    if (this.entryRole === UserRole.RECRUITER && user.role !== UserRole.RECRUITER) {
      this.showToast('当前入口为招聘者登录，请使用 HR 账号')
      return
    }
    await this.loginSuccess(user)
  }

  async handleEmailCodeLogin(): Promise<void> {
    const normalizedEmail = this.emailAddress.trim().toLowerCase()
    const normalizedCode = this.emailVerifyCode.trim()
    if (!normalizedEmail || !normalizedCode) {
      this.showToast('请完整填写邮箱和验证码')
      return
    }
    if (!this.emailAuthService.isValidEmail(normalizedEmail)) {
      this.showToast('请输入正确的邮箱地址')
      return
    }
    const result = await this.emailAuthService.verifyCode(normalizedEmail, normalizedCode)
    if (!result.success) {
      this.showToast(result.message)
      return
    }
    let user = await this.userDao.getUserByEmail(normalizedEmail)
    if (!user) {
      user = await this.autoRegisterByEmail(normalizedEmail)
    }
    if (this.entryRole === UserRole.RECRUITER && user.role !== UserRole.RECRUITER) {
      this.showToast('当前入口为招聘者登录，请使用 HR 账号')
      return
    }
    const needsPasswordSetup = !user.password || user.password.trim().length === 0
    await this.loginSuccess(user, needsPasswordSetup)
  }

  async autoRegisterByPhone(phone: string): Promise<UserProfile> {
    const newUser: UserProfile = {
      userId: `${this.entryRole}_${phone}`,
      phone: phone,
      email: '',
      role: this.entryRole,
      isGuest: false,
      password: ''
    }
    await this.userDao.insertUser(newUser)
    const insertedUser = await this.userDao.getUserById(newUser.userId)
    return insertedUser || newUser
  }

  async autoRegisterByEmail(email: string): Promise<UserProfile> {
    const safeEmail = email.replace(/[^a-zA-Z0-9]/g, '_')
    const newUser: UserProfile = {
      userId: `${this.entryRole}_${safeEmail}`,
      phone: '',
      email: email,
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
      email: '',
      role: UserRole.JOB_SEEKER,
      isGuest: true
    }
    AppState.currentUser = guest
    AppState.isGuest = true
    AppState.isLoggedIn = false
    AppState.syncToStorage()
    router.replaceUrl({ url: AppConstants.ROUTE_JOB_SEEKER_MAIN })
  }

  async loginSuccess(user: UserProfile, forceSetPassword: boolean = false): Promise<void> {
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
    if (forceSetPassword) {
      router.replaceUrl({ url: AppConstants.ROUTE_SET_PASSWORD })
      return
    }
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

  @Builder
  LoginModeTabs() {
    Row() {
      this.ModeTab('手机号登录', this.loginType === 0, () => {
        this.loginType = 0
      })
      this.ModeTab('邮箱登录', this.loginType === 1, () => {
        this.loginType = 1
      })
    }
    .width('80%')
    .justifyContent(FlexAlign.SpaceAround)
    .margin({ bottom: 24 })
  }

  @Builder
  ModeTab(label: string, active: boolean, onTap: () => void) {
    Column() {
      Text(label)
        .fontSize(15)
        .fontColor(active ? AppConstants.COLOR_PRIMARY : '#666666')
      if (active) {
        Divider()
          .width(64)
          .height(2)
          .color(AppConstants.COLOR_PRIMARY)
          .margin({ top: 6 })
      }
    }
    .onClick(() => onTap())
  }

  @Builder
  PhoneLoginPanel() {
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

      if (this.phoneLoginSubType === 0) {
        TextInput({ placeholder: '请输入密码', text: this.phonePassword })
          .width('80%')
          .height(48)
          .fontSize(15)
          .type(InputType.Password)
          .maxLength(20)
          .onChange((value: string) => { this.phonePassword = value })
          .padding({ left: 12, right: 12 })
          .border({ width: 1, color: '#E5E5E5', radius: 8 })
          .margin({ bottom: 4 })

        Text('验证码登录')
          .fontSize(12)
          .fontColor(AppConstants.COLOR_PRIMARY)
          .alignSelf(ItemAlign.End)
          .margin({ right: '10%', bottom: 16 })
          .onClick(() => { this.phoneLoginSubType = 1 })

        Button('登录')
          .width('80%')
          .height(48)
          .fontSize(16)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .borderRadius(24)
          .onClick(() => this.handlePhonePasswordLogin())
      } else {
        Row() {
          TextInput({ placeholder: '验证码', text: this.phoneVerifyCode })
            .layoutWeight(1)
            .fontSize(15)
            .type(InputType.Number)
            .maxLength(6)
            .onChange((value: string) => { this.phoneVerifyCode = value })
            .padding({ left: 12 })
          Button(this.isSendingPhoneCode ? `${this.phoneCountDown}s` : '获取验证码')
            .fontSize(12)
            .height(32)
            .backgroundColor(this.isSendingPhoneCode ? '#E5E5E5' : AppConstants.COLOR_PRIMARY)
            .fontColor(this.isSendingPhoneCode ? '#999999' : '#FFFFFF')
            .borderRadius(16)
            .enabled(!this.isSendingPhoneCode)
            .onClick(() => this.sendPhoneVerifyCode())
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
          .onClick(() => { this.phoneLoginSubType = 0 })

        Button('登录')
          .width('80%')
          .height(48)
          .fontSize(16)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .borderRadius(24)
          .onClick(() => this.handlePhoneCodeLogin())
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  EmailLoginPanel() {
    Column() {
      TextInput({ placeholder: '请输入邮箱地址', text: this.emailAddress })
        .width('80%')
        .height(48)
        .fontSize(15)
        .type(InputType.Normal)
        .onChange((value: string) => { this.emailAddress = value })
        .padding({ left: 12, right: 12 })
        .border({ width: 1, color: '#E5E5E5', radius: 8 })
        .margin({ bottom: 16 })

      if (this.emailLoginSubType === 0) {
        TextInput({ placeholder: '请输入密码', text: this.emailPassword })
          .width('80%')
          .height(48)
          .fontSize(15)
          .type(InputType.Password)
          .maxLength(20)
          .onChange((value: string) => { this.emailPassword = value })
          .padding({ left: 12, right: 12 })
          .border({ width: 1, color: '#E5E5E5', radius: 8 })
          .margin({ bottom: 4 })

        Text('邮箱验证码登录')
          .fontSize(12)
          .fontColor(AppConstants.COLOR_PRIMARY)
          .alignSelf(ItemAlign.End)
          .margin({ right: '10%', bottom: 16 })
          .onClick(() => { this.emailLoginSubType = 1 })

        Button('登录')
          .width('80%')
          .height(48)
          .fontSize(16)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .borderRadius(24)
          .onClick(() => this.handleEmailPasswordLogin())
      } else {
        Row() {
          TextInput({ placeholder: '验证码', text: this.emailVerifyCode })
            .layoutWeight(1)
            .fontSize(15)
            .type(InputType.Number)
            .maxLength(6)
            .onChange((value: string) => { this.emailVerifyCode = value })
            .padding({ left: 12 })
          Button(this.isSendingEmailCode ? `${this.emailCountDown}s` : '获取验证码')
            .fontSize(12)
            .height(32)
            .backgroundColor(this.isSendingEmailCode ? '#E5E5E5' : AppConstants.COLOR_PRIMARY)
            .fontColor(this.isSendingEmailCode ? '#999999' : '#FFFFFF')
            .borderRadius(16)
            .enabled(!this.isSendingEmailCode)
            .onClick(() => this.sendEmailVerifyCode())
        }
        .width('80%')
        .height(48)
        .border({ width: 1, color: '#E5E5E5', radius: 8 })
        .padding({ left: 12, right: 12 })
        .margin({ bottom: 4 })

        Text('邮箱密码登录')
          .fontSize(12)
          .fontColor(AppConstants.COLOR_PRIMARY)
          .alignSelf(ItemAlign.End)
          .margin({ right: '10%', bottom: 16 })
          .onClick(() => { this.emailLoginSubType = 0 })

        Button('登录')
          .width('80%')
          .height(48)
          .fontSize(16)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .borderRadius(24)
          .onClick(() => this.handleEmailCodeLogin())
      }

      Text('邮箱验证码当前为前端开发模式，验证码会直接弹窗显示。')
        .fontSize(12)
        .fontColor(AppConstants.COLOR_TEXT_HINT)
        .width('80%')
        .margin({ top: 14 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  ThirdPartyLoginSection() {
    Column() {
      Text('第三方快捷登录')
        .fontSize(13)
        .fontColor(AppConstants.COLOR_TEXT_HINT)
        .margin({ bottom: 14 })

      Row() {
        Button('微信登录')
          .width(138)
          .height(44)
          .fontSize(15)
          .backgroundColor('#07C160')
          .borderRadius(22)
          .onClick(() => this.handleThirdPartyLogin('wechat'))

        Button('QQ 登录')
          .width(138)
          .height(44)
          .fontSize(15)
          .backgroundColor('#12B7F5')
          .borderRadius(22)
          .onClick(() => this.handleThirdPartyLogin('qq'))
      }
      .width('80%')
      .justifyContent(FlexAlign.SpaceBetween)

      Text(AppConstants.THIRD_PARTY_AUTH_MOCK_ENABLED
        ? '当前为 mock 模式，模拟器中会直接走授权成功后的绑定手机号流程。'
        : '已接入真实 SDK，真机安装微信或 QQ 后可测试真实授权。')
        .fontSize(12)
        .fontColor(AppConstants.COLOR_TEXT_HINT)
        .width('80%')
        .margin({ top: 12 })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .margin({ top: 20, bottom: 20 })
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

      this.LoginModeTabs()

      if (this.loginType === 0) {
        this.PhoneLoginPanel()
      } else {
        this.EmailLoginPanel()
      }

      if (this.entryRole === UserRole.JOB_SEEKER) {
        this.ThirdPartyLoginSection()
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
