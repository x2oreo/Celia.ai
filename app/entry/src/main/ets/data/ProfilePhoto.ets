// The user's profile photo, for the Settings avatar and the emergency card (so a helper can match the card to the
// person). Phone only: a square JPEG in the app's files dir (encrypted at rest with the user's lock screen), never
// synced, never put in the card QR or the web card. Each save gets a new file name, so an Image showing the old
// one reloads; older files are deleted. Whether the card shows it is CardField.PHOTO in Profile.hiddenOnCard.

import { common } from '@kit.AbilityKit';
import { fileIo } from '@kit.CoreFileKit';
import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { Listeners } from '../common/Listeners';
import { Logger } from '../common/Logger';

const log: Logger = new Logger('ProfilePhoto');
const PREFIX: string = 'profile_photo_';
const SIDE: number = 512;        // stored size in px, square
const QUALITY: number = 85;

export class ProfilePhoto {
  private static dir: string = '';
  private static current: string = '';   // file name, '' = no photo
  private static changes: Listeners<string> = new Listeners<string>();

  static init(context: common.Context): void {
    ProfilePhoto.dir = context.filesDir;
    try {
      const names: string[] = fileIo.listFileSync(ProfilePhoto.dir)
        .filter((n: string) => n.startsWith(PREFIX))
        .sort();
      ProfilePhoto.current = names.length > 0 ? names[names.length - 1] : '';
    } catch (e) {
      log.warn(`list failed: ${JSON.stringify(e)}`);
    }
  }

  static exists(): boolean {
    return ProfilePhoto.current !== '';
  }

  // file:// uri for Image(), '' when there is no photo.
  static uri(): string {
    return ProfilePhoto.current === '' ? '' : `file://${ProfilePhoto.dir}/${ProfilePhoto.current}`;
  }

  // Called with the new uri ('' after remove).
  static onChange(listener: (uri: string) => void): () => void {
    return ProfilePhoto.changes.add(listener);
  }

  // Opens the system photo picker (no permission needed). True when a photo was picked and saved.
  static async pick(): Promise<boolean> {
    const opts: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    opts.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    opts.maxSelectNumber = 1;
    const res: photoAccessHelper.PhotoSelectResult = await new photoAccessHelper.PhotoViewPicker().select(opts);
    if (res.photoUris.length === 0) {
      return false;
    }
    await ProfilePhoto.saveFrom(res.photoUris[0]);
    return true;
  }

  // Centre-crops to a square, scales to SIDE and stores it as JPEG.
  static async saveFrom(uri: string): Promise<void> {
    if (ProfilePhoto.dir === '') {
      throw new Error('ProfilePhoto.init was not called');
    }
    const src: fileIo.File = fileIo.openSync(uri, fileIo.OpenMode.READ_ONLY);
    let pm: image.PixelMap | undefined = undefined;
    const packer: image.ImagePacker = image.createImagePacker();
    try {
      pm = await image.createImageSource(src.fd).createPixelMap();
      const info: image.ImageInfo = await pm.getImageInfo();
      const side: number = Math.min(info.size.width, info.size.height);
      const region: image.Region = {
        x: Math.floor((info.size.width - side) / 2),
        y: Math.floor((info.size.height - side) / 2),
        size: { width: side, height: side }
      };
      await pm.crop(region);
      if (side > SIDE) {
        await pm.scale(SIDE / side, SIDE / side);
      }
      const opts: image.PackingOption = { format: 'image/jpeg', quality: QUALITY };
      const data: ArrayBuffer = await packer.packToData(pm, opts);
      const name: string = `${PREFIX}${Date.now()}.jpg`;
      const out: fileIo.File = fileIo.openSync(`${ProfilePhoto.dir}/${name}`,
        fileIo.OpenMode.CREATE | fileIo.OpenMode.WRITE_ONLY | fileIo.OpenMode.TRUNC);
      try {
        fileIo.writeSync(out.fd, data);
      } finally {
        fileIo.closeSync(out);
      }
      ProfilePhoto.deleteAllBut(name);
      ProfilePhoto.current = name;
      ProfilePhoto.changes.emit(ProfilePhoto.uri());
    } finally {
      fileIo.closeSync(src);
      packer.release();
      if (pm !== undefined) {
        pm.release();
      }
    }
  }

  static remove(): void {
    if (ProfilePhoto.dir === '') {
      return;
    }
    ProfilePhoto.deleteAllBut('');
    ProfilePhoto.current = '';
    ProfilePhoto.changes.emit('');
  }

  private static deleteAllBut(keep: string): void {
    try {
      for (const n of fileIo.listFileSync(ProfilePhoto.dir)) {
        if (n.startsWith(PREFIX) && n !== keep) {
          fileIo.unlinkSync(`${ProfilePhoto.dir}/${n}`);
        }
      }
    } catch (e) {
      log.warn(`cleanup failed: ${JSON.stringify(e)}`);
    }
  }
}
