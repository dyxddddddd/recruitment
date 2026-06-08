import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { ResumeInfo } from '../../model/ResumeModel'
import { ResumeDao } from '../../service/ResumeDao'
import { UserDao } from '../../service/UserDao'

export interface ProfileCompletenessResult {
  score: number
  missingFields: string[]
  tip: string
}

export interface FieldCheckItem {
  name: string
  ok: boolean
}

@Component
export struct JobSeekerProfileTab {
  private userDao: UserDao = new UserDao()
  private resumeDao: ResumeDao = new ResumeDao()

  @State profileCompleteness: number = 0
  @State missingFields: string[] = []
  @State completenessTip: string = ''
  @State profileResume: ResumeInfo | null = null

  aboutToAppear(): void {
    this.loadCompleteness()
  }

  async loadCompleteness(): Promise<void> {
    if (!AppState.currentUser) {
      return
    }
    const resume = await this.resumeDao.getResumeByUserId(AppState.currentUser.userId)
    this.profileResume = resume
    const result = this.computeProfileCompleteness(resume)
    this.profileCompleteness = result.score
    this.missingFields = result.missingFields
    this.completenessTip = result.tip
  }

  computeProfileCompleteness(resume: ResumeInfo | null): ProfileCompletenessResult {
    const fields: FieldCheckItem[] = [
      { name: '姓名', ok: !!resume?.realName },
      { name: '学校', ok: !!resume?.school },
      { name: '专业', ok: !!resume?.major },
      { name: '电话', ok: !!resume?.phone },
      { name: '教育经历', ok: resume?.educationList !== undefined && resume.educationList.length > 0 },
      { name: '工作经历', ok: resume?.experienceList !== undefined && resume.experienceList.length > 0 }
    ]

    let filledCount = 0
    const missing: string[] = []
    for (let i = 0; i < fields.length; i++) {
      if (fields[i].ok) {
        filledCount++
      } else {
        missing.push(fields[i].name)
      }
    }

    const score = Math.round((filledCount / fields.length) * 100)
    let tip: string = '基础信息还未填完，快去完善简历吧'
    if (score >= 80) {
      tip = '简历完整度很高，继续保持'
    } else if (score >= 50) {
      tip = '继续完善简历，可以提升曝光和回复率'
    }
    return { score: score, missingFields: missing, tip: tip }
  }

  getCompletenessColor(score: number): string {
    return score >= 60 ? '#52C41A' : score >= 40 ? '#FAAD14' : '#FF4D4F'
  }

  guardLogin(message: string): boolean {
    if (AppState.isGuest) {
      AlertDialog.show({
        title: '登录提示',
        message: `${message}，是否前往登录？`,
        primaryButton: {
          value: '去登录',
          action: () => router.pushUrl({ url: AppConstants.ROUTE_LOGIN })
        },
        secondaryButton: {
          value: '取消',
          action: () => {}
        }
      })
      return true
    }
    return false
  }

  openResume(): void {
    if (!this.guardLogin('管理在线简历需要登录')) {
      router.pushUrl({ url: AppConstants.ROUTE_RESUME_EDIT })
    }
  }

  openFlexCalendar(): void {
    if (!this.guardLogin('设置弹性工作日历需要登录')) {
      router.pushUrl({ url: AppConstants.ROUTE_FLEX_WORK_CALENDAR })
    }
  }

  build() {
    Column() {
      Column() {
        Row() {
          Column() {
            Text(this.profileResume?.school || AppState.currentUser?.school || '未设置学校')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
            Text(this.profileResume?.major || AppState.currentUser?.major || '未设置专业')
              .fontSize(13)
              .fontColor('#666666')
              .margin({ top: 4 })
            if (AppState.isGuest) {
              Text('游客模式，仅可浏览')
                .fontSize(11)
                .fontColor(AppConstants.COLOR_WARNING)
                .margin({ top: 4 })
            }
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Text('🎓')
            .fontSize(36)
            .margin({ right: 4 })
        }
        .width('100%')
        .margin({ bottom: 12 })

        Column() {
          Row() {
            Text('简历完整度')
              .fontSize(13)
              .fontColor('#666666')
            Blank()
            Text(`${this.profileCompleteness}%`)
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.getCompletenessColor(this.profileCompleteness))
            Text(`  ${this.completenessTip}`)
              .fontSize(11)
              .fontColor('#999999')
          }
          .width('100%')
          .margin({ bottom: 8 })

          Stack() {
            Row() {
              Divider()
                .height(6)
                .width(`${this.profileCompleteness}%`)
                .backgroundColor(this.getCompletenessColor(this.profileCompleteness))
                .borderRadius(3)
              Blank()
            }
            .width('100%')
          }
          .width('100%')
          .height(6)
          .backgroundColor('#F0F0F0')
          .borderRadius(3)
          .clip(true)
          .onClick(() => this.openResume())

          if (this.missingFields.length > 0) {
            Flex({ wrap: FlexWrap.Wrap }) {
              ForEach(this.missingFields, (field: string) => {
                Text(`缺少：${field}`)
                  .fontSize(11)
                  .fontColor('#FF6B35')
                  .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                  .backgroundColor('#FFF8F0')
                  .borderRadius(10)
                  .margin({ right: 6, bottom: 4 })
              })
            }
            .width('100%')
            .margin({ top: 8 })
          }
        }
        .width('100%')
        .padding(14)
        .backgroundColor('#FFFCF5')
        .borderRadius(12)
        .margin({ bottom: 12 })
        .border({ width: 1, color: '#FFF0E0' })

        Row() {
          this.StatItemBuilder('投递数', '0')
          this.StatItemBuilder('面试数', '0')
          this.StatItemBuilder('收藏', '0')
          this.StatItemBuilder('微任务', '0')
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceAround)
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius({ bottomLeft: 16, bottomRight: 16 })
      .shadow({ radius: 4, color: '#10000000', offsetY: 2 })

      List() {
        ListItem() {
          Column() {
            this.MenuItemBuilder('📝', '我的简历', '管理你的在线简历')
          }
        }
        .onClick(() => this.openResume())

        if (!AppState.isGuest) {
          ListItem() {
            Column() {
              this.MenuItemBuilder('🗓️', '弹性工时日历', '设置每周空闲时间，匹配微任务')
            }
          }
          .onClick(() => this.openFlexCalendar())
        }

        ListItem() {
          Column() {
            this.MenuItemBuilder('📬', '投递记录', '查看所有投递状态')
          }
        }
        .onClick(() => {
          if (!this.guardLogin('查看投递记录需要登录')) {
            router.pushUrl({ url: AppConstants.ROUTE_APPLICATION_TRACK })
          }
        })

        ListItem() {
          Column() {
            this.MenuItemBuilder('🤖', 'AI 招聘助手', '岗位分析、简历优化和求职建议')
          }
        }
        .onClick(() => {
          if (!this.guardLogin('使用 AI 招聘助手需要登录')) {
            router.pushUrl({ url: AppConstants.ROUTE_AI_ASSISTANT })
          }
        })

        ListItem() {
          Column() {
            this.MenuItemBuilder('🧠', 'AI 数字分身', '设置自动代聊底线与可用时间')
          }
        }
        .onClick(() => {
          if (!this.guardLogin('管理 AI 数字分身需要登录')) {
            router.pushUrl({ url: AppConstants.ROUTE_AI_DIGITAL_TWIN })
          }
        })

        ListItem() {
          Column() {
            this.MenuItemBuilder('📋', '三方协议 AI 审查', '拍照上传，自动识别合同风险')
          }
        }
        .onClick(() => {
          if (!this.guardLogin('三方协议审查需要登录')) {
            router.pushUrl({ url: AppConstants.ROUTE_CONTRACT_REVIEW })
          }
        })

        ListItem() {
          Column() {
            this.MenuItemBuilder('⚙️', '设置', '账号安全与隐私设置')
          }
        }
        .onClick(() => {
          this.guardLogin('设置需要登录')
        })

        if (!AppState.isGuest) {
          ListItem() {
            Button('退出登录')
              .width('60%')
              .height(40)
              .fontSize(14)
              .backgroundColor('#FF4D4F')
              .fontColor('#FFFFFF')
              .borderRadius(20)
              .margin({ top: 16 })
              .onClick(async () => {
                await this.userDao.logoutAll()
                AppState.currentUser = null
                AppState.isLoggedIn = false
                AppState.isGuest = true
                AppState.syncToStorage()
                router.replaceUrl({ url: AppConstants.ROUTE_INDEX })
              })
          }
        }

        if (AppState.isGuest) {
          ListItem() {
            Button('登录解锁全部功能')
              .width('60%')
              .height(40)
              .fontSize(14)
              .backgroundColor(AppConstants.COLOR_PRIMARY)
              .fontColor('#FFFFFF')
              .borderRadius(20)
              .margin({ top: 16 })
              .onClick(() => router.pushUrl({ url: AppConstants.ROUTE_LOGIN }))
          }
        }
      }
      .width('100%')
      .layoutWeight(1)
      .padding({ left: 16, right: 16, top: 8 })
      .backgroundColor('#F5F5F5')
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  StatItemBuilder(label: string, value: string) {
    Column() {
      Text(value)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(AppConstants.COLOR_PRIMARY)
      Text(label)
        .fontSize(11)
        .fontColor('#999999')
        .margin({ top: 2 })
    }
  }

  @Builder
  MenuItemBuilder(icon: string, title: string, subtitle: string) {
    Row() {
      Text(icon)
        .fontSize(22)
        .margin({ right: 12 })
      Column() {
        Text(title)
          .fontSize(15)
          .fontColor('#1A1A1A')
        Text(subtitle)
          .fontSize(11)
          .fontColor('#999999')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Image($r('sys.symbol.chevron_right'))
        .width(14)
        .height(14)
        .fillColor('#CCCCCC')
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
    .backgroundColor('#FFFFFF')
  }
}
