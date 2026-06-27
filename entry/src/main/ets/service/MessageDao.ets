import { relationalStore } from '@kit.ArkData'
import { DatabaseHelper } from '../database/DatabaseHelper'
import { TABLE_CHAT_MESSAGE, TABLE_CHAT_SESSION, TABLE_SYSTEM_MESSAGE } from '../database/Tables'
import { ChatMessage, ChatSession, SystemMessage, buildConversationId, getPeerId } from '../model/MessageModel'
import { UserProfile } from '../model/UserModel'
import { MessageApiService, RemoteConversation, RemoteMessage } from './MessageApiService'

export class MessageDao {
  private helper: DatabaseHelper = DatabaseHelper.getInstance()

  // 同步会话列表：从后端 REST 拉取并合并到本地
  async syncConversations(userId: string): Promise<void> {
    const conversations = await MessageApiService.fetchConversations(userId)
    if (conversations.length === 0) {
      return
    }
    const store = await this.helper.getStore()
    for (let i = 0; i < conversations.length; i++) {
      const c = conversations[i]
      const peerId = getPeerId(c.id, userId)
      const remoteUnread = userId === c.user1Id ? c.unreadCountUser1 : c.unreadCountUser2
      const exists = await this.conversationExists(c.id)
      if (exists) {
        // 更新消息预览；未读数只升不降（markConversationRead 负责清零）
        // 本地 peer_name 优先，为空则从用户表推导
        const localPeerName = await this.getLocalPeerName(c.id)
        const fillName = localPeerName || (await this.getPeerDisplayName(peerId))
        await store.executeSql(
          `UPDATE ${TABLE_CHAT_SESSION}
          SET last_message = '${this.escapeSql(c.lastMessage || '')}',
              last_message_time = ${c.lastMessageTime || 0},
              unread_count = MAX(unread_count, ${remoteUnread}),
              peer_name = CASE WHEN peer_name = '' AND '${this.escapeSql(fillName)}' != '' THEN '${this.escapeSql(fillName)}' ELSE peer_name END
          WHERE session_id = '${c.id}'`
        )
      } else {
        const peerName = await this.getPeerDisplayName(peerId)
        await store.executeSql(
          `INSERT OR IGNORE INTO ${TABLE_CHAT_SESSION}
          (session_id, peer_id, peer_name, peer_avatar, last_message, last_message_time, unread_count, is_ai_agent)
          VALUES ('${c.id}', '${peerId}', '${this.escapeSql(peerName)}', '', '${this.escapeSql(c.lastMessage || '')}', ${c.lastMessageTime || 0}, ${remoteUnread}, 0)`
        )
      }
    }
  }

  // 同步消息：从后端 REST 拉取并合并到本地（用于初次加载或拉取更早的历史）
  async syncMessages(conversationId: string, page: number = 0): Promise<number> {
    const messages = await MessageApiService.fetchMessages(conversationId, page)
    if (messages.length === 0) {
      return 0
    }
    const store = await this.helper.getStore()
    let count = 0
    let latestContent = ''
    let latestTime = 0
    for (let i = 0; i < messages.length; i++) {
      const m = messages[i]
      const existing = await this.messageExists(store, m.id)
      if (!existing) {
        await store.executeSql(
          `INSERT OR IGNORE INTO ${TABLE_CHAT_MESSAGE}
          (message_id, session_id, sender_id, receiver_id, content, timestamp, is_ai_agent_reply, message_type, is_read)
          VALUES ('${m.id}', '${m.conversationId}', '${m.senderId}', '${m.receiverId || ''}', '${this.escapeSql(m.content)}', ${m.timestamp}, 0, '${(m.type || 'TEXT').toLowerCase()}', ${m.isRead ? 1 : 0})`
        )
        count++
      }
      if (m.timestamp > latestTime) {
        latestTime = m.timestamp
        latestContent = m.content
      }
    }
    // 更新会话最后消息
    if (latestTime > 0) {
      try {
        await store.executeSql(
          `UPDATE ${TABLE_CHAT_SESSION}
           SET last_message = CASE WHEN last_message_time < ${latestTime} THEN '${this.escapeSql(latestContent)}' ELSE last_message END,
               last_message_time = MAX(last_message_time, ${latestTime})
           WHERE session_id = '${conversationId}'`
        )
      } catch (_e) { /* ignore */ }
    }
    return count
  }

  private async messageExists(store: relationalStore.RdbStore, messageId: string): Promise<boolean> {
    try {
      const rs = await store.querySql(
        `SELECT 1 FROM ${TABLE_CHAT_MESSAGE} WHERE message_id = '${messageId}'`
      )
      const exists = rs.goToFirstRow()
      rs.close()
      return exists
    } catch (e) {
      return false
    }
  }

  // 获取本地会话列表
  async getConversations(userId: string): Promise<ChatSession[]> {
    const store = await this.helper.getStore()
    const rs = await store.querySql(
      `SELECT * FROM ${TABLE_CHAT_SESSION} WHERE instr(session_id, '${userId}') > 0 ORDER BY last_message_time DESC`
    )
    const sessions: ChatSession[] = []
    while (rs.goToNextRow()) {
      const sessionId = rs.getString(rs.getColumnIndex('session_id'))
      // 从 session_id 动态推导对方 ID，而非依赖存储的 peer_id（存储值可能以另一方视角写入）
      const peerId = getPeerId(sessionId, userId)
      // 始终从用户表推导对方显示名（存储的 peer_name 可能以另一方视角写入）
      let peerName = await this.getPeerDisplayName(peerId)
      if (!peerName) {
        // 用户表查不到则回退到已存储的 peer_name
        peerName = rs.getString(rs.getColumnIndex('peer_name'))
      }
      // 回填推导结果
      if (peerName) {
        try {
          await store.executeSql(
            `UPDATE ${TABLE_CHAT_SESSION} SET peer_name = '${this.escapeSql(peerName)}', peer_id = '${peerId}' WHERE session_id = '${sessionId}'`
          )
        } catch (e) {
          // ignore
        }
      }
      // 动态计算未读数（对方发送的未读消息数）+ 会话存储的兜底值（种子数据/后端同步）
      let unreadCount = rs.getLong(rs.getColumnIndex('unread_count'))
      try {
        const countRs = await store.querySql(
          `SELECT COUNT(*) AS cnt FROM ${TABLE_CHAT_MESSAGE} WHERE session_id = '${sessionId}' AND sender_id = '${peerId}' AND is_read = 0`
        )
        if (countRs.goToFirstRow()) {
          const dynamicCount = countRs.getLong(countRs.getColumnIndex('cnt'))
          unreadCount = Math.max(unreadCount, dynamicCount)
        }
        countRs.close()
      } catch (e) {
        // keep stored value
      }
      sessions.push({
        sessionId: sessionId,
        peerId: peerId,
        peerName: peerName || peerId || '用户',
        peerAvatar: rs.getString(rs.getColumnIndex('peer_avatar')),
        lastMessage: rs.getString(rs.getColumnIndex('last_message')) || await this.getLatestMessageContent(sessionId),
        lastMessageTime: rs.getLong(rs.getColumnIndex('last_message_time')),
        unreadCount: unreadCount,
        isAIAgent: rs.getLong(rs.getColumnIndex('is_ai_agent')) === 1
      })
    }
    rs.close()
    return sessions
  }

  // 获取本地消息
  async getMessages(conversationId: string): Promise<ChatMessage[]> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_CHAT_MESSAGE)
    predicates.equalTo('session_id', conversationId)
    predicates.orderByAsc('timestamp')
    const rs = await store.query(predicates)
    const messages: ChatMessage[] = []
    while (rs.goToNextRow()) {
      messages.push({
        messageId: rs.getString(rs.getColumnIndex('message_id')),
        sessionId: rs.getString(rs.getColumnIndex('session_id')),
        senderId: rs.getString(rs.getColumnIndex('sender_id')),
        receiverId: rs.getString(rs.getColumnIndex('receiver_id')),
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

  // 插入消息到本地数据库
  async insertMessage(message: ChatMessage): Promise<void> {
    const store = await this.helper.getStore()
    const bucket: relationalStore.ValuesBucket = {
      message_id: message.messageId,
      session_id: message.sessionId,
      sender_id: message.senderId,
      receiver_id: message.receiverId || '',
      content: message.content,
      timestamp: message.timestamp,
      is_ai_agent_reply: message.isAIAgentReply ? 1 : 0,
      message_type: message.messageType,
      is_read: message.isRead ? 1 : 0
    }
    await store.insert(TABLE_CHAT_MESSAGE, bucket)

    // 更新会话最后消息
    const sessionBucket: relationalStore.ValuesBucket = {
      last_message: message.content,
      last_message_time: message.timestamp
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_CHAT_SESSION)
    predicates.equalTo('session_id', message.sessionId)
    await store.update(sessionBucket, predicates)
  }

  // 确保会话存在
  async ensureConversation(conversationId: string, peerId: string, peerName: string): Promise<void> {
    const store = await this.helper.getStore()
    const exists = await this.conversationExists(conversationId)
    if (exists) {
      if (peerName) {
        try {
          await store.executeSql(
            `UPDATE ${TABLE_CHAT_SESSION} SET peer_name = '${this.escapeSql(peerName)}', peer_id = '${peerId}' WHERE session_id = '${conversationId}' AND (peer_name = '' OR peer_name IS NULL)`
          )
        } catch (_e) { /* ignore */ }
      }
      return
    }
    const bucket: relationalStore.ValuesBucket = {
      session_id: conversationId,
      peer_id: peerId,
      peer_name: peerName,
      peer_avatar: '',
      last_message: '',
      last_message_time: Date.now(),
      unread_count: 0,
      is_ai_agent: 0
    }
    await store.insert(TABLE_CHAT_SESSION, bucket)
  }

  // === 演示种子会话（仅首次创建，只插会话不插消息） ===

  async ensureRecruiterDemoSession(userId: string): Promise<void> {
    const studentId = 'student_demo_001'
    const conversationId = buildConversationId(userId, studentId)
    if (await this.conversationExists(conversationId)) {
      return
    }
    const now = Date.now()
    const store = await this.helper.getStore()
    const bucket: relationalStore.ValuesBucket = {
      session_id: conversationId,
      peer_id: studentId,
      peer_name: '',
      peer_avatar: '',
      last_message: '你好 HR，我对贵公司的实习岗位比较感兴趣。',
      last_message_time: now,
      unread_count: 1,
      is_ai_agent: 0
    }
    await store.insert(TABLE_CHAT_SESSION, bucket)
  }

  async ensureJobSeekerDemoSession(userId: string): Promise<void> {
    const hrId = 'hr_demo_001'
    const conversationId = buildConversationId(userId, hrId)
    if (await this.conversationExists(conversationId)) {
      return
    }
    const now = Date.now()
    const store = await this.helper.getStore()
    const bucket: relationalStore.ValuesBucket = {
      session_id: conversationId,
      peer_id: hrId,
      peer_name: '校招HR',
      peer_avatar: '',
      last_message: '你好，方便介绍一下你的项目经历吗？',
      last_message_time: now,
      unread_count: 1,
      is_ai_agent: 1
    }
    await store.insert(TABLE_CHAT_SESSION, bucket)
  }

  // 为投递岗位创建沟通会话
  async ensureApplicationConversation(recruiterId: string, studentId: string, studentName: string, recruiterName: string, jobTitle: string): Promise<string> {
    const conversationId = buildConversationId(recruiterId, studentId)
    const now = Date.now()
    const preview = `已就「${jobTitle}」建立沟通。`

    await this.ensureConversation(conversationId, studentId, '')
    const store = await this.helper.getStore()

    // 更新会话预览
    const bucket: relationalStore.ValuesBucket = {
      last_message: preview,
      last_message_time: now
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_CHAT_SESSION)
    predicates.equalTo('session_id', conversationId)
    await store.update(bucket, predicates)

    // 插入系统提示消息
    const existingMessages = await this.getMessages(conversationId)
    if (existingMessages.length === 0) {
      const sysMsg: ChatMessage = {
        messageId: `sys_${now}_${conversationId}`,
        sessionId: conversationId,
        senderId: 'system_notice',
        receiverId: '',
        content: `${studentName} 已投递「${jobTitle}」，你们现在可以直接沟通。`,
        timestamp: now,
        isAIAgentReply: false,
        messageType: 'text',
        isRead: true
      }
      await this.insertMessage(sysMsg)
    }

    return conversationId
  }

  // 标记本地会话已读
  async markConversationRead(conversationId: string): Promise<void> {
    const store = await this.helper.getStore()
    const sessionPredicates = new relationalStore.RdbPredicates(TABLE_CHAT_SESSION)
    sessionPredicates.equalTo('session_id', conversationId)
    await store.update({ unread_count: 0 }, sessionPredicates)

    const messagePredicates = new relationalStore.RdbPredicates(TABLE_CHAT_MESSAGE)
    messagePredicates.equalTo('session_id', conversationId)
    await store.update({ is_read: 1 }, messagePredicates)
  }

  // 标记远程已读
  async markReadRemote(conversationId: string, userId: string): Promise<void> {
    await MessageApiService.markRead(conversationId, userId)
  }

  // 增加未读数（收到其他会话的 WebSocket 消息时调用）
  async incrementUnread(conversationId: string, lastMessage: string, timestamp: number): Promise<void> {
    const store = await this.helper.getStore()
    try {
      await store.executeSql(
        `UPDATE ${TABLE_CHAT_SESSION}
        SET unread_count = unread_count + 1,
            last_message = '${this.escapeSql(lastMessage)}',
            last_message_time = ${timestamp}
        WHERE session_id = '${conversationId}'`
      )
    } catch (e) {
      // ignore
    }
  }

  // 后端推送 UNREAD_UPDATE 时，直接设置某会话的未读数
  async setUnreadCount(conversationId: string, unreadCount: number): Promise<void> {
    const store = await this.helper.getStore()
    try {
      await store.executeSql(
        `UPDATE ${TABLE_CHAT_SESSION} SET unread_count = ${unreadCount} WHERE session_id = '${conversationId}'`
      )
    } catch (e) {
      // ignore
    }
  }

  // 获取未读总数（本地动态计算 + 后端兜底）
  async getUnreadTotal(userId: string): Promise<number> {
    const sessions = await this.getConversations(userId)
    let total = 0
    for (let i = 0; i < sessions.length; i++) {
      total += sessions[i].unreadCount
    }
    return total
  }

  // 检查在线状态
  async checkOnline(userId: string): Promise<boolean> {
    return await MessageApiService.checkOnline(userId)
  }

  // AI 代聊相关
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

  async insertSystemMessage(userId: string, title: string, content: string, type: string): Promise<void> {
    const store = await this.helper.getStore()
    const bucket: relationalStore.ValuesBucket = {
      message_id: `sys_${Date.now()}_${Math.random().toString(36).slice(2, 8)}`,
      user_id: userId,
      title: title,
      content: content,
      type: type,
      is_read: 0,
      timestamp: Date.now()
    }
    await store.insert(TABLE_SYSTEM_MESSAGE, bucket)
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

  // 从用户表查找对方显示名
  private async getPeerDisplayName(peerId: string): Promise<string> {
    try {
      const store = await this.helper.getStore()
      const rs = await store.querySql(
        `SELECT real_name, hr_real_name, company_name FROM tb_user WHERE user_id = '${peerId}'`
      )
      if (rs.goToFirstRow()) {
        const realName = rs.getString(rs.getColumnIndex('real_name'))
        if (realName) {
          rs.close()
          return realName
        }
        const hrRealName = rs.getString(rs.getColumnIndex('hr_real_name'))
        if (hrRealName) {
          rs.close()
          return hrRealName
        }
        const companyName = rs.getString(rs.getColumnIndex('company_name'))
        if (companyName) {
          rs.close()
          return companyName
        }
      }
      rs.close()
    } catch (e) {
      // ignore
    }
    return ''
  }

  // 获取本地会话已存储的 peer_name
  private async getLocalPeerName(conversationId: string): Promise<string> {
    try {
      const store = await this.helper.getStore()
      const rs = await store.querySql(
        `SELECT peer_name FROM ${TABLE_CHAT_SESSION} WHERE session_id = '${conversationId}'`
      )
      if (rs.goToFirstRow()) {
        const name = rs.getString(rs.getColumnIndex('peer_name'))
        rs.close()
        return name || ''
      }
      rs.close()
    } catch (e) {
      // ignore
    }
    return ''
  }

  private async conversationExists(conversationId: string): Promise<boolean> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_CHAT_SESSION)
    predicates.equalTo('session_id', conversationId)
    const rs = await store.query(predicates)
    const exists = rs.goToFirstRow()
    rs.close()
    return exists
  }

  // 当会话表中 last_message 为空时，从消息表取最新一条作为兜底
  private async getLatestMessageContent(conversationId: string): Promise<string> {
    try {
      const store = await this.helper.getStore()
      const rs = await store.querySql(
        `SELECT content FROM ${TABLE_CHAT_MESSAGE} WHERE session_id = '${conversationId}' ORDER BY timestamp DESC LIMIT 1`
      )
      if (rs.goToFirstRow()) {
        const content = rs.getString(rs.getColumnIndex('content'))
        rs.close()
        return content || ''
      }
      rs.close()
    } catch (_e) { /* ignore */ }
    return ''
  }

  private escapeSql(value: string): string {
    return value.replace(/'/g, "''")
  }
}
