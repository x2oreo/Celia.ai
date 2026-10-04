// Home-screen service cards (DESIGN.md §11 widgets v2, B6, B13, B15): the agent, next dose, resting heart rate,
// "Can I take this?", feeling diary, Medical alert and Medical ID. The card data is a snapshot written by the app
// (widget/WidgetSync.ets); nothing here calls a model or the network. Every 30 minutes the extension moves the Next
// dose card on by the clock from the stored schedule, so "Due" and "Missed" stay true while the app is closed.

import { formBindingData, FormExtensionAbility, formInfo, formProvider } from '@kit.FormKit';
import { common, Want } from '@kit.AbilityKit';
import { DoseInputs, forCard, isWide, placeForm, readDoseInputs, readSnapshot, removeForm } from '../widget/WidgetData';
import { applyDose, WidgetSnapshot } from '../widget/WidgetSnapshot';

function current(ctx: common.Context): WidgetSnapshot {
  const s: WidgetSnapshot = readSnapshot(ctx);
  const d: DoseInputs = readDoseInputs(ctx);
  applyDose(s, d.reminders, d.logs, Date.now());
  return s;
}

export default class EntryFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    const params: Record<string, Object> = want.parameters ?? {};
    const id: string = (params[formInfo.FormParam.IDENTITY_KEY] as string) ?? '';
    const dim: number = (params[formInfo.FormParam.DIMENSION_KEY] as number) ?? formInfo.FormDimension.Dimension_2_2;
    const wide: boolean = dim === formInfo.FormDimension.Dimension_2_4;
    if (id !== '') {
      placeForm(this.context, id, wide);
    }
    return formBindingData.createFormBindingData(forCard(current(this.context), wide));
  }

  onUpdateForm(formId: string, wantParams?: Record<string, Object>): void {
    let wide: boolean = isWide(this.context, formId);
    const dim: Object | undefined = wantParams?.[formInfo.FormParam.DIMENSION_KEY];
    if (dim !== undefined) {
      // The user resized the card.
      wide = (dim as number) === formInfo.FormDimension.Dimension_2_4;
      placeForm(this.context, formId, wide);
    }
    formProvider.updateForm(formId, formBindingData.createFormBindingData(forCard(current(this.context), wide)))
      .catch(() => {
        // The card keeps its last data; the next update or app refresh tries again.
      });
  }

  onRemoveForm(formId: string): void {
    removeForm(this.context, formId);
  }

  onAcquireFormState(want: Want): formInfo.FormState {
    return formInfo.FormState.READY;
  }
}
