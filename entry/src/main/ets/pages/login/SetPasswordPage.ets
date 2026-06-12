import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { UserRole } from '../../model/UserModel'
import { UserDao } from '../../service/UserDao'

@Entry
@Component
struct SetPasswordPage {
  @State password: string = ''
  @State confirmPassword: string = ''
  @State isSaving: boolean = false

  private userDao: UserDao = new UserDao()

  private async completePasswordSetup(): Promise<void> {
    const currentUser = AppState.currentUser
    if (!currentUser) {
      this.showToast('当前登录信息已失效，请重新登录')
      router.replaceUrl({ url: AppConstants.ROUTE_LOGIN })
      return
    }

    const normalizedPassword = this.password.trim()
    const normalizedConfirm = this.confirmPassword.trim()
    if (normalizedPassword.length < 6) {
      this.showToast('请设置至少 6 位密码')
      return
    }
    if (normalizedPassword !== normalizedConfirm) {
      this.showToast('两次输入的密码不一致')
      return
    }

    this.isSaving = true
    await this.userDao.updatePassword(currentUser.userId, normalizedPassword)
    currentUser.password = normalizedPassword
    AppState.currentUser = currentUser
    AppState.syncToStorage()
    this.isSaving = false
    this.routeAfterPasswordSet()
  }

  private routeAfterPasswordSet(): void {
    const currentUser = AppState.currentUser
    if (!currentUser) {
      router.replaceUrl({ url: AppConstants.ROUTE_LOGIN })
      return
    }
    if (currentUser.role === UserRole.RECRUITER) {
      router.replaceUrl({ url: AppConstants.ROUTE_RECRUITER_MAIN })
      return
    }
    if (!currentUser.studentType) {
      router.replaceUrl({ url: AppConstants.ROUTE_IDENTITY_GUIDE })
      return
    }
    router.replaceUrl({ url: AppConstants.ROUTE_JOB_SEEKER_MAIN })
  }

  private showToast(message: string): void {
    AlertDialog.show({ message: message })
  }

  build() {
    Column() {
      Row() {
        Text('设置登录密码')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ left: 24, right: 24, top: 64 })

      Text('首次使用验证码登录后，需要先设置一个密码，后续可直接用密码登录。')
        .fontSize(14)
        .fontColor('#666666')
        .width('100%')
        .padding({ left: 24, right: 24, top: 12, bottom: 28 })

      Column() {
        TextInput({ placeholder: '设置密码（至少 6 位）', text: this.password })
          .width('100%')
          .height(52)
          .fontSize(16)
          .type(InputType.Password)
          .maxLength(20)
          .onChange((value: string) => { this.password = value })
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: '#E5E5E5', radius: 12 })

        TextInput({ placeholder: '再次输入密码', text: this.confirmPassword })
          .width('100%')
          .height(52)
          .fontSize(16)
          .type(InputType.Password)
          .maxLength(20)
          .onChange((value: string) => { this.confirmPassword = value })
          .padding({ left: 16, right: 16 })
          .border({ width: 1, color: '#E5E5E5', radius: 12 })
          .margin({ top: 16 })

        Button(this.isSaving ? '保存中...' : '保存密码')
          .width('100%')
          .height(50)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .backgroundColor('#4A90D9')
          .enabled(!this.isSaving)
          .borderRadius(25)
          .margin({ top: 24 })
          .onClick(() => {
            this.completePasswordSetup()
          })
      }
      .width('100%')
      .padding({ left: 24, right: 24 })

      Blank()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
