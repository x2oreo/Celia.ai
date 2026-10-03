// System share sheet for plain text (SMS, messengers, e-mail, notes…). No permissions needed.

import { common } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { Logger } from './Logger';

const log: Logger = new Logger('Share');

export async function shareText(ctx: common.UIAbilityContext, title: string, text: string): Promise<boolean> {
  try {
    const record: systemShare.SharedRecord = {
      utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,
      content: text,
      title: title
    };
    const controller: systemShare.ShareController = new systemShare.ShareController(new systemShare.SharedData(record));
    const options: systemShare.ShareControllerOptions = {};
    await controller.show(ctx, options);
    return true;
  } catch (e) {
    log.error(`share failed: ${JSON.stringify(e)}`);
    return false;
  }
}
