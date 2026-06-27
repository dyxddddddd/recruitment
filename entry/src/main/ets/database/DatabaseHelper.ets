import { relationalStore } from '@kit.ArkData'
import { hilog } from '@kit.PerformanceAnalysisKit'
import { ALL_CREATE_TABLES, DATABASE_NAME, TABLE_USER } from './Tables'
import { DemoDataInitializer } from './DemoDataInitializer'

const TAG = 'DatabaseHelper'

export class DatabaseHelper {
  private static instance: DatabaseHelper
  private store: relationalStore.RdbStore | null = null

  static getInstance(): DatabaseHelper {
    if (!DatabaseHelper.instance) {
      DatabaseHelper.instance = new DatabaseHelper()
    }
    return DatabaseHelper.instance
  }

  async getStore(): Promise<relationalStore.RdbStore> {
    if (this.store) {
      return this.store
    }
    return this.initDatabase()
  }

  private async initDatabase(): Promise<relationalStore.RdbStore> {
    const context = getContext(this)
    const config: relationalStore.StoreConfig = {
      name: DATABASE_NAME,
      securityLevel: relationalStore.SecurityLevel.S1
    }

    this.store = await relationalStore.getRdbStore(context, config)

    for (const sql of ALL_CREATE_TABLES) {
      await this.store.executeSql(sql)
      hilog.info(0x0000, TAG, 'Table created successfully')
    }

    await this.migrateV1ToV2()
    await this.migrateV2ToV3()
    await this.migrateV3ToV4()
    await this.migrateV4ToV5()
    await this.migrateV5ToV6()

    await this.migrateV6ToV7()
    await this.migrateV7ToV8()
    await this.migrateV8ToV9()
    await this.migrateV9ToV10()

    await DemoDataInitializer.seed(this.store)

    return this.store
  }

  private async migrateV1ToV2(): Promise<void> {
    if (!this.store) return
    try {
      await this.store.executeSql('ALTER TABLE tb_user ADD COLUMN password TEXT')
    } catch (e) {
    }
  }

  private async migrateV2ToV3(): Promise<void> {
    if (!this.store) return
    try {
      await this.store.executeSql('ALTER TABLE tb_user ADD COLUMN password TEXT')
    } catch (e) {
    }
    try {
      await this.store.executeSql('ALTER TABLE tb_community_post ADD COLUMN favorite_count INTEGER DEFAULT 0')
    } catch (e) {
    }
    try {
      await this.store.executeSql(
        `UPDATE ${TABLE_USER} SET password = '123456'
         WHERE user_id IN ('student_demo_001', 'student_demo_002', 'recruiter_demo_001')`
      )
    } catch (e) {
    }
  }

  private async migrateV3ToV4(): Promise<void> {
    if (!this.store) return
    try {
      await this.store.executeSql(`DELETE FROM ${TABLE_USER} WHERE user_id = 'student_demo_002'`)
    } catch (e) {
    }
  }

  private async migrateV4ToV5(): Promise<void> {
    if (!this.store) return
    const alterSqlList: string[] = [
      'ALTER TABLE tb_job ADD COLUMN required_day_of_week INTEGER DEFAULT -1',
      'ALTER TABLE tb_job ADD COLUMN required_start_hour INTEGER DEFAULT -1',
      'ALTER TABLE tb_job ADD COLUMN required_end_hour INTEGER DEFAULT -1',
      'ALTER TABLE tb_micro_task ADD COLUMN required_day_of_week INTEGER DEFAULT -1',
      'ALTER TABLE tb_micro_task ADD COLUMN required_start_hour INTEGER DEFAULT -1',
      'ALTER TABLE tb_micro_task ADD COLUMN required_end_hour INTEGER DEFAULT -1',
      'ALTER TABLE tb_job ADD COLUMN task_start_time INTEGER DEFAULT -1',
      'ALTER TABLE tb_job ADD COLUMN task_end_time INTEGER DEFAULT -1'
    ]
    for (let i = 0; i < alterSqlList.length; i++) {
      try {
        await this.store.executeSql(alterSqlList[i])
      } catch (e) {
      }
    }
  }

  private async migrateV5ToV6(): Promise<void> {
    if (!this.store) return
    try {
      await this.store.executeSql('ALTER TABLE tb_user ADD COLUMN email TEXT')
    } catch (e) {
    }
  }

  private async migrateV6ToV7(): Promise<void> {
    if (!this.store) return
    const alters: string[] = [
      'ALTER TABLE tb_user ADD COLUMN auth_status INTEGER DEFAULT 0',
      'ALTER TABLE tb_user ADD COLUMN id_card_front_image TEXT',
      'ALTER TABLE tb_user ADD COLUMN id_card_back_image TEXT',
      'ALTER TABLE tb_user ADD COLUMN face_image TEXT',
      'ALTER TABLE tb_user ADD COLUMN auth_submit_time INTEGER',
      'ALTER TABLE tb_user ADD COLUMN auth_approve_time INTEGER',
      'ALTER TABLE tb_user ADD COLUMN auth_reject_reason TEXT',
      'ALTER TABLE tb_user ADD COLUMN company_address TEXT',
      'ALTER TABLE tb_user ADD COLUMN company_industry TEXT',
      'ALTER TABLE tb_user ADD COLUMN company_scale TEXT',
      'ALTER TABLE tb_user ADD COLUMN legal_person TEXT',
      'ALTER TABLE tb_user ADD COLUMN contact_position TEXT',
      'ALTER TABLE tb_user ADD COLUMN company_email TEXT'
    ]
    for (let i = 0; i < alters.length; i++) {
      try {
        await this.store.executeSql(alters[i])
      } catch (e) {
        // column may already exist
      }
    }
  }

  private async migrateV7ToV8(): Promise<void> {
    if (!this.store) return
    try {
      await this.store.executeSql(
        `CREATE TABLE IF NOT EXISTS tb_ai_interview (
          interview_id TEXT PRIMARY KEY,
          recruiter_id TEXT NOT NULL,
          user_id TEXT NOT NULL,
          job_id TEXT NOT NULL,
          application_id TEXT NOT NULL,
          status TEXT DEFAULT 'invited',
          questions TEXT,
          answers TEXT,
          assessment_result TEXT,
          total_score INTEGER DEFAULT 0,
          invite_time INTEGER,
          start_time INTEGER,
          complete_time INTEGER
        )`
      )
    } catch (e) {
      // table may already exist
    }
  }

  private async migrateV8ToV9(): Promise<void> {
    if (!this.store) return
    try {
      await this.store.executeSql('ALTER TABLE tb_user ADD COLUMN vip_expire_time INTEGER DEFAULT 0')
    } catch (e) { /* column may already exist */ }
    try {
      await this.store.executeSql('ALTER TABLE tb_user ADD COLUMN vip_lifetime INTEGER DEFAULT 0')
    } catch (e) { /* column may already exist */ }
  }

  private async migrateV9ToV10(): Promise<void> {
    if (!this.store) return
    // 清除旧的演示聊天会话及消息
    const demoSessionIds = [
      'recruiter_demo_001:student_demo_001',
      'recruiter_demo_001:student_demo_002'
    ]
    for (const sid of demoSessionIds) {
      try {
        await this.store.executeSql(`DELETE FROM tb_chat_message WHERE session_id = '${sid}'`)
        await this.store.executeSql(`DELETE FROM tb_chat_session WHERE session_id = '${sid}'`)
      } catch (e) { /* ignore */ }
    }
    // 修正旧种子数据中 student_demo_001 和 002 的名字
    try {
      await this.store.executeSql(`UPDATE tb_user SET real_name = '陈逸飞', school = '中南大学', major = '软件工程', education = '本科大三', expected_position = '前端开发实习', expected_salary = '4000-6000', current_city = '长沙' WHERE user_id = 'student_demo_001' AND real_name = '校园同学'`)
    } catch (e) { /* ignore */ }
    try {
      await this.store.executeSql(`UPDATE tb_user SET real_name = '林雪莹', student_type = 'graduating', school = '湖南大学', major = '计算机科学与技术', education = '硕士', expected_position = 'Java后端开发', expected_salary = '12000-18000', current_city = '长沙' WHERE user_id = 'student_demo_002' AND (real_name IS NULL OR real_name = '' OR real_name = '学生用户')`)
    } catch (e) { /* ignore */ }
  }

  async close(): Promise<void> {
    if (this.store) {
      await this.store.close()
      this.store = null
    }
  }
}
