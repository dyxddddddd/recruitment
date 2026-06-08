import { common, Want } from '@kit.AbilityKit'
import {
  AuthReqOptions,
  AuthResult,
  AuthResultType,
  IQQOpenApi,
  OpenApiConfig,
  QQOpenApiFactory
} from '@tencent/qq-open-sdk'
import {
  BaseResp,
  ErrCode,
  SendAuthReq,
  SendAuthResp,
  WXAPIFactory,
  WXApi,
  WXApiEventHandler
} from '@tencent/wechat_open_sdk'
import { AppConstants } from '../common/constants/AppConstants'
import { HttpService } from './HttpService'

type SocialPlatform = 'wechat' | 'qq'

interface SocialExchangeApiData {
  platform: string
  openId: string
  nickname: string
  avatar: string
  accessToken: string
}

interface ExchangeAuthCodeRequest {
  authCode: string
}

class PendingWechatLogin {
  state: string
  resolve: (result: ThirdPartyAuthResult) => void
  reject: (error: Error) => void

  constructor(state: string, resolve: (result: ThirdPartyAuthResult) => void, reject: (error: Error) => void) {
    this.state = state
    this.resolve = resolve
    this.reject = reject
  }
}

class WechatEventHandler implements WXApiEventHandler {
  onReq(_req: SendAuthReq): void {
  }

  onResp(resp: BaseResp): void {
    void ThirdPartyAuthService.resolveWechatResponse(resp)
  }
}

export interface ThirdPartyAuthResult {
  success: boolean
  platform: string
  openId: string
  nickname: string
  avatar: string
  authCode: string
}

export class ThirdPartyAuthService {
  private static qqApi: IQQOpenApi | null = null
  private static wxApi: WXApi | null = null
  private static pendingWechatLogin: PendingWechatLogin | null = null
  private static readonly wechatEventHandler: WechatEventHandler = new WechatEventHandler()

  async authorize(platform: string, context: common.UIAbilityContext): Promise<ThirdPartyAuthResult> {
    if (platform === 'wechat') {
      return this.authorizeWechat(context)
    }
    if (platform === 'qq') {
      return this.authorizeQq()
    }
    throw new Error('暂不支持该第三方登录方式')
  }

  static handleIncomingWant(want: Want): void {
    ThirdPartyAuthService.handleWechatWant(want)
    ThirdPartyAuthService.handleQqWant(want)
  }

  private async authorizeQq(): Promise<ThirdPartyAuthResult> {
    const appIdText = AppConstants.QQ_APP_ID.trim()
    if (!appIdText) {
      throw new Error('请先在 AppConstants.ets 中填写 QQ_APP_ID')
    }

    const appId = Number(appIdText)
    if (!Number.isFinite(appId) || appId <= 0) {
      throw new Error('QQ_APP_ID 必须是有效的数字字符串')
    }

    const api = ThirdPartyAuthService.getQqApi(appId)
    const options = new AuthReqOptions()
    options.scope = AppConstants.QQ_LOGIN_SCOPE
    options.forceWebLogin = !api.isQQInstalled()
    options.useQrCode = !api.isQQInstalled()
    options.networkTimeout = 10000

    const authResult = await api.login(options)
    if (authResult.type === AuthResultType.Cancel) {
      throw new Error('已取消 QQ 登录')
    }
    if (authResult.type !== AuthResultType.Success || !authResult.authResponse || !authResult.authResponse.authCode) {
      throw new Error(authResult.message || authResult.detail || 'QQ 登录失败')
    }

    return this.exchangeProfile('qq', authResult.authResponse.authCode)
  }

  private async authorizeWechat(context: common.UIAbilityContext): Promise<ThirdPartyAuthResult> {
    const appId = AppConstants.WECHAT_APP_ID.trim()
    if (!appId) {
      throw new Error('请先在 AppConstants.ets 中填写 WECHAT_APP_ID')
    }

    const wxApi = ThirdPartyAuthService.getWxApi()
    if (!wxApi.isWXAppInstalled()) {
      throw new Error('当前设备未安装微信，微信登录需要在装有微信的真机上测试')
    }

    const state = `wx_${Date.now()}`
    const request = new SendAuthReq()
    request.scope = AppConstants.WECHAT_LOGIN_SCOPE
    request.state = state
    request.callbackAbility = AppConstants.ENTRY_ABILITY_NAME

    const loginPromise = new Promise<ThirdPartyAuthResult>((resolve, reject) => {
      if (ThirdPartyAuthService.pendingWechatLogin) {
        ThirdPartyAuthService.pendingWechatLogin.reject(new Error('上一条微信登录请求尚未完成'))
      }
      ThirdPartyAuthService.pendingWechatLogin = new PendingWechatLogin(state, resolve, reject)
    })

    const sent = await Promise.resolve(wxApi.sendReq(context, request))
    if (!sent) {
      ThirdPartyAuthService.pendingWechatLogin = null
      throw new Error('微信授权请求发送失败，请检查 AppID、签名和开放平台配置')
    }

    return loginPromise
  }

  private async exchangeProfile(platform: SocialPlatform, authCode: string): Promise<ThirdPartyAuthResult> {
    const body: ExchangeAuthCodeRequest = {
      authCode: authCode
    }
    const result = await HttpService.post<SocialExchangeApiData>(`/auth/${platform}/exchange`, body)
    if (result.code !== 200 || !result.data) {
      throw new Error(result.message || `${platform} 登录失败`)
    }

    const nickname = result.data.nickname || (platform === 'wechat' ? '微信用户' : 'QQ用户')
    return {
      success: true,
      platform: platform,
      openId: result.data.openId,
      nickname: nickname,
      avatar: result.data.avatar || '',
      authCode: authCode
    }
  }

  private static getQqApi(appId: number): IQQOpenApi {
    if (!ThirdPartyAuthService.qqApi) {
      const config = new OpenApiConfig()
      config.forceEnableWeb = false
      config.disableDisallowLaunchCheck = false
      ThirdPartyAuthService.qqApi = QQOpenApiFactory.createApi(appId, config)
    }
    return ThirdPartyAuthService.qqApi
  }

  private static getWxApi(): WXApi {
    if (!ThirdPartyAuthService.wxApi) {
      ThirdPartyAuthService.wxApi = WXAPIFactory.createWXAPI(AppConstants.WECHAT_APP_ID.trim())
    }
    return ThirdPartyAuthService.wxApi
  }

  private static handleQqWant(want: Want): void {
    if (!ThirdPartyAuthService.qqApi) {
      const appIdText = AppConstants.QQ_APP_ID.trim()
      const appId = Number(appIdText)
      if (Number.isFinite(appId) && appId > 0) {
        ThirdPartyAuthService.qqApi = ThirdPartyAuthService.getQqApi(appId)
      }
    }
    if (!ThirdPartyAuthService.qqApi) {
      return
    }

    const routeParams = want.parameters ? want.parameters as Object : want as Object
    ThirdPartyAuthService.qqApi.handleResult(routeParams)
  }

  private static handleWechatWant(want: Want): void {
    if (!ThirdPartyAuthService.wxApi && AppConstants.WECHAT_APP_ID.trim()) {
      ThirdPartyAuthService.wxApi = ThirdPartyAuthService.getWxApi()
    }
    if (!ThirdPartyAuthService.wxApi) {
      return
    }

    ThirdPartyAuthService.wxApi.handleWant(want, ThirdPartyAuthService.wechatEventHandler)
  }

  static async resolveWechatResponse(resp: BaseResp): Promise<void> {
    const pending = ThirdPartyAuthService.pendingWechatLogin
    if (!pending) {
      return
    }

    const authResp = resp as SendAuthResp
    if (resp.errCode === ErrCode.ERR_USER_CANCEL) {
      ThirdPartyAuthService.pendingWechatLogin = null
      pending.reject(new Error('已取消微信登录'))
      return
    }
    if (resp.errCode !== ErrCode.ERR_OK) {
      ThirdPartyAuthService.pendingWechatLogin = null
      pending.reject(new Error(resp.errStr || '微信登录失败'))
      return
    }
    if (!authResp.code) {
      ThirdPartyAuthService.pendingWechatLogin = null
      pending.reject(new Error('微信登录未返回授权码'))
      return
    }
    if (authResp.state && authResp.state !== pending.state) {
      ThirdPartyAuthService.pendingWechatLogin = null
      pending.reject(new Error('微信登录状态校验失败，请重试'))
      return
    }

    try {
      const service = new ThirdPartyAuthService()
      const result = await service.exchangeProfile('wechat', authResp.code)
      ThirdPartyAuthService.pendingWechatLogin = null
      pending.resolve(result)
    } catch (error) {
      ThirdPartyAuthService.pendingWechatLogin = null
      pending.reject(error instanceof Error ? error : new Error('微信登录失败'))
    }
  }
}
