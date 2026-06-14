// 学生端 - AI虚拟人异步一面（对话式AI面试）
import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { RecruiterAIService, AIInterviewQuestion, AIInterviewAnswer, AIAssessmentResult } from '../../service/RecruiterAIService'
import { DatabaseHelper } from '../../database/DatabaseHelper'
import { TABLE_AI_INTERVIEW } from '../../database/Tables'
import { MessageDao } from '../../service/MessageDao'
import { ResumeDao } from '../../service/ResumeDao'

interface ChatBubble {
  role: 'ai' | 'student' | 'system'
  content: string
  round?: number
}

@Entry
@Component
export struct AIInterviewPage {
  @State bubbles: ChatBubble[] = []
  @State inputText: string = ''
  @State currentRound: number = 0
  @State totalRounds: number = 5
  @State status: string = 'intro'
  @State isSubmitting: boolean = false
  @State finalScore: number = 0
  @State companyName: string = ''
  private interviewId: string = ''
  private recruiterId: string = ''
  private jobTitle: string = ''
  private questions: AIInterviewQuestion[] = []
  private answers: AIInterviewAnswer[] = []
  private messageDao: MessageDao = new MessageDao()
  private scroller: Scroller = new Scroller()

  async aboutToAppear(): Promise<void> {
    const params = router.getParams() as Record<string, Object>
    this.interviewId = (params['interviewId'] as string) || ''
    this.jobTitle = (params['jobTitle'] as string) || 'AI面试'
    if (!this.interviewId || !AppState.currentUser) {
      this.status = 'error'
      return
    }
    // 加载基本信息，显示介绍页
    await this.loadBasicInfo()
  }

  async loadBasicInfo(): Promise<void> {
    try {
      const store = await DatabaseHelper.getInstance().getStore()
      const rs = await store.querySql(
        `SELECT ai.status, ai.total_score, ai.recruiter_id, u.company_name
         FROM ${TABLE_AI_INTERVIEW} ai
         LEFT JOIN tb_user u ON ai.recruiter_id = u.user_id
         WHERE ai.interview_id = '${this.interviewId}'`
      )
      if (rs.goToFirstRow()) {
        const dbStatus = rs.getString(rs.getColumnIndex('status'))
        this.recruiterId = rs.getString(rs.getColumnIndex('recruiter_id'))
        this.companyName = rs.getString(rs.getColumnIndex('company_name')) || '企业'
        if (dbStatus === 'completed') {
          this.finalScore = rs.getLong(rs.getColumnIndex('total_score'))
          this.status = 'completed'
          rs.close()
          return
        }
      }
      rs.close()
      this.status = 'intro'
    } catch (_e) {
      this.status = 'intro'
    }
  }

  startInterview(): void {
    this.status = 'loading'
    this.initInterview()
  }

  async initInterview(): Promise<void> {
    try {
      const store = await DatabaseHelper.getInstance().getStore()
      const rs = await store.querySql(
        `SELECT ai.status, ai.questions, ai.recruiter_id, u.company_name
         FROM ${TABLE_AI_INTERVIEW} ai
         LEFT JOIN tb_user u ON ai.recruiter_id = u.user_id
         WHERE ai.interview_id = '${this.interviewId}'`
      )
      if (!rs.goToFirstRow()) {
        this.status = 'error'
        rs.close()
        return
      }
      const dbStatus = rs.getString(rs.getColumnIndex('status'))
      this.recruiterId = rs.getString(rs.getColumnIndex('recruiter_id'))
      this.companyName = rs.getString(rs.getColumnIndex('company_name')) || '企业'
      const existingQuestions = rs.getString(rs.getColumnIndex('questions'))
      rs.close()

      if (dbStatus === 'completed') {
        this.status = 'completed'
        return
      }

      if (existingQuestions && existingQuestions.length > 0) {
        this.questions = JSON.parse(existingQuestions) as AIInterviewQuestion[]
      } else {
        const resumeDao = new ResumeDao()
        const resume = await resumeDao.getResumeByUserId(AppState.currentUser!.userId)
        const resumeText = resume ? `姓名：${resume.realName}，学校：${resume.school}，专业：${resume.major}，技能：${(resume.skills || []).join('、')}，自我介绍：${resume.selfIntro || ''}` : ''
        this.questions = await RecruiterAIService.generateInterviewQuestions(
          resumeText, this.jobTitle, '', []
        )
        if (this.questions.length === 0) {
          this.questions = this.getDefaultQuestions()
        }
        await store.executeSql(
          `UPDATE ${TABLE_AI_INTERVIEW} SET questions = '${JSON.stringify(this.questions).replace(/'/g, "''")}', status = 'in_progress', start_time = ${Date.now()} WHERE interview_id = '${this.interviewId}'`
        )
      }

      this.totalRounds = this.questions.length
      this.status = 'in_progress'

      setTimeout(() => {
        this.bubbles = [{
          role: 'system',
          content: `欢迎参加「${this.companyName}」的「${this.jobTitle}」AI虚拟面试。面试共 ${this.totalRounds} 轮，请放松，就像和真人面试官聊天一样。`
        }, {
          role: 'ai',
          content: this.questions[0].question,
          round: 1
        }]
        this.currentRound = 1
        this.scrollToBottom()
      }, 600)
    } catch (_e) {
      this.status = 'error'
    }
  }

  getDefaultQuestions(): AIInterviewQuestion[] {
    return [
      { round: 1, question: '请简单介绍一下你自己，包括你的专业背景和擅长的技能。', dimension: '表达逻辑', expectedTopics: '专业、技能、优势' },
      { round: 2, question: '请描述一个你做过的最有挑战性的项目或任务，你遇到了什么困难，是如何解决的？', dimension: '抗压能力', expectedTopics: '困难、解决方案、心态' },
      { round: 3, question: '在你简历中提到的技术栈里，你最擅长哪一个？请具体说明你在实际项目中是如何应用的。', dimension: '技术真实度', expectedTopics: '具体技术、实际应用' },
      { round: 4, question: '在团队合作中，你通常扮演什么样的角色？请举一个具体例子。', dimension: '团队协作', expectedTopics: '角色、协作方式、成果' },
      { round: 5, question: '你为什么对这个岗位感兴趣？你觉得你能为公司带来什么价值？', dimension: '学习潜力', expectedTopics: '动机、价值、规划' }
    ]
  }

  sendAnswer(): void {
    const trimmed = this.inputText.trim()
    if (!trimmed || this.currentRound > this.totalRounds || this.status !== 'in_progress') {
      return
    }

    const q = this.questions[this.currentRound - 1]
    const answer: AIInterviewAnswer = { round: q.round, question: q.question, answer: trimmed }
    this.answers.push(answer)

    this.bubbles = this.bubbles.concat([{ role: 'student', content: trimmed }])
    this.inputText = ''

    if (this.currentRound < this.totalRounds) {
      this.currentRound++
      setTimeout(() => {
        this.bubbles = this.bubbles.concat([{
          role: 'ai',
          content: this.questions[this.currentRound - 1].question,
          round: this.currentRound
        }])
        this.scrollToBottom()
      }, 500)
    } else {
      this.status = 'ready_to_submit'
      this.bubbles = this.bubbles.concat([{
        role: 'system',
        content: '所有问题已回答完毕，请点击下方按钮提交评估。'
      }])
    }
    this.scrollToBottom()
  }

  async submitAssessment(): Promise<void> {
    if (this.isSubmitting) return
    this.isSubmitting = true
    try {
      const resumeDao = new ResumeDao()
      const resume = await resumeDao.getResumeByUserId(AppState.currentUser!.userId)
      const resumeText = resume ? `姓名：${resume.realName}，学校：${resume.school}，专业：${resume.major}，技能：${(resume.skills || []).join('、')}，自我介绍：${resume.selfIntro || ''}` : ''

      const result = await RecruiterAIService.evaluateInterviewAnswers(
        this.questions, this.answers, resumeText, this.jobTitle
      )

      this.finalScore = result.totalScore
      this.status = 'completed'

      const store = await DatabaseHelper.getInstance().getStore()
      await store.executeSql(
        `UPDATE ${TABLE_AI_INTERVIEW} SET status = 'completed', answers = '${JSON.stringify(this.answers).replace(/'/g, "''")}', assessment_result = '${JSON.stringify(result).replace(/'/g, "''")}', total_score = ${result.totalScore}, complete_time = ${Date.now()} WHERE interview_id = '${this.interviewId}'`
      )

      await this.messageDao.insertSystemMessage(
        this.recruiterId,
        'AI面试评估完成',
        `${AppState.currentUser?.realName || '学生'}已完成的「${this.jobTitle}」AI虚拟面试评估，总分${result.totalScore}，建议：${result.recommendation}。请前往评估大屏查看详情。`,
        'interview'
      )

      AppStorage.setOrCreate('msg_refresh', Date.now())
      this.bubbles = this.bubbles.concat([{
        role: 'system',
        content: `评估完成！您的总分：${result.totalScore}，建议：${result.recommendation}。HR 将收到评估报告。`
      }])
      this.scrollToBottom()
    } catch (_e) {
      AlertDialog.show({ title: '提交失败', message: '评估提交失败，请稍后重试。' })
    } finally {
      this.isSubmitting = false
    }
  }

  scrollToBottom(): void {
    setTimeout((): void => { this.scroller.scrollEdge(Edge.Bottom) }, 100)
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

  build(): void {
    Column() {
      // 顶部栏
      Row() {
        Button() { Image($r('app.media.ic_back')).width(22).height(22).fillColor('#4A90D9') }
          .backgroundColor(Color.Transparent)
          .padding(0)
          .onClick(() => router.back())
        Blank()
        Column() {
          Text(this.jobTitle)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.status === 'in_progress') {
            Text(`第 ${this.currentRound}/${this.totalRounds} 轮`)
              .fontSize(11)
              .fontColor('#999999')
          }
        }
        .alignItems(HorizontalAlign.Center)
        .layoutWeight(1)
        Blank()
        Row().width(48)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 60, bottom: 14 })
      .backgroundColor('#FFFFFF')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      Divider().height(1).color('#F0F0F0')

      // 进度条
      if (this.status === 'in_progress') {
        Row() {
          Progress({ value: this.currentRound, total: this.totalRounds, type: ProgressType.Linear })
            .width('100%')
            .height(3)
            .color('#9B59B6')
            .backgroundColor('#F0F0F0')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8 })
      }

      if (this.status === 'intro') {
        Column() {
          Column() {
            Text('🤖').fontSize(48).margin({ bottom: 10 })
            Text('AI 虚拟面试').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#1A1A1A').margin({ bottom: 4 })
            if (this.companyName) {
              Text(`来自：${this.companyName}`).fontSize(13).fontColor('#9B59B6')
                .padding({ left: 10, right: 10, top: 2, bottom: 2 })
                .backgroundColor('#F8F4FF').borderRadius(8)
                .margin({ bottom: 4 })
            }
            Text(this.jobTitle).fontSize(14).fontColor('#666666').margin({ bottom: 20 })

            Column() {
              this.RuleItem('1', '找好环境', '确保安静、网络稳定，就像真实的视频面试一样准备。')
              this.RuleItem('2', '对话式作答', 'AI面试官会逐轮提问，每题用文字清晰作答即可，没有时间限制。')
              this.RuleItem('3', '五维评估', 'AI将从表达逻辑、抗压能力、技术真实度、团队协作、学习潜力五个维度评估。')
              this.RuleItem('4', '提交即完成', '全部答完后点击提交，HR将收到你的评估报告。')
            }
            .width('100%').margin({ top: 4, bottom: 20 })

            Button('开始面试')
              .width('75%').height(44).fontSize(16).fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF').backgroundColor('#9B59B6').borderRadius(22)
              .onClick(() => this.startInterview())

            Button('返回').fontSize(13).fontColor('#999999')
              .backgroundColor(Color.Transparent).margin({ top: 10 })
              .onClick(() => router.back())
          }
          .width('85%').padding(28).backgroundColor('#FFFFFF').borderRadius(16)
          .shadow({ radius: 16, color: 'rgba(0,0,0,0.08)' })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
        .backgroundColor('#F4F6FB')
      } else if (this.status === 'loading') {
        Column() {
          LoadingProgress().width(28).height(28).color('#9B59B6')
          Text('准备面试中...').fontSize(13).fontColor('#999999').margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.status === 'error') {
        Column() {
          Text('😕').fontSize(48).margin({ bottom: 12 })
          Text('面试信息加载失败').fontSize(14).fontColor('#999999')
          Button('返回').margin({ top: 16 }).onClick(() => router.back())
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        // 对话区
        Scroll(this.scroller) {
          Column() {
            ForEach(this.bubbles, (bubble: ChatBubble) => {
              Row() {
                if (bubble.role === 'system') {
                  Text(bubble.content)
                    .fontSize(12)
                    .fontColor('#999999')
                    .textAlign(TextAlign.Center)
                    .width('100%')
                    .padding({ top: 10, bottom: 6 })
                } else {
                  if (bubble.role === 'ai') {
                    Column() {
                      Text('🤖 AI面试官')
                        .fontSize(10)
                        .fontColor('#9B59B6')
                        .margin({ bottom: 4 })
                      Text(bubble.content)
                        .fontSize(14)
                        .fontColor('#1A1A1A')
                        .lineHeight(21)
                    }
                    .padding(12)
                    .backgroundColor('#F8F4FF')
                    .borderRadius({ topLeft: 4, topRight: 12, bottomLeft: 12, bottomRight: 12 })
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.Start)
                    Row().width(48)
                  } else {
                    Row().width(48)
                    Column() {
                      Text('👤 我')
                        .fontSize(10)
                        .fontColor('#4A90D9')
                        .margin({ bottom: 4 })
                        .alignSelf(ItemAlign.End)
                      Text(bubble.content)
                        .fontSize(14)
                        .fontColor('#FFFFFF')
                        .lineHeight(21)
                    }
                    .padding(12)
                    .backgroundColor('#4A90D9')
                    .borderRadius({ topLeft: 12, topRight: 4, bottomLeft: 12, bottomRight: 12 })
                    .layoutWeight(1)
                    .alignItems(HorizontalAlign.End)
                  }
                }
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 4, bottom: 4 })
            })
          }
          .width('100%')
          .padding({ top: 8, bottom: 16 })
        }
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('#F4F6FB')
        .scrollBar(BarState.Off)

        // 底部输入区
        Column() {
          if (this.status === 'in_progress') {
            Row() {
              TextInput({ text: this.inputText, placeholder: '输入你的回答...' })
                .fontSize(14)
                .layoutWeight(1)
                .height(42)
                .backgroundColor('#F5F5F5')
                .borderRadius(21)
                .padding({ left: 16, right: 16 })
                .onChange((value: string) => this.inputText = value)
                .onSubmit(() => this.sendAnswer())
              Button('发送')
                .fontSize(13)
                .height(36)
                .backgroundColor(this.inputText.trim() ? '#9B59B6' : '#CCCCCC')
                .fontColor('#FFFFFF')
                .borderRadius(18)
                .padding({ left: 16, right: 16 })
                .margin({ left: 8 })
                .enabled(this.inputText.trim().length > 0)
                .onClick(() => this.sendAnswer())
            }
            .width('100%')
          }

          if (this.status === 'ready_to_submit') {
            Button(this.isSubmitting ? '提交中...' : '📤 提交评估')
              .width('80%')
              .height(44)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
              .backgroundColor('#9B59B6')
              .borderRadius(22)
              .enabled(!this.isSubmitting)
              .onClick(() => this.submitAssessment())
          }

          if (this.status === 'completed') {
            Column() {
              Text('✅ 面试评估已完成')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#52C41A')
                .margin({ bottom: 8 })
              Text(`综合评分：${this.finalScore} 分`)
                .fontSize(13)
                .fontColor('#666666')
              Button('返回')
                .margin({ top: 12 })
                .fontSize(13)
                .backgroundColor('#F5F5F5')
                .fontColor('#666666')
                .borderRadius(16)
                .onClick(() => router.back())
            }
            .width('100%')
            .alignItems(HorizontalAlign.Center)
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 10, bottom: 16 })
        .backgroundColor('#FFFFFF')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
