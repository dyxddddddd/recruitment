// 招聘者 - 岗位管理页（已发布岗位详情 + AI工时拼图入口）
import { router } from '@kit.ArkUI'
import { AppConstants } from '../../common/constants/AppConstants'
import { JobPosition, JobCategory, JobStatus } from '../../model/JobModel'
import { JobDao } from '../../service/JobDao'
import { DatabaseHelper } from '../../database/DatabaseHelper'
import { TABLE_JOB } from '../../database/Tables'
import { RecruiterAIService, AIScheduleMatch } from '../../service/RecruiterAIService'
import { SchedulePuzzleView } from './SchedulePuzzleView'

const DAY_LABELS: string[] = ['周一', '周二', '周三', '周四', '周五', '周六', '周日']

@Entry
@Component
export struct JobManagePage {
  @State job: JobPosition | null = null
  @State loading: boolean = true
  @State showSchedulePuzzle: boolean = false
  @State scheduleMatches: AIScheduleMatch[] = []
  @State scheduleSummary: string = ''
  @State isLoadingSchedule: boolean = false

  private jobDao: JobDao = new JobDao()
  private jobId: string = ''

  aboutToAppear(): void {
    const params = router.getParams() as Record<string, Object>
    if (params && params['jobId']) {
      this.jobId = params['jobId'] as string
      this.loadJob()
    } else {
      this.loading = false
    }
  }

  async loadJob(): Promise<void> {
    this.loading = true
    try {
      this.job = await this.jobDao.getJobById(this.jobId)
    } finally {
      this.loading = false
    }
  }

  async loadSchedulePuzzle(): Promise<void> {
    if (!this.job) return
    this.isLoadingSchedule = true
    try {
      const candidates = await RecruiterAIService.fetchScheduledStudents()
      const taskReq = `岗位：${this.job.title}，类型：微任务/兼职`
      const result = await RecruiterAIService.matchSchedulePuzzle(this.job.title, taskReq, candidates)
      this.scheduleMatches = result.matches
      this.scheduleSummary = result.summary
    } catch (_e) {
      this.scheduleSummary = 'AI工时拼图分析暂不可用，请稍后重试。'
      this.scheduleMatches = []
    } finally {
      this.isLoadingSchedule = false
      this.showSchedulePuzzle = true
    }
  }

  async closeJob(): Promise<void> {
    if (!this.job) return
    AlertDialog.show({
      title: '确认关闭',
      message: `确定要关闭岗位「${this.job.title}」吗？关闭后将不再接收新投递。`,
      primaryButton: {
        value: '确认关闭',
        action: async () => {
          try {
            const store = await DatabaseHelper.getInstance().getStore()
            await store.executeSql(
              `UPDATE ${TABLE_JOB} SET status = 'closed' WHERE job_id = '${this.jobId}'`
            )
            if (this.job) {
              this.job.status = JobStatus.CLOSED
            }
          } catch (_e) {
            AlertDialog.show({ message: '操作失败，请稍后重试' })
          }
        }
      },
      secondaryButton: { value: '取消', action: () => {} }
    })
  }

  build() {
    Column() {
      // 顶部导航栏
      Row() {
        Button() { Text('← 返回').fontSize(15).fontColor('#4A90D9') }
          .backgroundColor(Color.Transparent)
          .padding(0)
        Blank()
        Text('岗位详情')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        Blank()
        Row().width(48)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 80, bottom: 14 })
      .backgroundColor('#FFFFFF')
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.TOP])

      if (this.loading) {
        Column() {
          LoadingProgress().width(32).height(32).color('#4A90D9')
          Text('加载中...').fontSize(13).fontColor('#999999').margin({ top: 12 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (!this.job) {
        Column() {
          Text('😕').fontSize(48).margin({ bottom: 12 })
          Text('岗位不存在或已被删除').fontSize(14).fontColor('#999999')
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        Scroll() {
          Column() {
            // ==== 英雄卡片 ====
            Column() {
              Row() {
                this.StatusBadge(this.job!.status)
                Blank()
                Text(this.formatTime(this.job!.publishTime).split(' ')[0] + ' 发布')
                  .fontSize(11)
                  .fontColor('#BBBBBB')
              }
              .width('100%')
              .margin({ bottom: 12 })

              Text(this.job!.title)
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .fontColor('#1A1A1A')
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')

              Row() {
                Text(this.job!.companyName)
                  .fontSize(14)
                  .fontColor('#666666')
                if (this.job!.city) {
                  Text(' · ' + this.job!.city)
                    .fontSize(14)
                    .fontColor('#999999')
                }
              }
              .width('100%')
              .margin({ top: 6 })

              Row() {
                Text(this.job!.salaryRange || '面议')
                  .fontSize(26)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FF6B35')
                Text('  ' + (this.job!.category === JobCategory.MICRO_TASK ? '微任务' : '全职实习'))
                  .fontSize(12)
                  .fontColor('#999999')
                  .padding({ left: 8, right: 8, top: 2, bottom: 2 })
                  .border({ width: 1, color: '#E8E8E8', style: BorderStyle.Solid })
                  .borderRadius(8)
              }
              .width('100%')
              .margin({ top: 14 })
              .alignItems(VerticalAlign.Center)
            }
            .width('100%')
            .padding({ left: 20, right: 20, top: 16, bottom: 20 })
            .backgroundColor('#FFFFFF')
            .borderRadius(14)
            .margin({ top: 12, bottom: 12 })

            // ==== 数据统计 ====
            Row() {
              this.StatItem('👁', '浏览量', this.job!.viewCount, '#4A90D9')
              this.StatItem('📩', '投递数', this.job!.applyCount, '#52C41A')
              this.StatItem('📅', '已发布', this.getDaysSincePublish(), '#999999')
            }
            .width('100%')
            .justifyContent(FlexAlign.SpaceBetween)
            .margin({ bottom: 12 })

            // ==== 基本信息 ====
            Column() {
              this.SectionTitle('📋 基本信息')
              Row() {
                Column() {
                  this.DetailItem('岗位类别', this.job!.category === JobCategory.MICRO_TASK ? '微任务/兼职' : '全职/实习')
                  this.DetailItem('学历要求', this.job!.educationRequired || '不限')
                  this.DetailItem('工作年限', this.job!.workYearsRequired || '不限')
                }
                .layoutWeight(1)
                Column() {
                  this.DetailItem('工作地点', this.job!.workAddress || '未填写')
                  this.DetailItem('所在城市', this.job!.city || '未选择')
                  this.DetailItem('薪资待遇', this.job!.salaryRange || '面议')
                }
                .layoutWeight(1)
              }
              .width('100%')

              if (this.job!.skills && this.job!.skills.length > 0) {
                Row() {
                  Text('技能标签')
                    .fontSize(12)
                    .fontColor('#999999')
                    .margin({ right: 10 })
                    .alignSelf(ItemAlign.Start)
                    .padding({ top: 4 })
                  Column() {
                    Row() {
                      ForEach(this.job!.skills, (skill: string) => {
                        Text(skill)
                          .fontSize(11)
                          .fontColor('#4A90D9')
                          .padding({ left: 10, right: 10, top: 4, bottom: 4 })
                          .backgroundColor('rgba(74,144,217,0.06)')
                          .border({ width: 0.5, color: 'rgba(74,144,217,0.2)', style: BorderStyle.Solid })
                          .borderRadius(10)
                          .margin({ right: 6, bottom: 6 })
                      })
                    }
                    .width('100%')
                  }
                  .layoutWeight(1)
                }
                .width('100%')
                .margin({ top: 4, bottom: 4 })
              }

              Divider().height(1).color('#F0F0F0').margin({ top: 4, bottom: 14 })

              Text('岗位描述')
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor('#1A1A1A')
                .margin({ bottom: 8 })
              Text(this.job!.description)
                .fontSize(13)
                .fontColor('#666666')
                .lineHeight(22)
                .width('100%')
            }
            .width('100%')
            .padding({ left: 18, right: 18, top: 16, bottom: 18 })
            .backgroundColor('#FFFFFF')
            .borderRadius(14)
            .margin({ bottom: 12 })

            // ==== 微任务时间安排 ====
            if (this.job!.category === JobCategory.MICRO_TASK) {
              Column() {
                this.SectionTitle('⏰ 任务时间安排')
                // 日期范围
                Row() {
                  Column() {
                    Text('开始日期')
                      .fontSize(11)
                      .fontColor('#999999')
                      .margin({ bottom: 4 })
                    Text(this.job!.taskStartTime ? this.formatDate(this.job!.taskStartTime) : '待定')
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#1A1A1A')
                  }
                  .padding({ left: 14, right: 14, top: 12, bottom: 12 })
                  .backgroundColor('#F7F8FC')
                  .borderRadius(10)
                  .layoutWeight(1)

                  Column() {
                    Text('→')
                      .fontSize(20)
                      .fontColor('#CCCCCC')
                  }
                  .margin({ left: 8, right: 8 })

                  Column() {
                    Text('结束日期')
                      .fontSize(11)
                      .fontColor('#999999')
                      .margin({ bottom: 4 })
                    Text(this.job!.taskEndTime ? this.formatDate(this.job!.taskEndTime) : '待定')
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#1A1A1A')
                  }
                  .padding({ left: 14, right: 14, top: 12, bottom: 12 })
                  .backgroundColor('#F7F8FC')
                  .borderRadius(10)
                  .layoutWeight(1)
                }
                .width('100%')
                .margin({ bottom: 16 })

                // 每周工作天数
                if (this.job!.requiredDaysOfWeek && this.job!.requiredDaysOfWeek.length > 0) {
                  Text('每周工作')
                    .fontSize(11)
                    .fontColor('#999999')
                    .margin({ bottom: 8 })
                  Row() {
                    ForEach(DAY_LABELS, (label: string, idx: number) => {
                      Text(label)
                        .fontSize(12)
                        .fontWeight(FontWeight.Medium)
                        .fontColor(this.job!.requiredDaysOfWeek!.indexOf(idx + 1) >= 0 ? '#FFFFFF' : '#999999')
                        .width(38)
                        .height(30)
                        .textAlign(TextAlign.Center)
                        .backgroundColor(
                          this.job!.requiredDaysOfWeek!.indexOf(idx + 1) >= 0 ? '#4A90D9' : '#F5F5F5'
                        )
                        .borderRadius(8)
                        .margin({ right: 4 })
                    })
                  }
                  .width('100%')
                  .margin({ bottom: 14 })
                }

                // 每日时间段
                if (this.job!.requiredStartHour !== undefined && this.job!.requiredStartHour >= 0) {
                  Row() {
                    Text('每日时间')
                      .fontSize(11)
                      .fontColor('#999999')
                      .margin({ right: 10 })
                    Text(this.formatTimeOfDay(this.job!.requiredStartHour, this.job!.requiredStartMinute))
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#4A90D9')
                    Text('  —  ')
                      .fontSize(14)
                      .fontColor('#CCCCCC')
                    Text(this.formatTimeOfDay(this.job!.requiredEndHour!, this.job!.requiredEndMinute))
                      .fontSize(16)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#4A90D9')
                  }
                  .width('100%')
                }
              }
              .width('100%')
              .padding({ left: 18, right: 18, top: 16, bottom: 18 })
              .backgroundColor('#FFFFFF')
              .borderRadius(14)
              .margin({ bottom: 12 })

              // ==== AI 工时拼图 ====
              Column() {
                Row() {
                  Column() {
                    Text('🧩 AI 智能工时拼图')
                      .fontSize(15)
                      .fontWeight(FontWeight.Bold)
                      .fontColor('#1A1A1A')
                    Text('课表互补分析，一键打包约面')
                      .fontSize(11)
                      .fontColor('#999999')
                      .margin({ top: 2 })
                  }
                  .layoutWeight(1)
                  .alignItems(HorizontalAlign.Start)

                  if (!this.showSchedulePuzzle && !this.isLoadingSchedule) {
                    Image($r('sys.symbol.chevron_right'))
                      .width(14).height(14)
                      .fillColor('#CCCCCC')
                  }
                }
                .width('100%')
                .margin({ bottom: 14 })

                Row() {
                  Rect().width(3).height(38).fill('#9B59B6').radius(1.5).margin({ right: 10 })
                  Text('分析已上传课表的学生空闲时间，\n智能匹配课表互补的候选人组合。')
                    .fontSize(12)
                    .fontColor('#888888')
                    .lineHeight(18)
                    .layoutWeight(1)
                }
                .width('100%')
                .margin({ bottom: 14 })

                Button(this.isLoadingSchedule ? '⏳ 分析中...' : (this.showSchedulePuzzle ? '🔄 重新分析' : '🚀 启动工时拼图'))
                  .width('100%')
                  .height(44)
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#FFFFFF')
                  .backgroundColor(this.showSchedulePuzzle ? '#8E6BBF' : '#9B59B6')
                  .borderRadius(12)
                  .enabled(!this.isLoadingSchedule)
                  .onClick(() => this.loadSchedulePuzzle())

                if (this.isLoadingSchedule) {
                  Row() {
                    LoadingProgress().width(14).height(14).color('#9B59B6')
                    Text(' AI 正在分析学生课表...')
                      .fontSize(12)
                      .fontColor('#999999')
                      .margin({ left: 8 })
                  }
                  .width('100%')
                  .justifyContent(FlexAlign.Center)
                  .margin({ top: 14 })
                }

                if (this.showSchedulePuzzle) {
                  SchedulePuzzleView({
                    jobTitle: this.job!.title,
                    matches: this.scheduleMatches,
                    summary: this.scheduleSummary,
                    onClose: () => this.showSchedulePuzzle = false
                  })
                }
              }
              .width('100%')
              .padding({ left: 18, right: 18, top: 16, bottom: 18 })
              .backgroundColor('#FFFFFF')
              .borderRadius(14)
              .margin({ bottom: 12 })
            }

            // ==== 操作区 ====
            if (this.job!.status === JobStatus.PUBLISHED) {
              Column() {
                Button('关闭岗位')
                  .width('100%')
                  .height(48)
                  .fontSize(15)
                  .fontColor('#FF4D4F')
                  .backgroundColor('#FFF8F8')
                  .border({ width: 1, color: '#FFE0E0', style: BorderStyle.Solid })
                  .borderRadius(12)
                  .onClick(() => this.closeJob())
                Text('关闭后将不再接收新投递，已投递的学生不受影响')
                  .fontSize(11)
                  .fontColor('#CCCCCC')
                  .margin({ top: 10 })
              }
              .width('100%')
              .margin({ top: 4, bottom: 24 })
            }

            Row().height(20)
          }
          .width('100%')
          .padding({ left: 14, right: 14 })
        }
        .width('100%')
        .layoutWeight(1)
        .scrollBar(BarState.Off)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F4F6FB')
  }

  @Builder
  StatItem(icon: string, label: string, value: number, color: string) {
    Column() {
      Text(icon)
        .fontSize(16)
        .margin({ bottom: 6 })
      Text(String(value))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor(color)
      Text(label)
        .fontSize(10)
        .fontColor('#999999')
        .margin({ top: 2 })
    }
    .width('30%')
    .padding({ top: 16, bottom: 16 })
    .backgroundColor('#FFFFFF')
    .borderRadius(12)
  }

  @Builder
  SectionTitle(title: string) {
    Row() {
      Rect().width(3).height(14).fill('#4A90D9').radius(1.5).margin({ right: 8 })
      Text(title)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
    }
    .width('100%')
    .margin({ bottom: 14 })
  }

  @Builder
  DetailItem(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor('#AAAAAA')
        .width(60)
      Text(value)
        .fontSize(13)
        .fontColor('#333333')
        .layoutWeight(1)
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  @Builder
  StatusBadge(status: JobStatus) {
    if (status === JobStatus.PUBLISHED) {
      Row() {
        Rect().width(6).height(6).fill('#52C41A').radius(3).margin({ right: 4 })
        Text('已发布')
          .fontSize(11)
          .fontColor('#52C41A')
      }
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor('rgba(82,196,26,0.07)')
      .border({ width: 0.5, color: 'rgba(82,196,26,0.2)', style: BorderStyle.Solid })
      .borderRadius(8)
    } else if (status === JobStatus.CLOSED) {
      Row() {
        Rect().width(6).height(6).fill('#BBBBBB').radius(3).margin({ right: 4 })
        Text('已关闭')
          .fontSize(11)
          .fontColor('#999999')
      }
      .padding({ left: 10, right: 10, top: 4, bottom: 4 })
      .backgroundColor('rgba(0,0,0,0.04)')
      .border({ width: 0.5, color: 'rgba(0,0,0,0.08)', style: BorderStyle.Solid })
      .borderRadius(8)
    }
  }

  private formatTime(timestamp: number): string {
    const d = new Date(timestamp)
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`
  }

  private formatDate(timestamp: number): string {
    const d = new Date(timestamp)
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')}`
  }

  private getDaysSincePublish(): number {
    if (!this.job) return 0
    const diff = Date.now() - this.job.publishTime
    return Math.max(1, Math.floor(diff / (1000 * 60 * 60 * 24)))
  }

  private formatTimeOfDay(hour: number, minute?: number): string {
    const h = hour
    const m = minute ?? 0
    return `${h}:${String(m).padStart(2, '0')}`
  }

  private getDaysDisplay(days: number[]): string {
    const names: string[] = []
    for (let i = 0; i < days.length; i++) {
      const idx = days[i] - 1
      if (idx >= 0 && idx < DAY_LABELS.length) {
        names.push(DAY_LABELS[idx])
      }
    }
    return names.join('、')
  }
}
