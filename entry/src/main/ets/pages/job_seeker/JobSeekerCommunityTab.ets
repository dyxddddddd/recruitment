// 求职者 - 社区广场页（Tab c: 社区 + 匿名面经 + 求职搭子）
// 含：分类筛选 | 发布弹窗 | 匿名交流 | 点赞/评论

import { router } from '@kit.ArkUI'
import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { CommunityPost, PostComment } from '../../model/CompanyModel'
import { CompanyDao } from '../../service/CompanyDao'

@Component
export struct JobSeekerCommunityTab {
  @State posts: CommunityPost[] = []
  @State selectedCategory: string = 'all'
  @State showPostDialog: boolean = false
  @State postTitle: string = ''
  @State postContent: string = ''
  @State postCategory: string = 'discussion'
  @State isAnonymous: boolean = true
  @State postTags: string = ''
  @State likedPosts: Set<string> = new Set()
  @State activePost: CommunityPost | null = null
  @State showCommentSheet: boolean = false
  @State commentText: string = ''
  private companyDao: CompanyDao = new CompanyDao()

  aboutToAppear(): void {
    this.loadPosts()
  }

  async loadPosts(): Promise<void> {
    const school = AppState.currentUser?.school
    this.posts = await this.companyDao.getPosts(school)
  }

  build() {
    Column() {
      // 顶部标题
      Row() {
        Text('同学互助与面经传承')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        Blank()
        Button('发布')
          .fontSize(12)
          .height(30)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .fontColor('#FFFFFF')
          .borderRadius(15)
          .padding({ left: 14, right: 14 })
          .onClick(() => {
            if (AppState.isGuest) {
              AlertDialog.show({
                title: '登录提示',
                message: '登录后即可发布帖子',
                primaryButton: { value: '去登录', action: () => router.pushUrl({ url: AppConstants.ROUTE_LOGIN }) },
                secondaryButton: { value: '取消', action: () => {} }
              })
              return
            }
            this.showPostDialog = true
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 8 })

      // 分类筛选
      Row() {
        this.CategoryChipBuilder('全部', 'all')
        this.CategoryChipBuilder('面经', 'interview')
        this.CategoryChipBuilder('找搭子', 'companion')
        this.CategoryChipBuilder('讨论', 'discussion')
      }
      .width('100%')
      .padding({ left: 16, right: 16, bottom: 8 })

      Divider().height(1).color('#F0F0F0')

      // 帖子列表
      if (this.posts.length === 0) {
        Column() {
          Text('💬')
            .fontSize(48)
            .margin({ bottom: 12 })
          Text('暂无帖子')
            .fontSize(14)
            .fontColor('#999999')
          Text('分享面经或找到求职搭子')
            .fontSize(12)
            .fontColor('#CCCCCC')
            .margin({ top: 4 })
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      } else {
        List() {
          ForEach(this.filteredPosts(), (post: CommunityPost) => {
            ListItem() {
              this.PostCardBuilder(post)
            }
          })
        }
        .width('100%')
        .layoutWeight(1)
        .padding({ left: 16, right: 16 })
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
    .bindSheet($$this.showPostDialog, this.PostSheetBuilder(), {
      dragBar: true,
      showClose: true,
      height: 480
    })
    .bindSheet($$this.showCommentSheet, this.CommentSheetBuilder(), {
      dragBar: true,
      showClose: true,
      height: 400
    })
  }

  @Builder
  CategoryChipBuilder(label: string, category: string) {
    Text(label)
      .fontSize(12)
      .fontColor(this.selectedCategory === category ? '#FFFFFF' : '#666666')
      .backgroundColor(this.selectedCategory === category ? AppConstants.COLOR_PRIMARY : '#F5F5F5')
      .borderRadius(14)
      .padding({ left: 14, right: 14, top: 6, bottom: 6 })
      .margin({ right: 8 })
      .onClick(() => { this.selectedCategory = category })
  }

  filteredPosts(): CommunityPost[] {
    const school = AppState.currentUser?.school
    const visiblePosts = school
      ? this.posts
      : this.posts.filter((post: CommunityPost) => post.category !== 'interview')
    if (this.selectedCategory === 'all') {
      return visiblePosts
    }
    return visiblePosts.filter(p => p.category === this.selectedCategory)
  }

  @Builder
  PostCardBuilder(post: CommunityPost) {
    Column() {
      Row() {
        Text(post.isAnonymous ? '匿名同学' : '同学')
          .fontSize(12)
          .fontColor('#999999')
        Text(` · ${post.school}`)
          .fontSize(11)
          .fontColor('#CCCCCC')
        Blank()
        Text(this.formatTime(post.createTime))
          .fontSize(11)
          .fontColor('#CCCCCC')
      }
      .width('100%')
      .margin({ bottom: 8 })

      Text(post.title)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .fontColor('#1A1A1A')
        .maxLines(2)
        .margin({ bottom: 6 })

      Text(post.content)
        .fontSize(13)
        .fontColor('#666666')
        .maxLines(3)
        .margin({ bottom: 10 })

      Row() {
        ForEach(post.tags, (tag: string) => {
          Text(`#${tag}`)
            .fontSize(10)
            .fontColor('#4A90D9')
            .margin({ right: 8 })
        })
        Blank()
        Row() {
          // 点赞按钮
          Column() {
            Image($r('sys.symbol.heart'))
              .width(14)
              .height(14)
              .fillColor(this.likedPosts.has(post.postId) ? '#FF4D4F' : '#CCCCCC')
            Text(`${post.likeCount}`)
              .fontSize(11)
              .fontColor(this.likedPosts.has(post.postId) ? '#FF4D4F' : '#999999')
              .margin({ left: 2 })
          }
          .onClick(() => this.toggleLike(post))
          .margin({ right: 16 })

          // 评论按钮
          Column() {
            Text('💬')
              .fontSize(14)
            Text(`${post.commentCount}`)
              .fontSize(11)
              .fontColor('#999999')
              .margin({ left: 2 })
          }
          .onClick(() => this.openComments(post))
        }
      }
      .width('100%')
    }
    .width('100%')
    .padding({ top: 14, bottom: 14 })
    .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })
  }

  formatTime(timestamp: number): string {
    const now = Date.now()
    const diff = now - timestamp
    if (diff < 60000) return '刚刚'
    if (diff < 3600000) return `${Math.floor(diff / 60000)}分钟前`
    if (diff < 86400000) return `${Math.floor(diff / 3600000)}小时前`
    return `${Math.floor(diff / 86400000)}天前`
  }

  // 点赞
  toggleLike(post: CommunityPost): void {
    if (this.likedPosts.has(post.postId)) {
      this.likedPosts.delete(post.postId)
      post.likeCount--
    } else {
      this.likedPosts.add(post.postId)
      post.likeCount++
    }
    // 强制刷新列表
    this.posts = [...this.posts]
  }

  // 打开评论区
  openComments(post: CommunityPost): void {
    this.activePost = post
    this.showCommentSheet = true
  }

  // 发布帖子弹窗
  @Builder
  PostSheetBuilder() {
    Column() {
      Row() {
        Button('取消')
          .fontSize(14)
          .backgroundColor('transparent')
          .fontColor('#999999')
          .onClick(() => { this.showPostDialog = false })
        Blank()
        Text('发布帖子')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
        Blank()
        Button('发布')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .fontColor('#FFFFFF')
          .borderRadius(16)
          .padding({ left: 16, right: 16, top: 4, bottom: 4 })
          .enabled(!!this.postTitle.trim() && !!this.postContent.trim())
          .onClick(async () => {
            const newPost: CommunityPost = {
              postId: `post_${Date.now()}`,
              userId: AppState.currentUser?.userId || '',
              school: AppState.currentUser?.school || '本校',
              title: this.postTitle.trim(),
              content: this.postContent.trim(),
              category: this.postCategory as 'interview' | 'companion' | 'discussion',
              isAnonymous: this.isAnonymous,
              tags: this.postTags.split(/[,，]/).map(t => t.trim()).filter(t => t),
              likeCount: 0,
              commentCount: 0,
              createTime: Date.now()
            }
            await this.companyDao.insertPost(newPost)
            this.posts.unshift(newPost)
            this.showPostDialog = false
            this.postTitle = ''
            this.postContent = ''
            this.postTags = ''
            AlertDialog.show({ message: '发布成功！' })
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })

      Scroll() {
        Column() {
          // 分类选择
          Row() {
            Text('分类')
              .fontSize(14)
              .fontColor('#666666')
              .width(60)
            Row() {
              ForEach(['interview', 'companion', 'discussion'], (cat: string) => {
                Button(cat === 'interview' ? '面经' : cat === 'companion' ? '找搭子' : '讨论')
                  .fontSize(12)
                  .height(30)
                  .backgroundColor(this.postCategory === cat ? AppConstants.COLOR_PRIMARY : '#F5F5F5')
                  .fontColor(this.postCategory === cat ? '#FFFFFF' : '#666666')
                  .borderRadius(15)
                  .padding({ left: 14, right: 14 })
                  .margin({ right: 8 })
                  .onClick(() => { this.postCategory = cat })
              })
            }
          }
          .width('100%')
          .padding(12)
          .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })

          // 匿名开关
          Row() {
            Text('匿名发布')
              .fontSize(14)
              .fontColor('#666666')
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.isAnonymous })
              .selectedColor(AppConstants.COLOR_PRIMARY)
              .onChange((v: boolean) => { this.isAnonymous = v })
          }
          .width('100%')
          .padding(12)
          .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })

          TextInput({ placeholder: '标题（必填）', text: this.postTitle })
            .width('100%')
            .height(40)
            .fontSize(14)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .padding(12)
            .onChange((v: string) => { this.postTitle = v })

          TextArea({ placeholder: '分享你的面经/求职心得/找搭子...（必填）', text: this.postContent })
            .width('100%')
            .height(100)
            .fontSize(14)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .padding(12)
            .margin({ top: 8 })
            .onChange((v: string) => { this.postContent = v })

          TextInput({ placeholder: '标签（多个用逗号分隔，如：腾讯,后端,面试' })
            .width('100%')
            .height(40)
            .fontSize(13)
            .backgroundColor('#F5F5F5')
            .borderRadius(8)
            .padding(12)
            .margin({ top: 8 })
            .onChange((v: string) => { this.postTags = v })
        }
        .padding(16)
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor('#FFFFFF')
  }

  // ---- 评论弹窗 ----
  @Builder
  CommentSheetBuilder() {
    Column() {
      Row() {
        Button('取消')
          .fontSize(14)
          .backgroundColor('transparent')
          .fontColor('#999999')
          .onClick(() => { this.showCommentSheet = false })
        Blank()
        Text(this.activePost?.title || '评论区')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor('#1A1A1A')
          .maxLines(1)
          .layoutWeight(1)
          .textAlign(TextAlign.Center)
        Blank()
        Button('发送')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .backgroundColor(AppConstants.COLOR_PRIMARY)
          .fontColor('#FFFFFF')
          .borderRadius(16)
          .padding({ left: 14, right: 14, top: 4, bottom: 4 })
          .onClick(() => {
            if (this.commentText.trim()) {
              if (this.activePost) {
                this.activePost.commentCount++
                this.posts = [...this.posts]
                // 持久化评论到数据库
                const comment: PostComment = {
                  commentId: `comment_${Date.now()}`,
                  postId: this.activePost.postId,
                  userId: AppState.currentUser?.userId || '',
                  content: this.commentText.trim(),
                  isAnonymous: true,
                  createTime: Date.now()
                }
                this.companyDao.insertComment(comment)
              }
              this.commentText = ''
              this.showCommentSheet = false
              AlertDialog.show({ message: '评论发布成功' })
            }
          })
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 12, bottom: 12 })
      .border({ width: { bottom: 0.5 }, color: '#F0F0F0' })

      Column() {
        if (this.activePost) {
          Text(`原帖: ${this.activePost.content.substring(0, 80)}${this.activePost.content.length > 80 ? '...' : ''}`)
            .fontSize(12)
            .fontColor('#999999')
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 8 })
        }
        TextInput({ placeholder: '写下你的评论...', text: this.commentText })
          .width('90%')
          .height(44)
          .fontSize(14)
          .backgroundColor('#F5F5F5')
          .borderRadius(22)
          .padding({ left: 16 })
          .onChange((v: string) => { this.commentText = v })
      }
      .width('100%')
    }
    .width('100%')
    .backgroundColor('#FFFFFF')
  }
}
