// 求职者 - 消息页（Tab d: 消息 + AI数字分身）

import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { ChatSession } from '../../model/MessageModel'
import { MessageDao } from '../../service/MessageDao'

@Component
export struct JobSeekerMessagesTab {
  @State sessions: ChatSession[] = []
  @State isAIEnabled: boolean = false
  private messageDao: MessageDao = new MessageDao()

  aboutToAppear(): void {
    this.loadSessions()
  }

  async loadSessions(): Promise<void> {
    if (AppState.currentUser) {
      this.sessions = await this.messageDao.getSessions(AppState.currentUser.userId)
    }
  }

  build() {
    Column() {
      // 顶部标题 + AI开关
      Row() {
        Text('消息')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')

        Blank()

        // 创新点六：AI数字分身开关
        Row() {
          Text('AI分身')
            .fontSize(11)
            .fontColor(this.isAIEnabled ? '#FFFFFF' : '#999999')
            .margin({ right: 6 })

          Toggle({ type: ToggleType.Switch, isOn: this.isAIEnabled })
            .selectedColor(AppConstants.COLOR_AI_PURPLE)
            .onChange((value: boolean) => {
              this.isAIEnabled = value
              AlertDialog.show({
                title: value ? 'AI数字分身已开启' : 'AI数字分身已关闭',
                message: value
                  ? '24小时AI替身将自动回复HR消息，达成意向后强提醒通知你。'
                  : 'AI替身已关闭，你将直接收到所有HR消息。'
              })
            })
        }
        .padding({ left: 10, right: 10, top: 4, bottom: 4 })
        .backgroundColor(this.isAIEnabled ? 'rgba(155,89,182,0.15)' : '#F5F5F5')
        .borderRadius(16)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      Divider().height(1).color('#F0F0F0')

      if (this.sessions.length === 0) {
        Column() {
          Text('📬')
            .fontSize(48)
            .margin({ bottom: 12 })
          Text('暂无消息')
            .fontSize(14)
            .fontColor('#999999')
          Text('投递简历后将在这里收到HR消息')
            .fontSize(12)
            .fontColor('#CCCCCC')
            .margin({ top: 4 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.sessions, (session: ChatSession) => {
            ListItem() {
              Row() {
                // 头像
                Text('💬')
                  .fontSize(32)
                  .margin({ right: 12 })

                Column() {
                  Row() {
                    Text(session.peerName)
                      .fontSize(15)
                      .fontWeight(FontWeight.Medium)
                      .fontColor('#1A1A1A')
                    if (session.isAIAgent) {
                      Text('AI')
                        .fontSize(9)
                        .fontColor(AppConstants.COLOR_AI_PURPLE)
                        .padding({ left: 4, right: 4, top: 1, bottom: 1 })
                        .backgroundColor('rgba(155,89,182,0.1)')
                        .borderRadius(4)
                        .margin({ left: 4 })
                    }
                    Blank()
                    Text(this.formatTime(session.lastMessageTime))
                      .fontSize(11)
                      .fontColor('#CCCCCC')
                  }
                  .width('100%')
                  .margin({ bottom: 4 })

                  Row() {
                    Text(session.lastMessage)
                      .fontSize(13)
                      .fontColor(session.isAIAgent ? AppConstants.COLOR_AI_PURPLE : '#999999')
                      .maxLines(1)
                      .layoutWeight(1)

                    if (session.unreadCount > 0) {
                      Text(`${session.unreadCount}`)
                        .fontSize(10)
                        .fontColor('#FFFFFF')
                        .padding({ left: 6, right: 6, top: 2, bottom: 2 })
                        .backgroundColor('#FF4D4F')
                        .borderRadius(8)
                    }
                  }
                  .width('100%')
                }
                .layoutWeight(1)
              }
              .width('100%')
              .padding({ top: 14, bottom: 14 })
              .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  formatTime(timestamp: number): string {
    const now = Date.now()
    const diff = now - timestamp
    if (diff < 86400000) {
      const date = new Date(timestamp)
      return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`
    }
    return `${Math.floor(diff / 86400000)}天前`
  }
}
