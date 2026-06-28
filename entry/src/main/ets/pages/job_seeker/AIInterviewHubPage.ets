// 学生端 - AI虚拟面试中心（统一入口）
import { router, promptAction } from '@kit.ArkUI'
import { relationalStore } from '@kit.ArkData'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { DatabaseHelper } from '../../database/DatabaseHelper'
import { TABLE_AI_INTERVIEW, TABLE_USER, TABLE_JOB, TABLE_SYSTEM_MESSAGE } from '../../database/Tables'
import { MessageDao } from '../../service/MessageDao'
import { buildConversationId } from '../../model/MessageModel'

interface InterviewItem {
  interviewId: string
  companyName: string
  jobTitle: string
  status: string
  inviteTime: number
  completeTime: number
  totalScore: number
}

@Entry
@Component
export struct AIInterviewHubPage {
  @State activeList: InterviewItem[] = []
  @State doneList: InterviewItem[] = []
  @State loading: boolean = true
  @State showRules: boolean = false
  private pendingInterviewId: string = ''
  private pendingJobTitle: string = ''
  private messageDao: MessageDao = new MessageDao()

  async aboutToAppear(): Promise<void> {
    await this.loadInterviews()
  }

  async loadInterviews(): Promise<void> {
    if (!AppState.currentUser) return
    this.loading = true
    const seenIds: string[] = []
    const active: InterviewItem[] = []
    const done: InterviewItem[] = []

    try {
      const store = await DatabaseHelper.getInstance().getStore()

      // 来源1: tb_ai_interview
      const rs = await store.querySql(
        `SELECT ai.interview_id, ai.status, ai.invite_time, ai.complete_time, ai.total_score,
                u.company_name, j.title AS job_title
         FROM ${TABLE_AI_INTERVIEW} ai
         LEFT JOIN ${TABLE_USER} u ON ai.recruiter_id = u.user_id
         LEFT JOIN ${TABLE_JOB} j ON ai.job_id = j.job_id
         WHERE ai.user_id = '${AppState.currentUser.userId}'
         ORDER BY ai.invite_time DESC`
      )
      while (rs.goToNextRow()) {
        const id = rs.getString(rs.getColumnIndex('interview_id'))
        if (seenIds.indexOf(id) >= 0) continue
        seenIds.push(id)
        const item: InterviewItem = {
          interviewId: id,
          companyName: rs.getString(rs.getColumnIndex('company_name')) || '企业',
          jobTitle: rs.getString(rs.getColumnIndex('job_title')) || 'AI虚拟面试',
          status: rs.getString(rs.getColumnIndex('status')),
          inviteTime: rs.getLong(rs.getColumnIndex('invite_time')),
          completeTime: rs.getLong(rs.getColumnIndex('complete_time')),
          totalScore: rs.getLong(rs.getColumnIndex('total_score'))
        }
        if (item.status === 'invited' || item.status === 'in_progress') {
          active.push(item)
        } else {
          done.push(item)
        }
      }
      rs.close()

      // 来源2: tb_system_message 中 type='interview' 的消息（兜底）
      try {
        const msgRs = await store.querySql(
          `SELECT content, timestamp FROM ${TABLE_SYSTEM_MESSAGE}
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
              seenIds.push(id)
              const inviteTime = msgRs.getLong(msgRs.getColumnIndex('timestamp'))
              // 尝试从本地DB查补充信息
              let companyName = '企业'
              let jobTitle = 'AI虚拟面试'
              let dbStatus = 'invited'
              try {
                const subRs = await store.querySql(
                  `SELECT ai.status, u.company_name, j.title FROM ${TABLE_AI_INTERVIEW} ai
                   LEFT JOIN ${TABLE_USER} u ON ai.recruiter_id = u.user_id
                   LEFT JOIN ${TABLE_JOB} j ON ai.job_id = j.job_id
                   WHERE ai.interview_id = '${id}'`
                )
                if (subRs.goToFirstRow()) {
                  dbStatus = subRs.getString(subRs.getColumnIndex('status')) || 'invited'
                  companyName = subRs.getString(subRs.getColumnIndex('company_name')) || '企业'
                  const jt = subRs.getString(subRs.getColumnIndex('title'))
                  if (jt) jobTitle = jt
                }
                subRs.close()
              } catch (_e) { /* ignore */ }
              const item: InterviewItem = {
                interviewId: id,
                companyName: companyName,
                jobTitle: jobTitle,
                status: dbStatus,
                inviteTime: inviteTime,
                completeTime: 0,
                totalScore: 0
              }
              if (item.status === 'invited' || item.status === 'in_progress') {
                active.push(item)
              } else {
                done.push(item)
              }
            }
          }
        }
        msgRs.close()
      } catch (_e) { /* ignore */ }
    } catch (_e) {
      // ignore
    }

    this.activeList = active
    this.doneList = done
    this.loading = false
  }

  handleInterviewClick(item: InterviewItem): void {
    this.pendingInterviewId = item.interviewId
    this.pendingJobTitle = item.jobTitle
    // 首次进入显示规则弹窗
    this.showRules = true
  }

  goToInterview(): void {
    this.showRules = false
    router.pushUrl({
      url: AppConstants.ROUTE_AI_INTERVIEW_VIDEO,
      params: {
        interviewId: this.pendingInterviewId,
        jobTitle: this.pendingJobTitle
      }
    })
  }

  async handleReject(item: InterviewItem): Promise<void> {
    const store = await DatabaseHelper.getInstance().getStore()
    await store.executeSql(
      `UPDATE ${TABLE_AI_INTERVIEW} SET status = 'rejected', complete_time = ${Date.now()}
       WHERE interview_id = '${item.interviewId}'`
    )
    this.activeList = this.activeList.filter(a => a.interviewId !== item.interviewId)

    const currentUserId = AppState.currentUser?.userId
    if (currentUserId) {
      try {
        const rs = await store.querySql(
          `SELECT recruiter_id, job_id FROM ${TABLE_AI_INTERVIEW}
           WHERE interview_id = '${item.interviewId}'`
        )
        if (rs.goToFirstRow()) {
          const recruiterId = rs.getString(rs.getColumnIndex('recruiter_id'))
          rs.close()
          if (recruiterId) {
            const userName = AppState.currentUser?.realName || AppState.currentUser?.phone || '学生'
            // 系统消息通知 HR
            const sysBucket: relationalStore.ValuesBucket = {
              message_id: `sys_reject_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`,
              user_id: recruiterId,
              title: '面试被拒绝',
              content: `${userName} 拒绝了您发起的「${item.jobTitle}」AI虚拟面试邀请。`,
              type: 'interview',
              is_read: 0,
              timestamp: Date.now()
            } as relationalStore.ValuesBucket
            await store.insert(TABLE_SYSTEM_MESSAGE, sysBucket)
            // 聊天消息通知 HR
            const conversationId = buildConversationId(currentUserId, recruiterId)
            await this.messageDao.ensureConversation(conversationId, recruiterId, '')
            const chatBucket: relationalStore.ValuesBucket = {
              message_id: `msg_reject_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`,
              session_id: conversationId,
              sender_id: currentUserId,
              receiver_id: recruiterId,
              content: `我已收到您发起的「${item.jobTitle}」AI虚拟面试邀请，经过考虑后决定暂不参加，感谢您的关注。`,
              timestamp: Date.now(),
              is_ai_agent_reply: 0,
              message_type: 'text',
              is_read: 0
            } as relationalStore.ValuesBucket
            await store.insert('tb_chat_message', chatBucket)
            // 更新会话最后消息
            const sessionBucket: relationalStore.ValuesBucket = {
              last_message: chatBucket.content as string,
              last_message_time: chatBucket.timestamp as number
            }
            const predicates = new relationalStore.RdbPredicates('tb_chat_session')
            predicates.equalTo('session_id', conversationId)
            await store.update(sessionBucket, predicates)
          }
        } else {
          rs.close()
        }
      } catch (_e) { /* best effort */ }
    }
    AppStorage.setOrCreate('msg_refresh', Date.now())
    promptAction.showToast({ message: '已拒绝该面试邀请', duration: 2000 })
  }

  getStatusText(status: string): string {
    switch (status) {
      case 'invited': return '待参加'
      case 'in_progress': return '进行中'
      case 'completed': return '已完成'
      case 'submitted': return '已提交'
      case 'reviewed': return '已评估'
      default: return status
    }
  }

  getStatusColor(status: string): string {
    switch (status) {
      case 'invited': return '#FAAD14'
      case 'in_progress': return '#52C41A'
      case 'completed': return '#4A90D9'
      case 'submitted': return '#9B59B6'
      case 'reviewed': return '#999999'
      default: return '#999999'
    }
  }

  getStatusBg(status: string): string {
    switch (status) {
      case 'invited': return '#FFFBE6'
      case 'in_progress': return '#F0FFF0'
      case 'completed': return '#EBF4FF'
      case 'submitted': return '#F8F4FF'
      case 'reviewed': return '#F5F5F5'
      default: return '#F5F5F5'
    }
  }

  formatTime(timestamp: number): string {
    if (!timestamp) return ''
    const date = new Date(timestamp)
    return `${date.getMonth() + 1}/${date.getDate()} ${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
  }

  build(): void {
    Stack() {
      Column() {
        // 顶部导航
        Row() {
        Button() { Image($r('app.media.ic_back')).width(22).height(22).fillColor('#4A90D9') }
          .backgroundColor(Color.Transparent).padding(0)
          .onClick(() => router.back())
        Blank()
        Text('AI虚拟面试')
          .fontSize(17).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
        Blank()
        Row().width(48)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 60, bottom: 12 })
      .backgroundColor('#FFFFFF')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      if (this.loading) {
        Column() {
          LoadingProgress().width(28).height(28).color('#9B59B6')
          Text('加载中...').fontSize(13).fontColor('#999999').margin({ top: 12 })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.activeList.length === 0 && this.doneList.length === 0) {
        Column() {
          Text('📭').fontSize(48).margin({ bottom: 12 })
          Text('暂无AI面试邀请').fontSize(14).fontColor('#999999')
          Text('HR 发起面试邀请后，将在此处显示').fontSize(12).fontColor('#CCCCCC').margin({ top: 4 })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List() {
          // 待参加的面试
          if (this.activeList.length > 0) {
            ListItem() {
              Text('待参加')
                .fontSize(13).fontWeight(FontWeight.Medium).fontColor('#9B59B6')
                .margin({ bottom: 8 })
            }
            .width('100%').padding({ left: 14, right: 14, top: 8 })
            .backgroundColor(Color.Transparent)

            ForEach(this.activeList, (item: InterviewItem) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(item.companyName)
                      .fontSize(11).fontColor('#9B59B6')
                      .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                      .backgroundColor('#F8F4FF').borderRadius(4)
                      .margin({ bottom: 4 })
                    Text(item.jobTitle)
                      .fontSize(15).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
                    Text(`邀请时间：${this.formatTime(item.inviteTime)}`)
                      .fontSize(11).fontColor('#BBBBBB').margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start).layoutWeight(1)

                  Column() {
                    Text(this.getStatusText(item.status))
                      .fontSize(12).fontWeight(FontWeight.Medium)
                      .fontColor(this.getStatusColor(item.status))
                      .padding({ left: 10, right: 10, top: 3, bottom: 3 })
                      .backgroundColor(this.getStatusBg(item.status)).borderRadius(8)
                    Image($r('sys.symbol.chevron_right'))
                      .width(14).height(14).fillColor('#CCCCCC').margin({ top: 6 })
                  }
                }
                .width('100%').padding(14)
              }
              .width('100%')
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .margin({ left: 14, right: 14, bottom: 8 })
              .onClick(() => this.handleInterviewClick(item))
              .swipeAction({
                end: {
                  builder: () => {
                    this.RejectSwipeButton()
                  },
                  onAction: () => {
                    AlertDialog.show({
                      title: '拒绝面试',
                      message: `确定拒绝「${item.companyName}」发起的「${item.jobTitle}」AI虚拟面试邀请吗？`,
                      primaryButton: {
                        value: '确定拒绝',
                        fontColor: '#FF4D4F',
                        action: () => this.handleReject(item)
                      },
                      secondaryButton: { value: '取消', action: () => {} }
                    })
                  }
                }
              })
            })
          }

          // 已完成的面试
          if (this.doneList.length > 0) {
            ListItem() {
              Text('已完成')
                .fontSize(13).fontWeight(FontWeight.Medium).fontColor('#999999')
                .margin({ top: 8, bottom: 8 })
            }
            .width('100%').padding({ left: 14, right: 14 })
            .backgroundColor(Color.Transparent)

            ForEach(this.doneList, (item: InterviewItem) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(item.companyName)
                      .fontSize(11).fontColor('#999999')
                      .margin({ bottom: 2 })
                    Text(item.jobTitle)
                      .fontSize(14).fontColor('#666666')
                  }
                  .alignItems(HorizontalAlign.Start).layoutWeight(1)

                  Column() {
                    Text(this.getStatusText(item.status))
                      .fontSize(11)
                      .fontColor(this.getStatusColor(item.status))
                      .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                      .backgroundColor(this.getStatusBg(item.status)).borderRadius(6)
                    if (item.totalScore > 0) {
                      Text(`${item.totalScore} 分`)
                        .fontSize(24).fontWeight(FontWeight.Bold)
                        .fontColor('#4A90D9').margin({ top: 4 })
                    }
                  }
                  .alignItems(HorizontalAlign.Center)
                }
                .width('100%').padding(14)
              }
              .width('100%')
              .backgroundColor('#FAFAFA')
              .borderRadius(10)
              .margin({ left: 14, right: 14, bottom: 6 })
            })
          }
        }
        .width('100%').layoutWeight(1)
        .backgroundColor('#F4F6FB')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.None)
      }
    }
      .width('100%').height('100%').backgroundColor('#FFFFFF')

      // 规则弹窗
      if (this.showRules) {
        Column() {
          Column() {
            Text('🤖').fontSize(40).margin({ bottom: 8 })
            Text('AI 虚拟面试须知')
              .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
              .margin({ bottom: 12 })

            Column() {
              this.RuleItem('1', '准备环境', '找一个安静、光线充足的地方，整理仪容，确保网络稳定。')
              this.RuleItem('2', '视频录制', '每题先听语音播报题面，然后录制回答，每题最长3分钟。')
              this.RuleItem('3', '后端评估', '录制完成后自动提交到后端，进行语音识别、表情神态分析和多维度评分。')
              this.RuleItem('4', '评估维度', '后端将从表达逻辑、抗压能力、神态表情、语音语调等多维度综合评估。')
              this.RuleItem('5', '查看报告', '全部答完后后端生成评估报告，HR将收到通知。')
            }
            .width('100%').margin({ top: 4, bottom: 16 })

            Button('我知道了，开始面试')
              .width('85%').height(44).fontSize(15).fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF').backgroundColor('#9B59B6').borderRadius(22)
              .onClick(() => this.goToInterview())

            Button('稍后参加')
              .fontSize(13).fontColor('#999999')
              .backgroundColor(Color.Transparent)
              .margin({ top: 10 })
              .onClick(() => { this.showRules = false })
          }
          .width('85%').padding(24).backgroundColor('#FFFFFF').borderRadius(18)
          .shadow({ radius: 20, color: 'rgba(0,0,0,0.15)' })
        }
        .width('100%').height('100%')
        .backgroundColor('rgba(0,0,0,0.5)')
        .justifyContent(FlexAlign.Center)
      }
    }
  }

  @Builder
  RejectSwipeButton() {
    Column() {
      Text('拒绝')
        .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
    }
    .width(72).height('100%')
    .backgroundColor('#FF4D4F')
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .borderRadius(12)
  }

  @Builder
  RuleItem(num: string, title: string, desc: string) {
    Row() {
      Text(num)
        .fontSize(12).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        .width(22).height(22).textAlign(TextAlign.Center)
        .backgroundColor('#9B59B6').borderRadius(11).margin({ right: 10 })
      Column() {
        Text(title).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#333333')
        Text(desc).fontSize(11).fontColor('#888888').lineHeight(16).margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1)
    }
    .width('100%').margin({ bottom: 10 })
  }
}
