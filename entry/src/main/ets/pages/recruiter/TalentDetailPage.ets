// 招聘者 - 人才详情页（含简历信息 + AI面试邀请）

import { router } from '@kit.ArkUI'
import { AppConstants } from '../../common/constants/AppConstants'
import { ResumeInfo, EducationItem, ExperienceItem } from '../../model/ResumeModel'
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
      Row() {
        Button() {
          Image($r('sys.symbol.chevron_left'))
            .width(24)
            .height(24)
            .fillColor('#FFFFFF')
        }
        .backgroundColor('transparent')
        .onClick(() => router.back())
        Blank()
        Text('人才详情')
          .fontSize(16)
          .fontColor('#FFFFFF')
        Blank()
        Image($r('sys.symbol.star'))
          .width(22)
          .height(22)
          .fillColor('#FFFFFF')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 28, bottom: 12 })
      .backgroundColor(AppConstants.COLOR_ACCENT)

      if (!this.resume) {
        Column() {
          Text('加载中...')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            Column() {
              Text('人才卡片')
                .fontSize(56)
                .margin({ bottom: 12 })
              Text(this.resume.realName)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
              Text(`${this.resume.school} · ${this.resume.major}`)
                .fontSize(13)
                .fontColor('rgba(255,255,255,0.8)')
                .margin({ top: 4 })
              Text(`意向: ${this.resume.expectedPosition} · ${this.resume.expectedSalary}`)
                .fontSize(12)
                .fontColor('rgba(255,255,255,0.6)')
                .margin({ top: 4 })
            }
            .width('100%')
            .padding({ top: 20, bottom: 28 })
            .backgroundColor(AppConstants.COLOR_ACCENT)
            .alignItems(HorizontalAlign.Center)

            // 教育背景
            Column() {
              this.SectionTitle('教育背景')
              if (this.resume.educationList.length > 0) {
                ForEach(this.resume.educationList, (item: EducationItem) => {
                  Row() {
                    Text('学校')
                      .fontSize(20)
                      .margin({ right: 10 })
                    Column() {
                      Text(item.schoolName)
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                      Text(`${item.major} · ${item.degree} · ${item.startYear}-${item.endYear}`)
                        .fontSize(11)
                        .fontColor('#666666')
                        .margin({ top: 2 })
                    }
                    .alignItems(HorizontalAlign.Start)
                  }
                  .width('100%')
                  .padding({ top: 8, bottom: 8 })
                })
              } else {
                Text(`${this.resume.school} · ${this.resume.education}`)
                  .fontSize(13)
                  .fontColor('#666666')
              }
            }
            .width('90%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .margin({ top: -12, bottom: 12 })
            .shadow({ radius: 4, color: '#10000000', offsetY: 2 })

            // 实习/项目经历
            if (this.resume.experienceList.length > 0) {
              Column() {
                this.SectionTitle('实习/项目经历')
                ForEach(this.resume.experienceList, (item: ExperienceItem) => {
                  Column() {
                    Row() {
                      Text(item.type === 'intern' ? '实习' : '项目')
                        .fontSize(10)
                        .fontColor('#FFFFFF')
                        .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                        .backgroundColor(item.type === 'intern' ? '#4A90D9' : '#FF6B35')
                        .borderRadius(6)
                      Text(item.companyName || item.projectName || '')
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                        .margin({ left: 6 })
                    }
                    .margin({ bottom: 4 })

                    Text(item.description)
                      .fontSize(12)
                      .fontColor('#666666')
                      .maxLines(4)
                      .margin({ bottom: 2 })
                    Text(`${item.startTime} - ${item.endTime}`)
                      .fontSize(10)
                      .fontColor('#CCCCCC')
                  }
                  .width('100%')
                  .padding({ top: 8, bottom: 8 })
                  .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
                })
              }
              .width('90%')
              .padding(16)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .margin({ bottom: 12 })
            }

            // 技能
            Column() {
              this.SectionTitle('技能标签')
              Flex({ wrap: FlexWrap.Wrap }) {
                ForEach(this.resume.skills, (skill: string) => {
                  Text(skill)
                    .fontSize(12)
                    .fontColor('#4A90D9')
                    .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                    .backgroundColor('#F0F7FF')
                    .borderRadius(12)
                    .margin({ right: 6, bottom: 6 })
                })
              }
              .width('100%')
            }
            .width('90%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .margin({ bottom: 12 })

            // 自我介绍
            if (this.resume.selfIntro) {
              Column() {
                this.SectionTitle('自我介绍')
                Text(this.resume.selfIntro)
                  .fontSize(13)
                  .fontColor('#666666')
                  .lineHeight(20)
              }
              .width('90%')
              .padding(16)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .margin({ bottom: 12 })
            }

            // AI虚拟人面试邀请
            Column() {
              Row() {
                Text('AI虚拟人一面')
                  .fontSize(15)
                  .fontWeight(FontWeight.Bold)
                Blank()
                Button(this.showAIInterview ? '收起' : '发送面试邀请')
                  .fontSize(12)
                  .height(30)
                  .backgroundColor(AppConstants.COLOR_AI_PURPLE)
                  .fontColor('#FFFFFF')
                  .borderRadius(15)
                  .onClick(() => {
                    this.showAIInterview = !this.showAIInterview
                    if (!this.showAIInterview) {
                      AlertDialog.show({
                        title: '面试邀请已发送',
                        message: 'AI虚拟人将在24小时内对候选人进行多模态一面评估，评估完成后将生成多模态人才画像白皮书。'
                      })
                    }
                  })
              }
              .width('100%')

              if (this.showAIInterview) {
                Column() {
                  Text('AI虚拟人将自动完成以下评估维度：')
                    .fontSize(12)
                    .fontColor('#666666')
                    .margin({ bottom: 10 })
                  Row() {
                    Text('抗压能力评估')
                      .fontSize(12)
                      .fontColor('#4A90D9')
                      .margin({ right: 16 })
                    Text('表达逻辑分析')
                      .fontSize(12)
                      .fontColor('#FF6B35')
                  }
                  .margin({ bottom: 4 })
                  Row() {
                    Text('技术真实度检测')
                      .fontSize(12)
                      .fontColor('#52C41A')
                      .margin({ right: 16 })
                    Text('综合适配评分')
                      .fontSize(12)
                      .fontColor('#7B68EE')
                  }
                  .margin({ bottom: 12 })
                  Text('评估完成后将生成雷达图数据大屏，在控制台可查看')
                    .fontSize(10)
                    .fontColor('#CCCCCC')
                }
                .width('100%')
                .margin({ top: 12 })
              }
            }
            .width('90%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .margin({ bottom: 20 })

            // 操作按钮
            Row() {
              Button('拒绝')
                .width('40%')
                .height(44)
                .fontSize(14)
                .backgroundColor('#F5F5F5')
                .fontColor('#666666')
                .borderRadius(22)

              Button('约面试')
                .width('40%')
                .height(44)
                .fontSize(14)
                .backgroundColor(AppConstants.COLOR_ACCENT)
                .fontColor('#FFFFFF')
                .borderRadius(22)
                .onClick(() => {
                  AlertDialog.show({ message: '面试邀请已发送！' })
                })
            }
            .width('90%')
            .justifyContent(FlexAlign.SpaceAround)
            .margin({ bottom: 24 })
          }
          .width('100%')
        }
        .width('100%')
        .layoutWeight(1)
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SectionTitle(title: string) {
    Text(title)
      .fontSize(15)
      .fontWeight(FontWeight.Bold)
      .margin({ bottom: 8 })
      .alignSelf(ItemAlign.Start)
  }
}
