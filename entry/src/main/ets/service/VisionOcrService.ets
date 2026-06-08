import { fileIo } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'
import { DocumentParseService, ImageOcrBlock as DetailBlock } from './DocumentParseService'
import { LocalFileService } from './LocalFileService'

export interface OcrBlock {
  text: string
  left: number
  top: number
  width: number
  height: number
}

export interface OcrResult {
  fullText: string
  blocks: OcrBlock[]
  imageWidth: number
  imageHeight: number
}

export class VisionOcrService {
  static async recognizeImage(uri: string): Promise<OcrResult> {
    let width: number = 0
    let height: number = 0
    let file: fileIo.File | undefined = undefined

    try {
      file = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY)
      const source = image.createImageSource(file.fd)
      const imageInfo = await source.getImageInfo()
      width = Number(imageInfo.size.width || 0)
      height = Number(imageInfo.size.height || 0)
    } catch (_error) {
      throw new Error('图片已选中，但当前设备无法读取图片内容，请重新选择一张清晰的截图。')
    } finally {
      if (file) {
        try {
          fileIo.closeSync(file)
        } catch (_closeError) {
        }
      }
    }

    const base64 = await LocalFileService.readBase64(uri)
    const detail = await DocumentParseService.extractImageDetail(base64)
    const fullText = (detail.text || '').trim()
    if (!fullText) {
      throw new Error('OCR 未识别到可用文字，请换一张更清晰、对比度更高的图片后重试。')
    }

    const blocks: OcrBlock[] = []
    for (let i = 0; i < detail.blocks.length; i++) {
      const item: DetailBlock = detail.blocks[i]
      blocks.push({
        text: item.text || '',
        left: Number(item.left || 0),
        top: Number(item.top || 0),
        width: Number(item.width || 0),
        height: Number(item.height || 0)
      })
    }

    return {
      fullText: fullText,
      blocks: blocks,
      imageWidth: width,
      imageHeight: height
    }
  }
}
