import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { geoLocationManager } from '@kit.LocationKit'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { StudentType } from '../../model/UserModel'
import { CourseSchedule, EducationItem, ExperienceItem, FreeTimeSlot, ResumeInfo } from '../../model/ResumeModel'
import { CampusAIResumeParseResult, CampusAIService } from '../../service/CampusAIService'
import { DocumentParseService } from '../../service/DocumentParseService'
import { LocalFileService } from '../../service/LocalFileService'
import { PickerService } from '../../service/PickerService'
import { ResumeDao } from '../../service/ResumeDao'
import { UserDao } from '../../service/UserDao'
import { rewriteStudentExperience } from '../../service/AITranslateService'

interface SkillViewItem {
  id: string
  label: string
  index: number
}

interface EducationViewItem extends EducationItem {
  id: string
  index: number
}

interface ExperienceViewItem extends ExperienceItem {
  id: string
  index: number
}

interface ResumeEditRouteParams {
  openSchedule?: boolean
}

interface DaySlot {
  dayOfWeek: number
  label: string
  slots: FreeTimeSlot[]
}

const DAY_OPTIONS: DaySlot[] = [
  { dayOfWeek: 1, label: '周一', slots: [] },
  { dayOfWeek: 2, label: '周二', slots: [] },
  { dayOfWeek: 3, label: '周三', slots: [] },
  { dayOfWeek: 4, label: '周四', slots: [] },
  { dayOfWeek: 5, label: '周五', slots: [] },
  { dayOfWeek: 6, label: '周六', slots: [] },
  { dayOfWeek: 0, label: '周日', slots: [] },
]

interface BasicInfoFormState {
  realName: string
  phone: string
  email: string
  education: string
  currentCity: string
  school: string
  major: string
  graduationYear: string
  expectedPosition: string
  expectedSalary: string
}

@Entry
@Component
struct ResumeEditPage {
  @State resume: ResumeInfo = this.createEmptyResume()
  @State currentTab: number = 0
  @State isLocating: boolean = false
  @State isParsingResume: boolean = false
  @State isTranslatingExp: boolean = false
  @State translatingExpIndex: number = -1
  @State isParsingSchedule: boolean = false
  @State showResumeTextSheet: boolean = false
  @State resumeSourceText: string = ''
  @State showEduDialog: boolean = false
  @State showExpDialog: boolean = false
  @State showScheduleSheet: boolean = false
  @State skillInput: string = ''
  @State eduForm: EducationItem = this.emptyEducation()
  @State expForm: ExperienceItem = this.emptyExperience()
  @State eduEditIndex: number = -1
  @State expEditIndex: number = -1
  @State scheduleText: string = ''
  @State scheduleSummary: string = ''
  @State parsedFreeSlots: FreeTimeSlot[] = []
  @State basicInfoForm: BasicInfoFormState = this.emptyBasicInfoForm()
  @State importedDocumentName: string = ''
  @State importedScheduleImage: string = ''
  @State daySlots: DaySlot[] = []
  @State isStudentUser: boolean = AppState.currentUser?.studentType !== StudentType.GRADUATING
  @State formRenderKey: number = 0
  @State showFormShell: boolean = true
  @State basicInfoRenderFlip: boolean = false

  private tabsController: TabsController = new TabsController()
  private resumeDao: ResumeDao = new ResumeDao()
  private userDao: UserDao = new UserDao()

  aboutToAppear(): void {
    this.isStudentUser = AppState.currentUser?.studentType !== StudentType.GRADUATING
    this.loadResume()
    this.autoFillCity()
  }

  openScheduleFromRoute(): void {
    const params = router.getParams() as ResumeEditRouteParams
    if (params.openSchedule && this.isStudentUser) {
      setTimeout(() => {
        router.pushUrl({ url: AppConstants.ROUTE_FLEX_WORK_CALENDAR })
      }, 0)
    }
  }

  createEmptyResume(): ResumeInfo {
    return {
      resumeId: 'resume_' + Date.now(),
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
      hasSchedule: false,
      scheduleId: '',
      updateTime: Date.now()
    }
  }

  emptyEducation(): EducationItem {
    return { schoolName: '', major: '', degree: '本科', startYear: '', endYear: '' }
  }

  emptyExperience(): ExperienceItem {
    return {
      type: 'intern',
      companyName: '',
      projectName: '',
      role: '',
      description: '',
      startTime: '',
      endTime: ''
    }
  }

  emptyBasicInfoForm(): BasicInfoFormState {
    return {
      realName: '',
      phone: '',
      email: '',
      education: '',
      currentCity: '',
      school: '',
      major: '',
      graduationYear: '',
      expectedPosition: '',
      expectedSalary: ''
    }
  }

  cloneResume(source: ResumeInfo): ResumeInfo {
    return {
      resumeId: source.resumeId,
      userId: source.userId,
      realName: source.realName,
      gender: source.gender,
      birthday: source.birthday,
      education: source.education,
      school: source.school,
      major: source.major,
      graduationYear: source.graduationYear,
      expectedPosition: source.expectedPosition,
      expectedSalary: source.expectedSalary,
      currentCity: source.currentCity,
      phone: source.phone,
      email: source.email,
      skills: [...source.skills],
      selfIntro: source.selfIntro,
      educationList: [...source.educationList],
      experienceList: [...source.experienceList],
      isFromPDF: source.isFromPDF,
      pdfUncertainFields: [...source.pdfUncertainFields],
      hasSchedule: source.hasSchedule,
      scheduleId: source.scheduleId,
      updateTime: source.updateTime
    }
  }

  buildResume(base: ResumeInfo, patch: Partial<ResumeInfo>): ResumeInfo {
    return {
      resumeId: patch.resumeId !== undefined ? patch.resumeId : base.resumeId,
      userId: patch.userId !== undefined ? patch.userId : base.userId,
      realName: patch.realName !== undefined ? patch.realName : base.realName,
      gender: patch.gender !== undefined ? patch.gender : base.gender,
      birthday: patch.birthday !== undefined ? patch.birthday : base.birthday,
      education: patch.education !== undefined ? patch.education : base.education,
      school: patch.school !== undefined ? patch.school : base.school,
      major: patch.major !== undefined ? patch.major : base.major,
      graduationYear: patch.graduationYear !== undefined ? patch.graduationYear : base.graduationYear,
      expectedPosition: patch.expectedPosition !== undefined ? patch.expectedPosition : base.expectedPosition,
      expectedSalary: patch.expectedSalary !== undefined ? patch.expectedSalary : base.expectedSalary,
      currentCity: patch.currentCity !== undefined ? patch.currentCity : base.currentCity,
      phone: patch.phone !== undefined ? patch.phone : base.phone,
      email: patch.email !== undefined ? patch.email : base.email,
      skills: patch.skills !== undefined ? patch.skills : [...base.skills],
      selfIntro: patch.selfIntro !== undefined ? patch.selfIntro : base.selfIntro,
      educationList: patch.educationList !== undefined ? patch.educationList : [...base.educationList],
      experienceList: patch.experienceList !== undefined ? patch.experienceList : [...base.experienceList],
      isFromPDF: patch.isFromPDF !== undefined ? patch.isFromPDF : base.isFromPDF,
      pdfUncertainFields: patch.pdfUncertainFields !== undefined ? patch.pdfUncertainFields : [...base.pdfUncertainFields],
      hasSchedule: patch.hasSchedule !== undefined ? patch.hasSchedule : base.hasSchedule,
      scheduleId: patch.scheduleId !== undefined ? patch.scheduleId : base.scheduleId,
      updateTime: patch.updateTime !== undefined ? patch.updateTime : base.updateTime
    }
  }

  syncBasicInfoForm(source: ResumeInfo): void {
    const nextForm = this.emptyBasicInfoForm()
    nextForm.realName = source.realName || ''
    nextForm.phone = source.phone || ''
    nextForm.email = source.email || ''
    nextForm.education = source.education || ''
    nextForm.currentCity = source.currentCity || ''
    nextForm.school = source.school || ''
    nextForm.major = source.major || ''
    nextForm.graduationYear = source.graduationYear || ''
    nextForm.expectedPosition = source.expectedPosition || ''
    nextForm.expectedSalary = source.expectedSalary || ''
    this.basicInfoForm = nextForm
  }

  buildEducationForm(base: EducationItem, patch: Partial<EducationItem>): EducationItem {
    return {
      schoolName: patch.schoolName !== undefined ? patch.schoolName : base.schoolName,
      major: patch.major !== undefined ? patch.major : base.major,
      degree: patch.degree !== undefined ? patch.degree : base.degree,
      startYear: patch.startYear !== undefined ? patch.startYear : base.startYear,
      endYear: patch.endYear !== undefined ? patch.endYear : base.endYear
    }
  }

  buildExperienceForm(base: ExperienceItem, patch: Partial<ExperienceItem>): ExperienceItem {
    return {
      type: patch.type !== undefined ? patch.type : base.type,
      companyName: patch.companyName !== undefined ? patch.companyName : base.companyName,
      projectName: patch.projectName !== undefined ? patch.projectName : base.projectName,
      role: patch.role !== undefined ? patch.role : base.role,
      description: patch.description !== undefined ? patch.description : base.description,
      translatedDescription: patch.translatedDescription !== undefined ? patch.translatedDescription : base.translatedDescription,
      startTime: patch.startTime !== undefined ? patch.startTime : base.startTime,
      endTime: patch.endTime !== undefined ? patch.endTime : base.endTime
    }
  }

  buildUserSnapshot(realName: string, phone: string, email: string, education: string, school: string, major: string,
    expectedPosition: string, expectedSalary: string, currentCity: string): import('../../model/UserModel').UserProfile | null {
    if (!AppState.currentUser) {
      return null
    }
    return {
      userId: AppState.currentUser.userId,
      phone: phone,
      email: email,
      password: AppState.currentUser.password,
      role: AppState.currentUser.role,
      studentType: AppState.currentUser.studentType,
      realName: realName,
      gender: AppState.currentUser.gender,
      birthday: AppState.currentUser.birthday,
      education: education,
      school: school,
      major: major,
      expectedPosition: expectedPosition,
      expectedSalary: expectedSalary,
      currentCity: currentCity,
      isGuest: AppState.currentUser.isGuest,
      avatar: AppState.currentUser.avatar,
      companyName: AppState.currentUser.companyName,
      idCard: AppState.currentUser.idCard,
      businessLicense: AppState.currentUser.businessLicense,
      vipLevel: AppState.currentUser.vipLevel,
      positionCount: AppState.currentUser.positionCount,
      hrRealName: AppState.currentUser.hrRealName
    }
  }

  applyResumePatch(patch: Partial<ResumeInfo>): void {
    this.resume = this.buildResume(this.resume, patch)
  }

  replaceResume(nextResume: ResumeInfo): void {
    const nextBasicInfoRenderFlip = !this.basicInfoRenderFlip
    this.showFormShell = false
    this.resume = this.cloneResume(nextResume)
    this.syncBasicInfoForm(this.resume)
    this.formRenderKey = this.formRenderKey + 1
    setTimeout(() => {
      this.basicInfoRenderFlip = nextBasicInfoRenderFlip
      this.showFormShell = true
      setTimeout(() => {
        this.tabsController.changeIndex(this.currentTab)
      }, 32)
    }, 32)
  }

  refreshFormShell(): void {
    this.showFormShell = false
    this.formRenderKey = this.formRenderKey + 1
    setTimeout(() => {
      this.showFormShell = true
      setTimeout(() => {
        this.tabsController.changeIndex(0)
      }, 16)
    }, 0)
  }

  updateEducationForm(patch: Partial<EducationItem>): void {
    this.eduForm = this.buildEducationForm(this.eduForm, patch)
  }

  updateExperienceForm(patch: Partial<ExperienceItem>): void {
    this.expForm = this.buildExperienceForm(this.expForm, patch)
  }

  async loadResume(): Promise<void> {
    if (!AppState.currentUser) {
      return
    }
    const existing = await this.resumeDao.getResumeByUserId(AppState.currentUser.userId)
    if (existing) {
      this.replaceResume(this.cloneResume(existing))
      if (existing.hasSchedule) {
        const schedule = await this.resumeDao.getScheduleByUserId(AppState.currentUser.userId)
        if (schedule && schedule.freeSlots.length > 0) {
          this.parsedFreeSlots = schedule.freeSlots
          this.daySlots = this.buildDaySlotsFromSlots(schedule.freeSlots)
          this.scheduleSummary = this.buildScheduleSummary(schedule.freeSlots)
        }
      }
      return
    }
    this.syncBasicInfoForm(this.resume)
    this.refreshFormShell()
  }

  async autoFillCity(): Promise<void> {
    if (this.resume.currentCity) {
      return
    }
    try {
      this.isLocating = true
      const location = await geoLocationManager.getCurrentLocation()
      if (location) {
        this.applyResumePatch({ currentCity: AppState.currentUser?.currentCity || '褰撳墠鍩庡競' })
      }
    } catch (e) {
      this.applyResumePatch({ currentCity: AppState.currentUser?.currentCity || '' })
    } finally {
      this.isLocating = false
    }
  }

  async importResumeDocument(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext
      const picked = await PickerService.pickSingleDocument(context)
      this.importedDocumentName = picked.fileName
      this.isParsingResume = true
      let text = ''
      const lowerName = picked.fileName.toLowerCase()
      if (lowerName.endsWith('.pdf')) {
        const base64 = await LocalFileService.readBase64(picked.uri, context)
        text = await DocumentParseService.extractPdfText(base64)
      } else {
        text = await LocalFileService.readText(picked.uri, context)
      }
      this.resumeSourceText = text
      await this.parseResumeText(text, lowerName.endsWith('.pdf'))
    } catch (e) {
      AlertDialog.show({ message: e instanceof Error ? e.message : '瀵煎叆鏂囦欢澶辫触锛岃閲嶈瘯' })
    } finally {
      this.isParsingResume = false
    }
  }

  async parseResumeText(text: string, fromPdf: boolean): Promise<void> {
    const cleanText = text.trim()
    if (!cleanText) {
      AlertDialog.show({ message: '请先提供可解析的简历文本' })
      return
    }
    try {
      this.isParsingResume = true
      const result = await CampusAIService.parseResumeText(cleanText)
      this.applyParsedResume(result, cleanText, fromPdf)
      await this.persistResumeDraft()
      this.showResumeTextSheet = false
      AlertDialog.show({
        title: '简历解析完成',
        message: '结构化信息已回填到表单。黄色字段建议人工核对。'
      })
    } catch (e) {
      AlertDialog.show({ message: e instanceof Error ? e.message : '简历解析失败，请稍后重试' })
    } finally {
      this.isParsingResume = false
    }
  }

  applyParsedResume(result: CampusAIResumeParseResult, sourceText: string, fromPdf: boolean): void {
    const educations: EducationItem[] = []
    const educationSourceList = result.educationList || []
    for (let i = 0; i < educationSourceList.length; i++) {
      const item = educationSourceList[i]
      educations.push({
        schoolName: item.schoolName || '',
        major: item.major || '',
        degree: item.degree || '',
        startYear: item.startYear || '',
        endYear: item.endYear || ''
      })
    }
    const experiences: ExperienceItem[] = []
    const sourceList = result.experiences || []
    for (let i = 0; i < sourceList.length; i++) {
      const item = sourceList[i]
      experiences.push({
        type: item.type === 'project' ? 'project' : 'intern',
        companyName: item.companyName || '',
        projectName: item.projectName || '',
        role: item.role || '',
        description: item.description || '',
        translatedDescription: item.translatedDescription || '',
        startTime: item.startTime || '',
        endTime: item.endTime || ''
      })
    }
    const fallback = this.extractBasicInfoFallback(sourceText)
    const firstEducation = educations.length > 0 ? educations[0] : null
    const realName = this.normalizeParsedText(result.realName) || fallback.realName
    const phone = this.normalizeParsedText(result.phone) || fallback.phone
    const email = this.normalizeParsedText(result.email) || fallback.email
    const currentCity = this.normalizeParsedText(result.currentCity) || fallback.currentCity
    const school = this.normalizeParsedText(result.school)
      || fallback.school
      || (firstEducation ? this.normalizeParsedText(firstEducation.schoolName) : '')
    const major = this.normalizeParsedText(result.major)
      || fallback.major
      || (firstEducation ? this.normalizeParsedText(firstEducation.major) : '')
    const education = this.normalizeParsedText(result.education)
      || fallback.education
      || (firstEducation ? this.normalizeParsedText(firstEducation.degree) : '')
    const graduationYear = this.normalizeParsedText(result.graduationYear)
      || fallback.graduationYear
      || (firstEducation ? this.normalizeParsedText(firstEducation.endYear) : '')
    const expectedPosition = this.normalizeParsedText(result.expectedPosition) || fallback.expectedPosition
    const expectedSalary = this.normalizeParsedText(result.expectedSalary) || fallback.expectedSalary
    const selfIntro = this.normalizeParsedText(result.selfIntro) || fallback.selfIntro

    const baseResume = this.createImportBaseResume()
    const nextResume = this.buildResume(baseResume, {
      realName: realName || this.resume.realName,
      phone: phone || this.resume.phone,
      email: email || this.resume.email,
      currentCity: currentCity || this.resume.currentCity,
      school: school || this.resume.school,
      major: major || this.resume.major,
      education: education || this.resume.education,
      graduationYear: graduationYear || this.resume.graduationYear,
      expectedPosition: expectedPosition || this.resume.expectedPosition,
      expectedSalary: expectedSalary || this.resume.expectedSalary,
      selfIntro: selfIntro || this.resume.selfIntro,
      skills: result.skills && result.skills.length > 0 ? result.skills : this.resume.skills,
      educationList: educations.length > 0 ? educations : this.resume.educationList,
      experienceList: experiences.length > 0 ? experiences : this.resume.experienceList,
      isFromPDF: fromPdf,
      pdfUncertainFields: result.uncertainFields || [],
      updateTime: Date.now()
    })
    this.currentTab = 0
    this.replaceResume(nextResume)
    this.syncBasicInfoForm(this.resume)
  }

  private createImportBaseResume(): ResumeInfo {
    return {
      resumeId: this.resume.resumeId || ('resume_' + Date.now()),
      userId: this.resume.userId || AppState.currentUser?.userId || '',
      realName: '',
      gender: this.resume.gender || AppState.currentUser?.gender || '',
      birthday: this.resume.birthday || AppState.currentUser?.birthday || '',
      education: '',
      school: '',
      major: '',
      graduationYear: '',
      expectedPosition: '',
      expectedSalary: '',
      currentCity: '',
      phone: '',
      email: '',
      skills: [],
      selfIntro: '',
      educationList: [],
      experienceList: [],
      isFromPDF: false,
      pdfUncertainFields: [],
      hasSchedule: this.resume.hasSchedule,
      scheduleId: this.resume.scheduleId,
      updateTime: Date.now()
    }
  }

  private extractBasicInfoFallback(text: string): Partial<ResumeInfo> {
    const compactText = text.replace(/\r/g, '')
    const lines = compactText.split('\n')
    const result: Partial<ResumeInfo> = {}

    result.phone = this.firstMatch(compactText, /1[3-9]\d{9}/)
    result.email = this.firstMatch(compactText, /[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}/)
    result.currentCity = this.extractLabeledValue(compactText, ['现居地', '所在城市', '居住地', '意向城市'])
    result.school = this.extractLabeledValue(compactText, ['瀛︽牎', '姣曚笟闄㈡牎'])
    result.major = this.extractLabeledValue(compactText, ['专业', '所学专业'])
    result.education = this.extractLabeledValue(compactText, ['学历', '最高学历', '学位'])
    result.graduationYear = this.extractLabeledValue(compactText, ['姣曚笟骞翠唤', '姣曚笟鏃堕棿', '姣曚笟鏃ユ湡'])
    result.expectedPosition = this.extractLabeledValue(compactText, ['鏈熸湜宀椾綅', '鎰忓悜宀椾綅', '姹傝亴鎰忓悜', '搴旇仒宀椾綅', '鐩爣宀椾綅'])
    result.expectedSalary = this.extractLabeledValue(compactText, ['鏈熸湜钖祫', '钖祫瑕佹眰', '鏈熸湜鏈堣柂', '钖祫鑼冨洿'])
    result.selfIntro = this.extractLabeledParagraph(compactText, ['自我评价', '个人简介', '个人总结', '自我介绍'])

    const detectedName = this.detectName(lines)
    if (detectedName) {
      result.realName = detectedName
    }

    if (result.education) {
      result.education = this.normalizeEducationText(result.education)
    }
    if (result.graduationYear) {
      result.graduationYear = this.normalizeYearText(result.graduationYear)
    }

    return result
  }

  private detectName(lines: string[]): string {
    for (let i = 0; i < lines.length && i < 6; i++) {
      const line = lines[i].trim()
      if (!line || line.length > 12) {
        continue
      }
      if (line.indexOf('简历') >= 0 || line.indexOf('个人') >= 0 || /\d/.test(line) || line.indexOf('@') >= 0) {
        continue
      }
      if (/^[A-Za-z\u4e00-\u9fa5]{2,12}$/.test(line)) {
        return line
      }
    }
    return ''
  }

  private extractLabeledValue(text: string, labels: string[]): string {
    for (let i = 0; i < labels.length; i++) {
      const label = labels[i]
      const pattern = new RegExp(label + '[：:\\s\\t]*([^\\n|｜]+)')
      const value = this.firstMatchGroup(text, pattern)
      if (value) {
        return value
      }
    }
    return ''
  }

  private extractLabeledParagraph(text: string, labels: string[]): string {
    for (let i = 0; i < labels.length; i++) {
      const label = labels[i]
      const pattern = new RegExp(label + '[：:\\s\\t]*([\\s\\S]{0,160})')
      const value = this.firstMatchGroup(text, pattern)
      if (value) {
        const stopIndex = value.search(/\n(?:鏁欒偛缁忓巻|鏁欒偛鑳屾櫙|椤圭洰缁忓巻|瀹炰範缁忓巻|鎶€鑳絴鑾峰|璇佷功|鏍″洯缁忓巻)[锛?]?/)
        const clipped = stopIndex >= 0 ? value.substring(0, stopIndex) : value
        return clipped.trim()
      }
    }
    return ''
  }

  private firstMatch(text: string, pattern: RegExp): string {
    const match = text.match(pattern)
    return match && match.length > 0 ? match[0].trim() : ''
  }

  private firstMatchGroup(text: string, pattern: RegExp): string {
    const match = text.match(pattern)
    if (!match || match.length < 2) {
      return ''
    }
    return match[1].replace(/\s+/g, ' ').trim()
  }

  private normalizeEducationText(value: string): string {
    if (value.indexOf('博士') >= 0 || value.indexOf('鍗氬＋') >= 0) {
      return '博士'
    }
    if (value.indexOf('硕士') >= 0 || value.indexOf('研究生') >= 0 || value.indexOf('纭曞＋') >= 0) {
      return '硕士'
    }
    if (value.indexOf('本科') >= 0 || value.indexOf('鏈') >= 0) {
      return '本科'
    }
    if (value.indexOf('大专') >= 0 || value.indexOf('专科') >= 0
      || value.indexOf('澶т笓') >= 0 || value.indexOf('涓撶') >= 0) {
      return '大专'
    }
    return value
  }

  private normalizeYearText(value: string): string {
    const match = value.match(/(19|20)\d{2}/)
    return match && match.length > 0 ? match[0] : value
  }

  normalizeParsedText(value: string | undefined): string {
    return value ? value.trim() : ''
  }

  mergeSkills(skills: string[]): string[] {
    const merged = [...this.resume.skills]
    for (let i = 0; i < skills.length; i++) {
      const skill = skills[i].trim()
      if (skill && merged.indexOf(skill) < 0) {
        merged.push(skill)
      }
    }
    return merged
  }

  private buildSkillViewItems(): SkillViewItem[] {
    const items: SkillViewItem[] = []
    for (let i = 0; i < this.resume.skills.length; i++) {
      items.push({
        id: this.resume.skills[i] + '_' + i,
        label: this.resume.skills[i],
        index: i
      })
    }
    return items
  }

  private buildEducationViewItems(): EducationViewItem[] {
    const items: EducationViewItem[] = []
    for (let i = 0; i < this.resume.educationList.length; i++) {
      const item = this.resume.educationList[i]
      items.push({
        id: item.schoolName + '_' + item.major + '_' + item.startYear + '_' + item.endYear + '_' + i,
        index: i,
        schoolName: item.schoolName,
        major: item.major,
        degree: item.degree,
        startYear: item.startYear,
        endYear: item.endYear
      })
    }
    return items
  }

  private buildExperienceViewItems(): ExperienceViewItem[] {
    const items: ExperienceViewItem[] = []
    for (let i = 0; i < this.resume.experienceList.length; i++) {
      const item = this.resume.experienceList[i]
      items.push({
        id: item.type + '_' + (item.companyName || '') + '_' + (item.projectName || '') + '_' + item.role + '_' + item.description + '_' + (item.translatedDescription || '') + '_' + item.startTime + '_' + item.endTime + '_' + i,
        index: i,
        type: item.type,
        companyName: item.companyName,
        projectName: item.projectName,
        role: item.role,
        description: item.description,
        translatedDescription: item.translatedDescription,
        startTime: item.startTime,
        endTime: item.endTime
      })
    }
    return items
  }

  isUncertainField(path: string): boolean {
    return this.resume.pdfUncertainFields.indexOf(path) >= 0
  }

  clearUncertainField(path: string): void {
    if (!this.isUncertainField(path)) {
      return
    }
    const nextFields: string[] = []
    for (let i = 0; i < this.resume.pdfUncertainFields.length; i++) {
      const field = this.resume.pdfUncertainFields[i]
      if (field !== path) {
        nextFields.push(field)
      }
    }
    this.applyResumePatch({ pdfUncertainFields: nextFields })
  }

  clearUncertainByPrefix(prefix: string): void {
    const nextFields: string[] = []
    for (let i = 0; i < this.resume.pdfUncertainFields.length; i++) {
      const field = this.resume.pdfUncertainFields[i]
      if (!field.startsWith(prefix)) {
        nextFields.push(field)
      }
    }
    this.applyResumePatch({ pdfUncertainFields: nextFields })
  }

  educationPath(index: number, key: string): string {
    return 'educationList.' + index + '.' + key
  }

  experiencePath(index: number, key: string): string {
    return 'experiences.' + index + '.' + key
  }

  hasEducationUncertainty(index: number): boolean {
    return this.resume.pdfUncertainFields.some((field: string) => field.startsWith('educationList.' + index + '.'))
  }

  hasExperienceUncertainty(index: number): boolean {
    return this.resume.pdfUncertainFields.some((field: string) => field.startsWith('experiences.' + index + '.'))
  }

  openEducationEditor(index: number): void {
    const item = this.resume.educationList[index]
    this.eduEditIndex = index
    this.eduForm = this.buildEducationForm(this.emptyEducation(), item)
    this.showEduDialog = true
  }

  openNewEducationEditor(): void {
    this.eduForm = this.emptyEducation()
    this.eduEditIndex = -1
    this.showEduDialog = true
  }

  openNewExperienceEditor(type: 'intern' | 'project'): void {
    const nextForm = this.emptyExperience()
    nextForm.type = type
    this.expForm = nextForm
    this.expEditIndex = -1
    this.showExpDialog = true
  }

  closeEducationDialog(): void {
    this.showEduDialog = false
  }

  closeExperienceDialog(): void {
    this.showExpDialog = false
  }

  openExperienceEditor(index: number): void {
    if (this.isTranslatingExp && this.translatingExpIndex === index) {
      return
    }
    const item = this.resume.experienceList[index]
    this.expEditIndex = index
    this.expForm = this.buildExperienceForm(this.emptyExperience(), item)
    this.showExpDialog = true
  }

  confirmPdfReview(): void {
    if (this.resume.pdfUncertainFields.length === 0) {
      AlertDialog.show({ message: '褰撳墠娌℃湁寰呮牳瀵圭殑楂樹寒瀛楁' })
      return
    }
    this.applyResumePatch({ pdfUncertainFields: [] })
    AlertDialog.show({ message: '高亮字段已标记为核对完成，记得点击右上角保存简历。' })
  }

  handleFieldChange(field: string, value: string): void {
    const nextForm = this.emptyBasicInfoForm()
    nextForm.realName = this.basicInfoForm.realName
    nextForm.phone = this.basicInfoForm.phone
    nextForm.email = this.basicInfoForm.email
    nextForm.education = this.basicInfoForm.education
    nextForm.currentCity = this.basicInfoForm.currentCity
    nextForm.school = this.basicInfoForm.school
    nextForm.major = this.basicInfoForm.major
    nextForm.graduationYear = this.basicInfoForm.graduationYear
    nextForm.expectedPosition = this.basicInfoForm.expectedPosition
    nextForm.expectedSalary = this.basicInfoForm.expectedSalary

    switch (field) {
      case 'realName':
        nextForm.realName = value
        this.applyResumePatch({ realName: value })
        break
      case 'phone':
        nextForm.phone = value
        this.applyResumePatch({ phone: value })
        break
      case 'email':
        nextForm.email = value
        this.applyResumePatch({ email: value })
        break
      case 'education':
        nextForm.education = value
        this.applyResumePatch({ education: value })
        break
      case 'currentCity':
        nextForm.currentCity = value
        this.applyResumePatch({ currentCity: value })
        break
      case 'school':
        nextForm.school = value
        this.applyResumePatch({ school: value })
        break
      case 'major':
        nextForm.major = value
        this.applyResumePatch({ major: value })
        break
      case 'graduationYear':
        nextForm.graduationYear = value
        this.applyResumePatch({ graduationYear: value })
        break
      case 'expectedPosition':
        nextForm.expectedPosition = value
        this.applyResumePatch({ expectedPosition: value })
        break
      case 'expectedSalary':
        nextForm.expectedSalary = value
        this.applyResumePatch({ expectedSalary: value })
        break
      default:
        break
    }
    this.basicInfoForm = nextForm
    this.clearUncertainField(field)
  }

  addSkill(): void {
    const skill = this.skillInput.trim()
    if (!skill) {
      return
    }
    if (this.resume.skills.indexOf(skill) < 0) {
      this.applyResumePatch({ skills: [...this.resume.skills, skill] })
    }
    this.clearUncertainField('skills')
    this.skillInput = ''
  }

  removeSkill(index: number): void {
    const nextSkills = [...this.resume.skills]
    nextSkills.splice(index, 1)
    this.applyResumePatch({ skills: nextSkills })
  }

  async addEducation(): Promise<void> {
    if (!this.eduForm.schoolName.trim() || !this.eduForm.major.trim()) {
      AlertDialog.show({ message: '请先填写学校和专业' })
      return
    }
    const nextItem: EducationItem = {
      schoolName: this.eduForm.schoolName.trim(),
      major: this.eduForm.major.trim(),
      degree: this.eduForm.degree.trim(),
      startYear: this.eduForm.startYear.trim(),
      endYear: this.eduForm.endYear.trim()
    }
    const nextEducation: EducationItem[] = [...this.resume.educationList]
    if (this.eduEditIndex >= 0) {
      nextEducation[this.eduEditIndex] = nextItem
      this.clearUncertainByPrefix('educationList.' + this.eduEditIndex + '.')
    } else {
      nextEducation.push(nextItem)
    }
    this.applyResumePatch({ educationList: nextEducation })
    this.eduForm = this.emptyEducation()
    this.eduEditIndex = -1
    this.showEduDialog = false
  }

  removeEducation(index: number): void {
    const nextEducation = [...this.resume.educationList]
    nextEducation.splice(index, 1)
    this.applyResumePatch({ educationList: nextEducation })
    this.clearUncertainByPrefix('educationList.' + index + '.')
  }

  async addExperience(): Promise<void> {
    if (!this.expForm.role.trim() || !this.expForm.description.trim()) {
      AlertDialog.show({ message: '请先填写经历角色和描述' })
      return
    }
    const newExp: ExperienceItem = {
      type: this.expForm.type,
      companyName: (this.expForm.companyName || '').trim(),
      projectName: (this.expForm.projectName || '').trim(),
      role: this.expForm.role.trim(),
      description: this.expForm.description.trim(),
      translatedDescription: (this.expForm.translatedDescription || this.expForm.description).trim(),
      startTime: this.expForm.startTime.trim(),
      endTime: this.expForm.endTime.trim()
    }
    if (this.expEditIndex >= 0) {
      const editingList = [...this.resume.experienceList]
      editingList[this.expEditIndex] = newExp
      this.applyResumePatch({ experienceList: editingList })
      this.clearUncertainByPrefix('experiences.' + this.expEditIndex + '.')
    } else {
      const nextExperiences = [...this.resume.experienceList, newExp]
      this.applyResumePatch({ experienceList: nextExperiences })
    }
    this.expForm = this.emptyExperience()
    this.expEditIndex = -1
    this.showExpDialog = false
  }

  removeExperience(index: number): void {
    const nextExperiences = [...this.resume.experienceList]
    nextExperiences.splice(index, 1)
    this.applyResumePatch({ experienceList: nextExperiences })
    this.clearUncertainByPrefix('experiences.' + index + '.')
  }

  async translateExperience(index: number): Promise<void> {
    const exp = this.resume.experienceList[index]
    if (!exp) return
    this.isTranslatingExp = true
    this.translatingExpIndex = index
    try {
      const result = await rewriteStudentExperience(exp.description, exp.type)
      const updatedList: ExperienceItem[] = []
      for (let i = 0; i < this.resume.experienceList.length; i++) {
        if (i === index) {
          updatedList.push({
            type: this.resume.experienceList[i].type,
            companyName: this.resume.experienceList[i].companyName,
            projectName: this.resume.experienceList[i].projectName,
            role: this.resume.experienceList[i].role,
            description: result.rewritten,
            translatedDescription: result.rewritten,
            startTime: this.resume.experienceList[i].startTime,
            endTime: this.resume.experienceList[i].endTime
          })
        } else {
          updatedList.push(this.resume.experienceList[i])
        }
      }
      this.applyResumePatch({ experienceList: updatedList })
      this.applyResumePatch({ skills: this.mergeSkills(result.skills || []) })
      AlertDialog.show({ message: 'AI 优化已完成，表达已替换为优化版本。' })
    } catch (e) {
      AlertDialog.show({ message: e instanceof Error ? e.message : 'AI 优化失败，请稍后重试' })
    } finally {
      this.isTranslatingExp = false
      this.translatingExpIndex = -1
    }
  }

  buildScheduleSummary(slots: FreeTimeSlot[]): string {
    if (slots.length === 0) {
      return '暂未设置弹性工时'
    }
    return slots
      .slice(0, 4)
      .map((item: FreeTimeSlot) => item.label)
      .join('、')
  }

  buildDaySlotsFromSlots(slots: FreeTimeSlot[]): DaySlot[] {
    const result: DaySlot[] = []
    for (let i = 0; i < DAY_OPTIONS.length; i++) {
      const option = DAY_OPTIONS[i]
      result.push({
        dayOfWeek: option.dayOfWeek,
        label: option.label,
        slots: []
      })
    }
    for (let i = 0; i < slots.length; i++) {
      const slot = slots[i]
      const dayItem = result.find((item: DaySlot) => item.dayOfWeek === slot.dayOfWeek)
      if (dayItem) {
        dayItem.slots.push(slot)
      }
    }
    return result
  }

  openFlexWorkCalendar(): void {
    this.showScheduleSheet = false
    router.pushUrl({ url: AppConstants.ROUTE_FLEX_WORK_CALENDAR })
  }

  async handleSave(): Promise<void> {
    if (!AppState.currentUser) {
      AlertDialog.show({ message: '请先登录后再保存简历' })
      return
    }
    await this.persistResumeDraft()
    AlertDialog.show({ message: '简历保存成功' })
    router.back()
  }

  async persistResumeDraft(): Promise<void> {
    if (!AppState.currentUser) {
      return
    }
    const scheduleId = this.resume.scheduleId || ('schedule_' + AppState.currentUser.userId)
    if (this.parsedFreeSlots.length > 0) {
      const schedule: CourseSchedule = {
        scheduleId: scheduleId,
        userId: AppState.currentUser.userId,
        semesters: [],
        freeSlots: this.parsedFreeSlots,
        updateTime: Date.now()
      }
      await this.resumeDao.saveSchedule(schedule)
      this.applyResumePatch({
        scheduleId: schedule.scheduleId,
        hasSchedule: true
      })
    }

    this.resume = this.buildResume(this.resume, {
      userId: AppState.currentUser.userId,
      updateTime: Date.now()
    })
    await this.resumeDao.upsertResume(this.resume)
    await this.resumeDao.replaceEducationList(this.resume.resumeId, this.resume.educationList)
    await this.resumeDao.replaceExperienceList(this.resume.resumeId, this.resume.experienceList)
    const nextUser = this.buildUserSnapshot(
      this.resume.realName,
      this.resume.phone,
      this.resume.email,
      this.resume.education,
      this.resume.school,
      this.resume.major,
      this.resume.expectedPosition,
      this.resume.expectedSalary,
      this.resume.currentCity
    )
    if (nextUser) {
      AppState.currentUser = nextUser
      await this.userDao.updateUser(nextUser)
      AppState.syncToStorage()
    }
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
      Row() {
        Button() {
          Image($r('app.media.ic_back'))
            .width(24)
            .height(24)
            .fillColor('#1A1A1A')
        }
        .backgroundColor('transparent')
        .onClick(() => router.back())

        Text('编辑简历')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button('保存')
          .fontSize(14)
          .height(32)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .fontColor('#FFFFFF')
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .onClick(() => this.handleSave())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 28, bottom: 8 })

      Column() {
        Row() {
          Column() {
            Text('导入 PDF / TXT / Markdown 简历')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor(AppConstants.COLOR_PRIMARY)
            Text(this.importedDocumentName || '支持直接选择文件，PDF 会先提取文本再交给 DeepSeek 解析')
              .fontSize(11)
              .fontColor('#7A8CA6')
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          if (this.isParsingResume) {
            LoadingProgress()
              .width(22)
              .height(22)
              .color(AppConstants.COLOR_PRIMARY)
          }
        }
        .width('100%')

        Row() {
          Button('选择文件')
            .layoutWeight(1)
            .height(36)
            .fontSize(13)
            .backgroundColor(AppConstants.COLOR_PRIMARY)
            .fontColor('#FFFFFF')
            .borderRadius(18)
            .onClick(() => this.importResumeDocument())
          Button('粘贴文本')
            .layoutWeight(1)
            .height(36)
            .fontSize(13)
            .backgroundColor('#F0F7FF')
            .fontColor(AppConstants.COLOR_PRIMARY)
            .borderRadius(18)
            .margin({ left: 10 })
            .onClick(() => { this.showResumeTextSheet = true })
        }
        .width('100%')
        .margin({ top: 12 })
      }
      .width('92%')
      .padding(16)
      .backgroundColor('#F8FBFF')
      .border({ width: 1.5, color: '#BFD6F2', radius: 12, style: BorderStyle.Dashed })
      .margin({ top: 8, bottom: 8 })

      if (this.resume.isFromPDF) {
        Row() {
          Column() {
            Text(this.resume.pdfUncertainFields.length > 0 ? 'AI 已完成解析，请先核对黄色字段' : 'PDF 简历已完成核对')
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(this.resume.pdfUncertainFields.length > 0 ? '#8A6D1F' : '#2E8B57')
            Text(this.resume.pdfUncertainFields.length > 0
              ? ('当前还有 ' + this.resume.pdfUncertainFields.length + ' 处待确认，包括项目名、学校名或时间等。')
              : '所有高亮字段都已经确认，可以直接保存并投递。')
              .fontSize(11)
              .fontColor('#7A6A40')
              .margin({ top: 4 })
          }
          .layoutWeight(1)

          if (this.resume.pdfUncertainFields.length > 0) {
            Button('已校对高亮项')
              .fontSize(12)
              .height(34)
              .backgroundColor('#F0C24B')
              .fontColor('#5E4300')
              .borderRadius(17)
              .padding({ left: 12, right: 12 })
              .onClick(() => this.confirmPdfReview())
          }
        }
        .width('92%')
        .padding(14)
        .backgroundColor(this.resume.pdfUncertainFields.length > 0 ? '#FFF7D8' : '#EDF9F1')
        .borderRadius(12)
        .margin({ bottom: 8 })
      }

      if (this.showFormShell) {
        Tabs({ controller: this.tabsController, index: this.currentTab }) {
        TabContent() {
          Scroll() {
            this.BasicInfoForm()
          }
        }.tabBar('基本信息')

        TabContent() {
          Scroll() {
            this.EducationForm()
          }
        }.tabBar('教育经历')

        TabContent() {
          Scroll() {
            this.ExperienceForm()
          }
        }.tabBar('经历')

        TabContent() {
          Scroll() {
            this.SkillsForm()
          }
        }.tabBar('技能')

        TabContent() {
          Scroll() {
            this.ResumePreviewForm()
          }
        }.tabBar('在线预览')
        }
        .barHeight(44)
        .barMode(BarMode.Scrollable)
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .bindSheet($$this.showResumeTextSheet, this.ResumeTextSheet(), { dragBar: true, showClose: true, height: 560 })
    .bindSheet($$this.showScheduleSheet, this.ScheduleSheet(), { dragBar: true, showClose: true, height: 620 })

      if (this.showEduDialog) {
        this.DialogMask(() => this.closeEducationDialog())
        this.EducationSheet()
      }

      if (this.showExpDialog) {
        this.DialogMask(() => this.closeExperienceDialog())
        this.ExperienceSheet()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  DialogMask(onClose: () => void) {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => onClose())
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  BasicInfoForm() {
    if (this.basicInfoRenderFlip) {
      Column() {
        this.FormField('姓名', this.resume.realName, 'realName', this.resume.pdfUncertainFields.indexOf('realName') >= 0)
        this.FormField('电话', this.resume.phone, 'phone', this.resume.pdfUncertainFields.indexOf('phone') >= 0)
        this.FormField('邮箱', this.resume.email, 'email', this.resume.pdfUncertainFields.indexOf('email') >= 0)
        this.FormField('学历', this.resume.education, 'education', this.resume.pdfUncertainFields.indexOf('education') >= 0)
        this.FormField('现居地', this.resume.currentCity, 'currentCity', false, this.isLocating ? '定位中...' : '请输入当前城市')
        this.FormField('学校', this.resume.school, 'school', this.resume.pdfUncertainFields.indexOf('school') >= 0)
        this.FormField('专业', this.resume.major, 'major', this.resume.pdfUncertainFields.indexOf('major') >= 0)
        this.FormField('毕业年份', this.resume.graduationYear, 'graduationYear', this.resume.pdfUncertainFields.indexOf('graduationYear') >= 0)
        this.FormField('期望岗位', this.resume.expectedPosition, 'expectedPosition', this.resume.pdfUncertainFields.indexOf('expectedPosition') >= 0)
        this.FormField('期望薪资', this.resume.expectedSalary, 'expectedSalary', this.resume.pdfUncertainFields.indexOf('expectedSalary') >= 0)
      }
      .padding({ left: 16, right: 16 })
    } else {
      Column() {
        this.FormField('姓名', this.resume.realName, 'realName', this.resume.pdfUncertainFields.indexOf('realName') >= 0)
        this.FormField('电话', this.resume.phone, 'phone', this.resume.pdfUncertainFields.indexOf('phone') >= 0)
        this.FormField('邮箱', this.resume.email, 'email', this.resume.pdfUncertainFields.indexOf('email') >= 0)
        this.FormField('学历', this.resume.education, 'education', this.resume.pdfUncertainFields.indexOf('education') >= 0)
        this.FormField('现居地', this.resume.currentCity, 'currentCity', false, this.isLocating ? '定位中...' : '请输入当前城市')
        this.FormField('学校', this.resume.school, 'school', this.resume.pdfUncertainFields.indexOf('school') >= 0)
        this.FormField('专业', this.resume.major, 'major', this.resume.pdfUncertainFields.indexOf('major') >= 0)
        this.FormField('毕业年份', this.resume.graduationYear, 'graduationYear', this.resume.pdfUncertainFields.indexOf('graduationYear') >= 0)
        this.FormField('期望岗位', this.resume.expectedPosition, 'expectedPosition', this.resume.pdfUncertainFields.indexOf('expectedPosition') >= 0)
        this.FormField('期望薪资', this.resume.expectedSalary, 'expectedSalary', this.resume.pdfUncertainFields.indexOf('expectedSalary') >= 0)
      }
      .padding({ left: 16, right: 16 })
    }
  }

  @Builder
  EducationForm() {
    Column() {
      if (this.resume.educationList.length === 0) {
        this.PreviewEmpty('上传 PDF 后，AI 识别出的教育经历会回填到这里。你也可以手动添加。')
      }
      ForEach(this.buildEducationViewItems(), (item: EducationViewItem) => {
        Row() {
          Column() {
            Text(item.schoolName)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .backgroundColor(this.isUncertainField(this.educationPath(item.index, 'schoolName')) ? AppConstants.COLOR_YELLOW_HIGHLIGHT : 'transparent')
            Text(item.major + ' / ' + item.degree)
              .fontSize(12)
              .fontColor('#666666')
              .margin({ top: 4 })
            Text(item.startYear + ' - ' + item.endYear)
              .fontSize(11)
              .fontColor('#999999')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Button('鍒犻櫎')
            .fontSize(12)
            .backgroundColor('transparent')
            .fontColor('#FF4D4F')
            .onClick(() => this.removeEducation(item.index))
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.hasEducationUncertainty(item.index) ? '#FFFDF2' : '#FFFFFF')
        .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
        .onClick(() => this.openEducationEditor(item.index))
      }, (item: EducationViewItem) => item.id)

      Button('+ 添加教育经历')
        .width('92%')
        .height(40)
        .fontSize(14)
        .backgroundColor('#F5F5F5')
        .fontColor(AppConstants.COLOR_PRIMARY)
        .borderRadius(8)
        .margin({ top: 16 })
        .onClick(() => this.openNewEducationEditor())
    }
    .padding({ left: 16, right: 16 })
  }

  @Builder
  ExperienceForm() {
    Column() {
      if (this.resume.experienceList.length === 0) {
        this.PreviewEmpty('AI 识别出的实习、项目和作品集经历会回填到这里，点击卡片也可以继续编辑。')
      }
      ForEach(this.buildExperienceViewItems(), (item: ExperienceViewItem) => {
        Column() {
          Row() {
            Text(item.type === 'intern' ? '实习' : '项目')
              .fontSize(11)
              .fontColor('#FFFFFF')
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .backgroundColor(item.type === 'intern' ? AppConstants.COLOR_PRIMARY : AppConstants.COLOR_ACCENT)
              .borderRadius(8)
            Text(item.companyName || item.projectName || '未命名经历')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .margin({ left: 8 })
            Blank()
            Button('删除')
              .fontSize(12)
              .backgroundColor('transparent')
              .fontColor('#FF4D4F')
              .onClick(() => this.removeExperience(item.index))
          }
          .width('100%')

          Text(item.role)
            .fontSize(12)
            .fontColor('#1A1A1A')
            .margin({ top: 8 })
            .width('100%')
            .backgroundColor(this.isUncertainField(this.experiencePath(item.index, 'role')) ? AppConstants.COLOR_YELLOW_HIGHLIGHT : 'transparent')

          Text(item.translatedDescription || item.description)
            .fontSize(12)
            .fontColor('#666666')
            .lineHeight(20)
            .margin({ top: 6 })
            .width('100%')
            .backgroundColor(this.isUncertainField(this.experiencePath(item.index, 'description')) ? AppConstants.COLOR_YELLOW_HIGHLIGHT : 'transparent')

          Row() {
            if (this.isTranslatingExp && this.translatingExpIndex === item.index) {
              LoadingProgress()
                .width(16)
                .height(16)
              Text('AI 优化中...')
                .fontSize(11)
                .fontColor(AppConstants.COLOR_AI_PURPLE)
                .margin({ left: 6 })
            } else {
              Text('AI 优化表达')
                .fontSize(11)
                .fontColor('#FFFFFF')
                .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                .backgroundColor(AppConstants.COLOR_AI_PURPLE)
                .borderRadius(14)
                .hitTestBehavior(HitTestMode.Block)
                .onClick(() => this.translateExperience(item.index))
            }
          }
          .margin({ top: 8 })
        }
        .width('100%')
        .padding(12)
        .backgroundColor(this.hasExperienceUncertainty(item.index) ? '#FFFDF2' : '#FFFFFF')
        .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
        .onClick(() => this.openExperienceEditor(item.index))
      }, (item: ExperienceViewItem) => item.id)

      Row() {
        Button('+ 添加实习')
          .layoutWeight(1)
          .height(40)
          .fontSize(13)
          .backgroundColor('#F0F7FF')
          .fontColor(AppConstants.COLOR_PRIMARY)
          .borderRadius(8)
          .onClick(() => this.openNewExperienceEditor('intern'))

        Button('+ 添加项目')
          .layoutWeight(1)
          .height(40)
          .fontSize(13)
          .backgroundColor('#FFF4EE')
          .fontColor(AppConstants.COLOR_ACCENT)
          .borderRadius(8)
          .margin({ left: 10 })
          .onClick(() => this.openNewExperienceEditor('project'))
      }
      .width('100%')
      .margin({ top: 16 })

    }
    .padding({ left: 16, right: 16 })
  }

  @Builder
  SkillsForm() {
    Column() {
      Text('技能标签')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)
        .margin({ bottom: 8 })

      Row() {
        TextInput({ text: this.skillInput, placeholder: '输入技能后点击添加' })
          .layoutWeight(1)
          .height(40)
          .fontSize(13)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .padding({ left: 12 })
          .onChange((value: string) => { this.skillInput = value })
          .onSubmit(() => this.addSkill())
        Button('添加')
          .fontSize(12)
          .height(40)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .fontColor('#FFFFFF')
          .borderRadius(8)
          .margin({ left: 8 })
          .onClick(() => this.addSkill())
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.buildSkillViewItems(), (item: SkillViewItem) => {
          Row() {
            Text(item.label)
              .fontSize(12)
              .fontColor(AppConstants.COLOR_PRIMARY)
            Text(' ×')
              .fontSize(12)
              .fontColor('#999999')
          }
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor('#F0F7FF')
          .borderRadius(14)
          .margin({ right: 8, bottom: 8 })
          .onClick(() => this.removeSkill(item.index))
        }, (item: SkillViewItem) => item.id)
      }
      .width('100%')
      .margin({ top: 12 })

      if (this.isUncertainField('skills')) {
        Text('AI 对技能标签仍有不确定项，建议核对后再保存。')
          .fontSize(11)
          .fontColor('#8A6D1F')
          .alignSelf(ItemAlign.Start)
          .margin({ top: 4 })
      }

      Text('个人介绍')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)
        .margin({ top: 16, bottom: 8 })

      TextArea({ text: this.resume.selfIntro, placeholder: '简要描述你的优势、方向和求职目标' })
        .width('100%')
        .height(140)
        .fontSize(13)
        .backgroundColor(this.isUncertainField('selfIntro') ? AppConstants.COLOR_YELLOW_HIGHLIGHT : '#F5F5F5')
        .borderRadius(8)
        .padding(12)
        .onChange((value: string) => {
          this.applyResumePatch({ selfIntro: value })
          this.clearUncertainField('selfIntro')
        })
    }
    .padding({ left: 16, right: 16, bottom: 24 })
  }

  @Builder
  ResumePreviewForm() {
    Column() {
      Column() {
        Text(this.resume.realName || '你的名字')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        Text([
          this.resume.school || '学校',
          this.resume.major || '专业',
          this.resume.education || '学历'
        ].filter((item: string) => !!item).join(' · '))
          .fontSize(13)
          .fontColor('#5F6B7A')
          .margin({ top: 6 })
        Text([
          this.resume.phone || '手机号',
          this.resume.email || '邮箱',
          this.resume.currentCity || '所在城市'
        ].filter((item: string) => !!item).join(' · '))
          .fontSize(12)
          .fontColor('#7D8792')
          .margin({ top: 8 })

        Flex({ wrap: FlexWrap.Wrap }) {
          this.PreviewBadge(this.resume.expectedPosition || '待填写岗位', '#EEF6FF', AppConstants.COLOR_PRIMARY)
          this.PreviewBadge(this.resume.expectedSalary || '待填写薪资', '#FFF2EA', AppConstants.COLOR_ACCENT)
          if (this.isStudentUser && this.resume.hasSchedule) {
            this.PreviewBadge('弹性工时已设置', '#EDF9F1', '#2E8B57')
          }
        }
        .width('100%')
        .margin({ top: 14 })
      }
      .width('100%')
      .padding(20)
      .backgroundColor('#FFFFFF')
      .borderRadius(20)
      .shadow({ radius: 16, color: '#12000000', offsetY: 6 })

      Column() {
        Text('教育经历')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 12 })
        if (this.resume.educationList.length > 0) {
          ForEach(this.resume.educationList, (item: EducationItem) => {
            this.PreviewTimeline(item.schoolName, item.major + ' / ' + item.degree, item.startYear + ' - ' + item.endYear)
          })
        } else {
          this.PreviewEmpty('补充教育经历后，这里会成为企业看到的第一张背景卡片。')
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(18)
      .margin({ top: 14 })

      Column() {
        Text('实习与项目')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 12 })
        if (this.resume.experienceList.length > 0) {
          ForEach(this.resume.experienceList, (item: ExperienceItem) => {
            Column() {
              Text(item.companyName || item.projectName || '未命名经历')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1A1A1A')
              Text(item.role + ' / ' + item.startTime + ' - ' + item.endTime)
                .fontSize(11)
                .fontColor('#7D8792')
                .margin({ top: 4 })
              Text(item.translatedDescription || item.description)
                .fontSize(12)
                .fontColor('#4C5665')
                .lineHeight(20)
                .margin({ top: 8 })
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#FAFBFD')
            .borderRadius(14)
            .margin({ bottom: 10 })
          }, (item: ExperienceItem, index: number) => item.type + '_' + (item.companyName || '') + '_' + (item.projectName || '') + '_' + item.role + '_' + item.description + '_' + (item.translatedDescription || '') + '_' + item.startTime + '_' + item.endTime + '_' + index)
        } else {
          this.PreviewEmpty('添加实习或项目后，投递时的在线简历会更完整。')
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(18)
      .margin({ top: 14 })

      Column() {
        Text('技能标签')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 12 })
        if (this.resume.skills.length > 0) {
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(this.buildSkillViewItems(), (item: SkillViewItem) => {
              Text(item.label)
                .fontSize(12)
                .fontColor(AppConstants.COLOR_PRIMARY)
                .padding({ left: 10, right: 10, top: 6, bottom: 6 })
                .backgroundColor('#EEF6FF')
                .borderRadius(16)
                .margin({ right: 8, bottom: 8 })
            }, (item: SkillViewItem) => item.id)
          }
          .width('100%')
        } else {
          this.PreviewEmpty('这里适合放技术栈、工具或专业能力关键词。')
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(18)
      .margin({ top: 14 })

      Column() {
        Text('个人介绍')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .alignSelf(ItemAlign.Start)
          .margin({ bottom: 12 })
        if (this.resume.selfIntro.trim()) {
          Text(this.resume.selfIntro)
            .fontSize(13)
            .fontColor('#4C5665')
            .lineHeight(22)
            .width('100%')
        } else {
          this.PreviewEmpty('用 3 到 5 句话总结你的方向、优势和想解决的问题。')
        }
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius(18)
      .margin({ top: 14 })
    }
    .padding({ left: 16, right: 16, bottom: 24 })
  }

  @Builder
  PreviewBadge(text: string, backgroundColor: string, textColor: string) {
    Text(text)
      .fontSize(11)
      .fontColor(textColor)
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor(backgroundColor)
      .borderRadius(16)
      .margin({ right: 8, bottom: 8 })
  }

  @Builder
  PreviewTimeline(title: string, subtitle: string, timeRange: string) {
    Row() {
      Column() {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
        Text(subtitle)
          .fontSize(12)
          .fontColor('#5F6B7A')
          .margin({ top: 4 })
        Text(timeRange)
          .fontSize(11)
          .fontColor('#97A0AA')
          .margin({ top: 6 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .border({ width: { bottom: 0.5 }, color: '#EEF1F5' })
  }

  @Builder
  PreviewEmpty(message: string) {
    Text(message)
      .fontSize(12)
      .fontColor('#97A0AA')
      .width('100%')
      .lineHeight(20)
  }

  @Builder
  FormField(label: string, value: string, field: string, highlight: boolean, placeholder?: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#666666')
        .width(80)
      TextInput({ text: value, placeholder: placeholder || ('请输入' + label) })
        .layoutWeight(1)
        .fontSize(14)
        .backgroundColor(highlight ? AppConstants.COLOR_YELLOW_HIGHLIGHT : 'transparent')
        .onChange((newValue: string) => this.handleFieldChange(field, newValue))
    }
    .width('100%')
    .padding(12)
    .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
  }

  @Builder
  ResumeTextSheet() {
    Column() {
      Row() {
        Button('清空')
          .fontSize(14)
          .backgroundColor('transparent')
          .fontColor('#999999')
          .onClick(() => { this.resumeSourceText = '' })
        Blank()
        Text('粘贴简历文本')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
        Blank()
        Button(this.isParsingResume ? '解析中...' : '解析文本')
          .fontSize(14)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .fontColor('#FFFFFF')
          .borderRadius(16)
          .padding({ left: 14, right: 14, top: 4, bottom: 4 })
          .enabled(!this.isParsingResume)
          .onClick(() => this.parseResumeText(this.resumeSourceText, false))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      TextArea({ text: this.resumeSourceText, placeholder: '把你的 PDF 提取文本、在线简历或作品集文字粘贴到这里' })
        .width('100%')
        .layoutWeight(1)
        .fontSize(13)
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .padding(12)
        .margin(16)
        .onChange((value: string) => { this.resumeSourceText = value })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  EducationSheet() {
    Column() {
      Row() {
        Button('取消')
          .fontSize(14)
          .backgroundColor('transparent')
          .fontColor('#999999')
          .onClick(() => this.closeEducationDialog())
        Blank()
        Text(this.eduEditIndex >= 0 ? '编辑教育经历' : '添加教育经历')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
        Blank()
        Button('保存')
          .fontSize(14)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .fontColor('#FFFFFF')
          .borderRadius(16)
          .padding({ left: 14, right: 14, top: 4, bottom: 4 })
          .onClick(() => this.addEducation())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Scroll() {
        Column() {
          TextInput({ text: this.eduForm.schoolName, placeholder: '学校名称' })
            .width('100%')
            .height(42)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .padding({ left: 12 })
            .onChange((value: string) => { this.updateEducationForm({ schoolName: value }) })
          TextInput({ text: this.eduForm.major, placeholder: '专业' })
            .width('100%')
            .height(42)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .padding({ left: 12 })
            .margin({ top: 10 })
            .onChange((value: string) => { this.updateEducationForm({ major: value }) })
          TextInput({ text: this.eduForm.degree, placeholder: '学历，如本科 / 硕士' })
            .width('100%')
            .height(42)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .padding({ left: 12 })
            .margin({ top: 10 })
            .onChange((value: string) => { this.updateEducationForm({ degree: value }) })
          Row() {
            TextInput({ text: this.eduForm.startYear, placeholder: '开始年份' })
              .layoutWeight(1)
              .height(42)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .padding({ left: 12 })
              .onChange((value: string) => { this.updateEducationForm({ startYear: value }) })
            TextInput({ text: this.eduForm.endYear, placeholder: '结束年份' })
              .layoutWeight(1)
              .height(42)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .padding({ left: 12 })
              .margin({ left: 10 })
              .onChange((value: string) => { this.updateEducationForm({ endYear: value }) })
          }
          .width('100%')
          .margin({ top: 10 })
        }
        .padding(16)
      }
    }
    .width('100%')
    .height('68%')
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 24, topRight: 24 })
  }

  @Builder
  ExperienceSheet() {
    Column() {
      Row() {
        Button('取消')
          .fontSize(14)
          .backgroundColor('transparent')
          .fontColor('#999999')
          .onClick(() => this.closeExperienceDialog())
        Blank()
        Text(this.expEditIndex >= 0 ? (this.expForm.type === 'intern' ? '编辑实习经历' : '编辑项目经历') : (this.expForm.type === 'intern' ? '添加实习经历' : '添加项目经历'))
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
        Blank()
        Button('保存')
          .fontSize(14)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .fontColor('#FFFFFF')
          .borderRadius(16)
          .padding({ left: 14, right: 14, top: 4, bottom: 4 })
          .onClick(() => this.addExperience())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Scroll() {
        Column() {
          TextInput({
            text: this.expForm.type === 'intern' ? this.expForm.companyName || '' : this.expForm.projectName || '',
            placeholder: this.expForm.type === 'intern' ? '公司名称' : '项目名称'
          })
            .width('100%')
            .height(42)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .padding({ left: 12 })
            .onChange((value: string) => {
              if (this.expForm.type === 'intern') {
                this.updateExperienceForm({ companyName: value })
              } else {
                this.updateExperienceForm({ projectName: value })
              }
            })
          TextInput({ text: this.expForm.role, placeholder: '担任角色，如前端开发 / 运营助理' })
            .width('100%')
            .height(42)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .padding({ left: 12 })
            .margin({ top: 10 })
            .onChange((value: string) => { this.updateExperienceForm({ role: value }) })
          Row() {
            TextInput({ text: this.expForm.startTime, placeholder: '开始时间' })
              .layoutWeight(1)
              .height(42)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .padding({ left: 12 })
              .onChange((value: string) => { this.updateExperienceForm({ startTime: value }) })
            TextInput({ text: this.expForm.endTime, placeholder: '结束时间' })
              .layoutWeight(1)
              .height(42)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .padding({ left: 12 })
              .margin({ left: 10 })
              .onChange((value: string) => { this.updateExperienceForm({ endTime: value }) })
          }
          .width('100%')
          .margin({ top: 10 })
          TextArea({
            text: this.expForm.translatedDescription || this.expForm.description,
            placeholder: '描述你的职责、方法、成果和产出'
          })
            .width('100%')
            .height(140)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .padding(12)
            .margin({ top: 10 })
            .onChange((value: string) => {
              this.updateExperienceForm({
                description: value,
                translatedDescription: value
              })
            })
        }
        .padding(16)
      }
    }
    .width('100%')
    .height('78%')
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 24, topRight: 24 })
  }

  @Builder
  ScheduleSheet() {
    Column() {
      Row() {
        Button('关闭')
          .fontSize(14)
          .backgroundColor('transparent')
          .fontColor('#999999')
          .onClick(() => { this.showScheduleSheet = false })
        Blank()
        Text('弹性工时日历')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
        Blank()
        Button('前往设置')
          .fontSize(14)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .fontColor('#FFFFFF')
          .borderRadius(16)
          .padding({ left: 14, right: 14, top: 4, bottom: 4 })
          .onClick(() => this.openFlexWorkCalendar())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Column() {
        Text('弹性工时日历已经独立成单独页面。')
          .fontSize(14)
          .fontColor('#344054')
          .alignSelf(ItemAlign.Start)
        Text('现在支持按小时和分钟手动设置每周空闲时间，也支持通过课表图片 OCR 自动识别后保存。')
          .fontSize(12)
          .fontColor('#667085')
          .lineHeight(20)
          .margin({ top: 8 })
          .alignSelf(ItemAlign.Start)

        if (this.scheduleSummary) {
          Text(this.scheduleSummary)
            .fontSize(12)
            .fontColor('#2E8B57')
            .lineHeight(20)
            .padding(12)
            .width('100%')
            .backgroundColor('#F5FBF7')
            .borderRadius(12)
            .margin({ top: 16 })
        }

        Button('去弹性工时日历')
          .width('100%')
          .height(42)
          .fontSize(14)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .fontColor('#FFFFFF')
          .borderRadius(21)
          .margin({ top: 20 })
          .onClick(() => this.openFlexWorkCalendar())
      }
      .padding(16)
      .width('100%')
    }
    .width('100%')
    .height('38%')
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 24, topRight: 24 })
  }
}
