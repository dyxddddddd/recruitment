import { common } from '@kit.AbilityKit'
import { photoAccessHelper } from '@kit.MediaLibraryKit'
import picker from '@ohos.file.picker'
import { LocalFileService } from './LocalFileService'

export interface PickedDocument {
  uri: string
  fileName: string
}

export class PickerService {
  static async pickSingleImage(): Promise<string> {
    const photoPicker = new photoAccessHelper.PhotoViewPicker()
    const options = new photoAccessHelper.PhotoSelectOptions()
    options.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE
    options.maxSelectNumber = 1
    const result = await photoPicker.select(options)
    const photoUris: string[] = result.photoUris || []
    const selected: string = photoUris.length > 0 ? photoUris[0] : ''
    if (!selected) {
      throw new Error('No image selected')
    }
    return selected
  }

  static async pickSingleDocument(context?: common.UIAbilityContext): Promise<PickedDocument> {
    const documentPicker = context ? new picker.DocumentViewPicker(context) : new picker.DocumentViewPicker()
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    options.fileSuffixFilters = ['.pdf', '.txt', '.md']
    const uris: string[] = await documentPicker.select(options)
    const uri: string = uris.length > 0 ? uris[0] : ''
    if (!uri) {
      throw new Error('No document selected')
    }
    const fileName: string = LocalFileService.decodeDisplayName(uri)
    return {
      uri: uri,
      fileName: fileName
    }
  }
}
