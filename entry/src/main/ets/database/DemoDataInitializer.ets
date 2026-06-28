import { relationalStore } from '@kit.ArkData'
import {
  TABLE_USER,
  TABLE_JOB,
  TABLE_COMPANY,
  TABLE_CAREER_TALK,
  TABLE_COMMUNITY_POST,
  TABLE_POST_COMMENT,
  TABLE_CHAT_SESSION,
  TABLE_CHAT_MESSAGE,
  TABLE_RESUME,
  TABLE_EXPERIENCE
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
    // 聊天会话不再预置演示数据，仅保留真实互动产生的对话
  }

  private static async seedUsers(store: relationalStore.RdbStore, now: number): Promise<void> {
    // 学生端演示账号
    await store.executeSql(
      `INSERT OR IGNORE INTO ${TABLE_USER}
      (user_id, phone, role, student_type, real_name, gender, school, major, education, expected_position, expected_salary, current_city, is_guest, password, create_time, update_time, is_login)
      VALUES
      ('student_demo_001', '13800138000', 'job_seeker', 'current', '陈逸飞', 'male', '中南大学', '软件工程', '本科大三', '前端开发实习', '4000-6000', '长沙', 0, '123456', ${now}, ${now}, 0)`
    )
    await store.executeSql(
      `INSERT OR IGNORE INTO ${TABLE_USER}
      (user_id, phone, role, student_type, real_name, gender, school, major, education, expected_position, expected_salary, current_city, is_guest, password, create_time, update_time, is_login)
      VALUES
      ('student_demo_002', '13800001234', 'job_seeker', 'graduating', '林雪莹', 'female', '湖南大学', '计算机科学与技术', '硕士', 'Java后端开发', '12000-18000', '长沙', 0, '123456', ${now}, ${now}, 0)`
    )

    // 更多样化的学生账号（用于人才匹配多样性测试）
    await store.executeSql(
      `INSERT OR IGNORE INTO ${TABLE_USER}
      (user_id, phone, role, student_type, real_name, gender, school, major, education, expected_position, expected_salary, current_city, is_guest, password, create_time, update_time, is_login)
      VALUES
      ('student_demo_003', '13800001001', 'job_seeker', 'graduating', '赵明远', 'male', '湖南大学', '软件工程', '本科大四', '全栈开发工程师', '10000-15000', '长沙', 0, '123456', ${now}, ${now}, 0),
      ('student_demo_004', '13800001002', 'job_seeker', 'graduating', '王思涵', 'female', '中南大学', '数据科学', '硕士研二', '数据分析师', '12000-16000', '长沙', 0, '123456', ${now}, ${now}, 0),
      ('student_demo_005', '13800001003', 'job_seeker', 'current', '李俊杰', 'male', '湖南师范大学', '市场营销', '本科大三', '新媒体运营实习', '3000-5000', '长沙', 0, '123456', ${now}, ${now}, 0),
      ('student_demo_006', '13800001004', 'job_seeker', 'graduating', '张雨晴', 'female', '中南大学', '视觉传达设计', '本科大四', 'UI/UX设计师', '8000-12000', '长沙', 0, '123456', ${now}, ${now}, 0),
      ('student_demo_007', '13800001005', 'job_seeker', 'graduating', '刘浩然', 'male', '湖南大学', '金融学', '硕士研二', '金融分析师', '15000-20000', '长沙', 0, '123456', ${now}, ${now}, 0),
      ('student_demo_008', '13800001006', 'job_seeker', 'current', '陈思琪', 'female', '长沙理工大学', '会计学', '本科大三', '财务助理', '3000-4500', '长沙', 0, '123456', ${now}, ${now}, 0),
      ('student_demo_009', '13800001007', 'job_seeker', 'current', '周子涵', 'male', '国防科技大学', '人工智能', '硕士研一', 'AI算法实习', '5000-8000', '长沙', 0, '123456', ${now}, ${now}, 0),
      ('student_demo_010', '13800001008', 'job_seeker', 'current', '吴雨桐', 'female', '中南林业科技大学', '英语', '本科大三', '翻译/英语助教', '2500-4000', '长沙', 0, '123456', ${now}, ${now}, 0),
      ('student_demo_011', '13800001009', 'job_seeker', 'graduating', '郑凯文', 'male', '湖南大学', '土木工程', '本科大四', '工程管理员', '7000-10000', '长沙', 0, '123456', ${now}, ${now}, 0),
      ('student_demo_012', '13800001010', 'job_seeker', 'graduating', '杨思远', 'male', '湖南工商大学', '电子商务', '本科大四', '电商运营专员', '6000-9000', '长沙', 0, '123456', ${now}, ${now}, 0),
      ('student_demo_013', '13800001011', 'job_seeker', 'graduating', '黄小雅', 'female', '湘潭大学', '法学', '硕士研二', '法务助理', '8000-11000', '长沙', 0, '123456', ${now}, ${now}, 0),
      ('student_demo_014', '13800001012', 'job_seeker', 'current', '许晨阳', 'male', '湖南科技大学', '计算机科学与技术', '本科大三', 'Java后端实习', '4000-6000', '长沙', 0, '123456', ${now}, ${now}, 0)`
    )

    // 简历种子数据（技能 + 简介 + 手机号，人才卡片展示用）
    await store.executeSql(
      `INSERT OR IGNORE INTO ${TABLE_RESUME}
      (resume_id, user_id, real_name, gender, birthday, education, school, major, expected_position, expected_salary, current_city, phone, skills, self_intro, update_time)
      VALUES
      ('resume_seed_001', 'student_demo_001', '陈逸飞', 'male', '2002-06-15', '本科大三', '中南大学', '软件工程', '前端开发实习', '4000-6000', '长沙', '13800138000', '${escapeSql(JSON.stringify(['ArkTS', 'TypeScript', 'React', 'Vue', 'Git']))}', '热爱前端技术，在校期间独立完成过多个H5和小程序项目，有良好的代码规范意识，希望找到一份能快速成长的前端实习岗位。', ${now}),
      ('resume_seed_002', 'student_demo_002', '林雪莹', 'female', '2001-03-22', '硕士', '湖南大学', '计算机科学与技术', 'Java后端开发', '12000-18000', '长沙', '13800001234', '${escapeSql(JSON.stringify(['Java', 'Spring Boot', 'MySQL', 'Redis', 'Docker', '微服务']))}', '硕士期间研究方向为分布式系统，参与过省级科研项目。有字节跳动后端实习经历，能独立负责模块设计与开发。', ${now}),
      ('resume_seed_003', 'student_demo_003', '赵明远', 'male', '2001-09-10', '本科大四', '湖南大学', '软件工程', '全栈开发工程师', '10000-15000', '长沙', '13800001001', '${escapeSql(JSON.stringify(['React', 'Node.js', 'TypeScript', 'Python', 'MongoDB', 'GraphQL']))}', '全栈开发爱好者，大三期间创业做过SaaS产品，从前端到部署全流程熟悉。技术栈扎实，能快速上手新技术。', ${now}),
      ('resume_seed_004', 'student_demo_004', '王思涵', 'female', '2000-11-05', '硕士研二', '中南大学', '数据科学', '数据分析师', '12000-16000', '长沙', '13800001002', '${escapeSql(JSON.stringify(['Python', 'SQL', 'Tableau', 'SPSS', '机器学习', '数据可视化']))}', '数据驱动决策的信仰者。硕士论文方向为用户行为预测模型，曾在腾讯做数据分析实习，熟练使用Python进行数据清洗与建模。', ${now}),
      ('resume_seed_005', 'student_demo_005', '李俊杰', 'male', '2003-02-18', '本科大三', '湖南师范大学', '市场营销', '新媒体运营实习', '3000-5000', '长沙', '13800001003', '${escapeSql(JSON.stringify(['文案撰写', '短视频剪辑', 'PS', '公众号运营', '社群运营']))}', '校园自媒体负责人，运营的校园公众号粉丝2万+。擅长内容策划与传播，对短视频平台算法有一定理解。', ${now}),
      ('resume_seed_006', 'student_demo_006', '张雨晴', 'female', '2002-07-20', '本科大四', '中南大学', '视觉传达设计', 'UI/UX设计师', '8000-12000', '长沙', '13800001004', '${escapeSql(JSON.stringify(['Figma', 'PS', 'AI', 'Sketch', 'Principle', 'AE']))}', '设计不仅仅是好看，更是解决问题。作品集获得过学院奖，参与过多个APP界面设计项目，注重用户体验与交互细节。', ${now}),
      ('resume_seed_007', 'student_demo_007', '刘浩然', 'male', '2000-05-12', '硕士研二', '湖南大学', '金融学', '金融分析师', '15000-20000', '长沙', '13800001005', '${escapeSql(JSON.stringify(['Excel', 'Python', 'Bloomberg', 'Wind', '财务建模', '行研']))}', 'CFA二级备考中。在券商研究所做过行研实习，独立完成过3份行业深度报告。对TMT赛道有深入理解。', ${now}),
      ('resume_seed_008', 'student_demo_008', '陈思琪', 'female', '2003-04-28', '本科大三', '长沙理工大学', '会计学', '财务助理', '3000-4500', '长沙', '13800001006', '${escapeSql(JSON.stringify(['用友', 'Excel', '记账', '报税', '发票管理']))}', '做事细致认真，曾在校财务处勤工俭学一年。已通过初级会计职称考试，熟悉一般纳税人账务处理流程。', ${now}),
      ('resume_seed_009', 'student_demo_009', '周子涵', 'male', '2001-12-03', '硕士研一', '国防科技大学', '人工智能', 'AI算法实习', '5000-8000', '长沙', '13800001007', '${escapeSql(JSON.stringify(['PyTorch', 'TensorFlow', 'Python', 'NLP', 'CV', 'Linux']))}', '研究方向为自然语言处理，发表过一篇CCF-B类论文。希望将学术积累应用到工业场景中，对大规模语言模型特别感兴趣。', ${now}),
      ('resume_seed_010', 'student_demo_010', '吴雨桐', 'female', '2003-08-15', '本科大三', '中南林业科技大学', '英语', '翻译/英语助教', '2500-4000', '长沙', '13800001008', '${escapeSql(JSON.stringify(['英语专八', '笔译', 'CAT工具', 'Office', '字幕制作']))}', '英语专业排名前5%，已通过专八考试。在字幕组做过2年无偿翻译，累计翻译超过100小时视频内容。', ${now}),
      ('resume_seed_011', 'student_demo_011', '郑凯文', 'male', '2002-01-30', '本科大四', '湖南大学', '土木工程', '工程管理员', '7000-10000', '长沙', '13800001009', '${escapeSql(JSON.stringify(['AutoCAD', 'Revit', 'BIM', '工程测量', 'Project']))}', '参加过省级结构设计竞赛并获奖。暑假期在中建五局实习过，熟悉施工现场管理流程和CAD出图规范。', ${now}),
      ('resume_seed_012', 'student_demo_012', '杨思远', 'male', '2001-10-22', '本科大四', '湖南工商大学', '电子商务', '电商运营专员', '6000-9000', '长沙', '13800001010', '${escapeSql(JSON.stringify(['淘宝运营', '抖音', '数据分析', '选品', '供应链管理']))}', '在校期间自主创业做过淘宝店，月销最高达到10万+。对电商全链路有实操经验，擅长数据化运营和爆品打造。', ${now}),
      ('resume_seed_013', 'student_demo_013', '黄小雅', 'female', '2000-09-08', '硕士研二', '湘潭大学', '法学', '法务助理', '8000-11000', '长沙', '13800001011', '${escapeSql(JSON.stringify(['合同法', '法律检索', '文书写作', '知识产权', '合规审查']))}', '已通过法考。在律所实习期间协助处理过多起合同纠纷案件，擅长合同条款审查和法律风险识别。', ${now}),
      ('resume_seed_014', 'student_demo_014', '许晨阳', 'male', '2003-06-25', '本科大三', '湖南科技大学', '计算机科学与技术', 'Java后端实习', '4000-6000', '长沙', '13800001012', '${escapeSql(JSON.stringify(['Java', 'Spring Boot', 'MySQL', 'Redis', 'Linux', 'Git']))}', '从大二开始自学Java后端开发，在GitHub上有几个开源项目获得star。参加过蓝桥杯获得省级二等奖，编程基础扎实。', ${now})`
    )

    // 实习/项目经历种子数据
    await store.executeSql(
      `INSERT OR IGNORE INTO ${TABLE_EXPERIENCE}
      (exp_id, resume_id, type, company_name, role, description, start_time, end_time)
      VALUES
      ('exp_seed_001', 'resume_seed_001', 'project', '校园助手小程序', '前端负责人', '独立使用uni-app开发了包含课表查询、成绩管理、校园导航等功能的小程序，日活2000+。', '2024-03', '2024-08'),
      ('exp_seed_002', 'resume_seed_002', 'intern', '字节跳动', '后端开发实习生', '参与内部中台系统的微服务拆分与容器化改造，优化接口响应时间40%以上，获得mentor好评。', '2025-06', '2025-12'),
      ('exp_seed_003', 'resume_seed_003', 'intern', '腾讯云', '全栈开发实习生', '独立负责云控制台某个功能模块的前后端开发，使用React+Node.js技术栈，项目按时交付上线。', '2025-07', '2025-11'),
      ('exp_seed_004', 'resume_seed_004', 'intern', '腾讯', '数据分析实习生', '负责用户增长数据分析，基于SQL和Python搭建自动化报表体系，为运营决策提供数据支持。', '2025-03', '2025-09'),
      ('exp_seed_005', 'resume_seed_005', 'project', '校园新媒体矩阵', '内容负责人', '从0到1搭建校园公众号和小红书矩阵，策划过多篇10万+爆款内容，累计涨粉2万+。', '2024-09', '2025-06'),
      ('exp_seed_006', 'resume_seed_006', 'intern', '芒果TV', 'UI设计实习生', '参与芒果TV国际版APP的界面设计改版，独立完成10+个页面的视觉设计稿和交互原型。', '2025-04', '2025-09'),
      ('exp_seed_007', 'resume_seed_007', 'intern', '中信证券', '行业研究实习生', '协助分析师覆盖TMT赛道，独立撰写3篇行业深度报告，其中1篇被首席分析师推荐为周度最佳。', '2025-07', '2025-12'),
      ('exp_seed_009', 'resume_seed_009', 'project', '智能问答系统', '核心算法成员', '基于BERT模型实现了一个面向校园场景的智能问答系统，在学院比赛中获得一等奖。', '2025-01', '2025-06'),
      ('exp_seed_012', 'resume_seed_012', 'project', '校园电商创业', '创始人', '自主创业开设淘宝店铺，主营校园周边文创产品，月销售额最高突破10万元，利润率稳定在30%以上。', '2024-06', '2025-12'),
      ('exp_seed_013', 'resume_seed_013', 'intern', '金杜律师事务所', '律师助理实习生', '协助合伙人处理商业合同审核、法律检索及诉讼材料准备，参与过跨国并购项目的尽职调查。', '2025-05', '2025-10'),
      ('exp_seed_014', 'resume_seed_014', 'project', '开源RPC框架', '项目发起人', '参考Dubbo实现了一个轻量级RPC框架，支持SPI扩展、负载均衡和简单的服务治理，GitHub获得200+ star。', '2024-10', '2025-05')`
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

    // 全新招聘者（已认证，可发布岗位）
    await store.executeSql(
      `INSERT OR IGNORE INTO ${TABLE_USER}
      (user_id, phone, role, is_guest, password, auth_status, create_time, update_time, is_login)
      VALUES
      ('recruiter_fresh_001', '13800000005', 'recruiter', 0, '123456', 2, ${now}, ${now}, 0)`
    )

    // 强制同步演示账号密码和认证状态（每次启动都执行，确保登录可用且可发布岗位）
    const demoIds = ['student_demo_001', 'student_demo_002', 'student_demo_003', 'student_demo_004', 'student_demo_005', 'student_demo_006', 'student_demo_007', 'student_demo_008', 'student_demo_009', 'student_demo_010', 'student_demo_011', 'student_demo_012', 'student_demo_013', 'student_demo_014', 'recruiter_demo_001', 'recruiter_demo_002', 'recruiter_demo_003', 'recruiter_demo_004', 'recruiter_fresh_001']
    const recruiterIds = ['recruiter_demo_001', 'recruiter_demo_002', 'recruiter_demo_003', 'recruiter_demo_004', 'recruiter_fresh_001']
    for (let i = 0; i < demoIds.length; i++) {
      const id = demoIds[i]
      const isRecruiter = recruiterIds.indexOf(id) >= 0
      if (isRecruiter) {
        await store.executeSql(
          `UPDATE ${TABLE_USER} SET password = '123456', auth_status = 2, update_time = ${now} WHERE user_id = '${id}'`
        )
      } else {
        await store.executeSql(
          `UPDATE ${TABLE_USER} SET password = '123456', update_time = ${now} WHERE user_id = '${id}'`
        )
      }
    }
  }

  private static async resetSeedJobs(store: relationalStore.RdbStore): Promise<void> {
    await store.executeSql(`DELETE FROM ${TABLE_JOB} WHERE job_id IN (
      'job_seed_001', 'job_seed_002', 'job_seed_003', 'job_seed_004',
      'job_seed_005', 'job_seed_006', 'job_seed_007', 'job_seed_008',
      'job_seed_009', 'job_seed_010', 'job_seed_011', 'job_seed_012',
      'job_seed_013', 'job_seed_014', 'job_seed_015', 'job_seed_016',
      'job_seed_021', 'job_seed_022', 'job_seed_023', 'job_seed_024',
      'job_seed_031', 'job_seed_032', 'job_seed_033', 'job_seed_034', 'job_seed_035'
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
      },
      // --- 更多全职岗位 ---
      {
        jobId: 'job_seed_021',
        recruiterId: 'recruiter_demo_001',
        companyName: 'Xiaomi Group',
        title: 'Data Analyst',
        category: 'fulltime',
        description: 'Support product and operations teams with data-driven insights, build dashboards and automate reports.',
        educationRequired: 'Bachelor',
        salaryRange: '12000-18000',
        workYearsRequired: 'No limit',
        workAddress: 'Beijing',
        city: 'Beijing',
        skills: ['Python', 'SQL', 'Tableau', '数据分析'],
        tags: ['big-tech', 'data'],
        taskStartTime: -1, taskEndTime: -1, requiredDayOfWeek: -1, requiredStartHour: -1, requiredEndHour: -1
      },
      {
        jobId: 'job_seed_022',
        recruiterId: 'recruiter_demo_002',
        companyName: 'ByteDance',
        title: 'UI/UX Designer',
        category: 'fulltime',
        description: 'Design user interfaces for internal platforms, create prototypes, and conduct user research.',
        educationRequired: 'Bachelor',
        salaryRange: '10000-15000',
        workYearsRequired: 'No limit',
        workAddress: 'Beijing',
        city: 'Beijing',
        skills: ['Figma', 'UI设计', '交互设计', '用户研究'],
        tags: ['big-tech', 'design'],
        taskStartTime: -1, taskEndTime: -1, requiredDayOfWeek: -1, requiredStartHour: -1, requiredEndHour: -1
      },
      {
        jobId: 'job_seed_023',
        recruiterId: 'recruiter_demo_003',
        companyName: 'Huawei Technologies',
        title: 'Financial Analyst',
        category: 'fulltime',
        description: 'Conduct financial modeling, industry analysis reports, and support strategic planning for business units.',
        educationRequired: 'Master',
        salaryRange: '15000-22000',
        workYearsRequired: 'No limit',
        workAddress: 'Shenzhen',
        city: 'Shenzhen',
        skills: ['财务建模', 'Excel', 'Python', '行业研究'],
        tags: ['big-tech', 'finance'],
        taskStartTime: -1, taskEndTime: -1, requiredDayOfWeek: -1, requiredStartHour: -1, requiredEndHour: -1
      },
      {
        jobId: 'job_seed_024',
        recruiterId: 'recruiter_demo_004',
        companyName: 'BlueLake Media',
        title: 'Marketing Specialist',
        category: 'fulltime',
        description: 'Plan and execute cross-platform marketing campaigns, manage social media accounts, and track performance metrics.',
        educationRequired: 'Bachelor',
        salaryRange: '8000-12000',
        workYearsRequired: 'No limit',
        workAddress: 'Changsha',
        city: 'Changsha',
        skills: ['市场营销', '文案策划', '数据分析', '社媒运营'],
        tags: ['media', 'marketing'],
        taskStartTime: -1, taskEndTime: -1, requiredDayOfWeek: -1, requiredStartHour: -1, requiredEndHour: -1
      },
      // --- 更多微任务 ---
      {
        jobId: 'job_seed_031',
        recruiterId: 'recruiter_demo_001',
        companyName: 'Xiaomi Group',
        title: 'AI数据标注员',
        category: 'micro_task',
        description: '对图片和文本数据进行分类标注，用于AI模型训练，要求细心耐心。',
        educationRequired: 'College or above',
        salaryRange: '60-100/task',
        workYearsRequired: 'No limit',
        workAddress: 'Remote',
        city: 'Changsha',
        skills: ['细心', 'Office', '标注工具'],
        tags: ['remote', 'AI数据'],
        taskStartTime: buildNextWeekdayTime(now, 3, 14, 0),
        taskEndTime: buildNextWeekdayTime(now, 3, 18, 0),
        requiredDayOfWeek: 3, requiredStartHour: 14, requiredEndHour: 18
      },
      {
        jobId: 'job_seed_032',
        recruiterId: 'recruiter_demo_002',
        companyName: 'ByteDance',
        title: '校园推广大使',
        category: 'micro_task',
        description: '在校园内推广公司招聘信息，组织线下宣讲活动，运营校园社群。',
        educationRequired: 'College or above',
        salaryRange: '200-400/次',
        workYearsRequired: 'No limit',
        workAddress: '长沙各高校',
        city: 'Changsha',
        skills: ['沟通', '社群运营', '活动组织'],
        tags: ['onsite', '推广'],
        taskStartTime: buildNextWeekdayTime(now, 4, 16, 0),
        taskEndTime: buildNextWeekdayTime(now, 4, 20, 0),
        requiredDayOfWeek: 4, requiredStartHour: 16, requiredEndHour: 20
      },
      {
        jobId: 'job_seed_033',
        recruiterId: 'recruiter_demo_003',
        companyName: 'Huawei Technologies',
        title: '技术文档翻译助手',
        category: 'micro_task',
        description: '协助翻译技术文档（中英互译），包括API文档和用户手册，需要扎实的英语功底。',
        educationRequired: 'Bachelor',
        salaryRange: '120-180/task',
        workYearsRequired: 'No limit',
        workAddress: 'Remote',
        city: 'Changsha',
        skills: ['英语翻译', '技术文档', 'Office'],
        tags: ['remote', '翻译'],
        taskStartTime: buildNextWeekdayTime(now, 2, 9, 0),
        taskEndTime: buildNextWeekdayTime(now, 2, 12, 0),
        requiredDayOfWeek: 2, requiredStartHour: 9, requiredEndHour: 12
      },
      {
        jobId: 'job_seed_034',
        recruiterId: 'recruiter_demo_004',
        companyName: 'BlueLake Media',
        title: '短视频素材采集',
        category: 'micro_task',
        description: '拍摄校园生活素材，用于公司短视频账号内容制作，要求有一定的拍摄审美。',
        educationRequired: 'College or above',
        salaryRange: '100-150/条',
        workYearsRequired: 'No limit',
        workAddress: '长沙各高校',
        city: 'Changsha',
        skills: ['拍摄', '剪辑', '审美'],
        tags: ['onsite', '视频'],
        taskStartTime: buildNextWeekdayTime(now, 5, 13, 0),
        taskEndTime: buildNextWeekdayTime(now, 5, 17, 0),
        requiredDayOfWeek: 5, requiredStartHour: 13, requiredEndHour: 17
      },
      {
        jobId: 'job_seed_035',
        recruiterId: 'recruiter_demo_002',
        companyName: 'ByteDance',
        title: '竞品信息收集员',
        category: 'micro_task',
        description: '收集和整理竞品APP的功能更新、用户评价和市场动态，每周提交分析小结。',
        educationRequired: 'Bachelor',
        salaryRange: '150-200/周',
        workYearsRequired: 'No limit',
        workAddress: 'Remote',
        city: 'Changsha',
        skills: ['信息检索', 'Excel', '分析归纳'],
        tags: ['remote', '竞品分析'],
        taskStartTime: buildNextWeekdayTime(now, 1, 10, 0),
        taskEndTime: buildNextWeekdayTime(now, 1, 16, 0),
        requiredDayOfWeek: 1, requiredStartHour: 10, requiredEndHour: 16
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
