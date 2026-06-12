import { VerifyCodeDao } from './VerifyCodeDao'

export interface EmailAuthResult {
  success: boolean
  message: string
}

export class EmailAuthService {
  private verifyCodeDao: VerifyCodeDao = new VerifyCodeDao()

  async sendVerifyCode(email: string): Promise<EmailAuthResult> {
    const normalizedEmail = this.normalizeEmail(email)
    if (!this.isValidEmail(normalizedEmail)) {
      return {
        success: false,
        message: '请输入正确的邮箱地址'
      }
    }
    const code = this.generateCode()
    await this.verifyCodeDao.saveCode(normalizedEmail, code, 5)
    return {
      success: true,
      message: `开发模式邮箱验证码：${code}`
    }
  }

  async verifyCode(email: string, code: string): Promise<EmailAuthResult> {
    const normalizedEmail = this.normalizeEmail(email)
    const normalizedCode = code.trim()
    if (!this.isValidEmail(normalizedEmail) || !normalizedCode) {
      return {
        success: false,
        message: '请完整填写邮箱和验证码'
      }
    }
    const ok = await this.verifyCodeDao.verifyCode(normalizedEmail, normalizedCode)
    if (!ok) {
      return {
        success: false,
        message: '邮箱验证码错误或已过期'
      }
    }
    await this.verifyCodeDao.deleteCode(normalizedEmail)
    return {
      success: true,
      message: '邮箱验证成功'
    }
  }

  isValidEmail(email: string): boolean {
    return /^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$/.test(email)
  }

  private normalizeEmail(email: string): string {
    return email.trim().toLowerCase()
  }

  private generateCode(): string {
    return `${Math.floor(Math.random() * 900000) + 100000}`
  }
}
