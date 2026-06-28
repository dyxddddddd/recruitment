import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { CommunityPost, PostComment } from '../../model/CompanyModel'
import { UserProfile } from '../../model/UserModel'
import { CompanyDao } from '../../service/CompanyDao'
import { ResumeDao } from '../../service/ResumeDao'
import { UserDao } from '../../service/UserDao'

@Component
export struct JobSeekerCommunityTab {
  @StorageLink('app_current_user') currentUser: UserProfile | null = null
  @StorageLink('app_is_guest') isGuest: boolean = true
  @StorageLink('app_is_logged_in') isLoggedIn: boolean = false

  @State posts: CommunityPost[] = []
  @State comments: PostComment[] = []
  @State myLikedPosts: CommunityPost[] = []
  @State myFavoritePosts: CommunityPost[] = []
  @State myPublishedPosts: CommunityPost[] = []
  @State myComments: PostComment[] = []
  @State selectedCategory: string = 'all'
  @State activeView: string = 'feed'
  @State activeMineTab: string = 'posts'  // 'posts' | 'liked' | 'favorites' | 'comments'
  @State showPostDialog: boolean = false
  @State showCommentSheet: boolean = false
  @State postTitle: string = ''
  @State postContent: string = ''
  @State postCategory: string = 'interview'
  @State postTags: string = ''
  @State isAnonymous: boolean = true
  @State commentText: string = ''
  @State commentAnonymous: boolean = true
  @State activePost: CommunityPost | null = null
  @State isLoading: boolean = false
  @State isSubmitting: boolean = false
  @State editingPostId: string = ''

  private companyDao: CompanyDao = new CompanyDao()
  private resumeDao: ResumeDao = new ResumeDao()
  private userDao: UserDao = new UserDao()

  aboutToAppear(): void {
    this.refreshCurrentUserAndSchool()
  }

  async refreshCurrentUserAndSchool(): Promise<void> {
    if (!this.currentUser?.userId) {
      await this.loadPosts()
      await this.loadMineData()
      return
    }
    const latestUser = await this.userDao.getUserById(this.currentUser.userId)
    const resume = await this.resumeDao.getResumeByUserId(this.currentUser.userId)
    const nextUser = latestUser || this.currentUser
    const userSchool = (nextUser.school || '').trim()
    const resumeSchool = (resume?.school || '').trim()
    if (!userSchool && resumeSchool) {
      nextUser.school = resumeSchool
      await this.userDao.updateUser(nextUser)
    }
    this.currentUser = nextUser
    AppState.currentUser = nextUser
    AppState.syncToStorage()
    await this.loadPosts()
    await this.loadMineData()
  }

  async loadPosts(): Promise<void> {
    if (!this.canBrowseCommunity()) {
      this.posts = []
      return
    }
    this.isLoading = true
    try {
      this.posts = await this.companyDao.getPosts(this.currentUser?.school, this.currentUser?.userId)
    } finally {
      this.isLoading = false
    }
  }

  async loadMineData(): Promise<void> {
    if (!this.currentUser?.userId) {
      this.myLikedPosts = []
      this.myFavoritePosts = []
      this.myPublishedPosts = []
      this.myComments = []
      return
    }
    this.myLikedPosts = await this.companyDao.getLikedPostsByUser(this.currentUser.userId)
    this.myFavoritePosts = await this.companyDao.getFavoritedPostsByUser(this.currentUser.userId)
    this.myPublishedPosts = await this.companyDao.getPostsByUser(this.currentUser.userId, this.currentUser.userId)
    this.myComments = await this.companyDao.getCommentsByUser(this.currentUser.userId)
  }

  async refreshPostsAndMine(postId?: string): Promise<void> {
    await this.loadPosts()
    await this.loadMineData()
    if (!postId) {
      return
    }
    const allPosts = this.collectAllVisiblePosts()
    for (let i = 0; i < allPosts.length; i++) {
      if (allPosts[i].postId === postId) {
        this.activePost = allPosts[i]
        break
      }
    }
  }

  async refreshComments(postId?: string): Promise<void> {
    const targetPostId = postId || this.activePost?.postId || ''
    if (!targetPostId) {
      this.comments = []
      return
    }
    this.comments = await this.companyDao.getComments(targetPostId)
  }

  collectAllVisiblePosts(): CommunityPost[] {
    const merged: CommunityPost[] = []
    const groups: CommunityPost[][] = [this.posts, this.myPublishedPosts, this.myLikedPosts, this.myFavoritePosts]
    for (let i = 0; i < groups.length; i++) {
      const group = groups[i]
      for (let j = 0; j < group.length; j++) {
        const item = group[j]
        let exists = false
        for (let k = 0; k < merged.length; k++) {
          if (merged[k].postId === item.postId) {
            exists = true
            break
          }
        }
        if (!exists) {
          merged.push(item)
        }
      }
    }
    return merged
  }

  canBrowseCommunity(): boolean {
    return !!this.currentUser && !this.currentUser.isGuest && !!this.currentUser.school
  }

  needsSchoolCompletion(): boolean {
    return !!this.currentUser && !this.currentUser.isGuest && !this.currentUser.school
  }

  filteredPosts(): CommunityPost[] {
    if (this.selectedCategory === 'all') {
      return this.posts
    }
    const result: CommunityPost[] = []
    for (let i = 0; i < this.posts.length; i++) {
      if (this.posts[i].category === this.selectedCategory) {
        result.push(this.posts[i])
      }
    }
    return result
  }

  categoryLabel(category: string): string {
    if (category === 'companion') {
      return '搭子'
    }
    if (category === 'discussion') {
      return '交流'
    }
    return '面经'
  }

  categoryTint(category: string): string {
    if (category === 'companion') {
      return '#4A90E2'
    }
    if (category === 'discussion') {
      return '#42B983'
    }
    return '#FF8A5B'
  }

  formatTime(timestamp: number): string {
    const diff = Date.now() - timestamp
    if (diff < 60 * 1000) {
      return '刚刚'
    }
    if (diff < 60 * 60 * 1000) {
      return `${Math.floor(diff / (60 * 1000))} 分钟前`
    }
    if (diff < 24 * 60 * 60 * 1000) {
      return `${Math.floor(diff / (60 * 60 * 1000))} 小时前`
    }
    return `${Math.floor(diff / (24 * 60 * 60 * 1000))} 天前`
  }

  resolvePostAuthor(post: CommunityPost): string {
    const anonymous = post.category === 'interview' && post.isAnonymous
    if (post.userId === this.currentUser?.userId) {
      return anonymous ? '我 · 匿名发布' : '我'
    }
    if (anonymous) {
      return '匿名同校同学'
    }
    return post.authorName && post.authorName.trim() ? `${post.authorName} 同学` : '同校同学'
  }

  resolveCommentAuthor(comment: PostComment): string {
    if (comment.userId === this.currentUser?.userId) {
      return comment.isAnonymous ? '我 · 匿名评论' : '我'
    }
    if (comment.isAnonymous) {
      return '匿名同校同学'
    }
    return comment.authorName && comment.authorName.trim() ? `${comment.authorName} 同学` : '同校同学'
  }

  canDeletePost(post: CommunityPost): boolean {
    return !!this.currentUser && post.userId === this.currentUser.userId
  }

  canDeleteComment(comment: PostComment): boolean {
    return !!this.currentUser && comment.userId === this.currentUser.userId
  }

  openPostDialog(): void {
    if (!this.canBrowseCommunity()) {
      this.promptLogin('进入社区发帖需要先登录并完善学校信息')
      return
    }
    this.editingPostId = ''
    this.postTitle = ''
    this.postContent = ''
    this.postCategory = 'interview'
    this.postTags = ''
    this.isAnonymous = true
    this.showPostDialog = true
  }

  openEditPostDialog(post: CommunityPost): void {
    if (!this.canDeletePost(post)) {
      return
    }
    this.editingPostId = post.postId
    this.postTitle = post.title
    this.postContent = post.content
    this.postCategory = post.category
    this.postTags = post.tags.join('，')
    this.isAnonymous = post.isAnonymous
    this.showPostDialog = true
  }

  closePostDialog(): void {
    this.showPostDialog = false
    this.editingPostId = ''
    this.postTitle = ''
    this.postContent = ''
    this.postCategory = 'interview'
    this.postTags = ''
    this.isAnonymous = true
  }

  async toggleLike(post: CommunityPost): Promise<void> {
    if (!this.currentUser) {
      this.promptLogin('点赞需要先登录')
      return
    }
    await this.companyDao.togglePostLike(post.postId, this.currentUser.userId)
    await this.refreshPostsAndMine(post.postId)
  }

  async toggleFavorite(post: CommunityPost): Promise<void> {
    if (!this.currentUser) {
      this.promptLogin('收藏需要先登录')
      return
    }
    await this.companyDao.togglePostFavorite(post.postId, this.currentUser.userId)
    await this.refreshPostsAndMine(post.postId)
  }

  async openComments(post: CommunityPost): Promise<void> {
    this.activePost = post
    await this.refreshComments(post.postId)
    await this.refreshPostsAndMine(post.postId)
    this.showCommentSheet = true
  }

  async publishPost(): Promise<void> {
    if (!this.currentUser?.school) {
      AlertDialog.show({ message: '请先完善学校信息后再发帖' })
      return
    }
    const title = this.postTitle.trim()
    const content = this.postContent.trim()
    if (!title || !content) {
      AlertDialog.show({ message: '标题和正文都需要填写' })
      return
    }
    const effectiveAnonymous = this.postCategory === 'interview' ? this.isAnonymous : false
    const existing = this.findPostById(this.editingPostId)
    const post: CommunityPost = {
      postId: this.editingPostId || `post_${Date.now()}`,
      userId: this.currentUser.userId,
      school: this.currentUser.school || '',
      title: title,
      content: content,
      category: this.postCategory as 'interview' | 'companion' | 'discussion',
      isAnonymous: effectiveAnonymous,
      tags: this.parseTags(this.postTags),
      likeCount: existing?.likeCount || 0,
      favoriteCount: existing?.favoriteCount || 0,
      commentCount: existing?.commentCount || 0,
      createTime: existing?.createTime || Date.now(),
      authorName: this.currentUser.realName || '',
      liked: existing?.liked || false,
      favorited: existing?.favorited || false
    }
    if (this.editingPostId) {
      await this.companyDao.updatePost(post)
      this.closePostDialog()
      await this.refreshPostsAndMine(post.postId)
      AlertDialog.show({ message: '帖子已更新' })
      return
    }
    await this.companyDao.insertPost(post)
    this.closePostDialog()
    await this.refreshPostsAndMine(post.postId)
    AlertDialog.show({ message: '帖子已发布' })
  }

  findPostById(postId: string): CommunityPost | null {
    if (!postId) {
      return null
    }
    const list = this.collectAllVisiblePosts()
    for (let i = 0; i < list.length; i++) {
      if (list[i].postId === postId) {
        return list[i]
      }
    }
    return null
  }

  parseTags(value: string): string[] {
    const raw = value.split(/[,\uFF0C/]/)
    const result: string[] = []
    for (let i = 0; i < raw.length; i++) {
      const item = raw[i].trim()
      if (item) {
        result.push(item)
      }
    }
    return result
  }

  async submitComment(): Promise<void> {
    if (!this.activePost || !this.currentUser) {
      return
    }
    const content = this.commentText.trim()
    if (!content) {
      AlertDialog.show({ message: '评论内容不能为空' })
      return
    }
    this.isSubmitting = true
    try {
      const comment: PostComment = {
        commentId: `comment_${Date.now()}`,
        postId: this.activePost.postId,
        userId: this.currentUser.userId,
        content: content,
        isAnonymous: this.commentAnonymous,
        createTime: Date.now(),
        authorName: this.currentUser.realName || ''
      }
      await this.companyDao.insertComment(comment)
      this.commentText = ''
      await this.refreshComments(this.activePost.postId)
      await this.refreshPostsAndMine(this.activePost.postId)
    } finally {
      this.isSubmitting = false
    }
  }

  async confirmDeletePost(post: CommunityPost): Promise<void> {
    if (!this.currentUser) {
      return
    }
    await this.companyDao.deletePost(post.postId, this.currentUser.userId)
    if (this.activePost?.postId === post.postId) {
      this.showCommentSheet = false
      this.activePost = null
      this.comments = []
    }
    await this.refreshPostsAndMine()
  }

  async confirmDeleteComment(comment: PostComment): Promise<void> {
    if (!this.currentUser) {
      return
    }
    await this.companyDao.deleteComment(comment.commentId, this.currentUser.userId)
    await this.refreshComments(comment.postId)
    await this.refreshPostsAndMine(comment.postId)
  }

  promptLogin(message: string): void {
    if (this.needsSchoolCompletion()) {
      AlertDialog.show({
        title: '完善学校信息',
        message: `${message}，是否前往完善？`,
        primaryButton: {
          value: '去完善',
          action: () => router.pushUrl({ url: AppConstants.ROUTE_RESUME_EDIT })
        },
        secondaryButton: {
          value: '取消',
          action: () => {}
        }
      })
      return
    }
    AlertDialog.show({
      title: '登录提示',
      message: `${message}，是否前往登录？`,
      primaryButton: {
        value: '去登录',
        action: () => router.pushUrl({ url: AppConstants.ROUTE_LOGIN })
      },
      secondaryButton: {
        value: '取消',
        action: () => {}
      }
    })
  }

  build() {
    Stack({ alignContent: Alignment.Bottom }) {
      Column() {
        this.HeaderBuilder()
        if (this.canBrowseCommunity()) {
          this.ViewSwitchRow()
          if (this.activeView === 'feed') {
            this.FeedBuilder()
          } else {
            this.MyCommunityBuilder()
          }
        } else {
          this.LockedStateBuilder()
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor('#F6F8FC')
      .bindSheet($$this.showCommentSheet, this.CommentSheetBuilder(), { dragBar: true, showClose: true, height: 720 })

      if (this.showPostDialog) {
        this.DialogMask(() => this.closePostDialog())
        this.PostSheetBuilder()
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#F6F8FC')
  }

  @Builder
  DialogMask(onClose: () => void) {
    Stack({ alignContent: Alignment.Bottom }) {
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#66000000')
        .onClick(() => onClose())
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  HeaderBuilder() {
    Column() {
      Row() {
        Column() {
          Text('同校社区')
            .fontSize(24)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
          Text('只有同校学生可见，适合匿名交流面经、求助和找搭子。')
            .fontSize(11)
            .fontColor('rgba(255,255,255,0.82)')
            .margin({ top: 8 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Button('发帖')
          .height(34)
          .fontSize(13)
          .backgroundColor('#FFFFFF')
          .fontColor('#2E5BFF')
          .borderRadius(18)
          .padding({ left: 16, right: 16 })
          .onClick(() => this.openPostDialog())
      }
      .width('100%')

      Row() {
        this.HeaderChip('同校可见')
        this.HeaderChip('支持点赞收藏')
      }
      .width('100%')
      .margin({ top: 16 })
    }
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 18 })
    .linearGradient({
      angle: 135,
      colors: [['#3C78F0', 0], ['#59B4FF', 1]]
    })
  }

  @Builder
  HeaderChip(text: string) {
    Text(text)
      .fontSize(11)
      .fontColor('#FFFFFF')
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .backgroundColor('rgba(255,255,255,0.16)')
      .borderRadius(14)
      .margin({ right: 8 })
  }

  @Builder
  ViewSwitchRow() {
    Row() {
      this.ViewSwitchChip('校园社区', 'feed')
      this.ViewSwitchChip('我的', 'mine')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 2 })
    .backgroundColor('#F6F8FC')
  }

  @Builder
  ViewSwitchChip(label: string, view: string) {
    Text(label)
      .fontSize(13)
      .fontWeight(this.activeView === view ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.activeView === view ? '#FFFFFF' : '#667085')
      .padding({ left: 16, right: 16, top: 10, bottom: 10 })
      .backgroundColor(this.activeView === view ? '#2E5BFF' : '#FFFFFF')
      .borderRadius(18)
      .margin({ right: 10 })
      .shadow(this.activeView === view ? { radius: 8, color: '#162E5BFF', offsetY: 3 } : { radius: 0 })
      .onClick(async () => {
        this.activeView = view
        if (view === 'mine') {
          await this.loadMineData()
        }
      })
  }

  @Builder
  FeedBuilder() {
    Column() {
      this.CategoryRow()
      if (this.isLoading) {
        Column() {
          LoadingProgress()
            .width(28)
            .height(28)
            .color(AppConstants.COLOR_PRIMARY)
          Text('正在刷新你们学校的帖子...')
            .fontSize(12)
            .fontColor('#8B95A1')
            .margin({ top: 10 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else if (this.filteredPosts().length === 0) {
        this.EmptyFeedBuilder()
      } else {
        Scroll() {
          Column() {
            ForEach(this.filteredPosts(), (post: CommunityPost) => {
              this.PostCardBuilder(post)
            })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 12, bottom: 18 })
        }
        .layoutWeight(1)
        .width('100%')
        .backgroundColor('#F6F8FC')
      }
    }
    .width('100%')
    .layoutWeight(1)
  }

  @Builder
  CategoryRow() {
    Row() {
      this.CategoryChipBuilder('全部', 'all')
      this.CategoryChipBuilder('面经', 'interview')
      this.CategoryChipBuilder('搭子', 'companion')
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 8 })
    .backgroundColor('#F6F8FC')
  }

  @Builder
  CategoryChipBuilder(label: string, category: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.selectedCategory === category ? '#FFFFFF' : '#667085')
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(this.selectedCategory === category ? '#2E5BFF' : '#FFFFFF')
      .borderRadius(18)
      .margin({ right: 10 })
      .onClick(() => { this.selectedCategory = category })
  }

  @Builder
  LockedStateBuilder() {
    Column() {
      Text('校园匿名社区仅对同校同学开放')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
      Text('登录后补充学校信息，就能看到只属于你们学校的面经、求助和搭子帖。')
        .fontSize(12)
        .fontColor('#8B95A1')
        .textAlign(TextAlign.Center)
        .lineHeight(20)
        .margin({ top: 10 })
      Button(this.needsSchoolCompletion() ? '去完善学校' : '去登录 / 完善学校')
        .height(40)
        .fontSize(14)
        .backgroundColor('#2E5BFF')
        .fontColor('#FFFFFF')
        .borderRadius(20)
        .padding({ left: 22, right: 22 })
        .margin({ top: 18 })
        .onClick(() => {
          if (this.needsSchoolCompletion()) {
            router.pushUrl({ url: AppConstants.ROUTE_RESUME_EDIT })
          } else {
            router.pushUrl({ url: AppConstants.ROUTE_LOGIN })
          }
        })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 32, right: 32 })
    .backgroundColor('#F6F8FC')
  }

  @Builder
  EmptyFeedBuilder() {
    Column() {
      Text('你们学校的社区还很新')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
      Text('发一条面经或搭子帖，成为第一位留下内容的同学。')
        .fontSize(12)
        .fontColor('#8B95A1')
        .textAlign(TextAlign.Center)
        .lineHeight(20)
        .margin({ top: 10 })
      Button('发布第一条帖子')
        .height(40)
        .fontSize(14)
        .backgroundColor('#2E5BFF')
        .fontColor('#FFFFFF')
        .borderRadius(20)
        .padding({ left: 22, right: 22 })
        .margin({ top: 18 })
        .onClick(() => this.openPostDialog())
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 32, right: 32 })
  }

  @Builder
  MineTabBar() {
    Scroll() {
      Row() {
        this.MineTabChip('帖子', 'posts', this.myPublishedPosts.length)
        this.MineTabChip('点赞', 'liked', this.myLikedPosts.length)
        this.MineTabChip('收藏', 'favorites', this.myFavoritePosts.length)
        this.MineTabChip('评论', 'comments', this.myComments.length)
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 4 })
    .backgroundColor('#F6F8FC')
  }

  @Builder
  MineTabChip(label: string, tab: string, count: number) {
    Column() {
      Text(`${label} ${count}`)
        .fontSize(12)
        .fontWeight(this.activeMineTab === tab ? FontWeight.Bold : FontWeight.Medium)
        .fontColor(this.activeMineTab === tab ? '#2E5BFF' : '#667085')
        .padding({ left: 14, right: 14, top: 9, bottom: 9 })
        .backgroundColor(this.activeMineTab === tab ? '#EEF3FF' : '#FFFFFF')
        .borderRadius(18)
        .margin({ right: 8 })
        .onClick(() => { this.activeMineTab = tab })
    }
  }

  @Builder
  MyCommunityBuilder() {
    Column() {
      this.MineTabBar()
      Column() {
        if (this.activeMineTab === 'posts') {
          if (this.myPublishedPosts.length === 0) {
            this.MineEmptyState('帖子', '发过的话题、搭子、面经都会出现在这里')
          } else {
            Scroll() {
              Column() {
                ForEach(this.myPublishedPosts, (post: CommunityPost) => {
                  this.PostCardBuilder(post)
                })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 10, bottom: 24 })
            }
          }
        } else if (this.activeMineTab === 'liked') {
          if (this.myLikedPosts.length === 0) {
            this.MineEmptyState('点赞', '点赞的内容会出现在这里，方便以后回顾')
          } else {
            Scroll() {
              Column() {
                ForEach(this.myLikedPosts, (post: CommunityPost) => {
                  this.PostCardBuilder(post)
                })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 10, bottom: 24 })
            }
          }
        } else if (this.activeMineTab === 'favorites') {
          if (this.myFavoritePosts.length === 0) {
            this.MineEmptyState('收藏', '收藏的内容会出现在这里，长期保留')
          } else {
            Scroll() {
              Column() {
                ForEach(this.myFavoritePosts, (post: CommunityPost) => {
                  this.PostCardBuilder(post)
                })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 10, bottom: 24 })
            }
          }
        } else {
          // comments
          if (this.myComments.length === 0) {
            this.MineEmptyState('评论', '你发过的评论会出现在这里')
          } else {
            Scroll() {
              Column() {
                ForEach(this.myComments, (comment: PostComment) => {
                  this.MyCommentCardBuilder(comment)
                })
              }
              .width('100%')
              .padding({ left: 16, right: 16, top: 10, bottom: 24 })
            }
          }
        }
      }
    }
    .width('100%')
    .layoutWeight(1)
    .backgroundColor('#F6F8FC')
  }

  @Builder
  MineEmptyState(title: string, subtitle: string) {
    Column() {
      Text(title)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
      Text(subtitle)
        .fontSize(12)
        .fontColor('#8B95A1')
        .textAlign(TextAlign.Center)
        .lineHeight(20)
        .margin({ top: 10 })
    }
    .width('100%')
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ left: 32, right: 32 })
  }

  @Builder
  MyCommentCardBuilder(comment: PostComment) {
    Column() {
      if (comment.postTitle) {
        Row() {
          Text('回复：' + comment.postTitle)
            .fontSize(11)
            .fontColor('#98A2B3')
            .maxLines(1)
            .ellipsisMode(EllipsisMode.END)
          Blank()
          Text(this.formatTime(comment.createTime))
            .fontSize(11)
            .fontColor('#98A2B3')
        }
        .width('100%')
        .margin({ bottom: 10 })
      }
      Text(comment.content)
        .fontSize(14)
        .fontColor('#1A1A1A')
        .lineHeight(22)
        .width('100%')
      Row() {
        Text(this.resolveCommentAuthor(comment))
          .fontSize(11)
          .fontColor('#667085')
        Blank()
        Text('删除')
          .fontSize(11)
          .fontColor('#FF4D4F')
          .onClick(() => this.confirmDeleteComment(comment))
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(20)
    .shadow({ radius: 12, color: '#12000000', offsetY: 5 })
    .margin({ bottom: 14 })
  }

  @Builder
  PostCardBuilder(post: CommunityPost) {
    Column() {
      Row() {
        Text(this.categoryLabel(post.category))
          .fontSize(11)
          .fontColor('#FFFFFF')
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor(this.categoryTint(post.category))
          .borderRadius(14)
        Text(this.resolvePostAuthor(post))
          .fontSize(11)
          .fontColor('#667085')
          .margin({ left: 8 })
        Blank()
        Text(this.formatTime(post.createTime))
          .fontSize(11)
          .fontColor('#98A2B3')
      }
      .width('100%')

      Text(post.title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor('#1A1A1A')
        .maxLines(2)
        .margin({ top: 14 })
        .width('100%')

      Text(post.content)
        .fontSize(13)
        .fontColor('#4C5665')
        .lineHeight(20)
        .maxLines(3)
        .margin({ top: 10 })
        .width('100%')

      if (post.tags.length > 0) {
        Flex({ wrap: FlexWrap.Wrap }) {
          ForEach(post.tags, (tag: string) => {
            Text(`#${tag}`)
              .fontSize(11)
              .fontColor('#2E5BFF')
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor('#EEF4FF')
              .borderRadius(14)
              .margin({ right: 8, bottom: 8 })
          })
        }
        .width('100%')
        .margin({ top: 12 })
      }

      Row() {
        if (this.canDeletePost(post)) {
          Text('编辑')
            .fontSize(11)
            .fontColor('#2E5BFF')
            .margin({ right: 10 })
            .onClick(() => this.openEditPostDialog(post))
          Text('删除')
            .fontSize(11)
            .fontColor('#FF4D4F')
            .onClick(() => this.confirmDeletePost(post))
        }
        Blank()
        this.ActionButton(post.liked === true ? '已赞' : '点赞', `${post.likeCount}`, post.liked === true ? '#FF6B6B' : '#667085', () => {
          this.toggleLike(post)
        })
        this.ActionButton(post.favorited === true ? '已藏' : '收藏', `${post.favoriteCount}`, post.favorited === true ? '#FF9D42' : '#667085', () => {
          this.toggleFavorite(post)
        })
        this.ActionButton('评论', `${post.commentCount}`, '#667085', () => {
          this.openComments(post)
        })
      }
      .width('100%')
      .margin({ top: 10 })
    }
    .width('100%')
    .padding(16)
    .backgroundColor('#FFFFFF')
    .borderRadius(22)
    .shadow({ radius: 14, color: '#12000000', offsetY: 6 })
    .margin({ bottom: 14 })
  }

  @Builder
  ActionButton(label: string, count: string, color: string, onClick: () => void) {
    Row() {
      Text(label)
        .fontSize(11)
        .fontColor(color)
      Text(` ${count}`)
        .fontSize(11)
        .fontColor(color)
    }
    .padding({ left: 10, right: 10, top: 6, bottom: 6 })
    .backgroundColor('#F8FAFD')
    .borderRadius(14)
    .margin({ left: 8 })
    .onClick(onClick)
  }

  @Builder
  PostSheetBuilder() {
    Column() {
      Row() {
        Button('取消')
          .fontSize(14)
          .backgroundColor('transparent')
          .fontColor('#98A2B3')
          .onClick(() => this.closePostDialog())
        Blank()
        Text(this.editingPostId ? '编辑帖子' : '发布帖子')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        Blank()
        Button(this.editingPostId ? '保存' : '发布')
          .fontSize(14)
          .backgroundColor('#2E5BFF')
          .fontColor('#FFFFFF')
          .borderRadius(16)
          .padding({ left: 16, right: 16, top: 5, bottom: 5 })
          .enabled(this.postTitle.trim().length > 0 && this.postContent.trim().length > 0)
          .onClick(() => this.publishPost())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Scroll() {
        Column() {
          this.FormBlock('帖子类型')
          Row() {
            this.PostTypeButton('interview', '匿名面经')
            this.PostTypeButton('companion', '找搭子')
            this.PostTypeButton('discussion', '交流')
          }
          .width('100%')

          this.FormBlock('标题')
          TextInput({ text: this.postTitle, placeholder: '用一句话概括你的内容' })
            .width('100%')
            .height(44)
            .fontSize(14)
            .backgroundColor('#F6F8FC')
            .borderRadius(14)
            .padding({ left: 14, right: 14 })
            .onChange((value: string) => { this.postTitle = value })

          this.FormBlock('正文')
          TextArea({ text: this.postContent, placeholder: '把你的问题、面经或招募需求描述清楚。' })
            .width('100%')
            .height(180)
            .fontSize(14)
            .backgroundColor('#F6F8FC')
            .borderRadius(18)
            .padding(14)
            .onChange((value: string) => { this.postContent = value })

          this.FormBlock('标签')
          TextInput({ text: this.postTags, placeholder: '例如：字节、前端、实习，用逗号分隔' })
            .width('100%')
            .height(44)
            .fontSize(13)
            .backgroundColor('#F6F8FC')
            .borderRadius(14)
            .padding({ left: 14, right: 14 })
            .onChange((value: string) => { this.postTags = value })

          if (this.postCategory === 'interview') {
            Row() {
              Column() {
                Text('匿名发布')
                  .fontSize(14)
                  .fontWeight(FontWeight.Medium)
                  .fontColor('#1A1A1A')
                Text('面经默认支持匿名展示。')
                  .fontSize(11)
                  .fontColor('#98A2B3')
                  .margin({ top: 4 })
              }
              .alignItems(HorizontalAlign.Start)
              Blank()
              Toggle({ type: ToggleType.Switch, isOn: this.isAnonymous })
                .selectedColor('#2E5BFF')
                .onChange((value: boolean) => { this.isAnonymous = value })
            }
            .width('100%')
            .padding(14)
            .backgroundColor('#FFFFFF')
            .borderRadius(18)
            .margin({ top: 18 })
          }
        }
        .padding(16)
      }
      .layoutWeight(1)
    }
    .width('100%')
    .height('78%')
    .backgroundColor('#FFFFFF')
    .borderRadius({ topLeft: 24, topRight: 24 })
  }

  @Builder
  FormBlock(title: string) {
    Text(title)
      .fontSize(14)
      .fontWeight(FontWeight.Medium)
      .fontColor('#1A1A1A')
      .alignSelf(ItemAlign.Start)
      .margin({ top: 18, bottom: 10 })
  }

  @Builder
  PostTypeButton(category: string, label: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.postCategory === category ? '#FFFFFF' : '#667085')
      .padding({ left: 14, right: 14, top: 8, bottom: 8 })
      .backgroundColor(this.postCategory === category ? '#2E5BFF' : '#F6F8FC')
      .borderRadius(16)
      .margin({ right: 10 })
      .onClick(() => {
        this.postCategory = category
        this.isAnonymous = category === 'interview'
      })
  }

  @Builder
  CommentSheetBuilder() {
    Column() {
      Row() {
        Blank()
        Text('帖子评论')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        Blank()
        Button(this.isSubmitting ? '发送中' : '发送')
          .fontSize(14)
          .backgroundColor('#2E5BFF')
          .fontColor('#FFFFFF')
          .borderRadius(16)
          .padding({ left: 16, right: 16, top: 5, bottom: 5 })
          .enabled(this.commentText.trim().length > 0 && !this.isSubmitting)
          .onClick(() => this.submitComment())
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })

      Scroll() {
        Column() {
          if (this.activePost) {
            this.PostCardBuilder(this.activePost)
          }

          Row() {
            Text('全部评论')
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor('#1A1A1A')
            Blank()
            Text(`${this.comments.length} 条`)
              .fontSize(12)
              .fontColor('#98A2B3')
          }
          .width('100%')
          .margin({ bottom: 10 })

          if (this.comments.length === 0) {
            Column() {
              Text('还没有评论')
                .fontSize(14)
                .fontColor('#667085')
              Text('你可以成为第一位回复的同学。')
                .fontSize(11)
                .fontColor('#98A2B3')
                .margin({ top: 8 })
            }
            .width('100%')
            .padding({ top: 24, bottom: 24 })
            .backgroundColor('#FFFFFF')
            .borderRadius(18)
          } else {
            ForEach(this.comments, (comment: PostComment) => {
              Column() {
                Row() {
                  Text(this.resolveCommentAuthor(comment))
                    .fontSize(12)
                    .fontWeight(FontWeight.Medium)
                    .fontColor('#1A1A1A')
                  Blank()
                  if (this.canDeleteComment(comment)) {
                    Text('删除')
                      .fontSize(11)
                      .fontColor('#FF4D4F')
                      .margin({ right: 10 })
                      .onClick(() => this.confirmDeleteComment(comment))
                  }
                  Text(this.formatTime(comment.createTime))
                    .fontSize(11)
                    .fontColor('#98A2B3')
                }
                .width('100%')

                Text(comment.content)
                  .fontSize(13)
                  .fontColor('#4C5665')
                  .lineHeight(20)
                  .margin({ top: 10 })
                  .width('100%')
              }
              .width('100%')
              .padding(14)
              .backgroundColor('#FFFFFF')
              .borderRadius(18)
              .margin({ bottom: 10 })
            })
          }
        }
        .padding(16)
      }
      .layoutWeight(1)
      .backgroundColor('#F6F8FC')

      Row() {
        TextInput({ text: this.commentText, placeholder: '写下你的评论...' })
          .layoutWeight(1)
          .height(42)
          .fontSize(13)
          .backgroundColor('#F6F8FC')
          .borderRadius(20)
          .padding({ left: 14, right: 14 })
          .onChange((value: string) => { this.commentText = value })
        Toggle({ type: ToggleType.Switch, isOn: this.commentAnonymous })
          .margin({ left: 12, right: 8 })
          .selectedColor('#2E5BFF')
          .onChange((value: boolean) => { this.commentAnonymous = value })
        Text('匿名')
          .fontSize(12)
          .fontColor('#667085')
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 18 })
      .backgroundColor('#FFFFFF')
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }
}
