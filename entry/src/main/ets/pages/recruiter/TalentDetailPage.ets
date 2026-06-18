import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { EducationItem, ExperienceItem, CourseSchedule, ResumeInfo, FreeTimeSlot } from '../../model/ResumeModel'
import { ResumeDao } from '../../service/ResumeDao'
import { UserDao } from '../../service/UserDao'
import { UserProfile, StudentType } from '../../model/UserModel'
import { buildConversationId } from '../../model/MessageModel'
import { InterviewApiService, CreateInterviewRequest } from '../../service/InterviewApiService'
import { DatabaseHelper } from '../../database/DatabaseHelper'
import { TABLE_AI_INTERVIEW } from '../../database/Tables'
import { MessageDao } from '../../service/MessageDao'

@Entry
@Component
struct TalentDetailPage {
  @State resume: ResumeInfo | null = null
  @State schedule: CourseSchedule | null = null
  @State studentUser: UserProfile | null = null
  @State showAIInterview: boolean = false
  @State isLoading: boolean = true
  @State loadError: boolean = false
  @State isSendingInterview: boolean = false
  @State matchScore: number = 0
  @State matchReason: string = ''
  private resumeDao: ResumeDao = new ResumeDao()
  private userDao: UserDao = new UserDao()
  private messageDao: MessageDao = new MessageDao()
  private userId: string = ''
  private jobTitle: string = ''

  async aboutToAppear(): Promise<void> {
    const params = router.getParams() as Record<string, Object>
    this.userId = (params['userId'] as string) || ''
    this.jobTitle = (params['jobTitle'] as string) || ''
    this.matchScore = (params['matchScore'] as number) || 0
    this.matchReason = (params['matchReason'] as string) || ''
    if (this.userId) {
      await this.loadData()
    } else {
      this.isLoading = false
      this.loadError = true
    }
  }

  async loadData(): Promise<void> {
    this.isLoading = true
    try {
      this.resume = await this.resumeDao.getResumeByUserId(this.userId)
      this.schedule = await this.resumeDao.getScheduleByUserId(this.userId)
      this.studentUser = await this.userDao.getUserById(this.userId)
    } catch (e) {
      // resume may not exist, which is ok
    }
    this.isLoading = false
  }

  handleStartChat(): void {
    if (!this.studentUser || !AppState.currentUser) {
      return
    }
    const conversationId = buildConversationId(AppState.currentUser.userId, this.studentUser.userId)
    router.pushUrl({
      url: AppConstants.ROUTE_CHAT,
      params: {
        conversationId: conversationId,
        peerName: this.studentUser.realName || '候选人',
        isAIAgent: false
      }
    })
  }

  async handleSendAIInterview(): Promise<void> {
    if (this.isSendingInterview || !AppState.currentUser || !this.studentUser) return
    const position = this.jobTitle || this.getDisplayPosition()
    AlertDialog.show({
      title: '确认发送',
      message: `确定向「${this.getDisplayName()}」发送「${position}」的AI虚拟面试邀请吗？`,
      primaryButton: {
        value: '发送',
        action: async () => {
          this.isSendingInterview = true
          try {
            const result = await InterviewApiService.createInterview({
              userId: this.userId,
              position: position
            })
            const questionsJson = JSON.stringify(result.questions || []).replace(/'/g, "''")
            const store = await DatabaseHelper.getInstance().getStore()
            await store.executeSql(
              `INSERT INTO ${TABLE_AI_INTERVIEW} (interview_id, recruiter_id, user_id, job_id, application_id, status, questions, invite_time)
               VALUES ('${result.sessionId}', '${AppState.currentUser!.userId}', '${this.userId}', '', '', 'invited', '${questionsJson}', ${Date.now()})`
            )
            await this.messageDao.insertSystemMessage(
              this.userId,
              'AI虚拟面试邀请',
              `[INTERVIEW:${result.sessionId}]${AppState.currentUser!.companyName || '企业'}邀请你参加「${position}」的AI视频面试（含数字人面试官+多维度评估）。请前往消息页查看并开始面试。`,
              'interview'
            )
            AlertDialog.show({ title: '发送成功', message: `已向 ${this.getDisplayName()} 发送AI面试邀请。` })
          } catch (e) {
            const errMsg = (e as Error).message || JSON.stringify(e)
            AlertDialog.show({ title: '发送失败', message: `原因：${errMsg}` })
          } finally {
            this.isSendingInterview = false
          }
        }
      },
      secondaryButton: { value: '取消', action: () => {} }
    })
  }

  getStudentTypeLabel(): string {
    if (!this.studentUser || !this.studentUser.studentType) {
      return ''
    }
    return this.studentUser.studentType === StudentType.GRADUATING ? '应届生' : '在校生'
  }

  getStudentTypeColor(): string {
    if (!this.studentUser || !this.studentUser.studentType) {
      return '#666666'
    }
    return this.studentUser.studentType === StudentType.GRADUATING ? '#4A90D9' : '#52C41A'
  }

  getDisplayName(): string {
    if (this.resume && this.resume.realName) {
      return this.resume.realName
    }
    if (this.studentUser && this.studentUser.realName) {
      return this.studentUser.realName
    }
    return '未填写姓名'
  }

  getDisplaySchool(): string {
    return this.resume?.school || this.studentUser?.school || '学校待完善'
  }

  getDisplayMajor(): string {
    return this.resume?.major || this.studentUser?.major || '专业待完善'
  }

  getDisplayEducation(): string {
    return this.resume?.education || this.studentUser?.education || '学历待完善'
  }

  getDisplayPhone(): string {
    return this.resume?.phone || this.studentUser?.phone || '手机号待完善'
  }

  getDisplayEmail(): string {
    return this.resume?.email || ''
  }

  getDisplayCity(): string {
    return this.resume?.currentCity || this.studentUser?.currentCity || '城市待完善'
  }

  getDisplayPosition(): string {
    return this.resume?.expectedPosition || this.studentUser?.expectedPosition || '意向岗位待补充'
  }

  getDisplaySalary(): string {
    if (this.resume && this.resume.expectedSalary) {
      return this.resume.expectedSalary
    }
    if (this.studentUser && this.studentUser.expectedSalary) {
      return this.studentUser.expectedSalary
    }
    return '意向薪资待补充'
  }

  getFreeSlotSummary(): string {
    if (!this.schedule || this.schedule.freeSlots.length === 0) {
      return ''
    }
    const days = ['周日', '周一', '周二', '周三', '周四', '周五', '周六']
    const slots = this.schedule.freeSlots.slice(0, 4)
    return slots.map((s) => s.label).join('；')
  }

  build() {
    Column() {
      this.PageHeader()

      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(28)
            .height(28)
            .color(AppConstants.COLOR_ACCENT)
          Text('正在加载候选人简历...')
            .fontSize(13)
            .fontColor('#7D8792')
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.loadError) {
        Column() {
          Text('😕')
            .fontSize(48)
            .margin({ bottom: 12 })
          Text('无法加载候选人信息')
            .fontSize(14)
            .fontColor('#999999')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            this.HeroCard()
            this.SummaryGrid()
            this.EducationCard()
            this.ExperienceCard()
            this.SkillCard()
            this.ScheduleCard()
            this.IntroCard()
            this.InterviewCard()
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 16 })
        }
        .layoutWeight(1)
        .backgroundColor('#F4F6FB')
        .scrollBar(BarState.Off)

        // 底部固定操作栏
        this.ActionBar()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F6FB')
  }

  @Builder
  PageHeader() {
    Row() {
      Button() {
        Image($r('app.media.ic_back'))
          .width(22)
          .height(22)
          .fillColor('#FFFFFF')
      }
      .width(36)
      .height(36)
      .backgroundColor('rgba(255,255,255,0.14)')
      .borderRadius(18)
      .onClick(() => router.back())

      Blank()

      Text('候选人详情')
        .fontSize(16)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')

      Blank()

      Button() {
        Image($r('sys.symbol.star'))
          .width(20)
          .height(20)
          .fillColor('#FFFFFF')
      }
      .width(36)
      .height(36)
      .backgroundColor('rgba(255,255,255,0.14)')
      .borderRadius(18)
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 80, bottom: 14 })
    .linearGradient({
      angle: 135,
      colors: [['#FF7B54', 0], ['#FF9F6B', 1]]
    })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])
  }

  @Builder
  HeroCard() {
    Column() {
      Row() {
        Column() {
          Row() {
            Text(this.getDisplayName())
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
            if (this.getStudentTypeLabel()) {
              Text(this.getStudentTypeLabel())
                .fontSize(10)
                .fontColor('#FFFFFF')
                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                .backgroundColor(this.getStudentTypeColor())
                .borderRadius(10)
                .margin({ left: 8 })
            }
          }

          Text([
            this.getDisplaySchool(),
            this.getDisplayMajor(),
            this.getDisplayEducation()
          ].join(' · '))
            .fontSize(12)
            .fontColor('#667085')
            .margin({ top: 8 })

          Text([
            this.getDisplayPhone(),
            this.getDisplayEmail(),
            this.getDisplayCity()
          ].filter(s => s && !s.includes('待完善')).join(' · ') || '联系方式待完善')
            .fontSize(11)
            .fontColor('#98A2B3')
            .margin({ top: 8 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Stack() {
          Circle()
            .width(72)
            .height(72)
            .fill('#FFF3EE')
          Text('简历')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(AppConstants.COLOR_ACCENT)
        }
      }
      .width('100%')

      Flex({ wrap: FlexWrap.Wrap }) {
        this.HeaderBadge(this.getDisplayPosition(), '#EEF5FF', '#2E6FD8')
        this.HeaderBadge(this.getDisplaySalary(), '#FFF3EE', AppConstants.COLOR_ACCENT)
        if (this.resume && this.resume.hasSchedule) {
          this.HeaderBadge('课表空闲已同步', '#EDF9F1', '#279255')
        }
        if (this.resume && this.resume.isFromPDF) {
          this.HeaderBadge('简历解析', '#FFF3EE', AppConstants.COLOR_ACCENT)
        }
      }
      .width('100%')
      .margin({ top: 18 })

      if (this.matchScore > 0 && this.matchReason) {
        Row() {
          Text(`${this.matchScore}分 · ${this.matchReason}`)
            .fontSize(11)
            .fontColor('#FF7B54')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('#FFF3EE')
            .borderRadius(6)
            .width('100%')
        }
        .width('100%')
        .margin({ top: 16 })
      }

      if (this.resume && this.resume.selfIntro.trim()) {
        Text(this.resume.selfIntro)
          .fontSize(13)
          .fontColor('#3E4C5A')
          .lineHeight(22)
          .width('100%')
          .margin({ top: 16 })
      }
    }
    .width('100%')
    .padding(20)
    .backgroundColor('#FFFFFF')
    .borderRadius(24)
    .shadow({ radius: 18, color: '#12000000', offsetY: 8 })
    .margin({ top: 12 })
  }

  @Builder
  HeaderBadge(text: string, background: string, color: string) {
    Text(text)
      .fontSize(11)
      .fontColor(color)
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor(background)
      .borderRadius(14)
      .margin({ right: 8, bottom: 8 })
  }

  @Builder
  SummaryGrid() {
    Row() {
      this.MetricCard('技能项',
        this.resume && this.resume.skills.length > 0 ? `${this.resume.skills.length} 项` : '暂无',
        '#EEF5FF', '#2E6FD8')
      this.MetricCard('教育记录',
        this.resume && this.resume.educationList.length > 0 ? `${this.resume.educationList.length} 段` : '暂无',
        '#FFF3EE', AppConstants.COLOR_ACCENT)
      this.MetricCard('实践经历',
        this.resume && this.resume.experienceList.length > 0 ? `${this.resume.experienceList.length} 段` : '暂无',
        '#EDF9F1', '#279255')
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .margin({ top: 14, bottom: 14 })
  }

  @Builder
  MetricCard(label: string, value: string, background: string, valueColor: string) {
    Column() {
      Text(label)
        .fontSize(11)
        .fontColor('#7D8792')
      Text(value)
        .fontSize(16)
        .fontWeight(FontWeight.Bold)
        .fontColor(valueColor)
        .margin({ top: 8 })
    }
    .width('31%')
    .padding({ top: 14, bottom: 14 })
    .backgroundColor(background)
    .borderRadius(18)
  }

  @Builder
  EducationCard() {
    Column() {
      this.CardHeader('教育经历', '学历和专业背景')
      this.EducationSection()
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(22)
    .margin({ bottom: 14 })
  }

  @Builder
  ExperienceCard() {
    Column() {
      this.CardHeader('实习与项目', '优先展示可迁移的实践能力')
      this.ExperienceSection()
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(22)
    .margin({ bottom: 14 })
  }

  @Builder
  SkillCard() {
    Column() {
      this.CardHeader('技能标签', '岗位检索最容易命中的关键词')
      this.SkillSection()
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(22)
    .margin({ bottom: 14 })
  }

  @Builder
  ScheduleCard() {
    Column() {
      this.CardHeader('空闲时段', '基于课表同步的可面试时间')
      this.ScheduleSection()
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(22)
    .margin({ bottom: 14 })
  }

  @Builder
  IntroCard() {
    Column() {
      this.CardHeader('个人介绍', '帮助 HR 快速判断表达和方向感')
      this.IntroSection()
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(22)
    .margin({ bottom: 14 })
  }

  @Builder
  CardHeader(title: string, subtitle: string) {
    Row() {
      Column() {
        Text(title)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        Text(subtitle)
          .fontSize(11)
          .fontColor('#8B95A1')
          .margin({ top: 4 })
      }
      .alignItems(HorizontalAlign.Start)
      Blank()
    }
    .width('100%')
    .margin({ bottom: 14 })
  }

  @Builder
  EducationSection() {
    if (this.resume && this.resume.educationList.length > 0) {
      ForEach(this.resume.educationList, (item: EducationItem, index: number) => {
        Row() {
          Column() {
            Circle()
              .width(10)
              .height(10)
              .fill(AppConstants.COLOR_PRIMARY)
            if (index < this.resume!.educationList.length - 1) {
              Divider()
                .width(2)
                .height(52)
                .color('#D8E7FB')
                .margin({ top: 6 })
            }
          }
          .width(16)

          Column() {
            Text(item.schoolName || '学校待完善')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1A1A1A')
            Text(`${item.major || '专业待完善'} · ${item.degree || '学历待完善'}`)
              .fontSize(12)
              .fontColor('#667085')
              .margin({ top: 4 })
            Text(`${item.startYear || '起始'} - ${item.endYear || '至今'}`)
              .fontSize(11)
              .fontColor('#98A2B3')
              .margin({ top: 6 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          .margin({ left: 12, bottom: 14 })
        }
        .width('100%')
        .alignItems(VerticalAlign.Top)
      })
    } else {
      this.EmptyHint('候选人还没有补充教育经历。')
    }
  }

  @Builder
  ExperienceSection() {
    if (this.resume && this.resume.experienceList.length > 0) {
      ForEach(this.resume.experienceList, (item: ExperienceItem) => {
        Column() {
          Row() {
            Text(item.type === 'intern' ? '实习' : '项目')
              .fontSize(10)
              .fontColor('#FFFFFF')
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(item.type === 'intern' ? AppConstants.COLOR_PRIMARY : AppConstants.COLOR_ACCENT)
              .borderRadius(10)
            Text(item.companyName || item.projectName || '未命名经历')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#1A1A1A')
              .margin({ left: 8 })
          }
          .width('100%')

          Text(item.role || '角色待完善')
            .fontSize(12)
            .fontColor('#43505E')
            .margin({ top: 10 })
            .width('100%')

          Text(`${item.startTime || '开始时间待补充'} - ${item.endTime || '结束时间待补充'}`)
            .fontSize(11)
            .fontColor('#98A2B3')
            .margin({ top: 6 })
            .width('100%')

          Text(item.translatedDescription || item.description || '经历描述待完善')
            .fontSize(12)
            .fontColor('#4C5665')
            .lineHeight(21)
            .margin({ top: 10 })
            .width('100%')
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#FAFBFD')
        .borderRadius(16)
        .margin({ bottom: 10 })
      })
    } else {
      this.EmptyHint('候选人还没有补充实习或项目经历。')
    }
  }

  @Builder
  SkillSection() {
    if (this.resume && this.resume.skills.length > 0) {
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.resume.skills, (skill: string) => {
          Text(skill)
            .fontSize(12)
            .fontColor('#2E6FD8')
            .padding({ left: 10, right: 10, top: 6, bottom: 6 })
            .backgroundColor('#EEF5FF')
            .borderRadius(16)
            .margin({ right: 8, bottom: 8 })
        })
      }
      .width('100%')
    } else {
      this.EmptyHint('候选人还没有整理技能关键词。')
    }
  }

  @Builder
  ScheduleSection() {
    if (this.schedule && this.schedule.freeSlots.length > 0) {
      Column() {
        ForEach(this.schedule.freeSlots, (slot: FreeTimeSlot) => {
          Row() {
            Circle()
              .width(8)
              .height(8)
              .fill('#279255')
            Text(slot.label)
              .fontSize(13)
              .fontColor('#3E4C5A')
              .margin({ left: 10 })
          }
          .width('100%')
          .margin({ bottom: 8 })
        })

        Row() {
          Text('以上时段来自课表识别，建议优先安排面试。')
            .fontSize(10)
            .fontColor('#8B95A1')
        }
        .width('100%')
        .margin({ top: 6 })
      }
      .width('100%')
    } else {
      this.EmptyHint('候选人暂未同步课表空闲时段。建议提醒候选人通过学生端同步课表，方便安排面试时间。')
    }
  }

  @Builder
  IntroSection() {
    if (this.resume && this.resume.selfIntro.trim()) {
      Text(this.resume.selfIntro)
        .fontSize(13)
        .fontColor('#4C5665')
        .lineHeight(22)
        .width('100%')
    } else {
      this.EmptyHint('候选人还没有填写个人介绍。')
    }
  }

  @Builder
  EmptyHint(text: string) {
    Text(text)
      .fontSize(12)
      .fontColor('#98A2B3')
      .lineHeight(20)
      .width('100%')
  }

  @Builder
  InterviewCard() {
    Column() {
      Row() {
        Column() {
          Text('AI 虚拟一面')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
          Text('基于候选人简历自动生成首轮沟通建议')
            .fontSize(11)
            .fontColor('#8B95A1')
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
      }
      .width('100%')

      Column() {
        this.InterviewPoint('项目真实性核验', '#2E6FD8')
        this.InterviewPoint('表达逻辑与岗位适配', AppConstants.COLOR_ACCENT)
        this.InterviewPoint('时间安排与到岗灵活性', '#279255')
        this.InterviewPoint('综合沟通风险提示', AppConstants.COLOR_ACCENT)
      }
      .width('100%')
      .margin({ top: 14, bottom: 14 })

      Button('🤖 发起AI虚拟面试')
        .width('100%')
        .height(44)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#FFFFFF')
        .backgroundColor(AppConstants.COLOR_ACCENT)
        .borderRadius(22)
        .enabled(!this.isSendingInterview)
        .onClick(() => this.handleSendAIInterview())
    }
    .width('100%')
    .padding(18)
    .backgroundColor('#FFFFFF')
    .borderRadius(22)
    .margin({ bottom: 14 })
  }

  @Builder
  InterviewPoint(text: string, color: string) {
    Row() {
      Circle()
        .width(8)
        .height(8)
        .fill(color)
      Text(text)
        .fontSize(12)
        .fontColor('#4C5665')
        .margin({ left: 10 })
    }
    .width('100%')
    .margin({ bottom: 10 })
  }

  @Builder
  ActionBar() {
    Row() {
      Button('暂不推进')
        .layoutWeight(1)
        .height(44)
        .fontSize(13)
        .backgroundColor('#FFFFFF')
        .fontColor('#667085')
        .borderRadius(22)
        .border({ width: 1, color: '#E0E0E0' })

      Button('发消息')
        .layoutWeight(1)
        .height(44)
        .fontSize(13)
        .backgroundColor(AppConstants.COLOR_PRIMARY)
        .fontColor('#FFFFFF')
        .borderRadius(22)
        .margin({ left: 10 })
        .onClick(() => this.handleStartChat())

      Button('发起面试')
        .layoutWeight(1)
        .height(44)
        .fontSize(13)
        .backgroundColor(AppConstants.COLOR_ACCENT)
        .fontColor('#FFFFFF')
        .borderRadius(22)
        .margin({ left: 10 })
        .onClick(() => this.handleSendAIInterview())
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 12 })
    .backgroundColor('#FFFFFF')
    .border({ width: { top: 0.5 }, color: '#E8E8E8' })
    .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
  }
}
