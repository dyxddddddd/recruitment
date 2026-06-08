import { router } from '@kit.ArkUI'
import { AppConstants } from '../../common/constants/AppConstants'
import { EducationItem, ExperienceItem, ResumeInfo } from '../../model/ResumeModel'
import { ResumeDao } from '../../service/ResumeDao'

@Entry
@Component
struct TalentDetailPage {
  @State resume: ResumeInfo | null = null
  @State showAIInterview: boolean = false
  private resumeDao: ResumeDao = new ResumeDao()

  async aboutToAppear(): Promise<void> {
    const params = router.getParams() as Record<string, Object>
    const userId = params['userId'] as string
    if (userId) {
      this.resume = await this.resumeDao.getResumeByUserId(userId)
    }
  }

  build() {
    Column() {
      this.PageHeader()

      if (!this.resume) {
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
      } else {
        Scroll() {
          Column() {
            this.HeroCard()
            this.SummaryGrid()
            this.EducationCard()
            this.ExperienceCard()
            this.SkillCard()
            this.IntroCard()
            this.InterviewCard()
            this.ActionBar()
          }
          .width('100%')
          .padding({ left: 16, right: 16, bottom: 24 })
        }
        .layoutWeight(1)
        .backgroundColor('#F4F6FB')
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
        Image($r('sys.symbol.chevron_left'))
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
    .padding({ left: 16, right: 16, top: 26, bottom: 14 })
    .linearGradient({
      angle: 135,
      colors: [['#FF7B54', 0], ['#FF9F6B', 1]]
    })
  }

  @Builder
  HeroCard() {
    if (this.resume) {
      Column() {
        Row() {
          Column() {
            Text(this.resume.realName || '未填写姓名')
              .fontSize(26)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')

            Text([
              this.resume.school || '学校待完善',
              this.resume.major || '专业待完善',
              this.resume.education || '学历待完善'
            ].join(' · '))
              .fontSize(12)
              .fontColor('#667085')
              .margin({ top: 8 })

            Text([
              this.resume.phone || '手机号待完善',
              this.resume.email || '邮箱待完善',
              this.resume.currentCity || '城市待完善'
            ].join(' · '))
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
          this.HeaderBadge(this.resume.expectedPosition || '待补充意向岗位', '#EEF5FF', '#2E6FD8')
          this.HeaderBadge(this.resume.expectedSalary || '待补充意向薪资', '#FFF3EE', AppConstants.COLOR_ACCENT)
          if (this.resume.hasSchedule) {
            this.HeaderBadge('课表空闲时段已同步', '#EDF9F1', '#279255')
          }
        }
        .width('100%')
        .margin({ top: 18 })

        if (this.resume.selfIntro.trim()) {
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
      .margin({ top: -18 })
    }
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
    if (this.resume) {
      Row() {
        this.MetricCard('匹配亮点', this.resume.skills.length > 0 ? `${this.resume.skills.length} 项技能` : '待补充', '#EEF5FF', '#2E6FD8')
        this.MetricCard('教育记录', this.resume.educationList.length > 0 ? `${this.resume.educationList.length} 段` : '暂无', '#FFF3EE', AppConstants.COLOR_ACCENT)
        this.MetricCard('实践经历', this.resume.experienceList.length > 0 ? `${this.resume.experienceList.length} 段` : '暂无', '#EDF9F1', '#279255')
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceBetween)
      .margin({ top: 14, bottom: 14 })
    }
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
    if (this.resume) {
      if (this.resume.educationList.length === 0) {
        this.EmptyHint('候选人还没有补充教育经历。')
      } else {
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
              Text(`${item.startYear || '起始时间待补充'} - ${item.endYear || '结束时间待补充'}`)
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
      }
    }
  }

  @Builder
  ExperienceSection() {
    if (this.resume) {
      if (this.resume.experienceList.length === 0) {
        this.EmptyHint('候选人还没有补充实习或项目经历。')
      } else {
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
      }
    }
  }

  @Builder
  SkillSection() {
    if (this.resume) {
      if (this.resume.skills.length === 0) {
        this.EmptyHint('候选人还没有整理技能关键词。')
      } else {
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
      }
    }
  }

  @Builder
  IntroSection() {
    if (this.resume) {
      if (!this.resume.selfIntro.trim()) {
        this.EmptyHint('候选人还没有填写个人介绍。')
      } else {
        Text(this.resume.selfIntro)
          .fontSize(13)
          .fontColor('#4C5665')
          .lineHeight(22)
          .width('100%')
      }
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
        Button(this.showAIInterview ? '收起' : '发起')
          .height(32)
          .fontSize(12)
          .backgroundColor(AppConstants.COLOR_AI_PURPLE)
          .fontColor('#FFFFFF')
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .onClick(() => {
            this.showAIInterview = !this.showAIInterview
            if (!this.showAIInterview) {
              AlertDialog.show({
                title: 'AI 邀约已发送',
                message: '系统会基于简历重点生成一轮结构化提问建议。'
              })
            }
          })
      }
      .width('100%')

      if (this.showAIInterview) {
        Column() {
          this.InterviewPoint('项目真实性核验', '#2E6FD8')
          this.InterviewPoint('表达逻辑与岗位适配', AppConstants.COLOR_ACCENT)
          this.InterviewPoint('时间安排与到岗灵活性', '#279255')
          this.InterviewPoint('综合沟通风险提示', AppConstants.COLOR_AI_PURPLE)
        }
        .width('100%')
        .margin({ top: 14 })
      }
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
        .width('46%')
        .height(44)
        .fontSize(14)
        .backgroundColor('#FFFFFF')
        .fontColor('#667085')
        .borderRadius(22)
      Button('发起面试')
        .width('46%')
        .height(44)
        .fontSize(14)
        .backgroundColor(AppConstants.COLOR_ACCENT)
        .fontColor('#FFFFFF')
        .borderRadius(22)
        .onClick(() => {
          AlertDialog.show({ message: '面试邀约已发送。' })
        })
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .margin({ top: 4, bottom: 10 })
  }
}
