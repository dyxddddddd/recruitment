// 求职者 - 名企主页（Tab b: 名企）

import { router } from '@kit.ArkUI'
import { AppConstants } from '../../common/constants/AppConstants'
import { CompanyInfo, CareerTalk } from '../../model/CompanyModel'
import { CompanyDao } from '../../service/CompanyDao'

@Component
export struct JobSeekerCompaniesTab {
  @State companies: CompanyInfo[] = []
  @State careerTalks: CareerTalk[] = []
  @State activeView: number = 0 // 0=名企, 1=宣讲会
  private companyDao: CompanyDao = new CompanyDao()

  aboutToAppear(): void {
    this.loadData()
  }

  async loadData(): Promise<void> {
    this.companies = await this.companyDao.getCompanies()
    this.careerTalks = await this.companyDao.getCareerTalks()
  }

  handleCompanyClick(company: CompanyInfo): void {
    router.pushUrl({
      url: AppConstants.ROUTE_COMPANY_DETAIL,
      params: { companyId: company.companyId }
    })
  }

  build() {
    Column() {
      // 顶部搜索
      Row() {
        TextInput({ placeholder: '搜索企业名称' })
          .layoutWeight(1)
          .height(36)
          .fontSize(13)
          .backgroundColor('#F0F0F0')
          .borderRadius(18)
          .padding({ left: 16 })
        Image($r('sys.symbol.magnifyingglass'))
          .width(20)
          .height(20)
          .fillColor('#999999')
          .margin({ left: 8 })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // 子标签切换
      Row() {
        Text('名企专区')
          .fontSize(15)
          .fontWeight(this.activeView === 0 ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.activeView === 0 ? AppConstants.COLOR_PRIMARY : '#666666')
          .onClick(() => { this.activeView = 0 })
        Text('宣讲会')
          .fontSize(15)
          .fontWeight(this.activeView === 1 ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.activeView === 1 ? AppConstants.COLOR_PRIMARY : '#666666')
          .margin({ left: 24 })
          .onClick(() => { this.activeView = 1 })
        Blank()
      }
      .width('100%')
      .padding({ left: 16, top: 8, bottom: 8 })

      // 分割线
      Divider().height(1).color('#F0F0F0')

      if (this.activeView === 0) {
        // 名企列表
        List() {
          ForEach(this.companies, (company: CompanyInfo) => {
            ListItem() {
              this.CompanyCardBuilder(company)
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      } else {
        // 宣讲会列表
        List() {
          ForEach(this.careerTalks, (talk: CareerTalk) => {
            ListItem() {
              this.TalkCardBuilder(talk)
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  CompanyCardBuilder(company: CompanyInfo) {
    Row() {
      Column() {
        Text(company.logo || '🏢')
          .fontSize(40)
      }
      .width(56)
      .height(56)
      .borderRadius(12)
      .backgroundColor('#F5F5F5')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Column() {
        Text(company.name)
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        Row() {
          Text(company.industry)
            .fontSize(12)
            .fontColor('#666666')
          Text(' · ')
            .fontSize(12)
            .fontColor('#999999')
          Text(company.scale)
            .fontSize(12)
            .fontColor('#666666')
        }
        .margin({ top: 4 })

        if (company.recruitmentPlan) {
          Text(`${company.recruitmentPlan.year}届招聘 ${company.recruitmentPlan.totalPositions}个岗位`)
            .fontSize(11)
            .fontColor(AppConstants.COLOR_ACCENT)
            .margin({ top: 4 })
        }
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .layoutWeight(1)

      Image($r('sys.symbol.chevron_right'))
        .width(16)
        .height(16)
        .fillColor('#CCCCCC')
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
    .onClick(() => this.handleCompanyClick(company))
  }

  @Builder
  TalkCardBuilder(talk: CareerTalk) {
    Row() {
      Column() {
        Text(talk.date.split('-').pop() || '')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.COLOR_PRIMARY)
        Text(talk.date.split('-').slice(0, 2).join('/'))
          .fontSize(10)
          .fontColor('#999999')
      }
      .width(48)
      .alignItems(HorizontalAlign.Center)

      Column() {
        Text(talk.title)
          .fontSize(15)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
          .maxLines(1)
        Text(`${talk.companyName} · ${talk.time}`)
          .fontSize(12)
          .fontColor('#666666')
          .margin({ top: 4 })
        Row() {
          Text(talk.isOnline ? '线上' : talk.location)
            .fontSize(11)
            .fontColor('#999999')
          if (talk.isOnline && talk.onlineLink) {
            Text(' 加入链接')
              .fontSize(11)
              .fontColor(AppConstants.COLOR_PRIMARY)
          }
        }
        .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .margin({ left: 12 })
      .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
  }
}
