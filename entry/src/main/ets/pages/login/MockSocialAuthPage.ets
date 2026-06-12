import { router } from '@kit.ArkUI'
import { common } from '@kit.AbilityKit'
import { AppConstants } from '../../common/constants/AppConstants'
import { SocialMockProfile, ThirdPartyAuthResult, ThirdPartyAuthService } from '../../service/ThirdPartyAuthService'

interface MockSocialAuthRouteParams {
  platform?: string
}

@Entry
@Component
struct MockSocialAuthPage {
  @State platform: string = 'wechat'
  @State isAuthorizing: boolean = false

  private thirdPartyAuthService: ThirdPartyAuthService = new ThirdPartyAuthService()

  aboutToAppear(): void {
    const params = router.getParams() as MockSocialAuthRouteParams
    if (params && (params.platform === 'wechat' || params.platform === 'qq')) {
      this.platform = params.platform
    }
  }

  private getDisplayName(): string {
    return this.platform === 'wechat' ? '微信' : 'QQ'
  }

  private getProfile(): SocialMockProfile {
    return ThirdPartyAuthService.getMockProfile(this.platform)
  }

  private getAccentColor(): string {
    return this.platform === 'wechat' ? '#07C160' : '#12B7F5'
  }

  private getBrandText(): string {
    return '校招护航 申请使用'
  }

  private getTitleText(): string {
    return this.platform === 'wechat' ? '你的昵称、头像' : '你的QQ头像和昵称信息'
  }

  private getHintText(): string {
    return this.platform === 'wechat'
      ? '你可以选择不同的昵称、头像登录'
      : '你可以使用不同的头像/昵称登录'
  }

  private getTopActionText(): string {
    return this.platform === 'wechat' ? '关闭' : '取消'
  }

  private getPrimaryButtonText(): string {
    if (this.isAuthorizing) {
      return this.platform === 'wechat' ? '允许中...' : '同意中...'
    }
    return this.platform === 'wechat' ? '允许' : '同意'
  }

  private async confirmAuthorize(): Promise<void> {
    this.isAuthorizing = true
    try {
      const context = getContext(this) as common.UIAbilityContext
      const authResult: ThirdPartyAuthResult = await this.thirdPartyAuthService.authorize(this.platform, context)
      router.replaceUrl({
        url: AppConstants.ROUTE_BIND_PHONE,
        params: {
          platform: authResult.platform,
          openId: authResult.openId,
          nickname: authResult.nickname,
          avatar: authResult.avatar,
          authCode: authResult.authCode
        }
      })
    } catch (e) {
      this.isAuthorizing = false
      AlertDialog.show({
        message: e instanceof Error ? e.message : '授权失败，请重试'
      })
    }
  }

  @Builder
  BrandMark() {
    Row({ space: 12 }) {
      Stack() {
        Column()
          .width(40)
          .height(40)
          .linearGradient({
            angle: 135,
            colors: [['#2F80ED', 0], ['#4AA3FF', 0.52], ['#7BC6FF', 1]]
          })
          .borderRadius(10)

        Column()
          .width(24)
          .height(6)
          .backgroundColor('#FFFFFF26')
          .borderRadius(3)
          .position({ x: 8, y: 6 })

        Column()
          .width(18)
          .height(18)
          .backgroundColor('#FF8A3D')
          .borderRadius(9)
          .position({ x: 22, y: 20 })

        Text('校招')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor('#FFFFFF')
          .position({ x: 7, y: 15 })
      }
      .width(40)
      .height(40)

      Text(this.getBrandText())
        .fontSize(20)
        .fontColor('#202020')
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  PhotoAvatarCard() {
    Stack() {
      Image(this.platform === 'wechat' ? $r('app.media.wechat') : $r('app.media.qq'))
        .width(64)
        .height(64)
        .objectFit(ImageFit.Cover)
        .borderRadius(this.platform === 'wechat' ? 12 : 32)
        .draggable(false)
    }
    .width(64)
    .height(64)
    .clip(true)
  }

  @Builder
  HintRow() {
    Row() {
      if (this.platform === 'qq') {
        Text('◌')
          .fontSize(22)
          .fontColor('#B8B8B8')
          .margin({ right: 10 })
      }

      Text(this.getHintText())
        .layoutWeight(1)
        .fontSize(this.platform === 'wechat' ? 15 : 14)
        .fontColor('#B1B1B1')
        .textAlign(TextAlign.Start)

      if (this.platform === 'qq') {
        Text('创建')
          .fontSize(16)
          .fontColor('#2D7DDA')
      }
    }
    .width('100%')
    .padding({ top: this.platform === 'wechat' ? 0 : 10, bottom: 14 })
    .border({ width: { bottom: 1 }, color: '#F1F1F1' })
  }

  @Builder
  ProfileRow() {
    Row() {
      this.PhotoAvatarCard()

      Column({ space: 4 }) {
        Text(this.getProfile().nickname)
          .fontSize(this.platform === 'wechat' ? 18 : 17)
          .fontWeight(FontWeight.Medium)
          .fontColor('#202020')
          .width('100%')
          .textAlign(TextAlign.Start)

        Text(`${this.getDisplayName()}头像昵称`)
          .fontSize(13)
          .fontColor('#B0B0B0')
          .width('100%')
          .textAlign(TextAlign.Start)
      }
      .layoutWeight(1)
      .margin({ left: 16 })
      .alignItems(HorizontalAlign.Start)

      Text('✓')
        .fontSize(25)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.getAccentColor())
    }
    .width('100%')
    .padding({ top: 18, bottom: 18 })
    .border({
      width: {
        top: this.platform === 'wechat' ? 1 : 0,
        bottom: 1
      },
      color: '#F1F1F1'
    })
  }

  @Builder
  WechatExtraRow() {
    Row() {
      Text('+')
        .fontSize(24)
        .fontWeight(FontWeight.Lighter)
        .fontColor('#C8C8C8')
        .width(64)
        .height(56)
        .textAlign(TextAlign.Center)
        .padding({ top: 8 })

      Text('新建昵称头像')
        .layoutWeight(1)
        .margin({ left: 16 })
        .fontSize(17)
        .fontColor('#222222')
        .textAlign(TextAlign.Start)

      Text('›')
        .fontSize(26)
        .fontColor('#C8C8C8')
    }
    .width('100%')
    .padding({ top: 12, bottom: 12 })
    .border({ width: { bottom: 1 }, color: '#F1F1F1' })
  }

  @Builder
  BottomActions() {
    Column({ space: this.platform === 'wechat' ? 14 : 16 }) {
      Button(this.getPrimaryButtonText())
        .width(this.platform === 'wechat' ? '50%' : '46%')
        .height(this.platform === 'wechat' ? 58 : 60)
        .fontSize(this.platform === 'wechat' ? 20 : 18)
        .fontWeight(FontWeight.Medium)
        .fontColor('#FFFFFF')
        .backgroundColor(this.getAccentColor())
        .borderRadius(this.platform === 'wechat' ? 14 : 18)
        .enabled(!this.isAuthorizing)
        .onClick(() => this.confirmAuthorize())

      if (this.platform === 'wechat') {
        Button('拒绝')
          .width('50%')
          .height(58)
          .fontSize(20)
          .fontWeight(FontWeight.Medium)
          .fontColor('#4B5563')
          .backgroundColor('#F3F4F6')
          .borderRadius(14)
          .onClick(() => router.back())
      } else {
        Text('切换账号')
          .fontSize(17)
          .fontColor('#2E5FB6')
          .onClick(() => router.back())
      }
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ bottom: this.platform === 'wechat' ? 40 : 52 })
  }

  build() {
    Column() {
      Row() {
        if (this.platform === 'wechat') {
          Text(this.getTopActionText())
            .fontSize(24)
            .fontColor('#111111')
            .onClick(() => router.back())
          Blank()
        } else {
          Blank()
          Text(this.getTopActionText())
            .fontSize(22)
            .fontColor('#111111')
            .onClick(() => router.back())
        }
      }
      .width('100%')
      .padding({ left: 24, right: 24, top: 44, bottom: this.platform === 'wechat' ? 30 : 18 })

      Column({ space: this.platform === 'wechat' ? 24 : 22 }) {
        this.BrandMark()

        Text(this.getTitleText())
          .fontSize(this.platform === 'wechat' ? 30 : 28)
          .fontWeight(FontWeight.Bold)
          .fontColor('#151515')
          .width('100%')
          .textAlign(TextAlign.Start)
          .lineHeight(this.platform === 'wechat' ? 37 : 35)

        Column() {
          this.HintRow()
          this.ProfileRow()
          if (this.platform === 'wechat') {
            this.WechatExtraRow()
          }
        }
        .width('100%')
      }
      .width('100%')
      .padding({
        left: 24,
        right: 24,
        top: this.platform === 'wechat' ? 34 : 40
      })

      Blank()

      this.BottomActions()
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
