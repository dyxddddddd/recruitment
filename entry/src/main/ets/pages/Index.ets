import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../common/constants/AppConstants'
import { RoleCard } from '../common/components/RoleCard'
import { StudentType, UserRole, AuthStatus } from '../model/UserModel'
import { UserDao } from '../service/UserDao'

@Entry
@Component
struct Index {
  @State selectedRole: string = ''
  private userDao: UserDao = new UserDao()

  async aboutToAppear(): Promise<void> {
    AppState.syncFromStorage()

    const loggedInUser = await this.userDao.getLoggedInUser()
    if (loggedInUser) {
      const normalizedLoggedInUser = await this.normalizeStudentType(loggedInUser)
      AppState.currentUser = normalizedLoggedInUser
      AppState.isLoggedIn = true
      AppState.isGuest = false
      AppState.syncToStorage()
      this.navigateByUser(normalizedLoggedInUser.role, !!normalizedLoggedInUser.studentType)
      return
    }

    AppState.currentUser = null
    AppState.isLoggedIn = false
    AppState.isGuest = true
    AppState.syncToStorage()
  }

  async normalizeStudentType(user: import('../model/UserModel').UserProfile): Promise<import('../model/UserModel').UserProfile> {
    if (user.studentType) {
      AppState.rememberStudentType(user.phone, user.studentType)
      return user
    }
    const remembered = AppState.getRememberedStudentType(user.phone)
    if (remembered === StudentType.CURRENT || remembered === StudentType.GRADUATING) {
      await this.userDao.updateStudentType(user.userId, remembered as StudentType)
      const refreshedUser = await this.userDao.getUserById(user.userId)
      if (refreshedUser) {
        return refreshedUser
      }
      user.studentType = remembered as StudentType
    }
    return user
  }

  navigateByUser(role: UserRole, hasStudentType: boolean): void {
    if (role === UserRole.JOB_SEEKER && !hasStudentType) {
      router.replaceUrl({ url: AppConstants.ROUTE_IDENTITY_GUIDE })
      return
    }
    this.navigateToMain(role)
  }

  navigateToMain(role: UserRole): void {
    if (role === UserRole.JOB_SEEKER) {
      router.replaceUrl({ url: AppConstants.ROUTE_JOB_SEEKER_MAIN })
    } else {
      const user = AppState.currentUser
      if (user && user.authStatus === AuthStatus.APPROVED) {
        router.replaceUrl({ url: AppConstants.ROUTE_RECRUITER_MAIN })
      } else {
        router.replaceUrl({ url: AppConstants.ROUTE_RECRUITER_AUTH })
      }
    }
  }

  handleRoleSelect(role: string): void {
    this.selectedRole = role
    if (role === UserRole.JOB_SEEKER) {
      router.pushUrl({ url: AppConstants.ROUTE_LOGIN })
    } else {
      router.pushUrl({
        url: AppConstants.ROUTE_LOGIN,
        params: { role: UserRole.RECRUITER }
      })
    }
  }

  build() {
    Column() {
      Column() {
        Text(AppConstants.APP_NAME)
          .fontSize(32)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .margin({ bottom: 8 })
        Text('打通校园到职场的最后一公里')
          .fontSize(14)
          .fontColor('rgba(255,255,255,0.8)')
      }
      .width('100%')
      .padding({ top: 80, bottom: 40 })
      .backgroundColor(AppConstants.COLOR_PRIMARY)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .borderRadius({ bottomLeft: 32, bottomRight: 32 })

      Column() {
        Text('选择你的身份')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
          .margin({ top: 40, bottom: 32 })

        Column() {
          RoleCard({
            title: '我要找工作',
            description: '在校生/应届生专属，支持微任务、兼职、实习、全职与 AI 求职工具。',
            emoji: '🎓',
            bgColor: '#F0F7FF',
            cardBorderColor: this.selectedRole === UserRole.JOB_SEEKER ? '#4A90D9' : '#D0E0F0'
          })
            .onClick(() => this.handleRoleSelect(UserRole.JOB_SEEKER))
        }
        .width('80%')
        .margin({ bottom: 20 })

        Column() {
          RoleCard({
            title: '我要招人',
            description: '企业 HR 入口，支持职位发布、人才管理和 AI 辅助招聘。',
            emoji: '💼',
            bgColor: '#FFF8F0',
            cardBorderColor: this.selectedRole === UserRole.RECRUITER ? '#FF6B35' : '#F0D8C0'
          })
            .onClick(() => this.handleRoleSelect(UserRole.RECRUITER))
        }
        .width('80%')
      }
      .width('100%')
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Text('已有账号，直接进入')
        .fontSize(13)
        .fontColor('#4A90D9')
        .margin({ bottom: 32 })
        .onClick(() => {
          router.pushUrl({ url: AppConstants.ROUTE_LOGIN })
        })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
