// 学生端 - AI虚拟人视频面试（异步自由录制模式）
import { router } from '@kit.ArkUI'
import { media } from '@kit.MediaKit'
import { fileIo } from '@kit.CoreFileKit'
import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import {
  InterviewApiService,
  InterviewQuestion,
  CreateInterviewRequest
} from '../../service/InterviewApiService'
import { DatabaseHelper } from '../../database/DatabaseHelper'
import { TABLE_AI_INTERVIEW } from '../../database/Tables'

const RECORD_MAX_SECONDS = 180

const REQUIRED_PERMISSIONS: Permissions[] = [
  'ohos.permission.CAMERA',
  'ohos.permission.MICROPHONE'
]

enum QuestionStatus {
  PENDING = 'pending',
  RECORDED = 'recorded'
}

interface QuestionState {
  question: InterviewQuestion
  status: QuestionStatus
  videoPath: string
}

interface RecordedItem {
  questionId: number
  questionText: string
  videoPath: string
}

function makeQuestionState(q: InterviewQuestion): QuestionState {
  return {
    question: q,
    status: QuestionStatus.PENDING,
    videoPath: ''
  }
}

@Entry
@Component
export struct AIInterviewVideoPage {
  @State status: string = 'loading'
  @State sessionId: string = ''
  @State jobTitle: string = ''
  @State questions: QuestionState[] = []
  @State completedCount: number = 0
  @State recordingIndex: number = -1
  @State isRecording: boolean = false
  @State recordSeconds: number = 0
  @State isUploading: boolean = false
  @State allDone: boolean = false

  private avRecorder: media.AVRecorder | null = null
  private videoPath: string = ''
  private recordTimerId: number = -1
  private uiContext: common.UIAbilityContext | null = null

  async aboutToAppear(): Promise<void> {
    this.uiContext = getContext(this) as common.UIAbilityContext
    const params = router.getParams() as Record<string, Object>
    this.jobTitle = (params['position'] as string) || (params['jobTitle'] as string) || 'AI面试'
    this.sessionId = (params['sessionId'] as string) || ''
    const userId = AppState.currentUser?.userId || ''

    if (this.sessionId) {
      await this.loadQuestions()
    } else if (userId && this.jobTitle) {
      await this.createSession(userId)
    } else {
      this.status = 'error'
    }
  }

  async createSession(userId: string): Promise<void> {
    this.status = 'loading'
    try {
      const req: CreateInterviewRequest = { userId: userId, position: this.jobTitle }
      const result = await InterviewApiService.createInterview(req)
      this.sessionId = result.sessionId
      this.questions = (result.questions || []).map((q: InterviewQuestion) => makeQuestionState(q))
      this.updateCompletedCount()
      this.status = this.questions.length > 0 ? 'list' : 'error'
    } catch (_e) {
      this.status = 'error'
    }
  }

  async loadQuestions(): Promise<void> {
    this.status = 'loading'
    try {
      const raw = await InterviewApiService.getQuestions(this.sessionId)
      this.questions = raw.map((q: InterviewQuestion) => makeQuestionState(q))
      this.updateCompletedCount()
      this.status = this.questions.length > 0 ? 'list' : 'error'
    } catch (_e) {
      await this.loadQuestionsFromDb()
    }
  }

  async loadQuestionsFromDb(): Promise<void> {
    try {
      const store = await DatabaseHelper.getInstance().getStore()
      const rs = await store.querySql(
        `SELECT questions FROM ${TABLE_AI_INTERVIEW} WHERE interview_id = '${this.sessionId}'`
      )
      if (rs.goToFirstRow()) {
        const raw = rs.getString(rs.getColumnIndex('questions'))
        if (raw && raw.length > 0) {
          const parsed = JSON.parse(raw) as InterviewQuestion[]
          this.questions = parsed.map((q: InterviewQuestion) => makeQuestionState(q))
          this.updateCompletedCount()
          this.status = this.questions.length > 0 ? 'list' : 'error'
          rs.close()
          return
        }
      }
      rs.close()
    } catch (_e2) {
      // fall through to error
    }
    this.status = 'error'
  }

  updateCompletedCount(): void {
    this.completedCount = this.questions.filter(q => q.status === QuestionStatus.RECORDED).length
    this.allDone = this.questions.length > 0 && this.completedCount === this.questions.length
  }

  // ===== 录制流程 =====

  async selectQuestion(index: number): Promise<void> {
    if (this.isRecording || this.isUploading) return
    if (this.questions[index].status === QuestionStatus.RECORDED) return
    this.recordingIndex = index
    this.recordSeconds = 0
    const granted = await this.requestPermissions()
    if (granted) {
      this.status = 'ready_to_record'
    }
  }

  backToList(): void {
    if (this.isRecording) {
      AlertDialog.show({
        title: '正在录制',
        message: '请先停止录制再返回。',
        primaryButton: { value: '好的', action: () => {} }
      })
      return
    }
    this.recordingIndex = -1
    this.status = 'list'
    this.avRecorder = null
  }

  async requestPermissions(): Promise<boolean> {
    if (!this.uiContext) return false
    const atManager = abilityAccessCtrl.createAtManager()
    try {
      const result = await atManager.requestPermissionsFromUser(this.uiContext, REQUIRED_PERMISSIONS)
      const allGranted = result.authResults.every(
        (s: abilityAccessCtrl.GrantStatus) => s === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED
      )
      if (allGranted) return true

      if (result.dialogShownResults && result.dialogShownResults.some((shown: boolean) => shown)) {
        AlertDialog.show({
          title: '需要授权',
          message: '您已拒绝相机和麦克风权限，是否前往设置页面开启？',
          primaryButton: {
            value: '去设置',
            action: async () => {
              await atManager.requestPermissionOnSetting(this.uiContext!, REQUIRED_PERMISSIONS)
            }
          },
          secondaryButton: { value: '取消', action: () => {} }
        })
      }
      return false
    } catch (_e) {
      AlertDialog.show({
        title: '需要授权',
        message: '录制面试需要相机和麦克风权限，请授权后重试。',
        primaryButton: { value: '知道了', action: () => {} }
      })
      return false
    }
  }

  async startRecording(): Promise<void> {
    if (this.isRecording || this.isUploading || !this.uiContext) return
    try {
      this.videoPath = `${this.uiContext.filesDir}/iv_q${this.recordingIndex}_${Date.now()}.m4a`
      const file = fileIo.openSync(this.videoPath, fileIo.OpenMode.CREATE | fileIo.OpenMode.READ_WRITE)

      const recorder = await media.createAVRecorder()
      const avConfig: media.AVRecorderConfig = {
        audioSourceType: media.AudioSourceType.AUDIO_SOURCE_TYPE_MIC,
        profile: {
          audioBitrate: 64000,
          audioChannels: 1,
          audioCodec: media.CodecMimeType.AUDIO_AAC,
          audioSampleRate: 16000,
          fileFormat: media.ContainerFormatType.CFT_MPEG_4A
        },
        url: `fd://${file.fd}`
      }
      await recorder.prepare(avConfig)
      await recorder.start()
      this.avRecorder = recorder
      this.isRecording = true
      this.recordSeconds = 0
      this.recordTimerId = setInterval(() => {
        this.recordSeconds++
        if (this.recordSeconds >= RECORD_MAX_SECONDS) this.stopRecording()
      }, 1000)
    } catch (_e) {
      this.isRecording = false
      if (this.avRecorder) {
        try { this.avRecorder.release() } catch (_e2) { /* ignore */ }
        this.avRecorder = null
      }
      AlertDialog.show({ title: '录制失败', message: '无法启动录制，请检查麦克风权限。' })
    }
  }

  async stopRecording(): Promise<void> {
    if (!this.isRecording || !this.avRecorder) return
    clearInterval(this.recordTimerId)
    this.isRecording = false
    try { await this.avRecorder.stop() } catch (_e) { /* ignore */ }
    try { await this.avRecorder.release() } catch (_e) { /* ignore */ }
    this.avRecorder = null
    // 保存录制结果到对应题目
    const updated: QuestionState[] = []
    for (let i = 0; i < this.questions.length; i++) {
      if (i === this.recordingIndex) {
        updated.push({
          question: this.questions[i].question,
          status: QuestionStatus.RECORDED,
          videoPath: this.videoPath
        })
      } else {
        updated.push(this.questions[i])
      }
    }
    this.questions = updated
    this.updateCompletedCount()
    // 自动返回列表
    this.status = 'list'
    this.recordingIndex = -1
  }

  async completeInterview(): Promise<void> {
    if (!this.allDone) {
      AlertDialog.show({ title: '还有题目未完成', message: '请完成所有题目的录制后再提交。' })
      return
    }
    AlertDialog.show({
      title: '确认提交',
      message: '提交后HR将收到你的面试视频并进行评估，确定提交吗？',
      primaryButton: {
        value: '确认提交',
        action: async () => {
          this.isUploading = true
          try {
            // 将录制数据保存到本地数据库，等待HR端拉取分析
            const store = await DatabaseHelper.getInstance().getStore()
            const recordedData: RecordedItem[] = this.questions.map(q => {
              const item: RecordedItem = {
                questionId: q.question.questionId,
                questionText: q.question.questionText,
                videoPath: q.videoPath
              }
              return item
            })
            await store.executeSql(
              `UPDATE ${TABLE_AI_INTERVIEW} SET answers = '${JSON.stringify(recordedData).replace(/'/g, "''")}', status = 'submitted', complete_time = ${Date.now()} WHERE interview_id = '${this.sessionId}'`
            )
            AppStorage.setOrCreate('msg_refresh', Date.now())
            this.status = 'submitted'
          } catch (_e) {
            AlertDialog.show({ title: '提交失败', message: '提交失败，请稍后重试。' })
          } finally {
            this.isUploading = false
          }
        }
      },
      secondaryButton: { value: '取消', action: () => {} }
    })
  }

  // ===== 工具方法 =====

  formatTime(seconds: number): string {
    const m = Math.floor(seconds / 60)
    const s = seconds % 60
    return `${m.toString().padStart(2, '0')}:${s.toString().padStart(2, '0')}`
  }

  aboutToDisappear(): void {
    clearInterval(this.recordTimerId)
    if (this.avRecorder) {
      try { this.avRecorder.release() } catch (_e) { /* ignore */ }
    }
  }

  // ===== UI =====

  build(): void {
    Column() {
      // 顶部栏
      Row() {
        Button() {
          Image($r('app.media.ic_back')).width(22).height(22).fillColor('#4A90D9')
        }
        .backgroundColor(Color.Transparent).padding(0)
        .onClick(() => {
          if (this.status === 'ready_to_record' || this.isRecording || this.isUploading) {
            this.backToList()
          } else if (this.completedCount > 0 && !this.allDone) {
            AlertDialog.show({
              title: '无法返回',
              message: '你已录制了部分题目，请完成全部题目并提交后再返回。',
              primaryButton: { value: '继续答题', action: () => {} }
            })
          } else if (this.allDone && this.status !== 'submitted') {
            AlertDialog.show({
              title: '请先提交',
              message: '全部题目已录制完成，请点击底部"确认提交"按钮提交面试。',
              primaryButton: { value: '好的', action: () => {} }
            })
          } else {
            router.back()
          }
        })
        Blank()
        // 录制中显示计时器
        if (this.isRecording) {
          Row() {
            Circle({ width: 8, height: 8 }).fill('#FF4D4F')
            Text(this.formatTime(this.recordSeconds))
              .fontSize(14).fontColor('#FF4D4F').fontWeight(FontWeight.Bold).margin({ left: 6 })
          }
        } else if (this.isUploading) {
          Text('提交中...').fontSize(13).fontColor('#9B59B6')
        }
      }
      .width('100%').padding({ left: 16, right: 16, top: 60, bottom: 14 }).backgroundColor('#FFFFFF')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      if (this.status === 'loading') {
        Column() {
          LoadingProgress().width(32).height(32).color('#9B59B6')
          Text('加载中...').fontSize(13).fontColor('#999999').margin({ top: 12 })
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.status === 'error') {
        Column() {
          Text('😕').fontSize(48).margin({ bottom: 12 })
          Text('加载失败').fontSize(14).fontColor('#999999')
          Button('返回').margin({ top: 16 }).onClick(() => router.back())
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.status === 'submitted') {
        Column() {
          Text('✅').fontSize(48).margin({ bottom: 12 })
          Text('面试视频已提交').fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1A1A1A').margin({ bottom: 8 })
          Text('HR 将查看你的面试视频并进行评估').fontSize(13).fontColor('#999999')
          Button('返回').margin({ top: 20 }).fontSize(14)
            .backgroundColor('#F5F5F5').fontColor('#666666').borderRadius(20)
            .onClick(() => router.back())
        }
        .width('100%').layoutWeight(1).justifyContent(FlexAlign.Center)
      } else if (this.status === 'ready_to_record' || this.isRecording || this.isUploading) {
        this.RecordingView()
      } else {
        this.QuestionListView()
      }
    }
    .width('100%').height('100%').backgroundColor('#F4F6FB')
  }

  // ===== 题目列表视图 =====

  @Builder
  QuestionListView() {
    Column() {
      Row() {
        Text(`已完成 ${this.completedCount}/${this.questions.length} 题`)
          .fontSize(12).fontColor('#9B59B6')
        Blank()
        Text('自由录制，无需约时间').fontSize(11).fontColor('#CCCCCC')
      }
      .width('100%').padding({ left: 16, right: 16, top: 12, bottom: 8 })

      Scroll() {
        Column() {
          ForEach(this.questions, (qs: QuestionState, idx: number) => {
            Column() {
              Row() {
                Column() {
                  if (qs.status === QuestionStatus.RECORDED) {
                    Text('✅').fontSize(20)
                  } else {
                    Text('🎤').fontSize(20)
                  }
                }
                .width(36).height(36).justifyContent(FlexAlign.Center)
                .backgroundColor(qs.status === QuestionStatus.RECORDED ? '#F0FFF0' : '#F8F4FF')
                .borderRadius(18)
                .margin({ right: 12 })

                Column() {
                  Text(`第 ${idx + 1} 题`)
                    .fontSize(13).fontColor('#1A1A1A').fontWeight(FontWeight.Medium)
                  Text(qs.question.questionText)
                    .fontSize(11).fontColor('#999999')
                    .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
                    .margin({ top: 2 })
                }
                .layoutWeight(1).alignItems(HorizontalAlign.Start)

                if (qs.status === QuestionStatus.RECORDED) {
                  Text('已录制')
                    .fontSize(12).height(30)
                    .fontColor('#52C41A')
                    .padding({ left: 14, right: 14 })
                    .border({ width: 1, color: '#52C41A', style: BorderStyle.Solid })
                    .borderRadius(15)
                    .margin({ left: 8 })
                } else {
                  Button('录制')
                    .fontSize(12).height(30)
                    .backgroundColor('#9B59B6')
                    .fontColor('#FFFFFF')
                    .borderRadius(15)
                    .padding({ left: 14, right: 14 })
                    .margin({ left: 8 })
                    .onClick(() => this.selectQuestion(idx))
                }
              }
              .width('100%')
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .margin({ bottom: 8 })
          })
        }
        .width('100%').padding({ left: 14, right: 14, top: 4, bottom: 8 })
      }
      .width('100%').layoutWeight(1).scrollBar(BarState.Off)

      Column() {
        Button(this.allDone ? '确认提交' : '请完成全部题目后提交')
          .width('90%').height(48)
          .fontSize(15).fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .backgroundColor(this.allDone ? '#FF6B35' : '#CCCCCC')
          .borderRadius(24)
          .enabled(this.allDone)
          .onClick(() => this.completeInterview())

        Text('提交后HR将收到你的面试视频并进行评估')
          .fontSize(10).fontColor('#CCCCCC').margin({ top: 6 })
      }
      .width('100%').padding({ top: 10, bottom: 20 }).backgroundColor('#FFFFFF')
    }
    .width('100%').layoutWeight(1)
  }

  // ===== 录制视图 =====

  @Builder
  RecordingView() {
    Column() {
      // 题目（仅在录制开始后显示）
      if (this.isRecording && this.recordingIndex >= 0 && this.recordingIndex < this.questions.length) {
        Column() {
          Text(`Q${this.recordingIndex + 1}`)
            .fontSize(12).fontColor('#9B59B6').fontWeight(FontWeight.Bold).margin({ bottom: 4 })
          Text(this.questions[this.recordingIndex].question.questionText)
            .fontSize(14).fontColor('#1A1A1A').fontWeight(FontWeight.Medium).lineHeight(20)
        }
        .width('100%').padding(12)
        .backgroundColor('#F8F4FF').borderRadius(10)
        .margin({ left: 12, right: 12, top: 10 })
      }

      // 录制指示区
      Column() {
        if (this.isRecording) {
          // 录制中：简洁的录制指示
          Column() {
            Row() {
              Circle({ width: 6, height: 6 }).fill('#FF4D4F')
              Text('REC').fontSize(10).fontColor('#FF4D4F').fontWeight(FontWeight.Bold).margin({ left: 4 })
            }
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('rgba(255,77,79,0.15)').borderRadius(4)
            .position({ x: 12, y: 12 })
          }
          .width('100%').height('100%')
          .backgroundColor('#1A1A1A')
        } else if (this.isUploading) {
          Column() {
            LoadingProgress().width(32).height(32).color('#9B59B6')
            Text('提交中...').fontSize(13).fontColor('#AAAAAA').margin({ top: 12 })
          }
          .width('100%').height('100%')
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
          .backgroundColor('#1A1A1A')
        } else {
          // 准备录制
          Column() {
            Text('🎙️').fontSize(40).margin({ bottom: 8 })
            Text('点击下方按钮开始录制').fontSize(14).fontColor('#FFFFFF').margin({ bottom: 4 })
            Text('请清晰说出你的回答').fontSize(12).fontColor('#AAAAAA')
          }
          .width('100%').height('100%')
          .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
          .backgroundColor('#1A1A1A')
        }
      }
      .width('100%').layoutWeight(1)
      .borderRadius(12)
      .margin({ left: 14, right: 14, top: 10 }).clip(true)

      // 操作区
      Column() {
        if (!this.isRecording && !this.isUploading) {
          Button('开始录制')
            .width('75%').height(48).fontSize(16).fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF').backgroundColor('#FF4D4F').borderRadius(24)
            .onClick(() => this.startRecording())
          Text(`最长 ${RECORD_MAX_SECONDS / 60} 分钟`).fontSize(10).fontColor('#CCCCCC').margin({ top: 6 })
        }

        if (this.isRecording) {
          Button('停止录制')
            .width('75%').height(48).fontSize(16).fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF').backgroundColor('#FF4D4F').borderRadius(24)
            .onClick(() => this.stopRecording())
        }

        if (this.isUploading) {
          Column() {
            LoadingProgress().width(24).height(24).color('#9B59B6')
            Text('正在提交...').fontSize(13).fontColor('#999999').margin({ top: 8 })
          }
        }
      }
      .width('100%').padding({ left: 16, right: 16, top: 14, bottom: 24 }).backgroundColor('#FFFFFF')
    }
    .width('100%').layoutWeight(1)
  }

}

