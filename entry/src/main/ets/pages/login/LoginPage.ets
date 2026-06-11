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
  @State phonePassword: string = ''
  @State phoneVerifyCode: string = ''
  @State isSendingPhoneCode: boolean = false
  @State phoneCountDown: number = 0
  @State phoneLoginSubType: number = 0
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

  async handlePhonePasswordLogin(): Promise<void> {
    const normalizedPhone = this.phoneNumber.trim()
    const normalizedPassword = this.phonePassword.trim()
    if (!normalizedPhone || !normalizedPassword) {
      this.showToast('请先输入手机号和密码')
      return
    }

    await this.userDao.ensureDemoAccounts()

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

  async handleThirdPartyLogin(platform: string): Promise<void> {
    if (AppConstants.THIRD_PARTY_AUTH_MOCK_ENABLED) {
      router.pushUrl({
        url: AppConstants.ROUTE_MOCK_SOCIAL_AUTH,
        params: {
          platform: platform
        }
      })
      return
    }
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

  private getPageTitle(): string {
    return this.entryRole === UserRole.RECRUITER ? '招聘者登录' : '欢迎回来'
  }

  private getPageSubtitle(): string {
    return this.entryRole === UserRole.RECRUITER
      ? '登录后可发布职位、查看投递和管理候选人'
      : '手机号、微信或 QQ 均可登录，首次验证码登录会自动注册'
  }

  private getPrimaryActionText(): string {
    return this.phoneLoginSubType === 0 ? '手机号密码登录' : '手机号验证码登录'
  }

  @Builder
  LoginTypeSwitcher() {
    Row() {
      this.LoginTypeChip('密码登录', this.phoneLoginSubType === 0, () => {
        this.phoneLoginSubType = 0
      })
      this.LoginTypeChip('验证码登录', this.phoneLoginSubType === 1, () => {
        this.phoneLoginSubType = 1
      })
    }
    .width('100%')
    .padding({ left: 6, right: 6, top: 6, bottom: 6 })
    .backgroundColor('#F4F7FB')
    .borderRadius(20)
  }

  @Builder
  LoginTypeChip(label: string, active: boolean, onTap: () => void) {
    Text(label)
      .layoutWeight(1)
      .height(42)
      .textAlign(TextAlign.Center)
      .fontSize(15)
      .fontWeight(active ? FontWeight.Medium : FontWeight.Regular)
      .fontColor(active ? '#1A1A1A' : '#6B7280')
      .backgroundColor(active ? '#FFFFFF' : 'transparent')
      .borderRadius(16)
      .onClick(() => onTap())
  }

  @Builder
  InputCard() {
    Column({ space: 14 }) {
      Column({ space: 8 }) {
        Text('手机号')
          .fontSize(13)
          .fontColor('#6B7280')
          .alignSelf(ItemAlign.Start)

        Row() {
          Text('+86')
            .fontSize(16)
            .fontColor('#111827')
            .padding({ right: 12 })
            .margin({ right: 12 })
            .border({ width: { right: 1 }, color: '#E5E7EB' })

          TextInput({ placeholder: '请输入手机号', text: this.phoneNumber })
            .layoutWeight(1)
            .fontSize(16)
            .type(InputType.Number)
            .maxLength(11)
            .backgroundColor('transparent')
            .onChange((value: string) => {
              this.phoneNumber = value
            })
        }
        .width('100%')
        .height(54)
        .padding({ left: 16, right: 16 })
        .backgroundColor('#F8FAFC')
        .borderRadius(16)
      }

      if (this.phoneLoginSubType === 0) {
        Column({ space: 8 }) {
          Text('登录密码')
            .fontSize(13)
            .fontColor('#6B7280')
            .alignSelf(ItemAlign.Start)

          TextInput({ placeholder: '请输入登录密码', text: this.phonePassword })
            .width('100%')
            .height(54)
            .fontSize(16)
            .type(InputType.Password)
            .maxLength(20)
            .padding({ left: 16, right: 16 })
            .backgroundColor('#F8FAFC')
            .borderRadius(16)
            .onChange((value: string) => {
              this.phonePassword = value
            })
        }
      } else {
        Column({ space: 8 }) {
          Text('短信验证码')
            .fontSize(13)
            .fontColor('#6B7280')
            .alignSelf(ItemAlign.Start)

          Row() {
            TextInput({ placeholder: '请输入验证码', text: this.phoneVerifyCode })
              .layoutWeight(1)
              .fontSize(16)
              .type(InputType.Number)
              .maxLength(6)
              .backgroundColor('transparent')
              .onChange((value: string) => {
                this.phoneVerifyCode = value
              })

            Button(this.isSendingPhoneCode ? `${this.phoneCountDown}s` : '获取验证码')
              .height(36)
              .fontSize(13)
              .fontColor('#FFFFFF')
              .backgroundColor(this.isSendingPhoneCode ? '#A7C6EA' : AppConstants.COLOR_PRIMARY)
              .borderRadius(18)
              .enabled(!this.isSendingPhoneCode)
              .onClick(() => this.sendPhoneVerifyCode())
          }
          .width('100%')
          .height(54)
          .padding({ left: 16, right: 10 })
          .backgroundColor('#F8FAFC')
          .borderRadius(16)
        }
      }

      Text(this.phoneLoginSubType === 0
        ? '若忘记密码，可切换到验证码登录'
        : '首次验证码登录会自动注册；若账号未设置密码，登录后会引导设置')
        .fontSize(12)
        .fontColor('#94A3B8')
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  ThirdPartyLoginSection() {
    Column({ space: 14 }) {
      Row() {
        Divider()
          .strokeWidth(1)
          .color('#E5E7EB')
          .layoutWeight(1)
        Text('其他登录方式')
          .fontSize(12)
          .fontColor('#94A3B8')
          .margin({ left: 12, right: 12 })
        Divider()
          .strokeWidth(1)
          .color('#E5E7EB')
          .layoutWeight(1)
      }
      .width('100%')

      Row({ space: 14 }) {
        this.ThirdPartyButton('微信', '#07C160', '#EAFBF1', 'wechat')
        this.ThirdPartyButton('QQ', '#12B7F5', '#EAF7FF', 'qq')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)

      Text(AppConstants.THIRD_PARTY_AUTH_MOCK_ENABLED
        ? '当前为演示授权流程，完成授权确认后仍会继续绑定手机号。'
        : '已接入正式 SDK，真机安装微信或 QQ 后可发起真实授权。')
        .fontSize(12)
        .fontColor('#94A3B8')
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  ThirdPartyButton(label: string, color: string, bgColor: string, platform: string) {
    Row({ space: 10 }) {
      Text(label.substring(0, 1))
        .width(28)
        .height(28)
        .textAlign(TextAlign.Center)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor(color)
        .borderRadius(14)
        .padding({ top: 5 })

      Text(`${label}登录`)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1F2937')
    }
    .width('48%')
    .height(54)
    .padding({ left: 16, right: 16 })
    .backgroundColor(bgColor)
    .borderRadius(18)
    .onClick(() => this.handleThirdPartyLogin(platform))
  }

  build() {
    Column() {
      Row() {
        Button() {
          Image($r('sys.symbol.chevron_left'))
            .width(22)
            .height(22)
            .fillColor('#1A1A1A')
        }
        .width(40)
        .height(40)
        .backgroundColor('#FFFFFF')
        .borderRadius(20)
        .onClick(() => router.back())

        Blank()
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 20, bottom: 8 })
      .margin({ top: 20 })

      Scroll() {
        Column({ space: 22 }) {
          Column({ space: 10 }) {
            Text(this.getPageTitle())
              .fontSize(30)
              .fontWeight(FontWeight.Bold)
              .fontColor('#111827')
              .width('100%')
              .textAlign(TextAlign.Start)

            Text(this.getPageSubtitle())
              .fontSize(14)
              .fontColor('#6B7280')
              .width('100%')
              .textAlign(TextAlign.Start)
              .lineHeight(22)
          }
          .width('100%')

          Column({ space: 18 }) {
            this.LoginTypeSwitcher()
            this.InputCard()

            Button(this.getPrimaryActionText())
              .width('100%')
              .height(52)
              .fontSize(17)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(AppConstants.COLOR_PRIMARY)
              .borderRadius(26)
              .onClick(() => {
                if (this.phoneLoginSubType === 0) {
                  void this.handlePhonePasswordLogin()
                } else {
                  void this.handlePhoneCodeLogin()
                }
              })

            if (this.entryRole === UserRole.JOB_SEEKER) {
              this.ThirdPartyLoginSection()
            }
          }
          .width('100%')
          .padding(22)
          .backgroundColor('#FFFFFF')
          .borderRadius(28)
          .shadow({ radius: 20, color: '#120F172A', offsetX: 0, offsetY: 10 })

          if (this.entryRole === UserRole.JOB_SEEKER) {
            Text('游客模式仅可浏览公开内容')
              .fontSize(13)
              .fontColor(AppConstants.COLOR_PRIMARY)
              .onClick(() => this.handleGuestMode())
          }
        }
        .width('100%')
        .padding({ left: 20, right: 20, top: 12, bottom: 32 })
      }
      .scrollBar(BarState.Off)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F7FB')
  }
}
