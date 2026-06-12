export enum JobCategory {
  MICRO_TASK = 'micro_task',
  FULLTIME_INTERN = 'fulltime'
}

export enum JobStatus {
  PUBLISHED = 'published',
  CLOSED = 'closed',
  PENDING_REVIEW = 'pending_review'
}

export interface JobPosition {
  jobId: string
  recruiterId: string
  companyName: string
  title: string
  category: JobCategory
  description: string
  educationRequired: string
  salaryRange: string
  workYearsRequired: string
  workAddress: string
  city: string
  skills: string[]
  status: JobStatus
  publishTime: number
  updateTime: number
  viewCount: number
  applyCount: number
  tags: string[]
  isAIGenerated: boolean
  taskStartTime?: number
  taskEndTime?: number
  requiredDayOfWeek?: number
  requiredDaysOfWeek?: number[]
  requiredStartHour?: number
  requiredStartMinute?: number
  requiredEndHour?: number
  requiredEndMinute?: number
}

export interface JobApplication {
  applicationId: string
  jobId: string
  userId: string
  resumeId: string
  status: ApplicationStatus
  applyTime: number
  interviewTime?: number
  remark?: string
  rejectionReason?: string
  viewTime?: number
}

export enum ApplicationStatus {
  SUBMITTED = 'submitted',
  VIEWED = 'viewed',
  INTERVIEW = 'interview',
  OFFERED = 'offered',
  REJECTED = 'rejected',
  ACCEPTED = 'accepted'
}

export interface MicroTask {
  taskId: string
  recruiterId: string
  title: string
  description: string
  price: number
  deadline: string
  skills: string[]
  status: string
  publishTime: number
  acceptedBy?: string
  requiredDayOfWeek?: number
  requiredStartHour?: number
  requiredEndHour?: number
}
