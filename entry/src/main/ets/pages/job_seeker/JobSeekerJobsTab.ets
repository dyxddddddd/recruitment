import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { StudentType } from '../../model/UserModel'
import { JobCategory, JobPosition } from '../../model/JobModel'
import { CourseSchedule, FreeTimeSlot } from '../../model/ResumeModel'
import { JobDao } from '../../service/JobDao'
import { ResumeDao } from '../../service/ResumeDao'

type StudentTaskFilterMode = 'all' | 'matched'

interface JobTimeRequirement {
  dayOfWeek: number
  startMinutes: number
  endMinutes: number
}

@Component
export struct JobSeekerJobsTab {
  @State categoryIndex: number = 0
  @State jobList: JobPosition[] = []
  @State isSearchVisible: boolean = false
  @State searchKeyword: string = ''
  @State schedule: CourseSchedule | null = null
  @State isCurrentStudent: boolean = AppState.currentUser?.studentType !== StudentType.GRADUATING
  @State studentFilterMode: StudentTaskFilterMode = 'all'

  private jobDao: JobDao = new JobDao()
  private resumeDao: ResumeDao = new ResumeDao()

  aboutToAppear(): void {
    this.isCurrentStudent = AppState.currentUser?.studentType !== StudentType.GRADUATING
    this.categoryIndex = this.isCurrentStudent ? 0 : this.categoryIndex
    this.loadSchedule()
    this.loadJobs()
  }

  async loadSchedule(): Promise<void> {
    if (AppState.currentUser) {
      this.schedule = await this.resumeDao.getScheduleByUserId(AppState.currentUser.userId)
    }
  }

  async loadJobs(): Promise<void> {
    const category = this.categoryIndex === 1 ? JobCategory.FULLTIME_INTERN : JobCategory.MICRO_TASK
    const sourceJobs = this.searchKeyword.trim()
      ? await this.jobDao.searchJobs(this.searchKeyword.trim())
      : await this.jobDao.queryJobs(category)

    let nextJobs = sourceJobs
    if (this.isCurrentStudent) {
      nextJobs = nextJobs.filter((job: JobPosition) => job.category === JobCategory.MICRO_TASK)
    }
    if (category === JobCategory.MICRO_TASK && this.studentFilterMode === 'matched') {
      nextJobs = nextJobs.filter((job: JobPosition) => this.isTimeMatch(job))
    }
    this.jobList = nextJobs
  }

  handleJobClick(job: JobPosition): void {
    router.pushUrl({ url: AppConstants.ROUTE_JOB_DETAIL, params: { jobId: job.jobId } })
  }

  private slotToMinutes(hour?: number, minute?: number, fallback: number = 0): number {
    const safeHour = hour === undefined ? fallback : hour
    const safeMinute = minute === undefined ? 0 : minute
    return safeHour * 60 + safeMinute
  }

  private buildJobScene(job: JobPosition): string {
    const tagsText = (job.tags || []).join(' ')
    return `${job.title} ${job.description} ${job.workAddress} ${tagsText}`.toLowerCase()
  }

  private hasAnyAvailability(): boolean {
    return !!this.schedule && this.schedule.freeSlots.length > 0
  }

  private matchSlotWithRequirement(slot: FreeTimeSlot, requiredStartHour: number, requiredEndHour: number): boolean {
    const slotStart = this.slotToMinutes(slot.startHour, slot.startMinute, 0)
    const slotEnd = this.slotToMinutes(slot.endHour, slot.endMinute, 23)
    const requiredStart = requiredStartHour * 60
    const requiredEnd = requiredEndHour * 60
    return slotStart <= requiredStart && slotEnd >= requiredEnd
  }

  private matchSlotWithMinutes(slot: FreeTimeSlot, requiredStartMinutes: number, requiredEndMinutes: number): boolean {
    const slotStart = this.slotToMinutes(slot.startHour, slot.startMinute, 0)
    const slotEnd = this.slotToMinutes(slot.endHour, slot.endMinute, 23)
    return slotStart <= requiredStartMinutes && slotEnd >= requiredEndMinutes
  }

  private deriveRequirementFromTaskTime(job: JobPosition): JobTimeRequirement | null {
    if (job.taskStartTime === undefined || job.taskEndTime === undefined || job.taskStartTime < 0 || job.taskEndTime < 0) {
      return null
    }
    const startDate = new Date(job.taskStartTime)
    const endDate = new Date(job.taskEndTime)
    const requirement: JobTimeRequirement = {
      dayOfWeek: startDate.getDay(),
      startMinutes: startDate.getHours() * 60 + startDate.getMinutes(),
      endMinutes: endDate.getHours() * 60 + endDate.getMinutes()
    }
    return requirement
  }

  private inferMatchFromText(job: JobPosition, slots: FreeTimeSlot[]): boolean {
    const scene = this.buildJobScene(job)
    if (scene.includes('周末')) {
      return slots.some((slot: FreeTimeSlot) => slot.dayOfWeek === 6 || slot.dayOfWeek === 0)
    }
    if (scene.includes('晚上') || scene.includes('夜间')) {
      return slots.some((slot: FreeTimeSlot) => (slot.endHour ?? 0) >= 21)
    }
    if (scene.includes('远程')) {
      return slots.length > 0
    }
    return slots.length > 0
  }

  isTimeMatch(job: JobPosition): boolean {
    if (job.category !== JobCategory.MICRO_TASK) {
      return false
    }
    if (!this.hasAnyAvailability()) {
      return false
    }
    const slots = this.schedule ? this.schedule.freeSlots : []
    const taskRequirement = this.deriveRequirementFromTaskTime(job)
    if (taskRequirement) {
      return slots.some((slot: FreeTimeSlot) => slot.dayOfWeek === taskRequirement.dayOfWeek
        && this.matchSlotWithMinutes(slot, taskRequirement.startMinutes, taskRequirement.endMinutes))
    }
    if (job.requiredDayOfWeek !== undefined && job.requiredStartHour !== undefined && job.requiredEndHour !== undefined) {
      return slots.some((slot: FreeTimeSlot) => slot.dayOfWeek === job.requiredDayOfWeek
        && this.matchSlotWithRequirement(slot, job.requiredStartHour || 0, job.requiredEndHour || 24))
    }
    return this.inferMatchFromText(job, slots)
  }

  private async setStudentFilterMode(mode: StudentTaskFilterMode): Promise<void> {
    this.studentFilterMode = mode
    if (mode === 'matched') {
      await this.loadSchedule()
    }
    this.loadJobs()
  }

  private formatDateTime(timestamp?: number): string {
    if (timestamp === undefined || timestamp < 0) {
      return ''
    }
    const date = new Date(timestamp)
    const year = date.getFullYear()
    const month = `${date.getMonth() + 1}`.padStart(2, '0')
    const day = `${date.getDate()}`.padStart(2, '0')
    const hour = `${date.getHours()}`.padStart(2, '0')
    const minute = `${date.getMinutes()}`.padStart(2, '0')
    return `${year}-${month}-${day} ${hour}:${minute}`
  }

  private taskTimeText(job: JobPosition): string {
    if (job.taskStartTime === undefined || job.taskEndTime === undefined || job.taskStartTime < 0 || job.taskEndTime < 0) {
      return ''
    }
    return `${this.formatDateTime(job.taskStartTime)} - ${this.formatDateTime(job.taskEndTime)}`
  }

  build() {
    Column() {
      if (this.isSearchVisible) {
        Row() {
          TextInput({ placeholder: '搜索职位 / 企业 / 技能', text: this.searchKeyword })
            .layoutWeight(1)
            .height(36)
            .fontSize(13)
            .backgroundColor('#F0F0F0')
            .borderRadius(18)
            .padding({ left: 16 })
            .onChange((value: string) => { this.searchKeyword = value })
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
      } else if (this.isCurrentStudent) {
        Column() {
          Row() {
            Column() {
              Text('微任务 / 短期兼职')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1A1A1A')
              Text('默认展示全部微任务；若未填写弹性工时，"仅看时间匹配" 会视为当前没有可匹配空闲时间。')
                .fontSize(11)
                .fontColor('#667085')
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            Blank()
            Image($r('sys.symbol.magnifyingglass'))
              .width(20)
              .height(20)
              .fillColor('#666666')
              .onClick(() => { this.isSearchVisible = true })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 8 })

          Row() {
            Button('全部微任务')
              .fontSize(12)
              .height(34)
              .backgroundColor(this.studentFilterMode === 'all' ? AppConstants.COLOR_PRIMARY : '#F5F5F5')
              .fontColor(this.studentFilterMode === 'all' ? '#FFFFFF' : '#666666')
              .borderRadius(17)
              .padding({ left: 16, right: 16 })
              .onClick(() => this.setStudentFilterMode('all'))
            Button('仅看时间匹配')
              .fontSize(12)
              .height(34)
              .backgroundColor(this.studentFilterMode === 'matched' ? '#2E8B57' : '#F5F5F5')
              .fontColor(this.studentFilterMode === 'matched' ? '#FFFFFF' : '#666666')
              .borderRadius(17)
              .padding({ left: 16, right: 16 })
              .margin({ left: 8 })
              .onClick(() => this.setStudentFilterMode('matched'))
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 8 })
        }
      } else {
        Row() {
          Button('微任务 / 短期兼职')
            .fontSize(13)
            .height(34)
            .backgroundColor(this.categoryIndex === 0 ? AppConstants.COLOR_PRIMARY : '#F5F5F5')
            .fontColor(this.categoryIndex === 0 ? '#FFFFFF' : '#666666')
            .borderRadius(17)
            .padding({ left: 16, right: 16 })
            .onClick(() => {
              this.categoryIndex = 0
              this.loadJobs()
            })

          Button('全职 / 转正实习')
            .fontSize(13)
            .height(34)
            .backgroundColor(this.categoryIndex === 1 ? AppConstants.COLOR_PRIMARY : '#F5F5F5')
            .fontColor(this.categoryIndex === 1 ? '#FFFFFF' : '#666666')
            .borderRadius(17)
            .padding({ left: 16, right: 16 })
            .margin({ left: 8 })
            .onClick(() => {
              this.categoryIndex = 1
              this.loadJobs()
            })

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
          Text(this.categoryIndex === 0 && this.studentFilterMode === 'matched'
            ? (this.hasAnyAvailability() ? '暂时没有和你空闲时间匹配的微任务' : '你还没有填写弹性工时，当前默认视为没有空闲时间')
            : '暂时没有合适职位')
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
          if (this.categoryIndex === 0 && this.taskTimeText(job)) {
            Text(this.taskTimeText(job))
              .fontSize(11)
              .fontColor('#667085')
              .margin({ top: 6 })
              .maxLines(2)
          }
        }
        .alignItems(HorizontalAlign.Start)

        Blank()

        Column() {
          Text(job.salaryRange)
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppConstants.COLOR_ACCENT)
          Text(job.category === JobCategory.MICRO_TASK ? '按件 / 按任务计薪' : job.city)
            .fontSize(11)
            .fontColor('#999999')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .margin({ bottom: 10 })

      Row() {
        if (job.category === JobCategory.MICRO_TASK && this.isTimeMatch(job)) {
          Text('时间可匹配')
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
          Text(`${job.applyCount} 人已投递`)
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
