import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { ApplicationStatus, JobApplication, JobPosition } from '../../model/JobModel'
import { StudentType, UserProfile } from '../../model/UserModel'
import { rewriteExperienceList, ExperienceInput } from '../../service/AITranslateService'
import { JobDao } from '../../service/JobDao'
import { calculateMatchScore, MatchResult, getMatchSummary } from '../../service/MatchScoreService'
import { MessageDao } from '../../service/MessageDao'
import { ResumeDao } from '../../service/ResumeDao'
import { UserDao } from '../../service/UserDao'

@Entry
@Component
struct JobDetailPage {
  @State job: JobPosition | null = null
  @State hasApplied: boolean = false
  @State isFavorite: boolean = false
  @State matchResult: MatchResult | null = null
  private jobDao: JobDao = new JobDao()
  private resumeDao: ResumeDao = new ResumeDao()
  private userDao: UserDao = new UserDao()
  private messageDao: MessageDao = new MessageDao()

  async aboutToAppear(): Promise<void> {
    const params = router.getParams() as Record<string, Object>
    const jobId = params['jobId'] as string
    if (!jobId) {
      return
    }

    this.job = await this.jobDao.getJobById(jobId)
    if (!this.job || !AppState.currentUser) {
      return
    }

    const resume = await this.resumeDao.getResumeByUserId(AppState.currentUser.userId)
    if (resume) {
      this.matchResult = calculateMatchScore(resume, this.job)
    }
    const existingApplication = await this.jobDao.getApplicationByUserAndJob(AppState.currentUser.userId, jobId)
    this.hasApplied = !!existingApplication
  }

  async handleApply(): Promise<void> {
    if (AppState.isGuest) {
      AlertDialog.show({
        title: '登录提示',
        message: '投递简历需要登录，是否前往登录？',
        primaryButton: { value: '去登录', action: () => router.pushUrl({ url: AppConstants.ROUTE_LOGIN }) },
        secondaryButton: { value: '取消', action: () => {} }
      })
      return
    }

    if (!this.job || !AppState.currentUser) {
      return
    }

    const existingApplication = await this.jobDao.getApplicationByUserAndJob(AppState.currentUser.userId, this.job.jobId)
    if (existingApplication) {
      this.hasApplied = true
      AlertDialog.show({
        title: '已投递',
        message: '你已经投递过该岗位，现在可以直接去和企业沟通。',
        primaryButton: { value: '去沟通', action: () => { this.openConversation() } },
        secondaryButton: { value: '我知道了', action: () => {} }
      })
      return
    }

    const resume = await this.resumeDao.getResumeByUserId(AppState.currentUser.userId)
    if (!resume) {
      AlertDialog.show({
        title: '请先完善简历',
        message: '投递前需要先保存一份完整简历，是否现在前往填写？',
        primaryButton: { value: '去完善', action: () => router.pushUrl({ url: AppConstants.ROUTE_RESUME_EDIT }) },
        secondaryButton: { value: '稍后再说', action: () => {} }
      })
      return
    }

    const recruiter = await this.userDao.getUserById(this.job.recruiterId)
    if (!recruiter) {
      AlertDialog.show({
        title: '暂时无法投递',
        message: '招聘方信息加载失败，请稍后重试。'
      })
      return
    }

    const translatedNote = await this.buildTranslationNote()
    const app: JobApplication = {
      applicationId: `app_${Date.now()}`,
      jobId: this.job.jobId,
      userId: AppState.currentUser.userId,
      resumeId: resume.resumeId,
      status: ApplicationStatus.SUBMITTED,
      applyTime: Date.now()
    }
    await this.jobDao.insertApplication(app)
    const studentName = AppState.currentUser.realName || AppState.currentUser.phone || '候选人'
    const recruiterName = this.getRecruiterDisplayName(recruiter)
    const sessionId = await this.messageDao.ensureApplicationConversation(
      recruiter.userId, AppState.currentUser.userId, studentName, recruiterName, this.job.title)
    this.hasApplied = true

    AlertDialog.show({
      title: '投递成功',
      message: `简历已发送给 ${recruiterName}。${translatedNote}你现在可以直接发消息沟通。`,
      primaryButton: {
        value: '去沟通',
        action: () => {
          router.pushUrl({
            url: AppConstants.ROUTE_CHAT,
            params: {
              conversationId: sessionId,
              peerName: recruiterName,
              isAIAgent: false
            }
          })
        }
      },
      secondaryButton: { value: '稍后', action: () => {} }
    })
  }

  async openConversation(): Promise<void> {
    if (!this.job || !AppState.currentUser) {
      return
    }
    const recruiter = await this.userDao.getUserById(this.job.recruiterId)
    if (!recruiter) {
      AlertDialog.show({
        title: '暂时无法打开沟通',
        message: '招聘方信息加载失败，请稍后重试。'
      })
      return
    }
    const studentName = AppState.currentUser.realName || AppState.currentUser.phone || '候选人'
    const recruiterName = this.getRecruiterDisplayName(recruiter)
    const conversationId = await this.messageDao.ensureApplicationConversation(
      recruiter.userId, AppState.currentUser.userId, studentName, recruiterName, this.job.title)
    router.pushUrl({
      url: AppConstants.ROUTE_CHAT,
      params: {
        conversationId: conversationId,
        peerName: recruiterName,
        isAIAgent: false
      }
    })
  }

  private async buildTranslationNote(): Promise<string> {
    if (!AppState.currentUser || AppState.currentUser.studentType !== StudentType.GRADUATING) {
      return ''
    }

    try {
      const resume = await this.resumeDao.getResumeByUserId(AppState.currentUser.userId)
      if (!resume || resume.experienceList.length === 0) {
        return ''
      }

      const inputList: ExperienceInput[] = []
      for (let i = 0; i < resume.experienceList.length; i++) {
        const item = resume.experienceList[i]
        inputList.push({ description: item.description, type: item.type })
      }
      const translated = await rewriteExperienceList(inputList)
      return translated.length > 0 ? '系统已同步生成更贴近企业表达的经历说明。' : ''
    } catch (_error) {
      return ''
    }
  }

  private getRecruiterDisplayName(recruiter: UserProfile): string {
    return recruiter.hrRealName || recruiter.companyName || this.job?.companyName || '招聘方'
  }

  private formatTaskDateTime(timestamp?: number): string {
    if (timestamp === undefined || timestamp < 0) {
      return '未设置'
    }
    const date = new Date(timestamp)
    const year = date.getFullYear()
    const month = `${date.getMonth() + 1}`.padStart(2, '0')
    const day = `${date.getDate()}`.padStart(2, '0')
    const hour = `${date.getHours()}`.padStart(2, '0')
    const minute = `${date.getMinutes()}`.padStart(2, '0')
    return `${year}-${month}-${day} ${hour}:${minute}`
  }

  private shouldShowTaskTime(): boolean {
    return !!this.job && this.job.category === 'micro_task'
      && this.job.taskStartTime !== undefined && this.job.taskStartTime >= 0
      && this.job.taskEndTime !== undefined && this.job.taskEndTime >= 0
  }

  build() {
    Column() {
      if (!this.job) {
        Text('加载中...')
          .width('100%')
          .height('100%')
          .textAlign(TextAlign.Center)
      } else {
        Row() {
          Button() {
            Image($r('sys.symbol.chevron_left'))
              .width(24)
              .height(24)
              .fillColor('#FFFFFF')
          }
          .backgroundColor('transparent')
          .onClick(() => router.back())

          Blank()

          Image($r('sys.symbol.heart'))
            .width(22)
            .height(22)
            .fillColor(this.isFavorite ? '#FF4D4F' : '#FFFFFF')
            .onClick(() => this.isFavorite = !this.isFavorite)
            .margin({ right: 8 })

          Image($r('sys.symbol.share'))
            .width(22)
            .height(22)
            .fillColor('#FFFFFF')
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 28, bottom: 12 })
        .backgroundColor(AppConstants.COLOR_PRIMARY)

        Scroll() {
          Column() {
            Column() {
              Text(this.job!.title)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
              Text(this.job!.companyName)
                .fontSize(14)
                .fontColor('rgba(255,255,255,0.8)')
                .margin({ top: 6 })
              Text(this.job!.salaryRange)
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppConstants.COLOR_ACCENT)
                .margin({ top: 12 })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 24 })
            .backgroundColor(AppConstants.COLOR_PRIMARY)

            Column() {
              this.DetailRow('岗位类别', this.job!.category === 'micro_task' ? '微任务/短期兼职' : '全职/转正实习')
              if (this.shouldShowTaskTime()) {
                this.DetailRow('任务开始', this.formatTaskDateTime(this.job!.taskStartTime))
                this.DetailRow('任务结束', this.formatTaskDateTime(this.job!.taskEndTime))
              }
              this.DetailRow('学历要求', this.job!.educationRequired)
              this.DetailRow('工作地点', this.job!.workAddress)
              this.DetailRow('工作年限', this.job!.workYearsRequired)
              this.DetailRow('发布时间', this.formatTaskDateTime(this.job!.publishTime))
            }
            .width('90%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .margin({ top: -12, bottom: 12 })
            .shadow({ radius: 4, color: '#10000000', offsetY: 2 })

            Column() {
              Text('技能要求')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .margin({ bottom: 12 })
                .alignSelf(ItemAlign.Start)

              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.job!.skills, (skill: string) => {
                  Text(skill)
                    .fontSize(12)
                    .fontColor('#4A90D9')
                    .padding({ left: 12, right: 12, top: 6, bottom: 6 })
                    .backgroundColor('#F0F7FF')
                    .borderRadius(14)
                    .margin({ right: 8, bottom: 8 })
                })
              }
            }
            .width('90%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .margin({ bottom: 12 })

            Column() {
              Text('岗位描述')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .margin({ bottom: 12 })
                .alignSelf(ItemAlign.Start)
              Text(this.job!.description)
                .fontSize(14)
                .fontColor('#666666')
                .lineHeight(22)
                .width('100%')
                .textAlign(TextAlign.Start)
            }
            .width('90%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .margin({ bottom: 12 })

            this.MatchScorePanel()

            Row() {
              Image($r('sys.symbol.eye'))
                .width(14)
                .height(14)
                .fillColor('#999999')
              Text(`${this.job!.viewCount}次浏览`)
                .fontSize(12)
                .fontColor('#999999')
                .margin({ left: 4, right: 16 })
              Image($r('sys.symbol.doc_text'))
                .width(14)
                .height(14)
                .fillColor('#999999')
              Text(`${this.job!.applyCount}人已投递`)
                .fontSize(12)
                .fontColor('#999999')
                .margin({ left: 4 })
            }
            .width('90%')
            .padding({ left: 16, bottom: 80 })
            .alignSelf(ItemAlign.Start)
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)

        Row() {
          Button(this.hasApplied ? '去沟通' : '立即投递')
            .width('80%')
            .height(48)
            .fontSize(16)
            .backgroundColor(this.hasApplied ? AppConstants.COLOR_PRIMARY : AppConstants.COLOR_ACCENT)
            .fontColor('#FFFFFF')
            .borderRadius(24)
            .onClick(() => {
              if (this.hasApplied) {
                this.openConversation()
              } else {
                this.handleApply()
              }
            })
        }
        .width('100%')
        .height(72)
        .backgroundColor('#FFFFFF')
        .justifyContent(FlexAlign.Center)
        .shadow({ radius: 8, color: '#20000000', offsetY: -4 })
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  DetailRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('#999999')
        .width(80)
      Text(value)
        .fontSize(14)
        .fontColor('#1A1A1A')
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 8, bottom: 8 })
    .border({ width: { bottom: 0.5 }, color: '#F5F5F5' })
  }

  @Builder
  MatchScorePanel() {
    if (this.matchResult && !AppState.isGuest) {
      Column() {
        Row() {
          Text('你与该岗位的匹配度')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
          Blank()
          Text(getMatchSummary(this.matchResult!))
            .fontSize(11)
            .fontColor('#999999')
        }
        .width('100%')
        .margin({ bottom: 12 })

        Row() {
          Stack() {
            Column() {
              Text(`${this.matchResult.score}`)
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor(this.matchResult.score >= 60 ? '#52C41A' : this.matchResult.score >= 40 ? '#FAAD14' : '#FF4D4F')
              Text('匹配度')
                .fontSize(10)
                .fontColor('#999999')
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)

            Column() {
              Divider()
                .width(60)
                .height(4)
                .backgroundColor(this.matchResult.score >= 60 ? '#52C41A' : this.matchResult.score >= 40 ? '#FAAD14' : '#FF4D4F')
                .borderRadius(2)
            }
            .width('100%')
            .height('100%')
            .justifyContent(FlexAlign.Center)
          }
          .width(80)
          .height(80)
          .backgroundColor('#F5F5F5')
          .borderRadius(40)

          Column() {
            Row() {
              this.ScoreBar('技能', this.matchResult.skillScore)
              this.ScoreBar('学历', this.matchResult.eduScore)
            }
            .width('100%')
            Row() {
              this.ScoreBar('城市', this.matchResult.cityScore)
              this.ScoreBar('薪资', this.matchResult.salaryScore)
            }
            .width('100%')
          }
          .layoutWeight(1)
          .padding({ left: 16 })
        }
        .width('100%')
        .margin({ bottom: 12 })

        if (this.matchResult.reasons.length > 0) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.matchResult.reasons, (reason: string) => {
              Text(reason)
                .fontSize(11)
                .fontColor('#52C41A')
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor('#F6FFED')
                .borderRadius(10)
                .margin({ right: 6, bottom: 4 })
            })
          }
          .width('100%')
          .margin({ bottom: 8 })
        }

        if (this.matchResult.gaps.length > 0) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.matchResult.gaps, (gap: string) => {
              Text(gap)
                .fontSize(11)
                .fontColor('#FF4D4F')
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor('#FFF2F0')
                .borderRadius(10)
                .margin({ right: 6, bottom: 4 })
            })
          }
          .width('100%')
        }
      }
      .width('100%')
      .padding(14)
      .backgroundColor('#FAFFF0')
      .borderRadius(12)
      .border({ width: 1, color: '#E8F5E9' })
      .margin({ top: 12, bottom: 4 })
    }
  }

  @Builder
  ScoreBar(label: string, score: number) {
    Row() {
      Text(label)
        .fontSize(11)
        .fontColor('#666666')
        .width(30)
      Column() {
        Row() {
          Divider()
            .height(4)
            .width(`${score}%`)
            .backgroundColor(score >= 60 ? '#52C41A' : score >= 40 ? '#FAAD14' : '#FF4D4F')
            .borderRadius(2)
          Blank()
        }
        .width('100%')
      }
      .layoutWeight(1)
      Text(`${score}%`)
        .fontSize(10)
        .fontColor('#999999')
        .width(32)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .margin({ bottom: 4 })
  }
}

export { JobDetailPage }
