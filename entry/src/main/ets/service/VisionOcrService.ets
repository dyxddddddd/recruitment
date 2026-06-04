import { fileIo } from '@kit.CoreFileKit'
import { image } from '@kit.ImageKit'

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
    } catch (e) {
      throw new Error('当前图片已选中，但这台设备上的 SDK 仍无法完成 OCR 识别。你可以继续保留这张图，并在下方文本框手动粘贴课表内容后解析。')
    } finally {
      if (file) {
        try {
          fileIo.closeSync(file)
        } catch (closeError) {
        }
      }
    }

    throw new Error(`已成功读取课表图片（${width} x ${height}），但当前工程尚未接入可用的 OCR 引擎。请先在下方文本框粘贴课表文本后再解析。`)
  }
}
