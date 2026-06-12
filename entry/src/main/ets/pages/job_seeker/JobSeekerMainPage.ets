import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { StudentType } from '../../model/UserModel'
import { JobSeekerCompaniesTab } from './JobSeekerCompaniesTab'
import { JobSeekerCommunityTab } from './JobSeekerCommunityTab'
import { JobSeekerJobsTab } from './JobSeekerJobsTab'
import { JobSeekerMessagesTab } from './JobSeekerMessagesTab'
import { JobSeekerProfileTab } from './JobSeekerProfileTab'
import { StompClient, StompMessage } from '../../service/StompClient'
import { MessageDao } from '../../service/MessageDao'

@Entry
@Component
struct JobSeekerMainPage {
  @State currentTabIndex: number = 0
  @StorageLink('total_unread') totalUnread: number = 0
  @StorageLink('msg_refresh') @Watch('refreshTotalUnread') refreshTrigger: number = 0
  private tabsController: TabsController = new TabsController()
  private stompClient: StompClient | null = null
  private messageDao: MessageDao = new MessageDao()

  aboutToAppear(): void {
    if (!AppState.currentUser) {
      AppState.isGuest = true
    }
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
        .padding({ left: 20, right: 20, top: 80, bottom: 12 })
        .backgroundColor(AppConstants.COLOR_PRIMARY)
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        if (AppState.isGuest) {
          Row() {
            Text('游客模式仅开放职位、名企和社区浏览')
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
            .tabBar(this.TabItemBuilder('职', '职位', 0))

          TabContent() { JobSeekerCompaniesTab() }
            .tabBar(this.TabItemBuilder('企', '名企', 1))

          TabContent() { JobSeekerCommunityTab() }
            .tabBar(this.TabItemBuilder('圈', '社区', 2))

          if (!AppState.isGuest) {
            TabContent() { JobSeekerMessagesTab() }
              .tabBar(this.TabItemBuilder('信', '消息', 3))

            TabContent() { JobSeekerProfileTab() }
              .tabBar(this.TabItemBuilder('我', '我的', 4))
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
  TabItemBuilder(icon: string, title: string, index: number) {
    Column() {
      Text(icon)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.currentTabIndex === index ? AppConstants.COLOR_PRIMARY : '#999999')
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
}
