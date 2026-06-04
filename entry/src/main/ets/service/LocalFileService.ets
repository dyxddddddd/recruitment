import { fileIo as fs } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'

export class LocalFileService {
  static async readText(uri: string): Promise<string> {
    const file = await fs.open(uri, fs.OpenMode.READ_ONLY)
    try {
      const stat = await fs.stat(file.fd)
      const bytes = new Uint8Array(Number(stat.size))
      await fs.read(file.fd, bytes)
      const decoder = util.TextDecoder.create('utf-8')
      return decoder.decodeWithStream(bytes, { stream: false })
    } finally {
      await fs.close(file)
    }
  }

  static async readBase64(uri: string): Promise<string> {
    const file = await fs.open(uri, fs.OpenMode.READ_ONLY)
    try {
      const stat = await fs.stat(file.fd)
      const bytes = new Uint8Array(Number(stat.size))
      await fs.read(file.fd, bytes)
      const helper = new util.Base64Helper()
      return helper.encodeToStringSync(bytes)
    } finally {
      await fs.close(file)
    }
  }
}
