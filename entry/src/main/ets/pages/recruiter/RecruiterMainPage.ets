// 招聘者主页面 - 五大核心Tab容器（B端）

import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { RecruiterTalentsTab } from './RecruiterTalentsTab'
import { RecruiterPublishTab } from './RecruiterPublishTab'
import { RecruiterUpgradeTab } from './RecruiterUpgradeTab'
import { RecruiterMessagesTab } from './RecruiterMessagesTab'
import { RecruiterProfileTab } from './RecruiterProfileTab'
import { StompClient, StompMessage } from '../../service/StompClient'
import { MessageDao } from '../../service/MessageDao'

@Entry
@Component
struct RecruiterMainPage {
  @State currentTabIndex: number = 0
  @StorageLink('total_unread') totalUnread: number = 0
  @StorageLink('msg_refresh') @Watch('refreshTotalUnread') refreshTrigger: number = 0
  private tabsController: TabsController = new TabsController()
  private stompClient: StompClient | null = null
  private messageDao: MessageDao = new MessageDao()

  aboutToAppear(): void {
    this.connectUnreadPush()
    this.refreshTotalUnread()
  }

  aboutToDisappear(): void {
    this.disconnectUnreadPush()
  }

  onPageShow(): void {
    AppStorage.setOrCreate<number>('msg_refresh', Date.now())
  }

  async refreshTotalUnread(): Promise<void> {
    if (AppState.currentUser) {
      const total = await this.messageDao.getUnreadTotal(AppState.currentUser.userId)
      AppStorage.setOrCreate<number>('total_unread', total)
    }
  }

  connectUnreadPush(): void {
    if (!AppState.currentUser) {
      return
    }
    this.stompClient = new StompClient(AppConstants.WS_URL, AppState.currentUser.userId)
    this.stompClient.onMessage((msg: StompMessage) => {
      if (msg.destination === '__connected__') {
        this.stompClient!.subscribe('/user/queue/unread')
        return
      }
      if (msg.destination === '/user/queue/unread') {
        try {
          const data: Record<string, Object> = JSON.parse(msg.body) as Record<string, Object>
          if (data['type'] === 'UNREAD_UPDATE') {
            const conversationId = (data['conversationId'] as string) || ''
            const unreadCount = data['unreadCount'] as number
            if (conversationId && unreadCount !== undefined) {
              this.messageDao.setUnreadCount(conversationId, unreadCount as number)
            }
            if (data['totalUnread'] !== undefined) {
              AppStorage.setOrCreate<number>('total_unread', data['totalUnread'] as number)
            }
            AppStorage.setOrCreate<number>('msg_refresh', Date.now())
          }
        } catch (e) {
          // parse error, ignore
        }
      }
    })
    this.stompClient.onClose(() => {
      // reconnect handled internally
    })
    this.stompClient.connect()
  }

  disconnectUnreadPush(): void {
    if (this.stompClient) {
      this.stompClient.disconnect()
      this.stompClient = null
    }
  }

  build() {
    Stack() {
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

          TabContent() { RecruiterUpgradeTab() }
            .tabBar(this.TabBuilder('升级', 1))

          TabContent() { RecruiterPublishTab() }
            .tabBar(this.CenterTabBuilder(2))

          TabContent() { RecruiterMessagesTab() }
            .tabBar(this.TabBuilder('消息', 3))

          TabContent() { RecruiterProfileTab() }
            .tabBar(this.TabBuilder('我的', 4))
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

      // 消息标签红泡泡 - 覆盖在导航栏上方
      if (this.totalUnread > 0) {
        Text(this.totalUnread > 99 ? '99+' : `${this.totalUnread}`)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor('#FF4D4F')
          .borderRadius(8)
          .padding({ left: 4, right: 4, top: 1, bottom: 1 })
          .position({ x: '72%', y: '94%' })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TabBuilder(title: string, index: number) {
    Column() {
      Text(this.getTabIcon(index))
        .fontSize(20)
        .opacity(this.currentTabIndex === index ? 1.0 : 0.45)
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
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width(36)
      .height(36)
      .backgroundColor(AppConstants.COLOR_ACCENT)
      .borderRadius(18)
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
    const icons = ['👥', '👑', '', '💬', '👤']
    return icons[index]
  }
}
