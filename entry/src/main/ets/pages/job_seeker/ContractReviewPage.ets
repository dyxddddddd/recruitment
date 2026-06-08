import { router } from '@kit.ArkUI'
import { AppConstants } from '../../common/constants/AppConstants'
import { CampusAIContractRisk, CampusAIContractReviewResult, CampusAIService } from '../../service/CampusAIService'
import { PickerService } from '../../service/PickerService'
import { OcrBlock, OcrResult, VisionOcrService } from '../../service/VisionOcrService'

interface HighlightMark {
  left: number
  top: number
  width: number
  height: number
  severity: string
  title: string
}

interface ImageLayoutInfo {
  scale: number
  offsetX: number
  offsetY: number
}

interface BlockMatchCandidate {
  block: OcrBlock
  score: number
}

@Entry
@Component
struct ContractReviewPage {
  @State imageUri: string = ''
  @State contractText: string = ''
  @State isScanning: boolean = false
  @State risks: CampusAIContractRisk[] = []
  @State summary: string = ''
  @State riskLevel: string = ''
  @State ocrBlocks: OcrBlock[] = []
  @State imageWidth: number = 0
  @State imageHeight: number = 0
  @State highlightMarks: HighlightMark[] = []

  private readonly previewWidth: number = 340
  private readonly previewHeight: number = 240
  private canvasSettings: RenderingContextSettings = new RenderingContextSettings(true)
  private canvasContext: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.canvasSettings)

  getExampleContractText(): string {
    return [
      '乙方需参加入职前培训，培训费用人民币5000元，由乙方承担。',
      '乙方需缴纳入职保证金3000元。',
      '如乙方提前离职，需支付违约金20000元。',
      '乙方在职期间不得生育子女。',
      '公司不给乙方缴纳社保，以每月现金补贴替代。'
    ].join('\n')
  }

  async pickAndAnalyzeImage(): Promise<void> {
    try {
      this.imageUri = await PickerService.pickSingleImage()
      this.isScanning = true
      const ocrResult: OcrResult = await VisionOcrService.recognizeImage(this.imageUri)
      this.applyOcrResult(ocrResult)
      await this.reviewCurrentText()
    } catch (e) {
      AlertDialog.show({ message: e instanceof Error ? e.message : '合同图片识别失败，请重试' })
    } finally {
      this.isScanning = false
    }
  }

  async useExampleAndReview(): Promise<void> {
    this.imageUri = ''
    this.ocrBlocks = []
    this.imageWidth = 0
    this.imageHeight = 0
    this.highlightMarks = []
    this.clearCanvas()
    this.contractText = this.getExampleContractText()
    await this.reviewCurrentText()
  }

  async reviewCurrentText(): Promise<void> {
    if (!this.contractText.trim()) {
      AlertDialog.show({ message: '请先上传合同图片，或粘贴合同文本' })
      return
    }
    try {
      this.isScanning = true
      const result: CampusAIContractReviewResult = await CampusAIService.reviewContract(this.contractText.trim())
      this.summary = result.summary || ''
      this.riskLevel = result.overallRiskLevel || ''
      this.risks = result.risks || []
      this.highlightMarks = this.buildHighlightMarks(this.risks, this.ocrBlocks)
      this.redrawHighlightCanvas()
      AlertDialog.show({
        message: this.risks.length > 0
          ? `AI 审查完成，发现 ${this.risks.length} 条风险，并已在原图上做红圈标记。`
          : 'AI 审查完成，暂未发现明显风险。'
      })
    } catch (e) {
      AlertDialog.show({ message: e instanceof Error ? e.message : 'AI 合同审查失败，请稍后重试' })
    } finally {
      this.isScanning = false
    }
  }

  private applyOcrResult(ocrResult: OcrResult): void {
    this.contractText = ocrResult.fullText
    this.ocrBlocks = ocrResult.blocks
    this.imageWidth = ocrResult.imageWidth
    this.imageHeight = ocrResult.imageHeight
    this.highlightMarks = []
    this.redrawHighlightCanvas()
  }

  private buildHighlightMarks(risks: CampusAIContractRisk[], blocks: OcrBlock[]): HighlightMark[] {
    const marks: HighlightMark[] = []
    for (let i = 0; i < risks.length; i++) {
      const risk = risks[i]
      const matched = this.findMatchedBlocks(risk, blocks)
      if (matched.length === 0) {
        continue
      }
      const merged = this.mergeMatchedBlocks(matched)
      if (this.hasExistingMark(marks, merged)) {
        continue
      }
      marks.push({
        left: merged.left,
        top: merged.top,
        width: merged.width,
        height: merged.height,
        severity: risk.severity,
        title: risk.title
      })
    }
    return this.compactHighlightMarks(marks)
  }

  private findMatchedBlocks(risk: CampusAIContractRisk, blocks: OcrBlock[]): OcrBlock[] {
    const clause = (risk.matchedClause || '').trim()
    const clauseTokens = this.extractKeywords(clause)
    const titleTokens = clauseTokens.length > 0 ? [] : this.extractKeywords(risk.title || '')
    const normalizedClause = this.normalizeCompareText(clause)
    const candidates: BlockMatchCandidate[] = []

    for (let i = 0; i < blocks.length; i++) {
      const block = blocks[i]
      const text = (block.text || '').trim()
      if (!text) {
        continue
      }
      const score = this.computeMatchScore(text, normalizedClause, clauseTokens, titleTokens)
      if (score <= 0) {
        continue
      }
      candidates.push({ block: block, score: score })
    }

    candidates.sort((left: BlockMatchCandidate, right: BlockMatchCandidate) => right.score - left.score)
    if (candidates.length === 0) {
      return []
    }
    if (candidates.length > 1) {
      const lead = candidates[0]
      const runnerUp = candidates[1]
      if (lead.score - runnerUp.score < 4) {
        return []
      }
    }
    return [candidates[0].block]
  }

  private extractKeywords(text: string): string[] {
    const normalized = text
      .replace(/[，。、“”‘’；：,.!?\-_/()（）【】\[\]\s]/g, ' ')
      .split(' ')
    const result: string[] = []
    for (let i = 0; i < normalized.length; i++) {
      const token = normalized[i].trim()
      if (token.length >= 2 && result.indexOf(token) < 0) {
        result.push(token)
      }
    }
    return result
  }

  private hitByTokens(text: string, tokens: string[]): boolean {
    for (let i = 0; i < tokens.length; i++) {
      if (tokens[i] && text.includes(tokens[i])) {
        return true
      }
    }
    return false
  }

  private normalizeCompareText(text: string): string {
    return text
      .replace(/[锛屻€傘€佲€溾€濃€樷€欙紱锛?.!?\-_/()锛堬級銆愩€慭[\]\s]/g, '')
      .trim()
  }

  private computeMatchScore(text: string, normalizedClause: string, clauseTokens: string[], titleTokens: string[]): number {
    const normalizedText = this.normalizeCompareText(text)
    if (normalizedText.length < 4) {
      return 0
    }

    let score = 0
    if (normalizedClause.length >= 6) {
      if (normalizedClause.includes(normalizedText)) {
        score = Math.max(score, normalizedText.length + 8)
      } else if (normalizedText.includes(normalizedClause)) {
        score = Math.max(score, normalizedClause.length + 6)
      }
    }

    const clauseTokenScore = this.tokenScore(text, clauseTokens)
    const titleTokenScore = clauseTokens.length > 0 ? 0 : this.tokenScore(text, titleTokens)
    score += clauseTokenScore
    score += titleTokenScore

    if (clauseTokens.length > 0 && clauseTokenScore < 6 && score < 12) {
      return 0
    }
    if (score < 10) {
      return 0
    }
    return score
  }

  private tokenScore(text: string, tokens: string[]): number {
    let score = 0
    let hitCount = 0
    for (let i = 0; i < tokens.length; i++) {
      const token = tokens[i]
      if (!token || token.length < 4) {
        continue
      }
      if (text.includes(token)) {
        score += token.length
        hitCount += 1
      }
    }
    if (hitCount >= 2) {
      score += 4
    }
    return score
  }

  private isNearBlock(left: OcrBlock, right: OcrBlock): boolean {
    const verticalGap = Math.abs((left.top + left.height / 2) - (right.top + right.height / 2))
    const horizontalGap = Math.abs(left.left - right.left)
    return verticalGap < 28 && horizontalGap < 80
  }

  private compactHighlightMarks(marks: HighlightMark[]): HighlightMark[] {
    const compacted: HighlightMark[] = []
    for (let i = 0; i < marks.length; i++) {
      const current = marks[i]
      let merged = false
      for (let j = 0; j < compacted.length; j++) {
        if (this.isOverlappingMark(compacted[j], current)) {
          compacted[j] = this.mergeHighlightMarks(compacted[j], current)
          merged = true
          break
        }
      }
      if (!merged) {
        compacted.push(current)
      }
    }
    return compacted
  }

  private isOverlappingMark(left: HighlightMark, right: HighlightMark): boolean {
    const leftRight = left.left + left.width
    const rightRight = right.left + right.width
    const leftBottom = left.top + left.height
    const rightBottom = right.top + right.height
    const overlapWidth = Math.min(leftRight, rightRight) - Math.max(left.left, right.left)
    const overlapHeight = Math.min(leftBottom, rightBottom) - Math.max(left.top, right.top)
    return overlapWidth > 12 && overlapHeight > 8
  }

  private mergeHighlightMarks(left: HighlightMark, right: HighlightMark): HighlightMark {
    const minLeft = Math.min(left.left, right.left)
    const minTop = Math.min(left.top, right.top)
    const maxRight = Math.max(left.left + left.width, right.left + right.width)
    const maxBottom = Math.max(left.top + left.height, right.top + right.height)
    return {
      left: minLeft,
      top: minTop,
      width: maxRight - minLeft,
      height: maxBottom - minTop,
      severity: left.severity === 'high' || right.severity === 'high' ? 'high' : left.severity,
      title: left.title
    }
  }

  private mergeMatchedBlocks(blocks: OcrBlock[]): OcrBlock {
    let minLeft = blocks[0].left
    let minTop = blocks[0].top
    let maxRight = blocks[0].left + blocks[0].width
    let maxBottom = blocks[0].top + blocks[0].height
    for (let i = 1; i < blocks.length; i++) {
      const block = blocks[i]
      minLeft = Math.min(minLeft, block.left)
      minTop = Math.min(minTop, block.top)
      maxRight = Math.max(maxRight, block.left + block.width)
      maxBottom = Math.max(maxBottom, block.top + block.height)
    }
    return {
      text: '',
      left: minLeft,
      top: minTop,
      width: maxRight - minLeft,
      height: maxBottom - minTop
    }
  }

  private hasExistingMark(existing: HighlightMark[], block: OcrBlock): boolean {
    for (let i = 0; i < existing.length; i++) {
      const mark = existing[i]
      if (Math.abs(mark.left - block.left) < 6 &&
        Math.abs(mark.top - block.top) < 6 &&
        Math.abs(mark.width - block.width) < 6 &&
        Math.abs(mark.height - block.height) < 6) {
        return true
      }
    }
    return false
  }

  private redrawHighlightCanvas(): void {
    setTimeout(() => {
      this.clearCanvas()
      if (!this.imageUri || this.highlightMarks.length === 0 || this.imageWidth <= 0 || this.imageHeight <= 0) {
        return
      }
      const ctx = this.canvasContext
      const layout = this.computeImageLayout()
      for (let i = 0; i < this.highlightMarks.length; i++) {
        const mark = this.highlightMarks[i]
        const left = layout.offsetX + mark.left * layout.scale
        const top = layout.offsetY + mark.top * layout.scale
        const width = Math.max(mark.width * layout.scale, 24)
        const height = Math.max(mark.height * layout.scale, 18)
        ctx.beginPath()
        ctx.strokeStyle = this.highlightColor(mark.severity)
        ctx.lineWidth = mark.severity === 'high' ? 3 : 2
        ctx.ellipse(left + width / 2, top + height / 2, width / 2 + 10, height / 2 + 8, 0, 0, Math.PI * 2)
        ctx.stroke()
      }
    }, 60)
  }

  private clearCanvas(): void {
    this.canvasContext.clearRect(0, 0, this.previewWidth, this.previewHeight)
  }

  private createImageLayoutInfo(scale: number, offsetX: number, offsetY: number): ImageLayoutInfo {
    return { scale: scale, offsetX: offsetX, offsetY: offsetY }
  }

  private computeImageLayout(): ImageLayoutInfo {
    if (this.imageWidth <= 0 || this.imageHeight <= 0) {
      return this.createImageLayoutInfo(1, 0, 0)
    }
    const scaleX = this.previewWidth / this.imageWidth
    const scaleY = this.previewHeight / this.imageHeight
    const scale = Math.min(scaleX, scaleY)
    const renderWidth = this.imageWidth * scale
    const renderHeight = this.imageHeight * scale
    return this.createImageLayoutInfo(
      scale,
      (this.previewWidth - renderWidth) / 2,
      (this.previewHeight - renderHeight) / 2
    )
  }

  private highlightColor(severity: string): string {
    if (severity === 'high') {
      return '#FF3B30'
    }
    if (severity === 'medium') {
      return '#FF6B35'
    }
    return '#FF6B35'
  }

  severityColor(severity: string): string {
    if (severity === 'high') {
      return AppConstants.COLOR_DANGER
    }
    if (severity === 'medium') {
      return AppConstants.COLOR_WARNING
    }
    return AppConstants.COLOR_SUCCESS
  }

  severityText(severity: string): string {
    if (severity === 'high') {
      return '高风险'
    }
    if (severity === 'medium') {
      return '中风险'
    }
    return '低风险'
  }

  levelText(level: string): string {
    if (level === 'danger') {
      return '整体风险较高'
    }
    if (level === 'warning') {
      return '存在需核对条款'
    }
    if (level === 'safe') {
      return '整体较安全'
    }
    return '等待审查'
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

        Text('三方协议 AI 审查')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)

        Button(this.isScanning ? '审查中' : '审查')
          .fontSize(14)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .fontColor('#FFFFFF')
          .borderRadius(18)
          .padding({ left: 14, right: 14, top: 6, bottom: 6 })
          .enabled(!this.isScanning)
          .onClick(() => this.reviewCurrentText())
      }
      .width('100%')
      .padding({ left: 8, right: 16, top: 52, bottom: 10 })
      .backgroundColor('#FFFFFF')

      Scroll() {
        Column() {
          Column() {
            Text('拍照上传合同，自动识别风险条款')
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
              .alignSelf(ItemAlign.Start)
            Text('适合三方协议、实习协议、兼职合同。AI 会重点检查保证金、违约金、社保、竞业限制等风险，并在原图上用红圈标出可疑条款。')
              .fontSize(13)
              .fontColor('#667085')
              .lineHeight(22)
              .margin({ top: 8 })
          }
          .width('100%')
          .padding(18)
          .backgroundColor('#FFF8F0')
          .borderRadius(18)

          Row() {
            Button(this.isScanning ? '识别中...' : '选择合同图片')
              .layoutWeight(1)
              .height(42)
              .fontSize(14)
              .backgroundColor(AppConstants.COLOR_PRIMARY)
              .fontColor('#FFFFFF')
              .borderRadius(21)
              .enabled(!this.isScanning)
              .onClick(() => this.pickAndAnalyzeImage())
            Button('使用示例')
              .layoutWeight(1)
              .height(42)
              .fontSize(14)
              .backgroundColor('#F5F5F5')
              .fontColor('#666666')
              .borderRadius(21)
              .margin({ left: 10 })
              .enabled(!this.isScanning)
              .onClick(() => this.useExampleAndReview())
          }
          .width('100%')
          .margin({ top: 14 })

          if (this.imageUri) {
            Column() {
              Text('原图风险标记')
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1A1A1A')
                .alignSelf(ItemAlign.Start)
              Text(this.highlightMarks.length > 0 ? '已按 OCR 文字块位置圈出可疑条款。' : '识别后会在图上用红圈标出可疑条款。')
                .fontSize(12)
                .fontColor('#667085')
                .margin({ top: 6, bottom: 10 })
                .alignSelf(ItemAlign.Start)

              Stack({ alignContent: Alignment.TopStart }) {
                Image(this.imageUri)
                  .width(this.previewWidth)
                  .height(this.previewHeight)
                  .objectFit(ImageFit.Contain)
                  .borderRadius(14)
                  .backgroundColor('#FFFFFF')
                Canvas(this.canvasContext)
                  .width(this.previewWidth)
                  .height(this.previewHeight)
              }
              .width(this.previewWidth)
              .height(this.previewHeight)
              .backgroundColor('#FFFFFF')
              .borderRadius(14)
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#FFFFFF')
            .borderRadius(16)
            .margin({ top: 14 })
          }

          Column() {
            Row() {
              Text('审查结果')
                .fontSize(16)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1A1A1A')
              Blank()
              Text(this.levelText(this.riskLevel))
                .fontSize(12)
                .fontColor(this.riskLevel === 'danger' ? AppConstants.COLOR_DANGER : this.riskLevel === 'safe' ? AppConstants.COLOR_SUCCESS : AppConstants.COLOR_WARNING)
                .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                .backgroundColor('#FFFDF2')
                .borderRadius(12)
            }
            .width('100%')

            Text(this.summary || '上传合同或粘贴文本后，AI 审查摘要会显示在这里。')
              .fontSize(13)
              .fontColor('#667085')
              .lineHeight(22)
              .width('100%')
              .margin({ top: 10 })

            if (this.risks.length === 0) {
              Text('暂无风险卡片')
                .fontSize(13)
                .fontColor('#999999')
                .width('100%')
                .textAlign(TextAlign.Center)
                .padding(18)
                .margin({ top: 12 })
                .backgroundColor('#F7F8FA')
                .borderRadius(12)
            } else {
              ForEach(this.risks, (risk: CampusAIContractRisk) => {
                this.RiskCard(risk)
              })
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(16)
          .margin({ top: 14 })

          TextArea({ text: this.contractText, placeholder: 'OCR 识别出的合同文本会出现在这里，你也可以手动粘贴或修改后重新审查。' })
            .width('100%')
            .height(220)
            .fontSize(13)
            .backgroundColor('#FFFFFF')
            .borderRadius(14)
            .padding(12)
            .margin({ top: 14, bottom: 24 })
            .onChange((value: string) => { this.contractText = value })
        }
        .padding({ left: 16, right: 16, top: 14 })
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')
  }

  @Builder
  RiskCard(risk: CampusAIContractRisk) {
    Column() {
      Row() {
        Text(this.severityText(risk.severity))
          .fontSize(11)
          .fontColor('#FFFFFF')
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor(this.severityColor(risk.severity))
          .borderRadius(10)
        Text(risk.title || '风险条款')
          .fontSize(14)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .margin({ left: 8 })
          .layoutWeight(1)
      }
      .width('100%')

      Text(risk.description || '请人工复核该条款。')
        .fontSize(13)
        .fontColor('#444444')
        .lineHeight(21)
        .width('100%')
        .margin({ top: 10 })

      if (risk.matchedClause) {
        Text('原文：' + risk.matchedClause)
          .fontSize(12)
          .fontColor('#8A6D1F')
          .lineHeight(20)
          .width('100%')
          .padding(10)
          .backgroundColor('#FFF7D8')
          .borderRadius(10)
          .margin({ top: 10 })
      }

      if (risk.negotiationScript) {
        Text('谈判话术：' + risk.negotiationScript)
          .fontSize(12)
          .fontColor('#2E8B57')
          .lineHeight(20)
          .width('100%')
          .padding(10)
          .backgroundColor('#F0FAF4')
          .borderRadius(10)
          .margin({ top: 10 })
      }
    }
    .width('100%')
    .padding(14)
    .backgroundColor('#FCFCFC')
    .borderRadius(14)
    .margin({ top: 12 })
    .border({ width: 1, color: '#F0F0F0' })
  }
}

export { ContractReviewPage }
