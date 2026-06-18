import { DeepSeekService } from './DeepSeekService'
import { UserDao } from './UserDao'
import { ResumeDao } from './ResumeDao'
import { FreeTimeSlot } from '../model/ResumeModel'
import { UserRole } from '../model/UserModel'
import { DatabaseHelper } from '../database/DatabaseHelper'
import { TABLE_AI_INTERVIEW, TABLE_APPLICATION, TABLE_JOB, TABLE_USER } from '../database/Tables'

export interface AIRedFlagScanResult {
  hasRedFlags: boolean
  detectedFlags: string[]
  riskLevel: 'safe' | 'warning' | 'danger'
  analysis: string
}

export interface AIScheduleMatch {
  studentName: string
  studentId: string
  school: string
  major: string
  freeSlots: string[]
  freeSlotDetails: FreeTimeSlot[]
  matchScore: number
  complementarity: string
}

interface RedFlagPayload {
  description: string
  title: string
}

interface RedFlagAIResult {
  hasRedFlags: boolean
  detectedFlags: string[]
  riskLevel: 'safe' | 'warning' | 'danger'
  analysis: string
}

interface ScheduleCandidate {
  userId: string
  name: string
  school: string
  major: string
  freeSlots: string[]
  freeSlotDetails: FreeTimeSlot[]
  expectedPosition: string
}

interface ScheduleMatchPayload {
  taskTitle: string
  taskRequirements: string
  candidates: ScheduleCandidate[]
}

interface ScheduleMatchAIResult {
  matches: AIScheduleMatch[]
  summary: string
}

export interface SchedulePuzzleResult {
  matches: AIScheduleMatch[]
  summary: string
}

interface QuestionGenPayload {
  jobTitle: string
  jobDescription: string
  skills: string[]
  resumeText: string
  questionCount: number
}

interface QuestionGenResult {
  questions: AIInterviewQuestion[]
}

interface EvaluationPayload {
  jobTitle: string
  resumeText: string
  questions: AIInterviewQuestion[]
  answers: AIInterviewAnswer[]
}

export class RecruiterAIService {
  // 创新点一：AI辅助生成岗位描述
  static async generateJobDescription(keywords: string, title: string, category: string, education: string, salary: string): Promise<string> {
    const systemPrompt = [
      '你是一个面向大学生群体的招聘描述撰写助手。',
      '你需要根据HR提供的关键词和岗位信息，直接生成一份规范的、有学生气的校园招聘描述。',
      '严格格式要求：分为【岗位职责】、【任职要求】、【我们提供】三个板块。',
      '如果关键词中包含具体技术栈（如Python、Java、Vue等），要在职责中具体体现。',
      '薪资和学历要求要如实反映在描述中。',
      '控制在200-400字。',
      '【绝对禁止事项】',
      '1. 禁止使用任何Markdown格式符号（如**、*、#、```等），只用纯文本',
      '2. 禁止包含任何对话式语言，如"好的"、"没问题"、"很高兴为您"、"以下是"等开场白或结束语',
      '3. 直接输出岗位描述内容，不要有任何前缀说明或后缀寒暄'
    ].join(' ')

    const categoryLabel = category === 'micro_task' ? '微任务/兼职' : '全职/实习'
    const userPrompt = [
      `关键词：${keywords}`,
      `岗位名称：${title || '未指定'}`,
      `岗位类型：${categoryLabel}`,
      `学历要求：${education || '未指定'}`,
      `薪资范围：${salary || '面议'}`,
      '请生成招聘描述。'
    ].join('\n')

    return DeepSeekService.chatText(systemPrompt, userPrompt)
  }

  // 创新点三：AI红线扫描仪
  static async scanForRedFlags(title: string, description: string): Promise<AIRedFlagScanResult> {
    // 第一道：关键词快速匹配（毫秒级拦截）
    const fastKeywords = [
      '自费培训', '保证金', '自备高配电脑', '押金', '押证',
      '培训费', '中介费', '介绍费', '入职费', '工装费',
      '体检费', '办证费', '垫付', '刷单', '网贷',
      '先交钱', '预付', '转账到个人', '线下交费'
    ]
    const fastHits: string[] = []
    const combinedText = `${title} ${description}`
    for (const kw of fastKeywords) {
      if (combinedText.indexOf(kw) >= 0) {
        fastHits.push(kw)
      }
    }
    if (fastHits.length > 0) {
      return {
        hasRedFlags: true,
        detectedFlags: fastHits,
        riskLevel: 'danger',
        analysis: `关键词匹配检测到以下高风险词汇：${fastHits.join('、')}。这些词汇属于招聘骗局常见话术，已被立即拦截。`
      }
    }

    // 第二道：AI语义分析（深度扫描）
    try {
      const payload: RedFlagPayload = {
        description: description,
        title: title
      }
      const result = await DeepSeekService.chatJson<RedFlagAIResult>(
        [
          '你是大学生招聘平台的防骗审查助手。',
          '分析岗位描述，检测是否存在以下风险：',
          '1. 要求求职者付费（培训费、押金、保证金、材料费等任何费用）',
          '2. 要求自备贵重设备（高配电脑、专业设备等）',
          '3. 诱导线下交易或私下转账',
          '4. 薪资描述严重不实（如夸大收入、传销式描述）',
          '5. 要求提供身份证、银行卡等敏感个人信息',
          '6. 工作内容不明确，仅强调"轻松""高薪""在家可做"',
          '7. 公司信息模糊或查不到',
          '8. 要求先试工不给钱',
          '9. 刷单、刷信誉、网贷相关',
          '返回JSON：hasRedFlags(boolean), detectedFlags(string数组), riskLevel("safe"/"warning"/"danger"), analysis(中文分析说明)',
          '如果没有风险，hasRedFlags为false，detectedFlags为空数组，riskLevel为safe。',
          '只在确实检测到问题时才标记为warning或danger。'
        ].join(' '),
        JSON.stringify(payload)
      )
      return {
        hasRedFlags: result.hasRedFlags || false,
        detectedFlags: result.detectedFlags || [],
        riskLevel: result.riskLevel || 'safe',
        analysis: result.analysis || ''
      }
    } catch (e) {
      // AI分析失败时，仅依赖关键词匹配结果（已通过）
      const fallback: AIRedFlagScanResult = {
        hasRedFlags: false,
        detectedFlags: [],
        riskLevel: 'safe',
        analysis: ''
      }
      return fallback
    }
  }

  // 创新点四：AI智能工时拼图
  static async matchSchedulePuzzle(
    taskTitle: string,
    taskRequirements: string,
    candidates: ScheduleCandidate[]
  ): Promise<SchedulePuzzleResult> {
    if (candidates.length === 0) {
      const emptyResult: SchedulePuzzleResult = {
        matches: [],
        summary: '暂无导入课表的学生，建议在岗位详情中注明弹性工作时间。'
      }
      return emptyResult
    }

    const payload: ScheduleMatchPayload = {
      taskTitle: taskTitle,
      taskRequirements: taskRequirements,
      candidates: candidates
    }

    try {
      const result = await DeepSeekService.chatJson<ScheduleMatchAIResult>(
        [
          '你是一个大学生兼职排班调度助手。',
          '分析岗位需求和学生空闲时间，找出时间互补、能够配对覆盖岗位时段的学生组合。',
          '重点关注：哪些学生的空闲时段与岗位要求的时段匹配，哪些学生可以互补组合。',
          '返回JSON：matches数组（每个包含studentName, studentId, school, major, freeSlots, matchScore(0-100), complementarity(中文说明)），summary(中文总结)',
          '按matchScore从高到低排序，最多返回5个匹配结果。',
          'complementarity字段说明该学生的时间如何与岗位匹配，如有多人互补方案也在这里说明。',
          '如果没有匹配的学生，matches为空数组，summary说明原因。'
        ].join(' '),
        JSON.stringify(payload)
      )

      const rawMatches: AIScheduleMatch[] = result.matches || []
      const enrichedMatches: AIScheduleMatch[] = []
      for (let i = 0; i < rawMatches.length; i++) {
        const m = rawMatches[i]
        const candidate = candidates.find((c: ScheduleCandidate) => c.userId === m.studentId)
        const match: AIScheduleMatch = {
          studentName: m.studentName,
          studentId: m.studentId,
          school: m.school,
          major: m.major,
          freeSlots: m.freeSlots,
          freeSlotDetails: candidate?.freeSlotDetails || [],
          matchScore: m.matchScore,
          complementarity: m.complementarity
        }
        enrichedMatches.push(match)
      }
      const successResult: SchedulePuzzleResult = {
        matches: enrichedMatches,
        summary: result.summary || ''
      }
      return successResult
    } catch (e) {
      const fallbackResult: SchedulePuzzleResult = {
        matches: [],
        summary: 'AI工时拼图分析暂不可用，请稍后重试。'
      }
      return fallbackResult
    }
  }

  // 查询有课表的学生候选
  static async fetchScheduledStudents(): Promise<ScheduleCandidate[]> {
    const resumeDao = new ResumeDao()
    const userDao = new UserDao()
    const allUsers = await userDao.getAllUsers()
    const candidates: ScheduleCandidate[] = []
    for (const user of allUsers) {
      if (user.role === UserRole.JOB_SEEKER) {
        const schedule = await resumeDao.getScheduleByUserId(user.userId)
        if (schedule && schedule.freeSlots && schedule.freeSlots.length > 0) {
          candidates.push({
            userId: user.userId,
            name: user.realName || user.phone || '同学',
            school: user.school || '',
            major: user.major || '',
            freeSlots: schedule.freeSlots.map((s: FreeTimeSlot) => s.label),
            freeSlotDetails: schedule.freeSlots,
            expectedPosition: user.expectedPosition || ''
          })
        }
      }
    }
    return candidates
  }

  // ==== 创新点七：AI虚拟人多模态一面评估 ====

  static async generateInterviewQuestions(resumeText: string, jobTitle: string, jobDescription: string, skills: string[]): Promise<AIInterviewQuestion[]> {
    const payload: QuestionGenPayload = {
      jobTitle: jobTitle,
      jobDescription: jobDescription,
      skills: skills,
      resumeText: resumeText,
      questionCount: 5
    }
    const result = await DeepSeekService.chatJson<QuestionGenResult>(
      [
        '你是一个校园招聘AI面试官。你需要根据学生的简历和岗位要求，生成5轮个性化面试问题。',
        '每轮问题应该考察不同的维度：抗压能力(dimension: "抗压能力")、表达逻辑("表达逻辑")、技术真实度("技术真实度")、团队协作("团队协作")、学习潜力("学习潜力")。',
        '每个问题应该针对简历中的具体经历（项目、实习、竞赛）提问，验证其真实性。',
        '返回JSON：{ questions: [{ round: 1-5, question: "问题", dimension: "维度名", expectedTopics: "期望答案覆盖的要点" }] }',
        '问题要有针对性，不能泛泛而谈。'
      ].join(' '),
      JSON.stringify(payload)
    )
    return result.questions || []
  }

  static async evaluateInterviewAnswers(
    questions: AIInterviewQuestion[], answers: AIInterviewAnswer[],
    resumeText: string, jobTitle: string
  ): Promise<AIAssessmentResult> {
    const payload: EvaluationPayload = {
      jobTitle: jobTitle,
      resumeText: resumeText,
      questions: questions,
      answers: answers
    }
    const result = await DeepSeekService.chatJson<AIAssessmentResult>(
      [
        '你是一个专业的校园招聘面试评估专家。',
        '你需要根据学生的简历和面试回答，进行多维度评分。',
        '评估5个维度，每个维度打分0-100：抗压能力、表达逻辑、技术真实度、团队协作、学习潜力。',
        '返回JSON格式：{ summary: "综合评语", totalScore: 0-100, dimensions: [{ label: "维度名", value: 0-100, max: 100, comment: "评语", highlights: ["亮点1"], concerns: ["关注点1"] }], recommendation: "建议录用"/"可考虑"/"不建议", keywords: ["关键词"] }',
        '评分要客观，结合简历和回答给出具体依据。推荐建议要基于总分：>80建议录用，60-80可考虑，<60不建议。'
      ].join(' '),
      JSON.stringify(payload)
    )
    return {
      summary: result.summary || '',
      totalScore: Math.max(0, Math.min(100, result.totalScore || 0)),
      dimensions: result.dimensions || [],
      recommendation: result.recommendation || '可考虑',
      keywords: result.keywords || []
    }
  }

  static async getCompletedAssessments(recruiterId: string): Promise<AssessmentSummaryItem[]> {
    const store = await DatabaseHelper.getInstance().getStore()
    const rs = await store.querySql(
      `SELECT ai.interview_id, ai.user_id, ai.total_score, ai.complete_time, ai.assessment_result, ai.job_id, ai.application_id,
              u.real_name, u.school
       FROM ${TABLE_AI_INTERVIEW} ai
       LEFT JOIN ${TABLE_USER} u ON ai.user_id = u.user_id
       WHERE ai.recruiter_id = '${recruiterId}' AND ai.status IN ('completed', 'submitted')
       ORDER BY ai.complete_time DESC`
    )
    const list: AssessmentSummaryItem[] = []
    while (rs.goToNextRow()) {
      let jobTitle = ''
      try {
        const jobRs = await store.querySql(
          `SELECT title FROM ${TABLE_JOB} WHERE job_id = '${rs.getString(rs.getColumnIndex('job_id'))}'`
        )
        if (jobRs.goToFirstRow()) {
          jobTitle = jobRs.getString(jobRs.getColumnIndex('title'))
        }
        jobRs.close()
      } catch (_e) {
        // ignore
      }
      let recommendation = ''
      try {
        const raw = rs.getString(rs.getColumnIndex('assessment_result'))
        if (raw) {
          const parsed = JSON.parse(raw) as AIAssessmentResult
          recommendation = parsed.recommendation || ''
        }
      } catch (_e) {
        // ignore
      }
      list.push({
        interviewId: rs.getString(rs.getColumnIndex('interview_id')),
        userId: rs.getString(rs.getColumnIndex('user_id')),
        applicantName: rs.getString(rs.getColumnIndex('real_name')) || '未知',
        school: rs.getString(rs.getColumnIndex('school')) || '',
        jobTitle: jobTitle,
        totalScore: rs.getLong(rs.getColumnIndex('total_score')),
        completeTime: rs.getLong(rs.getColumnIndex('complete_time')),
        recommendation: recommendation,
        applicationId: rs.getString(rs.getColumnIndex('application_id')) || '',
        status: rs.getString(rs.getColumnIndex('status')) || ''
      })
    }
    rs.close()
    return list
  }

  static async getAssessmentById(interviewId: string): Promise<AIAssessmentResult | null> {
    const store = await DatabaseHelper.getInstance().getStore()
    const rs = await store.querySql(
      `SELECT assessment_result FROM ${TABLE_AI_INTERVIEW} WHERE interview_id = '${interviewId}'`
    )
    let result: AIAssessmentResult | null = null
    if (rs.goToFirstRow()) {
      const raw = rs.getString(rs.getColumnIndex('assessment_result'))
      if (raw) {
        try {
          result = JSON.parse(raw) as AIAssessmentResult
        } catch (_e) {
          // ignore
        }
      }
    }
    rs.close()
    return result
  }
}

export interface AIInterviewQuestion {
  round: number
  question: string
  dimension: string
  expectedTopics: string
}

export interface AIInterviewAnswer {
  round: number
  question: string
  answer: string
}

export interface AIAssessmentDimension {
  label: string
  value: number
  max: number
  comment: string
  highlights: string[]
  concerns: string[]
}

export interface AIAssessmentResult {
  summary: string
  totalScore: number
  dimensions: AIAssessmentDimension[]
  recommendation: string
  keywords: string[]
}

export interface AssessmentSummaryItem {
  interviewId: string
  userId: string
  applicantName: string
  school: string
  jobTitle: string
  totalScore: number
  completeTime: number
  recommendation: string
  applicationId: string
  status: string
}
