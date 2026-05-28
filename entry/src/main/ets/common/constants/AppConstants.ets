// 应用常量定义

export class AppConstants {
  // 应用名称
  static readonly APP_NAME = '校招护航'
  static readonly APP_SUBTITLE = 'Uni-Campus'

  // 角色
  static readonly ROLE_JOB_SEEKER = 'job_seeker'
  static readonly ROLE_RECRUITER = 'recruiter'

  // 学生类型
  static readonly STUDENT_CURRENT = 'current'
  static readonly STUDENT_GRADUATING = 'graduating'

  // 岗位类别
  static readonly CATEGORY_MICRO_TASK = 'micro_task'
  static readonly CATEGORY_FULLTIME = 'fulltime'

  // VIP
  static readonly VIP_NORMAL = 'normal'
  static readonly VIP_VIP = 'vip'
  static readonly NORMAL_MAX_POSITIONS = 1

  // 颜色
  static readonly COLOR_PRIMARY = '#4A90D9'
  static readonly COLOR_ACCENT = '#FF6B35'
  static readonly COLOR_SUCCESS = '#52C41A'
  static readonly COLOR_WARNING = '#FAAD14'
  static readonly COLOR_DANGER = '#FF4D4F'
  static readonly COLOR_PURPLE = '#7B68EE'
  static readonly COLOR_BG_LIGHT = '#F5F5F5'
  static readonly COLOR_TEXT_PRIMARY = '#1A1A1A'
  static readonly COLOR_TEXT_SECONDARY = '#666666'
  static readonly COLOR_TEXT_HINT = '#999999'
  static readonly COLOR_YELLOW_HIGHLIGHT = '#FFFACD'
  static readonly COLOR_AI_PURPLE = '#9B59B6'

  // 页面路由
  static readonly ROUTE_INDEX = 'pages/Index'
  static readonly ROUTE_WELCOME = 'pages/WelcomePage'
  static readonly ROUTE_LOGIN = 'pages/login/LoginPage'
  static readonly ROUTE_BIND_PHONE = 'pages/login/BindPhonePage'
  static readonly ROUTE_JOB_SEEKER_MAIN = 'pages/job_seeker/JobSeekerMainPage'
  static readonly ROUTE_RECRUITER_MAIN = 'pages/recruiter/RecruiterMainPage'
  static readonly ROUTE_RESUME_EDIT = 'pages/job_seeker/ResumeEditPage'
  static readonly ROUTE_JOB_DETAIL = 'pages/job_seeker/JobDetailPage'
  static readonly ROUTE_COMPANY_DETAIL = 'pages/job_seeker/CompanyDetailPage'
  static readonly ROUTE_TALENT_DETAIL = 'pages/recruiter/TalentDetailPage'
  static readonly ROUTE_RECRUITER_AUTH = 'pages/recruiter/AuthPage'
  static readonly ROUTE_CHAT = 'pages/ChatPage'
}

// 全局用户状态
export class AppState {
  static currentUser: import('../../model/UserModel').UserProfile | null = null
  static isLoggedIn: boolean = false
  static isGuest: boolean = true
  static agreementAccepted: boolean = false
}
