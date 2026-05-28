// 角色选择卡片组件

@Component
export struct RoleCard {
  @Prop title: string = ''
  @Prop description: string = ''
  @Prop emoji: string = ''
  @Prop bgColor: string = '#FFFFFF'
  @Prop cardBorderColor: string = '#E5E5E5'

  build() {
    Column() {
      Text(this.emoji)
        .fontSize(56)
        .margin({ bottom: 16 })
      Text(this.title)
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .margin({ bottom: 8 })
      Text(this.description)
        .fontSize(13)
        .fontColor('#999999')
        .textAlign(TextAlign.Center)
        .maxLines(2)
    }
    .width('100%')
    .height(180)
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
    .backgroundColor(this.bgColor)
    .borderRadius(16)
    .border({
      width: 2,
      color: this.cardBorderColor
    })
    .shadow({
      radius: 8,
      color: '#10000000',
      offsetX: 0,
      offsetY: 2
    })
    .padding(20)
  }
}
