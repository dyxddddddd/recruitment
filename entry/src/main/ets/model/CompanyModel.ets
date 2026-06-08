export interface CompanyInfo {
  companyId: string
  name: string
  logo: string
  industry: string
  scale: string
  description: string
  address: string
  recruitmentPlan?: RecruitmentPlan
  careerTalks: CareerTalk[]
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
  name: string
  school: string
  major: string
  graduationYear: string
  department: string
  position: string
  connections: string[]
}

export interface CommunityPost {
  postId: string
  userId: string
  school: string
  title: string
  content: string
  category: 'interview' | 'companion' | 'discussion'
  isAnonymous: boolean
  tags: string[]
  likeCount: number
  favoriteCount: number
  commentCount: number
  createTime: number
  authorName?: string
  liked?: boolean
  favorited?: boolean
}

export interface PostComment {
  commentId: string
  postId: string
  userId: string
  content: string
  isAnonymous: boolean
  createTime: number
  authorName?: string
  postTitle?: string     // 所属帖子标题（用于"我的评论"展示）
}
