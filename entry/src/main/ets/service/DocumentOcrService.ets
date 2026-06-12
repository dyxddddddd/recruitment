import { common } from '@kit.AbilityKit'
import { HttpService, ApiResult } from './HttpService'
import { LocalFileService } from './LocalFileService'

// ==================== 请求类型 ====================

interface RecognizeIdCardRequest {
  base64: string
  side: 'front' | 'back'
}

interface RecognizeBusinessLicenseRequest {
  base64: string
}

// ==================== 响应类型 ====================

export interface IdCardResult {
  side: string
  name?: string
  sex?: string
  ethnicity?: string
  birth?: string
  address?: string
  number?: string
  issue?: string
  validFrom?: string
  validTo?: string
}

export interface BusinessLicenseResult {
  regNumber?: string
  name?: string
  type?: string
  address?: string
  legalRepresentative?: string
  registeredCapital?: string
  establishedDate?: string
  businessTerm?: string
  businessScope?: string
}

// ==================== 服务 ====================

export class DocumentOcrService {
  static async recognizeIdCard(uri: string, side: 'front' | 'back', context?: common.UIAbilityContext): Promise<ApiResult<IdCardResult>> {
    let base64: string
    try {
      base64 = await LocalFileService.readBase64(uri, context)
    } catch (e) {
      return { code: -1, message: '无法读取照片文件，请重新选择' }
    }

    const body: RecognizeIdCardRequest = {
      base64: base64,
      side: side
    }
    const result = await HttpService.post<IdCardResult>('/document/recognize-id-card', body)
    if (result.code < 0) {
      return { code: -1, message: '无法连接识别服务，请确认后端已启动' }
    }
    return result
  }

  static async recognizeBusinessLicense(uri: string, context?: common.UIAbilityContext): Promise<ApiResult<BusinessLicenseResult>> {
    let base64: string
    try {
      base64 = await LocalFileService.readBase64(uri, context)
    } catch (e) {
      return { code: -1, message: '无法读取照片文件，请重新选择' }
    }

    const body: RecognizeBusinessLicenseRequest = {
      base64: base64
    }
    const result = await HttpService.post<BusinessLicenseResult>('/document/recognize-business-license', body)
    if (result.code < 0) {
      return { code: -1, message: '无法连接识别服务，请确认后端已启动' }
    }
    return result
  }
}
