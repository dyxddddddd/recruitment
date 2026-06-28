import { relationalStore } from '@kit.ArkData'
import { DatabaseHelper } from '../database/DatabaseHelper'
import {
  TABLE_CAREER_TALK,
  TABLE_COMMUNITY_POST,
  TABLE_COMPANY,
  TABLE_POST_COMMENT,
  TABLE_POST_FAVORITE,
  TABLE_POST_LIKE,
  TABLE_USER
} from '../database/Tables'
import { AlumniNode, CareerTalk, CommunityPost, CompanyInfo, PostComment, RecruitmentPlan } from '../model/CompanyModel'

const COMMUNITY_SEED_POSTS: CommunityPost[] = [
  {
    postId: 'post_runtime_seed_001',
    userId: 'student_demo_001',
    school: 'Central South University',
    title: '腾讯前端一面都问了什么？',
    content: '这周刚面完，主要围绕项目拆解、性能优化、跨端适配和八股基础展开，整体更关注你真实做过什么。',
    category: 'interview',
    isAnonymous: true,
    tags: ['腾讯', '前端', '面经'],
    likeCount: 6,
    favoriteCount: 4,
    commentCount: 0,
    createTime: Date.now() - 2 * 60 * 60 * 1000,
    authorName: '校园同学'
  },
  {
    postId: 'post_runtime_seed_002',
    userId: 'student_demo_001',
    school: 'Central South University',
    title: '找一个后端秋招搭子互相监督',
    content: '想找同校一起刷八股、改简历、模拟面试的同学，最好方向是 Java / 后端开发。',
    category: 'companion',
    isAnonymous: true,
    tags: ['后端', '秋招', '搭子'],
    likeCount: 3,
    favoriteCount: 1,
    commentCount: 0,
    createTime: Date.now() - 5 * 60 * 60 * 1000,
    authorName: '校园同学'
  },
  {
    postId: 'post_runtime_seed_003',
    userId: 'student_demo_001',
    school: 'Hunan University',
    title: '产品岗暑期实习笔试交流',
    content: '有没有同校同学也投了产品暑期？想交流一下笔试题型和群面准备方式。',
    category: 'discussion',
    isAnonymous: true,
    tags: ['产品', '暑期实习', '笔试'],
    likeCount: 5,
    favoriteCount: 2,
    commentCount: 0,
    createTime: Date.now() - 8 * 60 * 60 * 1000,
    authorName: '校园同学'
  },
  {
    postId: 'post_runtime_seed_004',
    userId: 'student_demo_001',
    school: '华南理工科技大学',
    title: '有没有一起准备测开 / 测试开发暑期实习的同学？',
    content: '我这周刚开始系统刷测开方向的题，想找同校同学一起整理接口测试、SQL、Linux 和自动化测试常问点，也可以互相看简历。',
    category: 'companion',
    isAnonymous: true,
    tags: ['测开', '暑期实习', '搭子'],
    likeCount: 7,
    favoriteCount: 3,
    commentCount: 0,
    createTime: Date.now() - 90 * 60 * 1000,
    authorName: '校园同学'
  },
  {
    postId: 'post_runtime_seed_005',
    userId: 'student_demo_001',
    school: '华南理工科技大学',
    title: '小红书前端一面体验：更看重项目细节，不太爱问死八股',
    content: '今天面完感觉整体氛围还可以，面试官主要追问项目里你自己真正负责的模块、复杂交互怎么做、接口异常怎么处理，也问了性能优化和工程化。',
    category: 'interview',
    isAnonymous: true,
    tags: ['前端', '面经', '暑期实习'],
    likeCount: 12,
    favoriteCount: 8,
    commentCount: 0,
    createTime: Date.now() - 4 * 60 * 60 * 1000,
    authorName: '校园同学'
  },
  {
    postId: 'post_runtime_seed_006',
    userId: 'student_demo_001',
    school: '华南理工科技大学',
    title: '想问下现在大家找日常实习都主要投哪些平台？',
    content: 'BOSS、实习僧和公司官网我都有在看，但感觉信息有点散。想听听同校同学最近都在哪些渠道投得更多，尤其是产品和运营方向。',
    category: 'discussion',
    isAnonymous: false,
    tags: ['日常实习', '求职渠道', '交流'],
    likeCount: 5,
    favoriteCount: 2,
    commentCount: 0,
    createTime: Date.now() - 7 * 60 * 60 * 1000,
    authorName: '校园同学'
  },
  {
    postId: 'post_runtime_seed_007',
    userId: 'student_demo_001',
    school: '华南理工科技大学',
    title: '腾讯后端笔试复盘：并发、网络和两道算法题是重点',
    content: '刚做完一场后端笔试，主观感受是数据库题不算多，反而并发基础、HTTP / TCP、缓存一致性思路和算法实现更关键，时间还是挺紧的。',
    category: 'interview',
    isAnonymous: true,
    tags: ['腾讯', '后端', '笔试'],
    likeCount: 10,
    favoriteCount: 6,
    commentCount: 0,
    createTime: Date.now() - 11 * 60 * 60 * 1000,
    authorName: '校园同学'
  }
]

function escapeSql(value: string): string {
  return value.replace(/'/g, "''")
}

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
    rs.close()
    return null
  }

  async getCareerTalks(): Promise<CareerTalk[]> {
    const store = await this.helper.getStore()
    const sql = `SELECT * FROM ${TABLE_CAREER_TALK} ORDER BY date ASC`
    const rs = await store.querySql(sql)
    const list: CareerTalk[] = []
    while (rs.goToNextRow()) {
      list.push(this.rowToTalk(rs))
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
      list.push(this.rowToTalk(rs))
    }
    rs.close()
    return list
  }

  async getPosts(school?: string, viewerId?: string): Promise<CommunityPost[]> {
    if (!school) {
      return []
    }
    const store = await this.helper.getStore()
    const safeSchool = escapeSql(school)
    const sql = `
      SELECT p.*, u.real_name
      FROM ${TABLE_COMMUNITY_POST} p
      LEFT JOIN ${TABLE_USER} u ON u.user_id = p.user_id
      WHERE p.school = '${safeSchool}'
      ORDER BY p.create_time DESC
    `
    const rs = await store.querySql(sql)
    const likedSet: Set<string> = viewerId ? await this.loadReactionSet(TABLE_POST_LIKE, viewerId) : new Set<string>()
    const favoriteSet: Set<string> = viewerId ? await this.loadReactionSet(TABLE_POST_FAVORITE, viewerId) : new Set<string>()
    const posts: CommunityPost[] = []
    while (rs.goToNextRow()) {
      const postId = rs.getString(rs.getColumnIndex('post_id'))
      posts.push({
        postId: postId,
        userId: rs.getString(rs.getColumnIndex('user_id')),
        school: rs.getString(rs.getColumnIndex('school')),
        title: rs.getString(rs.getColumnIndex('title')),
        content: rs.getString(rs.getColumnIndex('content')),
        category: rs.getString(rs.getColumnIndex('category')) as 'interview' | 'companion' | 'discussion',
        isAnonymous: rs.getLong(rs.getColumnIndex('is_anonymous')) === 1,
        tags: JSON.parse(rs.getString(rs.getColumnIndex('tags')) || '[]') as string[],
        likeCount: rs.getLong(rs.getColumnIndex('like_count')),
        favoriteCount: rs.getLong(rs.getColumnIndex('favorite_count')),
        commentCount: rs.getLong(rs.getColumnIndex('comment_count')),
        createTime: rs.getLong(rs.getColumnIndex('create_time')),
        authorName: rs.getString(rs.getColumnIndex('real_name')),
        liked: likedSet.has(postId),
        favorited: favoriteSet.has(postId)
      })
    }
    rs.close()
    const mergedPosts: CommunityPost[] = []
    for (let i = 0; i < posts.length; i++) {
      mergedPosts.push(posts[i])
    }
    for (let i = 0; i < COMMUNITY_SEED_POSTS.length; i++) {
      const seedPost = COMMUNITY_SEED_POSTS[i]
      if (seedPost.school !== school) {
        continue
      }
      const exists = mergedPosts.some((item: CommunityPost) => item.postId === seedPost.postId)
      if (!exists) {
        mergedPosts.push({
          postId: seedPost.postId,
          userId: seedPost.userId,
          school: seedPost.school,
          title: seedPost.title,
          content: seedPost.content,
          category: seedPost.category,
          isAnonymous: seedPost.isAnonymous,
          tags: seedPost.tags,
          likeCount: seedPost.likeCount,
          favoriteCount: seedPost.favoriteCount,
          commentCount: seedPost.commentCount,
          createTime: seedPost.createTime,
          authorName: seedPost.authorName,
          liked: likedSet.has(seedPost.postId),
          favorited: favoriteSet.has(seedPost.postId)
        })
      }
    }
    mergedPosts.sort((a: CommunityPost, b: CommunityPost) => b.createTime - a.createTime)
    return mergedPosts
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
      favorite_count: post.favoriteCount,
      comment_count: post.commentCount,
      create_time: post.createTime
    }
    await store.insert(TABLE_COMMUNITY_POST, vb)
  }

  async updatePost(post: CommunityPost): Promise<void> {
    const store = await this.helper.getStore()
    const safePostId = escapeSql(post.postId)
    const safeUserId = escapeSql(post.userId)
    const sql = `
      UPDATE ${TABLE_COMMUNITY_POST}
      SET title = '${escapeSql(post.title)}',
          content = '${escapeSql(post.content)}',
          category = '${post.category}',
          is_anonymous = ${post.isAnonymous ? 1 : 0},
          tags = '${escapeSql(JSON.stringify(post.tags))}'
      WHERE post_id = '${safePostId}' AND user_id = '${safeUserId}'
    `
    await store.executeSql(sql)
  }

  async deletePost(postId: string, userId: string): Promise<void> {
    const store = await this.helper.getStore()
    const postPredicates = new relationalStore.RdbPredicates(TABLE_COMMUNITY_POST)
    postPredicates.equalTo('post_id', postId)
    postPredicates.equalTo('user_id', userId)
    await store.delete(postPredicates)

    const commentPredicates = new relationalStore.RdbPredicates(TABLE_POST_COMMENT)
    commentPredicates.equalTo('post_id', postId)
    await store.delete(commentPredicates)

    const likePredicates = new relationalStore.RdbPredicates(TABLE_POST_LIKE)
    likePredicates.equalTo('post_id', postId)
    await store.delete(likePredicates)

    const favoritePredicates = new relationalStore.RdbPredicates(TABLE_POST_FAVORITE)
    favoritePredicates.equalTo('post_id', postId)
    await store.delete(favoritePredicates)
  }

  async deleteComment(commentId: string, userId: string): Promise<void> {
    const store = await this.helper.getStore()
    const commentPredicates = new relationalStore.RdbPredicates(TABLE_POST_COMMENT)
    commentPredicates.equalTo('comment_id', commentId)
    commentPredicates.equalTo('user_id', userId)
    const rs = await store.query(commentPredicates)
    let postId: string = ''
    if (rs.goToFirstRow()) {
      postId = rs.getString(rs.getColumnIndex('post_id'))
    }
    rs.close()
    if (!postId) {
      return
    }
    await store.delete(commentPredicates)
    await this.updatePostCounter(postId, 'comment_count', -1)
  }

  async togglePostLike(postId: string, userId: string): Promise<boolean> {
    const store = await this.helper.getStore()
    const exists = await this.hasReaction(TABLE_POST_LIKE, userId, postId)
    if (exists) {
      const predicates = new relationalStore.RdbPredicates(TABLE_POST_LIKE)
      predicates.equalTo('user_id', userId)
      predicates.equalTo('post_id', postId)
      await store.delete(predicates)
      await this.updatePostCounter(postId, 'like_count', -1)
      return false
    }
    await store.insert(TABLE_POST_LIKE, {
      user_id: userId,
      post_id: postId,
      create_time: Date.now()
    })
    await this.updatePostCounter(postId, 'like_count', 1)
    return true
  }

  async togglePostFavorite(postId: string, userId: string): Promise<boolean> {
    const store = await this.helper.getStore()
    const exists = await this.hasReaction(TABLE_POST_FAVORITE, userId, postId)
    if (exists) {
      const predicates = new relationalStore.RdbPredicates(TABLE_POST_FAVORITE)
      predicates.equalTo('user_id', userId)
      predicates.equalTo('post_id', postId)
      await store.delete(predicates)
      await this.updatePostCounter(postId, 'favorite_count', -1)
      return false
    }
    await store.insert(TABLE_POST_FAVORITE, {
      user_id: userId,
      post_id: postId,
      create_time: Date.now()
    })
    await this.updatePostCounter(postId, 'favorite_count', 1)
    return true
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
    await this.updatePostCounter(comment.postId, 'comment_count', 1)
  }

  async getComments(postId: string): Promise<PostComment[]> {
    const store = await this.helper.getStore()
    const safePostId = escapeSql(postId)
    const sql = `
      SELECT c.*, u.real_name
      FROM ${TABLE_POST_COMMENT} c
      LEFT JOIN ${TABLE_USER} u ON u.user_id = c.user_id
      WHERE c.post_id = '${safePostId}'
      ORDER BY c.create_time ASC
    `
    const rs = await store.querySql(sql)
    const list: PostComment[] = []
    while (rs.goToNextRow()) {
      list.push({
        commentId: rs.getString(rs.getColumnIndex('comment_id')),
        postId: rs.getString(rs.getColumnIndex('post_id')),
        userId: rs.getString(rs.getColumnIndex('user_id')),
        content: rs.getString(rs.getColumnIndex('content')),
        isAnonymous: rs.getLong(rs.getColumnIndex('is_anonymous')) === 1,
        createTime: rs.getLong(rs.getColumnIndex('create_time')),
        authorName: rs.getString(rs.getColumnIndex('real_name'))
      })
    }
    rs.close()
    return list
  }

  async getCommentsByUser(userId: string): Promise<PostComment[]> {
    const store = await this.helper.getStore()
    const safeUserId = escapeSql(userId)
    const sql = `
      SELECT c.*, u.real_name, p.title AS post_title
      FROM ${TABLE_POST_COMMENT} c
      LEFT JOIN ${TABLE_USER} u ON u.user_id = c.user_id
      LEFT JOIN ${TABLE_COMMUNITY_POST} p ON p.post_id = c.post_id
      WHERE c.user_id = '${safeUserId}'
      ORDER BY c.create_time DESC
    `
    const rs = await store.querySql(sql)
    const list: PostComment[] = []
    while (rs.goToNextRow()) {
      list.push({
        commentId: rs.getString(rs.getColumnIndex('comment_id')),
        postId: rs.getString(rs.getColumnIndex('post_id')),
        userId: rs.getString(rs.getColumnIndex('user_id')),
        content: rs.getString(rs.getColumnIndex('content')),
        isAnonymous: rs.getLong(rs.getColumnIndex('is_anonymous')) === 1,
        createTime: rs.getLong(rs.getColumnIndex('create_time')),
        authorName: rs.getString(rs.getColumnIndex('real_name')),
        postTitle: rs.getString(rs.getColumnIndex('post_title'))
      })
    }
    rs.close()
    return list
  }

  async getFavoriteCountByUser(userId: string): Promise<number> {
    const store = await this.helper.getStore()
    const safeUserId = escapeSql(userId)
    const sql = `SELECT COUNT(*) AS favorite_count FROM ${TABLE_POST_FAVORITE} WHERE user_id = '${safeUserId}'`
    const rs = await store.querySql(sql)
    let count = 0
    if (rs.goToFirstRow()) {
      count = rs.getLong(0)
    }
    rs.close()
    return count
  }

  async getPostsByUser(userId: string, viewerId?: string): Promise<CommunityPost[]> {
    const store = await this.helper.getStore()
    const safeUserId = escapeSql(userId)
    const sql = `
      SELECT p.*, u.real_name
      FROM ${TABLE_COMMUNITY_POST} p
      LEFT JOIN ${TABLE_USER} u ON u.user_id = p.user_id
      WHERE p.user_id = '${safeUserId}'
      ORDER BY p.create_time DESC
    `
    return this.queryPostsBySql(sql, viewerId)
  }

  async getLikedPostsByUser(userId: string): Promise<CommunityPost[]> {
    const store = await this.helper.getStore()
    const safeUserId = escapeSql(userId)
    const sql = `
      SELECT p.*, u.real_name
      FROM ${TABLE_POST_LIKE} l
      INNER JOIN ${TABLE_COMMUNITY_POST} p ON p.post_id = l.post_id
      LEFT JOIN ${TABLE_USER} u ON u.user_id = p.user_id
      WHERE l.user_id = '${safeUserId}'
      ORDER BY l.create_time DESC
    `
    const posts = await this.queryPostsBySql(sql, userId)
    return this.mergeSeedReactionPosts(posts, userId, TABLE_POST_LIKE)
  }

  async getFavoritedPostsByUser(userId: string): Promise<CommunityPost[]> {
    const store = await this.helper.getStore()
    const safeUserId = escapeSql(userId)
    const sql = `
      SELECT p.*, u.real_name
      FROM ${TABLE_POST_FAVORITE} f
      INNER JOIN ${TABLE_COMMUNITY_POST} p ON p.post_id = f.post_id
      LEFT JOIN ${TABLE_USER} u ON u.user_id = p.user_id
      WHERE f.user_id = '${safeUserId}'
      ORDER BY f.create_time DESC
    `
    const posts = await this.queryPostsBySql(sql, userId)
    return this.mergeSeedReactionPosts(posts, userId, TABLE_POST_FAVORITE)
  }

  private async hasReaction(tableName: string, userId: string, postId: string): Promise<boolean> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(tableName)
    predicates.equalTo('user_id', userId)
    predicates.equalTo('post_id', postId)
    const rs = await store.query(predicates)
    const exists = rs.rowCount > 0
    rs.close()
    return exists
  }

  private async loadReactionSet(tableName: string, userId: string): Promise<Set<string>> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(tableName)
    predicates.equalTo('user_id', userId)
    const rs = await store.query(predicates)
    const result: Set<string> = new Set()
    while (rs.goToNextRow()) {
      result.add(rs.getString(rs.getColumnIndex('post_id')))
    }
    rs.close()
    return result
  }

  private async queryPostsBySql(sql: string, viewerId?: string): Promise<CommunityPost[]> {
    const store = await this.helper.getStore()
    const rs = await store.querySql(sql)
    const likedSet: Set<string> = viewerId ? await this.loadReactionSet(TABLE_POST_LIKE, viewerId) : new Set<string>()
    const favoriteSet: Set<string> = viewerId ? await this.loadReactionSet(TABLE_POST_FAVORITE, viewerId) : new Set<string>()
    const posts: CommunityPost[] = []
    while (rs.goToNextRow()) {
      const postId = rs.getString(rs.getColumnIndex('post_id'))
      posts.push({
        postId: postId,
        userId: rs.getString(rs.getColumnIndex('user_id')),
        school: rs.getString(rs.getColumnIndex('school')),
        title: rs.getString(rs.getColumnIndex('title')),
        content: rs.getString(rs.getColumnIndex('content')),
        category: rs.getString(rs.getColumnIndex('category')) as 'interview' | 'companion' | 'discussion',
        isAnonymous: rs.getLong(rs.getColumnIndex('is_anonymous')) === 1,
        tags: JSON.parse(rs.getString(rs.getColumnIndex('tags')) || '[]') as string[],
        likeCount: rs.getLong(rs.getColumnIndex('like_count')),
        favoriteCount: rs.getLong(rs.getColumnIndex('favorite_count')),
        commentCount: rs.getLong(rs.getColumnIndex('comment_count')),
        createTime: rs.getLong(rs.getColumnIndex('create_time')),
        authorName: rs.getString(rs.getColumnIndex('real_name')),
        liked: likedSet.has(postId),
        favorited: favoriteSet.has(postId)
      })
    }
    rs.close()
    return posts
  }

  private async mergeSeedReactionPosts(posts: CommunityPost[], userId: string, reactionTable: string): Promise<CommunityPost[]> {
    const reactionSet = await this.loadReactionSet(reactionTable, userId)
    const likedSet = await this.loadReactionSet(TABLE_POST_LIKE, userId)
    const favoriteSet = await this.loadReactionSet(TABLE_POST_FAVORITE, userId)
    const merged: CommunityPost[] = []
    for (let i = 0; i < posts.length; i++) {
      merged.push(posts[i])
    }
    for (let i = 0; i < COMMUNITY_SEED_POSTS.length; i++) {
      const seedPost = COMMUNITY_SEED_POSTS[i]
      if (!reactionSet.has(seedPost.postId)) {
        continue
      }
      const exists = merged.some((item: CommunityPost) => item.postId === seedPost.postId)
      if (exists) {
        continue
      }
      merged.push({
        postId: seedPost.postId,
        userId: seedPost.userId,
        school: seedPost.school,
        title: seedPost.title,
        content: seedPost.content,
        category: seedPost.category,
        isAnonymous: seedPost.isAnonymous,
        tags: seedPost.tags,
        likeCount: seedPost.likeCount,
        favoriteCount: seedPost.favoriteCount,
        commentCount: seedPost.commentCount,
        createTime: seedPost.createTime,
        authorName: seedPost.authorName,
        liked: likedSet.has(seedPost.postId),
        favorited: favoriteSet.has(seedPost.postId)
      })
    }
    merged.sort((a: CommunityPost, b: CommunityPost) => b.createTime - a.createTime)
    return merged
  }

  private async updatePostCounter(postId: string, columnName: string, delta: number): Promise<void> {
    const store = await this.helper.getStore()
    const safePostId = escapeSql(postId)
    const sql = `
      UPDATE ${TABLE_COMMUNITY_POST}
      SET ${columnName} = CASE WHEN ${columnName} + (${delta}) < 0 THEN 0 ELSE ${columnName} + (${delta}) END
      WHERE post_id = '${safePostId}'
    `
    await store.executeSql(sql)
  }

  private rowToTalk(row: relationalStore.ResultSet): CareerTalk {
    return {
      talkId: row.getString(row.getColumnIndex('talk_id')),
      companyId: row.getString(row.getColumnIndex('company_id')),
      companyName: row.getString(row.getColumnIndex('company_name')),
      title: row.getString(row.getColumnIndex('title')),
      date: row.getString(row.getColumnIndex('date')),
      time: row.getString(row.getColumnIndex('time')),
      location: row.getString(row.getColumnIndex('location')),
      isOnline: row.getLong(row.getColumnIndex('is_online')) === 1,
      onlineLink: row.getString(row.getColumnIndex('online_link'))
    }
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
        ? JSON.parse(row.getString(row.getColumnIndex('recruitment_plan'))) as RecruitmentPlan
        : undefined,
      alumniNetwork: row.getString(row.getColumnIndex('alumni_network'))
        ? JSON.parse(row.getString(row.getColumnIndex('alumni_network'))) as AlumniNode[]
        : undefined,
      careerTalks: []
    }
  }
}
