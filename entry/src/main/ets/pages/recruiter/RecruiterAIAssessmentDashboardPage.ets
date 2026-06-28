// 招聘者 - AI虚拟人多模态人才画像白皮书（评估大屏）
import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { InterviewApiService, InterviewReport, AnswerWithFeedback } from '../../service/InterviewApiService'
import { DatabaseHelper } from '../../database/DatabaseHelper'
import { TABLE_AI_INTERVIEW, TABLE_APPLICATION } from '../../database/Tables'
import { AIAssessmentResult, AIAssessmentDimension, AIInterviewAnswer } from '../../service/RecruiterAIService'
import { MessageDao } from '../../service/MessageDao'
import { buildConversationId } from '../../model/MessageModel'

@Entry
@Component
export struct RecruiterAIAssessmentDashboardPage {
  @State loading: boolean = true
  @State report: InterviewReport | null = null
  @State expandedQuesIndex: number = -1
  @State studentName: string = ''
  @State jobTitle: string = ''
  @State isHiring: boolean = false
  @State submissionStatus: string = ''
  @State isRejecting: boolean = false
  @State isContinuing: boolean = false
  private sessionId: string = ''
  private applicationId: string = ''
  private userId: string = ''
  private messageDao: MessageDao = new MessageDao()

  async aboutToAppear(): Promise<void> {
    const params = router.getParams() as Record<string, Object>
    this.sessionId = (params['sessionId'] as string) || (params['interviewId'] as string) || ''
    this.studentName = (params['studentName'] as string) || ''
    this.jobTitle = (params['jobTitle'] as string) || ''
    this.applicationId = (params['applicationId'] as string) || ''
    this.userId = (params['userId'] as string) || ''

    if (this.sessionId) {
      await this.loadReport()
    } else {
      this.loading = false
    }
  }

  async loadReport(): Promise<void> {
    this.loading = true
    try {
      this.report = await InterviewApiService.getReport(this.sessionId)
      this.submissionStatus = 'completed'
      // 后端API成功时也查DB补齐userId和applicationId
      await this.fillIdsFromDb()
    } catch (_e) {
      await this.loadFromLocalDb()
    } finally {
      this.loading = false
    }
  }

  async fillIdsFromDb(): Promise<void> {
    if (this.userId && this.applicationId) return
    try {
      const store = await DatabaseHelper.getInstance().getStore()

      // 策略1: 从 tb_ai_interview 按 interview_id 查
      const rs = await store.querySql(
        `SELECT user_id, application_id, job_id FROM ${TABLE_AI_INTERVIEW} WHERE interview_id = '${this.sessionId}'`
      )
      if (rs.goToFirstRow()) {
        if (!this.userId) {
          this.userId = rs.getString(rs.getColumnIndex('user_id')) || ''
        }
        if (!this.applicationId) {
          this.applicationId = rs.getString(rs.getColumnIndex('application_id')) || ''
        }
        // 策略2: 有 userId 但没有 applicationId，从 tb_application 反查
        if (!this.applicationId && this.userId) {
          const jobId = rs.getString(rs.getColumnIndex('job_id')) || ''
          if (jobId) {
            try {
              const appRs = await store.querySql(
                `SELECT application_id FROM ${TABLE_APPLICATION} WHERE user_id = '${this.userId}' AND job_id = '${jobId}' LIMIT 1`
              )
              if (appRs.goToFirstRow()) {
                this.applicationId = appRs.getString(appRs.getColumnIndex('application_id')) || ''
              }
              appRs.close()
            } catch (_e2) { /* ignore */ }
          }
        }
      }
      rs.close()

      // 策略3: 仍缺 userId，尝试通过 studentName 从 tb_user 查
      if (!this.userId && this.studentName) {
        try {
          const userRs = await store.querySql(
            `SELECT user_id FROM tb_user WHERE real_name = '${this.studentName}' LIMIT 1`
          )
          if (userRs.goToFirstRow()) {
            this.userId = userRs.getString(userRs.getColumnIndex('user_id')) || ''
          }
          userRs.close()
        } catch (_e2) { /* ignore */ }
      }
    } catch (_e) {
      // ignore
    }
  }

  async loadFromLocalDb(): Promise<void> {
    try {
      const store = await DatabaseHelper.getInstance().getStore()
      const rs = await store.querySql(
        `SELECT user_id, application_id, status, questions, answers, assessment_result, total_score, complete_time
         FROM ${TABLE_AI_INTERVIEW} WHERE interview_id = '${this.sessionId}'`
      )
      if (rs.goToFirstRow()) {
        if (!this.userId) {
          this.userId = rs.getString(rs.getColumnIndex('user_id')) || ''
        }
        if (!this.applicationId) {
          this.applicationId = rs.getString(rs.getColumnIndex('application_id')) || ''
        }
        const dbStatus = rs.getString(rs.getColumnIndex('status'))
        this.submissionStatus = dbStatus
        if (dbStatus === 'completed' || dbStatus === 'submitted') {
          const raw = rs.getString(rs.getColumnIndex('assessment_result'))
          if (raw && raw.length > 0) {
            try {
              const parsed = JSON.parse(raw) as Object
              // 尝试转为InterviewReport格式（兼容AIAssessmentResult和InterviewReport两种格式）
              this.report = this.normalizeToReport(parsed)
            } catch (_e2) { /* ignore */ }
          }
          // 如果有answers但没有report，尝试从answers构建反馈
          if (this.report && (!this.report.answers || this.report.answers.length === 0)) {
            const answersRaw = rs.getString(rs.getColumnIndex('answers'))
            if (answersRaw && answersRaw.length > 0) {
              try {
                const answers = JSON.parse(answersRaw) as AIInterviewAnswer[]
                const parsed = JSON.parse(raw) as AIAssessmentResult
                this.report.answers = this.buildAnswersFeedback(answers, parsed)
              } catch (_e2) { /* ignore */ }
            }
          }
        }
      }
      rs.close()
    } catch (_e2) {
      this.report = null
    }
  }

  // 将AIAssessmentResult格式转为InterviewReport格式
  normalizeToReport(parsed: Object): InterviewReport {
    // 已经是InterviewReport格式（后端API返回的）
    if ((parsed as Record<string, Object>)['radar'] !== undefined) {
      return parsed as InterviewReport
    }
    // AIAssessmentResult格式（DeepSeek AI生成的），需要转换
    const ai = parsed as AIAssessmentResult
    return {
      sessionId: 0,
      position: '',
      totalScore: ai.totalScore || 0,
      summary: ai.summary || '',
      radar: {
        dimensions: (ai.dimensions || []).map((d: AIAssessmentDimension) => d.label),
        scores: (ai.dimensions || []).map((d: AIAssessmentDimension) => d.value),
        fullMarks: (ai.dimensions || []).map((d: AIAssessmentDimension) => d.max)
      },
      answers: []
    }
  }

  // 从AIInterviewAnswer[]和AIAssessmentResult构建AnswerWithFeedback[]
  buildAnswersFeedback(answers: AIInterviewAnswer[], assessment: AIAssessmentResult): AnswerWithFeedback[] {
    const dimMap: Record<string, AIAssessmentDimension> = {}
    for (const d of (assessment.dimensions || [])) {
      dimMap[d.label] = d
    }
    return answers.map((a: AIInterviewAnswer, idx: number) => {
      // 用维度标签尝试匹配comment作为反馈
      let feedback = ''
      let contentScore = 70
      const dimLabels: string[] = Object.keys(dimMap)
      if (idx < dimLabels.length && dimMap[dimLabels[idx]]) {
        const dim = dimMap[dimLabels[idx]]
        feedback = dim.comment || ''
        contentScore = dim.value || 70
      }
      return {
        questionId: a.round,
        questionText: a.question,
        contentScore: contentScore,
        feedback: feedback
      } as AnswerWithFeedback
    })
  }

  async handleHire(): Promise<void> {
    if (this.isHiring) return
    await this.fillIdsFromDb()
    if (!this.userId) {
      AlertDialog.show({ title: '操作失败', message: '无法识别该学生，请返回重试。' })
      return
    }
    AlertDialog.show({
      title: '确认录用',
      message: `确定要录用「${this.studentName}」吗？`,
      primaryButton: {
        value: '确认录用',
        action: async () => {
          this.isHiring = true
          try {
            const store = await DatabaseHelper.getInstance().getStore()
            if (this.applicationId) {
              await store.executeSql(
                `UPDATE ${TABLE_APPLICATION} SET status = 'offered' WHERE application_id = '${this.applicationId}'`
              )
            }
            await store.executeSql(
              `UPDATE ${TABLE_AI_INTERVIEW} SET status = 'reviewed' WHERE interview_id = '${this.sessionId}'`
            )
            const msg = `恭喜！你已被「${AppState.currentUser?.companyName || '企业'}」录用，岗位：${this.jobTitle || '详见详情'}。请留意后续入职安排。`
            await this.messageDao.insertSystemMessage(this.userId, '录用通知', msg, 'system')
            await this.sendChatMessage(this.userId, msg)
            AppStorage.setOrCreate('assessment_refresh', Date.now())
            AlertDialog.show({ title: '录用成功', message: `已向 ${this.studentName} 发送录用通知。` })
            setTimeout(() => router.back(), 800)
          } catch (_e) {
            AlertDialog.show({ title: '操作失败', message: '录用操作失败，请稍后重试。' })
          } finally {
            this.isHiring = false
          }
        }
      },
      secondaryButton: { value: '取消', action: () => {} }
    })
  }

  async handleContinue(): Promise<void> {
    if (this.isContinuing) return
    await this.fillIdsFromDb()
    if (!this.userId) {
      AlertDialog.show({ title: '操作失败', message: '缺少必要信息，请返回重试。' })
      return
    }
    AlertDialog.show({
      title: '继续沟通',
      message: `确定通知「${this.studentName}」一面通过，继续约下一轮吗？`,
      primaryButton: {
        value: '确认发送',
        action: async () => {
          this.isContinuing = true
          try {
            const companyName = AppState.currentUser?.companyName || '企业'
            const msg = `恭喜！你在「${companyName}」的AI虚拟人一面已通过，HR将与你进一步沟通后续安排，请保持联系。`
            await this.messageDao.insertSystemMessage(this.userId, '一面通过通知', msg, 'interview')
            // 同时发送聊天消息，确保学生在消息列表可见
            await this.sendChatMessage(this.userId, msg)
            const store = await DatabaseHelper.getInstance().getStore()
            if (this.applicationId) {
              await store.executeSql(
                `UPDATE ${TABLE_APPLICATION} SET status = 'interview_passed' WHERE application_id = '${this.applicationId}'`
              )
            }
            await store.executeSql(
              `UPDATE ${TABLE_AI_INTERVIEW} SET status = 'reviewed' WHERE interview_id = '${this.sessionId}'`
            )
            AppStorage.setOrCreate('assessment_refresh', Date.now())
            AlertDialog.show({ title: '已发送', message: `已通知 ${this.studentName} 一面通过。` })
            setTimeout(() => router.back(), 800)
          } catch (_e) {
            AlertDialog.show({ title: '操作失败', message: '发送通知失败，请稍后重试。' })
          } finally {
            this.isContinuing = false
          }
        }
      },
      secondaryButton: { value: '取消', action: () => {} }
    })
  }

  async handleReject(): Promise<void> {
    if (this.isRejecting) return
    await this.fillIdsFromDb()
    if (!this.userId) {
      AlertDialog.show({ title: '操作失败', message: '无法识别该学生，请返回重试。' })
      return
    }
    AlertDialog.show({
      title: '确认不录用',
      message: `确定不录用「${this.studentName}」吗？此操作不可撤销。`,
      primaryButton: {
        value: '确认不录用',
        action: async () => {
          this.isRejecting = true
          try {
            const store = await DatabaseHelper.getInstance().getStore()
            if (this.applicationId) {
              await store.executeSql(
                `UPDATE ${TABLE_APPLICATION} SET status = 'rejected', rejection_reason = 'AI评估未达录用标准' WHERE application_id = '${this.applicationId}'`
              )
            }
            await store.executeSql(
              `UPDATE ${TABLE_AI_INTERVIEW} SET status = 'reviewed' WHERE interview_id = '${this.sessionId}'`
            )
            const msg = `感谢你参与「${AppState.currentUser?.companyName || '企业'}」的AI面试，很遗憾本次未能通过，祝你早日找到合适的工作。`
            await this.messageDao.insertSystemMessage(this.userId, '面试结果通知', msg, 'system')
            await this.sendChatMessage(this.userId, msg)
            AppStorage.setOrCreate('assessment_refresh', Date.now())
            AlertDialog.show({ title: '操作完成', message: `已将 ${this.studentName} 标记为不录用。` })
            setTimeout(() => router.back(), 800)
          } catch (_e) {
            AlertDialog.show({ title: '操作失败', message: '操作失败，请稍后重试。' })
          } finally {
            this.isRejecting = false
          }
        }
      },
      secondaryButton: { value: '取消', action: () => {} }
    })
  }

  async sendChatMessage(toUserId: string, content: string): Promise<void> {
    if (!AppState.currentUser || !toUserId) return
    const hrId = AppState.currentUser.userId
    const conversationId = buildConversationId(hrId, toUserId)
    await this.messageDao.ensureConversation(conversationId, toUserId, this.studentName || '学生')
    const msgId = `msg_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`
    await this.messageDao.insertMessage({
      messageId: msgId,
      sessionId: conversationId,
      senderId: hrId,
      receiverId: toUserId,
      content: content,
      timestamp: Date.now(),
      isAIAgentReply: false,
      messageType: 'text',
      isRead: false
    })
  }

  getScoreColor(score: number): string {
    if (score >= 80) return '#52C41A'
    if (score >= 60) return '#FAAD14'
    return '#FF4D4F'
  }

  getScoreBg(score: number): string {
    if (score >= 80) return '#F0FFF0'
    if (score >= 60) return '#FFFBE6'
    return '#FFF1F0'
  }

  getRecLabel(totalScore: number): string {
    if (totalScore >= 80) return '建议录用'
    if (totalScore >= 60) return '可考虑'
    return '不建议'
  }

  getRecBadgeColor(totalScore: number): string {
    if (totalScore >= 80) return '#52C41A'
    if (totalScore >= 60) return '#FAAD14'
    return '#FF4D4F'
  }

  build(): void {
    Column() {
      // 顶部导航
      Row() {
        Button() { Image($r('app.media.ic_back')).width(22).height(22).fillColor('#4A90D9') }
          .backgroundColor(Color.Transparent).padding(0)
          .onClick(() => router.back())
        Blank()
        Text('人才画像白皮书')
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
          LoadingProgress().width(32).height(32).color('#4A90D9')
          Text('加载评估报告...').fontSize(13).fontColor('#999999').margin({ top: 12 })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (!this.report && this.submissionStatus !== 'submitted') {
        Column() {
          Text('📭').fontSize(48).margin({ bottom: 12 })
          Text('评估数据加载失败').fontSize(14).fontColor('#999999')
          Button('重试').margin({ top: 16 }).fontSize(13).backgroundColor('#4A90D9').fontColor('#FFFFFF').borderRadius(20).onClick(() => this.loadReport())
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (!this.report && this.submissionStatus === 'submitted') {
        Scroll() {
          Column() {
            // 学生信息
            Row() {
              Text(this.studentName.charAt(0))
                .fontSize(22).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                .width(52).height(52).textAlign(TextAlign.Center)
                .backgroundColor(AppConstants.COLOR_ACCENT).borderRadius(26).margin({ right: 14 })
              Column() {
                Text(this.studentName)
                  .fontSize(17).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
                if (this.jobTitle) {
                  Text('应聘：' + this.jobTitle)
                    .fontSize(12).fontColor('#999999').margin({ top: 2 })
                }
              }
              .alignItems(HorizontalAlign.Start).layoutWeight(1)
            }
            .width('100%').padding(16).backgroundColor('#FFFFFF').borderRadius(14)
            .margin({ top: 12, bottom: 12 })

            Column() {
              Text('📹').fontSize(36).margin({ bottom: 10 })
              Text('面试视频已提交')
                .fontSize(17).fontWeight(FontWeight.Bold).fontColor(AppConstants.COLOR_ACCENT)
              Text('学生已完成录制并提交，等待HR评估')
                .fontSize(12).fontColor('#888888').margin({ top: 6 })
              Text('您可以在此查看学生信息并决定是否直接录用')
                .fontSize(11).fontColor('#CCCCCC').margin({ top: 4 })
            }
            .width('100%').padding(28).backgroundColor('#FFFFFF').borderRadius(14)
            .margin({ bottom: 12 }).alignItems(HorizontalAlign.Center)

            Column() {
              Text('操作').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
                .margin({ bottom: 14 }).alignSelf(ItemAlign.Start)

              Row() {
                Button('继续沟通')
                  .layoutWeight(1).height(42).fontSize(13).fontWeight(FontWeight.Medium)
                  .fontColor('#4A90D9').backgroundColor('#EBF4FF').borderRadius(10)
                  .enabled(!this.isContinuing)
                  .onClick(() => this.handleContinue())

                Button('直接录用')
                  .layoutWeight(1).height(42).fontSize(13).fontWeight(FontWeight.Medium)
                  .fontColor('#FFFFFF').backgroundColor('#FF6B35').borderRadius(10)
                  .enabled(!this.isHiring)
                  .onClick(() => this.handleHire())
                  .margin({ left: 8, right: 8 })

                Button('不录用')
                  .layoutWeight(1).height(42).fontSize(13).fontWeight(FontWeight.Medium)
                  .fontColor('#FF4D4F').backgroundColor('#FFF1F0').borderRadius(10)
                  .enabled(!this.isRejecting)
                  .onClick(() => this.handleReject())
              }
              .width('100%')
            }
            .width('100%').padding(20).backgroundColor('#FFFFFF').borderRadius(14)
            .margin({ bottom: 12 })
          }
          .width('100%').padding({ left: 14, right: 14, bottom: 20 })
        }
        .width('100%').layoutWeight(1).scrollBar(BarState.Off)
      } else {
        Scroll() {
          Column() {
            // 学生信息卡片
            Row() {
              Text(this.studentName.charAt(0))
                .fontSize(22).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                .width(52).height(52).textAlign(TextAlign.Center)
                .backgroundColor('#4A90D9').borderRadius(26).margin({ right: 14 })
              Column() {
                Text(this.studentName)
                  .fontSize(17).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
                if (this.jobTitle) {
                  Text('应聘：' + this.jobTitle)
                    .fontSize(12).fontColor('#999999').margin({ top: 2 })
                }
              }
              .alignItems(HorizontalAlign.Start).layoutWeight(1)
              Column() {
                Text(this.getRecLabel(this.report!.totalScore))
                  .fontSize(11).fontWeight(FontWeight.Bold)
                  .fontColor(this.getRecBadgeColor(this.report!.totalScore))
                  .padding({ left: 10, right: 10, top: 3, bottom: 3 })
                  .backgroundColor(this.getScoreBg(this.report!.totalScore))
                  .borderRadius(10)
              }
            }
            .width('100%').padding(16).backgroundColor('#FFFFFF').borderRadius(14)
            .margin({ top: 12, bottom: 12 })

            // 综合评分 - 英雄卡片
            Column() {
              Text(String(this.report!.totalScore))
                .fontSize(56).fontWeight(FontWeight.Bold)
                .fontColor(this.getScoreColor(this.report!.totalScore))
                .fontFamily('sans-serif-medium')
              Text('综合评分')
                .fontSize(12).fontColor('#999999').margin({ top: 4 })
              Divider().height(1).color('#F0F0F0').width('60%').margin({ top: 14, bottom: 14 })
              Text(this.report!.summary)
                .fontSize(13).fontColor('#555555')
                .lineHeight(20).textAlign(TextAlign.Center)
                .maxLines(4).textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .width('100%').padding({ left: 24, right: 24, top: 28, bottom: 22 })
            .backgroundColor('#FFFFFF').borderRadius(14)
            .margin({ bottom: 12 }).alignItems(HorizontalAlign.Center)

            // 雷达图
            if (this.report!.radar && this.report!.radar.dimensions.length > 0) {
              Column() {
                Row() {
                  Text('能力雷达图')
                    .fontSize(15).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
                  Blank()
                  Text('满分 100')
                    .fontSize(11).fontColor('#CCCCCC')
                }
                .width('100%').margin({ bottom: 10 })

                // 分数一览（文本，始终可见）
                Row() {
                  ForEach(this.report!.radar.dimensions, (dim: string, idx: number) => {
                    Column() {
                      Text(String(this.report!.radar.scores[idx]))
                        .fontSize(24).fontWeight(FontWeight.Bold)
                        .fontColor(this.getScoreColor(this.report!.radar.scores[idx]))
                      Text(dim)
                        .fontSize(11).fontColor('#666666')
                        .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                        .margin({ top: 6 })
                    }
                    .layoutWeight(1).alignItems(HorizontalAlign.Center)
                  })
                }
                .width('100%').margin({ bottom: 14 })

                // Canvas 雷达图
                AssessmentRadarChart({ radar: this.report!.radar })
                  .width('100%').height(270)
              }
              .width('100%').padding(16).backgroundColor('#FFFFFF').borderRadius(14)
              .margin({ bottom: 12 })
            }

            // 维度得分
            if (this.report!.radar && this.report!.radar.dimensions.length > 0) {
              Column() {
                Text('维度得分')
                  .fontSize(15).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
                  .margin({ bottom: 12 }).alignSelf(ItemAlign.Start)

                ForEach(this.report!.radar.dimensions, (dim: string, idx: number) => {
                  Column() {
                    Row() {
                      Text(this.getDimIcon(idx)).fontSize(16).margin({ right: 8 })
                      Text(dim)
                        .fontSize(13).fontWeight(FontWeight.Medium).fontColor('#333333')
                      Blank()
                      Text(`${this.report!.radar.scores[idx]} 分`)
                        .fontSize(15).fontWeight(FontWeight.Bold)
                        .fontColor(this.getScoreColor(this.report!.radar.scores[idx]))
                    }
                    .width('100%').margin({ bottom: 8 })

                    Progress({
                      value: this.report!.radar.scores[idx],
                      total: this.report!.radar.fullMarks[idx],
                      type: ProgressType.Linear
                    })
                      .width('100%').height(6)
                      .color(this.getScoreColor(this.report!.radar.scores[idx]))
                      .backgroundColor('#F0F0F0')
                  }
                  .width('100%')
                  .padding({ left: 14, right: 14, top: 12, bottom: 12 })
                  .margin({ bottom: 6 })
                })
              }
              .width('100%').padding(16).backgroundColor('#FFFFFF').borderRadius(14)
              .margin({ bottom: 12 })
            }

            // 各题反馈
            if (this.report!.answers && this.report!.answers.length > 0) {
              Column() {
                Text('各题反馈')
                  .fontSize(15).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
                  .margin({ bottom: 12 }).alignSelf(ItemAlign.Start)

                ForEach(this.report!.answers, (ans: AnswerWithFeedback, idx: number) => {
                  Column() {
                    Row() {
                      Text(`Q${idx + 1}`)
                        .fontSize(12).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                        .width(24).height(24).textAlign(TextAlign.Center)
                        .backgroundColor('#4A90D9').borderRadius(12)
                        .margin({ right: 10 })
                      Text(ans.questionText)
                        .fontSize(13).fontColor('#1A1A1A').layoutWeight(1)
                        .maxLines(this.expandedQuesIndex === idx ? 100 : 1)
                        .textOverflow({ overflow: TextOverflow.Ellipsis })
                    }
                    .width('100%').margin({ bottom: 8 })

                    Row() {
                      Text(`得分：${ans.contentScore}`)
                        .fontSize(12).fontWeight(FontWeight.Bold)
                        .fontColor(this.getScoreColor(ans.contentScore))
                      Blank()
                      Text(this.expandedQuesIndex === idx ? '收起 ▲' : '展开详情 ▼')
                        .fontSize(11).fontColor('#4A90D9')
                        .onClick(() => {
                          this.expandedQuesIndex = this.expandedQuesIndex === idx ? -1 : idx
                        })
                    }
                    .width('100%')

                    if (this.expandedQuesIndex === idx && ans.feedback) {
                      Text(ans.feedback)
                        .fontSize(12).fontColor('#555555').lineHeight(19)
                        .width('100%').margin({ top: 10 })
                        .padding(12).backgroundColor('#F8FAFF').borderRadius(8)
                    }
                  }
                  .width('100%')
                  .padding({ left: 12, right: 12, top: 14, bottom: 14 })
                  .backgroundColor('#FAFAFA').borderRadius(12)
                  .margin({ bottom: 8 })
                })
              }
              .width('100%').padding(16).backgroundColor('#FFFFFF').borderRadius(14)
              .margin({ bottom: 12 })
            }

            // 操作区
            Column() {
              Text('操作').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
                .margin({ bottom: 14 }).alignSelf(ItemAlign.Start)

              Row() {
                Button('继续沟通')
                  .layoutWeight(1).height(42).fontSize(13).fontWeight(FontWeight.Medium)
                  .fontColor('#4A90D9').backgroundColor('#EBF4FF').borderRadius(10)
                  .enabled(!this.isContinuing)
                  .onClick(() => this.handleContinue())

                Button('直接录用')
                  .layoutWeight(1).height(42).fontSize(13).fontWeight(FontWeight.Medium)
                  .fontColor('#FFFFFF').backgroundColor('#FF6B35').borderRadius(10)
                  .enabled(!this.isHiring)
                  .onClick(() => this.handleHire())
                  .margin({ left: 8, right: 8 })

                Button('不录用')
                  .layoutWeight(1).height(42).fontSize(13).fontWeight(FontWeight.Medium)
                  .fontColor('#FF4D4F').backgroundColor('#FFF1F0').borderRadius(10)
                  .enabled(!this.isRejecting)
                  .onClick(() => this.handleReject())
              }
              .width('100%')
            }
            .width('100%').padding(20).backgroundColor('#FFFFFF').borderRadius(14)
            .margin({ bottom: 24 })
          }
          .width('100%').padding({ left: 14, right: 14 })
        }
        .width('100%').layoutWeight(1).scrollBar(BarState.Off)
      }
    }
    .width('100%').height('100%').backgroundColor('#F4F6FB')
  }

  getDimIcon(idx: number): string {
    const icons: string[] = ['💪', '💬', '🔧', '🤝', '🚀']
    return icons[idx] || '📊'
  }
}

// ===== 雷达图组件 =====

@Component
struct AssessmentRadarChart {
  @Prop radar: import('../../service/InterviewApiService').RadarData | null = null
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)
  @State private canvasW: number = 300
  @State private canvasH: number = 280
  private drawn: boolean = false

  drawChart(): void {
    if (this.drawn) return
    if (!this.radar || this.radar.dimensions.length === 0) return
    if (this.canvasW <= 0 || this.canvasH <= 0) return
    this.drawn = true

    const ctx = this.context
    const w = this.canvasW
    const h = this.canvasH
    const cx = w / 2
    const cy = h / 2
    const maxR = Math.min(w, h) / 2 - 40
    const count = this.radar.dimensions.length
    if (count === 0) return
    const step = (2 * Math.PI) / count

    // 清除画布
    ctx.clearRect(0, 0, w, h)

    // 背景网格环
    for (let ring = 1; ring <= 5; ring++) {
      ctx.beginPath()
      for (let i = 0; i < count; i++) {
        const angle = i * step - Math.PI / 2
        const r = (ring / 5) * maxR
        const x = cx + r * Math.cos(angle)
        const y = cy + r * Math.sin(angle)
        if (i === 0) ctx.moveTo(x, y)
        else ctx.lineTo(x, y)
      }
      ctx.closePath()
      const alpha = 0.04 + ring * 0.04
      ctx.strokeStyle = `rgba(74,144,217,${alpha})`
      ctx.lineWidth = ring === 5 ? 1.2 : 0.5
      ctx.stroke()
    }

    // 轴线和标签
    for (let i = 0; i < count; i++) {
      const angle = i * step - Math.PI / 2
      const ex = cx + maxR * Math.cos(angle)
      const ey = cy + maxR * Math.sin(angle)
      ctx.beginPath()
      ctx.moveTo(cx, cy)
      ctx.lineTo(ex, ey)
      ctx.strokeStyle = 'rgba(74,144,217,0.18)'
      ctx.lineWidth = 0.8
      ctx.stroke()

      // 维度标签
      const lx = cx + (maxR + 28) * Math.cos(angle)
      const ly = cy + (maxR + 28) * Math.sin(angle)
      ctx.fillStyle = '#333333'
      ctx.font = '12px HarmonyOS Sans'
      ctx.textAlign = 'center'
      ctx.textBaseline = 'middle'
      ctx.fillText(this.radar!.dimensions[i], lx, ly)
    }

    // 数据填充区域
    ctx.beginPath()
    for (let i = 0; i < count; i++) {
      const ratio = this.radar!.scores[i] / this.radar!.fullMarks[i]
      const angle = i * step - Math.PI / 2
      const r = ratio * maxR
      const x = cx + r * Math.cos(angle)
      const y = cy + r * Math.sin(angle)
      if (i === 0) ctx.moveTo(x, y)
      else ctx.lineTo(x, y)
    }
    ctx.closePath()
    ctx.fillStyle = 'rgba(74,144,217,0.12)'
    ctx.fill()
    ctx.strokeStyle = '#4A90D9'
    ctx.lineWidth = 2.5
    ctx.stroke()

    // 数据点（分两次绘制，避免 Canvas bug）
    for (let i = 0; i < count; i++) {
      const ratio = this.radar!.scores[i] / this.radar!.fullMarks[i]
      const angle = i * step - Math.PI / 2
      const r = ratio * maxR
      const x = cx + r * Math.cos(angle)
      const y = cy + r * Math.sin(angle)
      ctx.beginPath()
      ctx.arc(x, y, 5, 0, 2 * Math.PI)
      ctx.fillStyle = '#FFFFFF'
      ctx.fill()
      ctx.beginPath()
      ctx.arc(x, y, 5, 0, 2 * Math.PI)
      ctx.strokeStyle = '#4A90D9'
      ctx.lineWidth = 2.5
      ctx.stroke()
    }
  }

  build(): void {
    Canvas(this.context)
      .width('100%')
      .height(280)
      .onAppear(() => {
        // onAppear 作为兜底，防止 onAreaChange 不触发
        setTimeout(() => {
          if (!this.drawn) {
            this.drawChart()
          }
        }, 200)
      })
      .onAreaChange((_oldValue: Area, newValue: Area) => {
        const nw = newValue.width as number
        const nh = newValue.height as number
        if (nw > 0 && nh > 0 && (nw !== this.canvasW || nh !== this.canvasH)) {
          this.canvasW = nw
          this.canvasH = nh
          this.drawn = false
          setTimeout(() => this.drawChart(), 50)
        }
      })
  }
}
