// 用户数据访问对象

import { relationalStore } from '@kit.ArkData'
import { DatabaseHelper } from '../database/DatabaseHelper'
import { TABLE_USER, TABLE_RESUME, TABLE_EDUCATION, TABLE_EXPERIENCE, TABLE_SCHEDULE } from '../database/Tables'
import { UserProfile, UserRole, StudentType, Gender, VipLevel, AuthStatus } from '../model/UserModel'

export class UserDao {
  private helper: DatabaseHelper = DatabaseHelper.getInstance()

  private normalizePhone(phone: string): string {
    return phone.trim()
  }

  private normalizeEmail(email: string): string {
    return email.trim().toLowerCase()
  }

  private normalizePassword(password: string): string {
    return password.trim()
  }

  private async queryUsersByPhone(phone: string): Promise<UserProfile[]> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.equalTo('phone', this.normalizePhone(phone))
    predicates.orderByDesc('update_time')
    const resultSet = await store.query(predicates)
    const users: UserProfile[] = []
    while (resultSet.goToNextRow()) {
      users.push(this.rowToUserProfile(resultSet))
    }
    resultSet.close()
    return users
  }

  private async queryUsersByEmail(email: string): Promise<UserProfile[]> {
    const normalizedEmail = this.normalizeEmail(email)
    if (!normalizedEmail) {
      return []
    }
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.equalTo('email', normalizedEmail)
    predicates.orderByDesc('update_time')
    const resultSet = await store.query(predicates)
    const users: UserProfile[] = []
    while (resultSet.goToNextRow()) {
      users.push(this.rowToUserProfile(resultSet))
    }
    resultSet.close()
    return users
  }

  async insertUser(user: UserProfile): Promise<void> {
    const store = await this.helper.getStore()
    const valueBucket: relationalStore.ValuesBucket = {
      user_id: user.userId,
      phone: user.phone,
      email: user.email ?? '',
      role: user.role,
      student_type: user.studentType ?? '',
      real_name: user.realName ?? '',
      gender: user.gender ?? '',
      birthday: user.birthday ?? '',
      education: user.education ?? '',
      school: user.school ?? '',
      major: user.major ?? '',
      expected_position: user.expectedPosition ?? '',
      expected_salary: user.expectedSalary ?? '',
      current_city: user.currentCity ?? '',
      is_guest: user.isGuest ? 1 : 0,
      avatar: user.avatar ?? '',
      company_name: user.companyName ?? '',
      company_address: user.companyAddress ?? '',
      company_industry: user.companyIndustry ?? '',
      company_scale: user.companyScale ?? '',
      legal_person: user.legalPerson ?? '',
      contact_position: user.contactPosition ?? '',
      company_email: user.companyEmail ?? '',
      id_card: user.idCard ?? '',
      business_license: user.businessLicense ?? '',
      vip_level: user.vipLevel ?? VipLevel.NORMAL,
      vip_expire_time: user.vipExpireTime ?? 0,
      vip_lifetime: user.vipLifetime ? 1 : 0,
      position_count: user.positionCount ?? 0,
      hr_real_name: user.hrRealName ?? '',
      password: user.password ?? '',
      auth_status: user.authStatus ?? 0,
      id_card_front_image: user.idCardFrontImage ?? '',
      id_card_back_image: user.idCardBackImage ?? '',
      face_image: user.faceImage ?? '',
      auth_submit_time: user.authSubmitTime ?? 0,
      auth_approve_time: user.authApproveTime ?? 0,
      auth_reject_reason: user.authRejectReason ?? '',
      create_time: Date.now(),
      update_time: Date.now(),
      is_login: 0
    }
    await store.insert(TABLE_USER, valueBucket)
  }

  async updateUser(user: UserProfile): Promise<void> {
    const store = await this.helper.getStore()
    const existing = await this.getUserById(user.userId)
    const valueBucket: relationalStore.ValuesBucket = {
      phone: user.phone,
      email: user.email ?? existing?.email ?? '',
      role: user.role,
      student_type: user.studentType ?? existing?.studentType ?? '',
      real_name: user.realName ?? '',
      gender: user.gender ?? '',
      birthday: user.birthday ?? '',
      education: user.education ?? '',
      school: user.school ?? '',
      major: user.major ?? '',
      expected_position: user.expectedPosition ?? '',
      expected_salary: user.expectedSalary ?? '',
      current_city: user.currentCity ?? '',
      is_guest: user.isGuest ? 1 : 0,
      avatar: user.avatar ?? '',
      company_name: user.companyName ?? '',
      company_address: user.companyAddress ?? '',
      company_industry: user.companyIndustry ?? '',
      company_scale: user.companyScale ?? '',
      legal_person: user.legalPerson ?? '',
      contact_position: user.contactPosition ?? '',
      company_email: user.companyEmail ?? '',
      id_card: user.idCard ?? '',
      business_license: user.businessLicense ?? '',
      vip_level: user.vipLevel ?? VipLevel.NORMAL,
      vip_expire_time: user.vipExpireTime ?? 0,
      vip_lifetime: user.vipLifetime ? 1 : 0,
      position_count: user.positionCount ?? 0,
      hr_real_name: user.hrRealName ?? '',
      password: user.password && user.password.length > 0 ? user.password : (existing?.password ?? ''),
      auth_status: user.authStatus ?? existing?.authStatus ?? 0,
      id_card_front_image: user.idCardFrontImage ?? existing?.idCardFrontImage ?? '',
      id_card_back_image: user.idCardBackImage ?? existing?.idCardBackImage ?? '',
      face_image: user.faceImage ?? existing?.faceImage ?? '',
      auth_submit_time: user.authSubmitTime ?? existing?.authSubmitTime ?? 0,
      auth_approve_time: user.authApproveTime ?? existing?.authApproveTime ?? 0,
      auth_reject_reason: user.authRejectReason ?? existing?.authRejectReason ?? '',
      update_time: Date.now()
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.equalTo('user_id', user.userId)
    await store.update(valueBucket, predicates)
  }

  async ensureDemoAccounts(): Promise<void> {
    const store = await this.helper.getStore()
    const now = Date.now()

    // ---------- 招聘者账号 ----------
    const recruiterSqls: string[] = [
      `INSERT OR IGNORE INTO ${TABLE_USER} (user_id, phone, role, company_name, vip_level, position_count, hr_real_name, is_guest, password, create_time, update_time, is_login) VALUES ('recruiter_demo_001', '13900139000', 'recruiter', '小米集团', 'normal', 0, '董雨欣', 0, '123456', ${now}, ${now}, 0)`,
      `INSERT OR IGNORE INTO ${TABLE_USER} (user_id, phone, role, company_name, vip_level, position_count, hr_real_name, is_guest, password, create_time, update_time, is_login) VALUES ('recruiter_demo_002', '13800000001', 'recruiter', '字节跳动', 'normal', 0, '张HR', 0, '123456', ${now}, ${now}, 0)`,
      `INSERT OR IGNORE INTO ${TABLE_USER} (user_id, phone, role, company_name, vip_level, position_count, hr_real_name, is_guest, password, create_time, update_time, is_login) VALUES ('recruiter_demo_003', '13800000002', 'recruiter', '华为技术', 'vip', 0, '李HR', 0, '123456', ${now}, ${now}, 0)`,
      `INSERT OR IGNORE INTO ${TABLE_USER} (user_id, phone, role, company_name, vip_level, position_count, hr_real_name, is_guest, password, create_time, update_time, is_login) VALUES ('recruiter_demo_004', '13800000003', 'recruiter', '蓝湖传媒', 'normal', 0, '王HR', 0, '123456', ${now}, ${now}, 0)`
    ]

    // ---------- 求职者账号（5个真实学生，含完整简历信息）----------
    const studentSqls: string[] = [
      `INSERT OR IGNORE INTO ${TABLE_USER} (user_id, phone, role, student_type, real_name, gender, school, major, education, expected_position, expected_salary, current_city, is_guest, password, create_time, update_time, is_login) VALUES ('student_demo_001', '13800138000', 'job_seeker', 'current', '陈逸飞', 'male', '中南大学', '软件工程', '本科大三', '前端开发实习', '4000-6000', '长沙', 0, '123456', ${now}, ${now}, 0)`,
      `INSERT OR IGNORE INTO ${TABLE_USER} (user_id, phone, role, student_type, real_name, gender, school, major, education, expected_position, expected_salary, current_city, is_guest, password, create_time, update_time, is_login) VALUES ('student_demo_002', '13800001234', 'job_seeker', 'graduating', '林雪莹', 'female', '湖南大学', '计算机科学与技术', '硕士', 'Java后端开发', '12000-18000', '长沙', 0, '123456', ${now}, ${now}, 0)`,
      `INSERT OR IGNORE INTO ${TABLE_USER} (user_id, phone, role, student_type, real_name, gender, school, major, education, expected_position, expected_salary, current_city, is_guest, password, create_time, update_time, is_login) VALUES ('student_demo_003', '13800001235', 'job_seeker', 'graduating', '张浩然', 'male', '国防科技大学', '人工智能', '硕士', '算法工程师', '18000-25000', '长沙', 0, '123456', ${now}, ${now}, 0)`,
      `INSERT OR IGNORE INTO ${TABLE_USER} (user_id, phone, role, student_type, real_name, gender, school, major, education, expected_position, expected_salary, current_city, is_guest, password, create_time, update_time, is_login) VALUES ('student_demo_004', '13800001236', 'job_seeker', 'current', '王雨桐', 'female', '中南大学', '数据科学与大数据技术', '本科大三', '数据分析（兼职）', '3000-5000', '长沙', 0, '123456', ${now}, ${now}, 0)`,
      `INSERT OR IGNORE INTO ${TABLE_USER} (user_id, phone, role, student_type, real_name, gender, school, major, education, expected_position, expected_salary, current_city, is_guest, password, create_time, update_time, is_login) VALUES ('student_demo_005', '13800001237', 'job_seeker', 'graduating', '赵思远', 'male', '湖南大学', '电子信息工程', '本科', '嵌入式开发工程师', '10000-15000', '深圳', 0, '123456', ${now}, ${now}, 0)`
    ]

    const allUserSqls = recruiterSqls.concat(studentSqls)
    for (let i = 0; i < allUserSqls.length; i++) {
      await store.executeSql(allUserSqls[i])
    }

    // ---------- 简历种子数据 ----------
    await this.seedResumeData(store, now)
  }

  private async seedResumeData(store: relationalStore.RdbStore, now: number): Promise<void> {
    // 简历记录
    const resumeSqls: string[] = [
      `INSERT OR IGNORE INTO ${TABLE_RESUME} (resume_id, user_id, real_name, gender, birthday, education, school, major, graduation_year, expected_position, expected_salary, current_city, phone, email, skills, self_intro, has_schedule, update_time) VALUES ('resume_001', 'student_demo_001', '陈逸飞', 'male', '2003-06', '本科大三', '中南大学', '软件工程', '2027', '前端开发实习', '4000-6000', '长沙', '13800138000', 'chenyifei@csu.edu.cn', '${JSON.stringify(['React', 'Vue', 'TypeScript', 'JavaScript', 'HTML/CSS', 'Node.js', '微信小程序'])}', '热爱前端开发，大二开始自学 React 和 Vue，独立完成过多个项目。擅长组件化开发和性能优化，对用户体验有较高追求。希望找一份前端实习，积累真实项目经验。', 1, ${now})`,
      `INSERT OR IGNORE INTO ${TABLE_RESUME} (resume_id, user_id, real_name, gender, birthday, education, school, major, graduation_year, expected_position, expected_salary, current_city, phone, email, skills, self_intro, has_schedule, update_time) VALUES ('resume_002', 'student_demo_002', '林雪莹', 'female', '2001-11', '硕士', '湖南大学', '计算机科学与技术', '2027', 'Java后端开发', '12000-18000', '长沙', '13800001234', 'linxueying@hnu.edu.cn', '${JSON.stringify(['Java', 'Spring Boot', 'MySQL', 'Redis', '微服务', 'Docker', 'Linux', 'MyBatis'])}', '硕士研究方向为分布式系统，参与过导师的国家级项目。熟练掌握 Java 生态，有较强的系统设计和问题排查能力。期望进入一线互联网公司后端团队。', 1, ${now})`,
      `INSERT OR IGNORE INTO ${TABLE_RESUME} (resume_id, user_id, real_name, gender, birthday, education, school, major, graduation_year, expected_position, expected_salary, current_city, phone, email, skills, self_intro, has_schedule, update_time) VALUES ('resume_003', 'student_demo_003', '张浩然', 'male', '2001-03', '硕士', '国防科技大学', '人工智能', '2027', '算法工程师', '18000-25000', '长沙', '13800001235', 'zhanghaoran@nudt.edu.cn', '${JSON.stringify(['Python', 'PyTorch', 'TensorFlow', 'NLP', '计算机视觉', 'C++', 'CUDA', '数据挖掘'])}', '硕士期间主攻自然语言处理方向，在 ACL 上发表过一篇论文。有顶会论文和竞赛获奖经历，coding 能力强。期望加入 AI 核心团队，解决有挑战的技术问题。', 1, ${now})`,
      `INSERT OR IGNORE INTO ${TABLE_RESUME} (resume_id, user_id, real_name, gender, birthday, education, school, major, graduation_year, expected_position, expected_salary, current_city, phone, email, skills, self_intro, has_schedule, update_time) VALUES ('resume_004', 'student_demo_004', '王雨桐', 'female', '2003-09', '本科大三', '中南大学', '数据科学与大数据技术', '2027', '数据分析（兼职）', '3000-5000', '长沙', '13800001236', 'wangyutong@csu.edu.cn', '${JSON.stringify(['Python', 'SQL', 'Excel', 'Tableau', 'Pandas', '数据可视化', 'SPSS', 'R语言'])}', '对数据敏感，喜欢从数据中发现规律。参加过数学建模竞赛并获得省级奖项。希望找一份偏数据分析的兼职或实习，课余时间充裕。', 1, ${now})`,
      `INSERT OR IGNORE INTO ${TABLE_RESUME} (resume_id, user_id, real_name, gender, birthday, education, school, major, graduation_year, expected_position, expected_salary, current_city, phone, email, skills, self_intro, has_schedule, update_time) VALUES ('resume_005', 'student_demo_005', '赵思远', 'male', '2002-07', '本科', '湖南大学', '电子信息工程', '2026', '嵌入式开发工程师', '10000-15000', '深圳', '13800001237', 'zhaosiyuan@hnu.edu.cn', '${JSON.stringify(['C/C++', 'ARM', 'Linux驱动', 'STM32', 'RTOS', 'PCB设计', 'I2C/SPI', '单片机'])}', '喜欢硬件和底层开发，大学期间参加过智能车竞赛和电子设计大赛，均有获奖。动手能力强，能独立完成从电路设计到嵌入式软件的全流程开发。', 1, ${now})`
    ]

    // 教育经历
    const educationSqls: string[] = [
      `INSERT OR IGNORE INTO ${TABLE_EDUCATION} (edu_id, resume_id, school_name, major, degree, start_year, end_year) VALUES ('edu_001_1', 'resume_001', '中南大学', '软件工程', '本科', '2023-09', '2027-06')`,
      `INSERT OR IGNORE INTO ${TABLE_EDUCATION} (edu_id, resume_id, school_name, major, degree, start_year, end_year) VALUES ('edu_002_1', 'resume_002', '湖南大学', '计算机科学与技术', '硕士', '2025-09', '2027-06')`,
      `INSERT OR IGNORE INTO ${TABLE_EDUCATION} (edu_id, resume_id, school_name, major, degree, start_year, end_year) VALUES ('edu_002_2', 'resume_002', '湖南大学', '软件工程', '本科', '2021-09', '2025-06')`,
      `INSERT OR IGNORE INTO ${TABLE_EDUCATION} (edu_id, resume_id, school_name, major, degree, start_year, end_year) VALUES ('edu_003_1', 'resume_003', '国防科技大学', '人工智能', '硕士', '2025-09', '2027-06')`,
      `INSERT OR IGNORE INTO ${TABLE_EDUCATION} (edu_id, resume_id, school_name, major, degree, start_year, end_year) VALUES ('edu_003_2', 'resume_003', '国防科技大学', '计算机科学与技术', '本科', '2021-09', '2025-06')`,
      `INSERT OR IGNORE INTO ${TABLE_EDUCATION} (edu_id, resume_id, school_name, major, degree, start_year, end_year) VALUES ('edu_004_1', 'resume_004', '中南大学', '数据科学与大数据技术', '本科', '2023-09', '2027-06')`,
      `INSERT OR IGNORE INTO ${TABLE_EDUCATION} (edu_id, resume_id, school_name, major, degree, start_year, end_year) VALUES ('edu_005_1', 'resume_005', '湖南大学', '电子信息工程', '本科', '2022-09', '2026-06')`
    ]

    // 实习/项目经历
    const experienceSqls: string[] = [
      `INSERT OR IGNORE INTO ${TABLE_EXPERIENCE} (exp_id, resume_id, type, company_name, project_name, role, description, translated_description, start_time, end_time) VALUES ('exp_001_1', 'resume_001', 'intern', '万兴科技', '', '前端开发实习生', '参与公司内部管理系统前端开发，使用 React + TypeScript 技术栈，负责表格组件和表单组件的封装与优化。', '在万兴科技完成前端开发实习，独立交付4个通用组件，优化页面加载性能30%。', '2025-07', '2025-09')`,
      `INSERT OR IGNORE INTO ${TABLE_EXPERIENCE} (exp_id, resume_id, type, company_name, project_name, role, description, translated_description, start_time, end_time) VALUES ('exp_001_2', 'resume_001', 'project', '', '校园二手交易小程序', '全栈开发', '独立开发了一款面向本校学生的二手物品交易微信小程序，前端使用 uni-app，后端使用 Node.js + Express，数据库使用 MySQL。上线后累计用户2000+。', '从零到一完成校园二手交易平台全栈开发，上线后获得2000+用户，展现了产品思维和工程落地能力。', '2024-10', '2025-01')`,
      `INSERT OR IGNORE INTO ${TABLE_EXPERIENCE} (exp_id, resume_id, type, company_name, project_name, role, description, translated_description, start_time, end_time) VALUES ('exp_002_1', 'resume_002', 'intern', '华为技术', '', 'Java后端实习生', '参与华为云内部运维平台的微服务模块开发，使用 Spring Boot + Redis + Kafka，负责日志采集和分析接口的设计与实现。', '在华为完成Java后端实习，参与微服务开发，处理日均百万级日志数据。', '2026-01', '2026-06')`,
      `INSERT OR IGNORE INTO ${TABLE_EXPERIENCE} (exp_id, resume_id, type, company_name, project_name, role, description, translated_description, start_time, end_time) VALUES ('exp_002_2', 'resume_002', 'project', '', '分布式任务调度系统', '核心开发', '研究生课题项目，设计并实现了一个支持动态扩缩容的分布式任务调度系统，支持定时任务、依赖任务和流式任务三种模式。', '主导分布式调度系统设计与实现，支持3种任务模式，已申请软件著作权。', '2025-09', '2026-03')`,
      `INSERT OR IGNORE INTO ${TABLE_EXPERIENCE} (exp_id, resume_id, type, company_name, project_name, role, description, translated_description, start_time, end_time) VALUES ('exp_003_1', 'resume_003', 'intern', '字节跳动', '', '推荐算法实习生', '参与抖音推荐系统 NLP 特征工程优化，使用 PyTorch 训练文本理解模型，提升内容标签准确率2.3个百分点。', '在字节跳动AI团队实习，优化推荐系统NLP特征，内容标签准确率提升2.3pp。', '2026-02', '2026-05')`,
      `INSERT OR IGNORE INTO ${TABLE_EXPERIENCE} (exp_id, resume_id, type, company_name, project_name, role, description, translated_description, start_time, end_time) VALUES ('exp_003_2', 'resume_003', 'project', '', '基于大模型的智能问答系统', '项目负责人', '基于 LLaMA 开源模型进行领域微调，构建面向校园场景的智能问答助手，支持课表查询、成绩查询、校园导航等功能。ACL 2026 短文接收。', '主导LLM校园问答项目，完成模型微调全流程，论文被ACL 2026接收。', '2025-06', '2026-01')`,
      `INSERT OR IGNORE INTO ${TABLE_EXPERIENCE} (exp_id, resume_id, type, company_name, project_name, role, description, translated_description, start_time, end_time) VALUES ('exp_004_1', 'resume_004', 'project', '', '全国大学生数学建模竞赛', '队长兼建模手', '负责问题建模与数据分析，使用 Python 进行数据处理和可视化，最终获得省级一等奖。', '数学建模竞赛省一等奖队长，展现了突出的数据分析与建模能力。', '2025-09', '2025-09')`,
      `INSERT OR IGNORE INTO ${TABLE_EXPERIENCE} (exp_id, resume_id, type, company_name, project_name, role, description, translated_description, start_time, end_time) VALUES ('exp_004_2', 'resume_004', 'project', '', '长沙房价分析与预测', '数据分析', '使用 Pandas 和 Scikit-learn 对长沙市近5年房价数据进行分析与预测建模，制作 Tableau 可视化看板。', '独立完成房价预测数据分析项目，产出交互式可视化报告。', '2025-03', '2025-06')`,
      `INSERT OR IGNORE INTO ${TABLE_EXPERIENCE} (exp_id, resume_id, type, company_name, project_name, role, description, translated_description, start_time, end_time) VALUES ('exp_005_1', 'resume_005', 'intern', '大疆创新', '', '嵌入式软件实习生', '参与无人机飞控系统底层驱动开发，使用 C 语言编写 SPI/I2C 传感器驱动，并完成了单元测试和硬件调试。', '在大疆完成嵌入式开发实习，独立完成多个传感器驱动开发与调试。', '2025-07', '2025-12')`,
      `INSERT OR IGNORE INTO ${TABLE_EXPERIENCE} (exp_id, resume_id, type, company_name, project_name, role, description, translated_description, start_time, end_time) VALUES ('exp_005_2', 'resume_005', 'project', '', '智能车竞赛-电磁循迹组', '硬件+嵌入式负责人', '负责电磁循迹智能车的电路设计、传感器选型、STM32 控制程序编写，最终获得赛区二等奖。', '智能车竞赛赛区二等奖，独立完成硬件选型与嵌入式软件全流程。', '2024-09', '2025-05')`
    ]

    // 课表空闲时段
    const scheduleSqls: string[] = [
      `INSERT OR IGNORE INTO ${TABLE_SCHEDULE} (schedule_id, user_id, schedule_data, free_slots, update_time) VALUES ('schedule_001', 'student_demo_001', '[]', '${JSON.stringify([
        { dayOfWeek: 1, startPeriod: 5, endPeriod: 8, label: '周一 14:00-18:00' },
        { dayOfWeek: 3, startPeriod: 1, endPeriod: 4, label: '周三 08:00-12:00' },
        { dayOfWeek: 5, startPeriod: 5, endPeriod: 8, label: '周五 14:00-18:00' }
      ])}', ${now})`,
      `INSERT OR IGNORE INTO ${TABLE_SCHEDULE} (schedule_id, user_id, schedule_data, free_slots, update_time) VALUES ('schedule_002', 'student_demo_002', '[]', '${JSON.stringify([
        { dayOfWeek: 2, startPeriod: 1, endPeriod: 8, label: '周二 08:00-18:00' },
        { dayOfWeek: 4, startPeriod: 1, endPeriod: 8, label: '周四 08:00-18:00' },
        { dayOfWeek: 6, startPeriod: 3, endPeriod: 6, label: '周六 10:00-15:00' }
      ])}', ${now})`,
      `INSERT OR IGNORE INTO ${TABLE_SCHEDULE} (schedule_id, user_id, schedule_data, free_slots, update_time) VALUES ('schedule_003', 'student_demo_003', '[]', '${JSON.stringify([
        { dayOfWeek: 1, startPeriod: 3, endPeriod: 8, label: '周一 10:00-18:00' },
        { dayOfWeek: 3, startPeriod: 3, endPeriod: 6, label: '周三 10:00-15:00' },
        { dayOfWeek: 5, startPeriod: 1, endPeriod: 4, label: '周五 08:00-12:00' }
      ])}', ${now})`,
      `INSERT OR IGNORE INTO ${TABLE_SCHEDULE} (schedule_id, user_id, schedule_data, free_slots, update_time) VALUES ('schedule_004', 'student_demo_004', '[]', '${JSON.stringify([
        { dayOfWeek: 2, startPeriod: 5, endPeriod: 8, label: '周二 14:00-18:00' },
        { dayOfWeek: 4, startPeriod: 5, endPeriod: 8, label: '周四 14:00-18:00' },
        { dayOfWeek: 6, startPeriod: 1, endPeriod: 8, label: '周六 08:00-18:00' },
        { dayOfWeek: 7, startPeriod: 1, endPeriod: 8, label: '周日 08:00-18:00' }
      ])}', ${now})`,
      `INSERT OR IGNORE INTO ${TABLE_SCHEDULE} (schedule_id, user_id, schedule_data, free_slots, update_time) VALUES ('schedule_005', 'student_demo_005', '[]', '${JSON.stringify([
        { dayOfWeek: 1, startPeriod: 5, endPeriod: 8, label: '周一 14:00-18:00' },
        { dayOfWeek: 3, startPeriod: 5, endPeriod: 8, label: '周三 14:00-18:00' },
        { dayOfWeek: 5, startPeriod: 1, endPeriod: 8, label: '周五 08:00-18:00' }
      ])}', ${now})`
    ]

    const allSqls = resumeSqls.concat(educationSqls, experienceSqls, scheduleSqls)
    for (let i = 0; i < allSqls.length; i++) {
      await store.executeSql(allSqls[i])
    }
  }

  async getStudents(): Promise<UserProfile[]> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.equalTo('role', 'job_seeker')
    predicates.orderByDesc('update_time')
    const resultSet = await store.query(predicates)
    const users: UserProfile[] = []
    while (resultSet.goToNextRow()) {
      users.push(this.rowToUserProfile(resultSet))
    }
    resultSet.close()
    return users
  }

  async getAllUsers(): Promise<UserProfile[]> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.orderByDesc('update_time')
    const resultSet = await store.query(predicates)
    const users: UserProfile[] = []
    while (resultSet.goToNextRow()) {
      users.push(this.rowToUserProfile(resultSet))
    }
    resultSet.close()
    return users
  }

  async getUserById(userId: string): Promise<UserProfile | null> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.equalTo('user_id', userId)
    const resultSet = await store.query(predicates)
    if (resultSet.goToFirstRow()) {
      return this.rowToUserProfile(resultSet)
    }
    return null
  }

  async getLoggedInUser(): Promise<UserProfile | null> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.equalTo('is_login', 1)
    predicates.orderByDesc('update_time')
    const resultSet = await store.query(predicates)
    if (resultSet.goToFirstRow()) {
      const user = this.rowToUserProfile(resultSet)
      resultSet.close()
      return user
    }
    resultSet.close()
    return null
  }

  async logoutAll(): Promise<void> {
    const store = await this.helper.getStore()
    const valueBucket: relationalStore.ValuesBucket = { is_login: 0 }
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    await store.update(valueBucket, predicates)
  }

  async markUserLoggedIn(userId: string): Promise<void> {
    const store = await this.helper.getStore()
    const clearBucket: relationalStore.ValuesBucket = { is_login: 0 }
    const clearPredicates = new relationalStore.RdbPredicates(TABLE_USER)
    await store.update(clearBucket, clearPredicates)

    const valueBucket: relationalStore.ValuesBucket = {
      is_login: 1,
      update_time: Date.now()
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.equalTo('user_id', userId)
    await store.update(valueBucket, predicates)
  }

  async deleteUser(userId: string): Promise<void> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.equalTo('user_id', userId)
    await store.delete(predicates)
  }

  async updateStudentType(userId: string, studentType: StudentType): Promise<void> {
    const store = await this.helper.getStore()
    const valueBucket: relationalStore.ValuesBucket = {
      student_type: studentType,
      update_time: Date.now()
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.equalTo('user_id', userId)
    await store.update(valueBucket, predicates)
  }

  async updateStudentTypeByPhone(phone: string, studentType: StudentType): Promise<void> {
    const normalizedPhone = this.normalizePhone(phone)
    if (!normalizedPhone) {
      return
    }
    const store = await this.helper.getStore()
    const valueBucket: relationalStore.ValuesBucket = {
      student_type: studentType,
      update_time: Date.now()
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.equalTo('phone', normalizedPhone)
    await store.update(valueBucket, predicates)
  }

  async upgradeToVip(userId: string, extendMs: number, isLifetime: boolean): Promise<void> {
    const store = await this.helper.getStore()
    const user = await this.getUserById(userId)
    const now = Date.now()
    // 如果已过期或是首次开通，从现在开始计算；否则在现有到期时间上叠加
    const currentExpire = (user?.vipExpireTime && user.vipExpireTime > now) ? user.vipExpireTime : now
    const newExpireTime = isLifetime ? 0 : currentExpire + extendMs
    const valueBucket: relationalStore.ValuesBucket = {
      vip_level: VipLevel.VIP,
      vip_expire_time: newExpireTime,
      vip_lifetime: isLifetime ? 1 : 0,
      update_time: now
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.equalTo('user_id', userId)
    await store.update(valueBucket, predicates)
  }

  async submitAuth(userId: string, authData: Partial<UserProfile>): Promise<void> {
    const store = await this.helper.getStore()
    const valueBucket: relationalStore.ValuesBucket = {
      hr_real_name: authData.hrRealName ?? '',
      id_card: authData.idCard ?? '',
      company_name: authData.companyName ?? '',
      company_address: authData.companyAddress ?? '',
      company_industry: authData.companyIndustry ?? '',
      company_scale: authData.companyScale ?? '',
      legal_person: authData.legalPerson ?? '',
      contact_position: authData.contactPosition ?? '',
      company_email: authData.companyEmail ?? '',
      business_license: authData.businessLicense ?? '',
      id_card_front_image: authData.idCardFrontImage ?? '',
      id_card_back_image: authData.idCardBackImage ?? '',
      face_image: authData.faceImage ?? '',
      auth_status: authData.authStatus ?? (AuthStatus.PENDING as number),
      auth_submit_time: authData.authSubmitTime ?? Date.now(),
      auth_approve_time: authData.authApproveTime ?? 0,
      auth_reject_reason: authData.authRejectReason ?? '',
      update_time: Date.now()
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.equalTo('user_id', userId)
    await store.update(valueBucket, predicates)
  }

  async updatePassword(userId: string, password: string): Promise<void> {
    const store = await this.helper.getStore()
    const valueBucket: relationalStore.ValuesBucket = {
      password: password,
      update_time: Date.now()
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.equalTo('user_id', userId)
    await store.update(valueBucket, predicates)
  }

  async isPhoneBound(phone: string): Promise<boolean> {
    const users = await this.queryUsersByPhone(phone)
    return users.length > 0
  }

  async getUserByPhone(phone: string): Promise<UserProfile | null> {
    const users = await this.queryUsersByPhone(phone)
    if (users.length === 0) {
      return null
    }
    for (let i = 0; i < users.length; i++) {
      if (users[i].studentType) {
        return users[i]
      }
    }
    return users[0]
  }

  async getUserByEmail(email: string): Promise<UserProfile | null> {
    const users = await this.queryUsersByEmail(email)
    if (users.length === 0) {
      return null
    }
    for (let i = 0; i < users.length; i++) {
      if (users[i].studentType) {
        return users[i]
      }
    }
    return users[0]
  }

  async getUserByPhoneAndPassword(phone: string, password: string): Promise<UserProfile | null> {
    const normalizedPhone = this.normalizePhone(phone)
    const normalizedPassword = this.normalizePassword(password)
    if (!normalizedPhone || !normalizedPassword) {
      return null
    }
    const users = await this.queryUsersByPhone(normalizedPhone)
    let matchedWithoutStudentType: UserProfile | null = null
    for (let i = 0; i < users.length; i++) {
      const candidate = users[i]
      if (candidate && (candidate.password || '') === normalizedPassword) {
        if (candidate.studentType) {
          return candidate
        }
        if (!matchedWithoutStudentType) {
          matchedWithoutStudentType = candidate
        }
      }
    }
    if (matchedWithoutStudentType) {
      for (let i = 0; i < users.length; i++) {
        const candidate = users[i]
        if (candidate && candidate.studentType) {
          await this.updateStudentType(matchedWithoutStudentType.userId, candidate.studentType)
          return await this.getUserById(matchedWithoutStudentType.userId)
        }
      }
      return matchedWithoutStudentType
    }
    for (let i = 0; i < users.length; i++) {
      const candidate = users[i]
      if (candidate && (!candidate.password || candidate.password.length === 0)) {
        for (let j = 0; j < users.length; j++) {
          const typedUser = users[j]
          if (typedUser && typedUser.studentType) {
            await this.updateStudentType(candidate.userId, typedUser.studentType)
            break
          }
        }
        await this.updatePassword(candidate.userId, normalizedPassword)
        return await this.getUserById(candidate.userId)
      }
    }
    return null
  }

  async getUserByEmailAndPassword(email: string, password: string): Promise<UserProfile | null> {
    const normalizedEmail = this.normalizeEmail(email)
    const normalizedPassword = this.normalizePassword(password)
    if (!normalizedEmail || !normalizedPassword) {
      return null
    }
    const users = await this.queryUsersByEmail(normalizedEmail)
    let matchedWithoutStudentType: UserProfile | null = null
    for (let i = 0; i < users.length; i++) {
      const candidate = users[i]
      if (candidate && (candidate.password || '') === normalizedPassword) {
        if (candidate.studentType) {
          return candidate
        }
        if (!matchedWithoutStudentType) {
          matchedWithoutStudentType = candidate
        }
      }
    }
    if (matchedWithoutStudentType) {
      for (let i = 0; i < users.length; i++) {
        const candidate = users[i]
        if (candidate && candidate.studentType) {
          await this.updateStudentType(matchedWithoutStudentType.userId, candidate.studentType)
          return await this.getUserById(matchedWithoutStudentType.userId)
        }
      }
      return matchedWithoutStudentType
    }
    for (let i = 0; i < users.length; i++) {
      const candidate = users[i]
      if (candidate && (!candidate.password || candidate.password.length === 0)) {
        for (let j = 0; j < users.length; j++) {
          const typedUser = users[j]
          if (typedUser && typedUser.studentType) {
            await this.updateStudentType(candidate.userId, typedUser.studentType)
            break
          }
        }
        await this.updatePassword(candidate.userId, normalizedPassword)
        return await this.getUserById(candidate.userId)
      }
    }
    return null
  }

  private rowToUserProfile(row: relationalStore.ResultSet): UserProfile {
    const roleStr = row.getString(row.getColumnIndex('role'))
    const studentTypeStr = row.getString(row.getColumnIndex('student_type'))
    const genderStr = row.getString(row.getColumnIndex('gender'))
    const vipLevelStr = row.getString(row.getColumnIndex('vip_level'))

    return {
      userId: row.getString(row.getColumnIndex('user_id')),
      phone: row.getString(row.getColumnIndex('phone')),
      email: row.getString(row.getColumnIndex('email')),
      role: (roleStr === UserRole.RECRUITER ? UserRole.RECRUITER : UserRole.JOB_SEEKER) as UserRole,
      studentType: studentTypeStr === StudentType.GRADUATING
        ? StudentType.GRADUATING
        : studentTypeStr === StudentType.CURRENT
          ? StudentType.CURRENT
          : undefined,
      realName: row.getString(row.getColumnIndex('real_name')),
      gender: (genderStr === Gender.MALE ? Gender.MALE : genderStr === Gender.FEMALE ? Gender.FEMALE : Gender.UNKNOWN) as Gender,
      birthday: row.getString(row.getColumnIndex('birthday')),
      education: row.getString(row.getColumnIndex('education')),
      school: row.getString(row.getColumnIndex('school')),
      major: row.getString(row.getColumnIndex('major')),
      expectedPosition: row.getString(row.getColumnIndex('expected_position')),
      expectedSalary: row.getString(row.getColumnIndex('expected_salary')),
      currentCity: row.getString(row.getColumnIndex('current_city')),
      isGuest: row.getLong(row.getColumnIndex('is_guest')) === 1,
      avatar: row.getString(row.getColumnIndex('avatar')),
      companyName: row.getString(row.getColumnIndex('company_name')),
      companyAddress: row.getString(row.getColumnIndex('company_address')),
      companyIndustry: row.getString(row.getColumnIndex('company_industry')),
      companyScale: row.getString(row.getColumnIndex('company_scale')),
      legalPerson: row.getString(row.getColumnIndex('legal_person')),
      contactPosition: row.getString(row.getColumnIndex('contact_position')),
      companyEmail: row.getString(row.getColumnIndex('company_email')),
      idCard: row.getString(row.getColumnIndex('id_card')),
      businessLicense: row.getString(row.getColumnIndex('business_license')),
      vipLevel: (vipLevelStr === VipLevel.VIP ? VipLevel.VIP : VipLevel.NORMAL) as VipLevel,
      vipExpireTime: row.getLong(row.getColumnIndex('vip_expire_time')),
      vipLifetime: row.getLong(row.getColumnIndex('vip_lifetime')) === 1,
      positionCount: row.getLong(row.getColumnIndex('position_count')),
      hrRealName: row.getString(row.getColumnIndex('hr_real_name')),
      password: row.getString(row.getColumnIndex('password')),
      authStatus: row.getLong(row.getColumnIndex('auth_status')),
      idCardFrontImage: row.getString(row.getColumnIndex('id_card_front_image')),
      idCardBackImage: row.getString(row.getColumnIndex('id_card_back_image')),
      faceImage: row.getString(row.getColumnIndex('face_image')),
      authSubmitTime: row.getLong(row.getColumnIndex('auth_submit_time')),
      authApproveTime: row.getLong(row.getColumnIndex('auth_approve_time')),
      authRejectReason: row.getString(row.getColumnIndex('auth_reject_reason'))
    }
  }
}
