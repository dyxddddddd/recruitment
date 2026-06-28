// 求职者 - 投递记录页（Track application status + HR feedback）

import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { JobApplication, ApplicationStatus } from '../../model/JobModel'
import { JobDao } from '../../service/JobDao'
import { JobPosition } from '../../model/JobModel'

interface ApplicationWithJob {
  application: JobApplication
  job: JobPosition | null
}

interface StatItem {
  label: string
  value: string
}

interface StatusConfig {
  label: string
  color: string
  bg: string
  icon: string
}

interface StatItemsResult {
  submitted: string
  viewed: string
  interview: string
  offered: string
}

@Entry
@Component
export struct ApplicationTrackPage {
  @State applications: ApplicationWithJob[] = []
  @State isLoading: boolean = true
  private jobDao: JobDao = new JobDao()

  aboutToAppear(): void {
    this.loadApplications()
  }

  async loadApplications(): Promise<void> {
    if (!AppState.currentUser) {
      this.isLoading = false
      return
    }
    this.isLoading = true
    const apps = await this.jobDao.getApplicationsByUser(AppState.currentUser.userId)
    const withJobs: ApplicationWithJob[] = []
    for (let i = 0; i < apps.length; i++) {
      const app = apps[i]
      const job = await this.jobDao.getJobById(app.jobId)
      withJobs.push({ application: app, job })
    }
    this.applications = withJobs
    this.isLoading = false
  }

  getStatusConfig(status: ApplicationStatus): StatusConfig {
    const cfg: StatusConfig = { label: '已投递', color: '#4A90D9', bg: '#F0F7FF', icon: '📤' }
    const cfg2: StatusConfig = { label: '已查看', color: '#FAAD14', bg: '#FFF8E1', icon: '👀' }
    const cfg3: StatusConfig = { label: '面试邀请', color: '#52C41A', bg: '#F6FFED', icon: '🎉' }
    const cfg4: StatusConfig = { label: '已发Offer', color: '#9B59B6', bg: '#F9F0FF', icon: '🏆' }
    const cfg5: StatusConfig = { label: '不合适', color: '#FF4D4F', bg: '#FFF2F0', icon: '❌' }
    const cfg6: StatusConfig = { label: '已接受', color: '#52C41A', bg: '#F6FFED', icon: '✅' }
    const cfg7: StatusConfig = { label: '未知', color: '#999999', bg: '#F5F5F5', icon: '❓' }
    if (status === ApplicationStatus.SUBMITTED) { return cfg }
    if (status === ApplicationStatus.VIEWED) { return cfg2 }
    if (status === ApplicationStatus.INTERVIEW) { return cfg3 }
    if (status === ApplicationStatus.OFFERED) { return cfg4 }
    if (status === ApplicationStatus.REJECTED) { return cfg5 }
    if (status === ApplicationStatus.ACCEPTED) { return cfg6 }
    return cfg7
  }

  getRejectionReasonLabel(reason: string | undefined): string {
    if (!reason) return '暂无'
    if (reason === 'education') return '学历不符'
    if (reason === 'experience') return '经验不足'
    if (reason === 'full') return '该岗位已招满'
    if (reason === 'closed') return '岗位已下线'
    return reason
  }

  formatDate(ts: number): string {
    const d = new Date(ts)
    const y = d.getFullYear()
    const m = (d.getMonth() + 1).toString().padStart(2, '0')
    const day = d.getDate().toString().padStart(2, '0')
    return `${y}.${m}.${day}`
  }

  formatDateTime(ts: number): string {
    const d = new Date(ts)
    const y = d.getFullYear()
    const m = (d.getMonth() + 1).toString().padStart(2, '0')
    const day = d.getDate().toString().padStart(2, '0')
    const h = d.getHours().toString().padStart(2, '0')
    const min = d.getMinutes().toString().padStart(2, '0')
    return `${y}.${m}.${day} ${h}:${min}`
  }

  getStatItems(): StatItemsResult {
    let submitted = this.applications.length.toString()
    let viewed = '0'
    let interview = '0'
    let offered = '0'
    for (let i = 0; i < this.applications.length; i++) {
      const app = this.applications[i].application
      if (app.status === ApplicationStatus.VIEWED) { viewed = (parseInt(viewed) + 1).toString() }
      if (app.status === ApplicationStatus.INTERVIEW) { interview = (parseInt(interview) + 1).toString() }
      if (app.status === ApplicationStatus.OFFERED) { offered = (parseInt(offered) + 1).toString() }
    }
    return { submitted: submitted, viewed: viewed, interview: interview, offered: offered }
  }

  build() {
    Stack() {
      Column() {
        Row() {
          Button() {
            Image($r('app.media.ic_back'))
              .width(24).height(24).fillColor('#1A1A1A')
          }
          .backgroundColor('transparent')
          .onClick(() => router.back())

          Text('投递记录')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)

          Button() {
            Image($r('sys.symbol.arrow_clockwise'))
              .width(20).height(20).fillColor('#4A90D9')
          }
          .backgroundColor('transparent')
          .onClick(() => this.loadApplications())
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 52, bottom: 12 })

        Divider().height(1).color('#F0F0F0')

        if (this.isLoading) {
          Column() {
            LoadingProgress().width(40).height(40)
            Text('加载中...').fontSize(13).fontColor('#999999').margin({ top: 12 })
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else if (this.applications.length === 0) {
          Column() {
            Text('📋').fontSize(64).margin({ bottom: 16 })
            Text('还没有投递记录').fontSize(16).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
            Text('去发现适合你的岗位吧').fontSize(13).fontColor('#999999').margin({ top: 4 })
            Button('去求职')
              .fontSize(14)
              .height(40)
              .width(160)
              .backgroundColor(AppConstants.COLOR_PRIMARY)
              .fontColor('#FFFFFF')
              .borderRadius(20)
              .margin({ top: 20 })
              .onClick(() => router.back())
          }
          .width('100%')
          .layoutWeight(1)
          .justifyContent(FlexAlign.Center)
        } else {
          this.StatSummaryBuilder()
          List() {
            ForEach(this.applications, (item: ApplicationWithJob) => {
              ListItem() {
                this.ApplicationCardBuilder(item)
              }
            })
          }
          .width('100%')
          .layoutWeight(1)
          .padding({ left: 16, right: 16 })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#FFFFFF')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  StatSummaryBuilder() {
    Row() {
      Column() {
        Text(this.getStatItems().submitted)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.COLOR_PRIMARY)
        Text('投递')
          .fontSize(11)
          .fontColor('#999999')
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Column() {
        Text(this.getStatItems().viewed)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.COLOR_PRIMARY)
        Text('已查看')
          .fontSize(11)
          .fontColor('#999999')
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Column() {
        Text(this.getStatItems().interview)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.COLOR_PRIMARY)
        Text('面试')
          .fontSize(11)
          .fontColor('#999999')
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)

      Column() {
        Text(this.getStatItems().offered)
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.COLOR_PRIMARY)
        Text('Offer')
          .fontSize(11)
          .fontColor('#999999')
          .margin({ top: 2 })
      }
      .layoutWeight(1)
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .padding({ top: 16, bottom: 16 })
    .backgroundColor('#F9FAFF')
  }

  @Builder
  ApplicationCardBuilder(item: ApplicationWithJob) {
    Column() {
      Row() {
        Column() {
          Text(item.job ? item.job.title : '（岗位已下线）')
            .fontSize(15)
            .fontWeight(FontWeight.Medium)
            .fontColor(item.application.status === ApplicationStatus.REJECTED ? '#999999' : '#1A1A1A')
          Text(item.job ? item.job.companyName : '未知公司')
            .fontSize(12)
            .fontColor('#999999')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.getStatusConfig(item.application.status).icon + ' ' + this.getStatusConfig(item.application.status).label)
          .fontSize(11)
          .fontColor(this.getStatusConfig(item.application.status).color)
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(this.getStatusConfig(item.application.status).bg)
          .borderRadius(10)
      }
      .width('100%')
      .margin({ bottom: 8 })

      Row() {
        Text('投递于 ' + this.formatDate(item.application.applyTime))
          .fontSize(11)
          .fontColor('#CCCCCC')
          .layoutWeight(1)

        if (item.application.status === ApplicationStatus.VIEWED && item.application.viewTime) {
          Text('HR 查看于 ' + this.formatDateTime(item.application.viewTime))
            .fontSize(11)
            .fontColor('#FAAD14')
        }

        if (item.application.status === ApplicationStatus.INTERVIEW && item.application.interviewTime) {
          Text('面试 ' + this.formatDateTime(item.application.interviewTime))
            .fontSize(11)
            .fontColor('#52C41A')
        }
      }
      .width('100%')
      .margin({ bottom: 6 })

      if (item.application.status === ApplicationStatus.REJECTED && item.application.rejectionReason) {
        Row() {
          Text('HR反馈：')
            .fontSize(11)
            .fontColor('#FF4D4F')
          Text(this.getRejectionReasonLabel(item.application.rejectionReason))
            .fontSize(11)
            .fontColor('#FF8080')
        }
        .width('100%')
        .padding({ top: 6, bottom: 6 })
        .padding({ left: 8 })
        .backgroundColor('#FFF5F5')
        .borderRadius(6)
        .margin({ bottom: 6 })
      }

      if (item.application.status === ApplicationStatus.INTERVIEW) {
        Row() {
          Blank()
          Button('接受面试')
            .fontSize(12)
            .height(28)
            .backgroundColor(AppConstants.COLOR_SUCCESS)
            .fontColor('#FFFFFF')
            .borderRadius(14)
            .padding({ left: 14, right: 14 })
            .margin({ right: 8 })
          Button('婉拒')
            .fontSize(12)
            .height(28)
            .backgroundColor('#F5F5F5')
            .fontColor('#999999')
            .borderRadius(14)
            .padding({ left: 14, right: 14 })
        }
        .width('100%')
        .margin({ top: 4 })
      }

      if (item.job && item.application.status !== ApplicationStatus.REJECTED) {
        Button('查看详情')
          .fontSize(11)
          .height(28)
          .backgroundColor('#F5F5F5')
          .fontColor('#666666')
          .borderRadius(14)
          .padding({ left: 12, right: 12 })
          .alignSelf(ItemAlign.End)
          .margin({ top: 6 })
          .onClick(() => {
            router.pushUrl({ url: AppConstants.ROUTE_JOB_DETAIL, params: { jobId: item.job!.jobId } })
          })
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .margin({ bottom: 12 })
    .shadow({ radius: 4, color: '#08000000', offsetY: 2 })
  }
}
