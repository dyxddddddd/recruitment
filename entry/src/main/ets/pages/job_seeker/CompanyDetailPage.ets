// 求职者 - 名企详情页（含校友图谱）

import { router } from '@kit.ArkUI'
import { AppConstants } from '../../common/constants/AppConstants'
import { CompanyInfo, CareerTalk, AlumniNode } from '../../model/CompanyModel'
import { CompanyDao } from '../../service/CompanyDao'

@Entry
@Component
struct CompanyDetailPage {
  @State company: CompanyInfo | null = null
  @State careerTalks: CareerTalk[] = []
  @State alumniNetwork: AlumniNode[] = []
  @State showAlumniGraph: boolean = false
  private companyDao: CompanyDao = new CompanyDao()

  async aboutToAppear(): Promise<void> {
    const params = router.getParams() as Record<string, Object>
    const companyId = params['companyId'] as string
    if (companyId) {
      this.company = await this.companyDao.getCompanyById(companyId)
      if (this.company) {
        this.careerTalks = this.company.careerTalks
        this.alumniNetwork = this.company.alumniNetwork || []
      }
    }
  }

  build() {
    Column() {
      if (!this.company) {
        Text('加载中...')
      } else {
        // 顶部导航
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
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 28, bottom: 12 })
        .backgroundColor(AppConstants.COLOR_PRIMARY)

        Scroll() {
          Column() {
            // 企业信息
            Column() {
              Text(this.company.logo || '🏢')
                .fontSize(56)
                .margin({ bottom: 12 })
              Text(this.company.name)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
              Text(this.company.industry)
                .fontSize(13)
                .fontColor('rgba(255,255,255,0.8)')
                .margin({ top: 4 })
              Text(`${this.company.scale} · ${this.company.address}`)
                .fontSize(12)
                .fontColor('rgba(255,255,255,0.6)')
                .margin({ top: 4 })
            }
            .width('100%')
            .padding({ top: 24, bottom: 32 })
            .backgroundColor(AppConstants.COLOR_PRIMARY)

            // 企业简介
            Column() {
              Text('企业简介')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .margin({ bottom: 8 })
                .alignSelf(ItemAlign.Start)
              Text(this.company.description)
                .fontSize(14)
                .fontColor('#666666')
                .lineHeight(22)
            }
            .width('90%')
            .padding(16)
            .backgroundColor('#FFFFFF')
            .borderRadius(12)
            .margin({ top: -12, bottom: 12 })
            .shadow({ radius: 4, color: '#10000000', offsetY: 2 })

            // 招聘计划
            if (this.company.recruitmentPlan) {
              Column() {
                Text(`${this.company.recruitmentPlan.year}届招聘计划`)
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .margin({ bottom: 8 })
                  .alignSelf(ItemAlign.Start)
                Text(`${this.company.recruitmentPlan.totalPositions}个岗位`)
                  .fontSize(24)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppConstants.COLOR_ACCENT)
                  .margin({ bottom: 8 })
                Text(this.company.recruitmentPlan.descriptions)
                  .fontSize(13)
                  .fontColor('#666666')
              }
              .width('90%')
              .padding(16)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .margin({ bottom: 12 })
            }

            // 宣讲会
            if (this.careerTalks.length > 0) {
              Column() {
                Text('近期宣讲会')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .margin({ bottom: 12 })
                  .alignSelf(ItemAlign.Start)

                ForEach(this.careerTalks, (talk: CareerTalk) => {
                  Row() {
                    Column() {
                      Text(talk.date.split('-').pop() || '')
                        .fontSize(20)
                        .fontWeight(FontWeight.Bold)
                        .fontColor(AppConstants.COLOR_PRIMARY)
                      Text('日')
                        .fontSize(10)
                        .fontColor('#999999')
                    }
                    .width(36)
                    Column() {
                      Text(talk.title)
                        .fontSize(14)
                        .fontWeight(FontWeight.Medium)
                      Text(`${talk.time} · ${talk.isOnline ? '线上' : talk.location}`)
                        .fontSize(11)
                        .fontColor('#999999')
                        .margin({ top: 2 })
                    }
                    .alignItems(HorizontalAlign.Start)
                    .margin({ left: 12 })
                    .layoutWeight(1)
                  }
                  .width('100%')
                  .padding({ top: 10, bottom: 10 })
                  .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
                })
              }
              .width('90%')
              .padding(16)
              .backgroundColor('#FFFFFF')
              .borderRadius(12)
              .margin({ bottom: 12 })
            }

            // 创新点八：校友图谱
            Column() {
              Row() {
                Text('校友引路人图谱')
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .alignSelf(ItemAlign.Start)

                Blank()

                Button(this.showAlumniGraph ? '收起' : '展开')
                  .fontSize(12)
                  .height(28)
                  .backgroundColor('#F0F7FF')
                  .fontColor('#4A90D9')
                  .borderRadius(14)
                  .onClick(() => this.showAlumniGraph = !this.showAlumniGraph)
              }
              .width('100%')

              if (this.showAlumniGraph && this.alumniNetwork.length > 0) {
                // 拓扑图占位区（实际开发使用Canvas组件绘制拓扑图）
                Column() {
                  Text('🎓 校友连线图')
                    .fontSize(14)
                    .fontColor('#4A90D9')
                    .margin({ bottom: 12 })

                  // 简化版校友列表代替拓扑图
                  ForEach(this.alumniNetwork, (alumni: AlumniNode) => {
                    Row() {
                      Text('👤')
                        .fontSize(28)
                        .margin({ right: 10 })
                      Column() {
                        Text(`${alumni.school} · ${alumni.major}`)
                          .fontSize(13)
                          .fontWeight(FontWeight.Medium)
                        Text(`${alumni.department} - ${alumni.position}`)
                          .fontSize(11)
                          .fontColor('#666666')
                          .margin({ top: 2 })
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)
                      Button('请教面经')
                        .fontSize(11)
                        .height(28)
                        .backgroundColor(AppConstants.COLOR_PRIMARY)
                        .fontColor('#FFFFFF')
                        .borderRadius(14)
                        .padding({ left: 12, right: 12 })
                    }
                    .width('100%')
                    .padding({ top: 8, bottom: 8 })
                    .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
                  })

                  Text('以上校友均匿名展示，发起沟通后对方可选择是否接受')
                    .fontSize(10)
                    .fontColor('#CCCCCC')
                    .margin({ top: 8 })
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
}
