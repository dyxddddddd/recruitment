import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../common/constants/AppConstants'
import { ChatMessage } from '../model/MessageModel'
import { CampusAIService } from '../service/CampusAIService'
import { MessageDao } from '../service/MessageDao'
import { ResumeDao } from '../service/ResumeDao'

@Entry
@Component
struct ChatPage {
  @State messages: ChatMessage[] = []
  @State inputText: string = ''
  @State isAIAgentSession: boolean = false
  @State peerName: string = 'HR'
  private sessionId: string = ''
  private messageDao: MessageDao = new MessageDao()
  private resumeDao: ResumeDao = new ResumeDao()
  private scroller: Scroller = new Scroller()

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>
    this.sessionId = (params?.sessionId as string) || ''
    this.peerName = (params?.peerName as string) || 'HR'
    this.isAIAgentSession = ((params?.isAIAgent as boolean) || false)
    this.loadMessages()
  }

  async loadMessages(): Promise<void> {
    if (!AppState.currentUser) {
      return
    }
    if (!this.sessionId) {
      this.sessionId = await this.messageDao.ensureJobSeekerStarterSession(AppState.currentUser.userId)
      this.isAIAgentSession = true
    }
    this.messages = await this.messageDao.getMessages(this.sessionId)
    await this.messageDao.markSessionRead(this.sessionId)
    await this.maybeGenerateAIAgentReply()
    this.scrollToBottom()
  }

  async sendMessage(): Promise<void> {
    if (!this.inputText.trim()) {
      return
    }
    const message: ChatMessage = {
      messageId: `m_${Date.now()}`,
      sessionId: this.sessionId,
      senderId: AppState.currentUser?.userId || 'user',
      content: this.inputText.trim(),
      timestamp: Date.now(),
      isAIAgentReply: false,
      messageType: 'text',
      isRead: true
    }
    this.messages.push(message)
    this.inputText = ''
    await this.messageDao.insertConversationMessage(message)
    this.scrollToBottom()
  }

  async maybeGenerateAIAgentReply(): Promise<void> {
    if (!AppState.currentUser || this.messages.length === 0) {
      return
    }
    const enabled = await this.messageDao.getAIAgentEnabled(AppState.currentUser.userId)
    if (!enabled) {
      return
    }
    const latest = this.messages[this.messages.length - 1]
    if (latest.senderId === AppState.currentUser.userId) {
      return
    }
    const hasAIAfterLatest = this.messages.some((item: ChatMessage) =>
      item.timestamp > latest.timestamp &&
      item.senderId === AppState.currentUser!.userId &&
      item.isAIAgentReply
    )
    if (hasAIAfterLatest) {
      return
    }

    try {
      const resume = await this.resumeDao.getResumeByUserId(AppState.currentUser.userId)
      const schedule = await this.resumeDao.getScheduleByUserId(AppState.currentUser.userId)
      const replyText = await CampusAIService.generateDigitalTwinReply({
        user: AppState.currentUser,
        resume: resume,
        availableTime: schedule?.freeSlots.map((item) => item.label) || [],
        hrMessage: latest.content
      })
      const reply: ChatMessage = {
        messageId: `m_${Date.now()}`,
        sessionId: this.sessionId,
        senderId: AppState.currentUser.userId,
        content: replyText,
        timestamp: Date.now(),
        isAIAgentReply: true,
        messageType: 'text',
        isRead: true
      }
      this.messages.push(reply)
      await this.messageDao.insertConversationMessage(reply)
      this.scrollToBottom()
    } catch (e) {
      // keep chat available even if AI reply fails
    }
  }

  scrollToBottom(): void {
    setTimeout(() => {
      try {
        this.scroller.scrollEdge(Edge.Bottom)
      } catch (e) {
        // ignore scroll errors
      }
    }, 100)
  }

  formatTime(timestamp: number): string {
    const date = new Date(timestamp)
    return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
  }

  isOwnMessage(message: ChatMessage): boolean {
    return message.senderId === (AppState.currentUser?.userId || 'user')
  }

  build() {
    Column() {
      Row() {
        Button() {
          Image($r('sys.symbol.chevron_left'))
            .width(22)
            .height(22)
            .fillColor('#1A1A1A')
        }
        .backgroundColor('transparent')
        .onClick(() => router.back())

        Column() {
          Text(this.peerName)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
          if (this.isAIAgentSession) {
            Text('AI 数字分身在线')
              .fontSize(10)
              .fontColor(AppConstants.COLOR_AI_PURPLE)
              .margin({ top: 2 })
          }
        }
        .margin({ left: 12 })
        .alignItems(HorizontalAlign.Start)

        Blank()
      }
      .width('100%')
      .padding({ left: 12, right: 16, top: 28, bottom: 12 })
      .backgroundColor('#FFFFFF')
      .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })

      if (this.isAIAgentSession) {
        Row() {
          Text('当前会话已开启 AI 数字分身，AI 代聊会以紫色气泡展示。')
            .fontSize(11)
            .fontColor(AppConstants.COLOR_AI_PURPLE)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 6, bottom: 6 })
        .backgroundColor('rgba(155,89,182,0.08)')
      }

      List({ scroller: this.scroller }) {
        ForEach(this.messages, (message: ChatMessage) => {
          ListItem() {
            this.MessageBubble(message)
          }
        })
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 12, right: 12, top: 12 })

      Row() {
        TextInput({ placeholder: '输入消息...', text: this.inputText })
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .backgroundColor('#F5F5F5')
          .borderRadius(20)
          .padding({ left: 16, right: 16 })
          .onChange((value: string) => { this.inputText = value })
          .onSubmit(() => this.sendMessage())

        Button() {
          Image($r('sys.symbol.paperplane_fill'))
            .width(20)
            .height(20)
            .fillColor('#FFFFFF')
        }
        .width(40)
        .height(40)
        .backgroundColor(this.inputText.trim() ? AppConstants.COLOR_PRIMARY : '#CCCCCC')
        .borderRadius(20)
        .margin({ left: 8 })
        .enabled(!!this.inputText.trim())
        .onClick(() => this.sendMessage())
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 12 })
      .backgroundColor('#FFFFFF')
      .border({ width: { top: 0.5 }, color: '#F0F0F0' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F0F2F5')
  }

  @Builder
  MessageBubble(message: ChatMessage) {
    Column() {
      if (this.isOwnMessage(message)) {
        Row() {
          Blank()
          Column() {
            if (message.isAIAgentReply) {
              Text('AI 代聊')
                .fontSize(9)
                .fontColor(AppConstants.COLOR_AI_PURPLE)
                .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                .backgroundColor('rgba(155,89,182,0.1)')
                .borderRadius(4)
                .margin({ bottom: 4 })
            }
            Text(message.content)
              .fontSize(14)
              .fontColor(message.isAIAgentReply ? AppConstants.COLOR_AI_PURPLE : '#FFFFFF')
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor(message.isAIAgentReply ? 'rgba(155,89,182,0.12)' : AppConstants.COLOR_PRIMARY)
              .borderRadius(18)
          }
          .alignItems(HorizontalAlign.End)
          .width('80%')
        }
        .width('100%')
      } else {
        Row() {
          Column() {
            Text(message.content)
              .fontSize(14)
              .fontColor('#1A1A1A')
              .padding({ left: 14, right: 14, top: 8, bottom: 8 })
              .backgroundColor('#FFFFFF')
              .borderRadius(18)
          }
          .width('80%')
          Blank()
        }
        .width('100%')
      }

      Text(this.formatTime(message.timestamp))
        .fontSize(10)
        .fontColor('#CCCCCC')
        .margin({ top: 4 })
    }
    .width('100%')
    .margin({ bottom: 10 })
    .alignItems(this.isOwnMessage(message) ? HorizontalAlign.End : HorizontalAlign.Start)
  }
}

export { ChatPage }
