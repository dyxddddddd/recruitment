// 简历-岗位匹配度计算服务
// 创新点：基于技能、学历、城市、薪资、课表时间多维度计算匹配度

import { ResumeInfo } from '../model/ResumeModel'
import { JobPosition } from '../model/JobModel'

export interface MatchResult {
  score: number
  skillScore: number
  eduScore: number
  cityScore: number
  salaryScore: number
  timeScore: number
  reasons: string[]
  gaps: string[]
  matchedSkills: string[]
  missingSkills: string[]
}

export interface EduKeyword {
  keyword: string
  level: number
}

const EDU_LEVEL: Record<string, number> = {
  '中专': 1, '技校': 1, '高中': 2, '大专': 3,
  '本科': 4, '硕士': 5, 'MBA': 5, '博士': 6
}

const EDU_KEYWORDS: EduKeyword[] = [
  { keyword: '博士', level: 6 },
  { keyword: '硕士', level: 5 },
  { keyword: '本科', level: 4 },
  { keyword: '大专', level: 3 },
  { keyword: '高中', level: 2 },
  { keyword: '不限', level: 0 }
]

export function calculateMatchScore(resume: ResumeInfo, job: JobPosition): MatchResult {
  const reasons: string[] = []
  const gaps: string[] = []
  const matchedSkills: string[] = []
  const missingSkills: string[] = []

  const resumeSkills = resume.skills.map((s: string) => s.toLowerCase())
  const jobSkills = job.skills.map((s: string) => s.toLowerCase())

  let skillScore = 0
  if (jobSkills.length > 0) {
    const overlap = jobSkills.filter((s: string) => resumeSkills.some((r: string) => r.includes(s) || s.includes(r)))
    const missing = jobSkills.filter((s: string) => !resumeSkills.some((r: string) => r.includes(s) || s.includes(r)))
    for (let i = 0; i < overlap.length; i++) {
      matchedSkills.push(overlap[i])
    }
    for (let i = 0; i < missing.length; i++) {
      missingSkills.push(missing[i])
    }
    skillScore = Math.round((overlap.length / jobSkills.length) * 100)
  } else {
    skillScore = 80
  }

  if (skillScore >= 60) {
    reasons.push(`技能匹配 ${skillScore}%`)
  } else if (skillScore < 30) {
    gaps.push(`技能匹配仅 ${skillScore}%`)
  }

  let eduScore = 50
  const resumeEduLevel = EDU_LEVEL[resume.education] ?? 4
  let requiredLevel = 0
  for (let i = 0; i < EDU_KEYWORDS.length; i++) {
    if (job.educationRequired.includes(EDU_KEYWORDS[i].keyword)) {
      requiredLevel = EDU_KEYWORDS[i].level
      break
    }
  }

  if (requiredLevel === 0) {
    eduScore = 90
    reasons.push('学历要求不限')
  } else if (resumeEduLevel >= requiredLevel) {
    eduScore = 100
    reasons.push(`学历达标（${resume.education}）`)
  } else {
    eduScore = Math.round((resumeEduLevel / requiredLevel) * 60)
    gaps.push(`学历偏低（要求${job.educationRequired}）`)
  }

  let cityScore = 50
  if (resume.currentCity && job.city) {
    if (resume.currentCity.includes(job.city) || job.city.includes(resume.currentCity)) {
      cityScore = 100
      reasons.push(`工作地 ${job.city} 与你所在一致`)
    } else {
      cityScore = 40
      gaps.push(`工作地 ${job.city} 与你当前城市不同`)
    }
  } else if (!resume.currentCity) {
    cityScore = 70
    gaps.push('请完善「当前城市」以提升匹配度')
  } else {
    cityScore = 80
    reasons.push('岗位地点不限')
  }

  let salaryScore = 70
  if (resume.expectedSalary && job.salaryRange) {
    const resumeMin = parseInt(resume.expectedSalary.replace(/\D/g, '')) || 0
    const jobMin = parseInt(job.salaryRange.replace(/\D/g, '')) || 0
    if (resumeMin > 0 && jobMin > 0) {
      if (resumeMin <= jobMin) {
        salaryScore = 100
        reasons.push('期望薪资在岗位范围内')
      } else if (resumeMin > jobMin * 1.5) {
        salaryScore = 30
        gaps.push('期望薪资高于岗位范围')
      } else {
        salaryScore = 70
      }
    }
  } else {
    salaryScore = 75
  }

  let timeScore = 50
  if (resume.hasSchedule && job.category === 'micro_task') {
    timeScore = 85
    reasons.push('已导入课表，可精确匹配微任务时间')
  } else if (!resume.hasSchedule && job.category === 'micro_task') {
    timeScore = 40
    gaps.push('建议导入课表以匹配微任务时间')
  } else {
    timeScore = 80
  }

  const score = Math.round(
    skillScore * 0.30 + eduScore * 0.25 + cityScore * 0.20 + salaryScore * 0.15 + timeScore * 0.10
  )

  const topGaps: string[] = []
  for (let i = 0; i < Math.min(gaps.length, 3); i++) {
    topGaps.push(gaps[i])
  }

  return {
    score: Math.min(100, Math.max(0, score)),
    skillScore,
    eduScore,
    cityScore,
    salaryScore,
    timeScore,
    reasons,
    gaps: topGaps,
    matchedSkills,
    missingSkills
  }
}

export function getMatchSummary(result: MatchResult): string {
  if (result.score >= 80) return '高度匹配！投递成功率较高'
  if (result.score >= 60) return '基本匹配，可以尝试投递'
  if (result.score >= 40) return '匹配度一般，建议完善简历后再投递'
  return '匹配度较低，建议优先投递匹配度更高的岗位'
}
