import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { StudentType } from '../../model/UserModel'
import { JobSeekerCompaniesTab } from './JobSeekerCompaniesTab'
import { JobSeekerCommunityTab } from './JobSeekerCommunityTab'
import { JobSeekerJobsTab } from './JobSeekerJobsTab'
import { JobSeekerMessagesTab } from './JobSeekerMessagesTab'
import { JobSeekerProfileTab } from './JobSeekerProfileTab'

@Entry
@Component
struct JobSeekerMainPage {
  @State currentTabIndex: number = 0
  private tabsController: TabsController = new TabsController()

  aboutToAppear(): void {
    if (!AppState.currentUser) {
      AppState.isGuest = true
    }
  }

  build() {
    Column() {
      Row() {
        Text(AppConstants.APP_NAME)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')

        Blank()

        Text(AppState.currentUser?.studentType === StudentType.GRADUATING ? '应届生' : '在校生')
          .fontSize(11)
          .fontColor('#FFFFFF')
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor('rgba(255,255,255,0.25)')
          .borderRadius(10)
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 60, bottom: 12 })
      .backgroundColor(AppConstants.COLOR_PRIMARY)
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      if (AppState.isGuest) {
        Row() {
          Text('游客模式仅开放职位、名企、社区浏览')
            .fontSize(11)
            .fontColor('#FFFFFF')
          Blank()
          Button('去登录')
            .fontSize(11)
            .height(24)
            .backgroundColor('#FFFFFF')
            .fontColor(AppConstants.COLOR_PRIMARY)
            .borderRadius(12)
            .padding({ left: 12, right: 12 })
            .onClick(() => router.pushUrl({ url: AppConstants.ROUTE_LOGIN }))
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 10 })
        .backgroundColor(AppConstants.COLOR_PRIMARY)
      }

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

        if (!AppState.isGuest) {
          TabContent() { JobSeekerMessagesTab() }
            .tabBar(this.TabItemBuilder('消息', 3))

          TabContent() { JobSeekerProfileTab() }
            .tabBar(this.TabItemBuilder('我的', 4))
        }
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
