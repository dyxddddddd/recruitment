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

export enum AuthStatus {
  UNAUTHENTICATED = 0,
  PENDING = 1,
  APPROVED = 2,
  REJECTED = 3
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
  companyAddress?: string       // 企业注册地址
  companyIndustry?: string      // 所属行业
  companyScale?: string         // 企业规模
  legalPerson?: string          // 法定代表人
  contactPosition?: string      // 联系人职位
  companyEmail?: string         // 企业邮箱
  idCard?: string
  businessLicense?: string    // 营业执照图片路径
  vipLevel?: VipLevel
  vipExpireTime?: number          // VIP到期时间戳（毫秒），0或undefined为非VIP/已过期
  vipLifetime?: boolean           // 是否终身会员
  positionCount?: number       // 当前在招岗位数
  hrRealName?: string
  authStatus?: number           // AuthStatus 枚举值
  idCardFrontImage?: string     // 身份证人像面照片
  idCardBackImage?: string      // 身份证国徽面照片
  faceImage?: string            // 手持身份证照片
  authSubmitTime?: number       // 认证提交时间戳
  authApproveTime?: number      // 认证通过时间戳
  authRejectReason?: string     // 认证驳回原因
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
