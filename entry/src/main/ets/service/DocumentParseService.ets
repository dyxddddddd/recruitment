import { HttpService } from './HttpService'

interface PdfTextResponse {
  text: string
}

interface ExtractPdfRequest {
  base64: string
}

interface ImageOcrRequest {
  base64: string
}

interface ImageOcrBlockResponse {
  text: string
  left: number
  top: number
  width: number
  height: number
}

interface ImageOcrDetailResponse {
  text: string
  blocks: ImageOcrBlockResponse[]
}

export interface ImageOcrBlock {
  text: string
  left: number
  top: number
  width: number
  height: number
}

export interface ImageOcrDetailResult {
  text: string
  blocks: ImageOcrBlock[]
}

export class DocumentParseService {
  static async extractPdfText(base64: string): Promise<string> {
    const body: ExtractPdfRequest = {
      base64: base64
    }
    const result = await HttpService.post<PdfTextResponse>('/document/extract-pdf-text', body)
    if (result.code !== 200 || !result.data) {
      throw new Error(result.message || 'PDF parse failed')
    }
    return result.data.text || ''
  }

  static async extractImageText(base64: string): Promise<string> {
    const body: ImageOcrRequest = {
      base64: base64
    }
    const result = await HttpService.post<PdfTextResponse>('/document/ocr-text', body)
    if (result.code !== 200 || !result.data) {
      throw new Error(result.message || 'Image OCR failed')
    }
    return result.data.text || ''
  }

  static async extractImageDetail(base64: string): Promise<ImageOcrDetailResult> {
    const body: ImageOcrRequest = {
      base64: base64
    }
    const result = await HttpService.post<ImageOcrDetailResponse>('/document/ocr-detail', body)
    if (result.code !== 200 || !result.data) {
      throw new Error(result.message || 'Image OCR detail failed')
    }
    return {
      text: result.data.text || '',
      blocks: result.data.blocks || []
    }
  }
}
