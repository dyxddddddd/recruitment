// 招聘者 - 我的（Tab e: 人才管理控制台 + AI虚拟人数据大屏）

import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { VipLevel, AuthStatus } from '../../model/UserModel'
import { UserDao } from '../../service/UserDao'
import { DatabaseHelper } from '../../database/DatabaseHelper'
import { TABLE_JOB, TABLE_APPLICATION, TABLE_MICRO_TASK, TABLE_USER, TABLE_AI_INTERVIEW } from '../../database/Tables'
import { RecruiterAIService, AssessmentSummaryItem } from '../../service/RecruiterAIService'
import { MessageDao } from '../../service/MessageDao'
import { InterviewApiService } from '../../service/InterviewApiService'

interface InterviewItem {
  applicationId: string
  jobId: string
  userId: string
  applicantName: string
  school: string
  jobTitle: string
  interviewTime: number
  status: string
}

interface ApplicantItem {
  userId: string
  applicantName: string
  school: string
  major: string
  jobTitle: string
  status: string
  applyTime: number
}

interface ManagedJob {
  jobId: string
  title: string
  applyCount: number
  viewCount: number
  publishTime: number
  status: string
}

interface InboxItem {
  applicationId: string
  userId: string
  applicantName: string
  school: string
  jobId: string
  jobTitle: string
  status: string
  applyTime: number
}

@Component
export struct RecruiterProfileTab {
  @State showAIDashboard: boolean = false
  @State jobCount: number = 0
  @State todayResumeCount: number = 0
  @State pendingTaskReviewCount: number = 0
  @State todayAIInterviewCount: number = 0
  @State showSettings: boolean = false
  @State oldPassword: string = ''
  @State newPassword: string = ''
  @State confirmPassword: string = ''
  // 面试排期管理
  @State showInterviewMgmt: boolean = false
  @State interviewList: InterviewItem[] = []
  // 人才搜索历史
  @State showTalentHistory: boolean = false
  @State applicantList: ApplicantItem[] = []
  // 数据分析报告
  @State showDataReport: boolean = false
  @State reportPublishedJobs: number = 0
  @State reportDraftJobs: number = 0
  @State reportTotalApps: number = 0
  @State reportInterviewApps: number = 0
  @State reportHiredApps: number = 0
  // 已发布岗位管理
  @State showJobMgmt: boolean = false
  @State managedJobList: ManagedJob[] = []
  // 简历收件箱
  @State showInbox: boolean = false
  @State inboxList: InboxItem[] = []
  @State inboxSelectMode: boolean = false
  @State selectedInboxIds: Set<string> = new Set()
  // AI评估列表
  @State assessmentList: AssessmentSummaryItem[] = []
  @State unreviewedCount: number = 0
  @State assessmentLoading: boolean = false
  @StorageLink('assessment_refresh') @Watch('onAssessmentRefresh') assessmentRefresh: number = 0
  private userDao: UserDao = new UserDao()
  private messageDao: MessageDao = new MessageDao()

  aboutToAppear(): void {
    this.loadStats()
    this.loadAssessments()
  }

  async loadStats(): Promise<void> {
    const user = AppState.currentUser
    if (!user) return
    try {
      const store = await DatabaseHelper.getInstance().getStore()
      const recruiterId = user.userId
      const todayStart = new Date()
      todayStart.setHours(0, 0, 0, 0)
      const todayMs = todayStart.getTime()

      // 在招岗位数
      const jobRs = await store.querySql(
        `SELECT COUNT(*) AS cnt FROM ${TABLE_JOB} WHERE recruiter_id = '${recruiterId}' AND status = 'published'`
      )
      if (jobRs.goToFirstRow()) {
        this.jobCount = jobRs.getLong(jobRs.getColumnIndex('cnt'))
      }
      jobRs.close()

      // 今日新增简历（今日投递数）
      const appRs = await store.querySql(
        `SELECT COUNT(*) AS cnt FROM ${TABLE_APPLICATION} WHERE job_id IN (SELECT job_id FROM ${TABLE_JOB} WHERE recruiter_id = '${recruiterId}') AND apply_time >= ${todayMs}`
      )
      if (appRs.goToFirstRow()) {
        this.todayResumeCount = appRs.getLong(appRs.getColumnIndex('cnt'))
      }
      appRs.close()

      // 待处理微任务验收（已接取未完成）
      const taskRs = await store.querySql(
        `SELECT COUNT(*) AS cnt FROM ${TABLE_MICRO_TASK} WHERE recruiter_id = '${recruiterId}' AND status = 'accepted'`
      )
      if (taskRs.goToFirstRow()) {
        this.pendingTaskReviewCount = taskRs.getLong(taskRs.getColumnIndex('cnt'))
      }
      taskRs.close()

      // 今日AI面试数量（今日完成的）
      const aiRs = await store.querySql(
        `SELECT COUNT(*) AS cnt FROM ${TABLE_AI_INTERVIEW} WHERE recruiter_id = '${recruiterId}' AND complete_time >= ${todayMs}`
      )
      if (aiRs.goToFirstRow()) {
        this.todayAIInterviewCount = aiRs.getLong(aiRs.getColumnIndex('cnt'))
      }
      aiRs.close()
    } catch (e) {
      // fallback to zero
    }
  }

  async loadInterviewList(): Promise<void> {
    const user = AppState.currentUser
    if (!user) return
    try {
      const store = await DatabaseHelper.getInstance().getStore()
      const sql = `SELECT a.application_id, a.job_id, a.user_id, a.interview_time, a.status, j.title AS job_title, u.real_name, u.school FROM ${TABLE_APPLICATION} a INNER JOIN ${TABLE_JOB} j ON a.job_id = j.job_id INNER JOIN ${TABLE_USER} u ON a.user_id = u.user_id WHERE j.recruiter_id = '${user.userId}' AND a.status = 'interview' ORDER BY a.interview_time DESC`
      const rs = await store.querySql(sql)
      const list: InterviewItem[] = []
      while (rs.goToNextRow()) {
        list.push({
          applicationId: rs.getString(rs.getColumnIndex('application_id')),
          jobId: rs.getString(rs.getColumnIndex('job_id')),
          userId: rs.getString(rs.getColumnIndex('user_id')),
          applicantName: rs.getString(rs.getColumnIndex('real_name')),
          school: rs.getString(rs.getColumnIndex('school')),
          jobTitle: rs.getString(rs.getColumnIndex('job_title')),
          interviewTime: rs.getLong(rs.getColumnIndex('interview_time')),
          status: rs.getString(rs.getColumnIndex('status'))
        })
      }
      rs.close()
      this.interviewList = list
    } catch (e) {
      this.interviewList = []
    }
  }

  async loadApplicantList(): Promise<void> {
    const user = AppState.currentUser
    if (!user) return
    try {
      const store = await DatabaseHelper.getInstance().getStore()
      const sql = `SELECT a.user_id, a.status, a.apply_time, j.title AS job_title, u.real_name, u.school, u.major FROM ${TABLE_APPLICATION} a INNER JOIN ${TABLE_JOB} j ON a.job_id = j.job_id INNER JOIN ${TABLE_USER} u ON a.user_id = u.user_id WHERE j.recruiter_id = '${user.userId}' ORDER BY a.apply_time DESC`
      const rs = await store.querySql(sql)
      const list: ApplicantItem[] = []
      const seen: string[] = []
      while (rs.goToNextRow()) {
        const uid = rs.getString(rs.getColumnIndex('user_id'))
        if (seen.indexOf(uid) < 0) {
          seen.push(uid)
          list.push({
            userId: uid,
            applicantName: rs.getString(rs.getColumnIndex('real_name')),
            school: rs.getString(rs.getColumnIndex('school')),
            major: rs.getString(rs.getColumnIndex('major')),
            jobTitle: rs.getString(rs.getColumnIndex('job_title')),
            status: rs.getString(rs.getColumnIndex('status')),
            applyTime: rs.getLong(rs.getColumnIndex('apply_time'))
          })
        }
      }
      rs.close()
      this.applicantList = list
    } catch (e) {
      this.applicantList = []
    }
  }

  async loadDataReport(): Promise<void> {
    const user = AppState.currentUser
    if (!user) return
    try {
      const store = await DatabaseHelper.getInstance().getStore()
      // 已发布岗位
      const pubRs = await store.querySql(
        `SELECT COUNT(*) AS cnt FROM ${TABLE_JOB} WHERE recruiter_id = '${user.userId}' AND status = 'published'`
      )
      if (pubRs.goToFirstRow()) this.reportPublishedJobs = pubRs.getLong(pubRs.getColumnIndex('cnt'))
      pubRs.close()
      // 草稿岗位
      const draftRs = await store.querySql(
        `SELECT COUNT(*) AS cnt FROM ${TABLE_JOB} WHERE recruiter_id = '${user.userId}' AND status != 'published'`
      )
      if (draftRs.goToFirstRow()) this.reportDraftJobs = draftRs.getLong(draftRs.getColumnIndex('cnt'))
      draftRs.close()
      // 总投递
      const appRs = await store.querySql(
        `SELECT COUNT(*) AS cnt FROM ${TABLE_APPLICATION} WHERE job_id IN (SELECT job_id FROM ${TABLE_JOB} WHERE recruiter_id = '${user.userId}')`
      )
      if (appRs.goToFirstRow()) this.reportTotalApps = appRs.getLong(appRs.getColumnIndex('cnt'))
      appRs.close()
      // 面试
      const intRs = await store.querySql(
        `SELECT COUNT(*) AS cnt FROM ${TABLE_APPLICATION} WHERE job_id IN (SELECT job_id FROM ${TABLE_JOB} WHERE recruiter_id = '${user.userId}') AND status = 'interview'`
      )
      if (intRs.goToFirstRow()) this.reportInterviewApps = intRs.getLong(intRs.getColumnIndex('cnt'))
      intRs.close()
      // 已录用
      const hiredRs = await store.querySql(
        `SELECT COUNT(*) AS cnt FROM ${TABLE_APPLICATION} WHERE job_id IN (SELECT job_id FROM ${TABLE_JOB} WHERE recruiter_id = '${user.userId}') AND status = 'offered'`
      )
      if (hiredRs.goToFirstRow()) this.reportHiredApps = hiredRs.getLong(hiredRs.getColumnIndex('cnt'))
      hiredRs.close()
    } catch (e) {
      // fallback
    }
  }

  async loadManagedJobs(): Promise<void> {
    const user = AppState.currentUser
    if (!user) return
    try {
      const store = await DatabaseHelper.getInstance().getStore()
      const sql = `SELECT job_id, title, apply_count, view_count, publish_time, status FROM ${TABLE_JOB} WHERE recruiter_id = '${user.userId}' AND status = 'published' ORDER BY publish_time DESC`
      const rs = await store.querySql(sql)
      const list: ManagedJob[] = []
      while (rs.goToNextRow()) {
        list.push({
          jobId: rs.getString(rs.getColumnIndex('job_id')),
          title: rs.getString(rs.getColumnIndex('title')),
          applyCount: rs.getLong(rs.getColumnIndex('apply_count')),
          viewCount: rs.getLong(rs.getColumnIndex('view_count')),
          publishTime: rs.getLong(rs.getColumnIndex('publish_time')),
          status: rs.getString(rs.getColumnIndex('status'))
        })
      }
      rs.close()
      this.managedJobList = list
    } catch (e) {
      this.managedJobList = []
    }
  }

  async loadInbox(): Promise<void> {
    const user = AppState.currentUser
    if (!user) return
    try {
      const store = await DatabaseHelper.getInstance().getStore()
      const sql = `SELECT a.application_id, a.user_id, a.job_id, a.status, a.apply_time, j.title AS job_title, u.real_name, u.school FROM ${TABLE_APPLICATION} a INNER JOIN ${TABLE_JOB} j ON a.job_id = j.job_id INNER JOIN ${TABLE_USER} u ON a.user_id = u.user_id WHERE j.recruiter_id = '${user.userId}' ORDER BY a.apply_time DESC`
      const rs = await store.querySql(sql)
      const list: InboxItem[] = []
      while (rs.goToNextRow()) {
        list.push({
          applicationId: rs.getString(rs.getColumnIndex('application_id')),
          userId: rs.getString(rs.getColumnIndex('user_id')),
          applicantName: rs.getString(rs.getColumnIndex('real_name')),
          school: rs.getString(rs.getColumnIndex('school')),
          jobId: rs.getString(rs.getColumnIndex('job_id')),
          jobTitle: rs.getString(rs.getColumnIndex('job_title')),
          status: rs.getString(rs.getColumnIndex('status')),
          applyTime: rs.getLong(rs.getColumnIndex('apply_time'))
        })
      }
      rs.close()
      this.inboxList = list
    } catch (e) {
      this.inboxList = []
    }
  }

  async loadAssessments(): Promise<void> {
    const user = AppState.currentUser
    if (!user) return
    this.assessmentLoading = true
    try {
      const sessions = await InterviewApiService.getUserSessions(user.userId)
      if (sessions.length > 0) {
        const store = await DatabaseHelper.getInstance().getStore()
        const list: AssessmentSummaryItem[] = []
        let unreviewed = 0
        for (const s of sessions) {
          let applicantName = ''
          let school = ''
          let jobTitle = s.position
          let dbUserId = ''
          let dbApplicationId = ''
          let dbStatus = ''
          try {
            const rs = await store.querySql(
              `SELECT ai.user_id, ai.application_id, ai.status, u.real_name, u.school, j.title FROM ${TABLE_AI_INTERVIEW} ai
               LEFT JOIN tb_user u ON ai.user_id = u.user_id
               LEFT JOIN ${TABLE_JOB} j ON ai.job_id = j.job_id
               WHERE ai.interview_id = '${s.sessionId}'`
            )
            if (rs.goToFirstRow()) {
              dbStatus = rs.getString(rs.getColumnIndex('status')) || ''
              dbUserId = rs.getString(rs.getColumnIndex('user_id')) || ''
              dbApplicationId = rs.getString(rs.getColumnIndex('application_id')) || ''
              applicantName = rs.getString(rs.getColumnIndex('real_name')) || ''
              school = rs.getString(rs.getColumnIndex('school')) || ''
              const jt = rs.getString(rs.getColumnIndex('title'))
              if (jt) jobTitle = jt
            }
            rs.close()
          } catch (_e) { /* use backend data only */ }
          const isReviewed = dbStatus === 'reviewed'
          if (!isReviewed) unreviewed++
          list.push({
            interviewId: s.sessionId,
            userId: dbUserId,
            applicantName: applicantName || s.position,
            school: school,
            jobTitle: jobTitle,
            totalScore: s.totalScore,
            completeTime: Date.parse(s.completedAt) || 0,
            recommendation: s.totalScore >= 80 ? '建议录用' : (s.totalScore >= 60 ? '可考虑' : '不建议'),
            applicationId: dbApplicationId,
            status: dbStatus
          })
        }
        this.assessmentList = list
        this.unreviewedCount = unreviewed
      } else {
        this.assessmentList = await RecruiterAIService.getCompletedAssessments(user.userId)
        this.unreviewedCount = this.assessmentList.filter((a: AssessmentSummaryItem) => a.status !== 'reviewed').length
      }
    } catch (_e) {
      try {
        this.assessmentList = await RecruiterAIService.getCompletedAssessments(user.userId)
        this.unreviewedCount = this.assessmentList.filter((a: AssessmentSummaryItem) => a.status !== 'reviewed').length
      } catch (_e2) {
        this.assessmentList = []
        this.unreviewedCount = 0
      }
    } finally {
      this.assessmentLoading = false
    }
  }

  onAssessmentRefresh(): void {
    if (this.showAIDashboard && this.assessmentRefresh > 0) {
      this.loadAssessments()
    }
  }

  async sendInterviewInvites(): Promise<void> {
    const user = AppState.currentUser
    if (!user || this.selectedInboxIds.size === 0) return
    const store = await DatabaseHelper.getInstance().getStore()
    let sentCount = 0
    try {
      for (const item of this.inboxList) {
        if (!this.selectedInboxIds.has(item.userId)) continue
        try {
          const result = await InterviewApiService.createInterview({
            userId: item.userId,
            position: item.jobTitle
          })
          const questionsJson = JSON.stringify(result.questions || []).replace(/'/g, "''")
          await store.executeSql(
            `INSERT INTO ${TABLE_AI_INTERVIEW} (interview_id, recruiter_id, user_id, job_id, application_id, status, questions, invite_time)
             VALUES ('${result.sessionId}', '${user.userId}', '${item.userId}', '${item.jobId}', '${item.applicationId}', 'invited', '${questionsJson}', ${Date.now()})`
          )
          await this.messageDao.insertSystemMessage(
            item.userId,
            'AI虚拟面试邀请',
            `[INTERVIEW:${result.sessionId}]${user.companyName || '企业'}邀请你参加「${item.jobTitle}」的AI视频面试（含数字人面试官+多维度评估）。请前往消息页查看并开始面试。`,
            'interview'
          )
          sentCount++
        } catch (_e) {
          // 单个失败继续发下一个
        }
      }
      if (sentCount > 0) {
        AlertDialog.show({ title: '发送成功', message: `已向 ${sentCount} 名学生发送AI面试邀请。` })
      } else {
        AlertDialog.show({ title: '发送失败', message: '所有邀请发送失败，请检查网络后重试。' })
      }
      this.inboxSelectMode = false
      this.selectedInboxIds.clear()
      this.showInbox = false
    } catch (e) {
      AlertDialog.show({ title: '发送失败', message: '部分邀请发送失败，请稍后重试。' })
    }
  }

  build() {
    Stack() {
      Column() {
        Scroll() {
          Column() {
          // 个人头部
          Column() {
            Row() {
              Text(this.getCompanyInitial())
                .fontSize(26)
                .fontWeight(FontWeight.Bold)
                .fontColor('#FFFFFF')
                .width(52)
                .height(52)
                .textAlign(TextAlign.Center)
                .backgroundColor('#4A90D9')
                .borderRadius(26)
                .margin({ right: 14 })
              Column() {
                Row() {
                  Text(AppState.currentUser?.companyName || '未认证企业')
                    .fontSize(17)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1A1A1A')
                    .maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                  if (AppState.currentUser?.authStatus === AuthStatus.APPROVED) {
                    Text(' ✓')
                      .fontSize(13)
                      .fontColor('#52C41A')
                  }
                }
                Text(AppState.currentUser?.hrRealName || '未实名认证')
                  .fontSize(12)
                  .fontColor('#999999')
                  .margin({ top: 2 })
                Row() {
                  Text(this.getAuthStatusText())
                    .fontSize(10)
                    .fontColor(this.getAuthStatusColor())
                    .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                    .backgroundColor(this.getAuthStatusBgColor())
                    .borderRadius(6)
                  Text(AppState.currentUser?.vipLevel === VipLevel.VIP ? 'VIP' : '普通会员')
                    .fontSize(10)
                    .fontColor(AppState.currentUser?.vipLevel === VipLevel.VIP ? '#D4A017' : '#999999')
                    .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                    .backgroundColor(AppState.currentUser?.vipLevel === VipLevel.VIP ? '#FFF8E1' : '#F5F5F5')
                    .borderRadius(6)
                    .margin({ left: 6 })
                }
                .margin({ top: 6 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
            }
            .width('100%')
            .alignItems(VerticalAlign.Center)
          }
          .width('100%')
          .padding({ left: 18, right: 18, top: 20, bottom: 20 })
          .backgroundColor('#FFFFFF')
          .borderRadius(14)
          .margin({ top: 12, bottom: 16 })

          // 控制台数据大屏
          Row() {
            Text('数据看板')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
            Blank()
            Text(`${this.jobCount} 个`)
              .fontSize(11)
              .fontColor('#999999')
          }
          .width('100%')
          .margin({ top: 4, bottom: 12 })

          // 网格数据卡片
          Grid() {
            GridItem() {
              Column() {
                Text('📄')
                  .fontSize(20)
                  .margin({ bottom: 4 })
                Text(`${this.todayResumeCount}`)
                  .fontSize(26)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#4A90D9')
                Text('今日新增简历')
                  .fontSize(10)
                  .fontColor('#888888')
                  .margin({ top: 2 })
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .borderRadius(12)
              .backgroundColor('#F0F7FF')
            }

            GridItem() {
              Column() {
                Text('✅')
                  .fontSize(20)
                  .margin({ bottom: 4 })
                Text(`${this.pendingTaskReviewCount}`)
                  .fontSize(26)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#FF8C00')
                Text('待处理微任务')
                  .fontSize(10)
                  .fontColor('#888888')
                  .margin({ top: 2 })
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .borderRadius(12)
              .backgroundColor('#FFF8F0')
            }

            GridItem() {
              Column() {
                Text('🤖')
                  .fontSize(20)
                  .margin({ bottom: 4 })
                Text(`${this.todayAIInterviewCount}`)
                  .fontSize(26)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(AppConstants.COLOR_ACCENT)
                Text('今日AI面试')
                  .fontSize(10)
                  .fontColor('#888888')
                  .margin({ top: 2 })
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .borderRadius(12)
              .backgroundColor('#FFF3EE')
            }

            GridItem() {
              Column() {
                Text('💼')
                  .fontSize(20)
                  .margin({ bottom: 4 })
                Text(`${this.jobCount}`)
                  .fontSize(26)
                  .fontWeight(FontWeight.Bold)
                  .fontColor('#52C41A')
                Text('在招岗位')
                  .fontSize(10)
                  .fontColor('#888888')
                  .margin({ top: 2 })
              }
              .width('100%')
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .borderRadius(12)
              .backgroundColor('#F0FFF0')
            }
          }
          .columnsTemplate('1fr 1fr')
          .rowsTemplate('1fr 1fr')
          .columnsGap(10)
          .rowsGap(10)
          .width('100%')
          .height(200)
          .margin({ bottom: 16 })

          // AI虚拟人多模态评估入口
          Column() {
            Row() {
              Column() {
                Row() {
                  Text('AI 虚拟人一面评估')
                    .fontSize(15)
                    .fontWeight(FontWeight.Bold)
                    .fontColor('#1A1A1A')
                  if (this.unreviewedCount > 0) {
                    Text(`${this.unreviewedCount}`)
                      .fontSize(11).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
                      .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                      .backgroundColor('#FF4D4F').borderRadius(9)
                      .margin({ left: 8 })
                  }
                }
                Text('多模态人才画像白皮书')
                  .fontSize(11)
                  .fontColor('#999999')
                  .margin({ top: 2 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Row() {
                Circle({ width: 7, height: 7 })
                  .fill(this.assessmentList.length > 0 ? '#52C41A' : '#D9D9D9')
                  .margin({ right: 4 })
                Text(this.assessmentList.length > 0 ? `${this.assessmentList.length} 份报告` : '暂无数据')
                  .fontSize(11)
                  .fontColor('#999999')
              }
              .margin({ right: 10 })
              Button(this.showAIDashboard ? '收起 ▲' : '展开 ▼')
                .fontSize(11)
                .height(28)
                .backgroundColor('#F5F5F5')
                .fontColor('#666666')
                .borderRadius(14)
                .padding({ left: 10, right: 10 })
                .onClick(() => {
                  this.showAIDashboard = !this.showAIDashboard
                  if (this.showAIDashboard) this.loadAssessments()
                })
            }
            .width('100%')

            if (this.showAIDashboard) {
              Column() {
                Divider().height(1).color('#F0F0F0').margin({ top: 14, bottom: 12 })

                if (this.assessmentLoading) {
                  Column() {
                    LoadingProgress().width(24).height(24).color(AppConstants.COLOR_ACCENT)
                    Text('加载评估数据...').fontSize(12).fontColor('#999999').margin({ top: 8 })
                  }
                  .width('100%')
                  .padding({ top: 20, bottom: 20 })
                } else if (this.assessmentList.length === 0) {
                  Column() {
                    Text('📊').fontSize(36).margin({ bottom: 8 })
                    Text('暂无完成的AI评估')
                      .fontSize(13).fontColor('#999999')
                    Text('勾选简历发送邀请，学生完成后自动生成')
                      .fontSize(11).fontColor('#CCCCCC').margin({ top: 4 })
                  }
                  .width('100%')
                  .padding({ top: 16, bottom: 16 })
                } else {
                  List() {
                    ForEach(this.assessmentList, (item: AssessmentSummaryItem) => {
                      ListItem() {
                        Row() {
                          // 头像
                          Text(item.applicantName.charAt(0))
                            .fontSize(16)
                            .fontWeight(FontWeight.Bold)
                            .fontColor('#FFFFFF')
                            .width(38)
                            .height(38)
                            .textAlign(TextAlign.Center)
                            .backgroundColor(item.recommendation ? (item.totalScore >= 80 ? '#52C41A' : (item.totalScore >= 60 ? '#FAAD14' : '#FF4D4F')) : AppConstants.COLOR_ACCENT)
                            .borderRadius(19)
                            .margin({ right: 10 })
                          Column() {
                            Text(item.applicantName)
                              .fontSize(14)
                              .fontWeight(FontWeight.Medium)
                              .fontColor('#1A1A1A')
                            Row() {
                              if (item.school) {
                                Text(item.school)
                                  .fontSize(10)
                                  .fontColor('#AAAAAA')
                              }
                              if (item.jobTitle) {
                                Text(` · ${item.jobTitle}`)
                                  .fontSize(10)
                                  .fontColor('#AAAAAA')
                                  .maxLines(1)
                                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                              }
                            }
                            .margin({ top: 2 })
                          }
                          .alignItems(HorizontalAlign.Start)
                          .layoutWeight(1)

                          Column() {
                            if (item.status === 'reviewed') {
                              Text(String(item.totalScore))
                                .fontSize(22)
                                .fontWeight(FontWeight.Bold)
                                .fontColor(item.totalScore >= 80 ? '#52C41A' : (item.totalScore >= 60 ? '#FAAD14' : '#FF4D4F'))
                              Text('已评估')
                                .fontSize(10)
                                .fontColor('#999999')
                                .padding({ left: 6, right: 6, top: 1, bottom: 1 })
                                .backgroundColor('#F5F5F5')
                                .borderRadius(4)
                            } else if (item.recommendation) {
                              Text(String(item.totalScore))
                                .fontSize(22)
                                .fontWeight(FontWeight.Bold)
                                .fontColor(item.totalScore >= 80 ? '#52C41A' : (item.totalScore >= 60 ? '#FAAD14' : '#FF4D4F'))
                              Text(item.recommendation)
                                .fontSize(10)
                                .fontColor(item.recommendation.indexOf('建议录用') >= 0 ? '#52C41A' : '#999999')
                            } else {
                              Text('待评估')
                                .fontSize(12)
                                .fontWeight(FontWeight.Bold)
                                .fontColor(AppConstants.COLOR_ACCENT)
                                .padding({ left: 8, right: 8, top: 3, bottom: 3 })
                                .backgroundColor('#FFF3EE')
                                .borderRadius(8)
                            }
                          }
                          .alignItems(HorizontalAlign.End)

                          Image($r('sys.symbol.chevron_right'))
                            .width(12)
                            .height(12)
                            .fillColor('#CCCCCC')
                            .margin({ left: 6 })
                        }
                        .width('100%')
                        .padding({ top: 10, bottom: 10 })
                        .onClick(() => {
                          router.pushUrl({
                            url: AppConstants.ROUTE_RECRUITER_AI_ASSESSMENT,
                            params: {
                              sessionId: item.interviewId,
                              studentName: item.applicantName,
                              jobTitle: item.jobTitle,
                              applicationId: item.applicationId || '',
                              userId: item.userId || ''
                            }
                          })
                        })
                      }
                    })
                  }
                  .width('100%')
                  .constraintSize({ maxHeight: 280 })
                  .divider({ strokeWidth: 0.5, color: '#F0F0F0', startMargin: 48 })
                }

                Button('＋ 勾选简历发送评估邀请')
                  .width('100%')
                  .height(40)
                  .fontSize(13)
                  .fontWeight(FontWeight.Medium)
                  .backgroundColor('#FFF3EE')
                  .fontColor(AppConstants.COLOR_ACCENT)
                  .borderRadius(10)
                  .margin({ top: 14 })
                  .onClick(() => {
                    this.showInbox = true
                    this.inboxSelectMode = true
                  })
              }
              .width('100%')
              .margin({ top: 4 })
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor('#FFFFFF')
          .borderRadius(14)
          .margin({ bottom: 12 })

          // 功能菜单
          Column() {
            Column() {
              this.MenuItem('📋', '#4A90D9', '#EBF4FF', '已发布岗位管理', '查看和管理所有在招岗位')
            }
            .onClick(() => { this.loadManagedJobs(); this.showJobMgmt = true })

            Column() {
              this.MenuItem('📥', '#52C41A', '#EDFFF3', '简历收件箱', '查看已投递的学生简历')
            }
            .onClick(() => { this.loadInbox(); this.showInbox = true })

            Column() {
              this.MenuItem('📅', '#FF8C00', '#FFF8F0', '面试排期管理', '管理面试时间和安排')
            }
            .onClick(() => { this.loadInterviewList(); this.showInterviewMgmt = true })

            Column() {
              this.MenuItem('🔍', AppConstants.COLOR_ACCENT, '#FFF3EE', '人才搜索历史', '查看所有投递者记录')
            }
            .onClick(() => { this.loadApplicantList(); this.showTalentHistory = true })

            Column() {
              this.MenuItem('📊', '#FF4D4F', '#FFF1F0', '数据分析报告', '招聘数据统计与分析')
            }
            .onClick(() => { this.loadDataReport(); this.showDataReport = true })
          }
          .width('100%')
          .padding({ left: 4, right: 4 })
          .backgroundColor('#FFFFFF')
          .borderRadius(14)
          .margin({ bottom: 12 })

          // 设置与认证
          Column() {
            Column() {
              this.MenuItem('🔐', '#333333', '#F5F5F5', this.getAuthMenuTitle(), this.getAuthMenuSubtitle())
            }
            .onClick(() => router.pushUrl({ url: AppConstants.ROUTE_RECRUITER_AUTH, params: { mode: 'manage' } }))

            Column() {
              this.MenuItem('⚙️', '#666666', '#F5F5F5', '账号设置', '修改密码和通知设置')
            }
            .onClick(() => this.showSettings = true)
          }
          .width('100%')
          .padding({ left: 4, right: 4 })
          .backgroundColor('#FFFFFF')
          .borderRadius(14)
          .margin({ bottom: 20 })

          // 退出
          Button('退出登录')
            .width('100%')
            .height(46)
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .backgroundColor('#FF6B35')
            .fontColor('#fff')
            .borderRadius(14)
            .border({ width: 1, color: '#FFE0E0' })
            .margin({ bottom: 24 })
            .onClick(async () => {
              await this.userDao.logoutAll()
              AppState.currentUser = null
              AppState.isLoggedIn = false
              AppState.isGuest = true
              AppState.syncToStorage()
              router.replaceUrl({ url: AppConstants.ROUTE_INDEX })
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16 })
      }
      .width('100%')
      .layoutWeight(1)
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F5F5F5')

    // 设置弹窗
    if (this.showSettings) {
      Column() {
        Column()
          .width('100%')
          .layoutWeight(1)
          .backgroundColor('rgba(0,0,0,0.5)')
          .onClick(() => {
            this.showSettings = false
            this.oldPassword = ''
            this.newPassword = ''
            this.confirmPassword = ''
          })

        Column() {
          // 拖拽指示条
          Row() {
            Rect().width(36).height(4).radius(2).fill('#E0E0E0')
          }
          .width('100%')
          .justifyContent(FlexAlign.Center)
          .margin({ bottom: 20 })

          Row() {
            Text('账号设置')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
            Blank()
            Button({ type: ButtonType.Circle }) {
              Image($r('sys.symbol.xmark'))
                .width(16).height(16).fillColor('#999999')
            }
            .width(28).height(28).backgroundColor('#F5F5F5')
            .onClick(() => {
              this.showSettings = false
              this.oldPassword = ''
              this.newPassword = ''
              this.confirmPassword = ''
            })
          }
          .width('100%')
          .margin({ bottom: 20 })

          Text('修改密码')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor('#333333')
            .margin({ bottom: 12 })
            .alignSelf(ItemAlign.Start)

          TextInput({ text: this.oldPassword, placeholder: '请输入当前密码' })
            .width('100%').height(46).fontSize(14)
            .placeholderColor('#BBBBBB')
            .type(InputType.Password)
            .backgroundColor('#F8F8F8')
            .borderRadius(10)
            .padding({ left: 14 })
            .margin({ bottom: 12 })
            .onChange((v: string) => this.oldPassword = v)

          TextInput({ text: this.newPassword, placeholder: '请输入新密码（至少6位）' })
            .width('100%').height(46).fontSize(14)
            .placeholderColor('#BBBBBB')
            .type(InputType.Password)
            .backgroundColor('#F8F8F8')
            .borderRadius(10)
            .padding({ left: 14 })
            .margin({ bottom: 12 })
            .onChange((v: string) => this.newPassword = v)

          TextInput({ text: this.confirmPassword, placeholder: '请再次输入新密码' })
            .width('100%').height(46).fontSize(14)
            .placeholderColor('#BBBBBB')
            .type(InputType.Password)
            .backgroundColor('#F8F8F8')
            .borderRadius(10)
            .padding({ left: 14 })
            .margin({ bottom: 24 })
            .onChange((v: string) => this.confirmPassword = v)

          Button('确认修改密码')
            .width('100%')
            .height(46)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .backgroundColor(AppConstants.COLOR_ACCENT)
            .fontColor('#FFFFFF')
            .borderRadius(12)
            .margin({ bottom: 10 })
            .onClick(async () => {
              const user = AppState.currentUser
              if (!user) return
              if (!this.oldPassword) {
                AlertDialog.show({ message: '请输入当前密码' })
                return
              }
              if (this.oldPassword !== user.password) {
                AlertDialog.show({ message: '当前密码不正确' })
                return
              }
              if (!this.newPassword || this.newPassword.length < 6) {
                AlertDialog.show({ message: '新密码至少6位' })
                return
              }
              if (this.newPassword !== this.confirmPassword) {
                AlertDialog.show({ message: '两次输入的新密码不一致' })
                return
              }
              await this.userDao.updatePassword(user.userId, this.newPassword)
              user.password = this.newPassword
              AppState.currentUser = user
              AppState.syncToStorage()
              this.showSettings = false
              this.oldPassword = ''
              this.newPassword = ''
              this.confirmPassword = ''
              AlertDialog.show({ message: '密码修改成功' })
            })

          Button('取消')
            .width('100%')
            .height(44)
            .fontSize(14)
            .backgroundColor('#F5F5F5')
            .fontColor('#666666')
            .borderRadius(12)
            .onClick(() => {
              this.showSettings = false
              this.oldPassword = ''
              this.newPassword = ''
              this.confirmPassword = ''
            })
        }
        .width('100%')
        .padding({ left: 24, right: 24, top: 16, bottom: 30 })
        .backgroundColor('#FFFFFF')
        .borderRadius({ topLeft: 20, topRight: 20 })
      }
      .width('100%')
      .height('100%')
      .position({ x: 0, y: 0 })
    }

    if (this.showInterviewMgmt) {
      this.InterviewMgmtDialog()
    }

    if (this.showTalentHistory) {
      this.TalentHistoryDialog()
    }

    if (this.showDataReport) {
      this.DataReportDialog()
    }

    if (this.showJobMgmt) {
      this.JobMgmtDialog()
    }

    if (this.showInbox) {
      this.InboxDialog()
    }
    }
  }

  @Builder
  MenuItem(icon: string, iconColor: string, iconBg: string, title: string, subtitle: string) {
    Row() {
      Text(icon)
        .fontSize(16)
        .width(38)
        .height(38)
        .textAlign(TextAlign.Center)
        .backgroundColor(iconBg)
        .borderRadius(10)
        .margin({ right: 12 })
      Column() {
        Text(title)
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor('#1A1A1A')
        Text(subtitle)
          .fontSize(11)
          .fontColor('#AAAAAA')
          .margin({ top: 2 })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Image($r('sys.symbol.chevron_right'))
        .width(12)
        .height(12)
        .fillColor('#CCCCCC')
    }
    .width('100%')
    .padding({ top: 13, bottom: 13 })
    .border({ width: { bottom: 0.5 }, color: '#F5F5F5' })
  }

  // ==================== 已发布岗位管理 ====================

  @Builder
  JobMgmtDialog() {
    Column() {
      Column()
        .width('100%')
        .layoutWeight(1)
        .backgroundColor('rgba(0,0,0,0.5)')
        .onClick(() => this.showJobMgmt = false)

      Column() {
        Row() {
          Rect().width(36).height(4).radius(2).fill('#E0E0E0')
        }
        .width('100%').justifyContent(FlexAlign.Center).margin({ bottom: 18 })

        Row() {
          Text('已发布岗位管理')
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
          Blank()
          Button({ type: ButtonType.Circle }) {
            Image($r('sys.symbol.xmark')).width(16).height(16).fillColor('#999999')
          }
          .width(28).height(28).backgroundColor('#F5F5F5')
          .onClick(() => this.showJobMgmt = false)
        }
        .width('100%').margin({ bottom: 8 })

        Text(`共 ${this.managedJobList.length} 个在招岗位`)
          .fontSize(12).fontColor('#999999').margin({ bottom: 14 }).alignSelf(ItemAlign.Start)

        if (this.managedJobList.length === 0) {
          Column() {
            Text('📋').fontSize(40).margin({ bottom: 8 })
            Text('暂无已发布的岗位').fontSize(14).fontColor('#999999')
          }
          .width('100%').padding({ top: 40, bottom: 40 })
        } else {
          List() {
            ForEach(this.managedJobList, (job: ManagedJob) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(job.title)
                      .fontSize(15).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
                    Row() {
                      Text(`浏览 ${job.viewCount}`).fontSize(11).fontColor('#999999')
                      Text(`  ·  投递 ${job.applyCount}`).fontSize(11).fontColor(AppConstants.COLOR_PRIMARY)
                    }
                    .margin({ top: 4 })
                  }
                  .alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Button('关闭岗位')
                    .fontSize(11).height(28)
                    .backgroundColor('#FFF1F0').fontColor('#FF4D4F').borderRadius(14)
                    .onClick(async () => {
                      const store = await DatabaseHelper.getInstance().getStore()
                      await store.executeSql(`UPDATE ${TABLE_JOB} SET status = 'closed' WHERE job_id = '${job.jobId}'`)
                      this.loadManagedJobs()
                      this.loadStats()
                    })
                }
                .width('100%').padding({ top: 12, bottom: 12 })
                .onClick(() => router.pushUrl({ url: AppConstants.ROUTE_RECRUITER_JOB_MANAGE, params: { jobId: job.jobId } }))
              }
            })
          }
          .width('100%').constraintSize({ maxHeight: 400 })
          .divider({ strokeWidth: 0.5, color: '#F0F0F0' })
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 14, bottom: 30 })
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%').height('100%').position({ x: 0, y: 0 })
  }

  // ==================== 简历收件箱 ====================

  @Builder
  InboxDialog() {
    Column() {
      Column()
        .width('100%').layoutWeight(1)
        .backgroundColor('rgba(0,0,0,0.5)')
        .onClick(() => {
          this.showInbox = false; this.inboxSelectMode = false; this.selectedInboxIds.clear()
        })

      Column() {
        Row() {
          Rect().width(36).height(4).radius(2).fill('#E0E0E0')
        }
        .width('100%').justifyContent(FlexAlign.Center).margin({ bottom: 18 })

        Row() {
          Text('简历收件箱')
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
          Blank()
          Button(this.inboxSelectMode ? '取消' : '选择')
            .fontSize(12).height(28)
            .backgroundColor('#F5F5F5').fontColor('#666666')
            .borderRadius(14).padding({ left: 12, right: 12 }).margin({ right: 8 })
            .onClick(() => {
              this.inboxSelectMode = !this.inboxSelectMode
              if (!this.inboxSelectMode) this.selectedInboxIds.clear()
            })
          Button({ type: ButtonType.Circle }) {
            Image($r('sys.symbol.xmark')).width(16).height(16).fillColor('#999999')
          }
          .width(28).height(28).backgroundColor('#F5F5F5')
          .onClick(() => {
            this.showInbox = false; this.inboxSelectMode = false; this.selectedInboxIds.clear()
          })
        }
        .width('100%').margin({ bottom: 8 })

        Text(this.inboxSelectMode ? '勾选简历发送AI面试邀请' : `共 ${this.inboxList.length} 份简历`)
          .fontSize(12).fontColor('#999999').margin({ bottom: 14 }).alignSelf(ItemAlign.Start)

        if (this.inboxList.length === 0) {
          Column() {
            Text('📬').fontSize(40).margin({ bottom: 8 })
            Text('暂无收到的简历').fontSize(14).fontColor('#999999')
          }
          .width('100%').padding({ top: 40, bottom: 40 })
        } else {
          List() {
            ForEach(this.inboxList, (item: InboxItem) => {
              ListItem() {
                Row() {
                  if (this.inboxSelectMode) {
                    Checkbox()
                      .margin({ right: 10 })
                      .select(this.selectedInboxIds.has(item.userId))
                  }
                  Column() {
                    Text(item.applicantName)
                      .fontSize(15).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
                    Text(`${item.school}`)
                      .fontSize(11).fontColor('#999999').margin({ top: 2 })
                    Row() {
                      Text(`应聘：${item.jobTitle}`).fontSize(11).fontColor('#666666')
                      Text(` · ${this.getStatusLabel(item.status)}`)
                        .fontSize(11).fontColor(this.getStatusColor(item.status))
                    }
                    .margin({ top: 2 })
                  }
                  .alignItems(HorizontalAlign.Start).layoutWeight(1)
                  if (!this.inboxSelectMode) {
                    Image($r('sys.symbol.chevron_right'))
                      .width(12).height(12).fillColor('#CCCCCC')
                  }
                }
                .width('100%').padding({ top: 12, bottom: 12 })
                .onClick(() => {
                  if (this.inboxSelectMode) {
                    const newSet = new Set(this.selectedInboxIds)
                    if (newSet.has(item.userId)) {
                      newSet.delete(item.userId)
                    } else {
                      newSet.add(item.userId)
                    }
                    this.selectedInboxIds = newSet
                  } else {
                    this.showInbox = false
                    router.pushUrl({ url: AppConstants.ROUTE_TALENT_DETAIL, params: { userId: item.userId, jobTitle: item.jobTitle } })
                  }
                })
              }
            })
          }
          .width('100%').constraintSize({ maxHeight: 380 })
          .divider({ strokeWidth: 0.5, color: '#F0F0F0' })
        }

        if (this.inboxSelectMode && this.selectedInboxIds.size > 0) {
          Button(`发送AI面试邀请 (${this.selectedInboxIds.size})`)
            .width('100%').height(46).fontSize(15).fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF').backgroundColor(AppConstants.COLOR_ACCENT).borderRadius(12)
            .margin({ top: 14 })
            .onClick(() => {
              AlertDialog.show({
                title: '确认发送',
                message: `确定向 ${this.selectedInboxIds.size} 名学生发送AI虚拟面试邀请吗？`,
                primaryButton: { value: '发送', action: () => this.sendInterviewInvites() },
                secondaryButton: { value: '取消', action: () => {} }
              })
            })
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 14, bottom: 30 })
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%').height('100%').position({ x: 0, y: 0 })
  }

  // ==================== 面试排期管理 ====================

  @Builder
  InterviewMgmtDialog() {
    Column() {
      Column()
        .width('100%').layoutWeight(1)
        .backgroundColor('rgba(0,0,0,0.5)')
        .onClick(() => this.showInterviewMgmt = false)

      Column() {
        Row() {
          Rect().width(36).height(4).radius(2).fill('#E0E0E0')
        }
        .width('100%').justifyContent(FlexAlign.Center).margin({ bottom: 18 })

        Row() {
          Text('面试排期管理')
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
          Blank()
          Button({ type: ButtonType.Circle }) {
            Image($r('sys.symbol.xmark')).width(16).height(16).fillColor('#999999')
          }
          .width(28).height(28).backgroundColor('#F5F5F5')
          .onClick(() => this.showInterviewMgmt = false)
        }
        .width('100%').margin({ bottom: 14 })

        if (this.interviewList.length === 0) {
          Column() {
            Text('📅').fontSize(40).margin({ bottom: 8 })
            Text('暂无面试安排').fontSize(14).fontColor('#999999')
          }
          .width('100%').padding({ top: 40, bottom: 40 })
        } else {
          List() {
            ForEach(this.interviewList, (item: InterviewItem) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(item.applicantName)
                      .fontSize(15).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
                    Text(`${item.school}`).fontSize(11).fontColor('#999999').margin({ top: 2 })
                    Text(`应聘：${item.jobTitle}`).fontSize(11).fontColor('#666666').margin({ top: 2 })
                  }
                  .alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Column() {
                    Text(this.formatTime(item.interviewTime))
                      .fontSize(11).fontColor(AppConstants.COLOR_PRIMARY).margin({ bottom: 4 })
                    Text('查看详情 →').fontSize(11).fontColor('#4A90D9')
                  }
                  .alignItems(HorizontalAlign.End)
                }
                .width('100%').padding({ top: 12, bottom: 12 })
                .onClick(() => {
                  this.showInterviewMgmt = false
                  router.pushUrl({ url: AppConstants.ROUTE_TALENT_DETAIL, params: { userId: item.userId, jobTitle: item.jobTitle } })
                })
              }
            })
          }
          .width('100%').constraintSize({ maxHeight: 400 })
          .divider({ strokeWidth: 0.5, color: '#F0F0F0' })
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 14, bottom: 30 })
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%').height('100%').position({ x: 0, y: 0 })
  }

  // ==================== 人才搜索历史 ====================

  @Builder
  TalentHistoryDialog() {
    Column() {
      Column()
        .width('100%').layoutWeight(1)
        .backgroundColor('rgba(0,0,0,0.5)')
        .onClick(() => this.showTalentHistory = false)

      Column() {
        Row() {
          Rect().width(36).height(4).radius(2).fill('#E0E0E0')
        }
        .width('100%').justifyContent(FlexAlign.Center).margin({ bottom: 18 })

        Row() {
          Text('人才搜索记录')
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
          Blank()
          Button({ type: ButtonType.Circle }) {
            Image($r('sys.symbol.xmark')).width(16).height(16).fillColor('#999999')
          }
          .width(28).height(28).backgroundColor('#F5F5F5')
          .onClick(() => this.showTalentHistory = false)
        }
        .width('100%').margin({ bottom: 8 })

        Text(`共 ${this.applicantList.length} 位投递者`)
          .fontSize(12).fontColor('#999999').margin({ bottom: 14 }).alignSelf(ItemAlign.Start)

        if (this.applicantList.length === 0) {
          Column() {
            Text('🔍').fontSize(40).margin({ bottom: 8 })
            Text('暂无投递记录').fontSize(14).fontColor('#999999')
          }
          .width('100%').padding({ top: 40, bottom: 40 })
        } else {
          List() {
            ForEach(this.applicantList, (item: ApplicantItem) => {
              ListItem() {
                Row() {
                  Column() {
                    Text(item.applicantName)
                      .fontSize(15).fontWeight(FontWeight.Medium).fontColor('#1A1A1A')
                    Text(`${item.school} · ${item.major}`)
                      .fontSize(11).fontColor('#999999').margin({ top: 2 })
                    Row() {
                      Text(item.jobTitle).fontSize(11).fontColor('#666666')
                      Text(` · ${this.getStatusLabel(item.status)}`)
                        .fontSize(11).fontColor(this.getStatusColor(item.status))
                    }
                    .margin({ top: 2 })
                  }
                  .alignItems(HorizontalAlign.Start).layoutWeight(1)
                  Image($r('sys.symbol.chevron_right'))
                    .width(12).height(12).fillColor('#CCCCCC')
                }
                .width('100%').padding({ top: 12, bottom: 12 })
                .onClick(() => {
                  this.showTalentHistory = false
                  router.pushUrl({ url: AppConstants.ROUTE_TALENT_DETAIL, params: { userId: item.userId, jobTitle: item.jobTitle } })
                })
              }
            })
          }
          .width('100%').constraintSize({ maxHeight: 400 })
          .divider({ strokeWidth: 0.5, color: '#F0F0F0' })
        }
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 14, bottom: 30 })
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%').height('100%').position({ x: 0, y: 0 })
  }

  // ==================== 数据分析报告 ====================

  @Builder
  DataReportDialog() {
    Column() {
      Column()
        .width('100%').layoutWeight(1)
        .backgroundColor('rgba(0,0,0,0.5)')
        .onClick(() => this.showDataReport = false)

      Column() {
        Row() {
          Rect().width(36).height(4).radius(2).fill('#E0E0E0')
        }
        .width('100%').justifyContent(FlexAlign.Center).margin({ bottom: 18 })

        Row() {
          Text('数据分析报告')
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#1A1A1A')
          Blank()
          Button({ type: ButtonType.Circle }) {
            Image($r('sys.symbol.xmark')).width(16).height(16).fillColor('#999999')
          }
          .width(28).height(28).backgroundColor('#F5F5F5')
          .onClick(() => this.showDataReport = false)
        }
        .width('100%').margin({ bottom: 16 })

        Text('岗位概况')
          .fontSize(14).fontWeight(FontWeight.Medium).fontColor('#333333')
          .margin({ bottom: 10 }).alignSelf(ItemAlign.Start)
        Row() {
          this.ReportCard('已发布', `${this.reportPublishedJobs}`, '#4A90D9', '#F0F7FF')
          this.ReportCard('草稿/关闭', `${this.reportDraftJobs}`, '#FAAD14', '#FFF8F0')
        }
        .width('100%').justifyContent(FlexAlign.SpaceBetween).margin({ bottom: 16 })
        Divider().height(1).color('#F0F0F0').margin({ bottom: 16 })

        Text('投递概况')
          .fontSize(14).fontWeight(FontWeight.Medium).fontColor('#333333')
          .margin({ bottom: 10 }).alignSelf(ItemAlign.Start)
        Grid() {
          GridItem() {
            Column() {
              Text(`${this.reportTotalApps}`).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#4A90D9')
              Text('总投递').fontSize(10).fontColor('#999999').margin({ top: 2 })
            }
            .width('100%').height('100%').justifyContent(FlexAlign.Center)
            .backgroundColor('#F0F7FF').borderRadius(10)
          }
          GridItem() {
            Column() {
              Text(`${this.reportInterviewApps}`).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#FF8C00')
              Text('面试中').fontSize(10).fontColor('#999999').margin({ top: 2 })
            }
            .width('100%').height('100%').justifyContent(FlexAlign.Center)
            .backgroundColor('#FFF8F0').borderRadius(10)
          }
          GridItem() {
            Column() {
              Text(`${this.reportHiredApps}`).fontSize(22).fontWeight(FontWeight.Bold).fontColor('#52C41A')
              Text('已录用').fontSize(10).fontColor('#999999').margin({ top: 2 })
            }
            .width('100%').height('100%').justifyContent(FlexAlign.Center)
            .backgroundColor('#F0FFF0').borderRadius(10)
          }
          GridItem() {
            Column() {
              Text(`${this.computeConversionRate()}%`).fontSize(22).fontWeight(FontWeight.Bold).fontColor(AppConstants.COLOR_ACCENT)
              Text('转化率').fontSize(10).fontColor('#999999').margin({ top: 2 })
            }
            .width('100%').height('100%').justifyContent(FlexAlign.Center)
            .backgroundColor('#FFF3EE').borderRadius(10)
          }
        }
        .columnsTemplate('1fr 1fr').rowsTemplate('1fr 1fr')
        .columnsGap(10).rowsGap(10)
        .width('100%').height(170).margin({ bottom: 16 })
        Divider().height(1).color('#F0F0F0').margin({ bottom: 16 })

        Column() {
          this.SummaryLine('岗位平均投递数', this.reportPublishedJobs > 0 ? `${(this.reportTotalApps / this.reportPublishedJobs).toFixed(1)} 份` : '暂无数据')
          this.SummaryLine('面试转化率', `${this.computeConversionRate()}%`)
          this.SummaryLine('当前在招岗位', `${this.jobCount} 个`)
          this.SummaryLine('累计收到简历', `${this.todayResumeCount} 份`)
        }
        .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 14, bottom: 30 })
      .backgroundColor('#FFFFFF')
      .borderRadius({ topLeft: 20, topRight: 20 })
    }
    .width('100%').height('100%').position({ x: 0, y: 0 })
  }

  @Builder
  ReportCard(label: string, value: string, valueColor: string, bgColor: string) {
    Column() {
      Text(value)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(valueColor)
      Text(label)
        .fontSize(11)
        .fontColor('#999999')
        .margin({ top: 2 })
    }
    .width('47%')
    .height(60)
    .justifyContent(FlexAlign.Center)
    .backgroundColor(bgColor)
    .borderRadius(8)
  }

  @Builder
  SummaryLine(label: string, value: string) {
    Row() {
      Text(label)
        .fontSize(12)
        .fontColor('#999999')
      Blank()
      Text(value)
        .fontSize(12)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1A1A1A')
    }
    .width('100%')
    .margin({ bottom: 8 })
  }

  formatTime(timestamp: number): string {
    if (!timestamp || timestamp <= 0) return '待定'
    const d = new Date(timestamp)
    const month = (d.getMonth() + 1).toString().padStart(2, '0')
    const day = d.getDate().toString().padStart(2, '0')
    const hour = d.getHours().toString().padStart(2, '0')
    const min = d.getMinutes().toString().padStart(2, '0')
    return `${month}-${day} ${hour}:${min}`
  }

  getStatusLabel(status: string): string {
    switch (status) {
      case 'submitted': return '待查看'
      case 'viewed': return '已查看'
      case 'interview': return '面试中'
      case 'offered': return '已录用'
      case 'rejected': return '未通过'
      default: return status
    }
  }

  getStatusColor(status: string): string {
    switch (status) {
      case 'submitted': return '#999999'
      case 'viewed': return '#4A90D9'
      case 'interview': return AppConstants.COLOR_ACCENT
      case 'offered': return AppConstants.COLOR_SUCCESS
      case 'rejected': return AppConstants.COLOR_DANGER
      default: return '#999999'
    }
  }

  computeConversionRate(): number {
    if (this.reportTotalApps > 0) return Math.round((this.reportHiredApps / this.reportTotalApps) * 100)
    return 0
  }

  getMatchRate(): number {
    if (this.todayResumeCount > 0 && this.jobCount > 0) return Math.round((this.todayResumeCount / (this.jobCount * 5)) * 100)
    return 0
  }

  getCompanyInitial(): string {
    const name = AppState.currentUser?.companyName || '企'
    return name.charAt(0)
  }

  getAuthStatusText(): string {
    const status = AppState.currentUser?.authStatus ?? 0
    switch (status) {
      case AuthStatus.PENDING: return '认证审核中'
      case AuthStatus.APPROVED: return '已认证'
      case AuthStatus.REJECTED: return '认证未通过'
      default: return '未认证'
    }
  }

  getAuthStatusColor(): string {
    const status = AppState.currentUser?.authStatus ?? 0
    switch (status) {
      case AuthStatus.PENDING: return AppConstants.COLOR_WARNING
      case AuthStatus.APPROVED: return AppConstants.COLOR_SUCCESS
      case AuthStatus.REJECTED: return AppConstants.COLOR_DANGER
      default: return '#999999'
    }
  }

  getAuthStatusBgColor(): string {
    const status = AppState.currentUser?.authStatus ?? 0
    switch (status) {
      case AuthStatus.PENDING: return '#FFFBE6'
      case AuthStatus.APPROVED: return '#F0FFF0'
      case AuthStatus.REJECTED: return '#FFF1F0'
      default: return '#F5F5F5'
    }
  }

  getAuthMenuTitle(): string {
    const status = AppState.currentUser?.authStatus ?? 0
    switch (status) {
      case AuthStatus.PENDING: return '企业认证管理 (审核中)'
      case AuthStatus.REJECTED: return '企业认证管理 (未通过)'
      case AuthStatus.APPROVED: return '企业认证管理 (已认证)'
      default: return '企业认证管理'
    }
  }

  getAuthMenuSubtitle(): string {
    const status = AppState.currentUser?.authStatus ?? 0
    switch (status) {
      case AuthStatus.REJECTED: return '点击重新提交认证信息'
      case AuthStatus.PENDING: return '预计1-2个工作日内完成审核'
      case AuthStatus.APPROVED: return '管理营业执照和实名认证'
      default: return '完成认证后即可发布岗位'
    }
  }
}
