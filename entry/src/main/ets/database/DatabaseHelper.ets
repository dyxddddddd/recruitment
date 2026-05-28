// 数据库帮助类 - 管理关系型数据库的创建与升级

import { relationalStore } from '@kit.ArkData'
import { DATABASE_NAME, ALL_CREATE_TABLES } from './Tables'
import { hilog } from '@kit.PerformanceAnalysisKit'

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

    return this.store
  }

  private async migrateV1ToV2(): Promise<void> {
    if (!this.store) return
    try {
      await this.store.executeSql(
        'ALTER TABLE tb_user ADD COLUMN password TEXT'
      )
    } catch (e) {
      // 列已存在则忽略
    }
  }

  async close(): Promise<void> {
    if (this.store) {
      await this.store.close()
      this.store = null
    }
  }
}
