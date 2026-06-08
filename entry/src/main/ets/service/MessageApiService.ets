import { HttpService, ApiResult } from './HttpService'

// 后端返回的会话模型
export interface RemoteConversation {
  id: string                       // conversationId: userA:userB
  user1Id: string
  user2Id: string
  lastMessage: string
  lastMessageTime: number
  unreadCountUser1: number
  unreadCountUser2: number
}

// 后端返回的消息模型
export interface RemoteMessage {
  id: string
  conversationId: string
  senderId: string
  receiverId: string
  content: string
  type: string                     // TEXT / IMAGE / FILE
  timestamp: number
  isRead: boolean
}

// 标记已读请求
export interface MarkReadRequest {
  conversationId: string
  userId: string
}

export class MessageApiService {

  // 获取会话列表
  static async fetchConversations(userId: string): Promise<RemoteConversation[]> {
    try {
      const result: ApiResult<RemoteConversation[]> =
        await HttpService.get<RemoteConversation[]>(`/chat/conversations/${encodeURIComponent(userId)}`)
      if (result.code === 0 && result.data) {
        return result.data
      }
      return []
    } catch (e) {
      return []
    }
  }

  // 获取聊天记录
  static async fetchMessages(conversationId: string, page: number = 0, size: number = 50): Promise<RemoteMessage[]> {
    try {
      const result: ApiResult<RemoteMessage[]> =
        await HttpService.get<RemoteMessage[]>(`/chat/messages/${encodeURIComponent(conversationId)}?page=${page}&size=${size}`)
      if (result.code === 0 && result.data) {
        return result.data
      }
      return []
    } catch (e) {
      return []
    }
  }

  // 获取总未读数
  static async getUnreadTotal(userId: string): Promise<number> {
    try {
      const result: ApiResult<number> =
        await HttpService.get<number>(`/chat/unread-total/${encodeURIComponent(userId)}`)
      if (result.code === 0 && result.data !== undefined) {
        return result.data as number
      }
      return 0
    } catch (e) {
      return 0
    }
  }

  // 标记已读
  static async markRead(conversationId: string, userId: string): Promise<boolean> {
    try {
      const body: MarkReadRequest = { conversationId: conversationId, userId: userId }
      const result: ApiResult<Object> = await HttpService.post<Object>('/chat/read', body)
      return result.code === 0
    } catch (e) {
      return false
    }
  }

  // 查询在线状态
  static async checkOnline(userId: string): Promise<boolean> {
    try {
      const result: ApiResult<boolean> =
        await HttpService.get<boolean>(`/chat/online/${encodeURIComponent(userId)}`)
      if (result.code === 0 && result.data !== undefined) {
        return result.data as boolean
      }
      return false
    } catch (e) {
      return false
    }
  }
}
