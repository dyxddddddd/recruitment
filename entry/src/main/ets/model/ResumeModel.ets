// 简历数据模型

export interface ResumeInfo {
  resumeId: string
  userId: string
  realName: string
  gender: string                    // male / female
  birthday: string
  education: string                 // 学历
  school: string
  major: string
  graduationYear: string
  expectedPosition: string
  expectedSalary: string
  currentCity: string
  phone: string
  email: string
  skills: string[]
  selfIntro: string                 // 自我介绍
  // 教育经历
  educationList: EducationItem[]
  // 实习/项目经历
  experienceList: ExperienceItem[]
  // PDF解析状态
  isFromPDF: boolean
  pdfUncertainFields: string[]      // AI不确定需要人工确认的字段
  // 课表相关
  hasSchedule: boolean
  scheduleId?: string
  updateTime: number
}

export interface EducationItem {
  schoolName: string
  major: string
  degree: string
  startYear: string
  endYear: string
}

export interface ExperienceItem {
  type: 'intern' | 'project'        // 实习或项目
  companyName?: string
  projectName?: string
  role: string
  description: string
  startTime: string
  endTime: string
  // 创新点五：校园经历→企业术语翻译
  translatedDescription?: string
}

export interface CourseSchedule {
  scheduleId: string
  userId: string
  semesters: SemesterSchedule[]
  freeSlots: FreeTimeSlot[]         // 空闲时段（绿色）
  updateTime: number
}

export interface SemesterSchedule {
  semester: string
  courses: CourseItem[]
}

export interface CourseItem {
  name: string
  dayOfWeek: number                 // 0-6, 0=周日
  startPeriod: number               // 第几节开始
  endPeriod: number                 // 第几节结束
  weekRange: string                 // 第几周到第几周，如"1-16"
  location: string
  teacher: string
}

export interface FreeTimeSlot {
  dayOfWeek: number
  startPeriod: number
  endPeriod: number
  label: string                     // "周一上午", "周三下午"等
}
