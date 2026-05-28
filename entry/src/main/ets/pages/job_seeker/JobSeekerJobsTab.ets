// 求职者 - 职位广场页（Tab a: 职位）

import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { JobPosition, JobCategory, JobStatus } from '../../model/JobModel'
import { JobDao } from '../../service/JobDao'

@Component
export struct JobSeekerJobsTab {
  @State categoryIndex: number = 0
  @State jobList: JobPosition[] = []
  @State isRefreshing: boolean = false
  private jobDao: JobDao = new JobDao()

  aboutToAppear(): void {
    this.loadJobs()
  }

  async loadJobs(): Promise<void> {
    const category = this.categoryIndex === 1 ? JobCategory.FULLTIME_INTERN : JobCategory.MICRO_TASK
    this.jobList = await this.jobDao.queryJobs(category)
  }

  handleJobClick(job: JobPosition): void {
    if (AppState.isGuest) {
      AlertDialog.show({
        title: '登录提示',
        message: '投递简历需要登录，是否前往登录？',
        primaryButton: { value: '去登录', action: () => router.pushUrl({ url: AppConstants.ROUTE_LOGIN }) },
        secondaryButton: { value: '再逛逛', action: () => {} }
      })
      return
    }
    router.pushUrl({ url: AppConstants.ROUTE_JOB_DETAIL, params: { jobId: job.jobId } })
  }

  build() {
    Column() {
      // 分类切换开关
      Row() {
        Button('微任务/短期兼职')
          .fontSize(13)
          .height(34)
          .backgroundColor(this.categoryIndex === 0 ? AppConstants.COLOR_PRIMARY : '#F5F5F5')
          .fontColor(this.categoryIndex === 0 ? '#FFFFFF' : '#666666')
          .borderRadius(17)
          .padding({ left: 16, right: 16 })
          .onClick(() => { this.categoryIndex = 0; this.loadJobs() })

        Button('全职/转正实习')
          .fontSize(13)
          .height(34)
          .backgroundColor(this.categoryIndex === 1 ? AppConstants.COLOR_PRIMARY : '#F5F5F5')
          .fontColor(this.categoryIndex === 1 ? '#FFFFFF' : '#666666')
          .borderRadius(17)
          .padding({ left: 16, right: 16 })
          .margin({ left: 8 })
          .onClick(() => { this.categoryIndex = 1; this.loadJobs() })

        Blank()

        Image($r('sys.symbol.magnifyingglass'))
          .width(20)
          .height(20)
          .fillColor('#666666')
          .onClick(() => {
            // 搜索功能：可展开搜索框
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // 职位列表
      if (this.jobList.length === 0) {
        Column() {
          Text('📋')
            .fontSize(48)
            .margin({ bottom: 16 })
          Text('暂无合适的职位')
            .fontSize(14)
            .fontColor('#999999')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.jobList, (job: JobPosition) => {
            ListItem() {
              this.JobCardBuilder(job)
            }
            .margin({ bottom: 8 })
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 4 })
        .divider({ strokeWidth: 0.5, color: '#F0F0F0' })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  JobCardBuilder(job: JobPosition) {
    Column() {
      Row() {
        Column() {
          Text(job.title)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .maxLines(1)
          Text(job.companyName)
            .fontSize(13)
            .fontColor('#666666')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Column() {
          Text(job.salaryRange)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppConstants.COLOR_ACCENT)
          Text(job.city)
            .fontSize(11)
            .fontColor('#999999')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .margin({ bottom: 10 })

      Row() {
        ForEach(job.tags, (tag: string) => {
          Text(tag)
            .fontSize(10)
            .fontColor('#4A90D9')
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor('#F0F7FF')
            .borderRadius(8)
            .margin({ right: 6 })
        })

        Blank()

        if (job.applyCount > 0) {
          Text(`${job.applyCount}人已投递`)
            .fontSize(11)
            .fontColor('#999999')
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .onClick(() => this.handleJobClick(job))
  }
}
