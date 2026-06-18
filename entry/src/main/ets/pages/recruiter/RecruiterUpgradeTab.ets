// 招聘者 - 会员升级页（Tab c: 升级/VIP）
// 商业变现中心：权益对比 + 定价方案 + 鸿蒙原生支付

import { promptAction } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { VipLevel } from '../../model/UserModel'
import { UserDao } from '../../service/UserDao'

enum PlanType {
  MONTHLY = 'monthly',
  QUARTERLY = 'quarterly',
  YEARLY = 'yearly'
}

interface BenefitItem {
  category: string
  feature: string
  normal: string
  vip: string
  highlight: boolean
}

@Component
export struct RecruiterUpgradeTab {
  @State selectedPlan: PlanType = PlanType.YEARLY
  @State showFaq: boolean = false
  @State isUpgrading: boolean = false
  @State isVip: boolean = this.checkVipActive()
  @State isLifetime: boolean = AppState.currentUser?.vipLifetime ?? false
  @State vipExpireTime: number = AppState.currentUser?.vipExpireTime ?? 0
  @State positionCount: number = AppState.currentUser?.positionCount ?? 0
  @State showMockPayDialog: boolean = false
  @State mockPayStep: string = ''
  @State showPayPassword: boolean = false
  @State payPasswordInput: string = ''
  @State payPasswordError: boolean = false
  @StorageLink('app_is_logged_in') isLoggedIn: boolean = false
  private userDao: UserDao = new UserDao()

  checkVipActive(): boolean {
    const user = AppState.currentUser
    if (!user || user.vipLevel !== VipLevel.VIP) return false
    if (user.vipLifetime) return true
    if (user.vipExpireTime && user.vipExpireTime > Date.now()) return true
    return false
  }

  private readonly benefits: BenefitItem[] = [
    { category: '招聘发布', feature: '同时在招岗位数', normal: '1 个', vip: '无限发布', highlight: true },
    { category: '招聘发布', feature: '微任务发布数', normal: '3 个', vip: '无限发布', highlight: true },
    { category: '招聘发布', feature: '岗位置顶推荐', normal: '✕', vip: '✓ 每日3次', highlight: true },
    { category: '招聘发布', feature: '岗位紧急标注', normal: '✕', vip: '✓', highlight: false },
    { category: 'AI 智能工具', feature: 'AI虚拟人面试', normal: '5 次/月', vip: '无限次', highlight: true },
    { category: 'AI 智能工具', feature: 'AI招聘描述生成', normal: '3 次/月', vip: '无限次', highlight: true },
    { category: 'AI 智能工具', feature: '红线扫描检测', normal: '✓', vip: '✓ 增强版', highlight: false },
    { category: 'AI 智能工具', feature: 'AI工时拼图算法', normal: '✕', vip: '✓', highlight: true },
    { category: '人才搜索', feature: '人才高级搜索', normal: '10 次/天', vip: '无限次', highlight: true },
    { category: '人才搜索', feature: '简历查看与下载', normal: '5 份/天', vip: '无限份', highlight: true },
    { category: '人才搜索', feature: '校友图谱查看', normal: '✕', vip: '✓', highlight: true },
    { category: '数据分析', feature: '招聘数据报告', normal: '基础摘要', vip: '完整分析报告', highlight: true },
    { category: '数据分析', feature: '人才画像白皮书', normal: '✕', vip: '✓ 多模态评估', highlight: true },
    { category: '数据分析', feature: '市场薪酬洞察', normal: '✕', vip: '✓ 季度报告', highlight: false },
    { category: '专属服务', feature: '一对一专属客服', normal: '✕', vip: '✓ 5分钟响应', highlight: true },
    { category: '专属服务', feature: '面试排期助手', normal: '基础', vip: '智能排期', highlight: false },
    { category: '品牌展示', feature: '企业认证标识', normal: '基础认证', vip: '🏅 高级认证', highlight: true },
    { category: '品牌展示', feature: '企业主页装修', normal: '✕', vip: '✓ 自定义品牌页', highlight: false },
    { category: '品牌展示', feature: '宣讲会优先展示', normal: '✕', vip: '✓ 首页推荐', highlight: true }
  ]

  build() {
    Column() {
      Scroll() {
        Column() {
          this.HeroBanner()
          Divider().color('#F5F5F5').width('100%').height(8)
          this.QuotaDashboard()
          Divider().color('#F5F5F5').width('100%').height(8)
          this.BenefitComparison()
          Divider().color('#F5F5F5').width('100%').height(8)
          this.PricingPlans()
          Divider().color('#F5F5F5').width('100%').height(8)
          this.PaymentSection()
          Divider().color('#F5F5F5').width('100%').height(8)
          this.FaqSection()
          this.BottomSpacer()
        }
        .width('100%')
      }
      .width('100%')
      .layoutWeight(1)
      .edgeEffect(EdgeEffect.Spring)

      this.BottomButton()

      if (this.showPayPassword) {
        this.PayPasswordDialog()
      }

      if (this.isUpgrading) {
        this.MockPayOverlay()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  // ========== 1. 顶部 Hero 横幅 ==========
  @Builder
  HeroBanner() {
    Column() {
      // 渐变背景头图
      Column() {
        Row() {
          Column() {
            Text(this.isLifetime ? '🌟 终身会员' : (this.isVip ? '👑 VIP 会员' : '普通会员'))
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            Text(this.isLifetime ? '永久尊享全部权益' :
              (this.isVip ? `到期 ${this.formatDate(new Date(this.vipExpireTime))}` : '升级解锁更多招聘权益'))
              .fontSize(13)
              .fontColor('rgba(255,255,255,0.75)')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Text(this.isLifetime ? '🌟' : (this.isVip ? '👑' : '💎'))
            .fontSize(52)
        }
        .width('100%')

        if (this.isVip) {
          Text(this.isLifetime ? '终身有效 · 无限权益' : '无限发布 · 无限面试 · 支持续费叠加')
            .fontSize(11)
            .fontColor('rgba(255,255,255,0.85)')
            .margin({ top: 12 })
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .backgroundColor('rgba(255,255,255,0.15)')
            .borderRadius(10)
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 28, bottom: 24 })
      .borderRadius({ topLeft: 0, topRight: 0, bottomLeft: 20, bottomRight: 20 })
      .linearGradient({
        direction: GradientDirection.Bottom,
        colors: this.isVip
          ? [['#D4AF37', 0.0], ['#B8942E', 0.5], ['#8B6914', 1.0]]
          : [['#FF8C55', 0.0], ['#FF6B35', 0.6], ['#E5551F', 1.0]]
      })

      // 快捷数据
      Row() {
        this.HeroStat('岗位', `${this.positionCount}`, this.isVip ? '无限' : '/1')
        this.HeroStat('AI面试', '5', this.isVip ? '无限' : '/月')
        this.HeroStat('人才搜索', '10', this.isVip ? '无限' : '/天')
        this.HeroStat('微任务', '3', this.isVip ? '无限' : '个')
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 12, bottom: 8 })
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  HeroStat(label: string, used: string, limit: string) {
    Column() {
      Text(used)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
      Text(label)
        .fontSize(9)
        .fontColor('#999999')
        .margin({ top: 1 })
      Text(limit)
        .fontSize(9)
        .fontColor(AppConstants.COLOR_ACCENT)
        .margin({ top: 1 })
    }
    .width('25%')
    .alignItems(HorizontalAlign.Center)
  }

  // ========== 2. 额度使用仪表盘 ==========
  @Builder
  QuotaDashboard() {
    Column() {
      Text('📊 当前用量概览')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .margin({ bottom: 14 })
        .alignSelf(ItemAlign.Start)

      this.QuotaBar('在招岗位', this.positionCount, this.isVip ? 999 : 1, '个')
      this.QuotaBar('AI虚拟人面试（本月）', 3, this.isVip ? 999 : 5, '次')
      this.QuotaBar('人才搜索（今日）', 4, this.isVip ? 999 : 10, '次')
      this.QuotaBar('微任务发布', 2, this.isVip ? 999 : 3, '个')
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
  }

  @Builder
  QuotaBar(label: string, used: number, limit: number, unit: string) {
    Column() {
      Row() {
        Text(label)
          .fontSize(13)
          .fontColor('#333333')
        Blank()
        Text(`${used} / ${limit >= 999 ? '∞' : limit} ${unit}`)
          .fontSize(12)
          .fontColor(used >= limit ? AppConstants.COLOR_DANGER : '#999999')
      }
      .width('100%')

      Progress({
        value: limit >= 999 ? 0 : used,
        total: limit >= 999 ? 1 : Math.max(limit, 1),
        type: ProgressType.Linear
      })
        .width('100%')
        .height(6)
        .color(used >= limit ? AppConstants.COLOR_DANGER : AppConstants.COLOR_ACCENT)
        .backgroundColor('#F0F0F0')
        .borderRadius(3)
        .margin({ top: 6 })
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  // ========== 3. 会员权益对比表 ==========
  @Builder
  BenefitComparison() {
    Column() {
      Row() {
        Text('✨ 会员权益对比')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        Blank()
        Text(this.isVip ? 'VIP尊享全部权益' : `${this.benefits.filter(b => b.highlight).length}项核心差异`)
          .fontSize(11)
          .fontColor(AppConstants.COLOR_ACCENT)
          .padding({ left: 8, right: 8, top: 2, bottom: 2 })
          .backgroundColor('#FFF8F0')
          .borderRadius(8)
      }
      .width('100%')
      .margin({ bottom: 14 })

      // 分组表头
      Row() {
        Text('权益项')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#999999')
          .layoutWeight(2)
        Text('普通')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#999999')
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Text('VIP')
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor(AppConstants.COLOR_ACCENT)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ top: 9, bottom: 9, left: 10, right: 10 })
      .backgroundColor('#FAFAFA')
      .borderRadius(8)
      .margin({ bottom: 4 })

      // 分组渲染对比行
      ForEach(this.getBenefitCategories(), (category: string) => {
        Text(category)
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor('#666666')
          .padding({ top: 12, bottom: 4, left: 4 })
          .alignSelf(ItemAlign.Start)

        ForEach(this.benefits.filter(b => b.category === category), (item: BenefitItem) => {
          this.BenefitRow(item)
        })
      })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
  }

  @Builder
  BenefitRow(item: BenefitItem) {
    Row() {
      Text(item.feature)
        .fontSize(12)
        .fontColor(item.highlight ? '#333333' : '#888888')
        .fontWeight(item.highlight ? FontWeight.Medium : FontWeight.Normal)
        .layoutWeight(2)

      Text(item.normal)
        .fontSize(12)
        .fontColor(item.highlight ? '#999999' : '#AAAAAA')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)

      Text(item.vip)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor(item.highlight ? AppConstants.COLOR_ACCENT : '#1A1A1A')
        .layoutWeight(1)
        .textAlign(TextAlign.Center)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10, left: 10, right: 10 })
    .border({ width: { bottom: 0.5 }, color: '#F5F5F5' })
    .backgroundColor(item.highlight ? '#FFFCF8' : 'transparent')
  }

  private getBenefitCategories(): string[] {
    const categories = new Set<string>()
    for (let i = 0; i < this.benefits.length; i++) {
      categories.add(this.benefits[i].category)
    }
    const result: string[] = []
    categories.forEach(c => result.push(c))
    return result.sort()
  }

  // ========== 4. 定价方案 ==========
  @Builder
  PricingPlans() {
    Column() {
      Text('💰 选择方案')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .margin({ bottom: 14 })
        .alignSelf(ItemAlign.Start)

      // 月卡
      Row() {
        Column() {
          Text('月度')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
          Text('灵活试用')
            .fontSize(10)
            .fontColor('#999999')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column() {
          Text('¥299')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#333333')
          Text('/月')
            .fontSize(10)
            .fontColor('#999999')
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .padding(14)
      .backgroundColor(this.selectedPlan === PlanType.MONTHLY ? '#FFF8F0' : '#FAFAFA')
      .border({
        width: this.selectedPlan === PlanType.MONTHLY ? 2 : 1,
        color: this.selectedPlan === PlanType.MONTHLY ? AppConstants.COLOR_ACCENT : '#E8E8E8',
        radius: 12
      })
      .borderRadius(12)
      .margin({ bottom: 10 })
      .onClick(() => { this.selectedPlan = PlanType.MONTHLY })

      // 季卡
      Row() {
        Column() {
          Row() {
            Text('季度')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')
            Text('热门')
              .fontSize(9)
              .fontColor('#FFFFFF')
              .padding({ left: 5, right: 5, top: 1, bottom: 1 })
              .backgroundColor('#52C41A')
              .borderRadius(4)
              .margin({ left: 6 })
          }
          Text('性价比之选')
            .fontSize(10)
            .fontColor('#999999')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Column() {
          Row() {
            Text('¥249')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333333')
            Text('/月')
              .fontSize(10)
              .fontColor('#999999')
          }
          .justifyContent(FlexAlign.End)
          Text('¥747/季 · 省¥150')
            .fontSize(10)
            .fontColor('#52C41A')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.End)
      }
      .width('100%')
      .padding(14)
      .backgroundColor(this.selectedPlan === PlanType.QUARTERLY ? '#F0FFF0' : '#FAFAFA')
      .border({
        width: this.selectedPlan === PlanType.QUARTERLY ? 2 : 1,
        color: this.selectedPlan === PlanType.QUARTERLY ? '#52C41A' : '#E8E8E8',
        radius: 12
      })
      .borderRadius(12)
      .margin({ bottom: 10 })
      .onClick(() => { this.selectedPlan = PlanType.QUARTERLY })

      // 年卡
      Column() {
        Row() {
          Text('🔖 年度 · 最推荐')
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor(AppConstants.COLOR_ACCENT)
            .borderRadius(6)

          Blank()

          Text('省 ¥589')
            .fontSize(11)
            .fontColor(AppConstants.COLOR_ACCENT)
            .fontWeight(FontWeight.Medium)
        }
        .width('100%')
        .margin({ bottom: 10 })

        Row() {
          Column() {
            Text('年度')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .fontColor('#333333')
            Text('低至 ¥249/月')
              .fontSize(10)
              .fontColor('#999999')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Column() {
            Text('¥2,999')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor('#333333')
            Text('/年')
              .fontSize(10)
              .fontColor('#999999')
          }
          .alignItems(HorizontalAlign.End)
        }
        .width('100%')
      }
      .width('100%')
      .padding(14)
      .backgroundColor(this.selectedPlan === PlanType.YEARLY ? '#FFF0E5' : '#FAFAFA')
      .border({
        width: this.selectedPlan === PlanType.YEARLY ? 2 : 1,
        color: this.selectedPlan === PlanType.YEARLY ? AppConstants.COLOR_ACCENT : '#E8E8E8',
        radius: 12
      })
      .borderRadius(12)
      .onClick(() => { this.selectedPlan = PlanType.YEARLY })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
  }

  // ========== 5. 支付方式 ==========
  @Builder
  PaymentSection() {
    Column() {
      Text('💳 支付方式')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .margin({ bottom: 12 })
        .alignSelf(ItemAlign.Start)

      Row() {
        Text('🛡️')
          .fontSize(20)
        Column() {
          Text('鸿蒙原生支付')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
          Text('华为账户一键支付 · 安全加密 · 支持退款')
            .fontSize(10)
            .fontColor('#999999')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Image($r('sys.symbol.checkmark_shield'))
          .width(16)
          .height(16)
          .fillColor('#52C41A')
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#FAFAFA')
      .borderRadius(10)
      .margin({ bottom: 8 })

      Row() {
        Text('🔄')
          .fontSize(20)
        Column() {
          Text('自动续费 · 随时可取消')
            .fontSize(13)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
          Text('到期前24小时可取消，已扣费不可退')
            .fontSize(10)
            .fontColor('#999999')
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
      }
      .width('100%')
      .padding(12)
      .backgroundColor('#FAFAFA')
      .borderRadius(10)
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
  }

  // ========== 6. 常见问题 ==========
  @Builder
  FaqSection() {
    Column() {
      Row() {
        Text('❓ 常见问题')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        Blank()
        Text(this.showFaq ? '收起 ▲' : '展开 ▼')
          .fontSize(12)
          .fontColor(AppConstants.COLOR_PRIMARY)
          .onClick(() => { this.showFaq = !this.showFaq })
      }
      .width('100%')

      if (this.showFaq) {
        this.FaqItem('VIP 和普通会员的主要区别是什么？',
          'VIP会员享有无限岗位发布、无限AI虚拟人面试、无限人才搜索、完整数据分析报告、专属客服等核心权益。普通会员在招岗位仅限1个，AI面试限5次/月，人才搜索限10次/天。')
        this.FaqItem('开通 VIP 后可以退款吗？',
          '通过鸿蒙原生支付开通的VIP会员，在购买后48小时内且未使用任何VIP权益的情况下可申请退款。超过48小时或已使用VIP权益则不支持退款。')
        this.FaqItem('自动续费如何取消？',
          '您可在华为应用内支付中随时管理订阅，到期前24小时关闭自动续费即可，已开通的会员期限内权益不受影响。')
        this.FaqItem('VIP 会员账号可以多人共用吗？',
          'VIP会员与企业认证信息绑定，仅供该认证企业的HR使用。如需多个HR账号，每个账号需独立认证并开通。')
        this.FaqItem('升级后之前的数据会丢失吗？',
          '不会。升级为VIP会员后，所有历史发布岗位、聊天记录、简历数据等均完整保留，仅解锁更多功能和额度。')
      }
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
  }

  @Builder
  FaqItem(question: string, answer: string) {
    Column() {
      Row() {
        Text('Q')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.COLOR_ACCENT)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor('#FFF8F0')
          .borderRadius(4)
          .margin({ right: 8 })
        Text(question)
          .fontSize(12)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .layoutWeight(1)
      }
      .width('100%')

      Row() {
        Text('A')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(AppConstants.COLOR_PRIMARY)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor('#F0F7FF')
          .borderRadius(4)
          .margin({ right: 8 })
        Text(answer)
          .fontSize(11)
          .fontColor('#666666')
          .layoutWeight(1)
          .lineHeight(18)
      }
      .width('100%')
      .margin({ top: 8 })
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
  }

  // ========== 底部间距 ==========
  @Builder
  BottomSpacer() {
    Column()
      .width('100%')
      .height(80)
  }

  // ========== 底部固定按钮 ==========
  @Builder
  BottomButton() {
    Column() {
      Row() {
        Column() {
          Row() {
            Text(this.getPlanPrice())
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor('#FFFFFF')
            Text(` / ${this.isVip ? '续' : ''}${this.getPlanLabel()}`)
              .fontSize(12)
              .fontColor('rgba(255,255,255,0.7)')
          }
          if (this.isVip && !this.isLifetime) {
            Text(`续费后到期 ${this.formatDate(new Date(Date.now() + this.getPlanDurationMs()))}`)
              .fontSize(10)
              .fontColor('rgba(255,255,255,0.6)')
          } else if (!this.isVip && this.selectedPlan === PlanType.YEARLY) {
            Text('比月卡省 ¥589')
              .fontSize(10)
              .fontColor('rgba(255,255,255,0.6)')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button(this.isLifetime ? '终身会员' : this.getButtonText())
          .height(44)
          .padding({ left: 24, right: 24 })
          .fontSize(this.isLifetime ? 13 : 15)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(this.isLifetime ? 'rgba(255,255,255,0.3)' : '#FFFFFF')
          .fontColor(this.isLifetime ? '#FFFFFF' : AppConstants.COLOR_ACCENT)
          .borderRadius(22)
          .enabled(!this.isLifetime && !this.isUpgrading)
          .onClick(() => { this.handleUpgrade() })
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 12, bottom: 28 })
    }
    .width('100%')
    .backgroundColor(AppConstants.COLOR_ACCENT)
  }

  // ========== 业务逻辑 ==========
  private getPlanPrice(): string {
    switch (this.selectedPlan) {
      case PlanType.MONTHLY: return '¥299'
      case PlanType.QUARTERLY: return '¥249'
      case PlanType.YEARLY: return '¥2,999'
    }
  }

  private getPlanLabel(): string {
    switch (this.selectedPlan) {
      case PlanType.MONTHLY: return '月'
      case PlanType.QUARTERLY: return '月·季付'
      case PlanType.YEARLY: return '年'
    }
  }

  private getButtonText(): string {
    const prefix = this.isVip ? '续费' : '立即开通'
    switch (this.selectedPlan) {
      case PlanType.MONTHLY: return `${prefix} · ¥299/月`
      case PlanType.QUARTERLY: return `${prefix} · ¥747/季`
      case PlanType.YEARLY: return this.isVip ? `${prefix} · ¥2,999` : '立即开通 · ¥2,999/年'
    }
  }

  private async handleUpgrade(): Promise<void> {
    const user = AppState.currentUser
    if (!user) {
      promptAction.showToast({ message: '请先登录', duration: 2000 })
      return
    }
    if (this.isLifetime) {
      promptAction.showToast({ message: '已是终身会员，无需续费', duration: 2000 })
      return
    }

    // 先弹出支付密码输入
    this.payPasswordInput = ''
    this.payPasswordError = false
    this.showPayPassword = true
  }

  private async confirmPay(): Promise<void> {
    if (this.payPasswordInput !== '123456') {
      this.payPasswordError = true
      promptAction.showToast({ message: '密码错误，请重试', duration: 1500 })
      return
    }

    this.showPayPassword = false
    this.isUpgrading = true

    const user = AppState.currentUser!
    const extendMs = this.getPlanDurationMs()
    this.mockPayStep = '验证账户...'
    await this.sleep(500)
    this.mockPayStep = '扣款中...'
    await this.sleep(700)
    this.mockPayStep = '开通中...'
    await this.sleep(400)

    try {
      await this.userDao.upgradeToVip(user.userId, extendMs, this.selectedPlan === PlanType.YEARLY)

      // 更新内存
      user.vipLevel = VipLevel.VIP
      user.positionCount = user.positionCount ?? 1
      user.vipExpireTime = Date.now() + extendMs
      user.vipLifetime = this.selectedPlan === PlanType.YEARLY
      AppState.currentUser = user
      AppState.syncToStorage()
      this.isLoggedIn = true

      const isRenewal = this.isVip
      this.isVip = true
      this.isLifetime = this.selectedPlan === PlanType.YEARLY
      this.vipExpireTime = Date.now() + extendMs
      this.isUpgrading = false
      this.mockPayStep = ''

      if (this.selectedPlan === PlanType.YEARLY) {
        promptAction.showToast({ message: '🎉 恭喜！已开通终身会员', duration: 2500 })
      } else if (isRenewal) {
        const newDate = new Date(Date.now() + extendMs)
        promptAction.showToast({ message: `续费成功！会员有效期至 ${this.formatDate(newDate)}`, duration: 2500 })
      } else {
        promptAction.showToast({ message: '🎉 已成功开通 VIP 会员', duration: 2500 })
      }
    } catch (e) {
      this.isUpgrading = false
      this.mockPayStep = ''
      promptAction.showToast({ message: '支付失败，请稍后重试', duration: 2000 })
    }
  }

  private sleep(ms: number): Promise<void> {
    return new Promise<void>((resolve: () => void) => {
      setTimeout((): void => { resolve() }, ms)
    })
  }

  private getPlanDurationMs(): number {
    switch (this.selectedPlan) {
      case PlanType.MONTHLY: return 30 * 24 * 3600 * 1000
      case PlanType.QUARTERLY: return 92 * 24 * 3600 * 1000
      case PlanType.YEARLY: return 0 // lifetime
    }
  }

  private formatDate(d: Date): string {
    const y = d.getFullYear()
    const m = `${d.getMonth() + 1}`.padStart(2, '0')
    const day = `${d.getDate()}`.padStart(2, '0')
    return `${y}-${m}-${day}`
  }

  // ========== 支付密码弹窗 ==========
  @Builder
  PayPasswordDialog() {
    Stack() {
      Column() {
        Column() {
          Text('🔐')
            .fontSize(36)
            .margin({ bottom: 12 })
          Text('请输入支付密码')
            .fontSize(17)
            .fontWeight(FontWeight.Medium)
            .fontColor('#1A1A1A')
            .margin({ bottom: 4 })
          Text(`支付 ${this.getPlanPrice()} · ${this.isVip ? '续费' : '开通'}${this.getPlanLabel()}`)
            .fontSize(12)
            .fontColor('#999999')
            .margin({ bottom: 20 })

          // 6位密码格子
          Row() {
            ForEach([0, 1, 2, 3, 4, 5], (i: number): void => {
              Column() {
                Text(this.payPasswordInput.length > i ? '●' : '')
                  .fontSize(16)
                  .fontColor('#1A1A1A')
              }
              .width(32)
              .height(42)
              .justifyContent(FlexAlign.Center)
              .backgroundColor('#F5F5F5')
              .borderRadius(6)
              .border({ width: 1.5, color: this.payPasswordError ? '#FF4D4F' : (this.payPasswordInput.length === i ? AppConstants.COLOR_ACCENT : '#E8E8E8') })
              .margin({ left: i === 0 ? 0 : 2, right: i === 5 ? 0 : 2 })
              .margin({ left: i === 0 ? 0 : 6, right: i === 5 ? 0 : 6 })
            })
          }
          .justifyContent(FlexAlign.Center)
          .margin({ bottom: 8 })

          if (this.payPasswordError) {
            Text('密码错误，请重试')
              .fontSize(11)
              .fontColor('#FF4D4F')
              .margin({ top: 4, bottom: 4 })
          }

          // 自定义数字键盘
          Column() {
            ForEach([['1', '2', '3'], ['4', '5', '6'], ['7', '8', '9'], ['', '0', '⌫']], (row: string[]): void => {
              Row() {
                ForEach(row, (key: string): void => {
                  if (key === '') {
                    Column().width(60).height(44)
                  } else if (key === '⌫') {
                    Column() {
                      Text('⌫')
                        .fontSize(22)
                        .fontColor('#999999')
                    }
                    .width(60)
                    .height(44)
                    .justifyContent(FlexAlign.Center)
                    .backgroundColor('#F0F0F0')
                    .borderRadius(6)
                    .onClick((): void => {
                      if (this.payPasswordInput.length > 0) {
                        this.payPasswordInput = this.payPasswordInput.substring(0, this.payPasswordInput.length - 1)
                        this.payPasswordError = false
                      }
                    })
                  } else {
                    Column() {
                      Text(key)
                        .fontSize(22)
                        .fontWeight(FontWeight.Medium)
                        .fontColor('#333333')
                    }
                    .width(60)
                    .height(44)
                    .justifyContent(FlexAlign.Center)
                    .backgroundColor('#FFFFFF')
                    .borderRadius(6)
                    .border({ width: 0.5, color: '#E0E0E0' })
                    .onClick((): void => {
                      if (this.payPasswordInput.length < 6) {
                        this.payPasswordInput += key
                        this.payPasswordError = false
                      }
                    })
                  }
                })
              }
              .justifyContent(FlexAlign.Center)
              .margin({ bottom: 6 })
            })
          }
          .margin({ top: 8 })

          Row() {
            Button('取消')
              .layoutWeight(1)
              .height(42)
              .fontSize(14)
              .backgroundColor('#F5F5F5')
              .fontColor('#666666')
              .borderRadius(8)
              .onClick((): void => {
                this.showPayPassword = false
                this.payPasswordInput = ''
                this.payPasswordError = false
              })

            Button('确定')
              .layoutWeight(1)
              .height(42)
              .fontSize(14)
              .backgroundColor(this.payPasswordInput.length === 6 ? AppConstants.COLOR_ACCENT : '#E0E0E0')
              .fontColor(this.payPasswordInput.length === 6 ? '#FFFFFF' : '#AAAAAA')
              .borderRadius(8)
              .margin({ left: 12 })
              .enabled(this.payPasswordInput.length === 6)
              .onClick((): void => { this.confirmPay() })
          }
          .width('100%')
          .margin({ top: 12 })
        }
        .width('80%')
        .padding(24)
        .backgroundColor('#FFFFFF')
        .borderRadius(16)
        .shadow({ radius: 20, color: '#30000000', offsetY: 8 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor('rgba(0,0,0,0.45)')
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
  }

  // ========== Mock 支付处理遮罩 ==========
  @Builder
  MockPayOverlay() {
    Stack() {
      Column() {
        Column() {
          LoadingProgress()
            .width(40)
            .height(40)
            .color('#FFFFFF')
          Text('模拟支付中')
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FFFFFF')
            .margin({ top: 16 })
          Text(this.mockPayStep)
            .fontSize(13)
            .fontColor('rgba(255,255,255,0.7)')
            .margin({ top: 8 })
          Text('实际接入鸿蒙 IAP Kit 后替换')
            .fontSize(10)
            .fontColor('rgba(255,255,255,0.4)')
            .margin({ top: 20 })
        }
        .padding(32)
        .backgroundColor('rgba(0,0,0,0.8)')
        .borderRadius(16)
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .backgroundColor('rgba(0,0,0,0.45)')
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
  }
}
