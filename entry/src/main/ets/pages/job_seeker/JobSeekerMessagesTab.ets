import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { ChatSession } from '../../model/MessageModel'
import { MessageDao } from '../../service/MessageDao'

@Component
export struct JobSeekerMessagesTab {
  @State sessions: ChatSession[] = []
  @State isAIEnabled: boolean = false
  @StorageLink('msg_refresh') @Watch('onRefresh') refreshTrigger: number = 0
  private messageDao: MessageDao = new MessageDao()

  aboutToAppear(): void {
    this.loadSessions()
  }

  onRefresh(): void {
    this.loadSessions()
  }

  async loadSessions(): Promise<void> {
    if (!AppState.currentUser) {
      this.sessions = []
      this.isAIEnabled = false
      return
    }
    await this.messageDao.ensureJobSeekerDemoSession(AppState.currentUser.userId)
    await this.messageDao.syncConversations(AppState.currentUser.userId)
    this.sessions = await this.messageDao.getConversations(AppState.currentUser.userId)
    this.isAIEnabled = await this.messageDao.getAIAgentEnabled(AppState.currentUser.userId)
    let total = 0
    for (let i = 0; i < this.sessions.length; i++) {
      total += this.sessions[i].unreadCount
    }
    AppStorage.setOrCreate<number>('total_unread', total)
  }

  handleSessionClick(session: ChatSession): void {
    router.pushUrl({
      url: AppConstants.ROUTE_CHAT,
      params: {
        conversationId: session.sessionId,
        peerName: session.peerName || 'HR',
        isAIAgent: session.isAIAgent
      }
    })
  }

  async toggleAI(value: boolean): Promise<void> {
    this.isAIEnabled = value
    if (AppState.currentUser) {
      await this.messageDao.updateAIAgentEnabled(AppState.currentUser.userId, value)
    }
    AlertDialog.show({
      title: value ? 'AI 数字分身已开启' : 'AI 数字分身已关闭',
      message: value
        ? '开启后，系统会在你离线时根据简历与时间底线帮助你先接住 HR 的初步沟通。'
        : '关闭后，HR 消息将只等待你本人上线处理。'
    })
  }

  getAvatarChar(name: string): string {
    if (!name) {
      return '?'
    }
    return name.charAt(0)
  }

  getAvatarColor(name: string): string {
    const colors: string[] = [
      '#FF7B54', '#4A90D9', '#52C41A', '#FAAD14', '#9B59B6',
      '#FF4D4F', '#2E6FD8', '#279255', '#EB5A46', '#8963B3'
    ]
    let hash = 0
    for (let i = 0; i < name.length; i++) {
      hash = name.charCodeAt(i) + ((hash << 5) - hash)
    }
    return colors[Math.abs(hash) % colors.length]
  }

  formatTime(timestamp: number): string {
    if (!timestamp) {
      return ''
    }
    const now = Date.now()
    const diff = now - timestamp
    if (diff < 60000) {
      return '刚刚'
    }
    if (diff < 3600000) {
      return `${Math.floor(diff / 60000)}分钟前`
    }
    if (diff < 86400000) {
      const date = new Date(timestamp)
      return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
    }
    const date = new Date(timestamp)
    return `${date.getFullYear()}/${date.getMonth() + 1}/${date.getDate()}`
  }

  build() {
    Column() {
      Row() {
        Text('沟通消息')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')

        Blank()

        Row() {
          Text('AI 分身')
            .fontSize(11)
            .fontColor(this.isAIEnabled ? '#FFFFFF' : '#999999')
            .margin({ right: 6 })

          Toggle({ type: ToggleType.Switch, isOn: this.isAIEnabled })
            .selectedColor(AppConstants.COLOR_AI_PURPLE)
            .onChange((value: boolean) => { this.toggleAI(value) })
        }
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .backgroundColor(this.isAIEnabled ? 'rgba(155,89,182,0.15)' : '#F5F5F5')
        .borderRadius(16)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      Divider().height(1).color('#F0F0F0')

      if (this.sessions.length === 0) {
        Column() {
          Text('💬')
            .fontSize(48)
            .margin({ bottom: 12 })
          Text('暂无消息')
            .fontSize(14)
            .fontColor('#999999')
          Text('当有HR联系或咨询时，沟通会显示在这里')
            .fontSize(12)
            .fontColor('#CCCCCC')
            .textAlign(TextAlign.Center)
            .width('80%')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
        .backgroundColor('#FFFFFF')
      } else {
        List() {
          ForEach(this.sessions, (session: ChatSession) => {
            ListItem() {
              Row() {
                Stack() {
                  Circle()
                    .width(48)
                    .height(48)
                    .fill(this.getAvatarColor(session.peerName || '用户'))
                  Text(this.getAvatarChar(session.peerName || '用'))
                    .fontSize(20)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#FFFFFF')
                }
                .margin({ right: 12 })

                Column() {
                  Row() {
                    Text(session.peerName || '用户')
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#1A1A1A')
                    if (session.isAIAgent) {
                      Text('AI')
                        .fontSize(9)
                        .fontColor(AppConstants.COLOR_AI_PURPLE)
                        .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                        .backgroundColor('rgba(155,89,182,0.1)')
                        .borderRadius(4)
                        .margin({ left: 6 })
                    }
                    Blank()
                    Text(this.formatTime(session.lastMessageTime))
                      .fontSize(11)
                      .fontColor('#B0B5BE')
                  }
                  .width('100%')
                  .margin({ bottom: 4 })

                  Row() {
                    Text(session.lastMessage || '暂无消息')
                      .fontSize(13)
                      .fontColor('#999999')
                      .maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis })
                      .layoutWeight(1)

                    if (session.unreadCount > 0) {
                      Text(session.unreadCount > 99 ? '99+' : `${session.unreadCount}`)
                        .fontSize(11)
                        .fontWeight(FontWeight.Bold)
                        .fontColor('#FFFFFF')
                        .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                        .backgroundColor('#FF4D4F')
                        .borderRadius(10)
                    }
                  }
                  .width('100%')
                }
                .layoutWeight(1)
              }
              .width('100%')
              .padding({ top: 14, bottom: 14 })
              .border({ width: { bottom: 0.5 }, color: '#F5F5F5' })
            }
            .onClick(() => this.handleSessionClick(session))
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
