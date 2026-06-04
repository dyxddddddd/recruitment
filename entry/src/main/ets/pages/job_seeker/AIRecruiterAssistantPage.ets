import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { ApplicationStatus, JobApplication } from '../../model/JobModel'
import { CampusAIAdviceItem, CampusAIRadarItem, CampusAIService } from '../../service/CampusAIService'
import { JobDao } from '../../service/JobDao'
import { ResumeDao } from '../../service/ResumeDao'

@Entry
@Component
struct AIRecruiterAssistantPage {
  @State radarData: CampusAIRadarItem[] = []
  @State isLoading: boolean = true
  @State resumeAdvices: CampusAIAdviceItem[] = []
  @State sampleResumeText: string = ''
  @State assistantSummary: string = ''
  @State expandedAdviceId: string = ''
  private jobDao: JobDao = new JobDao()
  private resumeDao: ResumeDao = new ResumeDao()

  aboutToAppear(): void {
    this.loadData()
  }

  async loadData(): Promise<void> {
    this.isLoading = true
    try {
      if (!AppState.currentUser) {
        this.isLoading = false
        return
      }
      const resume = await this.resumeDao.getResumeByUserId(AppState.currentUser.userId)
      const applications = await this.jobDao.getApplicationsByUser(AppState.currentUser.userId)
      const failedApplications = applications.filter((item: JobApplication) =>
        item.status !== ApplicationStatus.OFFERED && item.status !== ApplicationStatus.ACCEPTED
      ).length
      const rejectCount = applications.filter((item: JobApplication) => item.status === ApplicationStatus.REJECTED).length
      const aiResult = await CampusAIService.analyzeCareerAssistant({
        user: AppState.currentUser,
        resume: resume,
        applications: applications,
        failedApplications: failedApplications,
        rejectCount: rejectCount
      })
      this.assistantSummary = aiResult.summary
      this.radarData = aiResult.radar
      this.resumeAdvices = aiResult.advices
      this.sampleResumeText = aiResult.sampleResumeText
    } catch (e) {
      this.assistantSummary = e instanceof Error ? e.message : 'AI 分析失败，请稍后重试'
    } finally {
      this.isLoading = false
    }
  }

  getPriorityColor(priority: 'high' | 'medium' | 'low'): string {
    switch (priority) {
      case 'high':
        return '#FF4D4F'
      case 'medium':
        return '#FAAD14'
      default:
        return '#52C41A'
    }
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
        Blank()
        Text('AI 招聘助手')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 28, bottom: 12 })

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color(AppConstants.COLOR_PRIMARY)
          Text('正在生成求职建议...')
            .fontSize(14)
            .fontColor('#999999')
            .margin({ top: 12 })
        }
        .layoutWeight(1)
        .width('100%')
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            if (this.assistantSummary) {
              Text(this.assistantSummary)
                .fontSize(13)
                .lineHeight(22)
                .fontColor('#445266')
                .padding(14)
                .backgroundColor('#FFF9E8')
                .borderRadius(12)
                .width('100%')
                .margin({ bottom: 12 })
            }

            Column() {
              Row() {
                Text('职业画像雷达图')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1A1A1A')
                Blank()
                Text('AI 生成')
                  .fontSize(11)
                  .fontColor('#999999')
              }
              .width('100%')
              .margin({ bottom: 16 })

              RadarChartComponent({ radarData: this.radarData })
                .width('100%')
                .height(240)
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .margin({ bottom: 12 })

            if (this.resumeAdvices.length > 0) {
              Column() {
                Text('简历优化建议')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#1A1A1A')
                  .alignSelf(ItemAlign.Start)
                  .margin({ bottom: 12 })

                ForEach(this.resumeAdvices, (item: CampusAIAdviceItem) => {
                  Column() {
                    Row() {
                      Text(item.title)
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                        .fontColor('#1A1A1A')
                        .layoutWeight(1)
                      Text(item.priority === 'high' ? '高优' : item.priority === 'medium' ? '中优' : '建议')
                        .fontSize(10)
                        .fontColor('#FFFFFF')
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .backgroundColor(this.getPriorityColor(item.priority))
                        .borderRadius(4)
                    }
                    .width('100%')

                    Text(this.expandedAdviceId === item.id ? item.content : `${item.content.substring(0, 58)}...`)
                      .fontSize(13)
                      .fontColor('#666666')
                      .lineHeight(20)
                      .margin({ top: 8 })

                    Text(this.expandedAdviceId === item.id ? '收起' : '展开详情')
                      .fontSize(12)
                      .fontColor(AppConstants.COLOR_PRIMARY)
                      .margin({ top: 8 })
                      .onClick(() => {
                        this.expandedAdviceId = this.expandedAdviceId === item.id ? '' : item.id
                      })
                  }
                  .width('100%')
                  .padding(12)
                  .backgroundColor('#FAFAFA')
                  .borderRadius(10)
                  .margin({ bottom: 10 })
                })
              }
              .width('100%')
              .padding(16)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .margin({ bottom: 12 })
            }

            Column() {
              Text('匿名简历参考')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1A1A1A')
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 12 })

              Text(this.sampleResumeText || '暂无可展示内容')
                .fontSize(13)
                .fontColor('#666666')
                .lineHeight(22)
                .padding(12)
                .backgroundColor('#F9F9F9')
                .borderRadius(8)
                .width('100%')
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
          }
          .padding({ left: 16, right: 16, top: 12, bottom: 20 })
        }
        .layoutWeight(1)
        .width('100%')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }
}

@Component
struct RadarChartComponent {
  @Prop radarData: CampusAIRadarItem[] = []
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)

  aboutToAppear(): void {
    setTimeout(() => this.drawChart(), 100)
  }

  drawChart(): void {
    const ctx = this.context
    const width = 320
    const height = 240
    const centerX = width / 2
    const centerY = height / 2
    const maxRadius = 85
    const count = this.radarData.length
    if (count === 0) {
      return
    }

    const step = (2 * Math.PI) / count

    for (let ring = 1; ring <= 4; ring++) {
      ctx.beginPath()
      for (let i = 0; i < count; i++) {
        const angle = i * step - Math.PI / 2
        const radius = (ring / 4) * maxRadius
        const x = centerX + radius * Math.cos(angle)
        const y = centerY + radius * Math.sin(angle)
        if (i === 0) {
          ctx.moveTo(x, y)
        } else {
          ctx.lineTo(x, y)
        }
      }
      ctx.closePath()
      ctx.strokeStyle = `rgba(74,144,217,${0.1 + ring * 0.05})`
      ctx.lineWidth = 0.5
      ctx.stroke()
    }

    for (let i = 0; i < count; i++) {
      const angle = i * step - Math.PI / 2
      const x = centerX + maxRadius * Math.cos(angle)
      const y = centerY + maxRadius * Math.sin(angle)
      ctx.beginPath()
      ctx.moveTo(centerX, centerY)
      ctx.lineTo(x, y)
      ctx.strokeStyle = 'rgba(74,144,217,0.3)'
      ctx.lineWidth = 1
      ctx.stroke()

      ctx.fillStyle = '#666666'
      ctx.font = '11px HarmonyOS Sans'
      ctx.textAlign = 'center'
      ctx.textBaseline = 'middle'
      ctx.fillText(this.radarData[i].label, centerX + (maxRadius + 18) * Math.cos(angle), centerY + (maxRadius + 18) * Math.sin(angle))
    }

    ctx.beginPath()
    for (let i = 0; i < count; i++) {
      const ratio = this.radarData[i].value / this.radarData[i].max
      const angle = i * step - Math.PI / 2
      const radius = ratio * maxRadius
      const x = centerX + radius * Math.cos(angle)
      const y = centerY + radius * Math.sin(angle)
      if (i === 0) {
        ctx.moveTo(x, y)
      } else {
        ctx.lineTo(x, y)
      }
    }
    ctx.closePath()
    ctx.fillStyle = 'rgba(74,144,217,0.2)'
    ctx.fill()
    ctx.strokeStyle = AppConstants.COLOR_PRIMARY
    ctx.lineWidth = 2
    ctx.stroke()
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height('100%')
  }
}

export { AIRecruiterAssistantPage }
