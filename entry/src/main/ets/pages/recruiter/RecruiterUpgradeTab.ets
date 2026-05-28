// 招聘者 - 会员升级页（Tab c: 升级/VIP）

import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { VipLevel } from '../../model/UserModel'

@Component
export struct RecruiterUpgradeTab {
  @State currentPlan: string = VipLevel.NORMAL

  build() {
    Column() {
      Scroll() {
        Column() {
          // 顶部标题
          Text('会员服务')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .margin({ top: 24, bottom: 8 })
          Text('升级VIP解锁更多招聘权益')
            .fontSize(13)
            .fontColor('#999999')
            .margin({ bottom: 24 })

          // 当前会员状态卡片
          Row() {
            Column() {
              Text(AppState.currentUser?.vipLevel === VipLevel.VIP ? 'VIP 会员' : '普通会员')
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
              Text('当前在招岗位数')
                .fontSize(12)
                .fontColor('rgba(255,255,255,0.7)')
                .margin({ top: 4 })
              Text(`${AppState.currentUser?.positionCount || 0}`)
                .fontSize(28)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
                .margin({ top: 4 })
            }
            .alignItems(HorizontalAlign.Start)
            .layoutWeight(1)

            Text('💎')
              .fontSize(48)
          }
          .width('90%')
          .padding(20)
          .backgroundColor(AppConstants.COLOR_ACCENT)
          .borderRadius(16)
          .margin({ bottom: 24 })

          // 会员权益对比表
          Text('会员权益对比')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .margin({ bottom: 12 })
            .alignSelf(ItemAlign.Start)

          Column() {
            // 表头
            Row() {
              Text('权益项')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .width(80)
              Text('普通会员')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .width(70)
                .textAlign(TextAlign.Center)
              Text('VIP会员')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .width(70)
                .textAlign(TextAlign.Center)
                .fontColor(AppConstants.COLOR_ACCENT)
            }
            .width('100%')
            .padding({ top: 10, bottom: 10 })
            .backgroundColor('#F5F5F5')
            .borderRadius(8)

            this.CompareRow('在招岗位', '1个', '无限')
            this.CompareRow('AI虚拟人面试', '限5次', '无限次')
            this.CompareRow('人才搜索次数', '10次/天', '无限次')
            this.CompareRow('微任务发布', '限3个', '无限')
            this.CompareRow('数据分析报告', '基础版', '完整版')
            this.CompareRow('优先推荐', '✕', '✓')
            this.CompareRow('专属客服', '✕', '✓')
            this.CompareRow('企业品牌展示', '基础', '高级认证')
          }
          .width('90%')
          .margin({ bottom: 24 })

          // 价格方案
          Column() {
            Text('选择方案')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 12 })
              .alignSelf(ItemAlign.Start)

            Row() {
              // 月卡
              Column() {
                Text('月卡')
                  .fontSize(15)
                  .fontWeight(FontWeight.Medium)
                Text('¥299')
                  .fontSize(28)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppConstants.COLOR_ACCENT)
                  .margin({ top: 4 })
                Text('/月')
                  .fontSize(11)
                  .fontColor('#999999')
              }
              .width('42%')
              .padding(16)
              .backgroundColor('#FFF8F0')
              .border({ width: 2, color: '#FF6B35', radius: 12 })
              .alignItems(HorizontalAlign.Center)
              .onClick(() => {})

              // 年卡（推荐）
              Column() {
                Text('🔖 年卡 · 推荐')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#FFFFFF')
                  .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                  .backgroundColor('#FF6B35')
                  .borderRadius(8)
                  .margin({ bottom: 8 })
                Text('¥2,999')
                  .fontSize(28)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppConstants.COLOR_ACCENT)
                  .margin({ top: 4 })
                Text('/年（省¥589）')
                  .fontSize(11)
                  .fontColor('#999999')
              }
              .width('42%')
              .padding(16)
              .backgroundColor('#FFF0E5')
              .border({ width: 2, color: '#FF6B35', radius: 12 })
              .alignItems(HorizontalAlign.Center)
              .margin({ left: 12 })
              .onClick(() => {})
            }
            .width('90%')
            .justifyContent(FlexAlign.Center)
          }
          .margin({ bottom: 24 })

          // 开通按钮
          Button('立即开通 VIP')
            .width('80%')
            .height(48)
            .fontSize(16)
            .backgroundColor(AppConstants.COLOR_ACCENT)
            .fontColor('#FFFFFF')
            .borderRadius(24)
            .onClick(() => {
              AlertDialog.show({
                title: '确认开通',
                message: '将使用鸿蒙原生支付进行购买。确认开通VIP会员？',
                primaryButton: { value: '确认支付', action: () => {} },
                secondaryButton: { value: '取消', action: () => {} }
              })
            })
            .margin({ bottom: 8 })

          Text('自动续费，可随时取消')
            .fontSize(11)
            .fontColor('#CCCCCC')
            .margin({ bottom: 32 })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  CompareRow(feature: string, normal: string, vip: string) {
    Row() {
      Text(feature)
        .fontSize(13)
        .fontColor('#666666')
        .width(80)
      Text(normal)
        .fontSize(13)
        .fontColor('#999999')
        .width(70)
        .textAlign(TextAlign.Center)
      Text(vip)
        .fontSize(13)
        .fontWeight(FontWeight.Medium)
        .fontColor(AppConstants.COLOR_ACCENT)
        .width(70)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
  }
}
