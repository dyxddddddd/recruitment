import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { CourseSchedule, FreeTimeSlot, ResumeInfo } from '../../model/ResumeModel'
import { StudentType } from '../../model/UserModel'
import { CampusAIService } from '../../service/CampusAIService'
import { PickerService } from '../../service/PickerService'
import { ResumeDao } from '../../service/ResumeDao'
import { ScheduleVisionParseService } from '../../service/ScheduleVisionParseService'

interface DaySlotGroup {
  dayOfWeek: number
  label: string
  slots: FreeTimeSlot[]
}

interface TimeOption {
  label: string
  hour: number
  minute: number
}

interface MenuActionItem {
  value: string
  action: () => void
}

@Entry
@Component
struct FlexWorkCalendarPage {
  @State scheduleSummary: string = '暂未设置弹性工时'
  @State parsedFreeSlots: FreeTimeSlot[] = []
  @State importedScheduleImage: string = ''
  @State scheduleText: string = ''
  @State isParsingSchedule: boolean = false
  @State daySlots: DaySlotGroup[] = []
  @State canImportSchedule: boolean = AppState.currentUser?.studentType !== StudentType.GRADUATING

  private resumeDao: ResumeDao = new ResumeDao()

  aboutToAppear(): void {
    this.canImportSchedule = AppState.currentUser?.studentType !== StudentType.GRADUATING
    this.daySlots = this.createEmptyDaySlots()
    this.loadSchedule()
  }

  private createDaySlotGroup(dayOfWeek: number, label: string): DaySlotGroup {
    return { dayOfWeek: dayOfWeek, label: label, slots: [] }
  }

  private createTimeOption(label: string, hour: number, minute: number): TimeOption {
    return { label: label, hour: hour, minute: minute }
  }

  private createMenuActionItem(value: string, action: () => void): MenuActionItem {
    return { value: value, action: action }
  }

  private createEmptyDaySlots(): DaySlotGroup[] {
    const result: DaySlotGroup[] = []
    result.push(this.createDaySlotGroup(1, '周一'))
    result.push(this.createDaySlotGroup(2, '周二'))
    result.push(this.createDaySlotGroup(3, '周三'))
    result.push(this.createDaySlotGroup(4, '周四'))
    result.push(this.createDaySlotGroup(5, '周五'))
    result.push(this.createDaySlotGroup(6, '周六'))
    result.push(this.createDaySlotGroup(0, '周日'))
    return result
  }

  private normalizeNumber(value: number | undefined, fallback: number, min: number, max: number): number {
    if (value === undefined || Number.isNaN(value)) {
      return fallback
    }
    if (value < min) {
      return min
    }
    if (value > max) {
      return max
    }
    return value
  }

  private periodToMinutes(period: number): number {
    switch (period) {
      case 1:
        return 8 * 60
      case 2:
        return 9 * 60
      case 3:
        return 10 * 60
      case 4:
        return 11 * 60
      case 5:
        return 14 * 60
      case 6:
        return 15 * 60
      case 7:
        return 16 * 60
      case 8:
        return 17 * 60
      case 9:
        return 19 * 60
      case 10:
        return 20 * 60
      default:
        return 9 * 60
    }
  }

  private findDayLabel(dayOfWeek: number): string {
    for (let i = 0; i < this.daySlots.length; i++) {
      if (this.daySlots[i].dayOfWeek === dayOfWeek) {
        return this.daySlots[i].label
      }
    }
    const defaults = this.createEmptyDaySlots()
    for (let i = 0; i < defaults.length; i++) {
      if (defaults[i].dayOfWeek === dayOfWeek) {
        return defaults[i].label
      }
    }
    return '周?'
  }

  private normalizeSlot(dayOfWeek: number, startHour?: number, startMinute?: number, endHour?: number, endMinute?: number,
    startPeriod?: number, endPeriod?: number): FreeTimeSlot {
    let startMinutes = this.normalizeNumber(startHour, 9, 0, 23) * 60 + this.normalizeNumber(startMinute, 0, 0, 59)
    let endMinutes = this.normalizeNumber(endHour, 18, 0, 23) * 60 + this.normalizeNumber(endMinute, 0, 0, 59)
    if (startPeriod !== undefined && endPeriod !== undefined) {
      startMinutes = this.periodToMinutes(startPeriod)
      endMinutes = this.periodToMinutes(endPeriod) + 60
    }
    if (endMinutes <= startMinutes) {
      endMinutes = Math.min(startMinutes + 60, 23 * 60 + 59)
    }
    const normalizedStartHour = Math.floor(startMinutes / 60)
    const normalizedStartMinute = startMinutes % 60
    const normalizedEndHour = Math.floor(endMinutes / 60)
    const normalizedEndMinute = endMinutes % 60
    return {
      dayOfWeek: dayOfWeek,
      startHour: normalizedStartHour,
      startMinute: normalizedStartMinute,
      endHour: normalizedEndHour,
      endMinute: normalizedEndMinute,
      startPeriod: startPeriod,
      endPeriod: endPeriod,
      label: `${this.findDayLabel(dayOfWeek)} ${this.formatTime(normalizedStartHour, normalizedStartMinute)}-${this.formatTime(normalizedEndHour, normalizedEndMinute)}`
    }
  }

  private createDefaultSlot(dayOfWeek: number): FreeTimeSlot {
    return this.normalizeSlot(dayOfWeek, 9, 0, 18, 0)
  }

  private buildDaySlots(slots: FreeTimeSlot[]): DaySlotGroup[] {
    const result = this.createEmptyDaySlots()
    for (let i = 0; i < slots.length; i++) {
      const slot = slots[i]
      const normalized = this.normalizeSlot(
        slot.dayOfWeek,
        slot.startHour,
        slot.startMinute,
        slot.endHour,
        slot.endMinute,
        slot.startPeriod,
        slot.endPeriod
      )
      for (let j = 0; j < result.length; j++) {
        if (result[j].dayOfWeek === normalized.dayOfWeek) {
          result[j].slots.push(normalized)
          break
        }
      }
    }
    return result
  }

  private rebuildFreeSlots(): void {
    const allSlots: FreeTimeSlot[] = []
    for (let i = 0; i < this.daySlots.length; i++) {
      const dayItem = this.daySlots[i]
      for (let j = 0; j < dayItem.slots.length; j++) {
        const slot = dayItem.slots[j]
        allSlots.push(this.normalizeSlot(
          dayItem.dayOfWeek,
          slot.startHour,
          slot.startMinute,
          slot.endHour,
          slot.endMinute,
          slot.startPeriod,
          slot.endPeriod
        ))
      }
    }
    this.daySlots = this.buildDaySlots(allSlots)
    this.parsedFreeSlots = allSlots
    this.scheduleSummary = this.buildScheduleSummary(allSlots)
  }

  private buildScheduleSummary(slots: FreeTimeSlot[]): string {
    if (slots.length === 0) {
      return '暂未设置弹性工时'
    }
    const parts: string[] = []
    for (let i = 0; i < slots.length && i < 5; i++) {
      parts.push(slots[i].label)
    }
    if (slots.length > 5) {
      parts.push(`等 ${slots.length} 个时段`)
    }
    return parts.join('、')
  }

  private buildTimeOptions(): TimeOption[] {
    const result: TimeOption[] = []
    result.push(this.createTimeOption('08:00', 8, 0))
    result.push(this.createTimeOption('09:00', 9, 0))
    result.push(this.createTimeOption('10:00', 10, 0))
    result.push(this.createTimeOption('11:00', 11, 0))
    result.push(this.createTimeOption('12:00', 12, 0))
    result.push(this.createTimeOption('13:00', 13, 0))
    result.push(this.createTimeOption('14:00', 14, 0))
    result.push(this.createTimeOption('15:00', 15, 0))
    result.push(this.createTimeOption('16:00', 16, 0))
    result.push(this.createTimeOption('17:00', 17, 0))
    result.push(this.createTimeOption('18:00', 18, 0))
    result.push(this.createTimeOption('19:00', 19, 0))
    result.push(this.createTimeOption('20:00', 20, 0))
    result.push(this.createTimeOption('21:00', 21, 0))
    result.push(this.createTimeOption('22:00', 22, 0))
    result.push(this.createTimeOption('23:00', 23, 0))
    result.push(this.createTimeOption('23:30', 23, 30))
    return result
  }

  private buildMenuActionItems(dayOfWeek: number, slotIndex: number, isStart: boolean): MenuActionItem[] {
    const options = this.buildTimeOptions()
    const result: MenuActionItem[] = []
    for (let i = 0; i < options.length; i++) {
      const option = options[i]
      result.push(this.createMenuActionItem(option.label, () => {
        this.updateSlotTime(dayOfWeek, slotIndex, isStart ? 'startHour' : 'endHour', option.hour)
        this.updateSlotTime(dayOfWeek, slotIndex, isStart ? 'startMinute' : 'endMinute', option.minute)
      }))
    }
    return result
  }

  async loadSchedule(): Promise<void> {
    if (!AppState.currentUser) {
      return
    }
    const schedule = await this.resumeDao.getScheduleByUserId(AppState.currentUser.userId)
    if (schedule && schedule.freeSlots.length > 0) {
      this.parsedFreeSlots = schedule.freeSlots
      this.daySlots = this.buildDaySlots(schedule.freeSlots)
      this.scheduleSummary = this.buildScheduleSummary(schedule.freeSlots)
      return
    }
    this.parsedFreeSlots = []
    this.daySlots = this.createEmptyDaySlots()
    this.scheduleSummary = '暂未设置弹性工时'
  }

  addSlot(dayOfWeek: number): void {
    for (let i = 0; i < this.daySlots.length; i++) {
      if (this.daySlots[i].dayOfWeek === dayOfWeek) {
        this.daySlots[i].slots.push(this.createDefaultSlot(dayOfWeek))
        break
      }
    }
    this.rebuildFreeSlots()
  }

  removeSlot(dayOfWeek: number, slotIndex: number): void {
    for (let i = 0; i < this.daySlots.length; i++) {
      if (this.daySlots[i].dayOfWeek === dayOfWeek) {
        this.daySlots[i].slots.splice(slotIndex, 1)
        break
      }
    }
    this.rebuildFreeSlots()
  }

  updateSlotTime(dayOfWeek: number, slotIndex: number, field: string, value: number): void {
    for (let i = 0; i < this.daySlots.length; i++) {
      if (this.daySlots[i].dayOfWeek !== dayOfWeek) {
        continue
      }
      if (slotIndex < 0 || slotIndex >= this.daySlots[i].slots.length) {
        return
      }
      const slot = this.daySlots[i].slots[slotIndex]
      if (field === 'startHour') {
        slot.startHour = value
      } else if (field === 'startMinute') {
        slot.startMinute = value
      } else if (field === 'endHour') {
        slot.endHour = value
      } else if (field === 'endMinute') {
        slot.endMinute = value
      }
      break
    }
    this.rebuildFreeSlots()
  }

  clearAllSlots(): void {
    this.daySlots = this.createEmptyDaySlots()
    this.parsedFreeSlots = []
    this.scheduleText = ''
    this.scheduleSummary = '暂未设置弹性工时'
  }

  applyQuickSelect(mode: string): void {
    const next = this.createEmptyDaySlots()
    for (let i = 0; i < next.length; i++) {
      const day = next[i]
      if (mode === 'weekday' && day.dayOfWeek >= 1 && day.dayOfWeek <= 5) {
        day.slots.push(this.normalizeSlot(day.dayOfWeek, 9, 0, 18, 0))
      } else if (mode === 'weekend' && (day.dayOfWeek === 6 || day.dayOfWeek === 0)) {
        day.slots.push(this.normalizeSlot(day.dayOfWeek, 9, 0, 18, 0))
      } else if (mode === 'evening') {
        day.slots.push(this.normalizeSlot(day.dayOfWeek, 19, 0, 22, 0))
      }
    }
    this.daySlots = next
    this.rebuildFreeSlots()
  }

  async importScheduleImage(): Promise<void> {
    if (!this.canImportSchedule) {
      AlertDialog.show({ message: '应届生无需导入课表，请直接手动设置每周可接单时间。' })
      return
    }
    try {
      this.importedScheduleImage = await PickerService.pickSingleImage()
      this.isParsingSchedule = true
      const result = await ScheduleVisionParseService.analyzeScheduleImage(this.importedScheduleImage)
      const slots = result.freeSlots || []
      this.scheduleText = result.recognizedText || ''
      this.parsedFreeSlots = slots
      this.daySlots = this.buildDaySlots(slots)
      this.scheduleSummary = result.summary || this.buildScheduleSummary(slots)
    } catch (e) {
      AlertDialog.show({ message: e instanceof Error ? e.message : '课表识别失败，请重试' })
    } finally {
      this.isParsingSchedule = false
    }
  }

  async parseScheduleText(): Promise<void> {
    if (!this.canImportSchedule) {
      AlertDialog.show({ message: '应届生已关闭课表导入功能，请直接手动设置弹性工时。' })
      return
    }
    if (!this.scheduleText.trim()) {
      AlertDialog.show({ message: '请先上传课表图片，或手动粘贴课表文本' })
      return
    }
    try {
      this.isParsingSchedule = true
      const result = await CampusAIService.parseScheduleText(this.scheduleText.trim())
      const slots = result.freeSlots || []
      this.parsedFreeSlots = slots
      this.daySlots = this.buildDaySlots(slots)
      this.scheduleSummary = result.summary || this.buildScheduleSummary(slots)
      AlertDialog.show({ message: `已识别 ${slots.length} 个空闲时段` })
    } catch (e) {
      AlertDialog.show({ message: e instanceof Error ? e.message : '课表解析失败，请稍后重试' })
    } finally {
      this.isParsingSchedule = false
    }
  }

  async saveSchedule(): Promise<void> {
    if (!AppState.currentUser) {
      AlertDialog.show({ message: '请先登录后再设置弹性工时日历' })
      return
    }
    this.rebuildFreeSlots()
    const scheduleId = 'schedule_' + AppState.currentUser.userId
    const schedule: CourseSchedule = {
      scheduleId: scheduleId,
      userId: AppState.currentUser.userId,
      semesters: [],
      freeSlots: this.parsedFreeSlots,
      updateTime: Date.now()
    }
    await this.resumeDao.saveSchedule(schedule)
    const existingResume = await this.resumeDao.getResumeByUserId(AppState.currentUser.userId)
    const nextResume = existingResume
      ? this.cloneResumeWithSchedule(existingResume, scheduleId, this.parsedFreeSlots.length > 0)
      : this.createResumeSnapshot(scheduleId, this.parsedFreeSlots.length > 0)
    await this.resumeDao.upsertResume(nextResume)
    await this.resumeDao.replaceEducationList(nextResume.resumeId, nextResume.educationList)
    await this.resumeDao.replaceExperienceList(nextResume.resumeId, nextResume.experienceList)
    AlertDialog.show({ message: '弹性工时日历已保存，职位广场可以按你的空闲时间筛选微任务了' })
  }

  private cloneResumeWithSchedule(resume: ResumeInfo, scheduleId: string, hasSchedule: boolean): ResumeInfo {
    return {
      resumeId: resume.resumeId,
      userId: resume.userId,
      realName: resume.realName,
      gender: resume.gender,
      birthday: resume.birthday,
      education: resume.education,
      school: resume.school,
      major: resume.major,
      graduationYear: resume.graduationYear,
      expectedPosition: resume.expectedPosition,
      expectedSalary: resume.expectedSalary,
      currentCity: resume.currentCity,
      phone: resume.phone,
      email: resume.email,
      skills: resume.skills,
      selfIntro: resume.selfIntro,
      educationList: resume.educationList,
      experienceList: resume.experienceList,
      isFromPDF: resume.isFromPDF,
      pdfUncertainFields: resume.pdfUncertainFields,
      hasSchedule: hasSchedule,
      scheduleId: scheduleId,
      updateTime: Date.now()
    }
  }

  private createResumeSnapshot(scheduleId: string, hasSchedule: boolean): ResumeInfo {
    return {
      resumeId: `resume_${AppState.currentUser?.userId || Date.now().toString()}`,
      userId: AppState.currentUser?.userId || '',
      realName: AppState.currentUser?.realName || '',
      gender: AppState.currentUser?.gender || '',
      birthday: AppState.currentUser?.birthday || '',
      education: AppState.currentUser?.education || '',
      school: AppState.currentUser?.school || '',
      major: AppState.currentUser?.major || '',
      graduationYear: '',
      expectedPosition: AppState.currentUser?.expectedPosition || '',
      expectedSalary: AppState.currentUser?.expectedSalary || '',
      currentCity: AppState.currentUser?.currentCity || '',
      phone: AppState.currentUser?.phone || '',
      email: '',
      skills: [],
      selfIntro: '',
      educationList: [],
      experienceList: [],
      isFromPDF: false,
      pdfUncertainFields: [],
      hasSchedule: hasSchedule,
      scheduleId: scheduleId,
      updateTime: Date.now()
    }
  }

  formatTime(hour?: number, minute?: number): string {
    const safeHour = this.normalizeNumber(hour, 0, 0, 23)
    const safeMinute = this.normalizeNumber(minute, 0, 0, 59)
    return `${safeHour.toString().padStart(2, '0')}:${safeMinute.toString().padStart(2, '0')}`
  }

  @Builder
  TimeRangePicker(dayOfWeek: number, slotIndex: number, slot: FreeTimeSlot) {
    Row() {
      this.TimePickerMenu(dayOfWeek, slotIndex, slot, true)
      Text('至')
        .fontSize(13)
        .fontColor('#667085')
        .margin({ left: 8, right: 8 })
      this.TimePickerMenu(dayOfWeek, slotIndex, slot, false)
      Blank()
      Text('清除')
        .fontSize(12)
        .fontColor('#D9485F')
        .padding({ left: 8, right: 8, top: 6, bottom: 6 })
        .backgroundColor('#FFF1F3')
        .borderRadius(10)
        .margin({ right: 8 })
        .onClick(() => this.removeSlot(dayOfWeek, slotIndex))
      Image($r('sys.symbol.xmark_circle_fill'))
        .width(18)
        .height(18)
        .fillColor('#FF6B6B')
        .onClick(() => this.removeSlot(dayOfWeek, slotIndex))
    }
    .width('100%')
  }

  @Builder
  TimePickerMenu(dayOfWeek: number, slotIndex: number, slot: FreeTimeSlot, isStart: boolean) {
    Text(this.formatTime(
      isStart ? slot.startHour : slot.endHour,
      isStart ? slot.startMinute : slot.endMinute
    ))
      .fontSize(13)
      .fontColor('#2E8B57')
      .fontWeight(FontWeight.Medium)
      .padding({ left: 10, right: 10, top: 8, bottom: 8 })
      .backgroundColor('#F0FFF4')
      .borderRadius(10)
      .bindMenu(this.buildMenuActionItems(dayOfWeek, slotIndex, isStart))
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

        Text('弹性工时日历')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button('保存')
          .fontSize(14)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .fontColor('#FFFFFF')
          .borderRadius(18)
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .onClick(() => this.saveSchedule())
      }
      .width('100%')
      .padding({ left: 8, right: 16, top: 52, bottom: 10 })
      .backgroundColor('#FFFFFF')

      Scroll() {
        Column() {
          Column() {
            Text('按小时设置每周空闲时间')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#123C2E')
              .alignSelf(ItemAlign.Start)
            Text(this.canImportSchedule
              ? '不设置也没关系，职位广场默认会先展示全部微任务。你也可以手动添加空闲时段，或上传教务课表截图，AI自动识别。'
              : '不设置也没关系，职位广场默认会先展示全部微任务。你可以直接手动添加每周空闲时段，用来筛选更适合你的微任务。')
              .fontSize(13)
              .fontColor('#667085')
              .lineHeight(22)
              .margin({ top: 8 })
              .alignSelf(ItemAlign.Start)
          }
          .width('100%')
          .padding(18)
          .backgroundColor('#EAF7EE')
          .borderRadius(18)

          Row() {
            Button('清空')
              .layoutWeight(1)
              .height(40)
              .fontSize(13)
              .backgroundColor('#FFF4EE')
              .fontColor(AppConstants.COLOR_ACCENT)
              .borderRadius(20)
              .onClick(() => this.clearAllSlots())
            if (this.canImportSchedule) {
              Button(this.isParsingSchedule ? '识别中...' : '导入课表图片')
                .layoutWeight(1)
                .height(40)
                .fontSize(13)
                .backgroundColor('#2E8B57')
                .fontColor('#FFFFFF')
                .borderRadius(20)
                .margin({ left: 10 })
                .enabled(!this.isParsingSchedule)
                .onClick(() => this.importScheduleImage())
            }
          }
          .width('100%')
          .margin({ top: 14 })

          Column() {
            Text('快捷设置')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .alignSelf(ItemAlign.Start)
            Row() {
              Button('工作日 09-18')
                .layoutWeight(1)
                .height(34)
                .fontSize(12)
                .backgroundColor('#F0F7FF')
                .fontColor(AppConstants.COLOR_PRIMARY)
                .borderRadius(17)
                .onClick(() => this.applyQuickSelect('weekday'))
              Button('周末 09-18')
                .layoutWeight(1)
                .height(34)
                .fontSize(12)
                .backgroundColor('#FFF4EE')
                .fontColor(AppConstants.COLOR_ACCENT)
                .borderRadius(17)
                .margin({ left: 8, right: 8 })
                .onClick(() => this.applyQuickSelect('weekend'))
              Button('晚上 19-22')
                .layoutWeight(1)
                .height(34)
                .fontSize(12)
                .backgroundColor('#EEF7F1')
                .fontColor('#2E8B57')
                .borderRadius(17)
                .onClick(() => this.applyQuickSelect('evening'))
            }
            .width('100%')
            .margin({ top: 10 })
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .margin({ top: 14 })

          ForEach(this.daySlots, (dayItem: DaySlotGroup) => {
            Column() {
              Row() {
                Text(dayItem.label)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1A1A1A')
                Blank()
                if (dayItem.slots.length > 0) {
                  Text(`${dayItem.slots.length} 个时段`)
                    .fontSize(11)
                    .fontColor('#2E8B57')
                    .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                    .backgroundColor('#EAF7EE')
                    .borderRadius(10)
                    .margin({ right: 8 })
                }
                Button('+ 添加时段')
                  .fontSize(12)
                  .backgroundColor('#2E8B57')
                  .fontColor('#FFFFFF')
                  .borderRadius(14)
                  .padding({ left: 12, right: 12, top: 4, bottom: 4 })
                  .onClick(() => this.addSlot(dayItem.dayOfWeek))
              }
              .width('100%')
              .margin({ bottom: 10 })

              if (dayItem.slots.length === 0) {
                Text('未填写时，系统默认你该天都无法接单。')
                  .fontSize(12)
                  .fontColor('#AAAAAA')
                  .width('100%')
                  .padding(12)
                  .backgroundColor('#F9F9F9')
                  .borderRadius(10)
                  .textAlign(TextAlign.Center)
              } else {
                ForEach(dayItem.slots, (slot: FreeTimeSlot, slotIndex: number) => {
                  Column() {
                    this.TimeRangePicker(dayItem.dayOfWeek, slotIndex, slot)
                  }
                  .width('100%')
                  .padding(10)
                  .backgroundColor('#F8FFFA')
                  .borderRadius(10)
                  .margin({ bottom: 8 })
                })
              }
            }
            .width('100%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
            .margin({ top: 10 })
          })

          if (this.canImportSchedule && this.importedScheduleImage) {
            Image(this.importedScheduleImage)
              .width('100%')
              .height(180)
              .objectFit(ImageFit.Contain)
              .borderRadius(12)
              .margin({ top: 16 })
          }

          Text(this.scheduleSummary)
            .fontSize(12)
            .fontColor('#466A54')
            .lineHeight(20)
            .padding(12)
            .width('100%')
            .backgroundColor('#F5FBF7')
            .borderRadius(10)
            .margin({ top: 12 })

          if (this.canImportSchedule) {
            TextArea({ text: this.scheduleText, placeholder: '你也可以手动粘贴教务课表文本或空闲时间描述，再点击重新解析。' })
              .width('100%')
              .height(160)
              .fontSize(13)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .padding(12)
              .margin({ top: 12 })
              .onChange((value: string) => { this.scheduleText = value })

            Button(this.isParsingSchedule ? '解析中...' : '重新解析文本')
              .width('100%')
              .height(42)
              .fontSize(14)
              .backgroundColor(AppConstants.COLOR_PRIMARY)
              .fontColor('#FFFFFF')
              .borderRadius(21)
              .margin({ top: 12, bottom: 24 })
              .enabled(!this.isParsingSchedule)
              .onClick(() => this.parseScheduleText())
          } else {
            Blank()
              .height(24)
          }
        }
        .padding({ left: 16, right: 16, top: 14 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F7F3')
  }
}
