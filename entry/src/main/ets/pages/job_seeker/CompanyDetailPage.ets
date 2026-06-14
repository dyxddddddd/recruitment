// 求职者 - 名企详情页（含校友图谱）

import { router } from '@kit.ArkUI'
import { AppConstants } from '../../common/constants/AppConstants'
import { CompanyInfo, CareerTalk, AlumniNode } from '../../model/CompanyModel'
import { CompanyDao } from '../../service/CompanyDao'

interface PositionResult {
  x: number
  y: number
}

@Entry
@Component
struct CompanyDetailPage {
  @State company: CompanyInfo | null = null
  @State careerTalks: CareerTalk[] = []
  @State alumniNetwork: AlumniNode[] = []
  @State showAlumniGraph: boolean = false
  @State selectedAlumni: AlumniNode | null = null
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
          .width('100%')
          .height('100%')
          .textAlign(TextAlign.Center)
      } else {
        // 顶部导航
        Row() {
          Button() {
            Image($r('app.media.ic_back'))
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

            // 创新点八：校友拓扑图
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
                Column() {
                  Text('🎓 校友连线拓扑图')
                    .fontSize(14)
                    .fontColor('#4A90D9')
                    .margin({ bottom: 8 })

                  // 可点击拓扑节点（替代 Canvas）
                  TopologyStackView({ alumniNetwork: this.alumniNetwork, selectedAlumni: $selectedAlumni })
                    .margin({ bottom: 12 })

                  // 选中校友操作
                  if (this.selectedAlumni) {
                    Row() {
                      Column() {
                        Text(`${this.selectedAlumni.school} · ${this.selectedAlumni.major}`)
                          .fontSize(13)
                          .fontWeight(FontWeight.Medium)
                          .fontColor('#1A1A1A')
                        Text(`${this.selectedAlumni.department} - ${this.selectedAlumni.position}`)
                          .fontSize(11)
                          .fontColor('#666666')
                          .margin({ top: 2 })
                      }
                      .alignItems(HorizontalAlign.Start)
                      .layoutWeight(1)
                      Button('请教面经')
                        .fontSize(12)
                        .height(30)
                        .backgroundColor(AppConstants.COLOR_PRIMARY)
                        .fontColor('#FFFFFF')
                        .borderRadius(15)
                        .padding({ left: 14, right: 14 })
                        .onClick(() => AlertDialog.show({ message: '已向该校友发起请教请求，请等待对方确认' }))
                      Button('关闭')
                        .fontSize(12)
                        .height(30)
                        .backgroundColor('#F5F5F5')
                        .fontColor('#999999')
                        .borderRadius(15)
                        .padding({ left: 12, right: 12 })
                        .margin({ left: 8 })
                        .onClick(() => { this.selectedAlumni = null })
                    }
                    .width('100%')
                    .padding(10)
                    .backgroundColor('#F0F7FF')
                    .borderRadius(8)
                    .margin({ bottom: 8 })
                  }

                  // 校友卡片列表
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

// ---- Stack 布局可点击拓扑图组件（创新点八）----
@Component
export struct TopologyStackView {
  @Prop alumniNetwork: AlumniNode[] = []
  @Link selectedAlumni: AlumniNode | null
  @State containerWidth: number = 320
  @State containerHeight: number = 200

  getNodePosition(index: number, total: number, isCenter: boolean): PositionResult {
    if (isCenter) {
      const x = this.containerWidth / 2 - 28
      const y = this.containerHeight / 2 - 28
      const result: PositionResult = { x, y }
      return result
    }
    const angle = (index / total) * 2 * Math.PI - Math.PI / 2
    const ringRadius = Math.min(this.containerWidth, this.containerHeight) * 0.38
    const cx = this.containerWidth / 2
    const cy = this.containerHeight / 2
    const nodeRadius = 18
    const x = cx + ringRadius * Math.cos(angle) - nodeRadius
    const y = cy + ringRadius * Math.sin(angle) - nodeRadius
    const result: PositionResult = { x, y }
    return result
  }

  build() {
    Stack() {
      // 背景 + 连线（用 Divider 实现）
      ForEach(this.alumniNetwork, (alumni: AlumniNode, i: number) => {
        Divider()
          .width(Math.min(this.containerWidth, this.containerHeight) * 0.38)
          .height(1.5)
          .color('rgba(74,144,217,0.35)')
          .rotate({
            z: 1,
            angle: (i / Math.max(this.alumniNetwork.length, 1)) * 360
          })
      })

      // 中心企业节点
      Column() {
        Text('企业')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
      }
      .width(56)
      .height(56)
      .borderRadius(28)
      .backgroundColor(AppConstants.COLOR_PRIMARY)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .position({
        x: this.containerWidth / 2 - 28,
        y: this.containerHeight / 2 - 28
      })

      // 校友节点
      ForEach(this.alumniNetwork, (alumni: AlumniNode, i: number) => {
        Column() {
          Text(alumni.school?.substring(0, 4) || '校友')
            .fontSize(10)
            .fontColor('#FFFFFF')
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor(AppConstants.COLOR_AI_PURPLE)
        .justifyContent(FlexAlign.Center)
        .alignItems(HorizontalAlign.Center)
        .border({
          width: this.selectedAlumni?.alumniId === alumni.alumniId ? 2 : 0,
          color: '#FFD700'
        })
        .position({
          x: this.getNodePosition(i, this.alumniNetwork.length, false).x,
          y: this.getNodePosition(i, this.alumniNetwork.length, false).y
        })
        .onClick(() => {
          this.selectedAlumni = alumni
        })
      })

      // 提示文字
      Text('点击节点了解详情')
        .fontSize(10)
        .fontColor('#CCCCCC')
        .position({ x: 0, y: this.containerHeight - 20 })
    }
    .width('100%')
    .height(200)
    .clip(true)
  }
}

