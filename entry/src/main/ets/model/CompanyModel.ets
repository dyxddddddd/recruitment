// 企业与社区数据模型

export interface CompanyInfo {
  companyId: string
  name: string
  logo: string
  industry: string
  scale: string                     // 规模
  description: string
  address: string
  // 招聘计划
  recruitmentPlan?: RecruitmentPlan
  // 宣讲会
  careerTalks: CareerTalk[]
  // 校友图谱数据
  alumniNetwork?: AlumniNode[]
}

export interface RecruitmentPlan {
  year: string
  totalPositions: number
  positions: string[]
  descriptions: string
}

export interface CareerTalk {
  talkId: string
  companyId: string
  companyName: string
  title: string
  date: string
  time: string
  location: string
  isOnline: boolean
  onlineLink?: string
}

export interface AlumniNode {
  alumniId: string
  name: string                    // 匿名显示
  school: string
  major: string
  graduationYear: string
  department: string
  position: string
  // 拓扑图连线关系
  connections: string[]
}

// 社区帖子
export interface CommunityPost {
  postId: string
  userId: string
  school: string                    // 所属学校
  title: string
  content: string
  category: 'interview' | 'companion' | 'discussion'  // 面经 / 找搭子 / 讨论
  isAnonymous: boolean
  tags: string[]
  likeCount: number
  commentCount: number
  createTime: number
}

export interface PostComment {
  commentId: string
  postId: string
  userId: string
  content: string
  isAnonymous: boolean
  createTime: number
}
