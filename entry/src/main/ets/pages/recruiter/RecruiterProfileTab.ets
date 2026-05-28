// 招聘者 - 我的（Tab e: 人才管理控制台 + AI虚拟人数据大屏）

import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { UserRole, VipLevel } from '../../model/UserModel'
import { UserDao } from '../../service/UserDao'

@Component
export struct RecruiterProfileTab {
  @State showAIDashboard: boolean = false
  private userDao: UserDao = new UserDao()

  build() {
    Column() {
      Scroll() {
        Column() {
          // 个人头部
          Row() {
            Column() {
              Text(AppState.currentUser?.companyName || '未认证企业')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1A1A1A')
              Text(AppState.currentUser?.hrRealName || '未实名认证')
                .fontSize(13)
                .fontColor('#666666')
                .margin({ top: 4 })
              Row() {
                Text(AppState.currentUser?.vipLevel === VipLevel.VIP ? '💎 VIP' : '普通会员')
                  .fontSize(11)
                  .fontColor(AppState.currentUser?.vipLevel === VipLevel.VIP ? '#FFD700' : '#999999')
                  .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                  .backgroundColor(AppState.currentUser?.vipLevel === VipLevel.VIP ? '#FFF8E1' : '#F5F5F5')
                  .borderRadius(8)
              }
              .margin({ top: 6 })
            }
            .alignItems(HorizontalAlign.Start)
            Blank()
            Text('🏢')
              .fontSize(48)
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .margin({ bottom: 8 })

          // 创新点七：控制台数据大屏
          Text('控制台大屏')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .margin({ bottom: 12 })
            .alignSelf(ItemAlign.Start)

          // 网格数据卡片
          Grid() {
            GridItem() {
              Column() {
                Text('12')
                  .fontSize(28)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppConstants.COLOR_PRIMARY)
                Text('今日新增简历')
                  .fontSize(11)
                  .fontColor('#999999')
                  .margin({ top: 4 })
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .backgroundColor('#F0F7FF')
              .borderRadius(8)
            }

            GridItem() {
              Column() {
                Text('5')
                  .fontSize(28)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppConstants.COLOR_ACCENT)
                Text('待处理微任务验收')
                  .fontSize(11)
                  .fontColor('#999999')
                  .margin({ top: 4 })
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .backgroundColor('#FFF8F0')
              .borderRadius(8)
            }

            GridItem() {
              Column() {
                Text('3')
                  .fontSize(28)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppConstants.COLOR_SUCCESS)
                Text('今日AI面试数量')
                  .fontSize(11)
                  .fontColor('#999999')
                  .margin({ top: 4 })
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .backgroundColor('#F0FFF0')
              .borderRadius(8)
            }

            GridItem() {
              Column() {
                Text('87%')
                  .fontSize(28)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppConstants.COLOR_AI_PURPLE)
                Text('简历匹配率')
                  .fontSize(11)
                  .fontColor('#999999')
                  .margin({ top: 4 })
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .backgroundColor('#F8F0FF')
              .borderRadius(8)
            }
          }
          .columnsTemplate('1fr 1fr')
          .rowsTemplate('1fr 1fr')
          .columnsGap(8)
          .rowsGap(8)
          .width('100%')
          .height(180)
          .margin({ bottom: 16 })

          // 创新点七：AI虚拟人多模态评估入口
          Column() {
            Row() {
              Text('🤖 AI虚拟人一面评估大屏')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)

              Blank()

              Button(this.showAIDashboard ? '收起' : '展开')
                .fontSize(12)
                .height(28)
                .backgroundColor('#F0F7FF')
                .fontColor('#4A90D9')
                .borderRadius(14)
                .onClick(() => this.showAIDashboard = !this.showAIDashboard)
            }
            .width('100%')

            if (this.showAIDashboard) {
              Column() {
                Text('📊 多模态人才画像白皮书')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .margin({ bottom: 16 })

                // 雷达图占位（实际使用Canvas绘制）
                Column() {
                  Text('🕸️')
                    .fontSize(48)
                    .margin({ bottom: 8 })
                  Text('能力雷达图')
                    .fontSize(12)
                    .fontColor('#999999')
                }
                .width('100%')
                .height(120)
                .backgroundColor('#FAFAFA')
                .borderRadius(8)
                .justifyContent(FlexAlign.Center)
                .alignItems(HorizontalAlign.Center)
                .margin({ bottom: 14 })

                // 评估维度
                Row() {
                  this.AssessmentItem('抗压能力', '85', '#4A90D9')
                  this.AssessmentItem('表达逻辑', '78', '#FF6B35')
                  this.AssessmentItem('技术真实度', '92', '#52C41A')
                }
                .width('100%')
                .justifyContent(FlexAlign.SpaceAround)
                .margin({ bottom: 14 })

                Button('勾选简历并发送评估邀请')
                  .width('90%')
                  .height(40)
                  .fontSize(13)
                  .backgroundColor(AppConstants.COLOR_ACCENT)
                  .fontColor('#FFFFFF')
                  .borderRadius(20)

                Text('学生答题后，系统自动生成多维度评估报告')
                  .fontSize(10)
                  .fontColor('#CCCCCC')
                  .margin({ top: 8 })
              }
              .width('100%')
              .margin({ top: 12 })
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .margin({ bottom: 12 })

          // 功能菜单
          Column() {
            this.MenuItemBuilder('📋', '已发布岗位管理', '查看和管理所有在招岗位')
            this.MenuItemBuilder('👥', '简历收件箱', '查看已投递的学生简历')
            this.MenuItemBuilder('📅', '面试排期管理', '管理面试时间和安排')
            this.MenuItemBuilder('🔍', '人才搜索历史', '查看搜索记录和收藏')
            this.MenuItemBuilder('📊', '数据分析报告', '招聘数据统计与分析')
          }
          .width('100%')
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .margin({ bottom: 12 })

          // 设置
          Column() {
            Column() {
              this.MenuItemBuilder('🔐', '企业认证管理', '管理营业执照和实名认证')
            }
            .onClick(() => router.pushUrl({ url: AppConstants.ROUTE_RECRUITER_AUTH }))

            this.MenuItemBuilder('⚙️', '账号设置', '修改密码和通知设置')
          }
          .width('100%')
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .margin({ bottom: 16 })

          // 退出
          Button('退出登录')
            .width('60%')
            .height(40)
            .fontSize(14)
            .backgroundColor('#FF4D4F')
            .fontColor('#FFFFFF')
            .borderRadius(20)
            .margin({ bottom: 24 })
            .onClick(async () => {
              await this.userDao.logoutAll()
              AppState.currentUser = null
              AppState.isLoggedIn = false
              AppState.isGuest = true
              router.replaceUrl({ url: AppConstants.ROUTE_INDEX })
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  AssessmentItem(label: string, score: string, color: string) {
    Column() {
      Text(score)
        .fontSize(24)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(10)
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
          .fontSize(14)
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
  }
}
