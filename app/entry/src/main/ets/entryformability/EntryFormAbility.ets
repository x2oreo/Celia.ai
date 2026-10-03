// Home-screen service cards (design B6): "Can I take this?" (2×2) and Medical alert (2×4).
// The card data is a snapshot written by the app (widget/WidgetSync.ets); nothing here calls a model.

import { formBindingData, FormExtensionAbility, formInfo } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { readAlertCard, readFormIds, writeFormIds } from '../widget/WidgetData';

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const id: string = want.parameters === undefined ? '' :
      (want.parameters[formInfo.FormParam.IDENTITY_KEY] as string ?? '');
    if (id !== '') {
      const ids: string[] = readFormIds(this.context);
      if (!ids.includes(id)) {
        ids.push(id);
        writeFormIds(this.context, ids);
      }
    }
    return formBindingData.createFormBindingData(readAlertCard(this.context));
  }

  onRemoveForm(formId: string): void {
    writeFormIds(this.context, readFormIds(this.context).filter((x: string) => x !== formId));
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
