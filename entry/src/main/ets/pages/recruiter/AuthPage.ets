// 招聘者 - 企业资质认证页（三步认证向导）

import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { AuthStatus } from '../../model/UserModel'
import { UserDao } from '../../service/UserDao'
import { PickerService } from '../../service/PickerService'
import { DocumentOcrService } from '../../service/DocumentOcrService'

@Entry
@Component
struct AuthPage {
  @State currentStep: number = 0
  @State mode: string = 'auth' // 'auth' = 首次认证三步向导, 'manage' = 管理编辑单页
  // 步骤一：个人实名
  @State hrRealName: string = ''
  @State hrIdCard: string = ''
  @State idCardFrontUri: string = ''
  @State idCardBackUri: string = ''
  @State faceUri: string = ''
  // 步骤二：企业资质
  @State companyName: string = ''
  @State companyAddress: string = ''
  @State companyIndustry: string = ''
  @State companyScale: string = ''
  @State legalPerson: string = ''
  @State contactPosition: string = ''
  @State companyEmail: string = ''
  @State businessLicenseUri: string = ''
  @State idCardOcrPassed: boolean = false
  @State licenseOcrPassed: boolean = false
  // 步骤三：审核提交
  @State agreed: boolean = false
  @State isSubmitting: boolean = false
  // 通用
  @State showImagePreview: boolean = false
  @State previewImageUri: string = ''
  // 选择器
  @State showPicker: boolean = false
  @State pickerType: string = ''
  @State @Watch('onIndustryCategoryChange') tempIndustryCategoryIndex: number = 0
  @State tempIndustryIndex: number = 0
  @State tempScaleIndex: number = 0
  private userDao: UserDao = new UserDao()

  // 行业分类数据
  private industryMap: Record<string, string[]> = {
    '互联网/IT': ['软件开发', '人工智能/机器学习', '大数据/数据科学', '云计算/DevOps', '网络安全', '物联网/嵌入式', '区块链/Web3', '游戏开发', 'IT服务/外包', '通信/5G'],
    '金融': ['银行', '证券/投行', '保险', '基金/资管', '互联网金融/金融科技', '消费金融', '支付/清算', '信托/租赁'],
    '教育': ['高等教育', 'K12教育', '学前教育', '职业培训', '在线教育', '留学服务', '素质教育', '教育科技'],
    '医疗健康': ['医药制造', '医疗器械', '医疗服务/医院', '生物科技', '健康管理/体检', '互联网医疗', '养老服务', '医美'],
    '制造': ['汽车制造', '电子/半导体', '机械/重工', '化工/材料', '食品加工', '航空航天', '纺织服装', '智能硬件'],
    '房地产/建筑': ['房地产开发', '物业管理', '建筑设计', '装修装饰', '建材', '房产中介', '商业地产'],
    '零售/电商': ['综合电商', '跨境电商', '新零售', '直播电商', '社区团购', '百货/商超', '便利店'],
    '文化传媒': ['广告/公关', '影视/娱乐', '出版', '新媒体/MCN', '体育/健身', '文化艺术', '会展'],
    '交通/物流': ['快递/物流', '航空运输', '铁路运输', '海运/港口', '城市交通/出行', '供应链管理'],
    '能源/环保': ['新能源/光伏', '电力/电网', '石油/化工能源', '环保/碳中和', '水利/水务', '矿业'],
    '咨询/服务': ['管理咨询', '人力资源服务', '法律/法务', '会计/审计/税务', '市场调研', '认证检测'],
    '消费品': ['食品饮料', '日化用品', '家电', '消费电子', '奢侈品/珠宝', '家居/家具', '宠物用品'],
    '农业': ['种植业', '养殖业', '农产品加工', '智慧农业', '种子/化肥', '休闲农业'],
    '政府/非营利': ['政府机关', '事业单位', '科研院所', '社会团体/NGO', '国际组织']
  }

  private scaleOptions: string[] = [
    '10人以下', '10-50人', '50-100人', '100-300人', '300-500人',
    '500-1000人', '1000-5000人', '5000-10000人', '10000人以上'
  ]

  getIndustryCategories(): string[] {
    return Object.keys(this.industryMap)
  }

  getIndustries(): string[] {
    const keys = Object.keys(this.industryMap)
    if (this.tempIndustryCategoryIndex >= 0 && this.tempIndustryCategoryIndex < keys.length) {
      return this.industryMap[keys[this.tempIndustryCategoryIndex]] || []
    }
    return []
  }

  onIndustryCategoryChange(): void {
    this.tempIndustryIndex = 0
  }

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>
    if (params && params['mode'] === 'manage') {
      this.mode = 'manage'
    }
    const user = AppState.currentUser
    if (user) {
      if (user.hrRealName) this.hrRealName = user.hrRealName
      if (user.idCard) this.hrIdCard = user.idCard
      if (user.companyName) this.companyName = user.companyName
      if (user.companyAddress) this.companyAddress = user.companyAddress
      if (user.companyIndustry) this.companyIndustry = user.companyIndustry
      if (user.companyScale) this.companyScale = user.companyScale
      if (user.legalPerson) this.legalPerson = user.legalPerson
      if (user.contactPosition) this.contactPosition = user.contactPosition
      if (user.companyEmail) this.companyEmail = user.companyEmail
      if (user.businessLicense) this.businessLicenseUri = user.businessLicense
      if (user.idCardFrontImage) this.idCardFrontUri = user.idCardFrontImage
      if (user.idCardBackImage) this.idCardBackUri = user.idCardBackImage
      if (user.faceImage) this.faceUri = user.faceImage
    }
  }

  // ==================== 图片选择 ====================

  async pickImage(target: string): Promise<void> {
    try {
      const uri = await PickerService.pickSingleImage()
      if (!uri) return
      if (target === 'idCardFront') {
        this.idCardFrontUri = uri
        this.recognizeIdCard(uri, 'front')
      } else if (target === 'idCardBack') {
        this.idCardBackUri = uri
        this.recognizeIdCard(uri, 'back')
      } else if (target === 'face') {
        this.faceUri = uri
      } else if (target === 'license') {
        this.businessLicenseUri = uri
        this.recognizeLicense(uri)
      }
    } catch (e) {
      // 用户取消选择
    }
  }

  async recognizeIdCard(uri: string, side: 'front' | 'back'): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext
      const result = await DocumentOcrService.recognizeIdCard(uri, side, context)
      if (result.code === 200 && result.data) {
        const d = result.data
        if (side === 'front') {
          if (d.name && !this.hrRealName) this.hrRealName = d.name
          if (d.number && !this.hrIdCard) this.hrIdCard = d.number
          if (d.name && d.number) this.idCardOcrPassed = true
        }
      } else {
        this.idCardOcrPassed = false
      }
    } catch (e) {
      this.idCardOcrPassed = false
    }
  }

  async recognizeLicense(uri: string): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext
      const result = await DocumentOcrService.recognizeBusinessLicense(uri, context)
      if (result.code === 200 && result.data) {
        const d = result.data
        if (d.name && !this.companyName) this.companyName = d.name
        if (d.legalRepresentative && !this.legalPerson) this.legalPerson = d.legalRepresentative
        if (d.address && !this.companyAddress) this.companyAddress = d.address
        if (d.name && d.legalRepresentative) this.licenseOcrPassed = true
      } else {
        this.licenseOcrPassed = false
      }
    } catch (e) {
      this.licenseOcrPassed = false
    }
  }

  // ==================== 选择器逻辑 ====================

  openPicker(type: string): void {
    this.pickerType = type
    if (type === 'industry') {
      if (this.companyIndustry) {
        const keys = Object.keys(this.industryMap)
        for (let i = 0; i < keys.length; i++) {
          const industries = this.industryMap[keys[i]]
          if (industries) {
            const idx = industries.indexOf(this.companyIndustry)
            if (idx >= 0) {
              this.tempIndustryCategoryIndex = i
              this.tempIndustryIndex = idx
              break
            }
          }
        }
      } else {
        this.tempIndustryCategoryIndex = 0
        this.tempIndustryIndex = 0
      }
    } else if (type === 'scale') {
      const idx = this.scaleOptions.indexOf(this.companyScale)
      this.tempScaleIndex = idx >= 0 ? idx : 0
    }
    this.showPicker = true
  }

  confirmPicker(): void {
    if (this.pickerType === 'industry') {
      const keys = Object.keys(this.industryMap)
      if (this.tempIndustryCategoryIndex >= 0 && this.tempIndustryCategoryIndex < keys.length) {
        const cat = keys[this.tempIndustryCategoryIndex]
        const industries = this.industryMap[cat]
        if (industries && this.tempIndustryIndex >= 0 && this.tempIndustryIndex < industries.length) {
          this.companyIndustry = industries[this.tempIndustryIndex]
        }
      }
    } else if (this.pickerType === 'scale') {
      if (this.tempScaleIndex >= 0 && this.tempScaleIndex < this.scaleOptions.length) {
        this.companyScale = this.scaleOptions[this.tempScaleIndex]
      }
    }
    this.showPicker = false
  }

  cancelPicker(): void {
    this.showPicker = false
  }

  getPickerTitle(): string {
    if (this.pickerType === 'industry') return '选择所属行业'
    if (this.pickerType === 'scale') return '选择企业规模'
    return ''
  }

  // ==================== 提交逻辑 ====================

  validateIdCard(id: string): boolean {
    return id.length === 18 && /^[0-9]{17}[0-9Xx]$/.test(id)
  }

  canGoStep1(): boolean {
    return !!this.hrRealName.trim() && !!this.hrIdCard.trim()
      && this.validateIdCard(this.hrIdCard.trim())
      && !!this.idCardFrontUri && !!this.idCardBackUri
  }

  canGoStep2(): boolean {
    return !!this.companyName.trim() && !!this.companyAddress.trim()
      && !!this.legalPerson.trim() && !!this.businessLicenseUri
  }

  async handleSubmit(): Promise<void> {
    if (!this.hrRealName || !this.hrIdCard || !this.companyName) {
      AlertDialog.show({ message: '请填写完整信息' })
      return
    }
    if (!this.validateIdCard(this.hrIdCard)) {
      AlertDialog.show({ message: '请输入正确的18位身份证号码' })
      return
    }
    if (!this.idCardFrontUri || !this.idCardBackUri) {
      AlertDialog.show({ message: '请上传身份证正反面照片' })
      return
    }
    if (!this.businessLicenseUri) {
      AlertDialog.show({ message: '请上传营业执照' })
      return
    }
    if (!this.agreed) {
      AlertDialog.show({ message: '请勾选信息真实性承诺' })
      return
    }

    this.isSubmitting = true
    try {
      const user = AppState.currentUser
      if (user) {
        const ocrAllPassed = this.idCardOcrPassed && this.licenseOcrPassed
        user.hrRealName = this.hrRealName
        user.idCard = this.hrIdCard
        user.companyName = this.companyName
        user.companyAddress = this.companyAddress
        user.companyIndustry = this.companyIndustry
        user.companyScale = this.companyScale
        user.legalPerson = this.legalPerson
        user.contactPosition = this.contactPosition
        user.companyEmail = this.companyEmail
        user.businessLicense = this.businessLicenseUri
        user.idCardFrontImage = this.idCardFrontUri
        user.idCardBackImage = this.idCardBackUri
        user.faceImage = this.faceUri
        user.authStatus = ocrAllPassed ? AuthStatus.APPROVED : AuthStatus.PENDING
        user.authSubmitTime = Date.now()
        if (ocrAllPassed) user.authApproveTime = Date.now()
        await this.userDao.submitAuth(user.userId, user)
        AppState.currentUser = user
        AppState.syncToStorage()

        if (ocrAllPassed) {
          AlertDialog.show({
            title: '认证通过',
            message: '身份证和营业执照核验一致，企业资质认证已通过，您可以立即发布岗位。',
            primaryButton: { value: '进入', action: () => {
              router.replaceUrl({ url: AppConstants.ROUTE_RECRUITER_MAIN })
            }}
          })
        } else {
          let failMsg = '以下证件未能通过系统自动识别，请重新拍摄上传：'
          if (!this.idCardOcrPassed) failMsg += '\n· 身份证（请确保照片清晰、正面拍摄）'
          if (!this.licenseOcrPassed) failMsg += '\n· 营业执照（请确保照片清晰、平整无反光）'
          AlertDialog.show({
            title: '证件识别未通过',
            message: failMsg,
            primaryButton: { value: '知道了', action: () => {} }
          })
        }
      }
    } catch (e) {
      AlertDialog.show({ message: '提交失败，请稍后重试' })
    } finally {
      this.isSubmitting = false
    }
  }

  async handleSaveManage(): Promise<void> {
    const user = AppState.currentUser
    if (!user) return
    user.hrRealName = this.hrRealName
    user.idCard = this.hrIdCard
    user.companyName = this.companyName
    user.companyAddress = this.companyAddress
    user.companyIndustry = this.companyIndustry
    user.companyScale = this.companyScale
    user.legalPerson = this.legalPerson
    user.contactPosition = this.contactPosition
    user.companyEmail = this.companyEmail
    user.businessLicense = this.businessLicenseUri
    user.idCardFrontImage = this.idCardFrontUri
    user.idCardBackImage = this.idCardBackUri
    user.faceImage = this.faceUri
    await this.userDao.updateUser(user)
    AppState.currentUser = user
    AppState.syncToStorage()
    AlertDialog.show({ message: '认证信息已更新' })
    router.back()
  }

  // ==================== 构建器 ====================

  @Builder
  StepIndicator() {
    Row() {
      Column() { this.StepDot('个人实名认证', 0) }
      Divider().width(28).height(2).color(this.currentStep >= 1 ? AppConstants.COLOR_PRIMARY : '#E5E5E5')
      Column() { this.StepDot('企业资质认证', 1) }
      Divider().width(28).height(2).color(this.currentStep >= 2 ? AppConstants.COLOR_PRIMARY : '#E5E5E5')
      Column() { this.StepDot('审核提交', 2) }
    }
    .width('90%')
    .justifyContent(FlexAlign.Center)
    .margin({ top: 16, bottom: 8 })
  }

  @Builder
  StepDot(label: string, index: number) {
    Column() {
      Column() {
        Text(`${index + 1}`)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.currentStep >= index ? '#FFFFFF' : '#999999')
      }
      .width(24)
      .height(24)
      .backgroundColor(this.currentStep >= index ? AppConstants.COLOR_PRIMARY : '#E5E5E5')
      .borderRadius(12)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .onClick(() => {
        if (index < this.currentStep) this.currentStep = index
      })
      Text(label)
        .fontSize(10)
        .fontColor(this.currentStep >= index ? AppConstants.COLOR_PRIMARY : '#999999')
        .margin({ top: 4 })
    }
    .alignItems(HorizontalAlign.Center)
  }

  @Builder
  FormField(label: string, value: string, placeholder: string, onChange: (v: string) => void, inputType?: InputType, maxLen?: number) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('#666666')
        .width(72)
      TextInput({ text: value, placeholder: placeholder })
        .layoutWeight(1)
        .fontSize(13)
        .height(44)
        .placeholderColor('#BBBBBB')
        .backgroundColor('#F8F8F8')
        .borderRadius(8)
        .padding({ left: 12 })
        .type(inputType ?? InputType.Normal)
        .maxLength(maxLen ?? -1)
        .onChange(onChange)
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  getUploadUri(target: string): string {
    if (target === 'idCardFront') return this.idCardFrontUri
    if (target === 'idCardBack') return this.idCardBackUri
    if (target === 'face') return this.faceUri
    if (target === 'license') return this.businessLicenseUri
    return ''
  }

  @Builder
  UploadCard(label: string, hint: string, target: string) {
    Column() {
      Text(label)
        .fontSize(12)
        .fontColor('#666666')
        .margin({ bottom: 8 })
        .alignSelf(ItemAlign.Start)

      Stack() {
        Column()
          .width('100%')
          .height(140)
          .backgroundColor('#F0F7FF')
          .border({ width: 2, color: '#4A90D9', style: BorderStyle.Dashed, radius: 8 })

        if (this.getUploadUri(target)) {
          Column() {
            Image(this.getUploadUri(target))
              .width('100%')
              .height(120)
              .objectFit(ImageFit.Contain)
              .borderRadius(6)
          }
          .width('100%')
          .height(140)
          .padding(10)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .onClick(() => {
            this.previewImageUri = this.getUploadUri(target)
            this.showImagePreview = true
          })

          Button() {
            Text('重选')
              .fontSize(10)
              .fontColor('#4A90D9')
          }
          .height(24)
          .backgroundColor('rgba(255,255,255,0.9)')
          .borderRadius(12)
          .padding({ left: 8, right: 8 })
          .position({ x: '85%', y: 6 })
          .onClick(() => this.pickImage(target))
        } else {
          Column() {
            Image($r('sys.symbol.camera'))
              .width(28)
              .height(28)
              .fillColor(AppConstants.COLOR_PRIMARY)
              .margin({ bottom: 6 })
            Text(hint)
              .fontSize(12)
              .fontColor('#4A90D9')
          }
          .width('100%')
          .height(140)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
          .onClick(() => this.pickImage(target))
        }
      }
      .width('100%')
      .height(140)
    }
    .width('100%')
    .margin({ bottom: 12 })
  }

  @Builder
  PickerRow(label: string, value: string, onClick: () => void) {
    Row() {
      Text(label)
        .fontSize(13)
        .fontColor('#666666')
        .width(72)
      Text(value)
        .fontSize(13)
        .fontColor(value === '请选择' ? '#CCCCCC' : '#1A1A1A')
        .layoutWeight(1)
      Image($r('sys.symbol.chevron_right'))
        .width(12)
        .height(12)
        .fillColor('#CCCCCC')
    }
    .width('100%')
    .height(44)
    .padding({ left: 12, right: 12 })
    .backgroundColor('#F8F8F8')
    .borderRadius(8)
    .margin({ bottom: 12 })
    .onClick(onClick)
  }

  @Builder
  IndustryCascadePicker() {
    Column() {
      Row() {
        Text('行业分类')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .width('50%')
          .textAlign(TextAlign.Center)
        Text('具体行业')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#333333')
          .width('50%')
          .textAlign(TextAlign.Center)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })
      .backgroundColor('#FAFAFA')

      Divider().height(1).color('#F0F0F0')

      Row() {
        TextPicker({ range: this.getIndustryCategories(), selected: $$this.tempIndustryCategoryIndex })
          .width('50%')
          .height(200)
          .backgroundColor('#FFFFFF')
        Divider().vertical(true).height(180).color('#F0F0F0')
        TextPicker({ range: this.getIndustries(), selected: $$this.tempIndustryIndex })
          .width('50%')
          .height(200)
          .backgroundColor('#FFFFFF')
      }
      .width('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
  }

  // ==================== 步骤一：个人实名认证 ====================

  @Builder
  StepOneIdentity() {
    Column() {
      Text('请填写您的真实身份信息，确保招聘行为责任到人')
        .fontSize(12)
        .fontColor('#999999')
        .margin({ bottom: 16 })
        .width('100%')
        .textAlign(TextAlign.Start)

      Column() {
        Text('HR 实名信息')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 10 })
          .alignSelf(ItemAlign.Start)

        this.FormField('真实姓名', this.hrRealName, '请输入您的真实姓名', (v) => this.hrRealName = v)
        this.FormField('身份证号', this.hrIdCard, '请输入18位身份证号码',
          (v) => this.hrIdCard = v, InputType.Number, 18)

        if (this.hrIdCard.length > 0 && !this.validateIdCard(this.hrIdCard)) {
          Text('请输入正确的18位身份证号码')
            .fontSize(11)
            .fontColor(AppConstants.COLOR_DANGER)
            .margin({ bottom: 8 })
            .alignSelf(ItemAlign.Start)
        }
      }
      .width('100%')

      Divider().height(1).color('#F0F0F0').margin({ top: 4, bottom: 16 })

      Text('身份证照片上传')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 10 })
        .alignSelf(ItemAlign.Start)

      this.UploadCard('身份证人像面（正面）', '拍照上传身份证人像面', 'idCardFront')

      this.UploadCard('身份证国徽面（反面）', '拍照上传身份证国徽面', 'idCardBack')

      this.UploadCard('手持身份证照片（建议）', '拍摄手持身份证正面照', 'face')
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  // ==================== 步骤二：企业资质认证 ====================

  @Builder
  StepTwoEnterprise() {
    Column() {
      Text('请上传企业营业执照，系统将自动识别并核验工商信息')
        .fontSize(12)
        .fontColor('#999999')
        .margin({ bottom: 16 })
        .width('100%')
        .textAlign(TextAlign.Start)

      Column() {
        Text('企业基本信息')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 10 })
          .alignSelf(ItemAlign.Start)

        this.FormField('企业全称', this.companyName, '请输入营业执照上的企业全称',
          (v) => this.companyName = v)
        this.FormField('法定代表人', this.legalPerson, '请输入企业法定代表人姓名',
          (v) => this.legalPerson = v)
        this.FormField('注册地址', this.companyAddress, '请输入企业工商注册地址',
          (v) => this.companyAddress = v)
        Row() {
          Text('所属行业')
            .fontSize(13)
            .fontColor('#666666')
            .width(72)
          Text(this.companyIndustry || '请选择')
            .fontSize(13)
            .fontColor(this.companyIndustry ? '#1A1A1A' : '#CCCCCC')
            .layoutWeight(1)
          Image($r('sys.symbol.chevron_right'))
            .width(12)
            .height(12)
            .fillColor('#CCCCCC')
        }
        .width('100%')
        .height(44)
        .padding({ left: 12, right: 12 })
        .backgroundColor('#F8F8F8')
        .borderRadius(8)
        .margin({ bottom: 12 })
        .onClick(() => this.openPicker('industry'))

        Row() {
          Text('企业规模')
            .fontSize(13)
            .fontColor('#666666')
            .width(72)
          Text(this.companyScale || '请选择')
            .fontSize(13)
            .fontColor(this.companyScale ? '#1A1A1A' : '#CCCCCC')
            .layoutWeight(1)
          Image($r('sys.symbol.chevron_right'))
            .width(12)
            .height(12)
            .fillColor('#CCCCCC')
        }
        .width('100%')
        .height(44)
        .padding({ left: 12, right: 12 })
        .backgroundColor('#F8F8F8')
        .borderRadius(8)
        .margin({ bottom: 12 })
        .onClick(() => this.openPicker('scale'))
      }
      .width('100%')

      Divider().height(1).color('#F0F0F0').margin({ top: 4, bottom: 16 })

      Text('联系人信息')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 10 })
        .alignSelf(ItemAlign.Start)

      this.FormField('联系人职位', this.contactPosition, '如：HR经理/招聘主管',
        (v) => this.contactPosition = v)
      this.FormField('企业邮箱', this.companyEmail, '请输入企业邮箱地址',
        (v) => this.companyEmail = v)

      Divider().height(1).color('#F0F0F0').margin({ top: 4, bottom: 16 })

      Text('营业执照上传')
        .fontSize(14)
        .fontWeight(FontWeight.Bold)
        .margin({ bottom: 10 })
        .alignSelf(ItemAlign.Start)

      this.UploadCard('营业执照（正本或副本）', '拍照或从相册选择营业执照', 'license')

      // 安全提示
      Row() {
        Image($r('sys.symbol.checkmark_shield'))
          .width(16)
          .height(16)
          .fillColor(AppConstants.COLOR_SUCCESS)
        Text('系统将自动进行法人及工商信息核验比对，从源头封杀皮包公司')
          .fontSize(11)
          .fontColor('#999999')
          .margin({ left: 6 })
          .layoutWeight(1)
      }
      .width('100%')
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  // ==================== 步骤三：审核提交 ====================

  @Builder
  StepThreeReview() {
    Column() {
      Text('请核对以下认证信息，确认无误后提交审核')
        .fontSize(12)
        .fontColor('#999999')
        .margin({ bottom: 16 })
        .width('100%')
        .textAlign(TextAlign.Start)

      // 个人实名汇总
      Column() {
        Text('个人实名信息')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 10 })
          .alignSelf(ItemAlign.Start)

        this.SummaryRow('真实姓名', this.hrRealName)
        this.SummaryRow('身份证号', this.hrIdCard.replace(/(\d{6})\d{8}(\d{4})/, '$1********$2'))

        Row() {
          if (this.idCardFrontUri) {
            Image(this.idCardFrontUri)
              .width(80)
              .height(50)
              .objectFit(ImageFit.Cover)
              .borderRadius(4)
              .onClick(() => { this.previewImageUri = this.idCardFrontUri; this.showImagePreview = true })
          }
          if (this.idCardBackUri) {
            Image(this.idCardBackUri)
              .width(80)
              .height(50)
              .objectFit(ImageFit.Cover)
              .borderRadius(4)
              .margin({ left: 8 })
              .onClick(() => { this.previewImageUri = this.idCardBackUri; this.showImagePreview = true })
          }
          if (this.faceUri) {
            Image(this.faceUri)
              .width(80)
              .height(50)
              .objectFit(ImageFit.Cover)
              .borderRadius(4)
              .margin({ left: 8 })
              .onClick(() => { this.previewImageUri = this.faceUri; this.showImagePreview = true })
          }
        }
        .width('100%')
        .margin({ top: 4, bottom: 8 })
      }
      .width('100%')
      .padding(14)
      .backgroundColor('#F8F8F8')
      .borderRadius(8)
      .margin({ bottom: 12 })

      // 企业资质汇总
      Column() {
        Text('企业资质信息')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .margin({ bottom: 10 })
          .alignSelf(ItemAlign.Start)

        this.SummaryRow('企业全称', this.companyName)
        this.SummaryRow('法定代表人', this.legalPerson)
        this.SummaryRow('注册地址', this.companyAddress)
        this.SummaryRow('所属行业', this.companyIndustry)
        this.SummaryRow('企业规模', this.companyScale)

        Divider().height(1).color('#F0F0F0').margin({ top: 4, bottom: 8 })

        this.SummaryRow('联系人职位', this.contactPosition)
        this.SummaryRow('企业邮箱', this.companyEmail)

        if (this.businessLicenseUri) {
          Row() {
            Text('营业执照')
              .fontSize(12)
              .fontColor('#666666')
              .width(72)
            Image(this.businessLicenseUri)
              .width(120)
              .height(75)
              .objectFit(ImageFit.Cover)
              .borderRadius(4)
              .onClick(() => { this.previewImageUri = this.businessLicenseUri; this.showImagePreview = true })
          }
          .width('100%')
          .margin({ top: 8, bottom: 4 })
        }
      }
      .width('100%')
      .padding(14)
      .backgroundColor('#F8F8F8')
      .borderRadius(8)
      .margin({ bottom: 20 })

      // 承诺勾选
      Row() {
        Checkbox()
          .select(this.agreed)
          .selectedColor(AppConstants.COLOR_PRIMARY)
          .width(18)
          .height(18)
          .onChange((checked: boolean) => this.agreed = checked)
        Text('我承诺所提交信息真实有效，自愿承担法律责任')
          .fontSize(12)
          .fontColor('#666666')
          .margin({ left: 8 })
          .layoutWeight(1)
      }
      .width('100%')
      .margin({ bottom: 8 })
    }
    .width('100%')
    .padding({ left: 16, right: 16 })
  }

  @Builder
  SummaryRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor('#999999')
        .width(72)
      Text(value || '未填写')
        .fontSize(13)
        .fontColor(value ? '#1A1A1A' : '#CCCCCC')
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ bottom: 6 })
  }

  // ==================== 图片预览 ====================

  @Builder
  ImagePreviewOverlay() {
    Column() {
      Row() {
        Blank()
        Button({ type: ButtonType.Circle }) {
          Image($r('sys.symbol.xmark'))
            .width(18)
            .height(18)
            .fillColor('#FFFFFF')
        }
        .width(36)
        .height(36)
        .backgroundColor('rgba(0,0,0,0.5)')
        .onClick(() => { this.showImagePreview = false; this.previewImageUri = '' })
        .margin({ top: 28, right: 16 })
      }
      .width('100%')

      Image(this.previewImageUri)
        .width('90%')
        .layoutWeight(1)
        .objectFit(ImageFit.Contain)
        .margin({ bottom: 60 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('rgba(0,0,0,0.92)')
  }

  // ==================== 主 Build ====================

  build() {
    if (this.showImagePreview) {
      Stack() {
        this.ImagePreviewOverlay()
      }
      .width('100%')
      .height('100%')
    } else if (this.mode === 'manage') {
      this.ManageModeContent()
    } else {
      Stack() {
        Column() {
          // 顶部导航
        Row() {
          Button() {
            Image($r('app.media.ic_back'))
              .width(24)
              .height(24)
              .fillColor('#1A1A1A')
          }
          .backgroundColor('transparent')
          .onClick(() => router.back())

          Text('企业资质认证')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 80, bottom: 4 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        // 步骤指示器
        this.StepIndicator()

        // 驳回原因提示
        if (AppState.currentUser?.authStatus === AuthStatus.REJECTED && AppState.currentUser?.authRejectReason) {
          Row() {
            Text('驳回原因：' + AppState.currentUser.authRejectReason)
              .fontSize(11)
              .fontColor(AppConstants.COLOR_DANGER)
              .layoutWeight(1)
          }
          .width('90%')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor('#FFF1F0')
          .border({ width: 1, color: '#FFCCC7', radius: 6 })
          .margin({ top: 4, bottom: 4 })
        }

        // 内容区
        Scroll() {
          if (this.currentStep === 0) {
            this.StepOneIdentity()
          } else if (this.currentStep === 1) {
            this.StepTwoEnterprise()
          } else {
            this.StepThreeReview()
          }
        }
        .width('100%')
        .layoutWeight(1)
        .margin({ top: 12 })

        // 底部导航按钮
        Row() {
          if (this.currentStep > 0) {
            Button('上一步')
              .width('40%')
              .height(46)
              .fontSize(15)
              .backgroundColor('#F0F0F0')
              .fontColor('#666666')
              .borderRadius(23)
              .onClick(() => this.currentStep--)
              .margin({ right: 12 })
          }

          if (this.currentStep < 2) {
            Button('下一步')
              .width(this.currentStep > 0 ? '40%' : '60%')
              .height(46)
              .fontSize(15)
              .backgroundColor(AppConstants.COLOR_PRIMARY)
              .fontColor('#FFFFFF')
              .borderRadius(23)
              .enabled(this.currentStep === 0 ? this.canGoStep1() : this.canGoStep2())
              .opacity((this.currentStep === 0 ? this.canGoStep1() : this.canGoStep2()) ? 1.0 : 0.5)
              .onClick(() => {
                if (this.currentStep === 0 && this.canGoStep1()) this.currentStep = 1
                else if (this.currentStep === 1 && this.canGoStep2()) this.currentStep = 2
              })
          } else {
            Button(this.isSubmitting ? '提交审核中…' : '提交审核')
              .width('60%')
              .height(46)
              .fontSize(15)
              .backgroundColor(AppConstants.COLOR_SUCCESS)
              .fontColor('#FFFFFF')
              .borderRadius(23)
              .enabled(!this.isSubmitting && this.agreed)
              .opacity(!this.isSubmitting && this.agreed ? 1.0 : 0.5)
              .onClick(() => this.handleSubmit())
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ left: 20, right: 20, top: 8, bottom: 20 })
        .backgroundColor('#FFFFFF')
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')

      // ========== 滚动选择器浮层 ==========
      if (this.showPicker) {
        Column() {
          Column()
            .width('100%')
            .layoutWeight(1)
            .backgroundColor('rgba(0,0,0,0.4)')
            .onClick(() => this.cancelPicker())

          Column() {
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

            if (this.pickerType === 'industry') {
              this.IndustryCascadePicker()
            }

            if (this.pickerType === 'scale') {
              Column() {
                Text('企业规模')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#333333')
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: 12, bottom: 8 })
                  .backgroundColor('#FAFAFA')
                Divider().height(1).color('#F0F0F0')
                TextPicker({ range: this.scaleOptions, selected: $$this.tempScaleIndex })
                  .height(200)
                  .backgroundColor('#FFFFFF')
              }
              .width('100%')
              .backgroundColor('#FFFFFF')
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
    }
  }
  // ==================== 管理模式：单页编辑 ====================

  @Builder
  ManageModeContent() {
    Stack() {
      Column() {
        Row() {
          Button() {
            Image($r('app.media.ic_back'))
              .width(24)
              .height(24)
              .fillColor('#1A1A1A')
          }
          .backgroundColor('transparent')
          .onClick(() => router.back())

          Text('企业认证管理')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 80, bottom: 4 })
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

        Row() {
          Text('认证状态')
            .fontSize(12)
            .fontColor('#666666')
          Blank()
          Text(this.getManageAuthStatusText())
            .fontSize(12)
            .fontColor(this.getManageAuthStatusColor())
            .padding({ left: 10, right: 10, top: 3, bottom: 3 })
            .backgroundColor(this.getManageAuthStatusBgColor())
            .borderRadius(8)
        }
        .width('90%')
        .padding({ left: 12, right: 12, top: 8, bottom: 8 })
        .backgroundColor('#FAFAFA')
        .borderRadius(8)
        .margin({ top: 8, bottom: 4 })

        if (AppState.currentUser?.authStatus === AuthStatus.REJECTED && AppState.currentUser?.authRejectReason) {
          Row() {
            Text('驳回原因：' + AppState.currentUser.authRejectReason)
              .fontSize(11)
              .fontColor(AppConstants.COLOR_DANGER)
              .layoutWeight(1)
          }
          .width('90%')
          .padding({ left: 12, right: 12, top: 8, bottom: 8 })
          .backgroundColor('#FFF1F0')
          .border({ width: 1, color: '#FFCCC7', radius: 6 })
          .margin({ top: 4, bottom: 4 })
        }

        Scroll() {
          Column() {
            Text('个人实名信息')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 10 })
              .alignSelf(ItemAlign.Start)

            this.FormField('真实姓名', this.hrRealName, '请输入您的真实姓名', (v) => this.hrRealName = v)
            this.FormField('身份证号', this.hrIdCard, '请输入18位身份证号码',
              (v) => this.hrIdCard = v, InputType.Number, 18)

            if (this.hrIdCard.length > 0 && !this.validateIdCard(this.hrIdCard)) {
              Text('请输入正确的18位身份证号码')
                .fontSize(11)
                .fontColor(AppConstants.COLOR_DANGER)
                .margin({ bottom: 8 })
                .alignSelf(ItemAlign.Start)
            }

            this.UploadCard('身份证人像面（正面）', '拍照上传身份证人像面', 'idCardFront')
            this.UploadCard('身份证国徽面（反面）', '拍照上传身份证国徽面', 'idCardBack')
            this.UploadCard('手持身份证照片（建议）', '拍摄手持身份证正面照', 'face')

            Divider().height(1).color('#F0F0F0').margin({ top: 4, bottom: 16 })

            Text('企业基本信息')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 10 })
              .alignSelf(ItemAlign.Start)

            this.FormField('企业全称', this.companyName, '请输入营业执照上的企业全称',
              (v) => this.companyName = v)
            this.FormField('法定代表人', this.legalPerson, '请输入企业法定代表人姓名',
              (v) => this.legalPerson = v)
            this.FormField('注册地址', this.companyAddress, '请输入企业工商注册地址',
              (v) => this.companyAddress = v)

            Row() {
              Text('所属行业')
                .fontSize(13)
                .fontColor('#666666')
                .width(72)
              Text(this.companyIndustry || '请选择')
                .fontSize(13)
                .fontColor(this.companyIndustry ? '#1A1A1A' : '#CCCCCC')
                .layoutWeight(1)
              Image($r('sys.symbol.chevron_right'))
                .width(12)
                .height(12)
                .fillColor('#CCCCCC')
            }
            .width('100%')
            .height(44)
            .padding({ left: 12, right: 12 })
            .backgroundColor('#F8F8F8')
            .borderRadius(8)
            .margin({ bottom: 12 })
            .onClick(() => this.openPicker('industry'))

            Row() {
              Text('企业规模')
                .fontSize(13)
                .fontColor('#666666')
                .width(72)
              Text(this.companyScale || '请选择')
                .fontSize(13)
                .fontColor(this.companyScale ? '#1A1A1A' : '#CCCCCC')
                .layoutWeight(1)
              Image($r('sys.symbol.chevron_right'))
                .width(12)
                .height(12)
                .fillColor('#CCCCCC')
            }
            .width('100%')
            .height(44)
            .padding({ left: 12, right: 12 })
            .backgroundColor('#F8F8F8')
            .borderRadius(8)
            .margin({ bottom: 12 })
            .onClick(() => this.openPicker('scale'))

            Divider().height(1).color('#F0F0F0').margin({ top: 4, bottom: 16 })

            Text('联系人信息')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 10 })
              .alignSelf(ItemAlign.Start)

            this.FormField('联系人职位', this.contactPosition, '如：HR经理/招聘主管',
              (v) => this.contactPosition = v)
            this.FormField('企业邮箱', this.companyEmail, '请输入企业邮箱地址',
              (v) => this.companyEmail = v)

            Divider().height(1).color('#F0F0F0').margin({ top: 4, bottom: 16 })

            Text('营业执照上传')
              .fontSize(14)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 10 })
              .alignSelf(ItemAlign.Start)

            this.UploadCard('营业执照（正本或副本）', '拍照或从相册选择营业执照', 'license')

            Row() {
              Image($r('sys.symbol.checkmark_shield'))
                .width(16)
                .height(16)
                .fillColor(AppConstants.COLOR_SUCCESS)
              Text('系统将自动进行法人及工商信息核验比对')
                .fontSize(11)
                .fontColor('#999999')
                .margin({ left: 6 })
                .layoutWeight(1)
            }
            .width('100%')
            .margin({ bottom: 20 })
          }
          .width('100%')
          .padding({ left: 16, right: 16 })
        }
        .width('100%')
        .layoutWeight(1)
        .margin({ top: 12 })

        Row() {
          Button('保存修改')
            .width('60%')
            .height(46)
            .fontSize(15)
            .backgroundColor(AppConstants.COLOR_PRIMARY)
            .fontColor('#FFFFFF')
            .borderRadius(23)
            .onClick(() => this.handleSaveManage())
        }
        .width('100%')
        .justifyContent(FlexAlign.Center)
        .padding({ left: 20, right: 20, top: 8, bottom: 20 })
        .backgroundColor('#FFFFFF')
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F5F5F5')

      if (this.showPicker) {
        Column() {
          Column()
            .width('100%')
            .layoutWeight(1)
            .backgroundColor('rgba(0,0,0,0.4)')
            .onClick(() => this.cancelPicker())

          Column() {
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

            if (this.pickerType === 'industry') {
              this.IndustryCascadePicker()
            }

            if (this.pickerType === 'scale') {
              Column() {
                Text('企业规模')
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#333333')
                  .width('100%')
                  .textAlign(TextAlign.Center)
                  .padding({ top: 12, bottom: 8 })
                  .backgroundColor('#FAFAFA')
                Divider().height(1).color('#F0F0F0')
                TextPicker({ range: this.scaleOptions, selected: $$this.tempScaleIndex })
                  .height(200)
                  .backgroundColor('#FFFFFF')
              }
              .width('100%')
              .backgroundColor('#FFFFFF')
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

  getManageAuthStatusText(): string {
    const status = AppState.currentUser?.authStatus ?? 0
    switch (status) {
      case AuthStatus.PENDING: return '认证审核中'
      case AuthStatus.APPROVED: return '已认证'
      case AuthStatus.REJECTED: return '认证未通过'
      default: return '未认证'
    }
  }

  getManageAuthStatusColor(): string {
    const status = AppState.currentUser?.authStatus ?? 0
    switch (status) {
      case AuthStatus.PENDING: return AppConstants.COLOR_WARNING
      case AuthStatus.APPROVED: return AppConstants.COLOR_SUCCESS
      case AuthStatus.REJECTED: return AppConstants.COLOR_DANGER
      default: return '#999999'
    }
  }

  getManageAuthStatusBgColor(): string {
    const status = AppState.currentUser?.authStatus ?? 0
    switch (status) {
      case AuthStatus.PENDING: return '#FFFBE6'
      case AuthStatus.APPROVED: return '#F0FFF0'
      case AuthStatus.REJECTED: return '#FFF1F0'
      default: return '#F5F5F5'
    }
  }
}
