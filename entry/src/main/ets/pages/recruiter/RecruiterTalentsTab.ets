// 招聘者 - 人才推荐与搜索页（Tab a: 人才）

import { router } from '@kit.ArkUI'
import { promptAction } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { UserProfile, UserRole, StudentType } from '../../model/UserModel'
import { UserDao } from '../../service/UserDao'
import { DatabaseHelper } from '../../database/DatabaseHelper'
import { TABLE_JOB, TABLE_RESUME, TABLE_EXPERIENCE } from '../../database/Tables'

// 已发岗位简要信息
interface JobBrief {
  title: string
  skills: string[]
  education: string
  category: string
}

// 匹配结果
interface MatchResult {
  score: number
  reason: string
}

// 简历简要数据（批量查询用）
interface ResumeBrief {
  realName: string
  birthday: string
  skills: string[]
  selfIntro: string
  salary: string
  phone: string
}

// 经历简要数据（批量查询用）
interface ExpBrief {
  company: string
  role: string
  startTime: string
}

// 人才卡片数据
interface TalentCard {
  userId: string
  realName: string
  school: string
  education: string
  major: string
  expectedPosition: string
  studentType: StudentType
  interviewStatus: string
  matchScore: number
  matchReason: string
  age: number
  experienceYears: number
  salary: string
  city: string
  lastActive: string
  skills: string[]
  workCompany: string
  workRole: string
  description: string
}

@Component
export struct RecruiterTalentsTab {
  @State talents: TalentCard[] = []
  @State filteredTalents: TalentCard[] = []
  @State searchKeyword: string = ''
  @State showAdvancedSearch: boolean = false
  @State isLoading: boolean = true
  @State filterEducation: string = '不限'
  @State filterType: string = '不限'
  @State jobCount: number = 0
  @State categoryIndex: number = 0  // 0=全职/实习, 1=微任务
  private userDao: UserDao = new UserDao()
  private allStudents: UserProfile[] = []
  private postedJobs: JobBrief[] = []

  async aboutToAppear(): Promise<void> {
    await this.loadTalentsFromDB()
  }

  async loadPostedJobs(): Promise<void> {
    const recruiterId = AppState.currentUser?.userId
    if (!recruiterId) return
    try {
      const store = await DatabaseHelper.getInstance().getStore()
      const rs = await store.querySql(
        `SELECT title, skills, education, category FROM ${TABLE_JOB} WHERE recruiter_id = '${recruiterId}' AND status = 'published'`
      )
      const jobs: JobBrief[] = []
      while (rs.goToNextRow()) {
        const skillsStr = rs.getString(rs.getColumnIndex('skills')) || ''
        const parsedSkills: string[] = []
        try {
          const arr = JSON.parse(skillsStr) as string[]
          for (const s of arr) parsedSkills.push(s)
        } catch (_e) { /* raw string fallback */ }
        jobs.push({
          title: rs.getString(rs.getColumnIndex('title')) || '',
          skills: parsedSkills.length > 0 ? parsedSkills : (skillsStr ? skillsStr.split(',') : []),
          education: rs.getString(rs.getColumnIndex('education')) || '',
          category: rs.getString(rs.getColumnIndex('category')) || ''
        })
      }
      rs.close()
      this.postedJobs = jobs
      this.jobCount = jobs.length
    } catch (_e) {
      this.postedJobs = []
    }
  }

  async loadTalentsFromDB(): Promise<void> {
    this.isLoading = true
    try {
      await this.loadPostedJobs()
      this.allStudents = await this.userDao.getStudents()

      const store = await DatabaseHelper.getInstance().getStore()
      const ids = this.allStudents.map((u: UserProfile) => `'${u.userId}'`).join(',')

      // 批量加载简历数据：姓名、生日、技能、自我介绍
      const resumeMap: Record<string, ResumeBrief> = {}
      if (ids) {
        try {
          const rs = await store.querySql(
            `SELECT user_id, real_name, birthday, skills, self_intro, expected_salary, phone FROM ${TABLE_RESUME} WHERE user_id IN (${ids})`
          )
          while (rs.goToNextRow()) {
            const uid = rs.getString(rs.getColumnIndex('user_id'))
            const skillsStr = rs.getString(rs.getColumnIndex('skills')) || '[]'
            let skills: string[] = []
            try { skills = JSON.parse(skillsStr) as string[] } catch (_e) { /* ignore */ }
            resumeMap[uid] = {
              realName: rs.getString(rs.getColumnIndex('real_name')) || '',
              birthday: rs.getString(rs.getColumnIndex('birthday')) || '',
              skills,
              selfIntro: rs.getString(rs.getColumnIndex('self_intro')) || '',
              salary: rs.getString(rs.getColumnIndex('expected_salary')) || '',
              phone: rs.getString(rs.getColumnIndex('phone')) || ''
            } as ResumeBrief
          }
          rs.close()
        } catch (_e) { /* ignore */ }
      }

      // 批量加载实习/项目经历，获取最近的工作公司、职位
      const expMap: Record<string, ExpBrief> = {}
      if (ids) {
        try {
          const rs = await store.querySql(
            `SELECT e.resume_id, e.type, e.company_name, e.role, e.start_time
             FROM ${TABLE_EXPERIENCE} e
             INNER JOIN ${TABLE_RESUME} r ON e.resume_id = r.resume_id
             WHERE r.user_id IN (${ids}) AND e.type = 'intern'
             ORDER BY e.start_time DESC`
          )
          while (rs.goToNextRow()) {
            const resumeId = rs.getString(rs.getColumnIndex('resume_id'))
            if (!expMap[resumeId]) {
              expMap[resumeId] = {
                company: rs.getString(rs.getColumnIndex('company_name')) || '',
                role: rs.getString(rs.getColumnIndex('role')) || '',
                startTime: rs.getString(rs.getColumnIndex('start_time')) || ''
              } as ExpBrief
            }
          }
          rs.close()
        } catch (_e) { /* ignore */ }
      }

      // 简历ID到用户ID的映射
      const resumeIdToUserId: Record<string, string> = {}
      if (ids) {
        try {
          const rs = await store.querySql(
            `SELECT resume_id, user_id FROM ${TABLE_RESUME} WHERE user_id IN (${ids})`
          )
          while (rs.goToNextRow()) {
            resumeIdToUserId[rs.getString(rs.getColumnIndex('resume_id'))] = rs.getString(rs.getColumnIndex('user_id'))
          }
          rs.close()
        } catch (_e) { /* ignore */ }
      }

      const mappedList: TalentCard[] = []
      for (let i = 0; i < this.allStudents.length; i++) {
        const user = this.allStudents[i]
        const matchResult = this.computeJobMatch(user)
        const resume = resumeMap[user.userId]

        // 计算年龄
        let age = 0
        const birthday = resume?.birthday || user.birthday || ''
        if (birthday) {
          const match = birthday.match(/^(\d{4})/)
          if (match) {
            age = new Date().getFullYear() - parseInt(match[1])
          }
        }

        // 估算经验年限
        let experienceYears = 0
        const expEntry = expMap[user.userId]
        if (expEntry && expEntry.startTime) {
          const expMatch = expEntry.startTime.match(/^(\d{4})/)
          if (expMatch) {
            experienceYears = Math.max(0, new Date().getFullYear() - parseInt(expMatch[1]))
          }
        }
        if (experienceYears === 0 && user.school) {
          const schoolMatch = user.school.match(/(\d{4})/)
          if (schoolMatch) {
            experienceYears = Math.max(1, new Date().getFullYear() - parseInt(schoolMatch[1]) - 3)
          } else {
            experienceYears = 0
          }
        }

        // 计算最近活跃时间（模拟数据）
        const lastActiveOptions = ['刚刚在线', '1h前在线', '3h前在线', '1天前在线']
        const lastActive = lastActiveOptions[i % lastActiveOptions.length]

        // 获取工作经历
        let workCompany = ''
        let workRole = ''
        for (const rid of Object.keys(resumeIdToUserId)) {
          if (resumeIdToUserId[rid] === user.userId) {
            const exp = expMap[rid]
            if (exp) {
              workCompany = exp.company
              workRole = exp.role
            }
            break
          }
        }

        const card: TalentCard = {
          userId: user.userId,
          realName: resume?.realName || user.realName || '未填写姓名',
          school: user.school || '未知院校',
          education: user.education || '学历待完善',
          major: user.major || '专业待完善',
          expectedPosition: user.expectedPosition || '意向待补充',
          studentType: user.studentType || StudentType.CURRENT,
          interviewStatus: '',
          matchScore: matchResult.score,
          matchReason: matchResult.reason,
          age,
          experienceYears,
          salary: resume?.salary || user.expectedSalary || '面议',
          city: user.currentCity || '未知城市',
          lastActive,
          skills: resume?.skills || [],
          workCompany,
          workRole,
          description: resume?.selfIntro || ''
        }
        mappedList.push(card)
      }
      // 按匹配分从高到低排序
      mappedList.sort((a: TalentCard, b: TalentCard) => b.matchScore - a.matchScore)
      this.talents = mappedList
      this.filteredTalents = mappedList
    } catch (e) {
      this.talents = []
      this.filteredTalents = []
    }
    this.isLoading = false
  }

  // 根据当前分类筛选岗位
  getActiveJobs(): JobBrief[] {
    if (this.categoryIndex === 0) {
      // 全职/实习：排除微任务
      return this.postedJobs.filter((j: JobBrief) => j.category !== 'micro_task')
    }
    // 微任务
    return this.postedJobs.filter((j: JobBrief) => j.category === 'micro_task')
  }

  // 基于已发岗位计算匹配分
  computeJobMatch(user: UserProfile): MatchResult {
    const activeJobs = this.getActiveJobs()
    if (activeJobs.length === 0) {
      // 无匹配岗位，基于简历完整度给基础分
      let score = 60
      const reasons: string[] = []
      if (user.school) { score += 5; reasons.push(user.school) }
      if (user.major) { score += 5; reasons.push(user.major) }
      if (user.expectedPosition) { score += 5; reasons.push(user.expectedPosition) }
      return {
        score: Math.min(score, 85),
        reason: reasons.length > 0 ? `匹配简历特征: ${reasons.join('、')}` : '基础推荐'
      }
    }

    let bestScore = 0
    let bestReason = ''

    for (const job of activeJobs) {
      let score = 40
      const hits: string[] = []

      // 学历匹配
      if (job.education && user.education) {
        const jobEdu = job.education.toLowerCase()
        const userEdu = user.education.toLowerCase()
        if (jobEdu.includes(userEdu) || userEdu.includes(jobEdu)) {
          score += 15
          hits.push(`学历${user.education}匹配`)
        } else {
          score += 3
        }
      }

      // 专业与岗位技能匹配
      if (job.skills.length > 0 && user.major) {
        const majorLower = user.major.toLowerCase()
        let skillHits = 0
        for (const skill of job.skills) {
          const s = skill.trim().toLowerCase()
          if (s && (majorLower.includes(s) || s.includes(majorLower) || majorLower.indexOf(s) >= 0)) {
            skillHits++
          }
        }
        if (skillHits > 0) {
          const bonus = Math.min(skillHits * 10, 25)
          score += bonus
          hits.push(`技能匹配${job.title}`)
        } else {
          score += 2
        }
      }

      // 意向岗位与岗位名称匹配
      if (user.expectedPosition && job.title) {
        const posLower = user.expectedPosition.toLowerCase()
        const titleLower = job.title.toLowerCase()
        if (posLower.includes(titleLower) || titleLower.includes(posLower)) {
          score += 15
          hits.push(`意向吻合${job.title}`)
        } else {
          // 模糊匹配
          const posWords = posLower.split(/[\s,，、/]+/)
          const titleWords = titleLower.split(/[\s,，、/]+/)
          let wordHit = false
          for (const pw of posWords) {
            for (const tw of titleWords) {
              if (pw && tw && (pw.includes(tw) || tw.includes(pw))) {
                wordHit = true
                break
              }
            }
            if (wordHit) break
          }
          score += wordHit ? 8 : 2
        }
      }

      // 类型匹配
      if (job.category && user.studentType) {
        if (job.category === 'micro_task' && user.studentType === StudentType.CURRENT) {
          score += 8
          hits.push('微任务适配在校生')
        } else if (job.category !== 'micro_task' && user.studentType === StudentType.GRADUATING) {
          score += 8
          hits.push('全职适配应届生')
        } else {
          score += 2
        }
      }

      // 学校加分
      if (user.school) {
        score += 4
      }

      if (score > bestScore) {
        bestScore = score
        bestReason = hits.length > 0 ? hits.join('、') : `匹配${job.title}`
      }
    }

    return {
      score: Math.min(bestScore, 99),
      reason: bestReason || '综合推荐'
    }
  }

  applyFilters(): void {
    let result = this.talents

    if (this.searchKeyword.trim()) {
      const kw = this.searchKeyword.trim().toLowerCase()
      result = result.filter((t: TalentCard) => {
        return t.school.toLowerCase().includes(kw) ||
          t.major.toLowerCase().includes(kw) ||
          t.realName.toLowerCase().includes(kw) ||
          t.expectedPosition.toLowerCase().includes(kw)
      })
    }

    if (this.filterEducation !== '不限') {
      result = result.filter((t: TalentCard) => {
        if (this.filterEducation === '本科') {
          return t.education.includes('本科')
        } else if (this.filterEducation === '硕士') {
          return t.education.includes('硕士')
        }
        return true
      })
    }

    if (this.filterType !== '不限') {
      result = result.filter((t: TalentCard) => {
        if (this.filterType === '应届') {
          return t.studentType === StudentType.GRADUATING
        } else if (this.filterType === '在校') {
          return t.studentType === StudentType.CURRENT
        }
        return true
      })
    }

    this.filteredTalents = result
  }

  handleSearchChange(value: string): void {
    this.searchKeyword = value
    this.applyFilters()
  }

  handleTalentClick(talent: TalentCard): void {
    router.pushUrl({
      url: AppConstants.ROUTE_TALENT_DETAIL,
      params: {
        userId: talent.userId,
        matchScore: talent.matchScore,
        matchReason: talent.matchReason
      }
    })
  }

  handleFilterEducation(level: string): void {
    this.filterEducation = level
    this.applyFilters()
  }

  handleFilterType(type: string): void {
    this.filterType = type
    this.applyFilters()
  }

  handleCategoryChange(index: number): void {
    this.categoryIndex = index
    this.loadTalentsFromDB()
  }

  getAvatarEmoji(name: string): string {
    const map: Record<string, string> = {
      '陈': '👦', '张': '🧑', '林': '👩', '王': '👧', '赵': '👨',
      '李': '🧑', '刘': '👩', '周': '👦', '吴': '👨', '郑': '👧'
    }
    const surname = name.charAt(0)
    return map[surname] || '👨‍🎓'
  }

  build() {
    Column() {
      // 分类切换
      Row() {
        Button('全职 / 转正实习')
          .fontSize(13)
          .height(34)
          .backgroundColor(this.categoryIndex === 0 ? AppConstants.COLOR_ACCENT : '#F5F5F5')
          .fontColor(this.categoryIndex === 0 ? '#FFFFFF' : '#666666')
          .borderRadius(17)
          .padding({ left: 16, right: 16 })
          .onClick(() => this.handleCategoryChange(0))

        Button('微任务 / 短期兼职')
          .fontSize(13)
          .height(34)
          .backgroundColor(this.categoryIndex === 1 ? AppConstants.COLOR_ACCENT : '#F5F5F5')
          .fontColor(this.categoryIndex === 1 ? '#FFFFFF' : '#666666')
          .borderRadius(17)
          .padding({ left: 16, right: 16 })
          .margin({ left: 8 })
          .onClick(() => this.handleCategoryChange(1))
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 4 })

      // 搜索栏
      Row() {
        Row() {
          Text('🔍')
            .fontSize(14)
            .margin({ right: 6 })
          TextInput({ text: this.searchKeyword, placeholder: '搜索学校、专业、技能关键词' })
            .layoutWeight(1)
            .height(38)
            .fontSize(AppConstants.FONT_SIZE_MD)
            .backgroundColor(Color.Transparent)
            .border({ width: 0 })
            .onChange((v: string) => this.handleSearchChange(v))
        }
        .layoutWeight(1)
        .height(40)
        .backgroundColor('#F8F8F8')
        .borderRadius(20)
        .padding({ left: 14, right: 8 })
        .border({ width: 1, color: '#ECECEC' })

        Button() {
          Text(this.showAdvancedSearch ? '收起 ▴' : '筛选 ▾')
            .fontSize(12)
        }
        .height(32)
        .padding({ left: 14, right: 14 })
        .backgroundColor(this.showAdvancedSearch ? AppConstants.COLOR_ACCENT : '#FFF8F5')
        .fontColor(this.showAdvancedSearch ? '#FFFFFF' : AppConstants.COLOR_ACCENT)
        .borderRadius(1)

        
        .margin({ left: AppConstants.SPACING_SM })
        .border({ width: 1, color: 'rgba(255,107,53,0.25)' })
        .onClick(() => {
          this.showAdvancedSearch = !this.showAdvancedSearch
          if (!this.showAdvancedSearch) {
            this.filterEducation = '不限'
            this.filterType = '不限'
            this.applyFilters()
          }
        })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // 高级搜索筛选栏
      if (this.showAdvancedSearch) {
        Column() {
          Row() {
            Text('学历:')
              .fontSize(12)
              .fontColor('#666666')
              .margin({ right: 8 })
            ForEach(['不限', '本科', '硕士'], (level: string) => {
              Text(level)
                .fontSize(12)
                .fontColor(this.filterEducation === level ? '#FFFFFF' : AppConstants.COLOR_ACCENT)
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .backgroundColor(this.filterEducation === level ? AppConstants.COLOR_ACCENT : '#FFF6F0')
                .borderRadius(10)
                .margin({ right: 6 })
                .onClick(() => this.handleFilterEducation(level))
            })
          }
          .width('100%')
          .margin({ bottom: 6 })

          Row() {
            Text('类型:')
              .fontSize(12)
              .fontColor('#666666')
              .margin({ right: 8 })
            ForEach(['不限', '应届', '在校'], (type: string) => {
              Text(type)
                .fontSize(12)
                .fontColor(this.filterType === type ? '#FFFFFF' : AppConstants.COLOR_ACCENT)
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .backgroundColor(this.filterType === type ? AppConstants.COLOR_ACCENT : '#FFF6F0')
                .borderRadius(10)
                .margin({ right: 6 })
                .onClick(() => this.handleFilterType(type))
            })
          }
          .width('100%')
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })
      }

      Divider().height(1).color('#F0F0F0')

      // 人才列表
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(32)
            .height(32)
            .color(AppConstants.COLOR_ACCENT)
          Text('正在加载人才库...')
            .fontSize(14)
            .fontColor(AppConstants.COLOR_TEXT_HINT)
            .margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.filteredTalents.length === 0) {
        Column() {
          Column() {
            Text(this.talents.length === 0 ? '👥' : '🔍')
              .fontSize(48)
              .opacity(0.3)
          }
          .width(80)
          .height(80)
          .justifyContent(FlexAlign.Center)
          .backgroundColor('#F8F8F8')
          .borderRadius(40)
          .margin({ bottom: 20 })
          Text(this.talents.length === 0 ? '暂无候选人才' : '无匹配结果')
            .fontSize(16)
            .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
            .fontWeight(FontWeight.Medium)
            .margin({ bottom: 6 })
          Text(this.talents.length === 0 ? '发布岗位后系统将自动推荐' : '调整筛选条件试试')
            .fontSize(13)
            .fontColor(AppConstants.COLOR_TEXT_HINT)
            .textAlign(TextAlign.Center)
            .width('80%')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.filteredTalents, (talent: TalentCard) => {
            ListItem() {
              this.TalentCardBuilder(talent)
            }
            .margin({ bottom: 12 })
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 8, bottom: 16 })
        .backgroundColor(AppConstants.COLOR_BG_LIGHT)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  TalentCardBuilder(talent: TalentCard) {
    Column() {
      // ========== 第1行：头像 + 基本信息 + 匹配分 ==========
      Row() {
        // 头像区
        Stack() {
          Column() {
            Text(this.getAvatarEmoji(talent.realName))
              .fontSize(28)
          }
          .width(48)
          .height(48)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .borderRadius(24)
          .linearGradient({
            direction: GradientDirection.Bottom,
            colors: [['#FFE0D6', 0.0], ['#FFC8B4', 1.0]]
          })
        }
        .margin({ right: 10 })

        // 名字 + 详细信息
        Column() {
          Row() {
            Text(talent.realName)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
            Text(talent.studentType === StudentType.GRADUATING ? '应届' : '在校')
              .fontSize(10)
              .fontColor(talent.studentType === StudentType.GRADUATING ? '#E5551F' : AppConstants.COLOR_PRIMARY)
              .padding({ left: 6, right: 6, top: 1, bottom: 2 })
              .backgroundColor(talent.studentType === StudentType.GRADUATING ? '#FFF0E5' : '#F0F5FF')
              .borderRadius(6)
              .margin({ left: 6 })
            // 在线状态圆点
            Circle({ width: 6, height: 6 })
              .fill('#52C41A')
              .margin({ left: 8 })
            Text(talent.lastActive)
              .fontSize(11)
              .fontColor('#999999')
              .margin({ left: 4 })
          }
          .margin({ bottom: 3 })

          Text(`${talent.school} · ${talent.education} · ${talent.major}`)
            .fontSize(12)
            .fontColor(AppConstants.COLOR_TEXT_SECONDARY)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ bottom: 2 })

          Text(`意向: ${talent.expectedPosition}`)
            .fontSize(11)
            .fontColor('#888888')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)

        // 匹配分
        Column() {
          Text(`${talent.matchScore}`)
            .fontSize(22)
            .fontWeight(FontWeight.Bold)
            .fontColor(talent.matchScore >= 80 ? '#FF6B35' : (talent.matchScore >= 60 ? '#FAAD14' : '#999999'))
          Text('匹配分')
            .fontSize(9)
            .fontColor('#999999')
            .margin({ top: -2 })
        }
        .alignItems(HorizontalAlign.End)
        .padding({ left: 10, top: 2, bottom: 2 })
        .border({ width: { left: 1 }, color: '#F0F0F0' })
      }
      .width('100%')
      .margin({ bottom: 10 })

      // ========== 第2行：关键信息标签行 ==========
      Row() {
        this.InfoChip(`${talent.age}岁`)
        Divider().vertical(true).height(10).color('#E0E0E0').margin({ left: 6, right: 6 })
        this.InfoChip(`${talent.experienceYears}年经验`)
        Divider().vertical(true).height(10).color('#E0E0E0').margin({ left: 6, right: 6 })
        this.InfoChip(talent.salary)
        Divider().vertical(true).height(10).color('#E0E0E0').margin({ left: 6, right: 6 })
        this.InfoChip(talent.city)
      }
      .width('100%')
      .margin({ bottom: 10 })

      // ========== 第3行：工作/教育经历 ==========
      if (talent.workCompany || talent.school) {
        Row() {
          if (talent.workCompany) {
            Row() {
              Text('💼')
                .fontSize(13)
                .margin({ right: 4 })
              Text(`${talent.workCompany} · ${talent.workRole}`)
                .fontSize(12)
                .fontColor('#555555')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .flexShrink(1)
            .margin({ right: 12 })
          }
          if (talent.school) {
            Row() {
              Text('🎓')
                .fontSize(13)
                .margin({ right: 4 })
              Text(`${talent.school} · ${talent.education}`)
                .fontSize(12)
                .fontColor('#555555')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
            }
            .flexShrink(1)
          }
        }
        .width('100%')
        .margin({ bottom: 8 })
      }

      // ========== 第4行：自我描述 ==========
      if (talent.description) {
        Text(talent.description)
          .fontSize(12)
          .fontColor('#666666')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .lineHeight(18)
          .width('100%')
          .margin({ bottom: 8 })
      }

      // ========== 第5行：技能标签 ==========
      if (talent.skills.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(talent.skills.slice(0, 4), (skill: string, idx: number) => {
            Text(skill)
              .fontSize(11)
              .fontColor(idx < 2 ? '#FFFFFF' : '#FF6B35')
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(idx < 2 ? '#FF6B35' : '#FFF6F0')
              .borderRadius(10)
              .margin({ right: 6, bottom: 4 })
          })
          if (talent.skills.length > 4) {
            Text(`+${talent.skills.length - 4}`)
              .fontSize(11)
              .fontColor('#999999')
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor('#F5F5F5')
              .borderRadius(10)
          }
        }
        .width('100%')
      }

      // ========== 操作按钮 ==========
      Row() {
        Blank()
        Button() { Text('要电话').fontSize(11).fontColor('#FF6B35') }
          .height(28)
          .padding({ left: 12, right: 12 })
          .backgroundColor('#FFFFFF')
          .border({ width: 1, color: '#FF6B35', style: BorderStyle.Solid })
          .borderRadius(14)
          .onClick(() => {
            promptAction.showToast({ message: '已复制电话到剪贴板', duration: 1500 })
          })

        Button() { Text('打招呼').fontSize(11).fontColor('#FFFFFF') }
          .height(28)
          .padding({ left: 12, right: 12 })
          .backgroundColor('#FF6B35')
          .borderRadius(14)
          .margin({ left: 8 })
          .onClick(() => {
            promptAction.showToast({ message: `已向 ${talent.realName} 打招呼`, duration: 1500 })
          })
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 12 })
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .border({ width: 1, color: '#E8E8E8' })
    .shadow({ radius: 6, color: '#18000000', offsetY: 2 })
    .onClick(() => this.handleTalentClick(talent))
  }

  @Builder
  InfoChip(text: string) {
    Text(text)
      .fontSize(11)
      .fontColor('#888888')
      .maxLines(1)
  }
}
