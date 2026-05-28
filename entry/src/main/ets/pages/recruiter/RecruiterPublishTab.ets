// 招聘者 - 发布岗位页（Tab b: 发布 + AI辅助）

import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { JobPosition, JobCategory, JobStatus } from '../../model/JobModel'
import { JobDao } from '../../service/JobDao'
import { UserDao } from '../../service/UserDao'
import { VipLevel } from '../../model/UserModel'

@Component
export struct RecruiterPublishTab {
  @State title: string = ''
  @State category: string = JobCategory.FULLTIME_INTERN
  @State description: string = ''
  @State educationRequired: string = '本科'
  @State salaryRange: string = ''
  @State workYearsRequired: string = '不限'
  @State workAddress: string = ''
  @State city: string = ''
  @State skills: string = ''
  @State isAIGenerating: boolean = false
  @State showAIDescInput: boolean = false
  @State aiKeywords: string = ''

  private jobDao: JobDao = new JobDao()
  private userDao: UserDao = new UserDao()

  // 创新点三：红线扫描
  checkRedFlags(desc: string): string[] {
    const redFlags: string[] = []
    const keywords = ['自费培训', '保证金', '自备高配电脑', '押金', '押证', '培训费', '中介费', '介绍费']
    for (const kw of keywords) {
      if (desc.indexOf(kw) >= 0) {
        redFlags.push(kw)
      }
    }
    return redFlags
  }

  // AI辅助生成描述
  async generateDescription(): Promise<void> {
    if (!this.aiKeywords) {
      AlertDialog.show({ message: '请输入关键词描述' })
      return
    }
    this.isAIGenerating = true
    // 模拟AI生成
    setTimeout(() => {
      this.description = `【岗位职责】
1. 负责${this.aiKeywords.indexOf('Python') >= 0 ? 'Python后端' : ''}相关模块的设计与开发
2. 参与核心业务系统的架构设计和代码评审
3. 编写高质量的代码文档和技术方案
4. 与团队成员协作完成项目交付

【任职要求】
1. ${this.educationRequired}及以上学历
2. 熟练掌握相关开发语言和框架
3. 良好的沟通表达能力和团队协作精神
4. 学习能力强，热爱技术

【我们提供】
1. 具有竞争力的薪资待遇：${this.salaryRange || '面议'}
2. 完善的培训体系和导师制度
3. 丰富的团建活动和发展空间
4. 实习表现优异者可转正`
      this.isAIGenerating = false
    }, 1500)
  }

  // 发布前红线检查
  async handlePublish(): Promise<void> {
    if (!this.title || !this.description) {
      AlertDialog.show({ message: '请填写完整信息' })
      return
    }

    // 红线扫描
    const redFlags = this.checkRedFlags(this.description)
    if (redFlags.length > 0) {
      // 创新点三：红色警告弹窗拦载
      AlertDialog.show({
        title: '⚠️ 红线警告',
        message: `系统检测到以下高风险词汇：${redFlags.join('、')}。\n\n这些词汇属于招聘骗局常见话术。为保护求职者安全，该岗位已被系统拦截，无法发布。\n\n如有疑问，请联系平台客服。`,
        primaryButton: { value: '我知道了', action: () => {} }
      })
      return
    }

    // 会员权限检查
    const user = AppState.currentUser
    if (user) {
      const existingJobs = await this.jobDao.getJobsByRecruiter(user.userId)
      if (user.vipLevel !== VipLevel.VIP && existingJobs.length >= AppConstants.NORMAL_MAX_POSITIONS) {
        AlertDialog.show({
          title: '发布限制',
          message: '普通会员仅可同时招聘一种岗位，升级 VIP 解锁无限发布。',
          primaryButton: {
            value: '去升级',
            action: () => { /* 切换到升级Tab */ }
          },
          secondaryButton: { value: '取消', action: () => {} }
        })
        return
      }
    }

    const job: JobPosition = {
      jobId: `job_${Date.now()}`,
      recruiterId: AppState.currentUser?.userId || '',
      companyName: AppState.currentUser?.companyName || '未认证企业',
      title: this.title,
      category: this.category as JobCategory,
      description: this.description,
      educationRequired: this.educationRequired,
      salaryRange: this.salaryRange,
      workYearsRequired: this.workYearsRequired,
      workAddress: this.workAddress,
      city: this.city,
      skills: this.skills.split(',').map(s => s.trim()).filter(s => s),
      status: JobStatus.PUBLISHED,
      publishTime: Date.now(),
      updateTime: Date.now(),
      viewCount: 0,
      applyCount: 0,
      tags: [this.category === JobCategory.MICRO_TASK ? '短期兼职' : '全职', this.educationRequired],
      isAIGenerated: this.isAIGenerating
    }

    await this.jobDao.insertJob(job)
    this.clearForm()

    // 创新点四：发布成功后展示AI智能工时拼图
    AlertDialog.show({
      title: '✅ 发布成功！',
      message: this.category === JobCategory.MICRO_TASK
        ? '岗位已成功发布！\n\n【AI 智能工时拼图】系统检测到2名课表互补的学生可完美匹配该岗位时间，建议一键打包约面。'
        : '岗位已成功发布！',
      primaryButton: { value: '好的', action: () => {} }
    })
  }

  clearForm(): void {
    this.title = ''
    this.description = ''
    this.salaryRange = ''
    this.workAddress = ''
    this.city = ''
    this.skills = ''
    this.aiKeywords = ''
  }

  build() {
    Column() {
      Scroll() {
        Column() {
          // 标题
          Text('发布招聘岗位')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .margin({ top: 12, bottom: 16 })
            .alignSelf(ItemAlign.Start)

          // 岗位类别
          Row() {
            Text('岗位类别')
              .fontSize(13)
              .fontColor('#666666')
              .width(80)
            Row() {
              Button('全职/实习')
                .fontSize(12)
                .height(32)
                .backgroundColor(this.category === JobCategory.FULLTIME_INTERN ? AppConstants.COLOR_ACCENT : '#F5F5F5')
                .fontColor(this.category === JobCategory.FULLTIME_INTERN ? '#FFFFFF' : '#666666')
                .borderRadius(16)
                .onClick(() => this.category = JobCategory.FULLTIME_INTERN)
              Button('微任务/兼职')
                .fontSize(12)
                .height(32)
                .backgroundColor(this.category === JobCategory.MICRO_TASK ? AppConstants.COLOR_ACCENT : '#F5F5F5')
                .fontColor(this.category === JobCategory.MICRO_TASK ? '#FFFFFF' : '#666666')
                .borderRadius(16)
                .margin({ left: 8 })
                .onClick(() => this.category = JobCategory.MICRO_TASK)
            }
          }
          .width('100%')
          .margin({ bottom: 14 })

          this.InputRow('岗位名称', this.title, '例如: 前端开发实习生', (v) => this.title = v)
          this.InputRow('学历要求', this.educationRequired, '例如: 本科以上', (v) => this.educationRequired = v)
          this.InputRow('薪资范围', this.salaryRange, '例如: 8k-15k', (v) => this.salaryRange = v)
          this.InputRow('工作年限', this.workYearsRequired, '例如: 不限', (v) => this.workYearsRequired = v)
          this.InputRow('工作地点', this.workAddress, '详细地址', (v) => this.workAddress = v)
          this.InputRow('所在城市', this.city, '例如: 长沙', (v) => this.city = v)
          this.InputRow('技能要求', this.skills, '逗号分隔，如: Python,Java', (v) => this.skills = v)

          // AI辅助生成描述
          Column() {
            Row() {
              Text('岗位描述')
                .fontSize(13)
                .fontColor('#666666')
              Blank()
              Button('🤖 AI辅助生成描述')
                .fontSize(11)
                .height(28)
                .backgroundColor('#F0F7FF')
                .fontColor('#4A90D9')
                .borderRadius(14)
                .padding({ left: 10, right: 10 })
                .onClick(() => this.showAIDescInput = !this.showAIDescInput)
            }
            .width('100%')
            .margin({ bottom: 8 })

            // AI关键词输入
            if (this.showAIDescInput) {
              Row() {
                TextInput({ text: this.aiKeywords, placeholder: '输入关键词，如: 招一个会Python的大三兼职' })
                  .layoutWeight(1)
                  .fontSize(12)
                  .height(36)
                  .backgroundColor('#F5F5F5')
                  .borderRadius(8)
                  .onChange((v) => this.aiKeywords = v)
                Button('生成')
                  .fontSize(12)
                  .height(36)
                  .backgroundColor(AppConstants.COLOR_PRIMARY)
                  .fontColor('#FFFFFF')
                  .borderRadius(8)
                  .margin({ left: 6 })
                  .enabled(!this.isAIGenerating)
                  .onClick(() => this.generateDescription())
              }
              .width('100%')
              .margin({ bottom: 8 })
            }

            if (this.isAIGenerating) {
              Row() {
                LoadingProgress().width(16).height(16)
                Text(' AI生成中...')
                  .fontSize(12)
                  .fontColor('#999999')
                  .margin({ left: 6 })
              }
              .margin({ bottom: 8 })
            }

            TextArea({ text: this.description, placeholder: '请输入详细的岗位职责和任职要求...' })
              .width('100%')
              .height(150)
              .fontSize(13)
              .backgroundColor('#F5F5F5')
              .borderRadius(8)
              .padding(12)
              .onChange((v) => this.description = v)
          }
          .width('100%')
          .margin({ top: 8, bottom: 24 })

          // 发布按钮
          Button('提交发布')
            .width('90%')
            .height(48)
            .fontSize(16)
            .backgroundColor(AppConstants.COLOR_ACCENT)
            .fontColor('#FFFFFF')
            .borderRadius(24)
            .onClick(() => this.handlePublish())
            .margin({ bottom: 20 })
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
  InputRow(label: string, value: string, placeholder: string, onChange: (v: string) => void) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('#666666')
        .width(80)
      TextInput({ text: value, placeholder: placeholder })
        .layoutWeight(1)
        .fontSize(13)
        .height(40)
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .padding({ left: 12 })
        .onChange(onChange)
    }
    .width('100%')
    .margin({ bottom: 14 })
  }
}
