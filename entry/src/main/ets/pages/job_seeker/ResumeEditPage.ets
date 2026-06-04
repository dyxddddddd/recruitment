import { router } from '@kit.ArkUI'
import { geoLocationManager } from '@kit.LocationKit'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { CourseSchedule, EducationItem, ExperienceItem, FreeTimeSlot, ResumeInfo } from '../../model/ResumeModel'
import { CampusAIResumeParseResult, CampusAIService } from '../../service/CampusAIService'
import { DocumentParseService } from '../../service/DocumentParseService'
import { LocalFileService } from '../../service/LocalFileService'
import { PickerService } from '../../service/PickerService'
import { ResumeDao } from '../../service/ResumeDao'
import { VisionOcrService } from '../../service/VisionOcrService'
import { translateStudentExperience } from '../../service/AITranslateService'

@Entry
@Component
struct ResumeEditPage {
  @State resume: ResumeInfo = this.createEmptyResume()
  @State currentTab: number = 0
  @State isLocating: boolean = false
  @State isParsingResume: boolean = false
  @State isParsingSchedule: boolean = false
  @State showResumeTextSheet: boolean = false
  @State resumeSourceText: string = ''
  @State showEduDialog: boolean = false
  @State showExpDialog: boolean = false
  @State showScheduleSheet: boolean = false
  @State skillInput: string = ''
  @State eduForm: EducationItem = this.emptyEducation()
  @State expForm: ExperienceItem = this.emptyExperience()
  @State scheduleText: string = ''
  @State scheduleSummary: string = ''
  @State parsedFreeSlots: FreeTimeSlot[] = []
  @State importedDocumentName: string = ''
  @State importedScheduleImage: string = ''

  private tabsController: TabsController = new TabsController()
  private resumeDao: ResumeDao = new ResumeDao()

  aboutToAppear(): void {
    this.loadResume()
    this.autoFillCity()
  }

  createEmptyResume(): ResumeInfo {
    return {
      resumeId: `resume_${Date.now()}`,
      userId: AppState.currentUser?.userId || '',
      realName: AppState.currentUser?.realName || '',
      gender: AppState.currentUser?.gender || '',
      birthday: AppState.currentUser?.birthday || '',
      education: AppState.currentUser?.education || '本科',
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

  async loadResume(): Promise<void> {
    if (!AppState.currentUser) {
      return
    }
    const existing = await this.resumeDao.getResumeByUserId(AppState.currentUser.userId)
    if (existing) {
      this.resume = existing
      if (existing.hasSchedule) {
        const schedule = await this.resumeDao.getScheduleByUserId(AppState.currentUser.userId)
        if (schedule) {
          this.parsedFreeSlots = schedule.freeSlots
          this.scheduleSummary = this.buildScheduleSummary(schedule.freeSlots)
        }
      }
    }
  }

  async autoFillCity(): Promise<void> {
    if (this.resume.currentCity) {
      return
    }
    try {
      this.isLocating = true
      const location = await geoLocationManager.getCurrentLocation()
      if (location) {
        this.resume.currentCity = AppState.currentUser?.currentCity || '当前城市'
      }
    } catch (e) {
      this.resume.currentCity = AppState.currentUser?.currentCity || ''
    } finally {
      this.isLocating = false
    }
  }

  async importResumeDocument(): Promise<void> {
    try {
      const picked = await PickerService.pickSingleDocument()
      this.importedDocumentName = picked.fileName
      this.isParsingResume = true
      let text = ''
      const lowerName = picked.fileName.toLowerCase()
      if (lowerName.endsWith('.pdf')) {
        const base64 = await LocalFileService.readBase64(picked.uri)
        text = await DocumentParseService.extractPdfText(base64)
      } else {
        text = await LocalFileService.readText(picked.uri)
      }
      this.resumeSourceText = text
      await this.parseResumeText(text, lowerName.endsWith('.pdf'))
    } catch (e) {
      AlertDialog.show({ message: e instanceof Error ? e.message : '导入文件失败，请重试' })
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
      this.applyParsedResume(result, fromPdf)
      this.showResumeTextSheet = false
      AlertDialog.show({
        title: '简历解析完成',
        message: '结构化信息已回填到表单。标黄字段建议你再人工确认一下。'
      })
    } catch (e) {
      AlertDialog.show({ message: e instanceof Error ? e.message : '简历解析失败，请稍后重试' })
    } finally {
      this.isParsingResume = false
    }
  }

  applyParsedResume(result: CampusAIResumeParseResult, fromPdf: boolean): void {
    this.resume.realName = result.realName || this.resume.realName
    this.resume.phone = result.phone || this.resume.phone
    this.resume.email = result.email || this.resume.email
    this.resume.school = result.school || this.resume.school
    this.resume.major = result.major || this.resume.major
    this.resume.education = result.education || this.resume.education
    this.resume.graduationYear = result.graduationYear || this.resume.graduationYear
    this.resume.expectedPosition = result.expectedPosition || this.resume.expectedPosition
    this.resume.expectedSalary = result.expectedSalary || this.resume.expectedSalary
    this.resume.selfIntro = result.selfIntro || this.resume.selfIntro
    this.resume.skills = this.mergeSkills(result.skills || [])
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
    this.resume.experienceList = experiences
    this.resume.isFromPDF = fromPdf
    this.resume.pdfUncertainFields = result.uncertainFields || []
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

  handleFieldChange(field: string, value: string): void {
    switch (field) {
      case 'realName':
        this.resume.realName = value
        break
      case 'phone':
        this.resume.phone = value
        break
      case 'email':
        this.resume.email = value
        break
      case 'education':
        this.resume.education = value
        break
      case 'currentCity':
        this.resume.currentCity = value
        break
      case 'school':
        this.resume.school = value
        break
      case 'major':
        this.resume.major = value
        break
      case 'graduationYear':
        this.resume.graduationYear = value
        break
      case 'expectedPosition':
        this.resume.expectedPosition = value
        break
      case 'expectedSalary':
        this.resume.expectedSalary = value
        break
      default:
        break
    }
  }

  addSkill(): void {
    const skill = this.skillInput.trim()
    if (!skill) {
      return
    }
    if (this.resume.skills.indexOf(skill) < 0) {
      this.resume.skills.push(skill)
      this.resume.skills = [...this.resume.skills]
    }
    this.skillInput = ''
  }

  removeSkill(index: number): void {
    this.resume.skills.splice(index, 1)
    this.resume.skills = [...this.resume.skills]
  }

  async addEducation(): Promise<void> {
    if (!this.eduForm.schoolName.trim() || !this.eduForm.major.trim()) {
      AlertDialog.show({ message: '请先填写学校和专业' })
      return
    }
    this.resume.educationList.push({
      schoolName: this.eduForm.schoolName.trim(),
      major: this.eduForm.major.trim(),
      degree: this.eduForm.degree.trim(),
      startYear: this.eduForm.startYear.trim(),
      endYear: this.eduForm.endYear.trim()
    })
    this.resume.educationList = [...this.resume.educationList]
    this.eduForm = this.emptyEducation()
    this.showEduDialog = false
  }

  removeEducation(index: number): void {
    this.resume.educationList.splice(index, 1)
    this.resume.educationList = [...this.resume.educationList]
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
      startTime: this.expForm.startTime.trim(),
      endTime: this.expForm.endTime.trim()
    }
    try {
      const translated = await translateStudentExperience(newExp.description, newExp.type)
      newExp.translatedDescription = translated.translated
      this.resume.skills = this.mergeSkills(translated.skills || [])
    } catch (e) {
    }
    this.resume.experienceList.push(newExp)
    this.resume.experienceList = [...this.resume.experienceList]
    this.expForm = this.emptyExperience()
    this.showExpDialog = false
  }

  removeExperience(index: number): void {
    this.resume.experienceList.splice(index, 1)
    this.resume.experienceList = [...this.resume.experienceList]
  }

  async importScheduleImage(): Promise<void> {
    try {
      this.importedScheduleImage = await PickerService.pickSingleImage()
      this.isParsingSchedule = true
      const ocrResult = await VisionOcrService.recognizeImage(this.importedScheduleImage)
      this.scheduleText = ocrResult.fullText
      await this.parseScheduleText()
    } catch (e) {
      AlertDialog.show({ message: e instanceof Error ? e.message : '课表识别失败，请重试' })
    } finally {
      this.isParsingSchedule = false
    }
  }

  async parseScheduleText(): Promise<void> {
    if (!this.scheduleText.trim()) {
      AlertDialog.show({ message: '请先提供课表文本' })
      return
    }
    try {
      this.isParsingSchedule = true
      const result = await CampusAIService.parseScheduleText(this.scheduleText.trim())
      this.parsedFreeSlots = result.freeSlots || []
      this.scheduleSummary = result.summary || this.buildScheduleSummary(this.parsedFreeSlots)
      this.resume.hasSchedule = this.parsedFreeSlots.length > 0
      AlertDialog.show({ message: `已识别 ${this.parsedFreeSlots.length} 个空闲时段` })
    } catch (e) {
      AlertDialog.show({ message: e instanceof Error ? e.message : '课表解析失败，请重试' })
    } finally {
      this.isParsingSchedule = false
    }
  }

  buildScheduleSummary(slots: FreeTimeSlot[]): string {
    if (slots.length === 0) {
      return '暂未导入课表'
    }
    return slots
      .slice(0, 4)
      .map((item) => item.label)
      .join('、')
  }

  async handleSave(): Promise<void> {
    if (!AppState.currentUser) {
      AlertDialog.show({ message: '请先登录后再保存简历' })
      return
    }
    const scheduleId = this.resume.scheduleId || `schedule_${AppState.currentUser.userId}`
    if (this.parsedFreeSlots.length > 0) {
      const schedule: CourseSchedule = {
        scheduleId: scheduleId,
        userId: AppState.currentUser.userId,
        semesters: [],
        freeSlots: this.parsedFreeSlots,
        updateTime: Date.now()
      }
      await this.resumeDao.saveSchedule(schedule)
      this.resume.scheduleId = schedule.scheduleId
      this.resume.hasSchedule = true
    }

    this.resume.userId = AppState.currentUser.userId
    this.resume.updateTime = Date.now()
    await this.resumeDao.upsertResume(this.resume)
    await this.resumeDao.replaceEducationList(this.resume.resumeId, this.resume.educationList)
    await this.resumeDao.replaceExperienceList(this.resume.resumeId, this.resume.experienceList)
    AlertDialog.show({ message: '简历保存成功' })
    router.back()
  }

  build() {
    Column() {
      Row() {
        Button() {
          Image($r('sys.symbol.chevron_left'))
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
            Text(this.importedDocumentName || '支持直接选文件，PDF 会先提取文本再交给 DeepSeek 解析')
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
      }
      .barHeight(44)
      .barMode(BarMode.Scrollable)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .bindSheet($$this.showResumeTextSheet, this.ResumeTextSheet(), { dragBar: true, showClose: true, height: 560 })
    .bindSheet($$this.showEduDialog, this.EducationSheet(), { dragBar: true, showClose: true, height: 520 })
    .bindSheet($$this.showExpDialog, this.ExperienceSheet(), { dragBar: true, showClose: true, height: 620 })
    .bindSheet($$this.showScheduleSheet, this.ScheduleSheet(), { dragBar: true, showClose: true, height: 620 })
  }

  @Builder
  BasicInfoForm() {
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

  @Builder
  EducationForm() {
    Column() {
      ForEach(this.resume.educationList, (item: EducationItem, index: number) => {
        Row() {
          Column() {
            Text(item.schoolName)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
            Text(`${item.major} · ${item.degree}`)
              .fontSize(12)
              .fontColor('#666666')
              .margin({ top: 4 })
            Text(`${item.startYear} - ${item.endYear}`)
              .fontSize(11)
              .fontColor('#999999')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Button('删除')
            .fontSize(12)
            .backgroundColor('transparent')
            .fontColor('#FF4D4F')
            .onClick(() => this.removeEducation(index))
        }
        .width('100%')
        .padding(12)
        .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
      })

      Button('+ 添加教育经历')
        .width('92%')
        .height(40)
        .fontSize(14)
        .backgroundColor('#F5F5F5')
        .fontColor(AppConstants.COLOR_PRIMARY)
        .borderRadius(8)
        .margin({ top: 16 })
        .onClick(() => {
          this.eduForm = this.emptyEducation()
          this.showEduDialog = true
        })
    }
    .padding({ left: 16, right: 16 })
  }

  @Builder
  ExperienceForm() {
    Column() {
      ForEach(this.resume.experienceList, (item: ExperienceItem, index: number) => {
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
              .onClick(() => this.removeExperience(index))
          }
          .width('100%')

          Text(item.role)
            .fontSize(12)
            .fontColor('#1A1A1A')
            .margin({ top: 8 })
            .width('100%')

          Text(item.description)
            .fontSize(12)
            .fontColor('#666666')
            .lineHeight(20)
            .margin({ top: 6 })
            .width('100%')

          if (item.translatedDescription) {
            Text(`AI 翻译：${item.translatedDescription}`)
              .fontSize(11)
              .fontColor(AppConstants.COLOR_AI_PURPLE)
              .lineHeight(18)
              .margin({ top: 8 })
              .width('100%')
          }
        }
        .width('100%')
        .padding(12)
        .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
      })

      Row() {
        Button('+ 添加实习')
          .layoutWeight(1)
          .height(40)
          .fontSize(13)
          .backgroundColor('#F0F7FF')
          .fontColor(AppConstants.COLOR_PRIMARY)
          .borderRadius(8)
          .onClick(() => {
            this.expForm = this.emptyExperience()
            this.expForm.type = 'intern'
            this.showExpDialog = true
          })

        Button('+ 添加项目')
          .layoutWeight(1)
          .height(40)
          .fontSize(13)
          .backgroundColor('#FFF4EE')
          .fontColor(AppConstants.COLOR_ACCENT)
          .borderRadius(8)
          .margin({ left: 10 })
          .onClick(() => {
            this.expForm = this.emptyExperience()
            this.expForm.type = 'project'
            this.showExpDialog = true
          })
      }
      .width('100%')
      .margin({ top: 16 })

      Column() {
        Row() {
          Column() {
            Text('一键导入课表')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#2E8B57')
            Text(this.scheduleSummary || '拍照识别教务课表，自动生成空闲时段')
              .fontSize(11)
              .fontColor('#6F8E79')
              .margin({ top: 4 })
          }
          .layoutWeight(1)
          Text(this.resume.hasSchedule ? '已导入' : '未导入')
            .fontSize(11)
            .fontColor(this.resume.hasSchedule ? '#2E8B57' : '#999999')
        }
        .width('100%')

        Button(this.isParsingSchedule ? '识别中...' : '导入/编辑课表')
          .width('100%')
          .height(38)
          .fontSize(13)
          .backgroundColor('#EAF7EE')
          .fontColor('#2E8B57')
          .borderRadius(19)
          .margin({ top: 12 })
          .onClick(() => { this.showScheduleSheet = true })
      }
      .width('100%')
      .padding(14)
      .backgroundColor('#F5FBF7')
      .borderRadius(12)
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
        ForEach(this.resume.skills, (skill: string, index: number) => {
          Row() {
            Text(skill)
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
          .onClick(() => this.removeSkill(index))
        })
      }
      .width('100%')
      .margin({ top: 12 })

      Text('自我介绍')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .alignSelf(ItemAlign.Start)
        .margin({ top: 16, bottom: 8 })

      TextArea({ text: this.resume.selfIntro, placeholder: '简要描述你的优势、方向和求职目标' })
        .width('100%')
        .height(140)
        .fontSize(13)
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .padding(12)
        .onChange((value: string) => { this.resume.selfIntro = value })
    }
    .padding({ left: 16, right: 16, bottom: 24 })
  }

  @Builder
  FormField(label: string, value: string, field: string, highlight: boolean, placeholder?: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#666666')
        .width(80)
      TextInput({ text: value, placeholder: placeholder || `请输入${label}` })
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
          .onClick(() => { this.showEduDialog = false })
        Blank()
        Text('添加教育经历')
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
            .onChange((value: string) => { this.eduForm.schoolName = value })
          TextInput({ text: this.eduForm.major, placeholder: '专业' })
            .width('100%')
            .height(42)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .padding({ left: 12 })
            .margin({ top: 10 })
            .onChange((value: string) => { this.eduForm.major = value })
          TextInput({ text: this.eduForm.degree, placeholder: '学历，如本科/硕士' })
            .width('100%')
            .height(42)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .padding({ left: 12 })
            .margin({ top: 10 })
            .onChange((value: string) => { this.eduForm.degree = value })
          Row() {
            TextInput({ text: this.eduForm.startYear, placeholder: '开始年份' })
              .layoutWeight(1)
              .height(42)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .padding({ left: 12 })
              .onChange((value: string) => { this.eduForm.startYear = value })
            TextInput({ text: this.eduForm.endYear, placeholder: '结束年份' })
              .layoutWeight(1)
              .height(42)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .padding({ left: 12 })
              .margin({ left: 10 })
              .onChange((value: string) => { this.eduForm.endYear = value })
          }
          .width('100%')
          .margin({ top: 10 })
        }
        .padding(16)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  ExperienceSheet() {
    Column() {
      Row() {
        Button('取消')
          .fontSize(14)
          .backgroundColor('transparent')
          .fontColor('#999999')
          .onClick(() => { this.showExpDialog = false })
        Blank()
        Text(this.expForm.type === 'intern' ? '添加实习经历' : '添加项目经历')
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
                this.expForm.companyName = value
              } else {
                this.expForm.projectName = value
              }
            })
          TextInput({ text: this.expForm.role, placeholder: '担任角色，如前端开发/运营助理' })
            .width('100%')
            .height(42)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .padding({ left: 12 })
            .margin({ top: 10 })
            .onChange((value: string) => { this.expForm.role = value })
          Row() {
            TextInput({ text: this.expForm.startTime, placeholder: '开始时间' })
              .layoutWeight(1)
              .height(42)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .padding({ left: 12 })
              .onChange((value: string) => { this.expForm.startTime = value })
            TextInput({ text: this.expForm.endTime, placeholder: '结束时间' })
              .layoutWeight(1)
              .height(42)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .padding({ left: 12 })
              .margin({ left: 10 })
              .onChange((value: string) => { this.expForm.endTime = value })
          }
          .width('100%')
          .margin({ top: 10 })
          TextArea({ text: this.expForm.description, placeholder: '描述你的职责、方法、成果和产出' })
            .width('100%')
            .height(140)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .padding(12)
            .margin({ top: 10 })
            .onChange((value: string) => { this.expForm.description = value })
        }
        .padding(16)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
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
        Text('导入课表')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
        Blank()
        Button(this.isParsingSchedule ? '识别中...' : '重新解析')
          .fontSize(14)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .fontColor('#FFFFFF')
          .borderRadius(16)
          .padding({ left: 14, right: 14, top: 4, bottom: 4 })
          .enabled(!this.isParsingSchedule)
          .onClick(() => this.parseScheduleText())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Scroll() {
        Column() {
          Button(this.importedScheduleImage ? '重新选择课表图片' : '选择课表图片并 OCR 识别')
            .width('100%')
            .height(40)
            .fontSize(13)
            .backgroundColor('#EAF7EE')
            .fontColor('#2E8B57')
            .borderRadius(20)
            .onClick(() => this.importScheduleImage())

          if (this.importedScheduleImage) {
            Image(this.importedScheduleImage)
              .width('100%')
              .height(180)
              .objectFit(ImageFit.Contain)
              .borderRadius(12)
              .margin({ top: 12 })
          }

          if (this.scheduleSummary) {
            Text(this.scheduleSummary)
              .fontSize(12)
              .fontColor('#466A54')
              .lineHeight(20)
              .padding(12)
              .width('100%')
              .backgroundColor('#F5FBF7')
              .borderRadius(10)
              .margin({ top: 12 })
          }

          if (this.parsedFreeSlots.length > 0) {
            Column() {
              Text('识别出的空闲时段')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .alignSelf(ItemAlign.Start)
                .margin({ bottom: 8 })
              ForEach(this.parsedFreeSlots, (slot: FreeTimeSlot) => {
                Text(`${slot.label}（周${slot.dayOfWeek === 0 ? '日' : slot.dayOfWeek} 第 ${slot.startPeriod}-${slot.endPeriod} 节）`)
                  .fontSize(12)
                  .fontColor('#2E8B57')
                  .width('100%')
                  .padding(10)
                  .backgroundColor('#F8FFFA')
                  .borderRadius(8)
                  .margin({ bottom: 8 })
            })
            }
            .width('100%')
            .margin({ top: 12 })
          }

          TextArea({ text: this.scheduleText, placeholder: 'OCR 识别出的课表文本会出现在这里，你也可以手动粘贴后重新解析。' })
            .width('100%')
            .height(220)
            .fontSize(13)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .padding(12)
            .margin({ top: 12 })
            .onChange((value: string) => { this.scheduleText = value })
        }
        .padding(16)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
