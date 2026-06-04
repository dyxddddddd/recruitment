import { JobApplication } from '../model/JobModel'
import { FreeTimeSlot, ResumeInfo } from '../model/ResumeModel'
import { StudentType, UserProfile } from '../model/UserModel'
import { DeepSeekService } from './DeepSeekService'

export interface CampusAITranslationResult {
  translated: string
  skills: string[]
  confidence: 'high' | 'medium' | 'low'
}

export interface CampusAIResumeExperience {
  type: 'intern' | 'project'
  companyName?: string
  projectName?: string
  role: string
  description: string
  translatedDescription?: string
  startTime: string
  endTime: string
}

export interface CampusAIResumeParseResult {
  realName: string
  phone: string
  email: string
  school: string
  major: string
  education: string
  graduationYear: string
  expectedPosition: string
  expectedSalary: string
  skills: string[]
  selfIntro: string
  experiences: CampusAIResumeExperience[]
  uncertainFields: string[]
}

export interface CampusAIContractRisk {
  title: string
  description: string
  severity: 'high' | 'medium' | 'low'
  matchedClause: string
  negotiationScript: string
  suggestion: string
}

export interface CampusAIContractReviewResult {
  summary: string
  overallRiskLevel: 'safe' | 'warning' | 'danger'
  risks: CampusAIContractRisk[]
}

export interface CampusAIRadarItem {
  label: string
  value: number
  max: number
}

export interface CampusAIAdviceItem {
  id: string
  title: string
  content: string
  priority: 'high' | 'medium' | 'low'
}

export interface CampusAICareerAssistantResult {
  summary: string
  radar: CampusAIRadarItem[]
  advices: CampusAIAdviceItem[]
  sampleResumeText: string
}

interface CareerAssistantRequest {
  user: UserProfile | null
  resume: ResumeInfo | null
  applications: JobApplication[]
  failedApplications: number
  rejectCount: number
}

interface DigitalTwinReplyRequest {
  user: UserProfile
  resume: ResumeInfo | null
  availableTime: string[]
  hrMessage: string
}

interface ScheduleParseResult {
  summary: string
  freeSlots: FreeTimeSlot[]
}

interface CampusTranslationPayload {
  type: string
  description: string
}

interface CareerAssistantPayload {
  studentType: string
  school: string
  major: string
  expectedPosition: string
  expectedSalary: string
  skills: string[]
  selfIntro: string
  educationList: object[]
  experienceList: object[]
  applicationCount: number
  failedApplications: number
  rejectCount: number
}

interface DigitalTwinPayload {
  studentType: string
  school: string
  major: string
  expectedPosition: string
  expectedSalary: string
  skills: string[]
  selfIntro: string
  availableTime: string[]
  hrMessage: string
}

export class CampusAIService {
  static async translateCampusExperience(description: string, type: string): Promise<CampusAITranslationResult> {
    const payload: CampusTranslationPayload = {
      type: type,
      description: description
    }
    return DeepSeekService.chatJson<CampusAITranslationResult>(
      [
        'You are a resume optimization assistant for Chinese college students.',
        'Translate campus experiences into recruiting-friendly professional language.',
        'Do not fabricate achievements or numbers.',
        'Return JSON only with translated, skills, confidence.'
      ].join(' '),
      JSON.stringify(payload)
    )
  }

  static async parseResumeText(text: string): Promise<CampusAIResumeParseResult> {
    return DeepSeekService.chatJson<CampusAIResumeParseResult>(
      [
        'You are a Chinese resume parsing assistant.',
        'Extract structured fields from the resume text without fabricating missing information.',
        'Return JSON only with realName, phone, email, school, major, education, graduationYear, expectedPosition, expectedSalary, skills, selfIntro, experiences, uncertainFields.',
        'Each experience must include type, companyName, projectName, role, description, translatedDescription, startTime, endTime.'
      ].join(' '),
      text
    )
  }

  static async reviewContract(text: string): Promise<CampusAIContractReviewResult> {
    return DeepSeekService.chatJson<CampusAIContractReviewResult>(
      [
        'You are a legal review assistant for Chinese students checking labor or tripartite contracts.',
        'Identify risks from the original contract text.',
        'Return JSON only with summary, overallRiskLevel, risks.',
        'overallRiskLevel must be one of safe, warning, danger.',
        'Each risk must include title, description, severity, matchedClause, negotiationScript, suggestion.'
      ].join(' '),
      text
    )
  }

  static async analyzeCareerAssistant(request: CareerAssistantRequest): Promise<CampusAICareerAssistantResult> {
    const payload: CareerAssistantPayload = {
      studentType: request.user?.studentType || StudentType.CURRENT,
      school: request.resume?.school || request.user?.school || '',
      major: request.resume?.major || request.user?.major || '',
      expectedPosition: request.resume?.expectedPosition || request.user?.expectedPosition || '',
      expectedSalary: request.resume?.expectedSalary || request.user?.expectedSalary || '',
      skills: request.resume?.skills || [],
      selfIntro: request.resume?.selfIntro || '',
      educationList: request.resume?.educationList || [],
      experienceList: request.resume?.experienceList || [],
      applicationCount: request.applications.length,
      failedApplications: request.failedApplications,
      rejectCount: request.rejectCount
    }
    const result = await DeepSeekService.chatJson<CampusAICareerAssistantResult>(
      [
        'You are an AI career assistant for campus recruiting.',
        'Analyze the student resume and application record.',
        'Return JSON only with summary, radar, advices, sampleResumeText.',
        'radar should contain 5 dimensions with label, value, max.',
        'advices should include id, title, content, priority.'
      ].join(' '),
      JSON.stringify(payload)
    )

    return {
      summary: result.summary || '',
      radar: CampusAIService.normalizeRadar(result.radar || []),
      advices: result.advices || [],
      sampleResumeText: result.sampleResumeText || ''
    }
  }

  static async generateDigitalTwinReply(request: DigitalTwinReplyRequest): Promise<string> {
    const payload: DigitalTwinPayload = {
      studentType: request.user.studentType || StudentType.CURRENT,
      school: request.resume?.school || request.user.school || '',
      major: request.resume?.major || request.user.major || '',
      expectedPosition: request.resume?.expectedPosition || request.user.expectedPosition || '',
      expectedSalary: request.resume?.expectedSalary || request.user.expectedSalary || '',
      skills: request.resume?.skills || [],
      selfIntro: request.resume?.selfIntro || '',
      availableTime: request.availableTime,
      hrMessage: request.hrMessage
    }
    return DeepSeekService.chatText(
      [
        'You are an AI digital twin for a university student during job search.',
        'Reply in polite and concise Chinese.',
        'Do not fabricate experiences.',
        'Do not directly confirm joining or salary negotiation results.',
        'Reply in 1 to 3 sentences.'
      ].join(' '),
      JSON.stringify(payload)
    )
  }

  static async parseScheduleText(text: string): Promise<ScheduleParseResult> {
    return DeepSeekService.chatJson<ScheduleParseResult>(
      [
        'You are a university class schedule parsing assistant.',
        'Infer weekly free time slots from OCR text.',
        'Return JSON only with summary and freeSlots.',
        'Each free slot must include dayOfWeek, startPeriod, endPeriod, label.',
        'dayOfWeek uses 0 for Sunday and 1 for Monday.'
      ].join(' '),
      text
    )
  }

  private static normalizeRadar(items: CampusAIRadarItem[]): CampusAIRadarItem[] {
    const normalized: CampusAIRadarItem[] = []
    const limit: number = items.length > 5 ? 5 : items.length
    for (let i = 0; i < limit; i++) {
      const item: CampusAIRadarItem = items[i]
      normalized.push({
        label: item.label || '综合能力',
        value: Math.max(0, Math.min(100, Math.round(item.value || 0))),
        max: 100
      })
    }
    return normalized
  }
}
