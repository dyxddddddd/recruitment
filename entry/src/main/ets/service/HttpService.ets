import { http } from '@kit.NetworkKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { AppConstants } from '../common/constants/AppConstants'

const TAG = 'HttpService'

export interface ApiResult<T> {
  code: number
  message: string
  data?: T
}

export interface SendVerifyCodeApiData {
  provider?: string
  debugCode?: string
}

export interface VerifyCodeApiData {
  token: string
}

interface SendVerifyCodeRequest {
  phone: string
}

interface VerifyCodeRequest {
  phone: string
  code: string
}

export class HttpService {
  private static baseUrl: string = `${AppConstants.BACKEND_BASE_URL}/api`

  static setBaseUrl(url: string): void {
    HttpService.baseUrl = url
  }

  static async get<T>(path: string): Promise<ApiResult<T>> {
    return HttpService.request<T>(`${HttpService.baseUrl}${path}`, http.RequestMethod.GET)
  }

  static async post<T>(path: string, body?: Object): Promise<ApiResult<T>> {
    return HttpService.request<T>(`${HttpService.baseUrl}${path}`, http.RequestMethod.POST, body)
  }

  static async request<T>(url: string, method: http.RequestMethod, body?: Object): Promise<ApiResult<T>> {
    const request = http.createHttp()
    try {
      const response = await request.request(url, {
        method: method,
        header: {
          'Content-Type': 'application/json'
        },
        extraData: body ? JSON.stringify(body) : undefined,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 45000
      })
      const raw: string = typeof response.result === 'string'
        ? response.result
        : JSON.stringify(response.result)
      return JSON.parse(raw) as ApiResult<T>
    } catch (error) {
      hilog.error(0x0000, TAG, 'request error: %{public}s', JSON.stringify(error))
      const failed: ApiResult<T> = {
        code: -1,
        message: 'Network request failed'
      }
      return failed
    } finally {
      request.destroy()
    }
  }

  static async sendVerifyCode(phone: string): Promise<ApiResult<SendVerifyCodeApiData>> {
    const body: SendVerifyCodeRequest = {
      phone: phone
    }
    return HttpService.post<SendVerifyCodeApiData>('/sms/send', body)
  }

  static async verifyCode(phone: string, code: string): Promise<ApiResult<VerifyCodeApiData>> {
    const body: VerifyCodeRequest = {
      phone: phone,
      code: code
    }
    return HttpService.post<VerifyCodeApiData>('/sms/verify', body)
  }
}
