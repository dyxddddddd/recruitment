// 企业与社区数据访问对象

import { relationalStore } from '@kit.ArkData'
import { DatabaseHelper } from '../database/DatabaseHelper'
import { TABLE_COMPANY, TABLE_CAREER_TALK, TABLE_COMMUNITY_POST, TABLE_POST_COMMENT } from '../database/Tables'
import { CompanyInfo, CareerTalk, AlumniNode, CommunityPost, PostComment } from '../model/CompanyModel'

export class CompanyDao {
  private helper: DatabaseHelper = DatabaseHelper.getInstance()

  async getCompanies(): Promise<CompanyInfo[]> {
    const store = await this.helper.getStore()
    const sql = `SELECT * FROM ${TABLE_COMPANY}`
    const rs = await store.querySql(sql)
    const list: CompanyInfo[] = []
    while (rs.goToNextRow()) {
      list.push(this.rowToCompany(rs))
    }
    rs.close()
    return list
  }

  async getCompanyById(companyId: string): Promise<CompanyInfo | null> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_COMPANY)
    predicates.equalTo('company_id', companyId)
    const rs = await store.query(predicates)
    if (rs.goToFirstRow()) {
      const company = this.rowToCompany(rs)
      rs.close()
      company.careerTalks = await this.getCareerTalksByCompany(companyId)
      return company
    }
    return null
  }

  async getCareerTalks(): Promise<CareerTalk[]> {
    const store = await this.helper.getStore()
    const sql = `SELECT * FROM ${TABLE_CAREER_TALK} ORDER BY date ASC`
    const rs = await store.querySql(sql)
    const list: CareerTalk[] = []
    while (rs.goToNextRow()) {
      list.push({
        talkId: rs.getString(rs.getColumnIndex('talk_id')),
        companyId: rs.getString(rs.getColumnIndex('company_id')),
        companyName: rs.getString(rs.getColumnIndex('company_name')),
        title: rs.getString(rs.getColumnIndex('title')),
        date: rs.getString(rs.getColumnIndex('date')),
        time: rs.getString(rs.getColumnIndex('time')),
        location: rs.getString(rs.getColumnIndex('location')),
        isOnline: rs.getLong(rs.getColumnIndex('is_online')) === 1,
        onlineLink: rs.getString(rs.getColumnIndex('online_link'))
      })
    }
    rs.close()
    return list
  }

  private async getCareerTalksByCompany(companyId: string): Promise<CareerTalk[]> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_CAREER_TALK)
    predicates.equalTo('company_id', companyId)
    predicates.orderByAsc('date')
    const rs = await store.query(predicates)
    const list: CareerTalk[] = []
    while (rs.goToNextRow()) {
      list.push({
        talkId: rs.getString(rs.getColumnIndex('talk_id')),
        companyId: rs.getString(rs.getColumnIndex('company_id')),
        companyName: rs.getString(rs.getColumnIndex('company_name')),
        title: rs.getString(rs.getColumnIndex('title')),
        date: rs.getString(rs.getColumnIndex('date')),
        time: rs.getString(rs.getColumnIndex('time')),
        location: rs.getString(rs.getColumnIndex('location')),
        isOnline: rs.getLong(rs.getColumnIndex('is_online')) === 1,
        onlineLink: rs.getString(rs.getColumnIndex('online_link'))
      })
    }
    rs.close()
    return list
  }

  // ---- 社区 ----

  async getPosts(school?: string): Promise<CommunityPost[]> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_COMMUNITY_POST)
    if (school) {
      predicates.equalTo('school', school)
    }
    predicates.orderByDesc('create_time')
    const rs = await store.query(predicates)
    const posts: CommunityPost[] = []
    while (rs.goToNextRow()) {
      posts.push({
        postId: rs.getString(rs.getColumnIndex('post_id')),
        userId: rs.getString(rs.getColumnIndex('user_id')),
        school: rs.getString(rs.getColumnIndex('school')),
        title: rs.getString(rs.getColumnIndex('title')),
        content: rs.getString(rs.getColumnIndex('content')),
        category: rs.getString(rs.getColumnIndex('category')) as 'interview' | 'companion' | 'discussion',
        isAnonymous: rs.getLong(rs.getColumnIndex('is_anonymous')) === 1,
        tags: JSON.parse(rs.getString(rs.getColumnIndex('tags')) || '[]'),
        likeCount: rs.getLong(rs.getColumnIndex('like_count')),
        commentCount: rs.getLong(rs.getColumnIndex('comment_count')),
        createTime: rs.getLong(rs.getColumnIndex('create_time'))
      })
    }
    rs.close()
    return posts
  }

  async insertPost(post: CommunityPost): Promise<void> {
    const store = await this.helper.getStore()
    const vb: relationalStore.ValuesBucket = {
      post_id: post.postId,
      user_id: post.userId,
      school: post.school,
      title: post.title,
      content: post.content,
      category: post.category,
      is_anonymous: post.isAnonymous ? 1 : 0,
      tags: JSON.stringify(post.tags),
      like_count: post.likeCount,
      comment_count: post.commentCount,
      create_time: post.createTime
    }
    await store.insert(TABLE_COMMUNITY_POST, vb)
  }

  async insertComment(comment: PostComment): Promise<void> {
    const store = await this.helper.getStore()
    const vb: relationalStore.ValuesBucket = {
      comment_id: comment.commentId,
      post_id: comment.postId,
      user_id: comment.userId,
      content: comment.content,
      is_anonymous: comment.isAnonymous ? 1 : 0,
      create_time: comment.createTime
    }
    await store.insert(TABLE_POST_COMMENT, vb)
  }

  async getComments(postId: string): Promise<PostComment[]> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_POST_COMMENT)
    predicates.equalTo('post_id', postId)
    predicates.orderByAsc('create_time')
    const rs = await store.query(predicates)
    const list: PostComment[] = []
    while (rs.goToNextRow()) {
      list.push({
        commentId: rs.getString(rs.getColumnIndex('comment_id')),
        postId: rs.getString(rs.getColumnIndex('post_id')),
        userId: rs.getString(rs.getColumnIndex('user_id')),
        content: rs.getString(rs.getColumnIndex('content')),
        isAnonymous: rs.getLong(rs.getColumnIndex('is_anonymous')) === 1,
        createTime: rs.getLong(rs.getColumnIndex('create_time'))
      })
    }
    rs.close()
    return list
  }

  private rowToCompany(row: relationalStore.ResultSet): CompanyInfo {
    return {
      companyId: row.getString(row.getColumnIndex('company_id')),
      name: row.getString(row.getColumnIndex('name')),
      logo: row.getString(row.getColumnIndex('logo')),
      industry: row.getString(row.getColumnIndex('industry')),
      scale: row.getString(row.getColumnIndex('scale')),
      description: row.getString(row.getColumnIndex('description')),
      address: row.getString(row.getColumnIndex('address')),
      recruitmentPlan: row.getString(row.getColumnIndex('recruitment_plan'))
        ? JSON.parse(row.getString(row.getColumnIndex('recruitment_plan')))
        : undefined,
      alumniNetwork: row.getString(row.getColumnIndex('alumni_network'))
        ? JSON.parse(row.getString(row.getColumnIndex('alumni_network')))
        : undefined,
      careerTalks: []
    }
  }
}
