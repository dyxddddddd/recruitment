// 求职者 - 个人中心页（Tab e: 我的 + 三方协议审查 + 简历管理）

import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { UserRole } from '../../model/UserModel'
import { UserDao } from '../../service/UserDao'

@Component
export struct JobSeekerProfileTab {
  @State showContractReview: boolean = false
  private userDao: UserDao = new UserDao()

  build() {
    Column() {
      // 个人信息头部
      Column() {
        Row() {
          Column() {
            Text(AppState.currentUser?.school || '未设置学校')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
            Text(AppState.currentUser?.major || '未设置专业')
              .fontSize(13)
              .fontColor('#666666')
              .margin({ top: 4 })
            if (AppState.isGuest) {
              Text('游客模式（仅浏览）')
                .fontSize(11)
                .fontColor(AppConstants.COLOR_WARNING)
                .margin({ top: 4 })
            }
          }
          .alignItems(HorizontalAlign.Start)

          Blank()

          Column() {
            Text('🧑‍🎓')
              .fontSize(48)
          }
        }
        .width('100%')
        .margin({ bottom: 12 })

        // 快捷统计
        Row() {
          this.StatItemBuilder('投递数', '12')
          this.StatItemBuilder('面试数', '3')
          this.StatItemBuilder('收藏', '8')
          this.StatItemBuilder('微任务', '5')
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceAround)
      }
      .width('100%')
      .padding(16)
      .backgroundColor('#FFFFFF')
      .borderRadius({ bottomLeft: 16, bottomRight: 16 })
      .shadow({ radius: 4, color: '#10000000', offsetY: 2 })

      // 功能菜单
      List() {
        ListItem() {
          Column() {
            this.MenuItemBuilder('📝', '我的简历', '管理你的在线简历')
          }
          .onClick(() => router.pushUrl({ url: AppConstants.ROUTE_RESUME_EDIT }))
        }

        ListItem() {
          this.MenuItemBuilder('📅', '我的课表', '导入课表，匹配弹性工时')
        }

        ListItem() {
          this.MenuItemBuilder('📊', '投递记录', '查看所有投递状态')
        }

        ListItem() {
          this.MenuItemBuilder('🤖', 'AI 招聘助手', '职场领航员，简历精修建议')
        }

        ListItem() {
          Column() {
            this.MenuItemBuilder('📋', '三方协议AI审查', '拍照上传，自动识别合同陷阱')
          }
          .onClick(() => this.showContractReview = !this.showContractReview)
        }

        // 创新点九：三方协议审查
        if (this.showContractReview) {
          ListItem() {
            Column() {
              Text('三方协议/劳动合同审查')
                .fontSize(14)
                .fontWeight(FontWeight.Medium)
                .margin({ bottom: 12 })
              Column() {
                Image($r('sys.symbol.doc_text'))
                  .width(40)
                  .height(40)
                  .fillColor('#4A90D9')
                  .margin({ bottom: 8 })
                Text('拍照上传三方协议')
                  .fontSize(13)
                  .fontColor('#4A90D9')
              }
              .width('100%')
              .height(120)
              .backgroundColor('#F0F7FF')
              .borderRadius(8)
              .justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
              .margin({ bottom: 12 })
              Text('法务大模型将在3秒内输出体检报告')
                .fontSize(11)
                .fontColor('#999999')
            }
            .width('100%')
            .padding(12)
          }
        }

        ListItem() {
          this.MenuItemBuilder('⚙️', '设置', '账号安全、隐私设置')
        }

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
        .fontSize(24)
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
