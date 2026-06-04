import { hilog } from '@kit.PerformanceAnalysisKit'
import { ApiResult, HttpService, SendVerifyCodeApiData, VerifyCodeApiData } from './HttpService'
import { VerifyCodeDao } from './VerifyCodeDao'

const TAG = 'SmsService'

export interface SmsStatusInfo {
  provider: string
  ready: boolean
  aliyunConfigured: boolean
  expireMinutes: number
  message: string
}

export interface SmsActionResult {
  success: boolean
  message: string
}

export class SmsService {
  private verifyCodeDao: VerifyCodeDao = new VerifyCodeDao()

  async sendVerifyCode(phone: string): Promise<SmsActionResult> {
    if (phone.length !== 11) {
      return {
        success: false,
        message: 'Please enter a valid phone number'
      }
    }
    const result: ApiResult<SendVerifyCodeApiData> = await HttpService.sendVerifyCode(phone)
    if (result.code === -1) {
      const localCode: string = this.generateLocalCode()
      await this.verifyCodeDao.saveCode(phone, localCode, 5)
      hilog.warn(0x0000, TAG, 'backend unavailable, use local dev code for %{public}s: %{public}s', phone, localCode)
      return {
        success: true,
        message: `Backend unavailable, using local dev code: ${localCode}`
      }
    }
    if (result.code !== 200) {
      hilog.error(0x0000, TAG, 'sms send failed: %{public}s', result.message)
      return {
        success: false,
        message: result.message || 'Send failed, please retry later'
      }
    }

    const data: SendVerifyCodeApiData | undefined = result.data
    if (data && data.provider === 'mock' && data.debugCode) {
      hilog.warn(0x0000, TAG, 'mock sms code for %{public}s: %{public}s', phone, data.debugCode)
      return {
        success: true,
        message: `Verification code generated in mock mode: ${data.debugCode}`
      }
    }

    hilog.info(0x0000, TAG, 'sms sent to %{public}s', phone)
    return {
      success: true,
      message: 'Verification code sent'
    }
  }

  async verifyCode(phone: string, code: string): Promise<SmsActionResult> {
    const result: ApiResult<VerifyCodeApiData> = await HttpService.verifyCode(phone, code)
    if (result.code === -1) {
      const ok: boolean = await this.verifyCodeDao.verifyCode(phone, code)
      if (ok) {
        await this.verifyCodeDao.deleteCode(phone)
        return {
          success: true,
          message: 'Local development code verified'
        }
      }
      return {
        success: false,
        message: 'Local development code is wrong or expired'
      }
    }
    if (result.code === 200) {
      hilog.info(0x0000, TAG, 'code verified successfully for %{public}s', phone)
      return {
        success: true,
        message: 'Verification successful'
      }
    }
    hilog.error(0x0000, TAG, 'code verify failed: %{public}s', result.message)
    return {
      success: false,
      message: result.message || 'Verification code is wrong or expired'
    }
  }

  async getStatus(): Promise<SmsStatusInfo | null> {
    const result: ApiResult<SmsStatusInfo> = await HttpService.get<SmsStatusInfo>('/sms/status')
    return result.code === 200 && result.data ? result.data : null
  }

  private generateLocalCode(): string {
    return `${Math.floor(Math.random() * 900000) + 100000}`
  }
}
