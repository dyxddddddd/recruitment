// 职位数据访问对象

import { relationalStore } from '@kit.ArkData'
import { DatabaseHelper } from '../database/DatabaseHelper'
import { TABLE_JOB, TABLE_APPLICATION, TABLE_MICRO_TASK } from '../database/Tables'
import { JobPosition, JobCategory, JobStatus, JobApplication, ApplicationStatus, MicroTask } from '../model/JobModel'

export class JobDao {
  private helper: DatabaseHelper = DatabaseHelper.getInstance()

  // ---- 职位操作 ----

  async insertJob(job: JobPosition): Promise<void> {
    const store = await this.helper.getStore()
    const vb: relationalStore.ValuesBucket = {
      job_id: job.jobId,
      recruiter_id: job.recruiterId,
      company_name: job.companyName,
      title: job.title,
      category: job.category,
      description: job.description,
      education_required: job.educationRequired,
      salary_range: job.salaryRange,
      work_years_required: job.workYearsRequired,
      work_address: job.workAddress,
      city: job.city,
      skills: JSON.stringify(job.skills),
      status: job.status,
      publish_time: job.publishTime,
      update_time: job.updateTime,
      tags: JSON.stringify(job.tags),
      is_ai_generated: job.isAIGenerated ? 1 : 0
    }
    await store.insert(TABLE_JOB, vb)
  }

  async queryJobs(category?: JobCategory, city?: string): Promise<JobPosition[]> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_JOB)
    predicates.equalTo('status', JobStatus.PUBLISHED)
    if (category) {
      predicates.equalTo('category', category)
    }
    if (city) {
      predicates.equalTo('city', city)
    }
    predicates.orderByDesc('publish_time')
    const rs = await store.query(predicates)
    const jobs: JobPosition[] = []
    while (rs.goToNextRow()) {
      jobs.push(this.rowToJob(rs))
    }
    rs.close()
    return jobs
  }

  async getJobById(jobId: string): Promise<JobPosition | null> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_JOB)
    predicates.equalTo('job_id', jobId)
    const rs = await store.query(predicates)
    if (rs.goToFirstRow()) {
      return this.rowToJob(rs)
    }
    return null
  }

  async getJobsByRecruiter(recruiterId: string): Promise<JobPosition[]> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_JOB)
    predicates.equalTo('recruiter_id', recruiterId)
    predicates.orderByDesc('publish_time')
    const rs = await store.query(predicates)
    const jobs: JobPosition[] = []
    while (rs.goToNextRow()) {
      jobs.push(this.rowToJob(rs))
    }
    rs.close()
    return jobs
  }

  async searchJobs(keyword: string): Promise<JobPosition[]> {
    const store = await this.helper.getStore()
    const sql = `SELECT * FROM ${TABLE_JOB} WHERE status = '${JobStatus.PUBLISHED}' AND (title LIKE '%${keyword}%' OR description LIKE '%${keyword}%' OR company_name LIKE '%${keyword}%' OR skills LIKE '%${keyword}%') ORDER BY publish_time DESC`
    const rs = await store.querySql(sql)
    const jobs: JobPosition[] = []
    while (rs.goToNextRow()) {
      jobs.push(this.rowToJob(rs))
    }
    rs.close()
    return jobs
  }

  async deleteJob(jobId: string): Promise<void> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_JOB)
    predicates.equalTo('job_id', jobId)
    await store.delete(predicates)
  }

  // ---- 投递操作 ----

  async insertApplication(app: JobApplication): Promise<void> {
    const store = await this.helper.getStore()
    const vb: relationalStore.ValuesBucket = {
      application_id: app.applicationId,
      job_id: app.jobId,
      user_id: app.userId,
      resume_id: app.resumeId,
      status: app.status,
      apply_time: app.applyTime,
      interview_time: app.interviewTime ?? null,
      remark: app.remark ?? ''
    }
    await store.insert(TABLE_APPLICATION, vb)

    await store.executeSql(
      `UPDATE ${TABLE_JOB} SET apply_count = apply_count + 1 WHERE job_id = '${app.jobId}'`
    )
  }

  async getApplicationsByUser(userId: string): Promise<JobApplication[]> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_APPLICATION)
    predicates.equalTo('user_id', userId)
    predicates.orderByDesc('apply_time')
    const rs = await store.query(predicates)
    const apps: JobApplication[] = []
    while (rs.goToNextRow()) {
      apps.push(this.rowToApplication(rs))
    }
    rs.close()
    return apps
  }

  async getApplicationsByJob(jobId: string): Promise<JobApplication[]> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_APPLICATION)
    predicates.equalTo('job_id', jobId)
    predicates.orderByDesc('apply_time')
    const rs = await store.query(predicates)
    const apps: JobApplication[] = []
    while (rs.goToNextRow()) {
      apps.push(this.rowToApplication(rs))
    }
    rs.close()
    return apps
  }

  // ---- 微任务操作 ----

  async insertMicroTask(task: MicroTask): Promise<void> {
    const store = await this.helper.getStore()
    const vb: relationalStore.ValuesBucket = {
      task_id: task.taskId,
      recruiter_id: task.recruiterId,
      title: task.title,
      description: task.description,
      price: task.price,
      deadline: task.deadline,
      skills: JSON.stringify(task.skills),
      status: task.status,
      publish_time: task.publishTime,
      accepted_by: task.acceptedBy ?? ''
    }
    await store.insert(TABLE_MICRO_TASK, vb)
  }

  async getMicroTasks(): Promise<MicroTask[]> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_MICRO_TASK)
    predicates.orderByDesc('publish_time')
    const rs = await store.query(predicates)
    const tasks: MicroTask[] = []
    while (rs.goToNextRow()) {
      tasks.push(this.rowToMicroTask(rs))
    }
    rs.close()
    return tasks
  }

  private rowToJob(row: relationalStore.ResultSet): JobPosition {
    const categoryStr = row.getString(row.getColumnIndex('category'))
    const statusStr = row.getString(row.getColumnIndex('status'))
    return {
      jobId: row.getString(row.getColumnIndex('job_id')),
      recruiterId: row.getString(row.getColumnIndex('recruiter_id')),
      companyName: row.getString(row.getColumnIndex('company_name')),
      title: row.getString(row.getColumnIndex('title')),
      category: (categoryStr === JobCategory.FULLTIME_INTERN ? JobCategory.FULLTIME_INTERN : JobCategory.MICRO_TASK) as JobCategory,
      description: row.getString(row.getColumnIndex('description')),
      educationRequired: row.getString(row.getColumnIndex('education_required')),
      salaryRange: row.getString(row.getColumnIndex('salary_range')),
      workYearsRequired: row.getString(row.getColumnIndex('work_years_required')),
      workAddress: row.getString(row.getColumnIndex('work_address')),
      city: row.getString(row.getColumnIndex('city')),
      skills: JSON.parse(row.getString(row.getColumnIndex('skills')) || '[]') as string[],
      status: (statusStr === JobStatus.CLOSED ? JobStatus.CLOSED : statusStr === JobStatus.PENDING_REVIEW ? JobStatus.PENDING_REVIEW : JobStatus.PUBLISHED) as JobStatus,
      publishTime: row.getLong(row.getColumnIndex('publish_time')),
      updateTime: row.getLong(row.getColumnIndex('update_time')),
      viewCount: row.getLong(row.getColumnIndex('view_count')),
      applyCount: row.getLong(row.getColumnIndex('apply_count')),
      tags: JSON.parse(row.getString(row.getColumnIndex('tags')) || '[]') as string[],
      isAIGenerated: row.getLong(row.getColumnIndex('is_ai_generated')) === 1
    }
  }

  private rowToApplication(row: relationalStore.ResultSet): JobApplication {
    const statusStr = row.getString(row.getColumnIndex('status'))
    return {
      applicationId: row.getString(row.getColumnIndex('application_id')),
      jobId: row.getString(row.getColumnIndex('job_id')),
      userId: row.getString(row.getColumnIndex('user_id')),
      resumeId: row.getString(row.getColumnIndex('resume_id')),
      status: (statusStr === ApplicationStatus.VIEWED ? ApplicationStatus.VIEWED
        : statusStr === ApplicationStatus.INTERVIEW ? ApplicationStatus.INTERVIEW
        : statusStr === ApplicationStatus.OFFERED ? ApplicationStatus.OFFERED
        : statusStr === ApplicationStatus.REJECTED ? ApplicationStatus.REJECTED
        : statusStr === ApplicationStatus.ACCEPTED ? ApplicationStatus.ACCEPTED
        : ApplicationStatus.SUBMITTED) as ApplicationStatus,
      applyTime: row.getLong(row.getColumnIndex('apply_time')),
      interviewTime: row.getLong(row.getColumnIndex('interview_time')),
      remark: row.getString(row.getColumnIndex('remark'))
    }
  }

  private rowToMicroTask(row: relationalStore.ResultSet): MicroTask {
    return {
      taskId: row.getString(row.getColumnIndex('task_id')),
      recruiterId: row.getString(row.getColumnIndex('recruiter_id')),
      title: row.getString(row.getColumnIndex('title')),
      description: row.getString(row.getColumnIndex('description')),
      price: row.getDouble(row.getColumnIndex('price')),
      deadline: row.getString(row.getColumnIndex('deadline')),
      skills: JSON.parse(row.getString(row.getColumnIndex('skills')) || '[]') as string[],
      status: row.getString(row.getColumnIndex('status')),
      publishTime: row.getLong(row.getColumnIndex('publish_time')),
      acceptedBy: row.getString(row.getColumnIndex('accepted_by'))
    }
  }
}
