import { HttpService, ApiResult } from './HttpService'

// ===== 请求体 =====

export interface CreateInterviewRequest {
  userId: string
  position: string
}

export interface SubmitAnswerRequest {
  sessionId: string
  questionId: number
  videoBase64: string
}

// ===== 响应体 =====

export interface InterviewQuestion {
  questionId: number
  questionText: string
  referenceAnswer?: string
}

export interface AnswerScore {
  contentScore: number
  expressionScore: number
  voiceScore: number
  overallScore: number
}

export interface SubmitAnswerResult {
  answerId: number
  asrText: string
  scores: AnswerScore
  nextQuestionIndex: number
  isComplete: boolean
}

export interface RadarData {
  dimensions: string[]
  scores: number[]
  fullMarks: number[]
}

export interface AnswerWithFeedback {
  questionId: number
  questionText: string
  contentScore: number
  feedback: string
}

export interface InterviewReport {
  totalScore: number
  summary: string
  radar: RadarData
  answers: AnswerWithFeedback[]
}

export interface SessionHistoryItem {
  sessionId: string
  position: string
  totalScore: number
  completedAt: string
}

// ===== 内部 API 响应类型 =====

interface CreateInterviewData {
  sessionId: string
  questions: InterviewQuestion[]
}

interface QuestionsData {
  questions: InterviewQuestion[]
}

interface SessionsData {
  sessions: SessionHistoryItem[]
}

// ===== API 服务 =====

export class InterviewApiService {
  static async createInterview(req: CreateInterviewRequest): Promise<CreateInterviewData> {
    const res = await HttpService.post<CreateInterviewData>(
      '/interview/create', req
    )
    if (res.code === 200 && res.data) {
      return res.data
    }
    throw new Error(`[${res.code}] ${res.message || '创建面试失败'}`)
  }

  static async getQuestions(sessionId: string): Promise<InterviewQuestion[]> {
    const res = await HttpService.get<QuestionsData>(
      `/interview/${sessionId}/questions`
    )
    if (res.code === 200 && res.data) {
      return res.data.questions
    }
    throw new Error(res.message || '获取题目失败')
  }

  static async submitAnswer(req: SubmitAnswerRequest): Promise<SubmitAnswerResult> {
    const res = await HttpService.post<SubmitAnswerResult>(
      '/interview/answer/submit', req
    )
    if (res.code === 200 && res.data) {
      return res.data
    }
    throw new Error(res.message || '提交答案失败')
  }

  static async completeInterview(sessionId: string): Promise<InterviewReport> {
    const res = await HttpService.post<InterviewReport>(
      `/interview/${sessionId}/complete`
    )
    if (res.code === 200 && res.data) {
      return res.data
    }
    throw new Error(res.message || '完成面试失败')
  }

  static async getReport(sessionId: string): Promise<InterviewReport> {
    const res = await HttpService.get<InterviewReport>(
      `/interview/report/${sessionId}`
    )
    if (res.code === 200 && res.data) {
      return res.data
    }
    throw new Error(res.message || '获取报告失败')
  }

  static async getUserSessions(userId: string): Promise<SessionHistoryItem[]> {
    const res = await HttpService.get<SessionsData>(
      `/interview/sessions/${userId}`
    )
    if (res.code === 200 && res.data) {
      return res.data.sessions || []
    }
    return []
  }
}
