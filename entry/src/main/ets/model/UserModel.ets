// 用户数据模型

export enum UserRole {
  JOB_SEEKER = 'job_seeker',   // 求职者（大学生）
  RECRUITER = 'recruiter'       // 招聘者（企业HR）
}

export enum StudentType {
  CURRENT = 'current',          // 在校大学生
  GRADUATING = 'graduating'     // 应届大学生
}

export enum Gender {
  MALE = 'male',
  FEMALE = 'female',
  UNKNOWN = 'unknown'
}

export enum VipLevel {
  NORMAL = 'normal',
  VIP = 'vip'
}

export interface UserProfile {
  userId: string
  phone: string
  email?: string
  password?: string
  role: UserRole
  // 求职者专属
  studentType?: StudentType
  realName?: string
  gender?: Gender
  birthday?: string
  education?: string          // 学历
  school?: string             // 学校
  major?: string              // 专业
  expectedPosition?: string   // 期望职位
  expectedSalary?: string     // 期望薪资
  currentCity?: string        // 现居地
  isGuest: boolean            // 游客模式
  avatar?: string

  // 招聘者专属
  companyName?: string
  idCard?: string
  businessLicense?: string    // 营业执照图片路径
  vipLevel?: VipLevel
  positionCount?: number       // 当前在招岗位数
  hrRealName?: string
}

export interface LoginInfo {
  loginType: 'phone' | 'email' | 'wechat' | 'qq'
  phone?: string
  email?: string
  password?: string
  verifyCode?: string
  openId?: string
  accessToken?: string
}
