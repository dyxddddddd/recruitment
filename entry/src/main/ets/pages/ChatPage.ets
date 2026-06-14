import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../common/constants/AppConstants'
import { ChatMessage, buildConversationId, getPeerId } from '../model/MessageModel'
import { UserRole } from '../model/UserModel'
import { CampusAIService } from '../service/CampusAIService'
import { MessageDao } from '../service/MessageDao'
import { ResumeDao } from '../service/ResumeDao'
import { StompClient, StompMessage } from '../service/StompClient'

@Entry
@Component
struct ChatPage {
  @State messages: ChatMessage[] = []
  @State inputText: string = ''
  @State isAIAgentSession: boolean = false
  @State peerName: string = '联系人'
  @State connectionStatus: string = ''
  @State isConnected: boolean = false
  @State showMorePanel: boolean = false
  private conversationId: string = ''
  private peerId: string = ''
  private messageDao: MessageDao = new MessageDao()
  private resumeDao: ResumeDao = new ResumeDao()
  private stompClient: StompClient | null = null
  private scroller: Scroller = new Scroller()
  private isSending: boolean = false
  private userId: string = ''
  private lastDateLabel: string = ''

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>
    this.conversationId = (params?.sessionId as string) || (params?.conversationId as string) || ''
    this.peerName = (params?.peerName as string) || '联系人'
    this.isAIAgentSession = ((params?.isAIAgent as boolean) || false)
    this.userId = AppState.currentUser?.userId || ''

    if (!this.userId) {
      return
    }

    this.initChat()
  }

  aboutToDisappear(): void {
    if (this.stompClient) {
      this.stompClient.disconnect()
      this.stompClient = null
    }
  }

  async initChat(): Promise<void> {
    if (!this.conversationId) {
      // 学生端无指定会话时，创建AI助手对话（不关联真实用户）
      const aiAssistantId = `ai_assistant_${this.userId}`
      this.conversationId = buildConversationId(this.userId, aiAssistantId)
      this.isAIAgentSession = true
      this.peerName = 'AI 招聘助手'
    }

    this.peerId = getPeerId(this.conversationId, this.userId)

    await this.messageDao.ensureConversation(this.conversationId, this.peerId, this.peerName)

    this.messages = await this.messageDao.getMessages(this.conversationId)
    this.scrollToBottom()

    const syncedCount = await this.messageDao.syncMessages(this.conversationId)
    if (syncedCount > 0) {
      this.messages = await this.messageDao.getMessages(this.conversationId)
      this.scrollToBottom()
    }

    await this.messageDao.syncConversations(this.userId)
    await this.messageDao.markConversationRead(this.conversationId)
    await this.messageDao.markReadRemote(this.conversationId, this.userId)

    this.connectWebSocket()
    await this.maybeGenerateAIAgentReply()
  }

  connectWebSocket(): void {
    this.stompClient = new StompClient(AppConstants.WS_URL, this.userId)

    this.stompClient.onMessage((msg: StompMessage) => {
      if (msg.destination === '__connected__') {
        this.isConnected = true
        this.connectionStatus = ''
        this.stompClient!.subscribe('/user/queue/private')
        this.stompClient!.subscribe('/user/queue/unread')
        return
      }

      if (msg.destination === '/user/queue/private') {
        this.handleIncomingMessage(msg.body)
        return
      }

      if (msg.destination === '/user/queue/unread') {
        this.handleUnreadPush(msg.body)
      }
    })

    this.stompClient.onClose(() => {
      this.isConnected = false
      this.connectionStatus = '连接断开，重连中...'
    })

    this.stompClient.connect()
  }

  handleUnreadPush(body: string): void {
    try {
      const data: Record<string, Object> = JSON.parse(body) as Record<string, Object>
      if (data['type'] === 'READ_RECEIPT') {
        const receiptConversationId = (data['conversationId'] as string) || ''
        const readerId = (data['readerId'] as string) || ''
        if (receiptConversationId === this.conversationId && readerId && readerId !== this.userId) {
          // 对方已读，刷新消息列表显示"已读"标记
          const updated: ChatMessage[] = []
          for (let i = 0; i < this.messages.length; i++) {
            const m = this.messages[i]
            if (m.senderId === this.userId) {
              updated.push({
                messageId: m.messageId,
                sessionId: m.sessionId,
                senderId: m.senderId,
                receiverId: m.receiverId,
                content: m.content,
                timestamp: m.timestamp,
                isAIAgentReply: m.isAIAgentReply,
                messageType: m.messageType,
                isRead: true
              })
            } else {
              updated.push(m)
            }
          }
          this.messages = updated
        }
      }
    } catch (e) {
      // parse error, ignore
    }
  }

  async handleIncomingMessage(body: string): Promise<void> {
    try {
      const remote: Record<string, Object> = JSON.parse(body) as Record<string, Object>
      const msgConversationId = (remote['conversationId'] as string) || ''
      if (msgConversationId !== this.conversationId) {
        const msgContent = (remote['content'] as string) || ''
        const msgTimestamp = (remote['timestamp'] as number) || Date.now()
        await this.messageDao.incrementUnread(msgConversationId, msgContent, msgTimestamp)
        return
      }

      const senderId = remote['senderId'] as string
      const newMsg: ChatMessage = {
        messageId: (remote['id'] as string) || `m_${Date.now()}`,
        sessionId: msgConversationId,
        senderId: senderId,
        receiverId: remote['receiverId'] as string || '',
        content: remote['content'] as string,
        timestamp: (remote['timestamp'] as number) || Date.now(),
        isAIAgentReply: false,
        messageType: ((remote['type'] as string) || 'TEXT').toLowerCase() as 'text' | 'image' | 'file',
        isRead: true
      }

      const exists = this.messages.some((m: ChatMessage) => m.messageId === newMsg.messageId)
      if (exists) {
        return
      }

      await this.messageDao.insertMessage(newMsg)
      this.messages = this.messages.concat([newMsg])
      this.scrollToBottom()

      await this.messageDao.markConversationRead(this.conversationId)
      await this.messageDao.markReadRemote(this.conversationId, this.userId)

      if (senderId !== this.userId) {
        await this.maybeGenerateAIAgentReply()
      }
    } catch (e) {
      // parse error, ignore
    }
  }

  async sendMessage(): Promise<void> {
    const trimmed = this.inputText.trim()
    if (!trimmed || this.isSending || !this.userId) {
      return
    }
    this.isSending = true

    const message: ChatMessage = {
      messageId: `m_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      sessionId: this.conversationId,
      senderId: this.userId,
      receiverId: this.peerId,
      content: trimmed,
      timestamp: Date.now(),
      isAIAgentReply: false,
      messageType: 'text',
      isRead: false
    }

    this.messages = this.messages.concat([message])
    this.inputText = ''
    this.scrollToBottom()

    await this.messageDao.insertMessage(message)

    if (this.stompClient && this.isConnected) {
      const stompBody = JSON.stringify({
        senderId: this.userId,
        receiverId: this.peerId,
        content: trimmed,
        type: 'TEXT'
      })
      this.stompClient.send('/app/chat.send', stompBody as string)
    } else {
      this.connectionStatus = '未送达'
      setTimeout(() => {
        this.connectionStatus = ''
      }, 2000)
    }

    this.isSending = false
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
        messageId: `m_${Date.now()}_ai`,
        sessionId: this.conversationId,
        senderId: AppState.currentUser.userId,
        receiverId: this.peerId,
        content: replyText,
        timestamp: Date.now(),
        isAIAgentReply: true,
        messageType: 'text',
        isRead: true
      }
      this.messages = this.messages.concat([reply])
      await this.messageDao.insertMessage(reply)
      this.scrollToBottom()

      if (this.stompClient && this.isConnected) {
        const stompBody = JSON.stringify({
          senderId: AppState.currentUser.userId,
          receiverId: this.peerId,
          content: replyText,
          type: 'TEXT'
        })
        this.stompClient.send('/app/chat.send', stompBody as string)
      }
    } catch (e) {
      // AI reply failure shouldn't break chat
    }
  }

  scrollToBottom(): void {
    setTimeout(() => {
      try {
        this.scroller.scrollEdge(Edge.Bottom)
      } catch (e) {
        // ignore
      }
    }, 100)
  }

  // ---------- UI 辅助方法 ----------

  isOwnMessage(message: ChatMessage): boolean {
    return message.senderId === this.userId
  }

  isRecruiter(): boolean {
    return AppState.currentUser?.role === UserRole.RECRUITER
  }

  isStudent(): boolean {
    return AppState.currentUser?.role === UserRole.JOB_SEEKER
  }

  // HR快捷回复模板
  getQuickReplies(): string[] {
    return [
      '你好，方便安排面试时间吗？',
      '请确认收到面试邀请',
      '你的简历已通过初筛，请查看面试详情',
      '请尽快完成AI虚拟面试',
      '恭喜你通过面试，请查收Offer'
    ]
  }

  sendQuickReply(text: string): void {
    this.inputText = text
    this.sendMessage()
  }

  goToInterviewSchedule(): void {
    // 回到招聘者主页并切换到"我的"tab（面试排期在该tab中）
    AppStorage.setOrCreate('recruiter_switch_tab', 4)
    if (this.stompClient) {
      this.stompClient.disconnect()
      this.stompClient = null
    }
    router.back()
  }

  // 获取发送者气泡颜色
  getBubbleColor(isAI: boolean): string {
    if (isAI) {
      return 'rgba(255,107,53,0.12)'
    }
    return this.isStudent() ? AppConstants.COLOR_PRIMARY : AppConstants.COLOR_ACCENT
  }

  getBubbleTextColor(isAI: boolean): string {
    if (isAI) {
      return AppConstants.COLOR_ACCENT
    }
    return '#FFFFFF'
  }

  getHeaderGradient(): [string, string] {
    return this.isStudent() ? ['#4A90D9', '#6BAFEF'] : ['#FF7B54', '#FF9F6B']
  }

  // 提取名字首字/首字母作为头像
  getAvatarChar(name: string): string {
    if (!name) {
      return '?'
    }
    return name.charAt(0)
  }

  // 自己的头像文字
  getSelfAvatarChar(): string {
    const user = AppState.currentUser
    if (!user) return '我'
    const name = user.realName || user.hrRealName || user.companyName || '我'
    return name.charAt(0)
  }

  // 根据名字生成固定的头像颜色
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

  // 点击头像跳转到对方主页
  navigateToPeerProfile(): void {
    if (!this.peerId) return
    if (this.isStudent()) {
      // 学生端：点击HR头像 → 查看企业信息
      router.pushUrl({
        url: AppConstants.ROUTE_COMPANY_DETAIL,
        params: { companyId: this.peerId }
      })
    } else {
      // HR端：点击学生头像 → 查看人才详情
      router.pushUrl({
        url: AppConstants.ROUTE_TALENT_DETAIL,
        params: { userId: this.peerId }
      })
    }
  }

  // 时间格式化
  formatTime(timestamp: number): string {
    const date = new Date(timestamp)
    return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
  }

  formatDateLabel(timestamp: number): string {
    const msgDate = new Date(timestamp)
    const now = new Date()
    const msgDay = new Date(msgDate.getFullYear(), msgDate.getMonth(), msgDate.getDate()).getTime()
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime()

    if (msgDay === today) {
      return '今天'
    }
    return `${msgDate.getFullYear()}/${msgDate.getMonth() + 1}/${msgDate.getDate()}`
  }

  // 判断是否需要显示日期分隔条
  shouldShowDateLabel(index: number): boolean {
    if (index === 0) {
      return true
    }
    const prev = this.messages[index - 1]
    const curr = this.messages[index]
    return this.formatDateLabel(prev.timestamp) !== this.formatDateLabel(curr.timestamp)
  }

  // ---------- UI ----------

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Button() {
          Image($r('app.media.ic_back'))
            .width(22)
            .height(22)
            .fillColor('#FFFFFF')
        }
        .width(32)
        .height(32)
        .backgroundColor('rgba(255,255,255,0.18)')
        .borderRadius(16)
        .onClick(() => {
          if (this.stompClient) {
            this.stompClient.disconnect()
            this.stompClient = null
          }
          router.back()
        })

        // 对方头像
        Stack() {
          Circle()
            .width(36)
            .height(36)
            .fill(this.getAvatarColor(this.peerName))
          Text(this.getAvatarChar(this.peerName))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
        }
        .margin({ left: 10 })
        .onClick(() => this.navigateToPeerProfile())

        Column() {
          Text(this.peerName)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Row() {
            Circle()
              .width(6)
              .height(6)
              .fill(this.isConnected ? '#BAF0BC' : '#FFB3B3')
            Text(this.isConnected ? '在线' : this.connectionStatus ? this.connectionStatus : '离线')
              .fontSize(10)
              .fontColor('rgba(255,255,255,0.75)')
              .margin({ left: 4 })
          }
          .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 10 })

        Blank()

        if (this.isRecruiter()) {
          Button() {
            Row() {
              Image($r('sys.symbol.calendar'))
                .width(12)
                .height(12)
                .fillColor('#FFFFFF')
              Text('排期')
                .fontSize(10)
                .fontColor('#FFFFFF')
                .margin({ left: 2 })
            }
          }
          .height(26)
          .fontSize(10)
          .backgroundColor('rgba(255,255,255,0.22)')
          .borderRadius(13)
          .padding({ left: 8, right: 8 })
          .margin({ right: 8 })
          .onClick(() => this.goToInterviewSchedule())
        }

        if (this.isAIAgentSession) {
          Text('AI')
            .fontSize(10)
            .fontColor('#FFFFFF')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('rgba(255,107,53,0.35)')
            .borderRadius(10)
        }
      }
      .width('100%')
      .padding({ left: 12, right: 16, top: 26, bottom: 10 })
      .linearGradient({
        angle: 135,
        colors: [[this.getHeaderGradient()[0], 0], [this.getHeaderGradient()[1], 1]]
      })

      if (this.isAIAgentSession) {
        Row() {
          Text('AI 数字分身已开启，离线时自动代聊')
            .fontSize(10)
            .fontColor(AppConstants.COLOR_ACCENT)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 5, bottom: 5 })
        .backgroundColor('rgba(255,107,53,0.06)')
      }

      // 消息列表
      List({ scroller: this.scroller }) {
        ForEach(this.messages, (message: ChatMessage, index: number) => {
          ListItem() {
            Column() {
              if (this.shouldShowDateLabel(index)) {
                this.DateDivider(this.formatDateLabel(message.timestamp))
              }
              this.MessageItem(message)
            }
            .width('100%')
          }
        }, (message: ChatMessage) => message.messageId)
      }
      .layoutWeight(1)
      .width('100%')
      .padding({ left: 12, right: 12, top: 8 })
      .backgroundColor('#EEF1F5')

      // 更多功能面板（微信风格：键盘区高度，无遮罩）
      if (this.showMorePanel) {
        Column() {
          // 快捷回复行（HR端）- 水平列表
          if (this.isRecruiter()) {
            List({ space: 8 }) {
              ForEach(this.getQuickReplies(), (text: string) => {
                ListItem() {
                  Text(text)
                    .fontSize(12)
                    .fontColor(AppConstants.COLOR_ACCENT)
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .backgroundColor('#FFFFFF')
                    .borderRadius(4)
                    .onClick(() => {
                      this.showMorePanel = false
                      this.sendQuickReply(text)
                    })
                }
              })
            }
            .listDirection(Axis.Horizontal)
            .width('100%')
            .height(40)
            .padding({ left: 16, right: 16 })
            .backgroundColor('#F7F8FA')
            .scrollBar(BarState.Off)
          }

          // 功能图标网格（2行 x 4列）
          Grid() {
            GridItem() { this.WxPanelItem('🖼️', '图片') }
            GridItem() { this.WxPanelItem('📷', '拍摄') }
            GridItem() { this.WxPanelItem('📁', '文件') }
            GridItem() { this.WxPanelItem('📍', '位置') }
            if (this.isRecruiter()) {
              GridItem() { this.WxPanelItem('📅', '排期') }
              GridItem() { this.WxPanelItem('📋', '简历') }
            } else {
              GridItem() { this.WxPanelItem('📋', '简历') }
              GridItem() { this.WxPanelItem('🎤', '语音') }
            }
          }
          .columnsTemplate('1fr 1fr 1fr 1fr')
          .rowsTemplate('1fr 1fr')
          .rowsGap(12)
          .width('100%')
          .height(200)
          .padding({ left: 4, right: 4, top: 16, bottom: 8 })
          .backgroundColor('#F7F8FA')
        }
        .width('100%')
        .backgroundColor('#F7F8FA')
        .border({ width: { top: 0.5 }, color: '#DDDDDD' })
      }

      // 底部输入栏
      Row() {
        // + 号按钮
        Button() {
          Image($r('sys.symbol.plus'))
            .width(22)
            .height(22)
            .fillColor(this.isStudent() ? AppConstants.COLOR_PRIMARY : AppConstants.COLOR_ACCENT)
        }
        .width(36)
        .height(36)
        .backgroundColor('#F5F5F5')
        .borderRadius(18)
        .onClick(() => { this.showMorePanel = !this.showMorePanel })

        TextInput({ placeholder: '输入消息...', text: this.inputText })
          .layoutWeight(1)
          .height(40)
          .fontSize(14)
          .backgroundColor('#F5F5F5')
          .borderRadius(20)
          .padding({ left: 16, right: 16 })
          .margin({ left: 8 })
          .onChange((value: string) => { this.inputText = value })
          .onSubmit(() => this.sendMessage())

        Button() {
          Image($r('sys.symbol.paperplane_fill'))
            .width(18)
            .height(18)
            .fillColor('#FFFFFF')
        }
        .width(40)
        .height(40)
        .backgroundColor(this.inputText.trim() ? (this.isStudent() ? AppConstants.COLOR_PRIMARY : AppConstants.COLOR_ACCENT) : '#CCCCCC')
        .borderRadius(20)
        .margin({ left: 8 })
        .enabled(!!this.inputText.trim())
        .onClick(() => this.sendMessage())
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 10 })
      .backgroundColor('#FFFFFF')
      .border({ width: { top: 0.5 }, color: '#E8E8E8' })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#EEF1F5')
  }

  @Builder
  WxPanelItem(emoji: string, label: string) {
    Column() {
      Stack() {
        Circle()
          .width(48)
          .height(48)
          .fill('#FFFFFF')
        Text(emoji)
          .fontSize(24)
      }
      Text(label)
        .fontSize(11)
        .fontColor('#888888')
        .margin({ top: 6 })
    }
    .alignItems(HorizontalAlign.Center)
    .onClick(() => this.handlePanelAction(label))
  }

  handlePanelAction(label: string): void {
    this.showMorePanel = false
    if (label === '快捷回复') return
    if (label === '面试排期') { this.goToInterviewSchedule(); return }
    if (label === '查看简历') {
      router.pushUrl({ url: AppConstants.ROUTE_TALENT_DETAIL, params: { userId: this.peerId } })
      return
    }
    if (label === '我的简历') return
    // 图片、拍摄、文件、位置等
    AlertDialog.show({ title: '提示', message: `「${label}」功能即将上线` })
  }

  @Builder
  DateDivider(label: string) {
    Row() {
      Text(label)
        .fontSize(11)
        .fontColor('#999999')
        .padding({ left: 12, right: 12, top: 3, bottom: 3 })
        .backgroundColor('rgba(0,0,0,0.04)')
        .borderRadius(10)
    }
    .width('100%')
    .justifyContent(FlexAlign.Center)
    .margin({ top: 10, bottom: 10 })
  }

  @Builder
  MessageItem(message: ChatMessage) {
    Row() {
      if (this.isOwnMessage(message)) {
        // 自己发的消息 — 右侧
        Blank()
        Column() {
          if (message.isAIAgentReply) {
            Text('AI')
              .fontSize(8)
              .fontColor(AppConstants.COLOR_ACCENT)
              .padding({ left: 5, right: 5, top: 1, bottom: 1 })
              .backgroundColor('rgba(255,107,53,0.12)')
              .borderRadius(4)
              .margin({ bottom: 3 })
          }
          Text(message.content)
            .fontSize(14)
            .fontColor(this.getBubbleTextColor(message.isAIAgentReply))
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .backgroundColor(this.getBubbleColor(message.isAIAgentReply))
            .borderRadius({ topLeft: 18, topRight: 4, bottomLeft: 18, bottomRight: 18 })
            .constraintSize({ maxWidth: '72%' })
        }
        .alignItems(HorizontalAlign.End)
        Stack() {
          Circle()
            .width(34)
            .height(34)
            .fill(this.getAvatarColor(this.getSelfAvatarChar()))
          Text(this.getSelfAvatarChar())
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
        }
        .margin({ left: 8 })
      } else {
        // 对方发的消息 — 左侧
        // 头像
        Stack() {
          Circle()
            .width(34)
            .height(34)
            .fill(this.getAvatarColor(this.peerName))
          Text(this.getAvatarChar(this.peerName))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
        }
        .onClick(() => this.navigateToPeerProfile())

        Column() {
          if (message.isAIAgentReply) {
            Text('AI 数字分身')
              .fontSize(8)
              .fontColor(AppConstants.COLOR_ACCENT)
              .padding({ left: 5, right: 5, top: 1, bottom: 1 })
              .backgroundColor('rgba(255,107,53,0.12)')
              .borderRadius(4)
              .margin({ bottom: 3 })
          }
          Text(message.content)
            .fontSize(14)
            .fontColor(message.isAIAgentReply ? AppConstants.COLOR_ACCENT : '#1A1A1A')
            .padding({ left: 14, right: 14, top: 10, bottom: 10 })
            .backgroundColor(message.isAIAgentReply ? 'rgba(255,107,53,0.06)' : '#FFFFFF')
            .borderRadius({ topLeft: 4, topRight: 18, bottomLeft: 18, bottomRight: 18 })
            .constraintSize({ maxWidth: '72%' })
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 8 })

        Blank()
      }
    }
    .width('100%')
    .margin({ bottom: 6 })

    // 时间戳
    Row() {
      Text(this.formatTime(message.timestamp))
        .fontSize(10)
        .fontColor('#C0C4CC')
      if (message.isRead && this.isOwnMessage(message)) {
        Text(' ✓✓')
          .fontSize(10)
          .fontColor('#52C41A')
      }
    }
    .width('100%')
    .justifyContent(this.isOwnMessage(message) ? FlexAlign.End : FlexAlign.Start)
    .padding(this.isOwnMessage(message) ? { right: 46 } : { left: 46 })
    .margin({ top: 2, bottom: 10 })
  }
}

export { ChatPage }
