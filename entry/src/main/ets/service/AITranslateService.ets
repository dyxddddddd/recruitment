import { CampusAIService } from './CampusAIService'

export interface ExperienceInput {
  description: string
  type: string
}

export interface RewrittenExperience {
  description: string
  rewrittenDescription: string
  skills: string[]
}

export interface ExperienceRewriteResult {
  original: string
  rewritten: string
  matchedPattern: string
  skills: string[]
  confidence: 'high' | 'medium' | 'low'
}

export async function rewriteStudentExperience(description: string, type: string = 'project'): Promise<ExperienceRewriteResult> {
  const result = await CampusAIService.translateCampusExperience(description, type)
  return {
    original: description,
    rewritten: result.translated || description,
    matchedPattern: 'deepseek-rewrite',
    skills: result.skills || [],
    confidence: result.confidence || 'medium'
  }
}

export async function rewriteExperienceList(experiences: ExperienceInput[]): Promise<RewrittenExperience[]> {
  const rewritten: RewrittenExperience[] = []
  for (let i = 0; i < experiences.length; i++) {
    const item = experiences[i]
    const result = await rewriteStudentExperience(item.description, item.type)
    rewritten.push({
      description: item.description,
      rewrittenDescription: result.rewritten,
      skills: result.skills
    })
  }
  return rewritten
}
