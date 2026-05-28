// 求职者主页面 - 五大核心Tab容器

import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { UserRole, StudentType } from '../../model/UserModel'
import { JobSeekerJobsTab } from './JobSeekerJobsTab'
import { JobSeekerCompaniesTab } from './JobSeekerCompaniesTab'
import { JobSeekerCommunityTab } from './JobSeekerCommunityTab'
import { JobSeekerMessagesTab } from './JobSeekerMessagesTab'
import { JobSeekerProfileTab } from './JobSeekerProfileTab'

@Entry
@Component
struct JobSeekerMainPage {
  @State currentTabIndex: number = 0
  @State isAIEnabled: boolean = false
  private tabsController: TabsController = new TabsController()

  aboutToAppear(): void {
    if (!AppState.currentUser) {
      // 游客模式默认设置
      AppState.isGuest = true
    }
  }

  build() {
    Column() {
      // 顶部身份快捷切换
      Row() {
        Text(AppConstants.APP_NAME)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')

        Blank()

        Row() {
          Text(AppState.currentUser?.studentType === StudentType.GRADUATING ? '应届生' : '在校生')
            .fontSize(11)
            .fontColor('#FFFFFF')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('rgba(255,255,255,0.25)')
            .borderRadius(10)
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 28, bottom: 12 })
      .backgroundColor(AppConstants.COLOR_PRIMARY)

      // Tab内容区
      Tabs({
        barPosition: BarPosition.End,
        controller: this.tabsController,
        index: this.currentTabIndex
      }) {
        TabContent() { JobSeekerJobsTab() }
          .tabBar(this.TabItemBuilder('职位', 0))

        TabContent() { JobSeekerCompaniesTab() }
          .tabBar(this.TabItemBuilder('名企', 1))

        TabContent() { JobSeekerCommunityTab() }
          .tabBar(this.TabItemBuilder('社区', 2))

        TabContent() { JobSeekerMessagesTab() }
          .tabBar(this.TabItemBuilder('消息', 3))

        TabContent() { JobSeekerProfileTab() }
          .tabBar(this.TabItemBuilder('我的', 4))
      }
      .barHeight(56)
      .barBackgroundColor('#FFFFFF')
      .onChange((index: number) => {
        this.currentTabIndex = index
      })
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TabItemBuilder(title: string, index: number) {
    Column() {
      Text(this.getTabIcon(index))
        .fontSize(20)
      Text(title)
        .fontSize(10)
        .fontColor(this.currentTabIndex === index ? AppConstants.COLOR_PRIMARY : '#999999')
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  getTabIcon(index: number): string {
    const icons = ['💼', '🏢', '👥', '💬', '👤']
    return icons[index]
  }
}
