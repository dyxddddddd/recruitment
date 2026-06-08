// 招聘者 - 人才推荐与搜索页（Tab a: 人才）

import { router } from '@kit.ArkUI'
import { AppConstants } from '../../common/constants/AppConstants'
import { UserProfile, UserRole, StudentType } from '../../model/UserModel'
import { UserDao } from '../../service/UserDao'

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
  avatar: string
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
  private userDao: UserDao = new UserDao()
  private allStudents: UserProfile[] = []

  async aboutToAppear(): Promise<void> {
    await this.loadTalentsFromDB()
  }

  async loadTalentsFromDB(): Promise<void> {
    this.isLoading = true
    try {
      this.allStudents = await this.userDao.getStudents()
      const mappedList: TalentCard[] = []
      for (let i = 0; i < this.allStudents.length; i++) {
        const user = this.allStudents[i]
        const card: TalentCard = {
          userId: user.userId,
          realName: user.realName || '未填写姓名',
          school: user.school || '未知院校',
          education: user.education || '学历待完善',
          major: user.major || '专业待完善',
          expectedPosition: user.expectedPosition || '意向待补充',
          studentType: user.studentType || StudentType.CURRENT,
          interviewStatus: '待筛选',
          matchScore: this.computeMatchScore(user),
          avatar: user.avatar || ''
        }
        mappedList.push(card)
      }
      this.talents = mappedList
      this.filteredTalents = mappedList
    } catch (e) {
      this.talents = []
      this.filteredTalents = []
    }
    this.isLoading = false
  }

  computeMatchScore(user: UserProfile): number {
    let score = 70
    if (user.realName) {
      score += 3
    }
    if (user.school) {
      score += 5
    }
    if (user.major) {
      score += 4
    }
    if (user.education) {
      score += 4
    }
    if (user.expectedPosition) {
      score += 5
    }
    if (user.expectedSalary) {
      score += 3
    }
    if (user.studentType === StudentType.GRADUATING) {
      score += 3
    }
    if (user.currentCity) {
      score += 3
    }
    return Math.min(score, 99)
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
      params: { userId: talent.userId }
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
      // 搜索栏
      Row() {
        TextInput({ text: this.searchKeyword, placeholder: '搜索学校、专业、技能关键词' })
          .layoutWeight(1)
          .height(36)
          .fontSize(13)
          .backgroundColor('#F0F0F0')
          .borderRadius(18)
          .padding({ left: 16 })
          .onChange((v: string) => this.handleSearchChange(v))

        Button(this.showAdvancedSearch ? '收起' : '筛选')
          .fontSize(12)
          .height(32)
          .backgroundColor(this.showAdvancedSearch ? AppConstants.COLOR_ACCENT : '#F5F5F5')
          .fontColor(this.showAdvancedSearch ? '#FFFFFF' : '#666666')
          .borderRadius(16)
          .margin({ left: 6 })
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
                .fontColor(this.filterEducation === level ? '#FFFFFF' : '#4A90D9')
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .backgroundColor(this.filterEducation === level ? '#4A90D9' : '#F0F7FF')
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
                .fontColor(this.filterType === type ? '#FFFFFF' : '#4A90D9')
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .backgroundColor(this.filterType === type ? '#4A90D9' : '#F0F7FF')
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

      // 统计信息
      if (!this.isLoading && this.filteredTalents.length > 0) {
        Row() {
          Text(`共 ${this.filteredTalents.length} 位候选人`)
            .fontSize(11)
            .fontColor('#999999')
          Blank()
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 6, bottom: 2 })
      }

      // 人才列表
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(28)
            .height(28)
            .color(AppConstants.COLOR_ACCENT)
          Text('正在加载人才库...')
            .fontSize(13)
            .fontColor('#999999')
            .margin({ top: 10 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.filteredTalents.length === 0) {
        Column() {
          Text('🔍')
            .fontSize(48)
            .margin({ bottom: 12 })
          Text(this.talents.length === 0 ? '暂无候选人才' : '无匹配结果')
            .fontSize(14)
            .fontColor('#999999')
          Text(this.talents.length === 0 ? '发布岗位后系统将自动推荐' : '调整筛选条件试试')
            .fontSize(12)
            .fontColor('#CCCCCC')
            .margin({ top: 6 })
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
            .margin({ bottom: 8 })
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16, top: 4 })
        .backgroundColor('#F5F5F5')
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  TalentCardBuilder(talent: TalentCard) {
    Column() {
      Row() {
        Text(this.getAvatarEmoji(talent.realName))
          .fontSize(36)
          .margin({ right: 12 })

        Column() {
          Row() {
            Text(talent.realName)
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
            Text(talent.studentType === StudentType.GRADUATING ? '应届' : '在校')
              .fontSize(10)
              .fontColor('#4A90D9')
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor('#F0F7FF')
              .borderRadius(6)
              .margin({ left: 6 })
            Blank()
            Text(`${talent.matchScore}%匹配`)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(AppConstants.COLOR_ACCENT)
          }
          .width('100%')
          .margin({ bottom: 4 })

          Text(`${talent.school} · ${talent.education} · ${talent.major}`)
            .fontSize(12)
            .fontColor('#666666')
            .margin({ bottom: 2 })
          Text(`意向: ${talent.expectedPosition}`)
            .fontSize(12)
            .fontColor('#999999')
            .margin({ bottom: 4 })

          Text(talent.interviewStatus)
            .fontSize(11)
            .fontColor('#FFFFFF')
            .padding({ left: 8, right: 8, top: 2, bottom: 2 })
            .backgroundColor(AppConstants.COLOR_SUCCESS)
            .borderRadius(8)
        }
        .layoutWeight(1)
        .alignItems(HorizontalAlign.Start)
      }
      .width('100%')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
    .shadow({ radius: 2, color: '#05000000', offsetY: 1 })
    .onClick(() => this.handleTalentClick(talent))
  }
}
