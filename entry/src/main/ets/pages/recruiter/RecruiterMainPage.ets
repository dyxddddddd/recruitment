// 招聘者主页面 - 五大核心Tab容器（B端）

import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { RecruiterTalentsTab } from './RecruiterTalentsTab'
import { RecruiterPublishTab } from './RecruiterPublishTab'
import { RecruiterUpgradeTab } from './RecruiterUpgradeTab'
import { RecruiterMessagesTab } from './RecruiterMessagesTab'
import { RecruiterProfileTab } from './RecruiterProfileTab'

@Entry
@Component
struct RecruiterMainPage {
  @State currentTabIndex: number = 0
  private tabsController: TabsController = new TabsController()

  build() {
    Column() {
      // 顶部信息
      Row() {
        Text(AppConstants.APP_NAME)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')

        Blank()

        Row() {
          Text(AppState.currentUser?.companyName || '企业用户')
            .fontSize(11)
            .fontColor('#FFFFFF')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('rgba(255,255,255,0.25)')
            .borderRadius(10)
        }

        if (AppState.currentUser?.vipLevel === 'vip') {
          Text('VIP')
            .fontSize(10)
            .fontColor('#FFD700')
            .fontWeight(FontWeight.Bold)
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .border({ width: 1, color: '#FFD700', radius: 8 })
            .margin({ left: 6 })
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 28, bottom: 12 })
      .backgroundColor(AppConstants.COLOR_ACCENT)

      // Tab内容区
      Tabs({
        barPosition: BarPosition.End,
        controller: this.tabsController,
        index: this.currentTabIndex
      }) {
        TabContent() { RecruiterTalentsTab() }
          .tabBar(this.TabBuilder('人才', 0))

        TabContent() { RecruiterPublishTab() }
          .tabBar(this.CenterTabBuilder(2))

        TabContent() { RecruiterUpgradeTab() }
          .tabBar(this.TabBuilder('升级', 3))

        TabContent() { RecruiterMessagesTab() }
          .tabBar(this.TabBuilder('消息', 4))

        TabContent() { RecruiterProfileTab() }
          .tabBar(this.TabBuilder('我的', 5))
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
  TabBuilder(title: string, index: number) {
    Column() {
      Text(this.getTabIcon(index))
        .fontSize(20)
      Text(title)
        .fontSize(10)
        .fontColor(this.currentTabIndex === index ? AppConstants.COLOR_ACCENT : '#999999')
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  // 中央发布按钮
  @Builder
  CenterTabBuilder(index: number) {
    Column() {
      Column() {
        Text('+')
          .fontSize(28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width(48)
      .height(48)
      .backgroundColor(AppConstants.COLOR_ACCENT)
      .borderRadius(24)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Text('发布')
        .fontSize(10)
        .fontColor(this.currentTabIndex === 2 ? AppConstants.COLOR_ACCENT : '#999999')
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  getTabIcon(index: number): string {
    const icons = ['👥', '', '👑', '💬', '👤']
    return icons[index]
  }
}
