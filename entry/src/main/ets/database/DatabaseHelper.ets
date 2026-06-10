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

  async close(): Promise<void> {
    if (this.store) {
      await this.store.close()
      this.store = null
    }
  }
}
