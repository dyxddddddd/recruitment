import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { JobCategory, JobPosition } from '../../model/JobModel'
import { CourseSchedule, FreeTimeSlot } from '../../model/ResumeModel'
import { JobDao } from '../../service/JobDao'
import { ResumeDao } from '../../service/ResumeDao'

@Component
export struct JobSeekerJobsTab {
  @State categoryIndex: number = 0
  @State jobList: JobPosition[] = []
  @State isSearchVisible: boolean = false
  @State searchKeyword: string = ''
  @State schedule: CourseSchedule | null = null

  private jobDao: JobDao = new JobDao()
  private resumeDao: ResumeDao = new ResumeDao()

  aboutToAppear(): void {
    this.loadJobs()
    this.loadSchedule()
  }

  async loadSchedule(): Promise<void> {
    if (AppState.currentUser) {
      this.schedule = await this.resumeDao.getScheduleByUserId(AppState.currentUser.userId)
    }
  }

  async loadJobs(): Promise<void> {
    const category = this.categoryIndex === 1 ? JobCategory.FULLTIME_INTERN : JobCategory.MICRO_TASK
    this.jobList = this.searchKeyword.trim()
      ? await this.jobDao.searchJobs(this.searchKeyword.trim())
      : await this.jobDao.queryJobs(category)
  }

  handleJobClick(job: JobPosition): void {
    router.pushUrl({ url: AppConstants.ROUTE_JOB_DETAIL, params: { jobId: job.jobId } })
  }

  buildJobScene(job: JobPosition): string {
    const text = `${job.title} ${job.description} ${job.workAddress} ${(job.tags || []).join(' ')}`
    return text.toLowerCase()
  }

  hasWeekendSlot(slots: FreeTimeSlot[]): boolean {
    return slots.some((slot) => slot.dayOfWeek === 0 || slot.dayOfWeek === 6)
  }

  hasEveningSlot(slots: FreeTimeSlot[]): boolean {
    return slots.some((slot) => slot.endPeriod >= 7)
  }

  hasLongSlot(slots: FreeTimeSlot[]): boolean {
    return slots.some((slot) => slot.endPeriod - slot.startPeriod >= 3)
  }

  hasWeekdaySlot(slots: FreeTimeSlot[]): boolean {
    return slots.some((slot) => slot.dayOfWeek >= 1 && slot.dayOfWeek <= 5)
  }

  isTimeMatch(job: JobPosition): boolean {
    if (!this.schedule || this.schedule.freeSlots.length === 0 || job.category !== JobCategory.MICRO_TASK) {
      return false
    }
    const slots = this.schedule.freeSlots
    const scene = this.buildJobScene(job)
    if (scene.includes('周末')) {
      return this.hasWeekendSlot(slots)
    }
    if (scene.includes('晚') || scene.includes('夜')) {
      return this.hasEveningSlot(slots)
    }
    if (scene.includes('全天')) {
      return this.hasLongSlot(slots)
    }
    if (scene.includes('远程')) {
      return this.hasWeekdaySlot(slots) || this.hasWeekendSlot(slots)
    }
    return this.hasWeekdaySlot(slots)
  }

  build() {
    Column() {
      if (this.isSearchVisible) {
        Row() {
          TextInput({ placeholder: '搜索职位/企业/技能...', text: this.searchKeyword })
            .layoutWeight(1)
            .height(36)
            .fontSize(13)
            .backgroundColor('#F0F0F0')
            .borderRadius(18)
            .padding({ left: 16 })
            .onChange((v: string) => { this.searchKeyword = v })
            .onSubmit(() => this.loadJobs())
          Button('搜索')
            .fontSize(13)
            .height(32)
            .backgroundColor(AppConstants.COLOR_PRIMARY)
            .fontColor('#FFFFFF')
            .borderRadius(16)
            .padding({ left: 14, right: 14 })
            .margin({ left: 8 })
            .onClick(() => this.loadJobs())
          Button('取消')
            .fontSize(13)
            .height(32)
            .backgroundColor('#F5F5F5')
            .fontColor('#666666')
            .borderRadius(16)
            .padding({ left: 12, right: 12 })
            .margin({ left: 4 })
            .onClick(() => {
              this.isSearchVisible = false
              this.searchKeyword = ''
              this.loadJobs()
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 8, bottom: 8 })
      } else {
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
            .onClick(() => { this.isSearchVisible = true })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      }

      if (this.jobList.length === 0) {
        Column() {
          Text('🔍')
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
        if (this.isTimeMatch(job)) {
          Text('🟢 时间完美吻合')
            .fontSize(10)
            .fontColor('#52C41A')
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor('rgba(82,196,26,0.1)')
            .borderRadius(8)
            .margin({ right: 6 })
        }

        ForEach(job.tags, (tag: string) => {
          Text(tag)
            .fontSize(10)
            .fontColor(AppConstants.COLOR_PRIMARY)
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
