import { HttpService, ApiResult } from './HttpService'
import { AppConstants } from '../common/constants/AppConstants'

// ===== 请求体 =====

export interface CreateInterviewRequest {
  userId: string
  position: string
}

export interface SubmitAnswerRequest {
  sessionId: string
  questionId: number
  questionText: string
  videoBase64: string
}

// ===== 响应体 =====

export interface InterviewQuestion {
  questionId: number
  questionText: string
  sortOrder: number
  ttsAudioUrl: string
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
  expressionScore: number
  voiceScore: number
  overallScore: number
  feedback: string
}

export interface InterviewReport {
  sessionId: number
  position: string
  totalScore: number
  summary: string
  radar: RadarData
  answers: AnswerWithFeedback[]
}

export interface SessionHistoryItem {
  sessionId: number
  position: string
  totalScore: number
  completedAt: string
}

// ===== 内部 API 响应包装 =====

interface CreateInterviewData {
  sessionId: number
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
  private static readonly BASE = '/interview'

  static getTtsUrl(path: string): string {
    if (!path || path.length === 0) return ''
    return `${AppConstants.BACKEND_BASE_URL}${path}`
  }

  static async createInterview(req: CreateInterviewRequest): Promise<CreateInterviewData> {
    const res = await HttpService.post<CreateInterviewData>(
      `${InterviewApiService.BASE}/create`, req
    )
    if (res.code === 200 && res.data) {
      return res.data
    }
    throw new Error(`[${res.code}] ${res.message || '创建面试失败'}`)
  }

  static async getQuestions(sessionId: string): Promise<InterviewQuestion[]> {
    const res = await HttpService.get<QuestionsData>(
      `${InterviewApiService.BASE}/${sessionId}/questions`
    )
    if (res.code === 200 && res.data) {
      return res.data.questions
    }
    throw new Error(res.message || '获取题目失败')
  }

  static async submitAnswer(req: SubmitAnswerRequest): Promise<SubmitAnswerResult> {
    const res = await HttpService.post<SubmitAnswerResult>(
      `${InterviewApiService.BASE}/answer/submit`, req
    )
    if (res.code === 200 && res.data) {
      return res.data
    }
    throw new Error(res.message || '提交答案失败')
  }

  static async completeInterview(sessionId: string): Promise<InterviewReport> {
    const res = await HttpService.post<InterviewReport>(
      `${InterviewApiService.BASE}/${sessionId}/complete`
    )
    if (res.code === 200 && res.data) {
      return res.data
    }
    throw new Error(res.message || '完成面试失败')
  }

  static async getReport(sessionId: string): Promise<InterviewReport> {
    const res = await HttpService.get<InterviewReport>(
      `${InterviewApiService.BASE}/report/${sessionId}`
    )
    if (res.code === 200 && res.data) {
      return res.data
    }
    throw new Error(res.message || '获取报告失败')
  }

  static async getUserSessions(userId: string): Promise<SessionHistoryItem[]> {
    const res = await HttpService.get<SessionsData>(
      `${InterviewApiService.BASE}/sessions/${userId}`
    )
    if (res.code === 200 && res.data) {
      return res.data.sessions || []
    }
    return []
  }
}
