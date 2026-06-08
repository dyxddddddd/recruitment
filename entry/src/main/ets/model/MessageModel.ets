// 消息与聊天数据模型

export interface ChatSession {
  sessionId: string
  peerId: string                    // 对方用户ID
  peerName: string
  peerAvatar: string
  lastMessage: string
  lastMessageTime: number
  unreadCount: number
  isAIAgent: boolean               // 对方是否在使用AI数字分身
}

export interface ChatMessage {
  messageId: string
  sessionId: string                 // conversationId: userA:userB
  senderId: string
  receiverId?: string               // 接收者ID（后端模型需要）
  content: string
  timestamp: number
  isAIAgentReply: boolean           // 紫色气泡：AI替身代聊
  messageType: 'text' | 'image' | 'file'
  isRead: boolean
}

// 构建会话ID（两个用户ID字母序排序，冒号拼接）
export function buildConversationId(userId1: string, userId2: string): string {
  if (userId1 < userId2) {
    return `${userId1}:${userId2}`
  }
  return `${userId2}:${userId1}`
}

// 从会话ID获取对方ID
export function getPeerId(conversationId: string, myUserId: string): string {
  const parts = conversationId.split(':')
  if (parts.length === 2) {
    return parts[0] === myUserId ? parts[1] : parts[0]
  }
  return ''
}

export interface SystemMessage {
  messageId: string
  userId: string
  title: string
  content: string
  type: 'interview' | 'task' | 'system' | 'apply'
  isRead: boolean
  timestamp: number
}
