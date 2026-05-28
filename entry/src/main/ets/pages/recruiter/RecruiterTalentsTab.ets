// 招聘者 - 人才推荐与搜索页（Tab a: 人才）

import { router } from '@kit.ArkUI'
import { AppConstants } from '../../common/constants/AppConstants'
import { UserProfile, UserRole, StudentType } from '../../model/UserModel'
import { ResumeInfo } from '../../model/ResumeModel'
import { ResumeDao } from '../../service/ResumeDao'
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
}

@Component
export struct RecruiterTalentsTab {
  @State talents: TalentCard[] = []
  @State searchKeyword: string = ''
  @State showAdvancedSearch: boolean = false

  aboutToAppear(): void {
    this.loadMockTalents()
  }

  loadMockTalents(): void {
    // 模拟推荐数据
    this.talents = [
      { userId: '1', realName: '张同学', school: '中南大学', education: '本科', major: '计算机科学',
        expectedPosition: '前端开发', studentType: StudentType.GRADUATING, interviewStatus: '待筛选', matchScore: 95 },
      { userId: '2', realName: '李同学', school: '湖南大学', education: '硕士', major: '软件工程',
        expectedPosition: 'Java开发', studentType: StudentType.GRADUATING, interviewStatus: '已投递', matchScore: 88 },
      { userId: '3', realName: '王同学', school: '中南大学', education: '本科大三', major: '数据科学',
        expectedPosition: '数据分析（兼职）', studentType: StudentType.CURRENT, interviewStatus: '匹配', matchScore: 92 },
      { userId: '4', realName: '赵同学', school: '国防科大', education: '硕士', major: '人工智能',
        expectedPosition: '算法工程师', studentType: StudentType.GRADUATING, interviewStatus: '已约面', matchScore: 78 }
    ]
  }

  handleTalentClick(talent: TalentCard): void {
    router.pushUrl({
      url: AppConstants.ROUTE_TALENT_DETAIL,
      params: { userId: talent.userId }
    })
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
          .onChange((v) => this.searchKeyword = v)

        Button('高级')
          .fontSize(12)
          .height(32)
          .backgroundColor(this.showAdvancedSearch ? AppConstants.COLOR_ACCENT : '#F5F5F5')
          .fontColor(this.showAdvancedSearch ? '#FFFFFF' : '#666666')
          .borderRadius(16)
          .margin({ left: 6 })
          .onClick(() => this.showAdvancedSearch = !this.showAdvancedSearch)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // 高级搜索筛选栏
      if (this.showAdvancedSearch) {
        Row() {
          Text('学历:')
            .fontSize(12)
            .fontColor('#666666')
          Text('不限 本科 硕士')
            .fontSize(12)
            .fontColor('#4A90D9')
          Blank()
          Text('类型:')
            .fontSize(12)
            .fontColor('#666666')
          Text('应届 在校')
            .fontSize(12)
            .fontColor('#4A90D9')
        }
        .width('100%')
        .padding({ left: 16, right: 16, bottom: 8 })
      }

      Divider().height(1).color('#F0F0F0')

      // 人才瀑布流列表
      if (this.talents.length === 0) {
        Column() {
          Text('🔍')
            .fontSize(48)
            .margin({ bottom: 12 })
          Text('暂无匹配人才')
            .fontSize(14)
            .fontColor('#999999')
          Text('发布岗位后系统将自动推荐')
            .fontSize(12)
            .fontColor('#CCCCCC')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.talents, (talent: TalentCard) => {
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
        Text('👨‍🎓')
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
