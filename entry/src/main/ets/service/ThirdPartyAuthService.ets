export interface ThirdPartyAuthResult {
  success: boolean
  platform: string
  openId: string
  nickname: string
  avatar: string
  authCode: string
}

export class ThirdPartyAuthService {
  async authorize(platform: string): Promise<ThirdPartyAuthResult> {
    await new Promise<void>((resolve) => setTimeout(resolve, 800))
    const timestamp = Date.now()
    return {
      success: true,
      platform: platform,
      openId: `${platform}_openid_${timestamp}`,
      nickname: platform === 'wechat' ? '微信同学' : 'QQ同学',
      avatar: '',
      authCode: `${platform}_auth_${timestamp}`
    }
  }
}
