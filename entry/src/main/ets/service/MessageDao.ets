import { relationalStore } from '@kit.ArkData'
import { DatabaseHelper } from '../database/DatabaseHelper'
import { TABLE_CHAT_MESSAGE, TABLE_CHAT_SESSION, TABLE_SYSTEM_MESSAGE } from '../database/Tables'
import { JobPosition } from '../model/JobModel'
import { ChatMessage, ChatSession, SystemMessage } from '../model/MessageModel'
import { UserProfile } from '../model/UserModel'

interface ParsedConversationSession {
  ownerId: string
  peerId: string
  jobId: string
}

export class MessageDao {
  private helper: DatabaseHelper = DatabaseHelper.getInstance()

  async getSessions(userId: string): Promise<ChatSession[]> {
    const store = await this.helper.getStore()
    const sql = `SELECT * FROM ${TABLE_CHAT_SESSION} WHERE instr(session_id, 'chat__${userId}__') = 1 OR instr(session_id, 'session_${userId}_') = 1 ORDER BY last_message_time DESC`
    const rs = await store.querySql(sql)
    const sessions: ChatSession[] = []
    while (rs.goToNextRow()) {
      sessions.push({
        sessionId: rs.getString(rs.getColumnIndex('session_id')),
        peerId: rs.getString(rs.getColumnIndex('peer_id')),
        peerName: rs.getString(rs.getColumnIndex('peer_name')),
        peerAvatar: rs.getString(rs.getColumnIndex('peer_avatar')),
        lastMessage: rs.getString(rs.getColumnIndex('last_message')),
        lastMessageTime: rs.getLong(rs.getColumnIndex('last_message_time')),
        unreadCount: rs.getLong(rs.getColumnIndex('unread_count')),
        isAIAgent: rs.getLong(rs.getColumnIndex('is_ai_agent')) === 1
      })
    }
    rs.close()
    return sessions
  }

  async ensureJobSeekerStarterSession(userId: string): Promise<string> {
    const store = await this.helper.getStore()
    const sessionId = `session_${userId}_hr_demo`
    const predicates = new relationalStore.RdbPredicates(TABLE_CHAT_SESSION)
    predicates.equalTo('session_id', sessionId)
    const rs = await store.query(predicates)
    const exists = rs.goToFirstRow()
    rs.close()
    if (exists) {
      return sessionId
    }

    const now = Date.now()
    const sessionBucket: relationalStore.ValuesBucket = {
      session_id: sessionId,
      peer_id: 'hr_demo_001',
      peer_name: '校招HR',
      peer_avatar: '',
      last_message: '你好，方便介绍一下你的项目经历和可约面时间吗？',
      last_message_time: now - 60000,
      unread_count: 1,
      is_ai_agent: 1
    }
    await store.insert(TABLE_CHAT_SESSION, sessionBucket)

    const messages: ChatMessage[] = [
      {
        messageId: `msg_${now - 3600000}`,
        sessionId: sessionId,
        senderId: 'hr_demo_001',
        content: '你好，我看了你的简历，对你的项目经历比较感兴趣。',
        timestamp: now - 3600000,
        isAIAgentReply: false,
        messageType: 'text',
        isRead: true
      },
      {
        messageId: `msg_${now - 1800000}`,
        sessionId: sessionId,
        senderId: 'hr_demo_001',
        content: '方便介绍一下你最近做过的项目吗？',
        timestamp: now - 1800000,
        isAIAgentReply: false,
        messageType: 'text',
        isRead: true
      },
      {
        messageId: `msg_${now - 60000}`,
        sessionId: sessionId,
        senderId: 'hr_demo_001',
        content: '你好，方便介绍一下你的项目经历和可约面时间吗？',
        timestamp: now - 60000,
        isAIAgentReply: false,
        messageType: 'text',
        isRead: false
      }
    ]

    for (let i = 0; i < messages.length; i++) {
      await this.insertMessage(messages[i])
    }
    return sessionId
  }

  async ensureApplicationConversation(job: JobPosition, jobSeeker: UserProfile, recruiter: UserProfile): Promise<string> {
    const studentSessionId = this.buildConversationSessionId(jobSeeker.userId, recruiter.userId, job.jobId)
    const recruiterSessionId = this.buildConversationSessionId(recruiter.userId, jobSeeker.userId, job.jobId)
    const recruiterName = recruiter.hrRealName || recruiter.companyName || job.companyName || '招聘方'
    const studentName = jobSeeker.realName || jobSeeker.phone || '候选人'
    const preview = `已就「${job.title}」建立沟通，可直接交流。`
    const now = Date.now()

    await this.ensureSession({
      sessionId: studentSessionId,
      peerId: recruiter.userId,
      peerName: recruiterName,
      peerAvatar: recruiter.avatar ?? '',
      lastMessage: preview,
      lastMessageTime: now,
      unreadCount: 0,
      isAIAgent: false
    })

    await this.ensureSession({
      sessionId: recruiterSessionId,
      peerId: jobSeeker.userId,
      peerName: studentName,
      peerAvatar: jobSeeker.avatar ?? '',
      lastMessage: preview,
      lastMessageTime: now,
      unreadCount: 0,
      isAIAgent: false
    })

    const studentMessages = await this.getMessages(studentSessionId)
    if (studentMessages.length === 0) {
      await this.insertRawMessage({
        messageId: `sys_${now}_student`,
        sessionId: studentSessionId,
        senderId: 'system_notice',
        content: `你已投递「${job.title}」，可在此直接与 ${recruiterName} 沟通。`,
        timestamp: now,
        isAIAgentReply: false,
        messageType: 'text',
        isRead: true
      }, false)
    }

    const recruiterMessages = await this.getMessages(recruiterSessionId)
    if (recruiterMessages.length === 0) {
      await this.insertRawMessage({
        messageId: `sys_${now}_recruiter`,
        sessionId: recruiterSessionId,
        senderId: 'system_notice',
        content: `${studentName} 已投递「${job.title}」，你们现在可以直接沟通。`,
        timestamp: now,
        isAIAgentReply: false,
        messageType: 'text',
        isRead: true
      }, false)
    }

    return studentSessionId
  }

  async getMessages(sessionId: string): Promise<ChatMessage[]> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_CHAT_MESSAGE)
    predicates.equalTo('session_id', sessionId)
    predicates.orderByAsc('timestamp')
    const rs = await store.query(predicates)
    const messages: ChatMessage[] = []
    while (rs.goToNextRow()) {
      messages.push({
        messageId: rs.getString(rs.getColumnIndex('message_id')),
        sessionId: rs.getString(rs.getColumnIndex('session_id')),
        senderId: rs.getString(rs.getColumnIndex('sender_id')),
        content: rs.getString(rs.getColumnIndex('content')),
        timestamp: rs.getLong(rs.getColumnIndex('timestamp')),
        isAIAgentReply: rs.getLong(rs.getColumnIndex('is_ai_agent_reply')) === 1,
        messageType: rs.getString(rs.getColumnIndex('message_type')) as 'text' | 'image' | 'file',
        isRead: rs.getLong(rs.getColumnIndex('is_read')) === 1
      })
    }
    rs.close()
    return messages
  }

  async insertMessage(message: ChatMessage): Promise<void> {
    await this.insertRawMessage(message, !message.isRead)
  }

  async insertConversationMessage(message: ChatMessage): Promise<void> {
    await this.insertRawMessage(message, false)
    const counterpartSessionId = this.getCounterpartSessionId(message.sessionId)
    if (!counterpartSessionId) {
      return
    }

    const counterpartExists = await this.sessionExists(counterpartSessionId)
    if (!counterpartExists) {
      return
    }

    await this.insertRawMessage({
      messageId: `${message.messageId}_mirror`,
      sessionId: counterpartSessionId,
      senderId: message.senderId,
      content: message.content,
      timestamp: message.timestamp,
      isAIAgentReply: message.isAIAgentReply,
      messageType: message.messageType,
      isRead: false
    }, true)
  }

  async markSessionRead(sessionId: string): Promise<void> {
    const store = await this.helper.getStore()
    const sessionPredicates = new relationalStore.RdbPredicates(TABLE_CHAT_SESSION)
    sessionPredicates.equalTo('session_id', sessionId)
    await store.update({ unread_count: 0 }, sessionPredicates)

    const messagePredicates = new relationalStore.RdbPredicates(TABLE_CHAT_MESSAGE)
    messagePredicates.equalTo('session_id', sessionId)
    await store.update({ is_read: 1 }, messagePredicates)
  }

  async getSystemMessages(userId: string): Promise<SystemMessage[]> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_SYSTEM_MESSAGE)
    predicates.equalTo('user_id', userId)
    predicates.orderByDesc('timestamp')
    const rs = await store.query(predicates)
    const messages: SystemMessage[] = []
    while (rs.goToNextRow()) {
      messages.push({
        messageId: rs.getString(rs.getColumnIndex('message_id')),
        userId: rs.getString(rs.getColumnIndex('user_id')),
        title: rs.getString(rs.getColumnIndex('title')),
        content: rs.getString(rs.getColumnIndex('content')),
        type: rs.getString(rs.getColumnIndex('type')) as 'interview' | 'task' | 'system' | 'apply',
        isRead: rs.getLong(rs.getColumnIndex('is_read')) === 1,
        timestamp: rs.getLong(rs.getColumnIndex('timestamp'))
      })
    }
    rs.close()
    return messages
  }

  async updateAIAgentEnabled(userId: string, enabled: boolean): Promise<void> {
    const store = await this.helper.getStore()
    await store.executeSql(
      `INSERT OR REPLACE INTO tb_user_setting (user_id, ai_agent_enabled, update_time) VALUES ('${userId}', ${enabled ? 1 : 0}, ${Date.now()})`
    )
  }

  async getAIAgentEnabled(userId: string): Promise<boolean> {
    const store = await this.helper.getStore()
    try {
      const rs = await store.querySql(`SELECT ai_agent_enabled FROM tb_user_setting WHERE user_id = '${userId}'`)
      const enabled = rs.goToFirstRow() ? rs.getLong(rs.getColumnIndex('ai_agent_enabled')) === 1 : false
      rs.close()
      return enabled
    } catch (e) {
      return false
    }
  }

  private async ensureSession(session: ChatSession): Promise<void> {
    const exists = await this.sessionExists(session.sessionId)
    if (exists) {
      return
    }
    const store = await this.helper.getStore()
    const bucket: relationalStore.ValuesBucket = {
      session_id: session.sessionId,
      peer_id: session.peerId,
      peer_name: session.peerName,
      peer_avatar: session.peerAvatar,
      last_message: session.lastMessage,
      last_message_time: session.lastMessageTime,
      unread_count: session.unreadCount,
      is_ai_agent: session.isAIAgent ? 1 : 0
    }
    await store.insert(TABLE_CHAT_SESSION, bucket)
  }

  private async sessionExists(sessionId: string): Promise<boolean> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_CHAT_SESSION)
    predicates.equalTo('session_id', sessionId)
    const rs = await store.query(predicates)
    const exists = rs.goToFirstRow()
    rs.close()
    return exists
  }

  private async getSessionUnreadCount(sessionId: string): Promise<number> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_CHAT_SESSION)
    predicates.equalTo('session_id', sessionId)
    const rs = await store.query(predicates)
    const unreadCount = rs.goToFirstRow() ? rs.getLong(rs.getColumnIndex('unread_count')) : 0
    rs.close()
    return unreadCount
  }

  private async insertRawMessage(message: ChatMessage, incrementUnread: boolean): Promise<void> {
    const store = await this.helper.getStore()
    const bucket: relationalStore.ValuesBucket = {
      message_id: message.messageId,
      session_id: message.sessionId,
      sender_id: message.senderId,
      content: message.content,
      timestamp: message.timestamp,
      is_ai_agent_reply: message.isAIAgentReply ? 1 : 0,
      message_type: message.messageType,
      is_read: message.isRead ? 1 : 0
    }
    await store.insert(TABLE_CHAT_MESSAGE, bucket)

    const currentUnreadCount = await this.getSessionUnreadCount(message.sessionId)
    const sessionBucket: relationalStore.ValuesBucket = {
      last_message: message.content,
      last_message_time: message.timestamp,
      unread_count: incrementUnread ? currentUnreadCount + 1 : currentUnreadCount
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_CHAT_SESSION)
    predicates.equalTo('session_id', message.sessionId)
    await store.update(sessionBucket, predicates)
  }

  private buildConversationSessionId(ownerId: string, peerId: string, jobId: string): string {
    return `chat__${ownerId}__${peerId}__${jobId}`
  }

  private getCounterpartSessionId(sessionId: string): string | null {
    const parsed = this.parseConversationSessionId(sessionId)
    if (!parsed) {
      return null
    }
    return this.buildConversationSessionId(parsed.peerId, parsed.ownerId, parsed.jobId)
  }

  private parseConversationSessionId(sessionId: string): ParsedConversationSession | null {
    if (!sessionId.startsWith('chat__')) {
      return null
    }
    const parts = sessionId.split('__')
    if (parts.length !== 4) {
      return null
    }
    return {
      ownerId: parts[1],
      peerId: parts[2],
      jobId: parts[3]
    }
  }
}
