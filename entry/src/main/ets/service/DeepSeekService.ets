import { http } from '@kit.NetworkKit'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { AppConstants } from '../common/constants/AppConstants'

const TAG = 'DeepSeekService'

interface DeepSeekResponseMessage {
  content?: string
}

interface DeepSeekChoice {
  message?: DeepSeekResponseMessage
}

interface DeepSeekErrorInfo {
  message?: string
}

interface DeepSeekResponse {
  choices?: DeepSeekChoice[]
  error?: DeepSeekErrorInfo
}

interface DeepSeekRequestMessage {
  role: string
  content: string
}

interface DeepSeekResponseFormat {
  type: string
}

interface DeepSeekRequestBody {
  model: string
  messages: DeepSeekRequestMessage[]
  temperature: number
  response_format?: DeepSeekResponseFormat
}

export class DeepSeekService {
  static isConfigured(): boolean {
    return AppConstants.DEEPSEEK_API_KEY.trim().length > 0
  }

  static getConfigErrorMessage(): string {
    return 'Please fill AppConstants.DEEPSEEK_API_KEY first'
  }

  static async chatText(systemPrompt: string, userPrompt: string): Promise<string> {
    const body: DeepSeekRequestBody = {
      model: AppConstants.DEEPSEEK_MODEL,
      messages: DeepSeekService.buildMessages(systemPrompt, userPrompt),
      temperature: 0.3
    }
    const response: DeepSeekResponse = await DeepSeekService.request(body)
    return DeepSeekService.extractContent(response)
  }

  static async chatJson<T>(systemPrompt: string, userPrompt: string): Promise<T> {
    const body: DeepSeekRequestBody = {
      model: AppConstants.DEEPSEEK_MODEL,
      messages: DeepSeekService.buildMessages(systemPrompt, userPrompt),
      temperature: 0.2,
      response_format: {
        type: 'json_object'
      }
    }
    const response: DeepSeekResponse = await DeepSeekService.request(body)
    const content: string = DeepSeekService.extractContent(response)
    const normalized: string = DeepSeekService.stripCodeFence(content)
    return JSON.parse(normalized) as T
  }

  private static buildMessages(systemPrompt: string, userPrompt: string): DeepSeekRequestMessage[] {
    return [
      {
        role: 'system',
        content: systemPrompt
      },
      {
        role: 'user',
        content: userPrompt
      }
    ]
  }

  private static async request(body: DeepSeekRequestBody): Promise<DeepSeekResponse> {
    if (!DeepSeekService.isConfigured()) {
      throw new Error(DeepSeekService.getConfigErrorMessage())
    }
    const request = http.createHttp()
    try {
      const response = await request.request(`${AppConstants.DEEPSEEK_BASE_URL}/chat/completions`, {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${AppConstants.DEEPSEEK_API_KEY.trim()}`
        },
        extraData: JSON.stringify(body),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 45000
      })
      const raw: string = typeof response.result === 'string'
        ? response.result
        : JSON.stringify(response.result)
      return JSON.parse(raw) as DeepSeekResponse
    } catch (error) {
      hilog.error(0x0000, TAG, 'deepseek request failed: %{public}s', JSON.stringify(error))
      throw new Error('DeepSeek request failed, please check network, model config, or API key')
    } finally {
      request.destroy()
    }
  }

  private static extractContent(response: DeepSeekResponse): string {
    if (response.error && response.error.message) {
      throw new Error(response.error.message)
    }
    const choices: DeepSeekChoice[] = response.choices || []
    if (choices.length === 0) {
      throw new Error('DeepSeek returned no content')
    }
    const message: DeepSeekResponseMessage | undefined = choices[0].message
    const content: string = message && message.content ? message.content.trim() : ''
    if (!content) {
      throw new Error('DeepSeek returned no usable content')
    }
    return content
  }

  private static stripCodeFence(text: string): string {
    const trimmed: string = text.trim()
    if (!trimmed.startsWith('```')) {
      return trimmed
    }
    return trimmed
      .replace(/^```json\s*/i, '')
      .replace(/^```\s*/i, '')
      .replace(/\s*```$/, '')
      .trim()
  }
}
