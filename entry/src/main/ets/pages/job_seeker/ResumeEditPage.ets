// 求职者 - 在线简历编辑页（含PDF解析 + 课表导入）

import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { ResumeInfo, EducationItem, ExperienceItem } from '../../model/ResumeModel'
import { ResumeDao } from '../../service/ResumeDao'

@Entry
@Component
struct ResumeEditPage {
  @State resume: ResumeInfo = this.createEmptyResume()
  @State currentTab: number = 0
  @State pdfUploaded: boolean = false
  @State pdfParsing: boolean = false
  private tabsController: TabsController = new TabsController()
  private resumeDao: ResumeDao = new ResumeDao()

  aboutToAppear(): void {
    this.loadResume()
  }

  async loadResume(): Promise<void> {
    if (AppState.currentUser) {
      const existing = await this.resumeDao.getResumeByUserId(AppState.currentUser.userId)
      if (existing) {
        this.resume = existing
      }
    }
  }

  createEmptyResume(): ResumeInfo {
    return {
      resumeId: `resume_${Date.now()}`,
      userId: AppState.currentUser?.userId || '',
      realName: AppState.currentUser?.realName || '',
      gender: AppState.currentUser?.gender || '',
      birthday: AppState.currentUser?.birthday || '',
      education: AppState.currentUser?.education || '本科',
      school: AppState.currentUser?.school || '',
      major: AppState.currentUser?.major || '',
      graduationYear: '',
      expectedPosition: AppState.currentUser?.expectedPosition || '',
      expectedSalary: AppState.currentUser?.expectedSalary || '',
      currentCity: AppState.currentUser?.currentCity || '',
      phone: AppState.currentUser?.phone || '',
      email: '',
      skills: [],
      selfIntro: '',
      educationList: [],
      experienceList: [],
      isFromPDF: false,
      pdfUncertainFields: [],
      hasSchedule: false,
      updateTime: Date.now()
    }
  }

  async handlePDFUpload(): Promise<void> {
    this.pdfParsing = true
    setTimeout(() => {
      this.pdfParsing = false
      this.pdfUploaded = true
      this.resume.isFromPDF = true
      this.resume.pdfUncertainFields = ['expectedPosition', 'skills']
      AlertDialog.show({
        title: 'PDF解析完成',
        message: '大部分信息已自动填写。黄色高亮字段为AI不确定的内容，请人工核对后点击确认。'
      })
    }, 2000)
  }

  async handleSave(): Promise<void> {
    this.resume.updateTime = Date.now()
    await this.resumeDao.insertResume(this.resume)
    AlertDialog.show({ message: '简历保存成功' })
    router.back()
  }

  build() {
    Column() {
      Row() {
        Button() {
          Image($r('sys.symbol.chevron_left'))
            .width(24)
            .height(24)
            .fillColor('#1A1A1A')
        }
        .backgroundColor('transparent')
        .onClick(() => router.back())

        Text('编辑简历')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button('保存')
          .fontSize(14)
          .height(32)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .fontColor('#FFFFFF')
          .borderRadius(16)
          .padding({ left: 14, right: 14 })
          .onClick(() => this.handleSave())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 28, bottom: 8 })

      // PDF上传区
      Column() {
        Row() {
          Image($r('sys.symbol.doc_text'))
            .width(24)
            .height(24)
            .fillColor(AppConstants.COLOR_PRIMARY)
          Text('上传我的 PDF 简历/作品集')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(AppConstants.COLOR_PRIMARY)
            .margin({ left: 8 })
        }

        if (this.pdfParsing) {
          LoadingProgress()
            .width(24)
            .height(24)
            .color(AppConstants.COLOR_PRIMARY)
            .margin({ top: 8 })
          Text('大模型解析中...')
            .fontSize(12)
            .fontColor('#999999')
        }
      }
      .width('90%')
      .height(72)
      .backgroundColor('#F0F7FF')
      .border({ width: 2, color: '#4A90D9', style: BorderStyle.Dashed, radius: 8 })
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .margin({ top: 8, bottom: 8 })
      .onClick(() => this.handlePDFUpload())

      Tabs({ controller: this.tabsController, index: this.currentTab }) {
        TabContent() {
          Scroll() {
            this.BasicInfoForm()
          }
        }.tabBar('基本信息')

        TabContent() {
          Scroll() {
            this.EducationForm()
          }
        }.tabBar('教育经历')

        TabContent() {
          Scroll() {
            this.ExperienceForm()
          }
        }.tabBar('经历')

        TabContent() {
          Scroll() {
            this.SkillsAndIntroForm()
          }
        }.tabBar('技能')
      }
      .barHeight(44)
      .barMode(BarMode.Scrollable)
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  @Builder
  BasicInfoForm() {
    Column() {
      this.FormField('姓名', this.resume.realName, false)
      this.FormField('电话', this.resume.phone, false)
      this.FormField('邮箱', this.resume.email, false)
      this.FormField('学历', this.resume.education, false)

      Row() {
        Text('现居地')
          .fontSize(14)
          .fontColor('#666666')
          .width(80)
        TextInput({ text: this.resume.currentCity, placeholder: '自动获取中...' })
          .layoutWeight(1)
          .fontSize(14)
          .onChange((v: string) => this.resume.currentCity = v)
        Text('📍')
          .fontSize(18)
      }
      .width('100%')
      .padding(12)
      .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })

      this.FormField('学校', this.resume.school, false)
      this.FormField('专业', this.resume.major, false)
      this.FormField('毕业年份', this.resume.graduationYear, false)

      // 期望职位（PDF不确定字段 - 淡黄色高亮）
      Row() {
        Text('期望职位')
          .fontSize(14)
          .fontColor('#666666')
          .width(80)
        TextInput({ text: this.resume.expectedPosition, placeholder: '请输入期望职位' })
          .layoutWeight(1)
          .fontSize(14)
          .backgroundColor(this.resume.pdfUncertainFields.indexOf('expectedPosition') >= 0 ? AppConstants.COLOR_YELLOW_HIGHLIGHT : 'transparent')
          .onChange((v: string) => this.resume.expectedPosition = v)
      }
      .width('100%')
      .padding(12)
      .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })

      this.FormField('期望薪资', this.resume.expectedSalary, false)
    }
    .padding({ left: 16, right: 16 })
  }

  @Builder
  EducationForm() {
    Column() {
      ForEach(this.resume.educationList, (item: EducationItem, index: number) => {
        Row() {
          Column() {
            Text(item.schoolName)
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
            Text(`${item.major} · ${item.degree}`)
              .fontSize(12)
              .fontColor('#666666')
              .margin({ top: 2 })
            Text(`${item.startYear} - ${item.endYear}`)
              .fontSize(11)
              .fontColor('#999999')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Button('删除')
            .fontSize(11)
            .backgroundColor('transparent')
            .fontColor('#FF4D4F')
        }
        .width('100%')
        .padding(12)
        .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
      })

      Button('+ 添加教育经历')
        .width('90%')
        .height(40)
        .fontSize(14)
        .backgroundColor('#F5F5F5')
        .fontColor('#4A90D9')
        .borderRadius(8)
        .margin({ top: 16 })
    }
    .padding({ left: 16, right: 16 })
  }

  @Builder
  ExperienceForm() {
    Column() {
      ForEach(this.resume.experienceList, (item: ExperienceItem, index: number) => {
        Column() {
          Row() {
            Text(item.type === 'intern' ? '实习' : '项目')
              .fontSize(11)
              .fontColor('#FFFFFF')
              .padding({ left: 8, right: 8, top: 2, bottom: 2 })
              .backgroundColor(item.type === 'intern' ? '#4A90D9' : '#FF6B35')
              .borderRadius(8)
            Text(item.companyName || item.projectName || '')
              .fontSize(14)
              .fontWeight(FontWeight.Medium)
              .margin({ left: 8 })
            Blank()
            Button('删除')
              .fontSize(11)
              .backgroundColor('transparent')
              .fontColor('#FF4D4F')
          }
          .width('100%')

          Text(item.description)
            .fontSize(12)
            .fontColor('#666666')
            .maxLines(3)
            .margin({ top: 6 })

          if (item.translatedDescription) {
            Row() {
              Text('AI翻译: ')
                .fontSize(11)
                .fontColor(AppConstants.COLOR_ACCENT)
              Text(item.translatedDescription)
                .fontSize(11)
                .fontColor('#666666')
            }
            .margin({ top: 4 })
          }
        }
        .width('100%')
        .padding(12)
        .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
      })

      Row() {
        Button('+ 添加实习经历')
          .width('44%')
          .height(40)
          .fontSize(13)
          .backgroundColor('#F0F7FF')
          .fontColor('#4A90D9')
          .borderRadius(8)

        Button('+ 添加项目经历')
          .width('44%')
          .height(40)
          .fontSize(13)
          .backgroundColor('#FFF8F0')
          .fontColor('#FF6B35')
          .borderRadius(8)
      }
      .width('100%')
      .justifyContent(FlexAlign.SpaceAround)
      .margin({ top: 16 })

      Button('一键导入课表')
        .width('90%')
        .height(44)
        .fontSize(14)
        .backgroundColor('#E8F5E9')
        .fontColor('#4CAF50')
        .borderRadius(8)
        .margin({ top: 16 })
        .onClick(() => {
          AlertDialog.show({
            title: '导入课表',
            message: '拍照上传教务处课表，系统将自动OCR识别并生成弹性工时日历。'
          })
        })
    }
    .padding({ left: 16, right: 16 })
  }

  @Builder
  SkillsAndIntroForm() {
    Column() {
      Text('技能标签')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .margin({ bottom: 8 })

      Row() {
        TextInput({ placeholder: '添加技能（回车确认）' })
          .layoutWeight(1)
          .fontSize(13)
          .backgroundColor('#F5F5F5')
          .borderRadius(8)
          .height(40)
        Button('添加')
          .fontSize(12)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .fontColor('#FFFFFF')
          .borderRadius(8)
          .height(40)
          .margin({ left: 8 })
      }
      .width('100%')
      .margin({ bottom: 12 })

      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.resume.skills, (skill: string) => {
          Row() {
            Text(skill)
              .fontSize(12)
              .fontColor('#4A90D9')
              .margin({ right: 4 })
            Text('x')
              .fontSize(14)
              .fontColor('#999999')
          }
          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
          .backgroundColor('#F0F7FF')
          .borderRadius(12)
          .margin({ right: 8, bottom: 8 })
        })
      }
      .width('100%')

      Text('自我介绍')
        .fontSize(14)
        .fontWeight(FontWeight.Medium)
        .margin({ top: 16, bottom: 8 })

      TextArea({ text: this.resume.selfIntro, placeholder: '简洁描述你的优势和职业目标...' })
        .width('100%')
        .height(120)
        .fontSize(13)
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .padding(12)
        .onChange((v: string) => this.resume.selfIntro = v)
    }
    .padding({ left: 16, right: 16 })
  }

  @Builder
  FormField(label: string, value: string, isPDFUncertain: boolean) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#666666')
        .width(80)
      TextInput({ text: value, placeholder: `请输入${label}` })
        .layoutWeight(1)
        .fontSize(14)
        .backgroundColor(isPDFUncertain ? AppConstants.COLOR_YELLOW_HIGHLIGHT : 'transparent')
        .onChange(() => {
        })
    }
    .width('100%')
    .padding(12)
    .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
  }
}
