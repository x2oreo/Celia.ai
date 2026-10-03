// Copy plain text to the system pasteboard (no permission needed for writing).

import { pasteboard } from '@kit.BasicServicesKit';
import { Logger } from './Logger';

const log: Logger = new Logger('Clipboard');

export async function copyText(text: string): Promise<boolean> {
  try {
    const data: pasteboard.PasteData = pasteboard.createData(pasteboard.MIMETYPE_TEXT_PLAIN, text);
    await pasteboard.getSystemPasteboard().setData(data);
    return true;
  } catch (e) {
    log.error(`copy failed: ${JSON.stringify(e)}`);
    return false;
  }
}
