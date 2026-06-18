// 数据库表结构定义

export const DATABASE_NAME = 'UniCampus.db'
export const DATABASE_VERSION = 9

// 用户表
export const TABLE_USER = 'tb_user'
export const CREATE_TABLE_USER = `
CREATE TABLE IF NOT EXISTS ${TABLE_USER} (
  user_id TEXT PRIMARY KEY,
  phone TEXT,
  email TEXT,
  role TEXT NOT NULL,
  student_type TEXT,
  real_name TEXT,
  gender TEXT,
  birthday TEXT,
  education TEXT,
  school TEXT,
  major TEXT,
  expected_position TEXT,
  expected_salary TEXT,
  current_city TEXT,
  is_guest INTEGER DEFAULT 0,
  avatar TEXT,
  company_name TEXT,
  company_address TEXT,
  company_industry TEXT,
  company_scale TEXT,
  legal_person TEXT,
  contact_position TEXT,
  company_email TEXT,
  id_card TEXT,
  business_license TEXT,
  vip_level TEXT DEFAULT 'normal',
  vip_expire_time INTEGER DEFAULT 0,
  vip_lifetime INTEGER DEFAULT 0,
  position_count INTEGER DEFAULT 0,
  hr_real_name TEXT,
  password TEXT,
  auth_status INTEGER DEFAULT 0,
  id_card_front_image TEXT,
  id_card_back_image TEXT,
  face_image TEXT,
  auth_submit_time INTEGER,
  auth_approve_time INTEGER,
  auth_reject_reason TEXT,
  create_time INTEGER,
  update_time INTEGER,
  is_login INTEGER DEFAULT 0
)`

// 简历表
export const TABLE_RESUME = 'tb_resume'
export const CREATE_TABLE_RESUME = `
CREATE TABLE IF NOT EXISTS ${TABLE_RESUME} (
  resume_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  real_name TEXT,
  gender TEXT,
  birthday TEXT,
  education TEXT,
  school TEXT,
  major TEXT,
  graduation_year TEXT,
  expected_position TEXT,
  expected_salary TEXT,
  current_city TEXT,
  phone TEXT,
  email TEXT,
  skills TEXT,
  self_intro TEXT,
  is_from_pdf INTEGER DEFAULT 0,
  pdf_uncertain_fields TEXT,
  has_schedule INTEGER DEFAULT 0,
  schedule_id TEXT,
  update_time INTEGER
)`

// 教育经历表
export const TABLE_EDUCATION = 'tb_education'
export const CREATE_TABLE_EDUCATION = `
CREATE TABLE IF NOT EXISTS ${TABLE_EDUCATION} (
  edu_id TEXT PRIMARY KEY,
  resume_id TEXT NOT NULL,
  school_name TEXT,
  major TEXT,
  degree TEXT,
  start_year TEXT,
  end_year TEXT
)`

// 实习/项目经历表
export const TABLE_EXPERIENCE = 'tb_experience'
export const CREATE_TABLE_EXPERIENCE = `
CREATE TABLE IF NOT EXISTS ${TABLE_EXPERIENCE} (
  exp_id TEXT PRIMARY KEY,
  resume_id TEXT NOT NULL,
  type TEXT,
  company_name TEXT,
  project_name TEXT,
  role TEXT,
  description TEXT,
  translated_description TEXT,
  start_time TEXT,
  end_time TEXT
)`

// 课表表
export const TABLE_SCHEDULE = 'tb_schedule'
export const CREATE_TABLE_SCHEDULE = `
CREATE TABLE IF NOT EXISTS ${TABLE_SCHEDULE} (
  schedule_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  schedule_data TEXT,
  free_slots TEXT,
  update_time INTEGER
)`

// 职位表
export const TABLE_JOB = 'tb_job'
export const CREATE_TABLE_JOB = `
CREATE TABLE IF NOT EXISTS ${TABLE_JOB} (
  job_id TEXT PRIMARY KEY,
  recruiter_id TEXT NOT NULL,
  company_name TEXT,
  title TEXT NOT NULL,
  category TEXT,
  description TEXT,
  education_required TEXT,
  salary_range TEXT,
  work_years_required TEXT,
  work_address TEXT,
  city TEXT,
  skills TEXT,
  status TEXT DEFAULT 'published',
  publish_time INTEGER,
  update_time INTEGER,
  view_count INTEGER DEFAULT 0,
  apply_count INTEGER DEFAULT 0,
  tags TEXT,
  is_ai_generated INTEGER DEFAULT 0,
  task_start_time INTEGER DEFAULT -1,
  task_end_time INTEGER DEFAULT -1,
  required_day_of_week INTEGER DEFAULT -1,
  required_start_hour INTEGER DEFAULT -1,
  required_end_hour INTEGER DEFAULT -1
)`

// 投递表
export const TABLE_APPLICATION = 'tb_application'
export const CREATE_TABLE_APPLICATION = `
CREATE TABLE IF NOT EXISTS ${TABLE_APPLICATION} (
  application_id TEXT PRIMARY KEY,
  job_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  resume_id TEXT,
  status TEXT DEFAULT 'submitted',
  apply_time INTEGER,
  interview_time INTEGER,
  remark TEXT,
  rejection_reason TEXT,
  view_time INTEGER
)`

// 微任务表
export const TABLE_MICRO_TASK = 'tb_micro_task'
export const CREATE_TABLE_MICRO_TASK = `
CREATE TABLE IF NOT EXISTS ${TABLE_MICRO_TASK} (
  task_id TEXT PRIMARY KEY,
  recruiter_id TEXT NOT NULL,
  title TEXT,
  description TEXT,
  price REAL,
  deadline TEXT,
  skills TEXT,
  status TEXT,
  publish_time INTEGER,
  accepted_by TEXT,
  required_day_of_week INTEGER DEFAULT -1,
  required_start_hour INTEGER DEFAULT -1,
  required_end_hour INTEGER DEFAULT -1
)`

// 聊天会话表
export const TABLE_CHAT_SESSION = 'tb_chat_session'
export const CREATE_TABLE_CHAT_SESSION = `
CREATE TABLE IF NOT EXISTS ${TABLE_CHAT_SESSION} (
  session_id TEXT PRIMARY KEY,
  peer_id TEXT NOT NULL,
  peer_name TEXT,
  peer_avatar TEXT,
  last_message TEXT,
  last_message_time INTEGER,
  unread_count INTEGER DEFAULT 0,
  is_ai_agent INTEGER DEFAULT 0
)`

// 聊天消息表
export const TABLE_CHAT_MESSAGE = 'tb_chat_message'
export const CREATE_TABLE_CHAT_MESSAGE = `
CREATE TABLE IF NOT EXISTS ${TABLE_CHAT_MESSAGE} (
  message_id TEXT PRIMARY KEY,
  session_id TEXT NOT NULL,
  sender_id TEXT NOT NULL,
  receiver_id TEXT,
  content TEXT,
  timestamp INTEGER,
  is_ai_agent_reply INTEGER DEFAULT 0,
  message_type TEXT DEFAULT 'text',
  is_read INTEGER DEFAULT 0
)`

// 系统消息表
export const TABLE_SYSTEM_MESSAGE = 'tb_system_message'
export const CREATE_TABLE_SYSTEM_MESSAGE = `
CREATE TABLE IF NOT EXISTS ${TABLE_SYSTEM_MESSAGE} (
  message_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  title TEXT,
  content TEXT,
  type TEXT,
  is_read INTEGER DEFAULT 0,
  timestamp INTEGER
)`

// 企业信息表
export const TABLE_COMPANY = 'tb_company'
export const CREATE_TABLE_COMPANY = `
CREATE TABLE IF NOT EXISTS ${TABLE_COMPANY} (
  company_id TEXT PRIMARY KEY,
  name TEXT,
  logo TEXT,
  industry TEXT,
  scale TEXT,
  description TEXT,
  address TEXT,
  recruitment_plan TEXT,
  alumni_network TEXT
)`

// 宣讲会表
export const TABLE_CAREER_TALK = 'tb_career_talk'
export const CREATE_TABLE_CAREER_TALK = `
CREATE TABLE IF NOT EXISTS ${TABLE_CAREER_TALK} (
  talk_id TEXT PRIMARY KEY,
  company_id TEXT NOT NULL,
  company_name TEXT,
  title TEXT,
  date TEXT,
  time TEXT,
  location TEXT,
  is_online INTEGER DEFAULT 0,
  online_link TEXT
)`

// 社区帖子表
export const TABLE_COMMUNITY_POST = 'tb_community_post'
export const CREATE_TABLE_COMMUNITY_POST = `
CREATE TABLE IF NOT EXISTS ${TABLE_COMMUNITY_POST} (
  post_id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  school TEXT,
  title TEXT,
  content TEXT,
  category TEXT,
  is_anonymous INTEGER DEFAULT 0,
  tags TEXT,
  like_count INTEGER DEFAULT 0,
  favorite_count INTEGER DEFAULT 0,
  comment_count INTEGER DEFAULT 0,
  create_time INTEGER
)`

// 帖子评论表
export const TABLE_POST_COMMENT = 'tb_post_comment'
export const CREATE_TABLE_POST_COMMENT = `
CREATE TABLE IF NOT EXISTS ${TABLE_POST_COMMENT} (
  comment_id TEXT PRIMARY KEY,
  post_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  content TEXT,
  is_anonymous INTEGER DEFAULT 0,
  create_time INTEGER
)`

export const TABLE_POST_LIKE = 'tb_post_like'
export const CREATE_TABLE_POST_LIKE = `
CREATE TABLE IF NOT EXISTS ${TABLE_POST_LIKE} (
  user_id TEXT NOT NULL,
  post_id TEXT NOT NULL,
  create_time INTEGER,
  PRIMARY KEY (user_id, post_id)
)`

export const TABLE_POST_FAVORITE = 'tb_post_favorite'
export const CREATE_TABLE_POST_FAVORITE = `
CREATE TABLE IF NOT EXISTS ${TABLE_POST_FAVORITE} (
  user_id TEXT NOT NULL,
  post_id TEXT NOT NULL,
  create_time INTEGER,
  PRIMARY KEY (user_id, post_id)
)`

// 用户偏好设置表
export const TABLE_USER_SETTING = 'tb_user_setting'
export const CREATE_TABLE_USER_SETTING = `
CREATE TABLE IF NOT EXISTS ${TABLE_USER_SETTING} (
  user_id TEXT PRIMARY KEY,
  ai_agent_enabled INTEGER DEFAULT 0,
  auto_translate_resume INTEGER DEFAULT 0,
  update_time INTEGER
)`

// 短信验证码表
export const TABLE_VERIFY_CODE = 'tb_verify_code'
export const CREATE_TABLE_VERIFY_CODE = `
CREATE TABLE IF NOT EXISTS ${TABLE_VERIFY_CODE} (
  phone TEXT PRIMARY KEY,
  code TEXT NOT NULL,
  expire_time INTEGER NOT NULL,
  created_at INTEGER NOT NULL
)`

// AI虚拟人面试记录表
export const TABLE_AI_INTERVIEW = 'tb_ai_interview'
export const CREATE_TABLE_AI_INTERVIEW = `
CREATE TABLE IF NOT EXISTS ${TABLE_AI_INTERVIEW} (
  interview_id TEXT PRIMARY KEY,
  recruiter_id TEXT NOT NULL,
  user_id TEXT NOT NULL,
  job_id TEXT NOT NULL,
  application_id TEXT NOT NULL,
  status TEXT DEFAULT 'invited',
  questions TEXT,
  answers TEXT,
  assessment_result TEXT,
  total_score INTEGER DEFAULT 0,
  invite_time INTEGER,
  start_time INTEGER,
  complete_time INTEGER
)`

export const ALL_CREATE_TABLES: string[] = [
  CREATE_TABLE_USER,
  CREATE_TABLE_RESUME,
  CREATE_TABLE_EDUCATION,
  CREATE_TABLE_EXPERIENCE,
  CREATE_TABLE_SCHEDULE,
  CREATE_TABLE_JOB,
  CREATE_TABLE_APPLICATION,
  CREATE_TABLE_MICRO_TASK,
  CREATE_TABLE_CHAT_SESSION,
  CREATE_TABLE_CHAT_MESSAGE,
  CREATE_TABLE_SYSTEM_MESSAGE,
  CREATE_TABLE_COMPANY,
  CREATE_TABLE_CAREER_TALK,
  CREATE_TABLE_COMMUNITY_POST,
  CREATE_TABLE_POST_COMMENT,
  CREATE_TABLE_POST_LIKE,
  CREATE_TABLE_POST_FAVORITE,
  CREATE_TABLE_USER_SETTING,
  CREATE_TABLE_VERIFY_CODE,
  CREATE_TABLE_AI_INTERVIEW
]
