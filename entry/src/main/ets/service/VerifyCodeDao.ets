// 验证码数据访问对象 - 本地存储后端下发的验证码供辅助验证

import { relationalStore } from '@kit.ArkData'
import { DatabaseHelper } from '../database/DatabaseHelper'
import { TABLE_VERIFY_CODE } from '../database/Tables'

export interface VerifyCodeRecord {
  phone: string
  code: string
  expireTime: number
  createdAt: number
}

export class VerifyCodeDao {
  private helper: DatabaseHelper = DatabaseHelper.getInstance()

  async saveCode(phone: string, code: string, expireMinutes: number = 5): Promise<void> {
    const store = await this.helper.getStore()
    const now = Date.now()
    const expireTime = now + expireMinutes * 60 * 1000
    const valueBucket: relationalStore.ValuesBucket = {
      phone: phone,
      code: code,
      expire_time: expireTime,
      created_at: now
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_VERIFY_CODE)
    predicates.equalTo('phone', phone)
    await store.delete(predicates)
    await store.insert(TABLE_VERIFY_CODE, valueBucket)
  }

  async verifyCode(phone: string, inputCode: string): Promise<boolean> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_VERIFY_CODE)
    predicates.equalTo('phone', phone)
    const resultSet = await store.query(predicates)
    if (resultSet.goToFirstRow()) {
      const code = resultSet.getString(resultSet.getColumnIndex('code'))
      const expireTime = resultSet.getLong(resultSet.getColumnIndex('expire_time'))
      resultSet.close()
      if (Date.now() > expireTime) {
        return false
      }
      return code === inputCode
    }
    resultSet.close()
    return false
  }

  async deleteCode(phone: string): Promise<void> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_VERIFY_CODE)
    predicates.equalTo('phone', phone)
    await store.delete(predicates)
  }
}
