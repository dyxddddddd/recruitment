import { relationalStore } from '@kit.ArkData'
import {
  TABLE_USER,
  TABLE_JOB,
  TABLE_COMPANY,
  TABLE_CAREER_TALK,
  TABLE_COMMUNITY_POST,
  TABLE_POST_COMMENT,
  TABLE_CHAT_SESSION,
  TABLE_CHAT_MESSAGE
} from './Tables'

interface SeedJob {
  jobId: string
  recruiterId: string
  companyName: string
  title: string
  category: string
  description: string
  educationRequired: string
  salaryRange: string
  workYearsRequired: string
  workAddress: string
  city: string
  skills: string[]
  tags: string[]
  taskStartTime: number
  taskEndTime: number
  requiredDayOfWeek: number
  requiredStartHour: number
  requiredEndHour: number
}

interface SeedRecruitmentPlan {
  year: string
  totalPositions: number
  positions: string[]
  description: string
}

interface SeedAlumniNode {
  alumniId: string
  name: string
  school: string
  major: string
  graduationYear: string
  department: string
  position: string
  connections: string[]
}

interface SeedCompany {
  companyId: string
  name: string
  logo: string
  industry: string
  scale: string
  description: string
  address: string
  recruitmentPlan: SeedRecruitmentPlan
  alumniNetwork: SeedAlumniNode[]
}

interface SeedTalk {
  talkId: string
  companyId: string
  companyName: string
  title: string
  date: string
  time: string
  location: string
  isOnline: boolean
  onlineLink: string
}

interface SeedPost {
  postId: string
  userId: string
  school: string
  title: string
  content: string
  category: string
  isAnonymous: boolean
  tags: string[]
  likeCount: number
  favoriteCount: number
  commentCount: number
}

interface SeedComment {
  commentId: string
  postId: string
  userId: string
  content: string
  isAnonymous: boolean
}

function escapeSql(value: string): string {
  return value.replace(/'/g, "''")
}

function buildNextWeekdayTime(baseTime: number, dayOfWeek: number, hour: number, minute: number = 0): number {
  const baseDate = new Date(baseTime)
  const currentDay = baseDate.getDay()
  let deltaDay = dayOfWeek - currentDay
  if (deltaDay < 0) {
    deltaDay += 7
  }
  const target = new Date(baseDate.getTime())
  target.setDate(baseDate.getDate() + deltaDay)
  target.setHours(hour, minute, 0, 0)
  if (target.getTime() <= baseTime) {
    target.setDate(target.getDate() + 7)
  }
  return target.getTime()
}

export class DemoDataInitializer {
  static async seed(store: relationalStore.RdbStore): Promise<void> {
    const now: number = Date.now()
    await DemoDataInitializer.seedUsers(store, now)
    await DemoDataInitializer.seedCompanies(store)
    await DemoDataInitializer.seedTalks(store)
    await DemoDataInitializer.seedJobs(store, now)
    await DemoDataInitializer.seedPosts(store, now)
    await DemoDataInitializer.seedComments(store, now)
    await DemoDataInitializer.seedChatSessions(store, now)
  }

  private static async seedUsers(store: relationalStore.RdbStore, now: number): Promise<void> {
    // 学生端演示账号
    await store.executeSql(
      `INSERT OR IGNORE INTO ${TABLE_USER}
      (user_id, phone, role, student_type, real_name, gender, school, major, education, expected_position, expected_salary, is_guest, password, create_time, update_time, is_login)
      VALUES
      ('student_demo_001', '13800138000', 'job_seeker', 'current', '校园同学', 'male', '中南大学', '软件工程', '本科', '前端开发实习', '6000', 0, '123456', ${now}, ${now}, 0)`
    )
    await store.executeSql(
      `INSERT OR IGNORE INTO ${TABLE_USER}
      (user_id, phone, role, is_guest, password, create_time, update_time, is_login)
      VALUES
      ('student_demo_002', '13800001234', 'job_seeker', 0, '123456', ${now}, ${now}, 0)`
    )

    // ========== 企业端演示账号 ==========
    await store.executeSql(
      `INSERT OR IGNORE INTO ${TABLE_USER}
      (user_id, phone, role, company_name, vip_level, position_count, hr_real_name, is_guest, password, create_time, update_time, is_login)
      VALUES
      ('recruiter_demo_001', '13900139000', 'recruiter', '小米集团', 'normal', 0, '董雨欣', 0, '123456', ${now}, ${now}, 0)`
    )
    await store.executeSql(
      `INSERT OR IGNORE INTO ${TABLE_USER}
      (user_id, phone, role, company_name, vip_level, position_count, hr_real_name, is_guest, password, create_time, update_time, is_login)
      VALUES
      ('recruiter_demo_002', '13800000001', 'recruiter', '字节跳动', 'normal', 0, '张HR', 0, '123456', ${now}, ${now}, 0)`
    )
    await store.executeSql(
      `INSERT OR IGNORE INTO ${TABLE_USER}
      (user_id, phone, role, company_name, vip_level, position_count, hr_real_name, is_guest, password, create_time, update_time, is_login)
      VALUES
      ('recruiter_demo_003', '13800000002', 'recruiter', '华为技术', 'vip', 0, '李HR', 0, '123456', ${now}, ${now}, 0)`
    )
    await store.executeSql(
      `INSERT OR IGNORE INTO ${TABLE_USER}
      (user_id, phone, role, company_name, vip_level, position_count, hr_real_name, is_guest, password, create_time, update_time, is_login)
      VALUES
      ('recruiter_demo_004', '13800000003', 'recruiter', '蓝湖传媒', 'normal', 0, '王HR', 0, '123456', ${now}, ${now}, 0)`
    )

    // 强制同步演示账号密码（每次启动都执行，确保登录可用）
    const demoIds = ['student_demo_001', 'student_demo_002', 'recruiter_demo_001', 'recruiter_demo_002', 'recruiter_demo_003', 'recruiter_demo_004']
    for (let i = 0; i < demoIds.length; i++) {
      await store.executeSql(
        `UPDATE ${TABLE_USER} SET password = '123456', update_time = ${now} WHERE user_id = '${demoIds[i]}'`
      )
    }
  }

  private static async resetSeedJobs(store: relationalStore.RdbStore): Promise<void> {
    await store.executeSql(`DELETE FROM ${TABLE_JOB} WHERE job_id IN (
      'job_seed_001', 'job_seed_002', 'job_seed_003', 'job_seed_004',
      'job_seed_005', 'job_seed_006', 'job_seed_007', 'job_seed_008',
      'job_seed_009', 'job_seed_010', 'job_seed_011', 'job_seed_012'
    )`)
  }

  private static async seedJobs(store: relationalStore.RdbStore, now: number): Promise<void> {
    await DemoDataInitializer.resetSeedJobs(store)
    const jobs: SeedJob[] = [
      {
        jobId: 'job_seed_001',
        recruiterId: 'recruiter_demo_001',
        companyName: 'Xiaomi Group',
        title: 'Frontend Intern',
        category: 'fulltime',
        description: 'Build campus recruiting product pages and component modules.',
        educationRequired: 'Bachelor',
        salaryRange: '150/day',
        workYearsRequired: 'No limit',
        workAddress: 'Changsha High-tech Zone',
        city: 'Changsha',
        skills: ['ArkTS', 'TypeScript', 'React'],
        tags: ['return-offer', 'frontend'],
        taskStartTime: -1,
        taskEndTime: -1,
        requiredDayOfWeek: -1,
        requiredStartHour: -1,
        requiredEndHour: -1
      },
      {
        jobId: 'job_seed_004',
        recruiterId: 'recruiter_demo_001',
        companyName: 'ByteDance',
        title: 'Backend Intern',
        category: 'fulltime',
        description: 'Develop internal platform services and improve interfaces and logs.',
        educationRequired: 'Bachelor',
        salaryRange: '200-260/day',
        workYearsRequired: 'No limit',
        workAddress: 'Beijing',
        city: 'Beijing',
        skills: ['Java', 'Spring Boot', 'MySQL'],
        tags: ['big-tech', 'backend'],
        taskStartTime: -1,
        taskEndTime: -1,
        requiredDayOfWeek: -1,
        requiredStartHour: -1,
        requiredEndHour: -1
      },
      {
        jobId: 'job_seed_011',
        recruiterId: 'recruiter_demo_002',
        companyName: 'BlueLake Media',
        title: '字幕质检助理',
        category: 'micro_task',
        description: '校对短视频字幕、检查错别字并提交修改建议，适合有耐心的同学。',
        educationRequired: 'College or above',
        salaryRange: '80-100/task',
        workYearsRequired: 'No limit',
        workAddress: 'Remote',
        city: 'Changsha',
        skills: ['文案', '细心', 'Office'],
        tags: ['remote', '内容审核'],
        taskStartTime: buildNextWeekdayTime(now, 1, 19, 0),
        taskEndTime: buildNextWeekdayTime(now, 1, 21, 0),
        requiredDayOfWeek: 1,
        requiredStartHour: 19,
        requiredEndHour: 21
      },
      {
        jobId: 'job_seed_012',
        recruiterId: 'recruiter_demo_002',
        companyName: 'Campus Orange',
        title: '活动签到协助',
        category: 'micro_task',
        description: '现场协助活动签到、引导入场并整理报名信息。',
        educationRequired: 'College or above',
        salaryRange: '70/task',
        workYearsRequired: 'No limit',
        workAddress: '岳麓区大学生活动中心',
        city: 'Changsha',
        skills: ['沟通', '执行', '表格处理'],
        tags: ['onsite', '活动支持'],
        taskStartTime: buildNextWeekdayTime(now, 3, 12, 0),
        taskEndTime: buildNextWeekdayTime(now, 3, 14, 0),
        requiredDayOfWeek: 3,
        requiredStartHour: 12,
        requiredEndHour: 14
      },
      {
        jobId: 'job_seed_013',
        recruiterId: 'recruiter_demo_003',
        companyName: 'Maple Survey Lab',
        title: '问卷整理员',
        category: 'micro_task',
        description: '整理问卷样本、标记无效数据并输出汇总表。',
        educationRequired: 'Bachelor',
        salaryRange: '100-150/task',
        workYearsRequired: 'No limit',
        workAddress: 'Remote',
        city: 'Changsha',
        skills: ['Excel', '数据清洗', '耐心'],
        tags: ['remote', '数据处理'],
        taskStartTime: buildNextWeekdayTime(now, 5, 20, 0),
        taskEndTime: buildNextWeekdayTime(now, 5, 22, 0),
        requiredDayOfWeek: 5,
        requiredStartHour: 20,
        requiredEndHour: 22
      },
      {
        jobId: 'job_seed_014',
        recruiterId: 'recruiter_demo_003',
        companyName: 'Pineapple Community',
        title: '社群答疑助手',
        category: 'micro_task',
        description: '在用户群里回答常见问题，并记录待跟进事项。',
        educationRequired: 'College or above',
        salaryRange: '80-120/shift',
        workYearsRequired: 'No limit',
        workAddress: 'Remote',
        city: 'Changsha',
        skills: ['社群运营', '打字', '服务意识'],
        tags: ['weekend', 'remote'],
        taskStartTime: buildNextWeekdayTime(now, 6, 9, 0),
        taskEndTime: buildNextWeekdayTime(now, 6, 12, 0),
        requiredDayOfWeek: 6,
        requiredStartHour: 9,
        requiredEndHour: 12
      },
      {
        jobId: 'job_seed_015',
        recruiterId: 'recruiter_demo_004',
        companyName: 'NorthStar Design',
        title: '海报改稿支持',
        category: 'micro_task',
        description: '协助修改活动海报细节并导出多尺寸图片。',
        educationRequired: 'College or above',
        salaryRange: '120-180/task',
        workYearsRequired: 'No limit',
        workAddress: 'Remote',
        city: 'Changsha',
        skills: ['Figma', '设计执行', '审美'],
        tags: ['weekend', '设计'],
        taskStartTime: buildNextWeekdayTime(now, 0, 14, 0),
        taskEndTime: buildNextWeekdayTime(now, 0, 18, 0),
        requiredDayOfWeek: 0,
        requiredStartHour: 14,
        requiredEndHour: 18
      },
      {
        jobId: 'job_seed_016',
        recruiterId: 'recruiter_demo_004',
        companyName: 'CloudArk QA',
        title: '小程序测试体验员',
        category: 'micro_task',
        description: '体验小程序核心流程，提交截图和问题复现步骤。',
        educationRequired: 'College or above',
        salaryRange: '90-130/task',
        workYearsRequired: 'No limit',
        workAddress: 'Remote',
        city: 'Changsha',
        skills: ['测试', '截图', '问题反馈'],
        tags: ['weeknight', 'QA'],
        taskStartTime: buildNextWeekdayTime(now, 2, 19, 0),
        taskEndTime: buildNextWeekdayTime(now, 2, 22, 0),
        requiredDayOfWeek: 2,
        requiredStartHour: 19,
        requiredEndHour: 22
      }
    ]

    for (let i = 0; i < jobs.length; i++) {
      const job: SeedJob = jobs[i]
      await store.executeSql(
        `INSERT OR IGNORE INTO ${TABLE_JOB}
        (job_id, recruiter_id, company_name, title, category, description, education_required, salary_range, work_years_required, work_address, city, skills, status, publish_time, update_time, view_count, apply_count, tags, is_ai_generated, task_start_time, task_end_time, required_day_of_week, required_start_hour, required_end_hour)
        VALUES
        ('${job.jobId}', '${job.recruiterId}', '${escapeSql(job.companyName)}', '${escapeSql(job.title)}', '${job.category}', '${escapeSql(job.description)}', '${escapeSql(job.educationRequired)}', '${escapeSql(job.salaryRange)}', '${escapeSql(job.workYearsRequired)}', '${escapeSql(job.workAddress)}', '${escapeSql(job.city)}', '${escapeSql(JSON.stringify(job.skills))}', 'published', ${now - i * 7200000}, ${now - i * 7200000}, ${30 + i * 7}, ${3 + i}, '${escapeSql(JSON.stringify(job.tags))}', 0, ${job.taskStartTime ?? -1}, ${job.taskEndTime ?? -1}, ${job.requiredDayOfWeek ?? -1}, ${job.requiredStartHour ?? -1}, ${job.requiredEndHour ?? -1})`
      )
    }
  }

  private static async seedCompanies(store: relationalStore.RdbStore): Promise<void> {
    const companies: SeedCompany[] = [
      {
        companyId: 'company_seed_001',
        name: 'Xiaomi Group',
        logo: 'MI',
        industry: 'Consumer Electronics / Internet',
        scale: '10000+',
        description: 'Open internship and graduate roles for campus hiring.',
        address: 'Beijing',
        recruitmentPlan: {
          year: '2027',
          totalPositions: 12,
          positions: ['Frontend', 'Backend', 'Operations'],
          description: 'Open to interns, early autumn hiring, and training camp.'
        },
        alumniNetwork: [
          {
            alumniId: 'alumni_001',
            name: 'Anonymous A',
            school: 'Central South University',
            major: 'Software Engineering',
            graduationYear: '2023',
            department: 'Terminal R&D',
            position: 'Frontend Engineer',
            connections: ['alumni_002']
          },
          {
            alumniId: 'alumni_002',
            name: 'Anonymous B',
            school: 'Hunan University',
            major: 'Computer Science',
            graduationYear: '2022',
            department: 'Platform R&D',
            position: 'Backend Engineer',
            connections: ['alumni_001']
          }
        ]
      },
      {
        companyId: 'company_seed_002',
        name: 'ByteDance',
        logo: 'BD',
        industry: 'Internet / Content Platform',
        scale: '10000+',
        description: 'Campus jobs for frontend, backend, data, and operations.',
        address: 'Beijing',
        recruitmentPlan: {
          year: '2027',
          totalPositions: 18,
          positions: ['Frontend', 'Backend', 'Data Analysis'],
          description: 'Support long-term internship and early campus hiring.'
        },
        alumniNetwork: [
          {
            alumniId: 'alumni_003',
            name: 'Anonymous C',
            school: 'Central South University',
            major: 'Computer Science',
            graduationYear: '2024',
            department: 'Info Platform',
            position: 'R&D Engineer',
            connections: []
          }
        ]
      }
    ]

    for (let i = 0; i < companies.length; i++) {
      const company: SeedCompany = companies[i]
      await store.executeSql(
        `INSERT OR IGNORE INTO ${TABLE_COMPANY}
        (company_id, name, logo, industry, scale, description, address, recruitment_plan, alumni_network)
        VALUES
        ('${company.companyId}', '${escapeSql(company.name)}', '${escapeSql(company.logo)}', '${escapeSql(company.industry)}', '${escapeSql(company.scale)}', '${escapeSql(company.description)}', '${escapeSql(company.address)}', '${escapeSql(JSON.stringify(company.recruitmentPlan))}', '${escapeSql(JSON.stringify(company.alumniNetwork))}')`
      )
    }
  }

  private static async seedTalks(store: relationalStore.RdbStore): Promise<void> {
    const talks: SeedTalk[] = [
      {
        talkId: 'talk_seed_001',
        companyId: 'company_seed_001',
        companyName: 'Xiaomi Group',
        title: 'Xiaomi 2027 Campus Talk',
        date: '2026-06-18',
        time: '19:00',
        location: 'Central South University A201',
        isOnline: false,
        onlineLink: ''
      },
      {
        talkId: 'talk_seed_002',
        companyId: 'company_seed_002',
        companyName: 'ByteDance',
        title: 'ByteDance Tech Sharing Live',
        date: '2026-06-20',
        time: '20:00',
        location: 'Online',
        isOnline: true,
        onlineLink: 'https://campus.example.com/live'
      }
    ]

    for (let i = 0; i < talks.length; i++) {
      const talk: SeedTalk = talks[i]
      await store.executeSql(
        `INSERT OR IGNORE INTO ${TABLE_CAREER_TALK}
        (talk_id, company_id, company_name, title, date, time, location, is_online, online_link)
        VALUES
        ('${talk.talkId}', '${talk.companyId}', '${escapeSql(talk.companyName)}', '${escapeSql(talk.title)}', '${talk.date}', '${talk.time}', '${escapeSql(talk.location)}', ${talk.isOnline ? 1 : 0}, '${escapeSql(talk.onlineLink)}')`
      )
    }
  }

  private static async seedPosts(store: relationalStore.RdbStore, now: number): Promise<void> {
    const posts: SeedPost[] = [
      {
        postId: 'post_seed_001',
        userId: 'student_demo_001',
        school: 'Central South University',
        title: 'Frontend internship interview notes',
        content: 'Questions focused on project breakdown, API integration, and performance.',
        category: 'interview',
        isAnonymous: true,
        tags: ['frontend', 'interview', 'changsha'],
        likeCount: 8,
        favoriteCount: 3,
        commentCount: 2
      },
      {
        postId: 'post_seed_002',
        userId: 'student_demo_001',
        school: 'Central South University',
        title: 'Looking for a backend interview partner',
        content: 'Want to practice interview questions and review resumes together.',
        category: 'companion',
        isAnonymous: true,
        tags: ['backend', 'practice', 'study-buddy'],
        likeCount: 5,
        favoriteCount: 2,
        commentCount: 1
      },
      {
        postId: 'post_seed_003',
        userId: 'student_demo_001',
        school: 'Central South University',
        title: 'ByteDance backend intern written test review',
        content: 'The written test covered networking basics, SQL, and two coding questions. The difficulty was moderate but time was tight.',
        category: 'interview',
        isAnonymous: true,
        tags: ['backend', 'bytedance', 'written-test'],
        likeCount: 9,
        favoriteCount: 4,
        commentCount: 1
      }
    ]

    for (let i = 0; i < posts.length; i++) {
      const post: SeedPost = posts[i]
      await store.executeSql(
        `INSERT OR IGNORE INTO ${TABLE_COMMUNITY_POST}
        (post_id, user_id, school, title, content, category, is_anonymous, tags, like_count, favorite_count, comment_count, create_time)
        VALUES
        ('${post.postId}', '${post.userId}', '${escapeSql(post.school)}', '${escapeSql(post.title)}', '${escapeSql(post.content)}', '${post.category}', ${post.isAnonymous ? 1 : 0}, '${escapeSql(JSON.stringify(post.tags))}', ${post.likeCount}, ${post.favoriteCount}, ${post.commentCount}, ${now - i * 3600000})`
      )
    }
  }

  private static async seedComments(store: relationalStore.RdbStore, now: number): Promise<void> {
    const comments: SeedComment[] = [
      {
        commentId: 'comment_seed_001',
        postId: 'post_seed_001',
        userId: 'student_demo_001',
        content: '二面主要追问了项目里你自己负责的模块，可以提前准备拆解。',
        isAnonymous: true
      },
      {
        commentId: 'comment_seed_002',
        postId: 'post_seed_001',
        userId: 'student_demo_001',
        content: '如果是前端岗，性能优化和接口异常处理基本都会问到。',
        isAnonymous: true
      },
      {
        commentId: 'comment_seed_003',
        postId: 'post_seed_002',
        userId: 'student_demo_001',
        content: '我也在找后端搭子，晚上可以一起刷题。',
        isAnonymous: true
      },
      {
        commentId: 'comment_seed_004',
        postId: 'post_seed_003',
        userId: 'student_demo_001',
        content: '这场笔试数据库题不少，建议提前把索引和 join 复习一下。',
        isAnonymous: true
      }
    ]

    for (let i = 0; i < comments.length; i++) {
      const comment: SeedComment = comments[i]
      await store.executeSql(
        `INSERT OR IGNORE INTO ${TABLE_POST_COMMENT}
        (comment_id, post_id, user_id, content, is_anonymous, create_time)
        VALUES
        ('${comment.commentId}', '${comment.postId}', '${comment.userId}', '${escapeSql(comment.content)}', ${comment.isAnonymous ? 1 : 0}, ${now - i * 1800000})`
      )
    }
  }

  private static async seedChatSessions(store: relationalStore.RdbStore, now: number): Promise<void> {
    const conv1 = 'recruiter_demo_001:student_demo_001'
    await store.executeSql(
      `INSERT OR IGNORE INTO ${TABLE_CHAT_SESSION}
      (session_id, peer_id, peer_name, peer_avatar, last_message, last_message_time, unread_count, is_ai_agent)
      VALUES ('${conv1}', 'student_demo_001', '校园同学', '', '你好 HR，我对贵公司的实习岗位比较感兴趣。', ${now}, 1, 0)`
    )
    await store.executeSql(
      `INSERT OR IGNORE INTO ${TABLE_CHAT_MESSAGE}
      (message_id, session_id, sender_id, receiver_id, content, timestamp, is_ai_agent_reply, message_type, is_read)
      VALUES ('msg_demo_seed_1', '${conv1}', 'student_demo_001', 'recruiter_demo_001', '你好 HR，我对贵公司的实习岗位比较感兴趣。', ${now - 3600000}, 0, 'text', 0)`
    )
    await store.executeSql(
      `INSERT OR IGNORE INTO ${TABLE_CHAT_MESSAGE}
      (message_id, session_id, sender_id, receiver_id, content, timestamp, is_ai_agent_reply, message_type, is_read)
      VALUES ('msg_demo_seed_2', '${conv1}', 'recruiter_demo_001', 'student_demo_001', '你好，方便介绍一下你的项目经历吗？', ${now - 1800000}, 0, 'text', 1)`
    )

    // 另一个学生的会话
    const conv2 = 'recruiter_demo_001:student_demo_002'
    await store.executeSql(
      `INSERT OR IGNORE INTO ${TABLE_CHAT_SESSION}
      (session_id, peer_id, peer_name, peer_avatar, last_message, last_message_time, unread_count, is_ai_agent)
      VALUES ('${conv2}', 'student_demo_002', '学生用户', '', '后端实习还有 HC 吗？', ${now - 7200000}, 0, 0)`
    )
    await store.executeSql(
      `INSERT OR IGNORE INTO ${TABLE_CHAT_MESSAGE}
      (message_id, session_id, sender_id, receiver_id, content, timestamp, is_ai_agent_reply, message_type, is_read)
      VALUES ('msg_demo_seed_3', '${conv2}', 'student_demo_002', 'recruiter_demo_001', '后端实习还有 HC 吗？', ${now - 7200000}, 0, 'text', 1)`
    )
  }
}
