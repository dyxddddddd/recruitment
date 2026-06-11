import { UserProfile } from '../../model/UserModel'

export class AppConstants {
  static readonly APP_NAME = '校招护航'
  static readonly APP_SUBTITLE = 'Uni-Campus'


  static readonly BACKEND_BASE_URL = 'http://10.0.2.2:8088'
  static readonly WS_URL = 'ws://10.0.2.2:8088/ws'
  static readonly DEEPSEEK_BASE_URL = 'https://api.deepseek.com'
  static readonly DEEPSEEK_MODEL = 'deepseek-chat'
  static readonly DEEPSEEK_API_KEY = 'sk-eb8ad2c97cb2406d9d5bf5a7a51d3717'
  static readonly WECHAT_APP_ID = ''
  static readonly QQ_APP_ID = ''
  static readonly THIRD_PARTY_AUTH_MOCK_ENABLED = true
  static readonly WECHAT_LOGIN_SCOPE = 'snsapi_userinfo'
  static readonly QQ_LOGIN_SCOPE = 'get_user_info'
  static readonly ENTRY_ABILITY_NAME = 'EntryAbility'

  static readonly ROLE_JOB_SEEKER = 'job_seeker'
  static readonly ROLE_RECRUITER = 'recruiter'

  static readonly STUDENT_CURRENT = 'current'
  static readonly STUDENT_GRADUATING = 'graduating'

  static readonly CATEGORY_MICRO_TASK = 'micro_task'
  static readonly CATEGORY_FULLTIME = 'fulltime'

  static readonly VIP_NORMAL = 'normal'
  static readonly VIP_VIP = 'vip'
  static readonly NORMAL_MAX_POSITIONS = 1

  static readonly COLOR_PRIMARY = '#4A90D9'
  static readonly COLOR_ACCENT = '#FF6B35'
  static readonly COLOR_SUCCESS = '#52C41A'
  static readonly COLOR_WARNING = '#FAAD14'
  static readonly COLOR_DANGER = '#FF4D4F'
  static readonly COLOR_BG_LIGHT = '#F5F5F5'
  static readonly COLOR_TEXT_PRIMARY = '#1A1A1A'
  static readonly COLOR_TEXT_SECONDARY = '#666666'
  static readonly COLOR_TEXT_HINT = '#999999'
  static readonly COLOR_YELLOW_HIGHLIGHT = '#FFFACD'
  static readonly COLOR_AI_PURPLE = '#9B59B6'

  static readonly ROUTE_INDEX = 'pages/Index'
  static readonly ROUTE_WELCOME = 'pages/WelcomePage'
  static readonly ROUTE_LOGIN = 'pages/login/LoginPage'
  static readonly ROUTE_MOCK_SOCIAL_AUTH = 'pages/login/MockSocialAuthPage'
  static readonly ROUTE_BIND_PHONE = 'pages/login/BindPhonePage'
  static readonly ROUTE_SET_PASSWORD = 'pages/login/SetPasswordPage'
  static readonly ROUTE_JOB_SEEKER_MAIN = 'pages/job_seeker/JobSeekerMainPage'
  static readonly ROUTE_RECRUITER_MAIN = 'pages/recruiter/RecruiterMainPage'
  static readonly ROUTE_RESUME_EDIT = 'pages/job_seeker/ResumeEditPage'
  static readonly ROUTE_FLEX_WORK_CALENDAR = 'pages/job_seeker/FlexWorkCalendarPage'
  static readonly ROUTE_JOB_DETAIL = 'pages/job_seeker/JobDetailPage'
  static readonly ROUTE_COMPANY_DETAIL = 'pages/job_seeker/CompanyDetailPage'
  static readonly ROUTE_TALENT_DETAIL = 'pages/recruiter/TalentDetailPage'
  static readonly ROUTE_RECRUITER_AUTH = 'pages/recruiter/AuthPage'
  static readonly ROUTE_CHAT = 'pages/ChatPage'
  static readonly ROUTE_APPLICATION_TRACK = 'pages/job_seeker/ApplicationTrackPage'
  static readonly ROUTE_IDENTITY_GUIDE = 'pages/job_seeker/IdentityGuidePage'
  static readonly ROUTE_AI_ASSISTANT = 'pages/job_seeker/AIRecruiterAssistantPage'
  static readonly ROUTE_CONTRACT_REVIEW = 'pages/job_seeker/ContractReviewPage'
  static readonly ROUTE_AI_DIGITAL_TWIN = 'pages/job_seeker/AIDigitalTwinPage'
}

const KEY_CURRENT_USER = 'app_current_user'
const KEY_IS_LOGGED_IN = 'app_is_logged_in'
const KEY_IS_GUEST = 'app_is_guest'
const KEY_PHONE_STUDENT_TYPES = 'app_phone_student_types'

export class AppState {
  static currentUser: UserProfile | null = null
  static isLoggedIn: boolean = false
  static isGuest: boolean = true
  static agreementAccepted: boolean = false

  static syncFromStorage(): void {
    AppState.currentUser = AppStorage.get<UserProfile>(KEY_CURRENT_USER) ?? null
    AppState.isLoggedIn = AppStorage.get<boolean>(KEY_IS_LOGGED_IN) ?? false
    AppState.isGuest = AppStorage.get<boolean>(KEY_IS_GUEST) ?? true
  }

  static syncToStorage(): void {
    AppStorage.setOrCreate(KEY_CURRENT_USER, AppState.currentUser)
    AppStorage.setOrCreate(KEY_IS_LOGGED_IN, AppState.isLoggedIn)
    AppStorage.setOrCreate(KEY_IS_GUEST, AppState.isGuest)
  }

  static rememberStudentType(phone: string, studentType: string): void {
    const normalizedPhone = phone.trim()
    const normalizedType = studentType.trim()
    if (!normalizedPhone || !normalizedType) {
      return
    }
    const snapshot = AppStorage.get<string>(KEY_PHONE_STUDENT_TYPES) ?? ''
    const lines = snapshot ? snapshot.split('\n') : []
    const nextLines: string[] = []
    let found: boolean = false
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim()
      if (!line) {
        continue
      }
      const separatorIndex = line.indexOf('=')
      if (separatorIndex < 0) {
        continue
      }
      const savedPhone = line.substring(0, separatorIndex).trim()
      if (savedPhone === normalizedPhone) {
        nextLines.push(normalizedPhone + '=' + normalizedType)
        found = true
      } else {
        nextLines.push(savedPhone + '=' + line.substring(separatorIndex + 1).trim())
      }
    }
    if (!found) {
      nextLines.push(normalizedPhone + '=' + normalizedType)
    }
    AppStorage.setOrCreate(KEY_PHONE_STUDENT_TYPES, nextLines.join('\n'))
  }

  static getRememberedStudentType(phone: string): string {
    const normalizedPhone = phone.trim()
    if (!normalizedPhone) {
      return ''
    }
    const snapshot = AppStorage.get<string>(KEY_PHONE_STUDENT_TYPES) ?? ''
    if (!snapshot) {
      return ''
    }
    const lines = snapshot.split('\n')
    for (let i = 0; i < lines.length; i++) {
      const line = lines[i].trim()
      if (!line) {
        continue
      }
      const separatorIndex = line.indexOf('=')
      if (separatorIndex < 0) {
        continue
      }
      const savedPhone = line.substring(0, separatorIndex).trim()
      if (savedPhone === normalizedPhone) {
        return line.substring(separatorIndex + 1).trim()
      }
    }
    return ''
  }
}

export function getAppCurrentUser(): UserProfile | null {
  return AppStorage.get<UserProfile>(KEY_CURRENT_USER) ?? null
}

export function isAppLoggedIn(): boolean {
  return AppStorage.get<boolean>(KEY_IS_LOGGED_IN) ?? false
}

export function isAppGuest(): boolean {
  return AppStorage.get<boolean>(KEY_IS_GUEST) ?? true
}
