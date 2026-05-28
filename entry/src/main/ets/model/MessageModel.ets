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
  sessionId: string
  senderId: string
  content: string
  timestamp: number
  isAIAgentReply: boolean           // 紫色气泡：AI替身代聊
  messageType: 'text' | 'image' | 'file'
  isRead: boolean
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
