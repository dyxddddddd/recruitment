// 学生端 - AI视频面试（前端DeepSeek出题 + 模拟录像 + 后端API提交/评估）
import { router, promptAction } from '@kit.ArkUI'
import { media } from '@kit.MediaKit'
import { fileIo } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'
import { relationalStore } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { RecruiterAIService, AIInterviewQuestion, AIInterviewAnswer, AIAssessmentResult } from '../../service/RecruiterAIService'
import { InterviewApiService, SubmitAnswerRequest } from '../../service/InterviewApiService'
import { DatabaseHelper } from '../../database/DatabaseHelper'
import { TABLE_AI_INTERVIEW } from '../../database/Tables'
import { ResumeDao } from '../../service/ResumeDao'
import { MessageDao } from '../../service/MessageDao'

const RECORD_MAX_SECONDS = 180
const COUNTDOWN_SECONDS = 3

const REQUIRED_PERMISSIONS: Permissions[] = [
  'ohos.permission.MICROPHONE'
]

enum PageState {
  LOADING = 'loading',
  PERMISSION = 'permission',
  INTRO = 'intro',
  QUESTION = 'question',
  COUNTDOWN = 'countdown',
  RECORDING = 'recording',
  SUBMITTING = 'submitting',
  RESULT = 'result',
  COMPLETED = 'completed',
  ERROR = 'error'
}

@Entry
@Component
export struct AIInterviewVideoPage {
  @State pageState: PageState = PageState.LOADING
  @State interviewId: string = ''
  @State jobTitle: string = ''
  @State companyName: string = ''
  @State questions: AIInterviewQuestion[] = []
  @State currentQuestionIndex: number = 0
  @State recordSeconds: number = 0
  @State countdownValue: number = COUNTDOWN_SECONDS
  @State hasStarted: boolean = false
  @State permissionGranted: boolean = false
  @State isSubmitting: boolean = false
  @State asrText: string = ''
  @State questionScores: string = ''
  @State finalScore: number = 0
  @State finalReport: string = ''

  private avRecorder: media.AVRecorder | null = null
  private audioPath: string = ''
  private audioBase64: string = ''
  private recordTimerId: number = -1
  private countdownTimerId: number = -1
  private uiContext: common.UIAbilityContext | null = null
  private messageDao: MessageDao = new MessageDao()
  private recruiterId: string = ''
  private isBackendSession: boolean = false

  async aboutToAppear(): Promise<void> {
    this.uiContext = getContext(this) as common.UIAbilityContext
    const params = router.getParams() as Record<string, Object>
    this.interviewId = (params ? (params['interviewId'] as string) : '') || ''
    this.jobTitle = (params ? (params['jobTitle'] as string) : '') || 'AI虚拟面试'
    await this.checkAndRequestPermissions()
  }

  aboutToDisappear(): void {
    this.clearAllTimers()
    this.releaseRecorder()
  }

  // ===== 权限 =====

  async checkAndRequestPermissions(): Promise<void> {
    if (!this.uiContext) return
    const atManager = abilityAccessCtrl.createAtManager()
    try {
      const result = await atManager.requestPermissionsFromUser(this.uiContext, REQUIRED_PERMISSIONS)
      const allGranted = result.authResults.every(
        (s: abilityAccessCtrl.GrantStatus) => s === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
      )
      if (allGranted) {
        this.permissionGranted = true
        await this.loadInterviewData()
      } else {
        this.pageState = PageState.PERMISSION
      }
    } catch (_e) {
      this.pageState = PageState.PERMISSION
    }
  }

  handleGoToSettings(): void {
    if (!this.uiContext) return
    abilityAccessCtrl.createAtManager().requestPermissionOnSetting(this.uiContext, REQUIRED_PERMISSIONS).then(() => {
      this.checkPermissionsSilent()
    })
  }

  async checkPermissionsSilent(): Promise<void> {
    if (!this.uiContext) return
    const atManager = abilityAccessCtrl.createAtManager()
    try {
      const result = await atManager.requestPermissionsFromUser(this.uiContext, REQUIRED_PERMISSIONS)
      const allGranted = result.authResults.every(
        (s: abilityAccessCtrl.GrantStatus) => s === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
      )
      if (allGranted) {
        this.permissionGranted = true
        await this.loadInterviewData()
      }
    } catch (_e) { /* keep */ }
  }

  // ===== 数据加载 =====

  async loadInterviewData(): Promise<void> {
    this.pageState = PageState.LOADING
    try {
      const store = await DatabaseHelper.getInstance().getStore()
      const rs = await store.querySql(
        `SELECT ai.status, ai.questions, ai.recruiter_id, ai.total_score, u.company_name
         FROM ${TABLE_AI_INTERVIEW} ai
         LEFT JOIN tb_user u ON ai.recruiter_id = u.user_id
         WHERE ai.interview_id = '${this.interviewId}'`
      )
      if (!rs.goToFirstRow()) {
        this.pageState = PageState.ERROR
        rs.close()
        return
      }
      const dbStatus = rs.getString(rs.getColumnIndex('status'))
      this.recruiterId = rs.getString(rs.getColumnIndex('recruiter_id'))
      this.companyName = rs.getString(rs.getColumnIndex('company_name')) || '企业'
      const existingQuestions = rs.getString(rs.getColumnIndex('questions'))
      rs.close()

      this.isBackendSession = this.interviewId.indexOf('ai_local_') !== 0

      if (dbStatus === 'completed') {
        const rs2 = await store.querySql(
          `SELECT total_score, assessment_result FROM ${TABLE_AI_INTERVIEW} WHERE interview_id = '${this.interviewId}'`
        )
        if (rs2.goToFirstRow()) {
          this.finalScore = rs2.getLong(rs2.getColumnIndex('total_score'))
          const report = rs2.getString(rs2.getColumnIndex('assessment_result'))
          if (report) {
            try {
              const parsed = JSON.parse(report) as AIAssessmentResult
              this.finalReport = parsed.recommendation || ''
            } catch (_e) { /* ignore */ }
          }
        }
        rs2.close()
        this.pageState = PageState.COMPLETED
        return
      }

      if (existingQuestions && existingQuestions.length > 0) {
        const parsed = JSON.parse(existingQuestions) as Object[]
        if (parsed.length > 0) {
          this.questions = this.normalizeQuestions(parsed)
        }
      }
      if (this.questions.length === 0) {
        await this.generateQuestions(store)
      }

      this.currentQuestionIndex = 0
      this.pageState = PageState.INTRO
    } catch (_e) {
      this.pageState = PageState.ERROR
    }
  }

  normalizeQuestions(raw: Object[]): AIInterviewQuestion[] {
    return raw.map((item: Object, idx: number): AIInterviewQuestion => {
      const r = item as Record<string, Object>
      return {
        round: (r['round'] as number) ?? (r['questionId'] as number) ?? (idx + 1),
        question: (r['question'] as string) ?? (r['questionText'] as string) ?? '',
        dimension: (r['dimension'] as string) ?? '',
        expectedTopics: (r['expectedTopics'] as string) ?? ''
      }
    })
  }

  async generateQuestions(store: relationalStore.RdbStore): Promise<void> {
    const resumeDao = new ResumeDao()
    const resume = await resumeDao.getResumeByUserId(AppState.currentUser!.userId)
    const resumeText = resume
      ? `姓名：${resume.realName}，学校：${resume.school}，专业：${resume.major}，技能：${(resume.skills || []).join('、')}，自我介绍：${resume.selfIntro || ''}`
      : ''
    try {
      const generated = await RecruiterAIService.generateInterviewQuestions(
        resumeText, this.jobTitle, '', []
      )
      this.questions = this.normalizeQuestions(generated as Object[])
    } catch (_e) { /* DeepSeek 不可用 */ }
    if (this.questions.length === 0) {
      this.questions = this.getDefaultQuestions()
    }
    await store.executeSql(
      `UPDATE ${TABLE_AI_INTERVIEW}
       SET questions = '${JSON.stringify(this.questions).replace(/'/g, "''")}',
           status = 'in_progress', start_time = ${Date.now()}
       WHERE interview_id = '${this.interviewId}'`
    )
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

  // ===== 面试开始 =====

  startInterview(): void {
    this.hasStarted = true
    this.pageState = PageState.QUESTION
  }

  // ===== 录音（模拟录像） =====

  startCountdown(): void {
    this.pageState = PageState.COUNTDOWN
    this.countdownValue = COUNTDOWN_SECONDS
    this.countdownTimerId = setInterval(() => {
      this.countdownValue--
      if (this.countdownValue <= 0) {
        clearInterval(this.countdownTimerId)
        this.countdownTimerId = -1
        this.beginRecording()
      }
    }, 1000)
  }

  async beginRecording(): Promise<void> {
    if (!this.uiContext) return
    this.pageState = PageState.RECORDING
    this.recordSeconds = 0
    this.audioBase64 = ''

    try {
      const fileName = `iv_${Date.now()}.m4a`
      this.audioPath = `${this.uiContext.filesDir}/${fileName}`
      const file = fileIo.openSync(this.audioPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)
      const fileFd = file.fd

      const recorder = await media.createAVRecorder()
      const avConfig: media.AVRecorderConfig = {
        audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC,
        profile: {
          audioBitrate: 96000,
          audioChannels: 1,
          audioCodec: media.CodecMimeType.AUDIO_AAC,
          audioSampleRate: 16000,
          fileFormat: media.ContainerFormatType.CFT_MPEG_4A
        },
        url: `fd://${fileFd}`
      }

      await recorder.prepare(avConfig)
      await recorder.start()
      this.avRecorder = recorder

      this.recordTimerId = setInterval(() => {
        this.recordSeconds++
        if (this.recordSeconds >= RECORD_MAX_SECONDS) {
          this.stopRecordingAndSubmit()
        }
      }, 1000)
    } catch (_e) {
      this.pageState = PageState.QUESTION
      AlertDialog.show({
        title: '录制失败',
        message: '无法启动麦克风，请检查权限后重试。',
        primaryButton: { value: '知道了', action: () => {} }
      })
    }
  }

  stopRecordingAndSubmit(): void {
    clearInterval(this.recordTimerId)
    this.recordTimerId = -1

    if (this.avRecorder) {
      try { this.avRecorder.stop() } catch (_e) { /* ignore */ }
      try { this.avRecorder.release() } catch (_e) { /* ignore */ }
      this.avRecorder = null
    }

    this.submitCurrentAnswer()
  }

  releaseRecorder(): void {
    if (this.avRecorder) {
      try { this.avRecorder.stop() } catch (_e) { /* ignore */ }
      try { this.avRecorder.release() } catch (_e) { /* ignore */ }
      this.avRecorder = null
    }
  }

  readAudioAsBase64(): string {
    try {
      const stat = fileIo.statSync(this.audioPath)
      if (stat.size === 0) return ''
      const buffer = new ArrayBuffer(stat.size)
      const f = fileIo.openSync(this.audioPath, fileIo.OpenMode.READ_ONLY)
      fileIo.readSync(f.fd, buffer)
      fileIo.closeSync(f.fd)
      return new util.Base64Helper().encodeToStringSync(new Uint8Array(buffer))
    } catch (_e) {
      return ''
    }
  }

  // ===== 提交到后端 =====

  async submitCurrentAnswer(): Promise<void> {
    this.pageState = PageState.SUBMITTING
    this.isSubmitting = true
    this.asrText = ''
    this.questionScores = ''

    const q = this.questions[this.currentQuestionIndex]
    this.audioBase64 = this.readAudioAsBase64()

    if (this.isBackendSession && this.audioBase64) {
      const reqBody: SubmitAnswerRequest = {
        sessionId: this.interviewId,
        questionId: q.round,
        questionText: q.question,
        videoBase64: this.audioBase64
      }
      const jsonStr = JSON.stringify(reqBody)
      try {
        hilog.info(0x0000, 'AIInterview', 'submit JSON (first 200): %{public}s', jsonStr.substring(0, 200))
        const result = await InterviewApiService.submitAnswer(reqBody)
        hilog.info(0x0000, 'AIInterview', 'submit SUCCESS asrText=%{public}s', result.asrText || '(empty)')
        this.asrText = result.asrText || ''
        if (result.scores) {
          this.questionScores = `内容:${result.scores.contentScore} 表达:${result.scores.expressionScore} 语音:${result.scores.voiceScore}`
        }
        this.pageState = PageState.RESULT
      } catch (e) {
        const errMsg = (e as Error).message || '未知错误'
        hilog.error(0x0000, 'AIInterview', 'submitAnswer FAILED: %{public}s', errMsg)
        AlertDialog.show({
          title: '提交失败',
          message: `发送的JSON：${jsonStr}\n\n后端返回：${errMsg}`,
          primaryButton: { value: '重试', action: () => {} },
          secondaryButton: { value: '跳过（本地评估）', action: () => {
            this.asrText = '（网络不可用，跳过提交）'
            setTimeout(() => {
              if (this.currentQuestionIndex < this.questions.length - 1) {
                this.moveToNextQuestion()
              } else {
                this.evaluateLocal()
              }
            }, 500)
          }}
        })
        this.pageState = PageState.QUESTION
      }
    } else {
      this.asrText = '（本地面试，未提交到后端）'
      setTimeout(() => {
        if (this.currentQuestionIndex < this.questions.length - 1) {
          this.moveToNextQuestion()
        } else {
          this.evaluateLocal()
        }
      }, 800)
    }
    this.isSubmitting = false
  }

  confirmAndNext(): void {
    if (this.currentQuestionIndex < this.questions.length - 1) {
      this.moveToNextQuestion()
    } else {
      if (this.isBackendSession) {
        this.completeInterview()
      } else {
        this.evaluateLocal()
      }
    }
  }

  moveToNextQuestion(): void {
    this.currentQuestionIndex++
    this.audioPath = ''
    this.audioBase64 = ''
    this.recordSeconds = 0
    this.asrText = ''
    this.questionScores = ''
    this.pageState = PageState.QUESTION
  }

  // ===== 完成后端面试 =====

  async completeInterview(): Promise<void> {
    this.pageState = PageState.SUBMITTING
    this.isSubmitting = true
    try {
      const report = await InterviewApiService.completeInterview(this.interviewId)
      this.finalScore = report.totalScore
      this.finalReport = report.summary || ''

      const store = await DatabaseHelper.getInstance().getStore()
      await store.executeSql(
        `UPDATE ${TABLE_AI_INTERVIEW}
         SET status = 'completed', total_score = ${report.totalScore},
             assessment_result = '${JSON.stringify(report).replace(/'/g, "''")}',
             complete_time = ${Date.now()}
         WHERE interview_id = '${this.interviewId}'`
      )

      this.pageState = PageState.COMPLETED
    } catch (_e) {
      await this.evaluateLocal()
    } finally {
      this.isSubmitting = false
    }
  }

  // ===== 本地 DeepSeek 评估（兜底） =====

  async evaluateLocal(): Promise<void> {
    this.pageState = PageState.SUBMITTING
    this.isSubmitting = true
    try {
      const resumeDao = new ResumeDao()
      const resume = await resumeDao.getResumeByUserId(AppState.currentUser!.userId)
      const resumeText = resume
        ? `姓名：${resume.realName}，学校：${resume.school}，专业：${resume.major}，技能：${(resume.skills || []).join('、')}，自我介绍：${resume.selfIntro || ''}`
        : ''

      const plainAnswers: AIInterviewAnswer[] = this.questions.map((q): AIInterviewAnswer => ({
        round: q.round, question: q.question, answer: this.asrText || ''
      }))

      const result = await RecruiterAIService.evaluateInterviewAnswers(
        this.questions, plainAnswers, resumeText, this.jobTitle
      )

      this.finalScore = result.totalScore
      this.finalReport = result.recommendation || ''

      const store = await DatabaseHelper.getInstance().getStore()
      await store.executeSql(
        `UPDATE ${TABLE_AI_INTERVIEW}
         SET status = 'completed',
             answers = '${JSON.stringify(plainAnswers).replace(/'/g, "''")}',
             assessment_result = '${JSON.stringify(result).replace(/'/g, "''")}',
             total_score = ${result.totalScore}, complete_time = ${Date.now()}
         WHERE interview_id = '${this.interviewId}'`
      )

      if (this.recruiterId) {
        await this.messageDao.insertSystemMessage(
          this.recruiterId,
          'AI视频面试评估完成',
          `${AppState.currentUser?.realName || '学生'}已完成「${this.jobTitle}」AI视频面试评估，总分${result.totalScore}，建议：${result.recommendation}。`,
          'interview'
        )
      }

      AppStorage.setOrCreate('msg_refresh', Date.now())
      this.pageState = PageState.COMPLETED
    } catch (_e) {
      this.pageState = PageState.ERROR
    } finally {
      this.isSubmitting = false
    }
  }

  // ===== 返回 =====

  handleBack(): void {
    if (this.hasStarted && this.pageState !== PageState.COMPLETED) {
      AlertDialog.show({
        title: '退出面试',
        message: '退出将提交已录制的回答并结束面试，确定退出吗？',
        primaryButton: { value: '提交并退出', action: () => {
          if (this.isBackendSession) {
            this.completeInterview()
          } else {
            this.evaluateLocal()
          }
        }},
        secondaryButton: { value: '继续面试', action: () => {} }
      })
      return
    }
    router.back()
  }

  clearAllTimers(): void {
    clearInterval(this.recordTimerId)
    clearInterval(this.countdownTimerId)
    this.recordTimerId = -1
    this.countdownTimerId = -1
  }

  formatTime(seconds: number): string {
    const m = Math.floor(seconds / 60)
    const s = seconds % 60
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`
  }

  get currentQuestion(): AIInterviewQuestion | null {
    return this.questions[this.currentQuestionIndex] || null
  }

  getProgressText(): string {
    return `第 ${this.currentQuestionIndex + 1}/${this.questions.length} 题`
  }

  // ===== UI =====

  build(): void {
    Stack() {
      if (this.pageState === PageState.PERMISSION) {
        this.PermissionView()
      } else if (this.pageState === PageState.LOADING) {
        this.LoadingView()
      } else if (this.pageState === PageState.ERROR) {
        this.ErrorView()
      } else if (this.pageState === PageState.INTRO) {
        this.IntroView()
      } else if (this.pageState === PageState.COMPLETED) {
        this.CompletedView()
      } else {
        this.MainInterviewView()
      }
    }
    .width('100%').height('100%').backgroundColor('#0A0A0A')
  }

  @Builder PermissionView() {
    Column() {
      Text('🎤').fontSize(56).margin({ bottom: 16 })
      Text('需要麦克风权限')
        .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').margin({ bottom: 8 })
      Text('AI视频面试需要访问麦克风\n用于录制面试回答')
        .fontSize(13).fontColor('#AAAAAA').textAlign(TextAlign.Center).lineHeight(20).margin({ bottom: 32 })
      Button('前往设置')
        .width('70%').height(44).fontSize(15).fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF').backgroundColor('#9B59B6').borderRadius(22)
        .onClick(() => this.handleGoToSettings())
      Button('返回')
        .fontSize(13).fontColor('#888888').backgroundColor(Color.Transparent).margin({ top: 12 })
        .onClick(() => router.back())
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor('#0A0A0A')
  }

  @Builder LoadingView() {
    Column() {
      LoadingProgress().width(36).height(36).color('#9B59B6')
      Text('正在准备面试...').fontSize(13).fontColor('#AAAAAA').margin({ top: 16 })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }

  @Builder ErrorView() {
    Column() {
      Text('😕').fontSize(48).margin({ bottom: 12 })
      Text('加载失败').fontSize(14).fontColor('#AAAAAA')
      Text('面试ID: ' + (this.interviewId || '无'))
        .fontSize(11).fontColor('#666666').margin({ top: 6 })
      Button('重试').margin({ top: 16 }).onClick(() => this.loadInterviewData())
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }

  @Builder IntroView() {
    Column() {
      Column() {
        Text('🤖').fontSize(48).margin({ bottom: 10 })
        Text('AI 视频面试').fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').margin({ bottom: 4 })
        if (this.companyName) {
          Text(`来自：${this.companyName}`).fontSize(13).fontColor('#9B59B6')
            .padding({ left: 10, right: 10, top: 2, bottom: 2 })
            .backgroundColor('rgba(155,89,182,0.15)').borderRadius(8)
            .margin({ bottom: 4 })
        }
        Text(this.jobTitle).fontSize(14).fontColor('#AAAAAA').margin({ bottom: 24 })

        Column() {
          this.RuleItem('1', '阅读题目', '仔细阅读每题题面，准备好后开始录制回答。')
          this.RuleItem('2', '视频录制', '每题最长录制3分钟，系统将录制你的语音回答。')
          this.RuleItem('3', '后端评估', '录制完成后提交到后端，进行语音识别和多维度评分。')
          this.RuleItem('4', '提交即完成', '全部答完后后端生成评估报告，HR将收到通知。')
        }
        .width('100%').margin({ top: 4, bottom: 24 })

        Button('开始面试')
          .width('75%').height(44).fontSize(16).fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF').backgroundColor('#9B59B6').borderRadius(22)
          .onClick(() => this.startInterview())

        Button('返回').fontSize(13).fontColor('#888888')
          .backgroundColor(Color.Transparent).margin({ top: 10 })
          .onClick(() => router.back())
      }
      .width('85%').padding(28)
      .backgroundColor('rgba(25,25,35,0.98)').borderRadius(16)
      .border({ width: 1, color: 'rgba(255,255,255,0.06)' })
    }
    .width('100%').height('100%').justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
  }

  @Builder CompletedView() {
    Column() {
      Text('✅').fontSize(56).margin({ bottom: 16 })
      Text('面试已完成')
        .fontSize(20).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').margin({ bottom: 8 })
      Text(`综合评分：${this.finalScore} 分`)
        .fontSize(16).fontColor('#9B59B6').margin({ bottom: 4 })
      if (this.finalReport) {
        Text(this.finalReport)
          .fontSize(13).fontColor('#AAAAAA').maxLines(3)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .margin({ top: 8, left: 20, right: 20 })
      }
      Button('返回')
        .width('60%').height(44).fontSize(15)
        .fontColor('#FFFFFF').backgroundColor('#9B59B6').borderRadius(22).margin({ top: 32 })
        .onClick(() => router.back())
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor('#0A0A0A')
  }

  // ===== 主面试界面 =====

  @Builder MainInterviewView() {
    Column() {
      this.TopBar()
      this.QuestionArea()
      this.RecordArea()
      this.BottomControls()
    }
    .width('100%').height('100%')
  }

  @Builder TopBar() {
    Row() {
      Image($r('sys.symbol.chevron_left'))
        .width(22).height(22).fillColor('#FFFFFF')
        .onClick(() => this.handleBack())

      Blank()

      Column() {
        Text(this.jobTitle)
          .fontSize(14).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
        Text(this.getProgressText()).fontSize(11).fontColor('#9B59B6').margin({ top: 2 })
      }

      Blank()
      Row().width(22).height(22)
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 56, bottom: 10 })
    .backgroundColor('#101010')
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder QuestionArea() {
    Column() {
      Row() {
        Text('🤖').fontSize(16)
        Text('AI 面试官').fontSize(13).fontWeight(FontWeight.Medium).fontColor('#9B59B6').margin({ left: 6 })
        Blank()
      }
      .width('100%').padding({ left: 4, right: 4 })

      Text(this.currentQuestion?.question || '')
        .fontSize(18).fontColor('#FFFFFF').lineHeight(26)
        .width('100%')
        .margin({ top: 14, bottom: 4 })
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 16, bottom: 16 })
    .backgroundColor('rgba(25,25,35,0.98)')
  }

  @Builder RecordArea() {
    Stack() {
      // 模拟摄像头预览区
      Column() {
        if (this.pageState === PageState.RECORDING) {
          // 录制中：红色 REC 指示灯 + 计时器
          Row() {
            Circle({ width: 8, height: 8 }).fill('#FF4D4F')
            Text('REC').fontSize(11).fontColor('#FF4D4F').fontWeight(FontWeight.Bold).margin({ left: 5 })
          }
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor('rgba(255,77,79,0.3)').borderRadius(4)
          .margin({ top: 12, right: 12 })
          .alignSelf(ItemAlign.End)

          Blank()

          Text(this.formatTime(this.recordSeconds))
            .fontSize(32).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
            .fontFamily('monospace').margin({ bottom: 12 })
        } else if (this.pageState === PageState.COUNTDOWN) {
          Text(`${this.countdownValue}`)
            .fontSize(80).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').opacity(0.9)
          Text('即将开始录制').fontSize(14).fontColor('#CCCCCC').margin({ top: 8 })
        } else if (this.pageState === PageState.SUBMITTING) {
          LoadingProgress().width(32).height(32).color('#9B59B6')
          Text('正在提交到后端...').fontSize(13).fontColor('#CCCCCC').margin({ top: 12 })
        } else if (this.pageState === PageState.RESULT) {
          Text('提交成功').fontSize(15).fontWeight(FontWeight.Bold).fontColor('#52C41A').margin({ bottom: 12 })
          if (this.asrText) {
            Text('识别结果：').fontSize(12).fontColor('#888888').margin({ bottom: 4 })
            Text(this.asrText)
              .fontSize(13).fontColor('#CCCCCC').maxLines(4)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .margin({ bottom: 8, left: 16, right: 16 })
          }
          if (this.questionScores) {
            Text(this.questionScores).fontSize(12).fontColor('#9B59B6').margin({ bottom: 12 })
          }
        } else {
          // QUESTION 状态：模拟摄像头画面
          Column() {
            // 模拟取景框 — 人像占位
            Circle({ width: 80, height: 80 })
              .fill('rgba(255,255,255,0.06)')
              .border({ width: 2, color: 'rgba(255,255,255,0.1)' })

            Text('👤').fontSize(36).margin({ top: -62, bottom: 30 })

            Text('摄像头预览').fontSize(11).fontColor('#444444')
          }
          .width('100%').height('100%')
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
        }
      }
      .width('100%').height('100%')
    }
    .width('100%').layoutWeight(1).clip(true)
    .backgroundColor('#0D0D0D')
    .border({ width: 1, color: 'rgba(255,255,255,0.04)' })
  }

  @Builder BottomControls() {
    Column() {
      if (this.pageState === PageState.COUNTDOWN || this.pageState === PageState.RECORDING) {
        // 录制中显示停止按钮
        if (this.pageState === PageState.RECORDING) {
          Button() {
            Text('⏹').fontSize(22).fontColor('#FFFFFF')
          }
          .width(60).height(60)
          .backgroundColor('#E53935').borderRadius(30)
          .shadow({ radius: 14, color: 'rgba(229,57,53,0.4)', offsetY: 4 })
          .onClick(() => this.stopRecordingAndSubmit())

          Text('停止并提交').fontSize(11).fontColor('#999999').margin({ top: 8 })
        }
      } else if (this.pageState === PageState.QUESTION) {
        Button() {
          Row() {
            Circle({ width: 12, height: 12 }).fill('#FF4D4F')
            Text('开始录制').fontSize(16).fontWeight(FontWeight.Bold).fontColor('#FFFFFF').margin({ left: 8 })
          }
        }
        .width('70%').height(52)
        .backgroundColor('#E53935').borderRadius(26)
        .shadow({ radius: 12, color: 'rgba(229,57,53,0.4)', offsetY: 4 })
        .onClick(() => this.startCountdown())

        Text('点击后将有 3 秒倒计时')
          .fontSize(11).fontColor('#888888').margin({ top: 8 })
      } else if (this.pageState === PageState.RESULT) {
        Button(this.currentQuestionIndex < this.questions.length - 1 ? '下一题' : '提交全部回答')
          .width('70%').height(44).fontSize(15).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          .backgroundColor('#9B59B6').borderRadius(22)
          .onClick(() => this.confirmAndNext())
      } else if (this.pageState === PageState.SUBMITTING) {
        Text('正在与服务器通信...').fontSize(11).fontColor('#888888')
      }
    }
    .width('100%')
    .padding({ top: 14, bottom: 32 })
    .backgroundColor('#101010')
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  RuleItem(num: string, title: string, desc: string) {
    Row() {
      Text(num)
        .fontSize(12).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        .width(22).height(22).textAlign(TextAlign.Center)
        .backgroundColor('#9B59B6').borderRadius(11).margin({ right: 10 })
      Column() {
        Text(title).fontSize(13).fontWeight(FontWeight.Medium).fontColor('#FFFFFF')
        Text(desc).fontSize(11).fontColor('#999999').lineHeight(16).margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start).layoutWeight(1)
    }
    .width('100%').margin({ bottom: 10 })
  }
}
