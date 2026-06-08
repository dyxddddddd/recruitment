import { common } from '@kit.AbilityKit'
import { fileIo as fs, fileUri } from '@kit.CoreFileKit'
import { util } from '@kit.ArkTS'

export class LocalFileService {
  static async readText(uri: string, context?: common.UIAbilityContext): Promise<string> {
    const bytes = await LocalFileService.readBytes(uri, context)
    const decoder = util.TextDecoder.create('utf-8')
    return decoder.decodeWithStream(bytes, { stream: false })
  }

  static async readBase64(uri: string, context?: common.UIAbilityContext): Promise<string> {
    const bytes = await LocalFileService.readBytes(uri, context)
    const helper = new util.Base64Helper()
    return helper.encodeToStringSync(bytes)
  }

  static decodeDisplayName(text: string): string {
    const normalized = LocalFileService.stripFileScheme(text)
    const segments = normalized.split('/')
    const rawName = segments.length > 0 ? segments[segments.length - 1] : text
    return LocalFileService.safeDecode(rawName)
  }

  static async copyToSandbox(uri: string, context: common.UIAbilityContext): Promise<string> {
    const rawName = LocalFileService.decodeDisplayName(uri)
    const dotIndex = rawName.lastIndexOf('.')
    const extension = dotIndex >= 0 ? rawName.substring(dotIndex) : ''
    const targetPath = `${context.cacheDir}/import_${Date.now()}${extension}`
    const candidates = LocalFileService.buildUriCandidates(uri)
    let lastError: Error | null = null

    for (let i = 0; i < candidates.length; i++) {
      const candidate = candidates[i]
      if (!candidate) {
        continue
      }
      try {
        await fs.copyFile(candidate, targetPath)
        return targetPath
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(`${error}`)
      }
    }

    const message = lastError ? lastError.message : 'Cannot copy selected file'
    const debugInfo = LocalFileService.summarizeCandidates(candidates)
    console.error(`copyToSandbox failed, uri=${uri}, candidates=${debugInfo}, message=${message}`)
    throw new Error(`无法读取所选文件：${message}\n原始URI：${uri}\n候选路径：${debugInfo}`)
  }

  private static async readBytes(uri: string, context?: common.UIAbilityContext): Promise<Uint8Array> {
    const candidates = LocalFileService.buildUriCandidates(uri)
    let lastError: Error | null = null

    for (let i = 0; i < candidates.length; i++) {
      const candidate = candidates[i]
      if (!candidate) {
        continue
      }
      try {
        const file = await fs.open(candidate, fs.OpenMode.READ_ONLY)
        try {
          const stat = await fs.stat(file.fd)
          const buffer = new ArrayBuffer(Number(stat.size))
          await fs.read(file.fd, buffer)
          return new Uint8Array(buffer)
        } finally {
          await fs.close(file)
        }
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(`${error}`)
      }
    }

    if (context) {
      try {
        const sandboxPath = await LocalFileService.copyToSandbox(uri, context)
        return LocalFileService.readBytes(sandboxPath)
      } catch (error) {
        lastError = error instanceof Error ? error : new Error(`${error}`)
      }
    }

    const message = lastError ? lastError.message : 'Cannot open selected file'
    const debugInfo = LocalFileService.summarizeCandidates(candidates)
    console.error(`readBytes failed, uri=${uri}, candidates=${debugInfo}, message=${message}`)
    throw new Error(`无法读取所选文件：${message}\n原始URI：${uri}\n候选路径：${debugInfo}`)
  }

  private static buildUriCandidates(uri: string): string[] {
    const candidates: string[] = []
    LocalFileService.pushCandidate(candidates, uri)

    const resolvedPath = LocalFileService.resolvePickerPath(uri)
    LocalFileService.pushCandidate(candidates, resolvedPath)
    LocalFileService.pushCandidate(candidates, LocalFileService.stripFileScheme(resolvedPath))
    LocalFileService.pushCandidate(candidates, LocalFileService.safeDecode(resolvedPath))

    const decodedUri = LocalFileService.safeDecode(uri)
    LocalFileService.pushCandidate(candidates, decodedUri)

    const resolvedDecodedPath = LocalFileService.resolvePickerPath(decodedUri)
    LocalFileService.pushCandidate(candidates, resolvedDecodedPath)
    LocalFileService.pushCandidate(candidates, LocalFileService.stripFileScheme(resolvedDecodedPath))
    LocalFileService.pushCandidate(candidates, LocalFileService.safeDecode(resolvedDecodedPath))

    const strippedUri = LocalFileService.stripFileScheme(uri)
    LocalFileService.pushCandidate(candidates, strippedUri)

    const decodedStrippedUri = LocalFileService.safeDecode(strippedUri)
    LocalFileService.pushCandidate(candidates, decodedStrippedUri)

    return candidates
  }

  private static pushCandidate(target: string[], value: string): void {
    const trimmed = value.trim()
    if (!trimmed) {
      return
    }
    if (target.indexOf(trimmed) < 0) {
      target.push(trimmed)
    }
  }

  private static stripFileScheme(uri: string): string {
    if (uri.startsWith('file://')) {
      return uri.substring('file://'.length)
    }
    return uri
  }

  private static safeDecode(value: string): string {
    try {
      return decodeURIComponent(value)
    } catch (_error) {
      return value
    }
  }

  private static resolvePickerPath(uri: string): string {
    try {
      return new fileUri.FileUri(uri).path
    } catch (_error) {
      return ''
    }
  }

  private static summarizeCandidates(candidates: string[]): string {
    return candidates.slice(0, 6).join(' | ')
  }
}
