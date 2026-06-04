import { router } from '@kit.ArkUI'
import { AppConstants } from '../../common/constants/AppConstants'
import { CampusAIContractRisk, CampusAIService } from '../../service/CampusAIService'
import { OcrBlock, VisionOcrService } from '../../service/VisionOcrService'
import { PickerService } from '../../service/PickerService'

@Entry
@Component
struct ContractReviewPage {
  @State imageUri: string = ''
  @State contractText: string = ''
  @State isScanning: boolean = false
  @State showTextSheet: boolean = false
  @State risks: CampusAIContractRisk[] = []
  @State summary: string = ''
  @State ocrBlocks: OcrBlock[] = []
  @State imageWidth: number = 1
  @State imageHeight: number = 1

  getExampleContractText(): string {
    return [
      '乙方需参加入职前培训，培训费用人民币5000元，由乙方承担。',
      '乙方需缴纳入职保证金2000元。',
      '如乙方提前离职，需支付违约金20000元。',
      '乙方在职期间不得生育子女。',
      '公司不给乙方缴纳社保，以每月现金补贴代替。'
    ].join('\n')
  }

  async pickAndAnalyzeImage(): Promise<void> {
    try {
      this.imageUri = await PickerService.pickSingleImage()
      this.isScanning = true
      const ocrResult = await VisionOcrService.recognizeImage(this.imageUri)
      this.contractText = ocrResult.fullText
      this.ocrBlocks = ocrResult.blocks
      this.imageWidth = ocrResult.imageWidth
      this.imageHeight = ocrResult.imageHeight
      await this.reviewCurrentText()
    } catch (e) {
      AlertDialog.show({ message: e instanceof Error ? e.message : '图片识别失败，请重试' })
    } finally {
      this.isScanning = false
    }
  }

  async reviewCurrentText(): Promise<void> {
    if (!this.contractText.trim()) {
      AlertDialog.show({ message: '请先提供合同内容' })
      return
    }
    try {
      const result = await CampusAIService.reviewContract(this.contractText)
      this.risks = result.risks || []
      this.summary = result.summary || ''
      this.showTextSheet = false
    } catch (e) {
      AlertDialog.show({ message: e instanceof Error ? e.message : 'AI 合同审查失败，请稍后重试' })
    }
  }

  copyScript(script: string): void {
    AlertDialog.show({
      title: '谈判话术',
      message: script
    })
  }

  getSeverityColor(severity: 'high' | 'medium' | 'low'): string {
    switch (severity) {
      case 'high':
        return '#FF4D4F'
      case 'medium':
        return '#FAAD14'
      default:
        return '#52C41A'
    }
  }

  build() {
    Column() {
      Row() {
        Button() {
          Image($r('sys.symbol.chevron_left'))
            .width(22)
            .height(22)
            .fillColor('#1A1A1A')
        }
        .backgroundColor('transparent')
        .onClick(() => router.back())
        Blank()
        Text('合同避坑审查')
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
            if (!this.imageUri && !this.isScanning) {
              Column() {
                Image($r('sys.symbol.camera'))
                  .width(48)
                  .height(48)
                  .fillColor(AppConstants.COLOR_PRIMARY)
                  .margin({ bottom: 12 })
                Text('上传合同或三方协议图片')
                  .fontSize(14)
                  .fontColor(AppConstants.COLOR_PRIMARY)
                Text('支持选择拍好的合同照片，系统会先 OCR 再做 AI 审查')
                  .fontSize(12)
                  .fontColor('#999999')
                  .margin({ top: 6 })
              }
              .width('100%')
              .padding(40)
              .alignItems(HorizontalAlign.Center)
              .justifyContent(FlexAlign.Center)
              .onClick(() => this.pickAndAnalyzeImage())
            } else if (this.isScanning) {
              Column() {
                LoadingProgress()
                  .width(48)
                  .height(48)
                  .color(AppConstants.COLOR_PRIMARY)
                Text('正在 OCR 识别并审查合同...')
                  .fontSize(14)
                  .fontColor('#666666')
                  .margin({ top: 12 })
              }
              .width('100%')
              .padding(40)
              .alignItems(HorizontalAlign.Center)
            } else {
              Stack() {
                Image(this.imageUri)
                  .width('100%')
                  .height(260)
                  .borderRadius(12)
                  .objectFit(ImageFit.Contain)

                HighlightOverlay({
                  blocks: this.ocrBlocks,
                  risks: this.risks,
                  imageWidth: this.imageWidth,
                  imageHeight: this.imageHeight
                })
                  .width('100%')
                  .height(260)
              }
            }
          }
          .width('100%')
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
          .border({ width: this.imageUri || this.isScanning ? 0 : 2, color: AppConstants.COLOR_PRIMARY, radius: 12 })
          .margin({ bottom: 12 })

          Row() {
            Button('手动编辑识别文本')
              .layoutWeight(1)
              .height(40)
              .fontSize(13)
              .backgroundColor('#F0F7FF')
              .fontColor(AppConstants.COLOR_PRIMARY)
              .borderRadius(20)
              .onClick(() => {
                if (!this.contractText.trim()) {
                  this.contractText = this.getExampleContractText()
                }
                this.showTextSheet = true
              })
            Button('重新选图')
              .layoutWeight(1)
              .height(40)
              .fontSize(13)
              .backgroundColor('#F5F5F5')
              .fontColor('#666666')
              .borderRadius(20)
              .margin({ left: 10 })
              .onClick(() => this.pickAndAnalyzeImage())
          }
          .width('100%')
          .margin({ bottom: 12 })

          if (this.summary) {
            Text(this.summary)
              .fontSize(13)
              .lineHeight(22)
              .fontColor('#445266')
              .padding(14)
              .backgroundColor('#FFF9E8')
              .borderRadius(12)
              .width('100%')
              .margin({ bottom: 12 })
          }

          Column() {
            Row() {
              Text('风险审查报告')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1A1A1A')
              Blank()
              Text(`${this.risks.length} 个风险点`)
                .fontSize(12)
                .fontColor(this.risks.length > 0 ? '#FF4D4F' : '#52C41A')
            }
            .width('100%')
            .margin({ bottom: 12 })

            if (this.risks.length === 0) {
              Text('暂未识别到明显风险条款。建议你继续人工复核关键薪资、违约金、社保和竞业限制条款。')
                .fontSize(13)
                .fontColor('#666666')
                .lineHeight(22)
                .width('100%')
            } else {
              ForEach(this.risks, (risk: CampusAIContractRisk) => {
                Column() {
                  Row() {
                    Text(risk.title)
                      .fontSize(14)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#1A1A1A')
                      .layoutWeight(1)
                    Text(risk.severity === 'high' ? '高风险' : risk.severity === 'medium' ? '中风险' : '低风险')
                      .fontSize(10)
                      .fontColor('#FFFFFF')
                      .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                      .backgroundColor(this.getSeverityColor(risk.severity))
                      .borderRadius(4)
                  }
                  .width('100%')

                  Text(`命中条款：${risk.matchedClause}`)
                    .fontSize(11)
                    .fontColor('#FF4D4F')
                    .margin({ top: 6 })
                    .width('100%')

                  Text(risk.description)
                    .fontSize(13)
                    .fontColor('#666666')
                    .lineHeight(20)
                    .margin({ top: 8 })
                    .width('100%')

                  Text(risk.suggestion)
                    .fontSize(12)
                    .fontColor('#445266')
                    .lineHeight(20)
                    .margin({ top: 8 })
                    .width('100%')

                  Button('查看谈判话术')
                    .fontSize(12)
                    .height(28)
                    .backgroundColor(AppConstants.COLOR_PRIMARY)
                    .fontColor('#FFFFFF')
                    .borderRadius(14)
                    .margin({ top: 10 })
                    .onClick(() => this.copyScript(risk.negotiationScript))
                }
                .width('100%')
                .padding(12)
                .backgroundColor('#FFFFFF')
                .borderRadius(12)
                .border({ width: 1, color: this.getSeverityColor(risk.severity), radius: 12 })
                .margin({ bottom: 10 })
              })
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(12)
        }
        .padding({ left: 16, right: 16, top: 12, bottom: 20 })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
    .bindSheet($$this.showTextSheet, this.TextSheet(), { dragBar: true, showClose: true, height: 560 })
  }

  @Builder
  TextSheet() {
    Column() {
      Row() {
        Button('载入示例')
          .fontSize(14)
          .backgroundColor('transparent')
          .fontColor(AppConstants.COLOR_PRIMARY)
          .onClick(() => {
            this.contractText = this.getExampleContractText()
          })
        Blank()
        Text('编辑识别文本')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
        Blank()
        Button('重新审查')
          .fontSize(14)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .fontColor('#FFFFFF')
          .borderRadius(16)
          .padding({ left: 14, right: 14, top: 4, bottom: 4 })
          .onClick(() => this.reviewCurrentText())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      TextArea({ text: this.contractText, placeholder: 'OCR 识别出的合同文本会出现在这里，你也可以手动修正后重新审查。' })
        .width('100%')
        .layoutWeight(1)
        .fontSize(13)
        .backgroundColor('#F5F5F5')
        .borderRadius(8)
        .padding(12)
        .margin(16)
        .onChange((value: string) => { this.contractText = value })
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}

@Component
struct HighlightOverlay {
  @Prop blocks: OcrBlock[] = []
  @Prop risks: CampusAIContractRisk[] = []
  @Prop imageWidth: number = 1
  @Prop imageHeight: number = 1
  private settings: RenderingContextSettings = new RenderingContextSettings(true)
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings)

  aboutToAppear(): void {
    setTimeout(() => this.draw(), 120)
  }

  draw(): void {
    const canvasWidth = 320
    const canvasHeight = 260
    const widthScale = canvasWidth / Math.max(1, this.imageWidth)
    const heightScale = canvasHeight / Math.max(1, this.imageHeight)
    const ctx = this.context
    ctx.clearRect(0, 0, canvasWidth, canvasHeight)

    for (let i = 0; i < this.blocks.length; i++) {
      const block = this.blocks[i]
      const matchedRisk = this.risks.find((risk: CampusAIContractRisk) =>
        block.text.includes(risk.matchedClause) || risk.matchedClause.includes(block.text)
      )
      if (!matchedRisk) {
        continue
      }
      const color = matchedRisk.severity === 'high' ? '#FF4D4F' : matchedRisk.severity === 'medium' ? '#FAAD14' : '#52C41A'
      ctx.strokeStyle = color
      ctx.lineWidth = 2
      ctx.strokeRect(
        block.left * widthScale,
        block.top * heightScale,
        Math.max(block.width * widthScale, 24),
        Math.max(block.height * heightScale, 16)
      )
    }
  }

  build() {
    Canvas(this.context)
      .width('100%')
      .height('100%')
      .onAreaChange(() => {
        this.draw()
      })
  }
}

export { ContractReviewPage }
