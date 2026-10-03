// Onboarding step 5 "Emergency contacts". The saved list lives in the page's draft; the half-typed contact lives
// here and survives Back/Continue because the page keeps every step alive (only hides the others).

import { Contact, Profile } from '../../model/Profile';
import { validContact, withContact, withoutContact } from '../../onboarding/OnboardingFlow';
import { SecondaryButton } from '../Common';
import { toast } from '../../common/Toast';
import { OnbHeading, OnbInput } from './OnbParts';

@ComponentV2
export struct StepContacts {
  @Param @Require profile: Profile;
  @Event onChange: (profile: Profile) => void = (profile: Profile) => {
  };
  @Local cName: string = '';
  @Local cPhone: string = '';
  @Local cRelation: string = '';

  private add(): void {
    if (!validContact(this.cName, this.cPhone)) {
      toast(this.getUIContext(), $r('app.string.onb_contact_invalid'));
      return;
    }
    this.onChange(withContact(this.profile, this.cName, this.cPhone, this.cRelation));
    this.cName = '';
    this.cPhone = '';
    this.cRelation = '';
  }

  build() {
    Column({ space: 12 }) {
      OnbHeading({ heading: $r('app.string.onb_contacts_title'), subtitle: $r('app.string.onb_contacts_subtitle') })
      OnbInput({
        value: this.cName,
        hint: $r('app.string.onb_contact_name'),
        onInput: (v: string) => {
          this.cName = v;
        }
      })
      OnbInput({
        value: this.cPhone,
        hint: $r('app.string.onb_contact_phone'),
        inputType: InputType.PhoneNumber,
        onInput: (v: string) => {
          this.cPhone = v;
        }
      })
      OnbInput({
        value: this.cRelation,
        hint: $r('app.string.onb_contact_relation'),
        onInput: (v: string) => {
          this.cRelation = v;
        }
      })
      SecondaryButton({
        label: $r('app.string.onb_contact_add'),
        icon: $r('app.media.ic_plus'),
        active: validContact(this.cName, this.cPhone),
        onTap: () => this.add()
      })
      if (this.profile.contacts.length === 0) {
        Text($r('app.string.onb_contacts_empty'))
          .fontSize($r('app.float.font_small'))
          .fontColor($r('app.color.ink_3'))
      }
      ForEach(this.profile.contacts, (c: Contact, i: number) => {
        Row({ space: 8 }) {
          Image($r('app.media.ic_phone')).width(18).height(18).fillColor($r('app.color.brand_accent'))
          Text(`${c.name}${c.relation === '' ? '' : ` (${c.relation})`} · ${c.phone}`)
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.ink'))
            .layoutWeight(1)
          Image($r('app.media.ic_close'))
            .width(18)
            .height(18)
            .fillColor($r('app.color.ink_4'))
            .accessibilityText($r('app.string.a11y_remove'))
            .responseRegion({ x: -15, y: -15, width: 48, height: 48 })
            .onClick(() => this.onChange(withoutContact(this.profile, i)))
        }
        .width('100%')
        .padding($r('app.float.space_sm'))
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.border') })
        .borderRadius($r('app.float.radius_s'))
      }, (c: Contact, i: number) => `${i}-${c.name}-${c.phone}`)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
