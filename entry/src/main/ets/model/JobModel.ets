// 职位数据模型

export enum JobCategory {
  MICRO_TASK = 'micro_task',       // 微任务/短期兼职
  FULLTIME_INTERN = 'fulltime'     // 全职/转正实习
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
  title: string                       // 岗位名称
  category: JobCategory              // 岗位类别
  description: string                 // 岗位描述
  educationRequired: string           // 学历要求
  salaryRange: string                 // 薪资范围
  workYearsRequired: string          // 工作年限要求
  workAddress: string                // 上班地址
  city: string                        // 城市
  skills: string[]                    // 技能要求
  status: JobStatus
  publishTime: number
  updateTime: number
  viewCount: number                  // 浏览次数
  applyCount: number                  // 投递次数
  tags: string[]                      // 标签
  isAIGenerated: boolean             // 是否AI生成描述
}

export interface JobApplication {
  applicationId: string
  jobId: string
  userId: string                     // 求职者ID
  resumeId: string
  status: ApplicationStatus
  applyTime: number
  interviewTime?: number
  remark?: string
  // HR反馈
  rejectionReason?: string           // 拒绝理由（如学历不符 / 经验不足 / 已招满）
  viewTime?: number                 // HR查看时间
}

export enum ApplicationStatus {
  SUBMITTED = 'submitted',           // 已投递
  VIEWED = 'viewed',                 // HR已查看
  INTERVIEW = 'interview',          // 约面试
  OFFERED = 'offered',              // 已发Offer
  REJECTED = 'rejected',            // 已拒绝
  ACCEPTED = 'accepted'             // 已接受
}

export interface MicroTask {
  taskId: string
  recruiterId: string
  title: string
  description: string
  price: number                     // 按件计薪
  deadline: string
  skills: string[]
  status: string
  publishTime: number
  acceptedBy?: string               // 接单学生ID
}
