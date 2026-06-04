import { relationalStore } from '@kit.ArkData'
import {
  TABLE_USER,
  TABLE_JOB,
  TABLE_COMPANY,
  TABLE_CAREER_TALK,
  TABLE_COMMUNITY_POST
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
  commentCount: number
}

function escapeSql(value: string): string {
  return value.replace(/'/g, "''")
}

export class DemoDataInitializer {
  static async seed(store: relationalStore.RdbStore): Promise<void> {
    const now: number = Date.now()
    await DemoDataInitializer.seedUsers(store, now)
    await DemoDataInitializer.seedCompanies(store)
    await DemoDataInitializer.seedTalks(store)
    await DemoDataInitializer.seedJobs(store, now)
    await DemoDataInitializer.seedPosts(store, now)
  }

  private static async seedUsers(store: relationalStore.RdbStore, now: number): Promise<void> {
    await store.executeSql(
      `INSERT OR IGNORE INTO ${TABLE_USER}
      (user_id, phone, role, student_type, real_name, school, major, expected_position, expected_salary, is_guest, password, create_time, update_time, is_login)
      VALUES
      ('student_demo_001', '13800138000', 'job_seeker', '', '', '', '', '', '', 0, '123456', ${now}, ${now}, 0)`
    )
    await store.executeSql(
      `INSERT OR IGNORE INTO ${TABLE_USER}
      (user_id, phone, role, company_name, vip_level, position_count, hr_real_name, is_guest, password, create_time, update_time, is_login)
      VALUES
      ('recruiter_demo_001', '13900139000', 'recruiter', 'Xiaomi Group', 'normal', 0, 'Campus HR', 0, '123456', ${now}, ${now}, 0)`
    )
  }

  private static async seedJobs(store: relationalStore.RdbStore, now: number): Promise<void> {
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
        tags: ['return-offer', 'frontend']
      },
      {
        jobId: 'job_seed_002',
        recruiterId: 'recruiter_demo_001',
        companyName: 'Tencent',
        title: 'Campus Content Operator',
        category: 'micro_task',
        description: 'Write content, manage groups, and track event signup data.',
        educationRequired: 'College or above',
        salaryRange: '80-120/task',
        workYearsRequired: 'No limit',
        workAddress: 'Remote',
        city: 'Changsha',
        skills: ['copywriting', 'community', 'excel'],
        tags: ['remote', 'weekend']
      },
      {
        jobId: 'job_seed_003',
        recruiterId: 'recruiter_demo_001',
        companyName: 'MiHoYo',
        title: 'Python Data Assistant',
        category: 'micro_task',
        description: 'Clean tables, process scripts, and organize weekly reports.',
        educationRequired: 'Bachelor',
        salaryRange: '200-300/task',
        workYearsRequired: 'No limit',
        workAddress: 'Remote',
        city: 'Shanghai',
        skills: ['Python', 'Pandas', 'data-cleaning'],
        tags: ['task-based', 'flexible']
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
        tags: ['big-tech', 'backend']
      }
    ]

    for (let i = 0; i < jobs.length; i++) {
      const job: SeedJob = jobs[i]
      await store.executeSql(
        `INSERT OR IGNORE INTO ${TABLE_JOB}
        (job_id, recruiter_id, company_name, title, category, description, education_required, salary_range, work_years_required, work_address, city, skills, status, publish_time, update_time, view_count, apply_count, tags, is_ai_generated)
        VALUES
        ('${job.jobId}', '${job.recruiterId}', '${escapeSql(job.companyName)}', '${escapeSql(job.title)}', '${job.category}', '${escapeSql(job.description)}', '${escapeSql(job.educationRequired)}', '${escapeSql(job.salaryRange)}', '${escapeSql(job.workYearsRequired)}', '${escapeSql(job.workAddress)}', '${escapeSql(job.city)}', '${escapeSql(JSON.stringify(job.skills))}', 'published', ${now - i * 7200000}, ${now - i * 7200000}, ${30 + i * 7}, ${3 + i}, '${escapeSql(JSON.stringify(job.tags))}', 0)`
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
        commentCount: 1
      }
    ]

    for (let i = 0; i < posts.length; i++) {
      const post: SeedPost = posts[i]
      await store.executeSql(
        `INSERT OR IGNORE INTO ${TABLE_COMMUNITY_POST}
        (post_id, user_id, school, title, content, category, is_anonymous, tags, like_count, comment_count, create_time)
        VALUES
        ('${post.postId}', '${post.userId}', '${escapeSql(post.school)}', '${escapeSql(post.title)}', '${escapeSql(post.content)}', '${post.category}', ${post.isAnonymous ? 1 : 0}, '${escapeSql(JSON.stringify(post.tags))}', ${post.likeCount}, ${post.commentCount}, ${now - i * 3600000})`
      )
    }
  }
}
