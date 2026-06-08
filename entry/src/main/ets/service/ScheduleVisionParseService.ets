import { FreeTimeSlot } from '../model/ResumeModel'
import { HttpService } from './HttpService'
import { LocalFileService } from './LocalFileService'

interface ScheduleImageParseRequest {
  imageDataUrl: string
}

interface ScheduleCourseItem {
  dayOfWeek: number
  courseName: string
  location: string
  teacher: string
  startTime: string
  endTime: string
}

export interface ScheduleVisionParseResult {
  summary: string
  recognizedText: string
  freeSlots: FreeTimeSlot[]
  courses: ScheduleCourseItem[]
}

export class ScheduleVisionParseService {
  static async analyzeScheduleImage(uri: string): Promise<ScheduleVisionParseResult> {
    const base64 = await LocalFileService.readBase64(uri)
    const requestBody: ScheduleImageParseRequest = {
      imageDataUrl: ScheduleVisionParseService.buildImageDataUrl(uri, base64)
    }
    const result = await HttpService.post<ScheduleVisionParseResult>('/document/parse-schedule-image', requestBody)
    if (result.code !== 200 || !result.data) {
      throw new Error(result.message || '课表图片识别失败')
    }
    return {
      summary: result.data.summary || '',
      recognizedText: result.data.recognizedText || '',
      freeSlots: result.data.freeSlots || [],
      courses: result.data.courses || []
    }
  }

  private static buildImageDataUrl(uri: string, base64: string): string {
    const fileName = LocalFileService.decodeDisplayName(uri).toLowerCase()
    const mimeType = ScheduleVisionParseService.inferMimeType(fileName)
    return `data:${mimeType};base64,${base64}`
  }

  private static inferMimeType(fileName: string): string {
    if (fileName.endsWith('.png')) {
      return 'image/png'
    }
    if (fileName.endsWith('.webp')) {
      return 'image/webp'
    }
    if (fileName.endsWith('.bmp')) {
      return 'image/bmp'
    }
    if (fileName.endsWith('.gif')) {
      return 'image/gif'
    }
    return 'image/jpeg'
  }
}
