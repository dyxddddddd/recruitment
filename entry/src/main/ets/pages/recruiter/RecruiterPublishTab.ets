// 招聘者 - 发布岗位页（Tab b: 发布 + AI辅助 + 红线扫描 + 工时拼图）

import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { JobPosition, JobCategory, JobStatus } from '../../model/JobModel'
import { JobDao } from '../../service/JobDao'
import { UserDao } from '../../service/UserDao'
import { VipLevel, AuthStatus } from '../../model/UserModel'
import { RecruiterAIService, AIRedFlagScanResult } from '../../service/RecruiterAIService'
import { querySkillsByJobTitle } from '../../data/JobSkillData'

@Component
struct PickerRowComponent {
  @Prop label: string = ''
  @Prop value: string = ''
  onTap?: () => void

  build() {
    Row() {
      Text(this.label)
        .fontSize(13)
        .fontColor('#666666')
        .width(80)
      Row() {
        Text(this.value)
          .fontSize(13)
          .fontColor(this.value === '请选择' ? '#CCCCCC' : '#333333')
          .layoutWeight(1)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
        Text('>')
          .fontSize(14)
          .fontColor('#CCCCCC')
          .margin({ left: 8 })
      }
      .layoutWeight(1)
      .height(40)
      .backgroundColor('#F5F5F5')
      .borderRadius(8)
      .padding({ left: 12, right: 12 })
      .onClick(() => this.onTap?.())
    }
    .width('100%')
    .margin({ bottom: 14 })
  }
}

@Component
export struct RecruiterPublishTab {
  @State title: string = ''
  @State category: string = JobCategory.FULLTIME_INTERN
  @State description: string = ''
  @State educationRequired: string = '本科'
  @State salaryRange: string = '面议'
  @State workYearsRequired: string = '不限'
  @State workAddress: string = ''
  @State city: string = ''
  @State skills: string = ''
  @State selectedSkills: string[] = []
  @State isAIGenerating: boolean = false
  @State showAIDescInput: boolean = false
  @State aiKeywords: string = ''
  @State wasAIGenerated: boolean = false
  @State isScanning: boolean = false
  // 微任务时间相关
  @State taskStartDate: string = ''
  @State taskEndDate: string = ''
  @State requiredDaysOfWeek: number[] = []
  @State requiredDayStartHour: number = -1
  @State requiredDayStartMinute: number = 0
  @State requiredDayEndHour: number = -1
  @State requiredDayEndMinute: number = 0
  // 滚动选择器状态
  @State showPicker: boolean = false
  @State pickerType: string = ''
  @State tempEducationIndex: number = 2
  @State tempWorkYearsIndex: number = 0
  @State @Watch('onProvinceChange') tempProvinceIndex: number = 0
  @State tempCityIndex: number = 0
  @State tempSkills: string[] = []
  @State skillOptions: string[] = []
  @State tempSalaryIndex: number = 0
  @State tempSelectedDays: number[] = []
  @State tempStartHIndex: number = 0
  @State tempStartMinuteIndex: number = 0
  @State tempEndHIndex: number = 0
  @State tempEndMinuteIndex: number = 0
  @State tempPickedDate: Date = new Date()
  @State @Watch('onJobFieldChange') tempJobFieldIndex: number = 0
  @State tempJobTitleIndex: number = 0

  private jobDao: JobDao = new JobDao()
  private userDao: UserDao = new UserDao()

  private educationOptions: string[] = ['不限', '大专', '本科', '硕士', '博士']
  private workYearsOptions: string[] = ['不限', '应届生', '1-3年', '3-5年', '5年以上']
  private salaryOptions: string[] = ['面议', '2k-4k', '4k-6k', '6k-10k', '10k-15k', '15k-20k', '20k-30k', '30k以上']
  private csSkillOptions: string[] = ['Python', 'Java', 'JavaScript/TS', 'C/C++', 'Go', 'Vue/React', 'Node.js', 'Spring', 'MySQL', '数据分析', 'AI/算法', '运维/测试', 'UI设计', '产品运营', '其他']
  private generalSkillOptions: string[] = ['文案写作', 'Excel/数据处理', '海报设计', '视频剪辑', '摄影', '新媒体运营', '客服/电销', '家教/辅导', '活动执行', '翻译/口译', '调研/问卷', '地推/促销', '配音/播音', 'PPT制作', '其他']
  private dayOptions: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']
  private hourOnlyOptions: string[] = ['0','1','2','3','4','5','6','7','8','9','10','11','12','13','14','15','16','17','18','19','20','21','22','23']
  private minuteOptions: string[] = ['00', '15', '30', '45']

  private cityMap: Record<string, string[]> = {
    '北京': ['东城区', '西城区', '朝阳区', '海淀区', '丰台区', '石景山区', '通州区', '大兴区', '昌平区', '顺义区'],
    '上海': ['黄浦区', '徐汇区', '长宁区', '静安区', '普陀区', '虹口区', '杨浦区', '浦东新区', '闵行区', '宝山区'],
    '广东': ['广州', '深圳', '东莞', '佛山', '珠海', '中山', '惠州', '汕头', '江门', '湛江'],
    '浙江': ['杭州', '宁波', '温州', '嘉兴', '湖州', '绍兴', '金华', '衢州', '舟山', '台州'],
    '江苏': ['南京', '苏州', '无锡', '常州', '南通', '扬州', '镇江', '徐州', '盐城', '泰州'],
    '四川': ['成都', '绵阳', '德阳', '宜宾', '南充', '泸州', '达州', '乐山', '广安', '眉山'],
    '湖北': ['武汉', '宜昌', '襄阳', '荆州', '黄石', '十堰', '孝感', '荆门', '鄂州', '黄冈'],
    '湖南': ['长沙', '株洲', '湘潭', '衡阳', '邵阳', '岳阳', '常德', '张家界', '益阳', '郴州'],
    '福建': ['福州', '厦门', '泉州', '漳州', '龙岩', '三明', '南平', '莆田', '宁德'],
    '山东': ['济南', '青岛', '烟台', '威海', '潍坊', '临沂', '淄博', '济宁', '泰安', '日照'],
    '陕西': ['西安', '咸阳', '宝鸡', '渭南', '延安', '汉中', '榆林', '安康', '商洛'],
    '河南': ['郑州', '洛阳', '开封', '南阳', '许昌', '新乡', '周口', '商丘', '安阳', '平顶山'],
    '安徽': ['合肥', '芜湖', '蚌埠', '淮南', '马鞍山', '安庆', '阜阳', '六安', '亳州', '滁州'],
    '重庆': ['渝中区', '江北区', '南岸区', '沙坪坝区', '九龙坡区', '大渡口区', '北碚区', '渝北区', '巴南区', '涪陵区'],
    '天津': ['和平区', '河东区', '河西区', '南开区', '河北区', '红桥区', '东丽区', '西青区', '北辰区', '武清区'],
    '河北': ['石家庄', '唐山', '保定', '邯郸', '廊坊', '沧州', '邢台', '衡水', '秦皇岛', '张家口'],
    '辽宁': ['沈阳', '大连', '鞍山', '抚顺', '本溪', '丹东', '锦州', '营口', '阜新', '辽阳'],
    '江西': ['南昌', '九江', '赣州', '吉安', '宜春', '上饶', '抚州', '景德镇', '萍乡', '新余'],
    '广西': ['南宁', '柳州', '桂林', '北海', '玉林', '梧州', '百色', '河池', '钦州', '贵港'],
    '云南': ['昆明', '大理', '丽江', '曲靖', '玉溪', '保山', '昭通', '普洱', '西双版纳', '红河'],
    '贵州': ['贵阳', '遵义', '六盘水', '安顺', '毕节', '铜仁', '黔东南', '黔南', '黔西南'],
    '山西': ['太原', '大同', '阳泉', '长治', '晋城', '朔州', '晋中', '运城', '忻州', '临汾'],
    '吉林': ['长春', '吉林', '四平', '辽源', '通化', '白山', '松原', '白城', '延边'],
    '黑龙江': ['哈尔滨', '齐齐哈尔', '鸡西', '鹤岗', '双鸭山', '大庆', '伊春', '佳木斯', '牡丹江', '黑河'],
    '甘肃': ['兰州', '天水', '白银', '武威', '张掖', '酒泉', '平凉', '庆阳', '定西', '陇南'],
    '海南': ['海口', '三亚', '儋州', '三沙'],
    '内蒙古': ['呼和浩特', '包头', '乌海', '赤峰', '通辽', '鄂尔多斯', '呼伦贝尔', '巴彦淖尔', '乌兰察布'],
    '新疆': ['乌鲁木齐', '克拉玛依', '吐鲁番', '哈密', '昌吉', '伊犁', '阿克苏', '喀什', '石河子'],
    '西藏': ['拉萨', '日喀则', '昌都', '林芝', '山南', '那曲', '阿里'],
    '宁夏': ['银川', '石嘴山', '吴忠', '固原', '中卫'],
    '青海': ['西宁', '海东', '海西', '海南', '海北', '黄南', '果洛', '玉树']
  }

  aboutToAppear(): void {
    this.checkVipLimit()
  }

  async checkVipLimit(): Promise<void> {
    const user = AppState.currentUser
    if (!user || user.vipLevel === VipLevel.VIP) {
      return
    }
    const existingJobs = await this.jobDao.getJobsByRecruiter(user.userId)
    if (existingJobs.length >= AppConstants.NORMAL_MAX_POSITIONS) {
      AlertDialog.show({
        title: '发布限制',
        message: '您当前为普通会员，仅可同时发布一种岗位。升级 VIP 可解锁无限发布。',
        primaryButton: {
          value: '去升级',
          action: () => {
            AppStorage.setOrCreate<number>('recruiter_switch_tab', 1)
          }
        },
        secondaryButton: { value: '知道了', action: () => {} }
      })
    }
  }

  getProvinces(): string[] {
    return Object.keys(this.cityMap)
  }

  getCities(): string[] {
    const keys: string[] = Object.keys(this.cityMap)
    if (this.tempProvinceIndex >= 0 && this.tempProvinceIndex < keys.length) {
      const province: string = keys[this.tempProvinceIndex]
      return this.cityMap[province] || []
    }
    return []
  }

  private jobTitleMap: Record<string, string[]> = {
    '互联网/IT': ['前端开发', '后端开发', '全栈开发', 'Android开发', 'iOS开发', '算法工程师', 'AI/机器学习', '数据分析师', '运维/DevOps', '安全工程师', '测试工程师', '嵌入式开发', '游戏开发', '区块链开发', '架构师', '技术经理'],
    '产品/设计': ['UI设计师', 'UX设计师', '产品经理', '交互设计师', '视觉设计师', '游戏策划', '用户研究员'],
    '运营/市场': ['新媒体运营', '产品运营', '用户运营', '市场推广', '品牌营销', '内容运营', 'SEO/SEM', '社群运营', '电商运营'],
    '职能/行政': ['人力资源', '行政管理', '财务会计', '法务专员', '秘书/助理', '前台/接待'],
    '金融/咨询': ['投资分析', '风险管理', '审计', '咨询顾问', '行业研究', '精算师'],
    '教育/培训': ['家教/辅导', '讲师/培训师', '课程顾问', '留学顾问'],
    '销售/客服': ['销售代表', '客户经理', '客服专员', '电话销售', '房产中介', '保险顾问'],
    '传媒/艺术': ['记者/编辑', '编导/导演', '主持人', '摄影师', '剪辑师', '配音/播音', '平面设计', '插画师'],
    '医疗/健康': ['护士', '医学检验', '康复治疗师', '心理咨询师'],
    '建筑/工程': ['建筑设计师', '土木工程师', '造价工程师', '监理工程师', '室内设计师', '暖通工程师'],
    '制造/物流': ['机械工程师', '电气工程师', '质量管理', '采购专员', '仓储管理', '物流专员'],
    '微任务/兼职': ['问卷填写', '数据标注', '内容审核', '地推/促销', '活动执行', '礼仪/模特', '传单派发', '打包分拣', '快递配送', '线上客服', '翻译/口译', '配音/录音', '摄影/修图', '家教辅导', '代驾/陪练']
  }

  getJobFields(): string[] {
    return Object.keys(this.jobTitleMap)
  }

  getJobTitles(): string[] {
    const fields: string[] = Object.keys(this.jobTitleMap)
    if (this.tempJobFieldIndex >= 0 && this.tempJobFieldIndex < fields.length) {
      const field: string = fields[this.tempJobFieldIndex]
      return this.jobTitleMap[field] || []
    }
    return []
  }

  onJobFieldChange(): void {
    this.tempJobTitleIndex = 0
  }

  getSkillOptions(): string[] {
    const result = querySkillsByJobTitle(this.title)
    if (result.length > 0) {
      return result
    }
    return this.category === JobCategory.MICRO_TASK
      ? this.generalSkillOptions : this.csSkillOptions
  }

  // 创新点三：红线扫描（关键词快速匹配 + AI深度分析）
  async checkRedFlags(title: string, desc: string): Promise<AIRedFlagScanResult> {
    this.isScanning = true
    try {
      return await RecruiterAIService.scanForRedFlags(title, desc)
    } finally {
      this.isScanning = false
    }
  }

  // 创新点一：AI辅助生成描述（接入DeepSeek）
  async generateDescription(): Promise<void> {
    if (!this.aiKeywords) {
      AlertDialog.show({ message: '请输入关键词描述' })
      return
    }
    this.isAIGenerating = true
    try {
      const result = await RecruiterAIService.generateJobDescription(
        this.aiKeywords, this.title, this.category,
        this.educationRequired, this.salaryRange
      )
      this.description = this.cleanAIDescription(result)
      this.wasAIGenerated = true
    } catch (e) {
      AlertDialog.show({
        title: 'AI生成失败',
        message: '网络异常或AI服务暂不可用，请稍后重试或手动填写描述。'
      })
    } finally {
      this.isAIGenerating = false
    }
  }

  // 清洗AI回复：去除markdown符号和对话式语言
  private cleanAIDescription(text: string): string {
    let cleaned = text
    // 去除常见的AI对话前缀
    const prefixes = [
      /^(好的[，,！!。.]?\s*)+/,
      /^(没问题[，,！!。.]?\s*)+/,
      /^(根据你?提供[的之].*?[，,]\s*)+/,
      /^(以下是为您?生成的.*?[：:]\s*)+/,
      /^(很高兴).*?[，,]\s*/,
      /^嗯[，,！!。.]?\s*/,
      /^(我.*?为[您你]).*?[：:]\s*/,
      /^(当然[，,！!。.]?\s*)+/,
      /^(OK[，,！!。.]?\s*)+/i,
    ]
    for (const re of prefixes) {
      cleaned = cleaned.replace(re, '')
    }
    // 去除markdown符号
    cleaned = cleaned.replace(/\*\*(.+?)\*\*/g, '$1')
    cleaned = cleaned.replace(/\*(.+?)\*/g, '$1')
    cleaned = cleaned.replace(/###+\s*/g, '')
    cleaned = cleaned.replace(/```[\s\S]*?```/g, '')
    cleaned = cleaned.replace(/`(.+?)`/g, '$1')
    // 去除结尾的对话式语言
    cleaned = cleaned.replace(/(希望.*?[！!。.])\s*$/g, '')
    cleaned = cleaned.replace(/(如有.*?(随时|联系).*?[！!。.])\s*$/g, '')
    cleaned = cleaned.replace(/(祝.*?[！!。.])\s*$/g, '')
    cleaned = cleaned.trim()
    return cleaned
  }

  async handlePublish(): Promise<void> {
    // 企业资质认证门禁
    const currentUser = AppState.currentUser
    if (currentUser && currentUser.authStatus !== AuthStatus.APPROVED) {
      let title = '发布限制'
      let message = '请先完成企业资质认证。'
      if (currentUser.authStatus === AuthStatus.UNAUTHENTICATED) {
        title = '发布限制'
        message = '您尚未完成企业资质认证，无法发布岗位。请先完成认证。'
      } else if (currentUser.authStatus === AuthStatus.PENDING) {
        title = '认证审核中'
        message = '您的企业资质正在审核中，审核通过后即可发布岗位。'
      } else if (currentUser.authStatus === AuthStatus.REJECTED) {
        title = '认证未通过'
        message = '您的企业资质审核未通过，请重新提交认证信息。'
      }
      AlertDialog.show({
        title: title,
        message: message,
        primaryButton: {
          value: '去认证',
          action: () => router.pushUrl({ url: AppConstants.ROUTE_RECRUITER_AUTH })
        },
        secondaryButton: { value: '取消', action: () => {} }
      })
      return
    }

    if (!this.title || !this.description) {
      AlertDialog.show({ message: '请填写完整信息' })
      return
    }

    // 创新点三：红线扫描
    const scanResult = await this.checkRedFlags(this.title, this.description)
    if (scanResult.hasRedFlags) {
      AlertDialog.show({
        title: scanResult.riskLevel === 'danger' ? '⚠️ 红线警告 - 禁止发布' : '⚠️ 风险提示',
        message: scanResult.analysis +
          '\n\n检测到的高风险词：' + scanResult.detectedFlags.join('、') +
          '\n\n该岗位已被系统拦截，无法发布。如有疑问，请联系平台客服。',
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
            action: () => {
              this.showPicker = false
              AppStorage.setOrCreate<number>('recruiter_switch_tab', 1)
            }
          },
          secondaryButton: { value: '取消', action: () => {} }
        })
        return
      }
    }

    // 微任务时间戳计算
    let computedTaskStart: number | undefined = undefined
    let computedTaskEnd: number | undefined = undefined
    if (this.category === JobCategory.MICRO_TASK) {
      if (this.taskStartDate) {
        computedTaskStart = Date.parse(this.taskStartDate)
        if (isNaN(computedTaskStart)) {
          computedTaskStart = undefined
        }
      }
      if (this.taskEndDate) {
        computedTaskEnd = Date.parse(this.taskEndDate)
        if (isNaN(computedTaskEnd)) {
          computedTaskEnd = undefined
        }
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
      skills: this.selectedSkills.length > 0 ? this.selectedSkills : this.skills.split(',').map(s => s.trim()).filter(s => s),
      status: JobStatus.PUBLISHED,
      publishTime: Date.now(),
      updateTime: Date.now(),
      viewCount: 0,
      applyCount: 0,
      tags: [this.category === JobCategory.MICRO_TASK ? '短期兼职' : '全职', this.educationRequired],
      isAIGenerated: this.wasAIGenerated,
      taskStartTime: computedTaskStart,
      taskEndTime: computedTaskEnd,
      requiredDayOfWeek: this.category === JobCategory.MICRO_TASK && this.requiredDaysOfWeek.length > 0 ? this.requiredDaysOfWeek[0] : undefined,
      requiredDaysOfWeek: this.category === JobCategory.MICRO_TASK ? this.requiredDaysOfWeek : undefined,
      requiredStartHour: this.category === JobCategory.MICRO_TASK ? this.requiredDayStartHour : undefined,
      requiredStartMinute: this.category === JobCategory.MICRO_TASK ? this.requiredDayStartMinute : undefined,
      requiredEndHour: this.category === JobCategory.MICRO_TASK ? this.requiredDayEndHour : undefined,
      requiredEndMinute: this.category === JobCategory.MICRO_TASK ? this.requiredDayEndMinute : undefined
    }

    await this.jobDao.insertJob(job)

    // 通知人才Tab刷新匹配
    AppStorage.setOrCreate<number>('talent_refresh', Date.now())

    AlertDialog.show({
      title: '✅ 发布成功！',
      message: '岗位已成功发布！可在「我的」→「已发布岗位管理」中查看详情和 AI 工时拼图分析。',
      primaryButton: { value: '好的', action: () => {} }
    })

    this.clearForm()
  }

  clearForm(): void {
    this.title = ''
    this.description = ''
    this.salaryRange = '面议'
    this.workAddress = ''
    this.city = ''
    this.skills = ''
    this.selectedSkills = []
    this.aiKeywords = ''
    this.wasAIGenerated = false
    this.taskStartDate = ''
    this.taskEndDate = ''
    this.requiredDaysOfWeek = []
    this.requiredDayStartHour = -1
    this.requiredDayStartMinute = 0
    this.requiredDayEndHour = -1
    this.requiredDayEndMinute = 0
  }

  // --- 滚动选择器逻辑 ---

  openPicker(type: string): void {
    this.showAIDescInput = false
    this.pickerType = type
    if (type === 'education') {
      this.tempEducationIndex = this.educationOptions.indexOf(this.educationRequired)
      if (this.tempEducationIndex < 0) {
        this.tempEducationIndex = 0
      }
    } else if (type === 'jobTitle') {
      if (this.title) {
        const fields: string[] = Object.keys(this.jobTitleMap)
        for (let i = 0; i < fields.length; i++) {
          const titles: string[] = this.jobTitleMap[fields[i]] || []
          const ti: number = titles.indexOf(this.title)
          if (ti >= 0) {
            this.tempJobFieldIndex = i
            this.tempJobTitleIndex = ti
            break
          }
        }
      }
    } else if (type === 'workYears') {
      this.tempWorkYearsIndex = this.workYearsOptions.indexOf(this.workYearsRequired)
      if (this.tempWorkYearsIndex < 0) {
        this.tempWorkYearsIndex = 0
      }
    } else if (type === 'city') {
      const provinces: string[] = Object.keys(this.cityMap)
      if (this.city) {
        for (let i = 0; i < provinces.length; i++) {
          const p: string = provinces[i]
          const c: string[] = this.cityMap[p] || []
          const ci: number = c.indexOf(this.city)
          if (ci >= 0) {
            this.tempProvinceIndex = i
            this.tempCityIndex = ci
            break
          }
          if (this.city === p) {
            this.tempProvinceIndex = i
            this.tempCityIndex = 0
            break
          }
        }
      }
    } else if (type === 'salary') {
      this.tempSalaryIndex = this.salaryOptions.indexOf(this.salaryRange)
      if (this.tempSalaryIndex < 0) {
        this.tempSalaryIndex = 0
      }
    } else if (type === 'skills') {
      this.tempSkills = [...this.selectedSkills]
      this.skillOptions = this.getSkillOptions()
    } else if (type === 'taskStartDate' || type === 'taskEndDate') {
      const dateStr = type === 'taskStartDate' ? this.taskStartDate : this.taskEndDate
      if (dateStr) {
        const d = new Date(dateStr)
        if (!isNaN(d.getTime())) {
          this.tempPickedDate = d
        } else {
          this.tempPickedDate = new Date()
        }
      } else {
        this.tempPickedDate = new Date()
      }
    } else if (type === 'taskDays') {
      this.tempSelectedDays = [...this.requiredDaysOfWeek]
    } else if (type === 'taskHours') {
      this.tempStartHIndex = this.requiredDayStartHour >= 0 ? this.requiredDayStartHour : 9
      this.tempStartMinuteIndex = this.minuteOptions.indexOf(
        this.requiredDayStartMinute >= 0 ? String(this.requiredDayStartMinute).padStart(2, '0') : '00')
      if (this.tempStartMinuteIndex < 0) {
        this.tempStartMinuteIndex = 0
      }
    } else if (type === 'taskEndHours') {
      this.tempEndHIndex = this.requiredDayEndHour >= 0 ? this.requiredDayEndHour : 17
      this.tempEndMinuteIndex = this.minuteOptions.indexOf(
        this.requiredDayEndMinute >= 0 ? String(this.requiredDayEndMinute).padStart(2, '0') : '00')
      if (this.tempEndMinuteIndex < 0) {
        this.tempEndMinuteIndex = 0
      }
    }
    this.showPicker = true
  }

  confirmPicker(): void {
    if (this.pickerType === 'education') {
      this.educationRequired = this.educationOptions[this.tempEducationIndex]
    } else if (this.pickerType === 'jobTitle') {
      const fields: string[] = Object.keys(this.jobTitleMap)
      const field: string = fields[this.tempJobFieldIndex]
      const titles: string[] = this.jobTitleMap[field] || []
      if (titles.length > 0 && this.tempJobTitleIndex < titles.length) {
        this.title = titles[this.tempJobTitleIndex]
        this.selectedSkills = []
      }
    } else if (this.pickerType === 'workYears') {
      this.workYearsRequired = this.workYearsOptions[this.tempWorkYearsIndex]
    } else if (this.pickerType === 'city') {
      const provinces: string[] = Object.keys(this.cityMap)
      const province: string = provinces[this.tempProvinceIndex]
      const cities: string[] = this.cityMap[province] || []
      if (cities.length > 0 && this.tempCityIndex < cities.length) {
        this.city = province + ' ' + cities[this.tempCityIndex]
      } else {
        this.city = province
      }
    } else if (this.pickerType === 'salary') {
      this.salaryRange = this.salaryOptions[this.tempSalaryIndex]
    } else if (this.pickerType === 'skills') {
      this.selectedSkills = [...this.tempSkills]
    } else if (this.pickerType === 'taskStartDate') {
      const d = this.tempPickedDate
      this.taskStartDate = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
    } else if (this.pickerType === 'taskEndDate') {
      const d = this.tempPickedDate
      this.taskEndDate = `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
    } else if (this.pickerType === 'taskDays') {
      this.requiredDaysOfWeek = [...this.tempSelectedDays].sort((a, b) => a - b)
    } else if (this.pickerType === 'taskHours') {
      this.requiredDayStartHour = this.tempStartHIndex
      this.requiredDayStartMinute = parseInt(this.minuteOptions[this.tempStartMinuteIndex])
    } else if (this.pickerType === 'taskEndHours') {
      this.requiredDayEndHour = this.tempEndHIndex
      this.requiredDayEndMinute = parseInt(this.minuteOptions[this.tempEndMinuteIndex])
    }
    this.showPicker = false
  }

  onProvinceChange(): void {
    this.tempCityIndex = 0
  }

  cancelPicker(): void {
    this.showPicker = false
  }

  build() {
    Stack() {
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
                  .onClick(() => {
                    this.category = JobCategory.FULLTIME_INTERN
                    this.selectedSkills = []
                  })
                Button('微任务/兼职')
                  .fontSize(12)
                  .height(32)
                  .backgroundColor(this.category === JobCategory.MICRO_TASK ? AppConstants.COLOR_ACCENT : '#F5F5F5')
                  .fontColor(this.category === JobCategory.MICRO_TASK ? '#FFFFFF' : '#666666')
                  .borderRadius(16)
                  .margin({ left: 8 })
                  .onClick(() => {
                    this.category = JobCategory.MICRO_TASK
                    this.selectedSkills = []
                  })
              }
            }
            .width('100%')
            .margin({ bottom: 14 })

            // 微任务时间设置（仅微任务显示）
            if (this.category === JobCategory.MICRO_TASK) {
              Column() {
                Text('⏰ 任务时间设置')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1A1A1A')
                  .margin({ bottom: 10 })
                  .alignSelf(ItemAlign.Start)

                // 任务起止日期（日历选择）
                PickerRowComponent({
                  label: '开始日期',
                  value: this.taskStartDate || '请选择',
                  onTap: () => this.openPicker('taskStartDate')
                })
                PickerRowComponent({
                  label: '结束日期',
                  value: this.taskEndDate || '请选择',
                  onTap: () => this.openPicker('taskEndDate')
                })

                // 工作时段（多选星期）
                PickerRowComponent({
                  label: '工作时段',
                  value: this.getDaysDisplay(),
                  onTap: () => this.openPicker('taskDays')
                })

                // 开始时间（时:分）
                PickerRowComponent({
                  label: '开始时间',
                  value: this.requiredDayStartHour >= 0 ?
                    `${this.requiredDayStartHour}:${String(this.requiredDayStartMinute).padStart(2, '0')}` : '请选择',
                  onTap: () => this.openPicker('taskHours')
                })

                // 结束时间（时:分）
                PickerRowComponent({
                  label: '结束时间',
                  value: this.requiredDayEndHour >= 0 ?
                    `${this.requiredDayEndHour}:${String(this.requiredDayEndMinute).padStart(2, '0')}` : '请选择',
                  onTap: () => this.openPicker('taskEndHours')
                })
              }
              .width('100%')
              .margin({ bottom: 6 })
            }

            PickerRowComponent({
              label: '岗位名称',
              value: this.title || '请选择',
              onTap: () => this.openPicker('jobTitle')
            })

            // 学历要求 - 滚动选择器
            PickerRowComponent({
              label: '学历要求',
              value: this.educationRequired || '请选择',
              onTap: () => this.openPicker('education')
            })

            // 薪资范围 - 滚动选择器
            PickerRowComponent({
              label: '薪资范围',
              value: this.salaryRange || '请选择',
              onTap: () => this.openPicker('salary')
            })

            // 工作年限 - 滚动选择器
            PickerRowComponent({
              label: '工作年限',
              value: this.workYearsRequired || '请选择',
              onTap: () => this.openPicker('workYears')
            })

            this.InputRow('工作地点', this.workAddress, '详细地址', (v) => this.workAddress = v)

            // 所在城市 - 级联滚动选择器
            PickerRowComponent({
              label: '所在城市',
              value: this.city || '请选择',
              onTap: () => this.openPicker('city')
            })

            // 技能要求 - 多选滚动选择器
            PickerRowComponent({
              label: '技能要求',
              value: this.selectedSkills.length > 0 ? this.selectedSkills.join('、') : '请选择',
              onTap: () => this.openPicker('skills')
            })

            // AI辅助生成描述
            Column() {
              Row() {
                Text('岗位描述')
                  .fontSize(13)
                  .fontColor('#666666')
                Blank()
                if (this.wasAIGenerated) {
                  Text('🤖 AI已生成')
                    .fontSize(10)
                    .fontColor(AppConstants.COLOR_ACCENT)
                    .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                    .backgroundColor('rgba(255,107,53,0.1)')
                    .borderRadius(8)
                    .margin({ right: 6 })
                }
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
                  LoadingProgress().width(16).height(16).color(AppConstants.COLOR_ACCENT)
                  Text(' AI生成中...')
                    .fontSize(12)
                    .fontColor(AppConstants.COLOR_ACCENT)
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
                .onChange((v) => {
                  this.description = v
                  this.wasAIGenerated = false
                })
            }
            .width('100%')
            .margin({ top: 8, bottom: 24 })

            // 发布按钮 + 扫描状态
            Column() {
              if (this.isScanning) {
                Row() {
                  LoadingProgress().width(14).height(14).color(AppConstants.COLOR_ACCENT)
                  Text(' 正在执行红线安全扫描...')
                    .fontSize(12)
                    .fontColor(AppConstants.COLOR_ACCENT)
                    .margin({ left: 4 })
                }
                .margin({ bottom: 10 })
              }

              Button('提交发布')
                .width('90%')
                .height(48)
                .fontSize(16)
                .backgroundColor(AppConstants.COLOR_ACCENT)
                .fontColor('#FFFFFF')
                .borderRadius(24)
                .enabled(!this.isScanning)
                .onClick(() => this.handlePublish())
            }
            .margin({ bottom: 12 })

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

      // 滚动选择器浮层
      if (this.showPicker) {
        Column() {
          // 半透明背景
          Column()
            .width('100%')
            .layoutWeight(1)
            .backgroundColor('rgba(0,0,0,0.4)')
            .onClick(() => this.cancelPicker())

          // 选择器面板
          Column() {
            // 顶部按钮行
            Row() {
              Button('取消')
                .fontSize(14)
                .fontColor('#999999')
                .backgroundColor(Color.Transparent)
                .onClick(() => this.cancelPicker())
              Blank()
              Text(this.getPickerTitle())
                .fontSize(15)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1A1A1A')
              Blank()
              Button('确认')
                .fontSize(14)
                .fontColor(AppConstants.COLOR_ACCENT)
                .backgroundColor(Color.Transparent)
                .fontWeight(FontWeight.Medium)
                .onClick(() => this.confirmPicker())
            }
            .width('100%')
            .height(44)
            .padding({ left: 16, right: 16 })
            .backgroundColor('#FAFAFA')
            .borderRadius({ topLeft: 12, topRight: 12 })

            Divider().height(1).color('#F0F0F0')

            // 根据类型显示不同选择器
            if (this.pickerType === 'education') {
              TextPicker({ range: this.educationOptions, selected: $$this.tempEducationIndex })
            }

            if (this.pickerType === 'workYears') {
              TextPicker({ range: this.workYearsOptions, selected: $$this.tempWorkYearsIndex })
            }

            if (this.pickerType === 'city') {
              this.CityCascadePicker()
            }

            if (this.pickerType === 'jobTitle') {
              this.JobTitleCascadePicker()
            }

            if (this.pickerType === 'salary') {
              TextPicker({ range: this.salaryOptions, selected: $$this.tempSalaryIndex })
            }

            if (this.pickerType === 'skills') {
              this.SkillMultiPicker()
            }

            if (this.pickerType === 'taskStartDate' || this.pickerType === 'taskEndDate') {
              DatePicker({
                start: new Date('2024-1-1'),
                end: new Date('2027-12-31'),
                selected: $$this.tempPickedDate
              })
            }

            if (this.pickerType === 'taskDays') {
              this.DayMultiPicker()
            }

            if (this.pickerType === 'taskHours') {
              Row() {
                Column() {
                  Text('时')
                    .fontSize(11)
                    .fontColor('#999999')
                    .margin({ bottom: 4 })
                  TextPicker({ range: this.hourOnlyOptions, selected: $$this.tempStartHIndex })
                }
                .layoutWeight(1)
                Column() {
                  Text('分')
                    .fontSize(11)
                    .fontColor('#999999')
                    .margin({ bottom: 4 })
                  TextPicker({ range: this.minuteOptions, selected: $$this.tempStartMinuteIndex })
                }
                .layoutWeight(1)
              }
              .width('100%')
              .height(200)
              .padding({ left: 16, right: 16 })
            }

            if (this.pickerType === 'taskEndHours') {
              Row() {
                Column() {
                  Text('时')
                    .fontSize(11)
                    .fontColor('#999999')
                    .margin({ bottom: 4 })
                  TextPicker({ range: this.hourOnlyOptions, selected: $$this.tempEndHIndex })
                }
                .layoutWeight(1)
                Column() {
                  Text('分')
                    .fontSize(11)
                    .fontColor('#999999')
                    .margin({ bottom: 4 })
                  TextPicker({ range: this.minuteOptions, selected: $$this.tempEndMinuteIndex })
                }
                .layoutWeight(1)
              }
              .width('100%')
              .height(200)
              .padding({ left: 16, right: 16 })
            }
          }
          .width('100%')
          .backgroundColor('#FFFFFF')
          .borderRadius({ topLeft: 12, topRight: 12 })
        }
        .width('100%')
        .height('100%')
        .position({ x: 0, y: 0 })
      }
    }
    .width('100%')
    .height('100%')
  }

  getPickerTitle(): string {
    if (this.pickerType === 'education') {
      return '选择学历要求'
    }
    if (this.pickerType === 'jobTitle') {
      return '选择岗位名称'
    }
    if (this.pickerType === 'workYears') {
      return '选择工作年限'
    }
    if (this.pickerType === 'city') {
      return '选择所在城市'
    }
    if (this.pickerType === 'salary') {
      return '选择薪资范围'
    }
    if (this.pickerType === 'skills') {
      return '选择技能要求（可多选）'
    }
    if (this.pickerType === 'taskStartDate') {
      return '选择任务开始日期'
    }
    if (this.pickerType === 'taskEndDate') {
      return '选择任务结束日期'
    }
    if (this.pickerType === 'taskDays') {
      return '选择工作时段（可多选）'
    }
    if (this.pickerType === 'taskHours') {
      return '选择开始时间'
    }
    if (this.pickerType === 'taskEndHours') {
      return '选择结束时间'
    }
    return ''
  }

  getDaysDisplay(): string {
    if (this.requiredDaysOfWeek.length === 0) {
      return '请选择'
    }
    const names: string[] = []
    for (let i = 0; i < this.requiredDaysOfWeek.length; i++) {
      const idx = this.requiredDaysOfWeek[i] - 1
      if (idx >= 0 && idx < this.dayOptions.length) {
        names.push(this.dayOptions[idx])
      }
    }
    return names.join('、')
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

  @Builder
  DayMultiPicker() {
    List() {
      ForEach(this.dayOptions, (day: string, index: number) => {
        ListItem() {
          Row() {
            Text(day)
              .fontSize(14)
              .fontColor('#333333')
              .layoutWeight(1)
            Checkbox({ name: 'day_' + index, group: 'dayPicker' })
              .selectedColor(AppConstants.COLOR_PRIMARY)
              .select(this.tempSelectedDays.indexOf(index + 1) >= 0)
              .onChange((checked: boolean) => {
                const dv = index + 1
                if (checked) {
                  this.tempSelectedDays = this.tempSelectedDays.concat([dv])
                } else {
                  const pos: number = this.tempSelectedDays.indexOf(dv)
                  if (pos >= 0) {
                    const tmp: number[] = this.tempSelectedDays
                    tmp.splice(pos, 1)
                    this.tempSelectedDays = tmp
                  }
                }
              })
          }
          .width('100%')
          .height(44)
          .padding({ left: 16, right: 16 })
        }
      })
    }
    .height(200)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder
  CityCascadePicker() {
    Row() {
      TextPicker({ range: this.getProvinces(), selected: $$this.tempProvinceIndex })
        .layoutWeight(1)
      TextPicker({ range: this.getCities(), selected: $$this.tempCityIndex })
        .layoutWeight(1)
    }
    .width('100%')
    .height(200)
  }

  @Builder
  JobTitleCascadePicker() {
    Row() {
      TextPicker({ range: this.getJobFields(), selected: $$this.tempJobFieldIndex })
        .layoutWeight(1)
      TextPicker({ range: this.getJobTitles(), selected: $$this.tempJobTitleIndex })
        .layoutWeight(1)
    }
    .width('100%')
    .height(200)
  }

  @Builder
  SkillMultiPicker() {
    List() {
      ForEach(this.skillOptions, (skill: string, index: number) => {
        ListItem() {
          Row() {
            Text(skill)
              .fontSize(14)
              .fontColor('#333333')
              .layoutWeight(1)
            Checkbox({ name: 'skill_' + index, group: 'skillPicker' })
              .selectedColor(AppConstants.COLOR_ACCENT)
              .select(this.tempSkills.indexOf(skill) >= 0)
              .onChange((checked: boolean) => {
                if (checked) {
                  this.tempSkills = this.tempSkills.concat([skill])
                } else {
                  const idx: number = this.tempSkills.indexOf(skill)
                  if (idx >= 0) {
                    const tmp: string[] = this.tempSkills
                    tmp.splice(idx, 1)
                    this.tempSkills = tmp
                  }
                }
              })
          }
          .width('100%')
          .height(44)
          .padding({ left: 16, right: 16 })
        }
      })
    }
    .height(200)
    .scrollBar(BarState.Off)
    .width('100%')
  }
}
