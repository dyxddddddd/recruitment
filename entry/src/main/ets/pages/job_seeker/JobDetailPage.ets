// 求职者 - 职位详情页

import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { JobPosition, JobApplication, ApplicationStatus } from '../../model/JobModel'
import { JobDao } from '../../service/JobDao'
import { ResumeDao } from '../../service/ResumeDao'
import { StudentType } from '../../model/UserModel'
import { translateExperienceList, ExperienceInput } from '../../service/AITranslateService'
import { calculateMatchScore, MatchResult, getMatchSummary } from '../../service/MatchScoreService'

@Entry
@Component
struct JobDetailPage {
  @State job: JobPosition | null = null
  @State hasApplied: boolean = false
  @State isFavorite: boolean = false
  @State matchResult: MatchResult | null = null
  private jobDao: JobDao = new JobDao()
  private resumeDao: ResumeDao = new ResumeDao()

  async aboutToAppear(): Promise<void> {
    const params = router.getParams() as Record<string, Object>
    const jobId = params['jobId'] as string
    if (jobId) {
      this.job = await this.jobDao.getJobById(jobId)
      // 计算匹配度
      if (this.job && AppState.currentUser) {
        const resume = await this.resumeDao.getResumeByUserId(AppState.currentUser.userId)
        if (resume) {
          this.matchResult = calculateMatchScore(resume, this.job)
        }
      }
    }
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

    if (!this.job) return

    // 创新点五：如果是应届生，自动翻译学生经历为企业语言
    const isGraduatingStudent = AppState.currentUser?.studentType === StudentType.GRADUATING
    let translatedNote = ''
    if (isGraduatingStudent && AppState.currentUser) {
      const resume = await this.resumeDao.getResumeByUserId(AppState.currentUser.userId)
      if (resume && resume.experienceList.length > 0) {
        const inputList: Array<ExperienceInput> = []
        for (let i = 0; i < resume.experienceList.length; i++) {
          const e = resume.experienceList[i]
          inputList.push({ description: e.description, type: e.type })
        }
        const translated = await translateExperienceList(inputList)
        if (translated.length > 0) {
          translatedNote = `\n（系统已将你的校园经历翻译为 HR 更易理解的表达）`
        }
      }
    }

    const app: JobApplication = {
      applicationId: `app_${Date.now()}`,
      jobId: this.job.jobId,
      userId: AppState.currentUser!.userId,
      resumeId: '',
      status: ApplicationStatus.SUBMITTED,
      applyTime: Date.now()
    }
    await this.jobDao.insertApplication(app)
    this.hasApplied = true
    AlertDialog.show({
      message: `投递成功！${translatedNote}HR将在24小时内查看你的简历。`
    })
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
              Text(this.job.title)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
              Text(this.job.companyName)
                .fontSize(14)
                .fontColor('rgba(255,255,255,0.8)')
                .margin({ top: 6 })
              Text(this.job.salaryRange)
                .fontSize(24)
                .fontWeight(FontWeight.Bold)
                .fontColor(AppConstants.COLOR_ACCENT)
                .margin({ top: 12 })
            }
            .width('100%')
            .padding({ left: 16, right: 16, top: 16, bottom: 24 })
            .backgroundColor(AppConstants.COLOR_PRIMARY)

            Column() {
              this.DetailRow('岗位类别', this.job.category === 'micro_task' ? '微任务/短期兼职' : '全职/转正实习')
              this.DetailRow('学历要求', this.job.educationRequired)
              this.DetailRow('工作地点', this.job.workAddress)
              this.DetailRow('工作年限', this.job.workYearsRequired)
              this.DetailRow('发布时间', new Date(this.job.publishTime).toLocaleDateString())
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
                ForEach(this.job.skills, (skill: string) => {
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
              Text(this.job.description)
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
              Text(`${this.job.viewCount}次浏览`)
                .fontSize(12)
                .fontColor('#999999')
                .margin({ left: 4, right: 16 })
              Image($r('sys.symbol.doc_text'))
                .width(14)
                .height(14)
                .fillColor('#999999')
              Text(`${this.job.applyCount}人已投递`)
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
          Button(this.hasApplied ? '已投递' : '立即投递')
            .width('80%')
            .height(48)
            .fontSize(16)
            .backgroundColor(this.hasApplied ? '#CCCCCC' : AppConstants.COLOR_ACCENT)
            .fontColor('#FFFFFF')
            .borderRadius(24)
            .enabled(!this.hasApplied)
            .onClick(() => this.handleApply())
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

  // 匹配度面板
  @Builder
  MatchScorePanel() {
    if (this.matchResult && !AppState.isGuest) {
    Column() {
      // 标题行
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

      // 环形进度 + 分数
      Row() {
        // 环形进度（用 Stack 模拟）
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

          // 进度条圆环（横向进度条代替 Arc）
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

        // 五维雷达摘要
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

      // 匹配亮点（绿色）
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

      // 差距项（红色）
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
      // 进度条
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
