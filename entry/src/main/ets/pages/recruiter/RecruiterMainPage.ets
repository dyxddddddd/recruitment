// 招聘者主页面 - 五大核心Tab容器（B端）

import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { UserRole, AuthStatus } from '../../model/UserModel'
import { RecruiterTalentsTab } from './RecruiterTalentsTab'
import { RecruiterPublishTab } from './RecruiterPublishTab'
import { RecruiterUpgradeTab } from './RecruiterUpgradeTab'
import { RecruiterMessagesTab } from './RecruiterMessagesTab'
import { RecruiterProfileTab } from './RecruiterProfileTab'
import { StompClient, StompMessage } from '../../service/StompClient'
import { MessageDao } from '../../service/MessageDao'
import { DatabaseHelper } from '../../database/DatabaseHelper'
import { TABLE_JOB } from '../../database/Tables'

@Entry
@Component
struct RecruiterMainPage {
  @State currentTabIndex: number = 0
  @StorageLink('total_unread') totalUnread: number = 0
  @StorageLink('msg_refresh') @Watch('refreshTotalUnread') refreshTrigger: number = 0
  @StorageLink('recruiter_switch_tab') @Watch('onTabSwitch') pendingTabSwitch: number = -1
  @State showAuthGate: boolean = false
  @State showFirstJobPrompt: boolean = false
  @State authGateChecking: boolean = true
  private tabsController: TabsController = new TabsController()
  private stompClient: StompClient | null = null
  private messageDao: MessageDao = new MessageDao()

  aboutToAppear(): void {
    this.checkOnboarding()
    this.connectUnreadPush()
    this.refreshTotalUnread()
  }

  aboutToDisappear(): void {
    this.disconnectUnreadPush()
  }

  onPageShow(): void {
    AppStorage.setOrCreate<number>('msg_refresh', Date.now())
    this.checkOnboarding()
  }

  async checkOnboarding(): Promise<void> {
    const user = AppState.currentUser
    if (!user || user.role !== UserRole.RECRUITER) {
      this.authGateChecking = false
      return
    }

    const authStatus = user.authStatus ?? AuthStatus.UNAUTHENTICATED

    // 未认证或被驳回 → 强制跳转认证页
    if (authStatus === AuthStatus.UNAUTHENTICATED || authStatus === AuthStatus.REJECTED) {
      this.showAuthGate = true
      this.authGateChecking = false
      return
    }

    // 审核中 → 允许浏览但提示
    if (authStatus === AuthStatus.PENDING) {
      this.showAuthGate = false
      this.authGateChecking = false
      return
    }

    // 已认证 → 检查是否有岗位
    this.showAuthGate = false
    try {
      const store = await DatabaseHelper.getInstance().getStore()
      const rs = await store.querySql(
        `SELECT COUNT(*) AS cnt FROM ${TABLE_JOB} WHERE recruiter_id = '${user.userId}'`
      )
      let jobCount = 0
      if (rs.goToFirstRow()) {
        jobCount = rs.getLong(rs.getColumnIndex('cnt'))
      }
      rs.close()
      this.showFirstJobPrompt = jobCount === 0
    } catch (_e) {
      // ignore
    }
    this.authGateChecking = false
  }

  async refreshTotalUnread(): Promise<void> {
    if (AppState.currentUser) {
      const total = await this.messageDao.getUnreadTotal(AppState.currentUser.userId)
      AppStorage.setOrCreate<number>('total_unread', total)
    }
  }

  onTabSwitch(): void {
    if (this.pendingTabSwitch >= 0) {
      this.currentTabIndex = this.pendingTabSwitch
      this.tabsController.changeIndex(this.pendingTabSwitch)
      AppStorage.setOrCreate<number>('recruiter_switch_tab', -1)
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
        // 顶部信息栏
        Row() {
          Text(AppConstants.APP_NAME)
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .fontFamily('HarmonyOS Sans')

          Blank()

          Row() {
            Text(AppState.currentUser?.companyName || '企业用户')
              .fontSize(12)
              .fontColor('#FFFFFF')
              .padding({ left: 10, right: 10, top: 4, bottom: 4 })
              .backgroundColor('rgba(255,255,255,0.18)')
              .borderRadius(12)
              .border({ width: 1, color: 'rgba(255,255,255,0.25)' })
          }

          if (AppState.currentUser?.vipLevel === 'vip') {
            Text('VIP')
              .fontSize(11)
              .fontColor('#FFD700')
              .fontWeight(FontWeight.Bold)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor('rgba(255,215,0,0.15)')
              .border({ width: 1, color: '#FFD700', radius: 10 })
              .margin({ left: 6 })
          }
        }
        .width('100%')
        .padding({ left: AppConstants.SPACING_MD, right: AppConstants.SPACING_MD, top: 60, bottom: AppConstants.SPACING_MD })
        .linearGradient({
          direction: GradientDirection.Bottom,
          colors: [['#FF8C55', 0.0], ['#FF6B35', 0.6], ['#E5551F', 1.0]]
        })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
        .shadow({ radius: 10, color: '#30000000', offsetY: 3 })

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
        .shadow({ radius: 4, color: '#10000000', offsetY: -2 })
      }
      .width('100%')
      .height('100%')

      // 消息标签红泡泡 - 覆盖在导航栏上方
      if (this.totalUnread > 0) {
        Text(this.totalUnread > 99 ? '99+' : `${this.totalUnread}`)
          .fontSize(AppConstants.FONT_SIZE_XS)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor(AppConstants.COLOR_DANGER)
          .borderRadius(AppConstants.BORDER_RADIUS_MD)
          .padding({ left: AppConstants.SPACING_XS, right: AppConstants.SPACING_XS, top: 1, bottom: 1 })
          .position({ x: '72%', y: '93%' })
      }

      // 企业认证门控 —— 未认证/被驳回时全屏遮罩
      if (this.showAuthGate) {
        Column() {
          Column() {
            Text('🔐').fontSize(48).margin({ bottom: 12 })
            Text('请先完成企业认证')
              .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
              .margin({ bottom: 8 })
            Text(AppState.currentUser?.authStatus === AuthStatus.REJECTED
              ? '您的企业认证申请被驳回，请重新提交认证资料。'
              : '首次登录需要完成企业资质认证，\n认证通过后才能使用人才推荐与岗位发布功能。')
              .fontSize(13).fontColor('#888888').lineHeight(20)
              .textAlign(TextAlign.Center)
              .width('90%')
              .margin({ bottom: 24 })

            Button('前往企业认证')
              .width('70%').height(46).fontSize(15).fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF').backgroundColor(AppConstants.COLOR_ACCENT)
              .borderRadius(23)
              .onClick(() => {
                this.showAuthGate = false
                router.pushUrl({ url: AppConstants.ROUTE_RECRUITER_AUTH })
              })

            Button('稍后再说')
              .fontSize(13).fontColor('#BBBBBB')
              .backgroundColor(Color.Transparent)
              .margin({ top: 12 })
              .onClick(() => {
                this.showAuthGate = false
              })
          }
          .width('85%').padding(28).backgroundColor('#FFFFFF').borderRadius(18)
          .shadow({ radius: 24, color: 'rgba(0,0,0,0.18)' })
        }
        .width('100%').height('100%')
        .backgroundColor('rgba(0,0,0,0.55)')
        .justifyContent(FlexAlign.Center)
      }

      // 首次岗位引导弹窗
      if (this.showFirstJobPrompt && !this.showAuthGate) {
        Column() {
          Column() {
            Text('📋').fontSize(48).margin({ bottom: 12 })
            Text('发布你的第一个岗位')
              .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
              .margin({ bottom: 8 })
            Text('认证通过后，建议立即发布一个招聘岗位，\n系统将基于岗位要求为你智能匹配推荐人才。')
              .fontSize(13).fontColor('#888888').lineHeight(20)
              .textAlign(TextAlign.Center)
              .width('90%')
              .margin({ bottom: 24 })

            Button('立即发布岗位')
              .width('70%').height(46).fontSize(15).fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF').backgroundColor(AppConstants.COLOR_ACCENT)
              .borderRadius(23)
              .onClick(() => {
                this.showFirstJobPrompt = false
                this.currentTabIndex = 2
                this.tabsController.changeIndex(2)
              })

            Button('先去逛逛')
              .fontSize(13).fontColor('#BBBBBB')
              .backgroundColor(Color.Transparent)
              .margin({ top: 12 })
              .onClick(() => {
                this.showFirstJobPrompt = false
              })
          }
          .width('85%').padding(28).backgroundColor('#FFFFFF').borderRadius(18)
          .shadow({ radius: 24, color: 'rgba(0,0,0,0.18)' })
        }
        .width('100%').height('100%')
        .backgroundColor('rgba(0,0,0,0.55)')
        .justifyContent(FlexAlign.Center)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  TabBuilder(title: string, index: number) {
    Column() {
      Text(this.getTabIcon(index))
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.currentTabIndex === index ? AppConstants.COLOR_ACCENT : '#999999')
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
      .backgroundColor(this.currentTabIndex === 2 ? AppConstants.COLOR_ACCENT : 'rgba(255,107,53,0.9)')
      .borderRadius(10)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .shadow({ radius: 4, color: this.currentTabIndex === 2 ? '#40FF6B35' : '#20FF6B35', offsetY: 2 })

      Text('发布')
        .fontSize(AppConstants.FONT_SIZE_XS)
        .fontColor(this.currentTabIndex === 2 ? AppConstants.COLOR_ACCENT : AppConstants.COLOR_TEXT_HINT)
        .margin({ top: AppConstants.SPACING_SM })
        .fontWeight(this.currentTabIndex === 2 ? FontWeight.Medium : FontWeight.Normal)
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }

  getTabIcon(index: number): string {
    const icons: string[] = ['才', '升', '', '信', '我']
    return icons[index]
  }
}
