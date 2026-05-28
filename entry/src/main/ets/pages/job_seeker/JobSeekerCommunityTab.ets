// 求职者 - 社区广场页（Tab c: 社区）

import { AppConstants, AppState } from '../../common/constants/AppConstants'
import { CommunityPost } from '../../model/CompanyModel'
import { CompanyDao } from '../../service/CompanyDao'

@Component
export struct JobSeekerCommunityTab {
  @State posts: CommunityPost[] = []
  @State selectedCategory: string = 'all' // all, interview, companion, discussion
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
    if (this.selectedCategory === 'all') {
      return this.posts
    }
    return this.posts.filter(p => p.category === this.selectedCategory)
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
          Image($r('sys.symbol.heart'))
            .width(14)
            .height(14)
            .fillColor('#CCCCCC')
          Text(`${post.likeCount}`)
            .fontSize(11)
            .fontColor('#999999')
            .margin({ left: 2, right: 10 })
          Text('💬')
            .fontSize(14)
          Text(`${post.commentCount}`)
            .fontSize(11)
            .fontColor('#999999')
            .margin({ left: 2 })
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
}
