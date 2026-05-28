// 聊天消息数据访问对象

import { relationalStore } from '@kit.ArkData'
import { DatabaseHelper } from '../database/DatabaseHelper'
import { TABLE_CHAT_SESSION, TABLE_CHAT_MESSAGE, TABLE_SYSTEM_MESSAGE } from '../database/Tables'
import { ChatSession, ChatMessage, SystemMessage } from '../model/MessageModel'

export class MessageDao {
  private helper: DatabaseHelper = DatabaseHelper.getInstance()

  // ---- 会话 ----

  async getSessions(userId: string): Promise<ChatSession[]> {
    const store = await this.helper.getStore()
    const sql = `SELECT * FROM ${TABLE_CHAT_SESSION} WHERE session_id LIKE '%${userId}%' ORDER BY last_message_time DESC`
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

  // ---- 消息 ----

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

  async insertMessage(msg: ChatMessage): Promise<void> {
    const store = await this.helper.getStore()
    const vb: relationalStore.ValuesBucket = {
      message_id: msg.messageId,
      session_id: msg.sessionId,
      sender_id: msg.senderId,
      content: msg.content,
      timestamp: msg.timestamp,
      is_ai_agent_reply: msg.isAIAgentReply ? 1 : 0,
      message_type: msg.messageType,
      is_read: msg.isRead ? 1 : 0
    }
    await store.insert(TABLE_CHAT_MESSAGE, vb)

    // 更新会话最后消息
    const sessionVb: relationalStore.ValuesBucket = {
      last_message: msg.content,
      last_message_time: msg.timestamp,
      unread_count: msg.isRead ? 0 : 1
    }
    const sessionPred = new relationalStore.RdbPredicates(TABLE_CHAT_SESSION)
    sessionPred.equalTo('session_id', msg.sessionId)
    await store.update(sessionVb, sessionPred)
  }

  // ---- 系统消息 ----

  async getSystemMessages(userId: string): Promise<SystemMessage[]> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_SYSTEM_MESSAGE)
    predicates.equalTo('user_id', userId)
    predicates.orderByDesc('timestamp')
    const rs = await store.query(predicates)
    const msgs: SystemMessage[] = []
    while (rs.goToNextRow()) {
      msgs.push({
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
    return msgs
  }
}
