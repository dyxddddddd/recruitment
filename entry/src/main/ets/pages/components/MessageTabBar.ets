@Component
export struct MessageTabBar {
  @Prop totalUnread: number = 0
  @Prop idx: number = 0
  @Prop color: string = '#4A90D9'
  @Prop icon: string = '信'
  @Prop useOpacity: boolean = false
  @StorageProp('current_tab') currentTab: number = -1

  build() {
    Column() {
      Stack() {
        Text(this.icon)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.currentTab === this.idx ? this.color : '#999999')
          .opacity(this.useOpacity ? (this.currentTab === this.idx ? 1.0 : 0.45) : 1.0)
        if (this.totalUnread > 0) {
          Text(this.totalUnread > 99 ? '99+' : `${this.totalUnread}`)
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .backgroundColor('#FF4D4F')
            .borderRadius(8)
            .padding({ left: 4, right: 4, top: 1, bottom: 1 })
            .position({ x: 22, y: -6 })
        }
      }
      Text('消息')
        .fontSize(10)
        .fontColor(this.currentTab === this.idx ? this.color : '#999999')
        .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .alignItems(HorizontalAlign.Center)
  }
}
