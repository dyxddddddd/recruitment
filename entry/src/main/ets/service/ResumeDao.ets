// 简历数据访问对象

import { relationalStore } from '@kit.ArkData'
import { DatabaseHelper } from '../database/DatabaseHelper'
import { TABLE_RESUME, TABLE_EDUCATION, TABLE_EXPERIENCE, TABLE_SCHEDULE } from '../database/Tables'
import { ResumeInfo, EducationItem, ExperienceItem, CourseSchedule, SemesterSchedule, FreeTimeSlot } from '../model/ResumeModel'

export class ResumeDao {
  private helper: DatabaseHelper = DatabaseHelper.getInstance()

  async upsertResume(resume: ResumeInfo): Promise<void> {
    const existing = await this.getResumeByUserId(resume.userId)
    if (existing) {
      resume.resumeId = existing.resumeId
      await this.updateResume(resume)
    } else {
      await this.insertResume(resume)
    }
  }

  async insertResume(resume: ResumeInfo): Promise<void> {
    const store = await this.helper.getStore()
    const vb: relationalStore.ValuesBucket = {
      resume_id: resume.resumeId,
      user_id: resume.userId,
      real_name: resume.realName,
      gender: resume.gender,
      birthday: resume.birthday,
      education: resume.education,
      school: resume.school,
      major: resume.major,
      graduation_year: resume.graduationYear,
      expected_position: resume.expectedPosition,
      expected_salary: resume.expectedSalary,
      current_city: resume.currentCity,
      phone: resume.phone,
      email: resume.email,
      skills: JSON.stringify(resume.skills),
      self_intro: resume.selfIntro,
      is_from_pdf: resume.isFromPDF ? 1 : 0,
      pdf_uncertain_fields: JSON.stringify(resume.pdfUncertainFields),
      has_schedule: resume.hasSchedule ? 1 : 0,
      schedule_id: resume.scheduleId ?? '',
      update_time: resume.updateTime
    }
    await store.insert(TABLE_RESUME, vb)
  }

  async updateResume(resume: ResumeInfo): Promise<void> {
    const store = await this.helper.getStore()
    const vb: relationalStore.ValuesBucket = {
      real_name: resume.realName,
      gender: resume.gender,
      birthday: resume.birthday,
      education: resume.education,
      school: resume.school,
      major: resume.major,
      graduation_year: resume.graduationYear,
      expected_position: resume.expectedPosition,
      expected_salary: resume.expectedSalary,
      current_city: resume.currentCity,
      phone: resume.phone,
      email: resume.email,
      skills: JSON.stringify(resume.skills),
      self_intro: resume.selfIntro,
      is_from_pdf: resume.isFromPDF ? 1 : 0,
      pdf_uncertain_fields: JSON.stringify(resume.pdfUncertainFields),
      has_schedule: resume.hasSchedule ? 1 : 0,
      schedule_id: resume.scheduleId ?? '',
      update_time: Date.now()
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_RESUME)
    predicates.equalTo('resume_id', resume.resumeId)
    await store.update(vb, predicates)
  }

  async getResumeByUserId(userId: string): Promise<ResumeInfo | null> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_RESUME)
    predicates.equalTo('user_id', userId)
    const rs = await store.query(predicates)
    if (rs.goToFirstRow()) {
      const resume = this.rowToResume(rs)
      rs.close()
      resume.educationList = await this.getEducationList(resume.resumeId)
      resume.experienceList = await this.getExperienceList(resume.resumeId)
      return resume
    }
    return null
  }

  async insertEducation(item: EducationItem, resumeId: string): Promise<void> {
    const store = await this.helper.getStore()
    const eduId = `edu_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`
    const vb: relationalStore.ValuesBucket = {
      edu_id: eduId,
      resume_id: resumeId,
      school_name: item.schoolName,
      major: item.major,
      degree: item.degree,
      start_year: item.startYear,
      end_year: item.endYear
    }
    await store.insert(TABLE_EDUCATION, vb)
  }

  async insertExperience(item: ExperienceItem, resumeId: string): Promise<void> {
    const store = await this.helper.getStore()
    const expId = `exp_${Date.now()}_${Math.random().toString(36).substring(2, 8)}`
    const vb: relationalStore.ValuesBucket = {
      exp_id: expId,
      resume_id: resumeId,
      type: item.type,
      company_name: item.companyName ?? '',
      project_name: item.projectName ?? '',
      role: item.role,
      description: item.description,
      translated_description: item.translatedDescription ?? '',
      start_time: item.startTime,
      end_time: item.endTime
    }
    await store.insert(TABLE_EXPERIENCE, vb)
  }

  async saveSchedule(schedule: CourseSchedule): Promise<void> {
    const store = await this.helper.getStore()
    const vb: relationalStore.ValuesBucket = {
      schedule_id: schedule.scheduleId,
      user_id: schedule.userId,
      schedule_data: JSON.stringify(schedule.semesters),
      free_slots: JSON.stringify(schedule.freeSlots),
      update_time: schedule.updateTime
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_SCHEDULE)
    predicates.equalTo('schedule_id', schedule.scheduleId)
    const rs = await store.query(predicates)
    if (rs.rowCount > 0) {
      await store.update(vb, predicates)
    } else {
      await store.insert(TABLE_SCHEDULE, vb)
    }
    rs.close()
  }

  async getScheduleByUserId(userId: string): Promise<CourseSchedule | null> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_SCHEDULE)
    predicates.equalTo('user_id', userId)
    const rs = await store.query(predicates)
    if (rs.goToFirstRow()) {
      const schedule: CourseSchedule = {
        scheduleId: rs.getString(rs.getColumnIndex('schedule_id')),
        userId: rs.getString(rs.getColumnIndex('user_id')),
        semesters: JSON.parse(rs.getString(rs.getColumnIndex('schedule_data')) || '[]') as SemesterSchedule[],
        freeSlots: JSON.parse(rs.getString(rs.getColumnIndex('free_slots')) || '[]') as FreeTimeSlot[],
        updateTime: rs.getLong(rs.getColumnIndex('update_time'))
      }
      rs.close()
      return schedule
    }
    return null
  }

  async replaceEducationList(resumeId: string, educationList: EducationItem[]): Promise<void> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_EDUCATION)
    predicates.equalTo('resume_id', resumeId)
    await store.delete(predicates)
    for (let i = 0; i < educationList.length; i++) {
      await this.insertEducation(educationList[i], resumeId)
    }
  }

  async replaceExperienceList(resumeId: string, experienceList: ExperienceItem[]): Promise<void> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_EXPERIENCE)
    predicates.equalTo('resume_id', resumeId)
    await store.delete(predicates)
    for (let i = 0; i < experienceList.length; i++) {
      await this.insertExperience(experienceList[i], resumeId)
    }
  }

  private async getEducationList(resumeId: string): Promise<EducationItem[]> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_EDUCATION)
    predicates.equalTo('resume_id', resumeId)
    const rs = await store.query(predicates)
    const list: EducationItem[] = []
    while (rs.goToNextRow()) {
      list.push({
        schoolName: rs.getString(rs.getColumnIndex('school_name')),
        major: rs.getString(rs.getColumnIndex('major')),
        degree: rs.getString(rs.getColumnIndex('degree')),
        startYear: rs.getString(rs.getColumnIndex('start_year')),
        endYear: rs.getString(rs.getColumnIndex('end_year'))
      })
    }
    rs.close()
    return list
  }

  private async getExperienceList(resumeId: string): Promise<ExperienceItem[]> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_EXPERIENCE)
    predicates.equalTo('resume_id', resumeId)
    const rs = await store.query(predicates)
    const list: ExperienceItem[] = []
    while (rs.goToNextRow()) {
      const expType = rs.getString(rs.getColumnIndex('type'))
      list.push({
        type: (expType === 'project' ? 'project' : 'intern') as 'intern' | 'project',
        companyName: rs.getString(rs.getColumnIndex('company_name')),
        projectName: rs.getString(rs.getColumnIndex('project_name')),
        role: rs.getString(rs.getColumnIndex('role')),
        description: rs.getString(rs.getColumnIndex('description')),
        translatedDescription: rs.getString(rs.getColumnIndex('translated_description')),
        startTime: rs.getString(rs.getColumnIndex('start_time')),
        endTime: rs.getString(rs.getColumnIndex('end_time'))
      })
    }
    rs.close()
    return list
  }

  private rowToResume(row: relationalStore.ResultSet): ResumeInfo {
    return {
      resumeId: row.getString(row.getColumnIndex('resume_id')),
      userId: row.getString(row.getColumnIndex('user_id')),
      realName: row.getString(row.getColumnIndex('real_name')),
      gender: row.getString(row.getColumnIndex('gender')),
      birthday: row.getString(row.getColumnIndex('birthday')),
      education: row.getString(row.getColumnIndex('education')),
      school: row.getString(row.getColumnIndex('school')),
      major: row.getString(row.getColumnIndex('major')),
      graduationYear: row.getString(row.getColumnIndex('graduation_year')),
      expectedPosition: row.getString(row.getColumnIndex('expected_position')),
      expectedSalary: row.getString(row.getColumnIndex('expected_salary')),
      currentCity: row.getString(row.getColumnIndex('current_city')),
      phone: row.getString(row.getColumnIndex('phone')),
      email: row.getString(row.getColumnIndex('email')),
      skills: JSON.parse(row.getString(row.getColumnIndex('skills')) || '[]') as string[],
      selfIntro: row.getString(row.getColumnIndex('self_intro')),
      isFromPDF: row.getLong(row.getColumnIndex('is_from_pdf')) === 1,
      pdfUncertainFields: JSON.parse(row.getString(row.getColumnIndex('pdf_uncertain_fields')) || '[]') as string[],
      hasSchedule: row.getLong(row.getColumnIndex('has_schedule')) === 1,
      scheduleId: row.getString(row.getColumnIndex('schedule_id')),
      updateTime: row.getLong(row.getColumnIndex('update_time')),
      educationList: [],
      experienceList: []
    }
  }
}
