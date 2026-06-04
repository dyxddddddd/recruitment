import { HttpService } from './HttpService'

interface PdfTextResponse {
  text: string
}

interface ExtractPdfRequest {
  base64: string
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
}
