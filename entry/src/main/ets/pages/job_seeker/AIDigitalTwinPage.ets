import { router, promptAction } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { ResumeDao } from '../../service/ResumeDao'
import { MessageDao } from '../../service/MessageDao'

@Entry
@Component
export struct AIDigitalTwinPage {
  @State isEnabled: boolean = false
  @State minSalary: string = ''
  @State preferredPositions: string[] = []
  @State availableTimeDesc: string = ''
  private resumeDao: ResumeDao = new ResumeDao()
  private messageDao: MessageDao = new MessageDao()

  aboutToAppear(): void {
    this.loadSettings()
  }

  async loadSettings(): Promise<void> {
    if (!AppState.currentUser) {
      return
    }
    this.isEnabled = await this.messageDao.getAIAgentEnabled(AppState.currentUser.userId)
    const resume = await this.resumeDao.getResumeByUserId(AppState.currentUser.userId)
    const schedule = await this.resumeDao.getScheduleByUserId(AppState.currentUser.userId)
    this.minSalary = resume?.expectedSalary || AppState.currentUser.expectedSalary || '5000'
    this.preferredPositions = resume?.expectedPosition
      ? resume.expectedPosition.split(/[、,，/]/).map((item: string) => item.trim()).filter((item: string) => !!item)
      : []
    this.availableTimeDesc = schedule?.freeSlots.map((item) => item.label).join('、') || '请先在简历页导入课表'
  }

  async toggleEnabled(value: boolean): Promise<void> {
    this.isEnabled = value
    if (AppState.currentUser) {
      await this.messageDao.updateAIAgentEnabled(AppState.currentUser.userId, value)
    }
    promptAction.showToast({
      message: value ? 'AI 数字分身已开启' : 'AI 数字分身已关闭',
      duration: 2000
    })
  }

  build() {
    Column() {
      Row() {
        Button() {
          Image($r('app.media.ic_back'))
            .width(22)
            .height(22)
            .fillColor('#1A1A1A')
        }
        .backgroundColor('transparent')
        .onClick(() => router.back())
        Blank()
        Text('AI 数字分身')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Blank()
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 28, bottom: 12 })

      Scroll() {
        Column() {
          Column() {
            Text('24 小时 AI 数字分身')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
            Text('当你上课、睡觉或暂时不在线时，AI 会根据简历和底线先帮你接住 HR 的初筛消息。')
              .fontSize(12)
              .lineHeight(20)
              .fontColor('#666666')
              .margin({ top: 8 })

            Toggle({ type: ToggleType.Switch, isOn: this.isEnabled })
              .selectedColor(AppConstants.COLOR_AI_PURPLE)
              .margin({ top: 16 })
              .onChange((value: boolean) => this.toggleEnabled(value))
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .margin({ bottom: 12 })

          Column() {
            Text('当前底线')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 12 })

            this.InfoRow('期望薪资', this.minSalary || '未设置')
            this.InfoRow('目标岗位', this.preferredPositions.join('、') || '未设置')
            this.InfoRow('可约时间', this.availableTimeDesc)
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .margin({ bottom: 12 })

          Column() {
            Text('工作说明')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
              .alignSelf(ItemAlign.Start)
              .margin({ bottom: 12 })
            this.RuleRow('1', 'AI 会优先回复问候、时间协调、项目介绍等初筛问题。')
            this.RuleRow('2', '涉及薪资谈判、录用确认等关键决策时，仍需要你本人接手。')
            this.RuleRow('3', '所有 AI 代聊消息都会显示为紫色气泡，便于你回看。')
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
        }
        .padding({ left: 16, right: 16, top: 12, bottom: 20 })
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  InfoRow(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(14)
        .fontColor('#666666')
        .width(90)
      Text(value)
        .fontSize(14)
        .fontColor('#1A1A1A')
        .layoutWeight(1)
    }
    .width('100%')
    .padding({ top: 10, bottom: 10 })
    .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
  }

  @Builder
  RuleRow(index: string, content: string) {
    Row() {
      Text(index)
        .fontSize(12)
        .fontColor('#FFFFFF')
        .width(20)
        .height(20)
        .backgroundColor(AppConstants.COLOR_AI_PURPLE)
        .borderRadius(10)
        .textAlign(TextAlign.Center)
        .margin({ right: 10 })
      Text(content)
        .fontSize(13)
        .lineHeight(20)
        .fontColor('#666666')
    }
    .width('100%')
    .padding({ top: 6, bottom: 6 })
  }
}
