import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { ResumeInfo } from '../../model/ResumeModel'
import { ResumeDao } from '../../service/ResumeDao'
import { UserDao } from '../../service/UserDao'
import { DatabaseHelper } from '../../database/DatabaseHelper'
import { TABLE_APPLICATION, TABLE_POST_FAVORITE, TABLE_MICRO_TASK } from '../../database/Tables'

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
  @State applicationCount: number = 0
  @State interviewCount: number = 0
  @State favoriteCount: number = 0
  @State microTaskCount: number = 0
  @State showSettings: boolean = false
  @State oldPassword: string = ''
  @State newPassword: string = ''
  @State confirmPassword: string = ''

  aboutToAppear(): void {
    this.loadCompleteness()
    this.loadStats()
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

  async loadStats(): Promise<void> {
    const user = AppState.currentUser
    if (!user) return
    try {
      const store = await DatabaseHelper.getInstance().getStore()
      const userId = user.userId

      // 投递数
      const appRs = await store.querySql(
        `SELECT COUNT(*) AS cnt FROM ${TABLE_APPLICATION} WHERE user_id = '${userId}'`
      )
      if (appRs.goToFirstRow()) {
        this.applicationCount = appRs.getLong(appRs.getColumnIndex('cnt'))
      }
      appRs.close()

      // 面试数
      const intRs = await store.querySql(
        `SELECT COUNT(*) AS cnt FROM ${TABLE_APPLICATION} WHERE user_id = '${userId}' AND status = 'interview'`
      )
      if (intRs.goToFirstRow()) {
        this.interviewCount = intRs.getLong(intRs.getColumnIndex('cnt'))
      }
      intRs.close()

      // 收藏数
      const favRs = await store.querySql(
        `SELECT COUNT(*) AS cnt FROM ${TABLE_POST_FAVORITE} WHERE user_id = '${userId}'`
      )
      if (favRs.goToFirstRow()) {
        this.favoriteCount = favRs.getLong(favRs.getColumnIndex('cnt'))
      }
      favRs.close()

      // 微任务数
      const taskRs = await store.querySql(
        `SELECT COUNT(*) AS cnt FROM ${TABLE_MICRO_TASK} WHERE accepted_by = '${userId}'`
      )
      if (taskRs.goToFirstRow()) {
        this.microTaskCount = taskRs.getLong(taskRs.getColumnIndex('cnt'))
      }
      taskRs.close()
    } catch (e) {
      // fallback to zero
    }
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
    Stack() {
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
          this.StatItemBuilder('投递数', `${this.applicationCount}`)
          this.StatItemBuilder('面试数', `${this.interviewCount}`)
          this.StatItemBuilder('收藏', `${this.favoriteCount}`)
          this.StatItemBuilder('微任务', `${this.microTaskCount}`)
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
          if (!this.guardLogin('设置需要登录')) {
            this.showSettings = true
          }
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

    // 设置弹窗
    if (this.showSettings) {
      Column() {
        Column()
          .width('100%')
          .layoutWeight(1)
          .backgroundColor('rgba(0,0,0,0.4)')
          .onClick(() => {
            this.showSettings = false
            this.oldPassword = ''
            this.newPassword = ''
            this.confirmPassword = ''
          })

        Column() {
          Text('账号设置')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#1A1A1A')
            .margin({ bottom: 16 })
            .alignSelf(ItemAlign.Start)

          Text('修改密码')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
            .margin({ bottom: 12 })
            .alignSelf(ItemAlign.Start)

          TextInput({ text: this.oldPassword, placeholder: '请输入当前密码' })
            .width('100%')
            .height(44)
            .fontSize(13)
            .placeholderColor('#BBBBBB')
            .type(InputType.Password)
            .backgroundColor('#F8F8F8')
            .borderRadius(8)
            .padding({ left: 12 })
            .margin({ bottom: 10 })
            .onChange((v: string) => this.oldPassword = v)

          TextInput({ text: this.newPassword, placeholder: '请输入新密码（至少6位）' })
            .width('100%')
            .height(44)
            .fontSize(13)
            .placeholderColor('#BBBBBB')
            .type(InputType.Password)
            .backgroundColor('#F8F8F8')
            .borderRadius(8)
            .padding({ left: 12 })
            .margin({ bottom: 10 })
            .onChange((v: string) => this.newPassword = v)

          TextInput({ text: this.confirmPassword, placeholder: '请再次输入新密码' })
            .width('100%')
            .height(44)
            .fontSize(13)
            .placeholderColor('#BBBBBB')
            .type(InputType.Password)
            .backgroundColor('#F8F8F8')
            .borderRadius(8)
            .padding({ left: 12 })
            .margin({ bottom: 20 })
            .onChange((v: string) => this.confirmPassword = v)

          Row() {
            Button('取消')
              .width('45%')
              .height(42)
              .fontSize(14)
              .backgroundColor('#F0F0F0')
              .fontColor('#666666')
              .borderRadius(21)
              .onClick(() => {
                this.showSettings = false
                this.oldPassword = ''
                this.newPassword = ''
                this.confirmPassword = ''
              })

            Button('确认修改')
              .width('45%')
              .height(42)
              .fontSize(14)
              .backgroundColor(AppConstants.COLOR_PRIMARY)
              .fontColor('#FFFFFF')
              .borderRadius(21)
              .onClick(async () => {
                const user = AppState.currentUser
                if (!user) return
                if (!this.oldPassword) {
                  AlertDialog.show({ message: '请输入当前密码' })
                  return
                }
                if (this.oldPassword !== user.password) {
                  AlertDialog.show({ message: '当前密码不正确' })
                  return
                }
                if (!this.newPassword || this.newPassword.length < 6) {
                  AlertDialog.show({ message: '新密码至少6位' })
                  return
                }
                if (this.newPassword !== this.confirmPassword) {
                  AlertDialog.show({ message: '两次输入的新密码不一致' })
                  return
                }
                await this.userDao.updatePassword(user.userId, this.newPassword)
                user.password = this.newPassword
                AppState.currentUser = user
                AppState.syncToStorage()
                this.showSettings = false
                this.oldPassword = ''
                this.newPassword = ''
                this.confirmPassword = ''
                AlertDialog.show({ message: '密码修改成功' })
              })
          }
          .width('100%')
          .justifyContent(FlexAlign.SpaceBetween)
        }
        .width('100%')
        .padding(24)
        .backgroundColor('#FFFFFF')
        .borderRadius({ topLeft: 16, topRight: 16 })
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
    }
    }
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
