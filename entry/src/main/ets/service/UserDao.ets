// 用户数据访问对象

import { relationalStore } from '@kit.ArkData'
import { DatabaseHelper } from '../database/DatabaseHelper'
import { TABLE_USER } from '../database/Tables'
import { UserProfile, UserRole, StudentType, Gender, VipLevel } from '../model/UserModel'

export class UserDao {
  private helper: DatabaseHelper = DatabaseHelper.getInstance()

  async insertUser(user: UserProfile): Promise<void> {
    const store = await this.helper.getStore()
    const valueBucket: relationalStore.ValuesBucket = {
      user_id: user.userId,
      phone: user.phone,
      role: user.role,
      student_type: user.studentType ?? '',
      real_name: user.realName ?? '',
      gender: user.gender ?? '',
      birthday: user.birthday ?? '',
      education: user.education ?? '',
      school: user.school ?? '',
      major: user.major ?? '',
      expected_position: user.expectedPosition ?? '',
      expected_salary: user.expectedSalary ?? '',
      current_city: user.currentCity ?? '',
      is_guest: user.isGuest ? 1 : 0,
      avatar: user.avatar ?? '',
      company_name: user.companyName ?? '',
      id_card: user.idCard ?? '',
      business_license: user.businessLicense ?? '',
      vip_level: user.vipLevel ?? VipLevel.NORMAL,
      position_count: user.positionCount ?? 0,
      hr_real_name: user.hrRealName ?? '',
      password: user.password ?? '',
      create_time: Date.now(),
      update_time: Date.now(),
      is_login: 1
    }
    await store.insert(TABLE_USER, valueBucket)
  }

  async updateUser(user: UserProfile): Promise<void> {
    const store = await this.helper.getStore()
    const valueBucket: relationalStore.ValuesBucket = {
      phone: user.phone,
      role: user.role,
      student_type: user.studentType ?? '',
      real_name: user.realName ?? '',
      gender: user.gender ?? '',
      birthday: user.birthday ?? '',
      education: user.education ?? '',
      school: user.school ?? '',
      major: user.major ?? '',
      expected_position: user.expectedPosition ?? '',
      expected_salary: user.expectedSalary ?? '',
      current_city: user.currentCity ?? '',
      is_guest: user.isGuest ? 1 : 0,
      avatar: user.avatar ?? '',
      company_name: user.companyName ?? '',
      id_card: user.idCard ?? '',
      business_license: user.businessLicense ?? '',
      vip_level: user.vipLevel ?? VipLevel.NORMAL,
      position_count: user.positionCount ?? 0,
      hr_real_name: user.hrRealName ?? '',
      password: user.password ?? '',
      update_time: Date.now()
    }
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.equalTo('user_id', user.userId)
    await store.update(valueBucket, predicates)
  }

  async getUserById(userId: string): Promise<UserProfile | null> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.equalTo('user_id', userId)
    const resultSet = await store.query(predicates)
    if (resultSet.goToFirstRow()) {
      return this.rowToUserProfile(resultSet)
    }
    return null
  }

  async getLoggedInUser(): Promise<UserProfile | null> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.equalTo('is_login', 1)
    const resultSet = await store.query(predicates)
    if (resultSet.goToFirstRow()) {
      return this.rowToUserProfile(resultSet)
    }
    return null
  }

  async logoutAll(): Promise<void> {
    const store = await this.helper.getStore()
    const valueBucket: relationalStore.ValuesBucket = { is_login: 0 }
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    await store.update(valueBucket, predicates)
  }

  async deleteUser(userId: string): Promise<void> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.equalTo('user_id', userId)
    await store.delete(predicates)
  }

  async isPhoneBound(phone: string): Promise<boolean> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.equalTo('phone', phone)
    const resultSet = await store.query(predicates)
    const count = resultSet.rowCount
    resultSet.close()
    return count > 0
  }

  async getUserByPhone(phone: string): Promise<UserProfile | null> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.equalTo('phone', phone)
    const resultSet = await store.query(predicates)
    if (resultSet.goToFirstRow()) {
      const user = this.rowToUserProfile(resultSet)
      resultSet.close()
      return user
    }
    resultSet.close()
    return null
  }

  async getUserByPhoneAndPassword(phone: string, password: string): Promise<UserProfile | null> {
    const store = await this.helper.getStore()
    const predicates = new relationalStore.RdbPredicates(TABLE_USER)
    predicates.equalTo('phone', phone)
    predicates.equalTo('password', password)
    const resultSet = await store.query(predicates)
    if (resultSet.goToFirstRow()) {
      const user = this.rowToUserProfile(resultSet)
      resultSet.close()
      return user
    }
    resultSet.close()
    return null
  }

  private rowToUserProfile(row: relationalStore.ResultSet): UserProfile {
    const roleStr = row.getString(row.getColumnIndex('role'))
    const studentTypeStr = row.getString(row.getColumnIndex('student_type'))
    const genderStr = row.getString(row.getColumnIndex('gender'))
    const vipLevelStr = row.getString(row.getColumnIndex('vip_level'))

    return {
      userId: row.getString(row.getColumnIndex('user_id')),
      phone: row.getString(row.getColumnIndex('phone')),
      role: (roleStr === UserRole.RECRUITER ? UserRole.RECRUITER : UserRole.JOB_SEEKER) as UserRole,
      studentType: (studentTypeStr === StudentType.GRADUATING ? StudentType.GRADUATING : StudentType.CURRENT) as StudentType,
      realName: row.getString(row.getColumnIndex('real_name')),
      gender: (genderStr === Gender.MALE ? Gender.MALE : genderStr === Gender.FEMALE ? Gender.FEMALE : Gender.UNKNOWN) as Gender,
      birthday: row.getString(row.getColumnIndex('birthday')),
      education: row.getString(row.getColumnIndex('education')),
      school: row.getString(row.getColumnIndex('school')),
      major: row.getString(row.getColumnIndex('major')),
      expectedPosition: row.getString(row.getColumnIndex('expected_position')),
      expectedSalary: row.getString(row.getColumnIndex('expected_salary')),
      currentCity: row.getString(row.getColumnIndex('current_city')),
      isGuest: row.getLong(row.getColumnIndex('is_guest')) === 1,
      avatar: row.getString(row.getColumnIndex('avatar')),
      companyName: row.getString(row.getColumnIndex('company_name')),
      idCard: row.getString(row.getColumnIndex('id_card')),
      businessLicense: row.getString(row.getColumnIndex('business_license')),
      vipLevel: (vipLevelStr === VipLevel.VIP ? VipLevel.VIP : VipLevel.NORMAL) as VipLevel,
      positionCount: row.getLong(row.getColumnIndex('position_count')),
      hrRealName: row.getString(row.getColumnIndex('hr_real_name')),
      password: row.getString(row.getColumnIndex('password'))
    }
  }
}
