// 学生端 - AI虚拟面试中心（统一入口）
import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { DatabaseHelper } from '../../database/DatabaseHelper'
import { TABLE_AI_INTERVIEW, TABLE_USER, TABLE_JOB, TABLE_SYSTEM_MESSAGE } from '../../database/Tables'

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
        sessionId: this.pendingInterviewId,
        jobTitle: this.pendingJobTitle
      }
    })
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
        Scroll() {
          Column() {
            // 待参加的面试
            if (this.activeList.length > 0) {
              Column() {
                Text('待参加')
                  .fontSize(13).fontWeight(FontWeight.Medium).fontColor('#9B59B6')
                  .margin({ bottom: 8 }).alignSelf(ItemAlign.Start)
              }
              .width('100%').padding({ left: 14, right: 14, top: 8 })

              ForEach(this.activeList, (item: InterviewItem) => {
                Column() {
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
                .width('100%').backgroundColor('#FFFFFF').borderRadius(12)
                .margin({ left: 14, right: 14, bottom: 8 })
                .onClick(() => this.handleInterviewClick(item))
              })
            }

            // 已完成的面试
            if (this.doneList.length > 0) {
              Column() {
                Text('已完成')
                  .fontSize(13).fontWeight(FontWeight.Medium).fontColor('#999999')
                  .margin({ top: 8, bottom: 8 }).alignSelf(ItemAlign.Start)
              }
              .width('100%').padding({ left: 14, right: 14 })

              ForEach(this.doneList, (item: InterviewItem) => {
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
                .backgroundColor('#FAFAFA').borderRadius(10)
                .margin({ left: 14, right: 14, bottom: 6 })
              })
            }
          }
          .width('100%').justifyContent(FlexAlign.Start).alignSelf(ItemAlign.Start).padding({ bottom: 24 })
        }
        .width('100%').layoutWeight(1).align(Alignment.TopStart)
        .backgroundColor('#F4F6FB').scrollBar(BarState.Off)
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
              this.RuleItem('1', '准备环境', '找一个安静、光线充足的地方，确保网络稳定。')
              this.RuleItem('2', '逐题录制', '每题单独录音作答，最长3分钟，想好再开始。')
              this.RuleItem('3', '自由安排', '无需预约时间，所有题目可自由安排录制顺序。')
              this.RuleItem('4', '评估维度', 'AI将从表达逻辑、抗压能力、技术真实度、团队协作、学习潜力五个维度综合评估。')
              this.RuleItem('5', '提交评估', '全部题目录制完毕后，点击提交按钮。HR将收到你的面试录音和评估报告。')
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
