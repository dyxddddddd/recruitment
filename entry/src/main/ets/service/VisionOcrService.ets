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
    const source = image.createImageSource(uri)
    const imageInfo = await source.getImageInfo()
    const width: number = Number(imageInfo.size.width || 1)
    const height: number = Number(imageInfo.size.height || 1)
    throw new Error(`Current SDK build does not expose a usable OCR API. Please manually paste the text after selecting the image. Image size: ${width} x ${height}`)
  }
}
