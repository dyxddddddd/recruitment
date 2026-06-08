import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { StudentType } from '../../model/UserModel'
import { UserDao } from '../../service/UserDao'

@Entry
@Component
struct IdentityGuidePage {
  @State selectedType: StudentType | null = null
  @State isConfirming: boolean = false
  private userDao: UserDao = new UserDao()

  aboutToAppear(): void {
    if (AppState.currentUser?.studentType) {
      router.replaceUrl({ url: AppConstants.ROUTE_JOB_SEEKER_MAIN })
    }
  }

  async handleConfirm(): Promise<void> {
    if (!this.selectedType || !AppState.currentUser) {
      return
    }
    this.isConfirming = true
    AppState.currentUser.studentType = this.selectedType
    await this.userDao.updateStudentType(AppState.currentUser.userId, this.selectedType)
    await this.userDao.updateStudentTypeByPhone(AppState.currentUser.phone || '', this.selectedType)
    await this.userDao.markUserLoggedIn(AppState.currentUser.userId)
    const refreshedUser = await this.userDao.getUserById(AppState.currentUser.userId)
    if (refreshedUser) {
      AppState.currentUser = refreshedUser
    }
    AppState.isLoggedIn = true
    AppState.isGuest = false
    AppState.rememberStudentType(AppState.currentUser?.phone || '', this.selectedType)
    AppState.syncToStorage()
    router.replaceUrl({ url: AppConstants.ROUTE_JOB_SEEKER_MAIN })
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Button() {
            Image($r('sys.symbol.chevron_left'))
              .width(22)
              .height(22)
              .fillColor('#FFFFFF')
          }
          .backgroundColor('transparent')
          .onClick(() => router.back())

          Blank()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 28, bottom: 4 })

        Column() {
          Text('欢迎加入校招护航')
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .margin({ bottom: 8 })

          Text('请选择你的身份类型，我们会为你定制更合适的求职服务')
            .fontSize(14)
            .fontColor('rgba(255,255,255,0.85)')
            .textAlign(TextAlign.Center)
            .width('80%')
        }
        .width('100%')
        .padding({ top: 56, bottom: 40 })

        Column() {
          Column() {
            Column() {
              Text('📎')
                .fontSize(48)
                .margin({ bottom: 12 })

              Text('在校大学生')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1A1A1A')

              Text('短期兼职、远程微任务、编程/设计/文案等灵活机会')
                .fontSize(12)
                .fontColor('#666666')
                .margin({ top: 6 })
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .padding(24)
            .backgroundColor(this.selectedType === StudentType.CURRENT ? '#E8F4FD' : '#FFFFFF')
            .border({
              width: this.selectedType === StudentType.CURRENT ? 2 : 1,
              color: this.selectedType === StudentType.CURRENT ? AppConstants.COLOR_PRIMARY : '#E5E5E5',
              radius: 16
            })
            .onClick(() => {
              this.selectedType = StudentType.CURRENT
            })
          }
          .width('100%')
          .margin({ bottom: 16 })

          Column() {
            Column() {
              Text('🎓')
                .fontSize(48)
                .margin({ bottom: 12 })

              Text('应届大学生')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1A1A1A')

              Text('长期实习、大厂秋招、转正与全职岗位')
                .fontSize(12)
                .fontColor('#666666')
                .margin({ top: 6 })
                .textAlign(TextAlign.Center)
            }
            .width('100%')
            .padding(24)
            .backgroundColor(this.selectedType === StudentType.GRADUATING ? '#FFF3E8' : '#FFFFFF')
            .border({
              width: this.selectedType === StudentType.GRADUATING ? 2 : 1,
              color: this.selectedType === StudentType.GRADUATING ? AppConstants.COLOR_ACCENT : '#E5E5E5',
              radius: 16
            })
            .onClick(() => {
              this.selectedType = StudentType.GRADUATING
            })
          }
          .width('100%')
        }
        .width('85%')
        .padding({ top: 20, bottom: 40 })

        Column() {
          Text('选择后也可以在“我的”页面继续调整')
            .fontSize(12)
            .fontColor('rgba(255,255,255,0.6)')

          Button(this.selectedType ? (this.isConfirming ? '正在进入...' : '确认进入') : '请先选择身份')
            .width('70%')
            .height(50)
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .backgroundColor(this.selectedType ? AppConstants.COLOR_PRIMARY : '#CCCCCC')
            .fontColor('#FFFFFF')
            .borderRadius(25)
            .margin({ top: 24 })
            .enabled(!!this.selectedType && !this.isConfirming)
            .onClick(() => this.handleConfirm())
        }
        .width('100%')
        .padding({ bottom: 60 })
      }
      .width('100%')
      .height('100%')
      .backgroundColor(AppConstants.COLOR_PRIMARY)
    }
    .width('100%')
    .height('100%')
  }
}
