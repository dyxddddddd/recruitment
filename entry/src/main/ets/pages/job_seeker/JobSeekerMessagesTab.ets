import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { ChatSession } from '../../model/MessageModel'
import { MessageDao } from '../../service/MessageDao'
import { DatabaseHelper } from '../../database/DatabaseHelper'
import { TABLE_AI_INTERVIEW, TABLE_SYSTEM_MESSAGE } from '../../database/Tables'

interface InterviewInvite {
  interviewId: string
  status: string
}

@Component
export struct JobSeekerMessagesTab {
  @State sessions: ChatSession[] = []
  @State isAIEnabled: boolean = false
  @State pendingInterviewCount: number = 0
  @StorageLink('msg_refresh') @Watch('onRefresh') refreshTrigger: number = 0
  private messageDao: MessageDao = new MessageDao()

  async aboutToAppear(): Promise<void> {
    await this.loadSessions()
    await this.loadPendingCount()
  }

  async onRefresh(): Promise<void> {
    await this.loadSessions()
    await this.loadPendingCount()
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
  }

  async loadPendingCount(): Promise<void> {
    if (!AppState.currentUser) return
    const seenIds: string[] = []
    let count = 0

    try {
      const store = await DatabaseHelper.getInstance().getStore()

      // tb_ai_interview 中待处理的（仅 invited 和 in_progress）
      try {
        const rs = await store.querySql(
          `SELECT interview_id FROM ${TABLE_AI_INTERVIEW}
           WHERE user_id = '${AppState.currentUser.userId}'
             AND status IN ('invited', 'in_progress')
           ORDER BY invite_time DESC`
        )
        while (rs.goToNextRow()) {
          const id = rs.getString(rs.getColumnIndex('interview_id'))
          if (seenIds.indexOf(id) < 0) {
            seenIds.push(id)
            count++
          }
        }
        rs.close()
      } catch (_e) { /* ignore */ }

      // tb_system_message 兜底：只计入状态仍是 invited/in_progress 的
      try {
        const msgRs = await store.querySql(
          `SELECT content FROM ${TABLE_SYSTEM_MESSAGE}
           WHERE user_id = '${AppState.currentUser.userId}' AND type = 'interview'
           ORDER BY timestamp DESC`
        )
        while (msgRs.goToNextRow()) {
          const content = msgRs.getString(msgRs.getColumnIndex('content'))
          const prefix = '[INTERVIEW:'
          const prefixEnd = content.indexOf(']')
          if (content.indexOf(prefix) === 0 && prefixEnd > prefix.length) {
            const id = content.substring(prefix.length, prefixEnd)
            if (seenIds.indexOf(id) < 0) {
              // 验证该面试确实是待参加状态
              let isPending = true
              try {
                const subRs = await store.querySql(
                  `SELECT status FROM ${TABLE_AI_INTERVIEW} WHERE interview_id = '${id}'`
                )
                if (subRs.goToFirstRow()) {
                  const st = subRs.getString(subRs.getColumnIndex('status'))
                  if (st !== 'invited' && st !== 'in_progress') {
                    isPending = false
                  }
                }
                subRs.close()
              } catch (_e2) { /* 查不到就按待处理计 */ }
              if (isPending) {
                seenIds.push(id)
                count++
              }
            }
          }
        }
        msgRs.close()
      } catch (_e) { /* ignore */ }
    } catch (_e) { /* ignore */ }

    this.pendingInterviewCount = count
    // 更新导航栏未读总数
    let sessionUnread = 0
    for (let i = 0; i < this.sessions.length; i++) {
      sessionUnread += this.sessions[i].unreadCount
    }
    AppStorage.setOrCreate<number>('total_unread', sessionUnread + count)
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

      Row().width('100%').height(1).backgroundColor('#F0F0F0')

      // AI面试入口（紧凑单行）
      Row() {
        Column() {
          Text('🤖').fontSize(18)
        }
        .width(36).height(36).justifyContent(FlexAlign.Center)
        .backgroundColor('#F8F4FF').borderRadius(10)
        .margin({ right: 10 })

        Column() {
          Text('AI虚拟面试')
            .fontSize(14).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
          Text(this.pendingInterviewCount > 0
            ? `${this.pendingInterviewCount} 个待参加`
            : '查看面试记录')
            .fontSize(11).fontColor(this.pendingInterviewCount > 0 ? '#9B59B6' : '#BBBBBB')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start).layoutWeight(1)

        if (this.pendingInterviewCount > 0) {
          Text(`${this.pendingInterviewCount}`)
            .fontSize(12).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('#FF4D4F').borderRadius(10)
            .margin({ right: 6 })
        }
        Image($r('sys.symbol.chevron_right'))
          .width(12).height(12).fillColor('#CCCCCC')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .backgroundColor('#FFFFFF')
      .border({ width: { bottom: 1 }, color: '#F0F0F0' })
      .onClick(() => {
        router.pushUrl({ url: AppConstants.ROUTE_AI_INTERVIEW_HUB })
      })

      if (this.sessions.length === 0 && this.pendingInterviewCount === 0) {
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
