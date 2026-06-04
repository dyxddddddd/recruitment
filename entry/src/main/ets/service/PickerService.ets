import { photoAccessHelper } from '@kit.MediaLibraryKit'
import picker from '@ohos.file.picker'

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

  static async pickSingleDocument(): Promise<PickedDocument> {
    const documentPicker = new picker.DocumentViewPicker()
    const options = new picker.DocumentSelectOptions()
    options.maxSelectNumber = 1
    options.fileSuffixFilters = ['.pdf', '.txt', '.md']
    const uris: string[] = await documentPicker.select(options)
    const uri: string = uris.length > 0 ? uris[0] : ''
    if (!uri) {
      throw new Error('No document selected')
    }
    const slashIndex: number = uri.lastIndexOf('/')
    const fileName: string = slashIndex >= 0 ? uri.substring(slashIndex + 1) : uri
    return {
      uri: uri,
      fileName: fileName
    }
  }
}
