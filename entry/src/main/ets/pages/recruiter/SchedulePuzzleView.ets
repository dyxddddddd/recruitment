// 创新点四：AI智能工时拼图可视化组件
// 用属性动画展示两个学生课表的互补拼合

import { AIScheduleMatch } from '../../service/RecruiterAIService'
import { FreeTimeSlot } from '../../model/ResumeModel'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { MessageDao } from '../../service/MessageDao'
import { buildConversationId, ChatMessage } from '../../model/MessageModel'

@Component
export struct SchedulePuzzleView {
  @Prop jobTitle: string = ''
  @Prop matches: AIScheduleMatch[] = []
  @Prop summary: string = ''
  onClose?: () => void

  @State phase1Done: boolean = false
  @State phase2Done: boolean = false
  @State phase3Done: boolean = false
  @State showCoverage: boolean = false

  private readonly DAY_LABELS: string[] = ['', '一', '二', '三', '四', '五', '六', '日']
  private readonly DAY_INDICES: number[] = [1, 2, 3, 4, 5, 6, 7]
  private readonly HOUR_LABELS: string[] = [
    '8:00', '9:00', '10:00', '11:00', '12:00', '13:00', '14:00',
    '15:00', '16:00', '17:00', '18:00', '19:00', '20:00', '21:00'
  ]
  private readonly COLOR_A: string = '#52C41A'
  private readonly COLOR_B: string = '#4A90D9'
  private messageDao: MessageDao = new MessageDao()

  aboutToAppear(): void {
    setTimeout(() => { this.phase1Done = true }, 80)
    setTimeout(() => { this.phase2Done = true }, 700)
    setTimeout(() => { this.phase3Done = true }, 1300)
    setTimeout(() => { this.showCoverage = true }, 1500)
  }

  build() {
    Column() {
      Divider().height(1).color('#F0F0F0').margin({ bottom: 14 })

      // 标题栏
      Row() {
        Text('🧩 AI 智能工时拼图')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        Blank()
        Button() { Text('✕').fontSize(14).fontColor('#999999') }
          .width(24).height(24)
          .backgroundColor(Color.Transparent)
          .onClick(() => { this.onClose?.() })
      }
      .width('100%')
      .margin({ bottom: 10 })

      // AI总结
      if (this.summary) {
        Text(this.summary)
          .fontSize(13)
          .fontColor('#666666')
          .lineHeight(20)
          .margin({ bottom: 14 })
      }

      // 配对卡片
      if (this.matches.length === 0) {
        Text('暂无匹配的学生课表数据')
          .fontSize(13)
          .fontColor('#999999')
          .padding({ top: 20, bottom: 20 })
      }

      ForEach(this.buildPairs(), (pair: PairInfo, pairIdx: number) => {
        this.PairCard(pair, pairIdx)
      })

      // 覆盖率指示器
      if (this.showCoverage && this.matches.length >= 2) {
        this.CoverageBar()
      }
    }
    .width('100%')
    .padding({ left: 4, right: 4, bottom: 20 })
  }

  // --- 配对卡片 ---
  @Builder
  PairCard(pair: PairInfo, pairIdx: number) {
    Column() {
      // 学生信息头部
      Row() {
        // 学生A头像
        Stack() {
          Circle()
            .width(36).height(36)
            .fill(this.COLOR_A)
          Text(pair.a.studentName.charAt(0))
            .fontSize(14).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        }

        Column() {
          Text(`${pair.a.studentName} · ${pair.a.school}`)
            .fontSize(12).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
          Text(pair.a.major)
            .fontSize(10).fontColor('#999999').margin({ top: 1 })
        }
        .margin({ left: 8 }).layoutWeight(1)

        Text(`匹配 ${pair.a.matchScore}%`)
          .fontSize(10).fontColor('#FFFFFF')
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(this.matchColor(pair.a.matchScore))
          .borderRadius(10)

        if (pair.b) {
          Text('🤝').fontSize(16).margin({ left: 6, right: 6 })
        }
      }
      .width('100%')
      .margin({ bottom: 10 })

      // 学生B信息
      if (pair.b) {
        Row() {
          Stack() {
            Circle()
              .width(30).height(30)
              .fill(this.COLOR_B)
            Text(pair.b.studentName.charAt(0))
              .fontSize(12).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          }

          Column() {
            Text(`${pair.b.studentName} · ${pair.b.school}`)
              .fontSize(12).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
            Text(pair.b.major)
              .fontSize(10).fontColor('#999999').margin({ top: 1 })
          }
          .margin({ left: 8 }).layoutWeight(1)

          Text(`匹配 ${pair.b.matchScore}%`)
            .fontSize(10).fontColor('#FFFFFF')
            .padding({ left: 6, right: 6, top: 2, bottom: 2 })
            .backgroundColor(this.matchColor(pair.b.matchScore))
            .borderRadius(10)
        }
        .width('100%')
        .margin({ bottom: 12 })
      }

      // 图例
      Row() {
        this.LegendDot(this.COLOR_A, pair.a.studentName)
        if (pair.b) {
          this.LegendDot(this.COLOR_B, pair.b.studentName)
        }
        Blank()
        Text('← 左滑查看更多时段 →')
          .fontSize(9).fontColor('#CCCCCC')
      }
      .width('100%')
      .margin({ bottom: 8 })

      // 课表拼图网格
      this.ScheduleGrid(pair)

      // 一键打包约面
      if (pair.b) {
        Button('📋 一键打包约面')
          .width('80%')
          .height(40)
          .fontSize(14)
          .backgroundColor(AppConstants.COLOR_ACCENT)
          .fontColor('#FFFFFF')
          .borderRadius(20)
          .margin({ top: 14 })
          .onClick(() => {
            const recruiterId = AppState.currentUser?.userId || ''
            if (!recruiterId) {
              AlertDialog.show({ title: '提示', message: '请先登录招聘者账号。' })
              return
            }
            AlertDialog.show({
              title: '打包约面确认',
              message: `即将向以下学生发送面试邀约：\n\n` +
                `${pair.a.studentName}（${pair.a.school}）\n空闲：${pair.a.freeSlots.slice(0, 3).join('、')}\n\n` +
                `${pair.b!.studentName}（${pair.b!.school}）\n空闲：${pair.b!.freeSlots.slice(0, 3).join('、')}\n\n` +
                `两位学生课表互补，可协同覆盖更多时段。`,
              primaryButton: {
                value: '确认发送',
                action: () => {
                  this.sendBatchInterviewInvite(recruiterId, pair.a, pair.b!)
                }
              },
              secondaryButton: { value: '取消', action: () => {} }
            })
          })
      }
    }
    .width('100%')
    .padding({ top: 14, bottom: 14, left: 12, right: 12 })
    .backgroundColor('#FAFAFA')
    .borderRadius(12)
    .margin({ bottom: 12 })
    .animation({ duration: 500, curve: Curve.EaseOut })
  }

  // --- 课表拼图网格 ---
  @Builder
  ScheduleGrid(pair: PairInfo) {
    Scroll() {
      Row() {
        // 左侧时间标签列
        Column() {
          Text('')
            .width(32).height(20) // 空标题
          ForEach(this.HOUR_LABELS, (label: string) => {
            Text(label)
              .fontSize(8)
              .fontColor('#999999')
              .width(32)
              .height(20)
              .textAlign(TextAlign.Center)
          })
        }

        // 7天列
        ForEach(this.DAY_INDICES, (day: number) => {
          Column() {
            // 星期标题
            Text(this.DAY_LABELS[day])
              .fontSize(10)
              .fontWeight(FontWeight.Medium)
              .fontColor('#666666')
              .width(44)
              .height(20)
              .textAlign(TextAlign.Center)

            // 每小时一个格子
            ForEach(this.HOUR_LABELS, (label: string, hourIdx: number) => {
              Stack() {
                // 背景
                Rect()
                  .width(42)
                  .height(18)
                  .fill('#F0F0F0')
                  .radius(2)

                // 学生A的块
                if (this.isHourFree(pair.a.freeSlotDetails, day, hourIdx + 8)) {
                  Rect()
                    .width(42)
                    .height(18)
                    .fill(this.COLOR_A)
                    .radius(2)
                    .opacity(this.phase1Done ? 0.85 : 0)
                    .scale(this.phase1Done ? { x: 1, y: 1 } : { x: 0.3, y: 0.3 })
                    .animation({
                      duration: 350,
                      curve: Curve.EaseOut,
                      delay: (day * 60) + (hourIdx * 40)
                    })
                }

                // 学生B的块（叠加在学生A之上）
                if (pair.b && this.isHourFree(pair.b.freeSlotDetails, day, hourIdx + 8)) {
                  Rect()
                    .width(42)
                    .height(18)
                    .fill(this.COLOR_B)
                    .radius(2)
                    .opacity(this.phase2Done ? 0.85 : 0)
                    .scale(this.phase2Done ? { x: 1, y: 1 } : { x: 0.3, y: 0.3 })
                    .animation({
                      duration: 350,
                      curve: Curve.EaseOut,
                      delay: (day * 60) + (hourIdx * 40)
                    })
                }
              }
              .width(44)
              .height(20)
            })
          }
        })
      }
    }
    .scrollBar(BarState.Off)
    .width('100%')
    .height(310)
  }

  // --- 覆盖率指示器 ---
  @Builder
  CoverageBar() {
    Column() {
      Row() {
        Text('📊 拼合覆盖率')
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
        Blank()
        Text(`${this.coveragePercent()}%`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.COLOR_A)
      }
      .width('100%')
      .margin({ top: 8, bottom: 6 })

      // 进度条
      Row() {
        Rect()
          .height(10)
          .fill(this.COLOR_A)
          .layoutWeight(this.phase3Done ? this.coveragePercent() : 0)
          .radius(5)
          .animation({ duration: 800, curve: Curve.EaseInOut })
        Rect()
          .height(10)
          .fill('#F0F0F0')
          .layoutWeight(this.phase3Done ? (100 - this.coveragePercent()) : 100)
          .radius(5)
      }
      .width('100%')
      .margin({ bottom: 6 })

      Row() {
        Text('学生A独立覆盖')
          .fontSize(10).fontColor('#999999')
        Rect().width(8).height(8).fill(this.COLOR_A).radius(2).margin({ left: 4, right: 12 })
        Text('学生B补充覆盖')
          .fontSize(10).fontColor('#999999')
        Rect().width(8).height(8).fill(this.COLOR_B).radius(2).margin({ left: 4 })
      }
    }
    .width('100%')
    .padding({ top: 10, bottom: 10, left: 12, right: 12 })
    .backgroundColor('#FAFAFA')
    .borderRadius(12)
    .margin({ top: 8 })
    .opacity(this.showCoverage ? 1 : 0)
    .animation({ duration: 400, curve: Curve.EaseOut })
  }

  // --- 辅助方法 ---

  private buildPairs(): PairInfo[] {
    const result: PairInfo[] = []
    for (let i = 0; i < this.matches.length; i += 2) {
      result.push({
        a: this.matches[i],
        b: i + 1 < this.matches.length ? this.matches[i + 1] : null
      })
    }
    return result
  }

  private isHourFree(slots: FreeTimeSlot[], day: number, hour: number): boolean {
    if (!slots || slots.length === 0) return false
    const hourStart = hour * 60
    const hourEnd = (hour + 1) * 60
    return slots.some(s => {
      if (s.dayOfWeek !== day) return false
      const slotStart = (s.startHour ?? 0) * 60 + (s.startMinute ?? 0)
      const slotEnd = (s.endHour ?? 0) * 60 + (s.endMinute ?? 0)
      return slotStart < hourEnd && slotEnd > hourStart
    })
  }

  private coveragePercent(): number {
    if (this.matches.length < 2) {
      // Single student coverage
      if (this.matches.length === 1) {
        const slots = this.matches[0].freeSlotDetails || []
        let totalMinutes = 0
        for (const s of slots) {
          const start = (s.startHour ?? 0) * 60 + (s.startMinute ?? 0)
          const end = (s.endHour ?? 0) * 60 + (s.endMinute ?? 0)
          totalMinutes += Math.max(0, end - start)
        }
        const maxPossible = 7 * 14 * 60 // 7 days * 14 hours * 60 min
        return Math.min(100, Math.round((totalMinutes / maxPossible) * 100))
      }
      return 0
    }

    // Combined coverage: union of both students' free slots
    const a = this.matches[0].freeSlotDetails || []
    const b = this.matches[1].freeSlotDetails || []
    const covered = new Set<string>()
    for (const day of [1, 2, 3, 4, 5, 6, 7]) {
      for (let h = 8; h < 22; h++) {
        if (this.isHourFree(a, day, h) || this.isHourFree(b, day, h)) {
          covered.add(`${day}-${h}`)
        }
      }
    }
    return Math.round((covered.size / (7 * 14)) * 100)
  }

  private matchColor(score: number): string {
    if (score >= 80) return '#52C41A'
    if (score >= 60) return '#FAAD14'
    return '#FF7B54'
  }

  @Builder
  LegendDot(color: string, name: string) {
    Row() {
      Rect()
        .width(10).height(10)
        .fill(color)
        .radius(2)
      Text(name)
        .fontSize(10)
        .fontColor('#666666')
        .margin({ left: 3 })
    }
    .margin({ right: 12 })
  }
  private async sendBatchInterviewInvite(recruiterId: string, studentA: AIScheduleMatch, studentB: AIScheduleMatch): Promise<void> {
    try {
      const recruiterName = AppState.currentUser?.companyName || AppState.currentUser?.realName || 'HR'
      const now = Date.now()
      const content = `【面试邀约】您好！您的课表空闲时间与「${this.jobTitle}」微任务高度匹配，` +
        `HR「${recruiterName}」诚邀您参与面试确认。请登录App在消息中回复您方便的时间段。`

      const students = [studentA, studentB]
      for (let i = 0; i < students.length; i++) {
        const s = students[i]
        const conversationId = buildConversationId(recruiterId, s.studentId)
        await this.messageDao.ensureConversation(conversationId, s.studentId, s.studentName)

        const message: ChatMessage = {
          messageId: `m_${now}_${i}_${Math.random().toString(36).slice(2, 8)}`,
          sessionId: conversationId,
          senderId: recruiterId,
          receiverId: s.studentId,
          content: content,
          timestamp: now,
          isAIAgentReply: false,
          messageType: 'text',
          isRead: false
        }
        await this.messageDao.insertMessage(message)
      }

      AppStorage.setOrCreate<number>('msg_refresh', now)

      AlertDialog.show({
        title: '约面已发送',
        message: `已向 ${studentA.studentName}、${studentB.studentName} 发送面试邀约，请等待对方确认。`
      })
    } catch (_e) {
      AlertDialog.show({ title: '发送失败', message: '消息发送失败，请稍后重试。' })
    }
  }
}

interface PairInfo {
  a: AIScheduleMatch
  b: AIScheduleMatch | null
}
