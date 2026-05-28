// 首页 - 角色选择入口（双向流分水岭）

import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../common/constants/AppConstants'
import { RoleCard } from '../common/components/RoleCard'
import { UserProfile, UserRole, StudentType } from '../model/UserModel'
import { UserDao } from '../service/UserDao'

@Entry
@Component
struct Index {
  @State selectedRole: string = ''
  private userDao: UserDao = new UserDao()

  async aboutToAppear(): Promise<void> {
    // 检查是否有已登录用户
    const loggedInUser = await this.userDao.getLoggedInUser()
    if (loggedInUser) {
      AppState.currentUser = loggedInUser
      AppState.isLoggedIn = true
      AppState.isGuest = false
      this.navigateToMain(loggedInUser.role)
    }
  }

  navigateToMain(role: UserRole): void {
    if (role === UserRole.JOB_SEEKER) {
      router.replaceUrl({ url: AppConstants.ROUTE_JOB_SEEKER_MAIN })
    } else {
      router.replaceUrl({ url: AppConstants.ROUTE_RECRUITER_MAIN })
    }
  }

  handleRoleSelect(role: string): void {
    this.selectedRole = role
    if (role === UserRole.JOB_SEEKER) {
      router.pushUrl({ url: AppConstants.ROUTE_LOGIN })
    } else {
      // 招聘者先登录，然后进行资质认证
      router.pushUrl({
        url: AppConstants.ROUTE_LOGIN,
        params: { role: UserRole.RECRUITER }
      })
    }
  }

  build() {
    Column() {
      // 顶部
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

      // 选择你的身份
      Column() {
        Text('选择你的身份')
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.COLOR_TEXT_PRIMARY)
          .margin({ top: 40, bottom: 32 })

        // 求职者卡片
        Column() {
          RoleCard({
            title: '我要找工作',
            description: '在校生/应届生专属 · 兼职微任务/全职实习 · AI简历工具 · 校友引路',
            emoji: '🎓',
            bgColor: '#F0F7FF',
            cardBorderColor: this.selectedRole === UserRole.JOB_SEEKER ? '#4A90D9' : '#D0E0F0'
          })
            .onClick(() => this.handleRoleSelect(UserRole.JOB_SEEKER))
        }
        .width('80%')
        .margin({ bottom: 20 })

        // 招聘者卡片
        Column() {
          RoleCard({
            title: '我要招人',
            description: '企业HR · 人才搜索/推荐 · AI辅助发布 · AI虚拟人一面评估',
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

      // 底部
      Text('已有账号？直接进入')
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
