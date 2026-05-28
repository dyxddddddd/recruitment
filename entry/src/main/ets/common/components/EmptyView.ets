// 通用空状态组件

@Component
export struct EmptyView {
  @Prop icon: string = '📋'
  @Prop message: string = '暂无数据'
  @Prop subMessage: string = ''

  build() {
    Column() {
      Text(this.icon)
        .fontSize(64)
        .margin({ bottom: 16 })
      Text(this.message)
        .fontSize(16)
        .fontColor('#666666')
        .fontWeight(FontWeight.Medium)
      if (this.subMessage) {
        Text(this.subMessage)
          .fontSize(12)
          .fontColor('#999999')
          .margin({ top: 8 })
      }
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
