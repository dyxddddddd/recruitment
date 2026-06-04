import { CampusAIService } from './CampusAIService'

export interface ExperienceInput {
  description: string
  type: string
}

export interface TranslatedExperience {
  description: string
  translatedDescription: string
  skills: string[]
}

export interface TranslateResult {
  original: string
  translated: string
  matchedPattern: string
  skills: string[]
  confidence: 'high' | 'medium' | 'low'
}

export async function translateStudentExperience(description: string, type: string = 'project'): Promise<TranslateResult> {
  const result = await CampusAIService.translateCampusExperience(description, type)
  return {
    original: description,
    translated: result.translated || description,
    matchedPattern: 'deepseek',
    skills: result.skills || [],
    confidence: result.confidence || 'medium'
  }
}

export async function translateExperienceList(experiences: ExperienceInput[]): Promise<TranslatedExperience[]> {
  const translated: TranslatedExperience[] = []
  for (let i = 0; i < experiences.length; i++) {
    const item = experiences[i]
    const result = await translateStudentExperience(item.description, item.type)
    translated.push({
      description: item.description,
      translatedDescription: result.translated,
      skills: result.skills
    })
  }
  return translated
}
