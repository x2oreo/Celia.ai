// "How are you feeling?" (B15): one mood tap plus an optional note, saved to the diary (an AppEvent of kind
// FEELING). Manual, no AI, stays on this phone. A low mood offers the symptom log; it never starts SOS by itself
// (red flags live in the symptom log, model/SymptomEntry isRedFlag).

import { AppEvent } from '../model/AppEvent';
import { FEELING_NOTE_MAX, FeelingEntry, isLowMood, Mood, MOODS, moodLabel, parseFeeling } from '../diary/Diary';
import { DiaryStore } from '../diary/DiaryStore';
import { Routes } from '../common/Routes';
import { dateTime } from '../common/Format';
import { toast } from '../common/Toast';
import { PrimaryButton, QuietButton, SectionHeader } from '../components/Common';

@ComponentV2
export struct FeelingPage {
  @Consumer('navStack') navStack: NavPathStack = new NavPathStack();
  @Local mood: Mood | undefined = undefined;
  @Local note: string = '';
  @Local recent: AppEvent[] = [];
  @Local loaded: boolean = false;
  private saving: boolean = false;

  aboutToAppear(): void {
    this.load();
  }

  private async load(): Promise<void> {
    this.recent = await DiaryStore.recent(10);
    this.loaded = true;
  }

  private async save(): Promise<void> {
    if (this.mood === undefined || this.saving) {
      return;
    }
    this.saving = true;
    try {
      await DiaryStore.add(this.mood, this.note);
      toast(this.getUIContext(), $r('app.string.doc_feel_saved'));
      this.note = '';
      await this.load();
    } finally {
      this.saving = false;
    }
  }

  @Builder
  moodChip(m: Mood) {
    Text(moodLabel(m))
      .fontSize($r('app.float.font_button'))
      .fontWeight(FontWeight.Medium)
      .fontColor(this.mood === m ? $r('app.color.chat_user_text') : $r('app.color.ink'))
      .height($r('app.float.chip_height'))
      .padding({ left: 18, right: 18 })
      .margin({ right: 8, bottom: 8 })
      .backgroundColor(this.mood === m ? $r('app.color.chat_user_bg') : $r('app.color.surface'))
      .border({ width: this.mood === m ? 0 : 1.5, color: $r('app.color.border_strong') })
      .borderRadius(100)
      .onClick(() => {
        this.mood = m;
      })
  }

  private describe(e: AppEvent): string {
    const f: FeelingEntry | undefined = parseFeeling(e.detail);
    if (f === undefined) {
      return dateTime(e.ts, Date.now());
    }
    return `${dateTime(e.ts, Date.now())} · ${moodLabel(f.mood)}${f.note === '' ? '' : ` · ${f.note}`}`;
  }

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 12 }) {
          Text($r('app.string.doc_feel_intro'))
            .fontSize($r('app.float.font_body'))
            .fontColor($r('app.color.ink_3'))
            .width('100%')
          Flex({ wrap: FlexWrap.Wrap }) {
            ForEach(MOODS, (m: Mood) => {
              this.moodChip(m)
            }, (m: Mood) => m)
          }
          .width('100%')

          if (this.mood !== undefined && isLowMood(this.mood)) {
            Column({ space: 8 }) {
              Text($r('app.string.doc_feel_low'))
                .fontSize($r('app.float.font_small'))
                .fontColor($r('app.color.ink_2'))
              QuietButton({
                label: $r('app.string.doc_feel_log_symptom'), onTap: () => {
                  this.navStack.pushPathByName(Routes.SYMPTOM_LOG, null);
                }
              })
            }
            .width('100%')
            .alignItems(HorizontalAlign.Start)
            .padding(14)
            .backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: $r('app.color.border') })
            .borderRadius($r('app.float.radius_m'))
          }

          TextArea({ text: this.note, placeholder: $r('app.string.doc_feel_note_hint') })
            .maxLength(FEELING_NOTE_MAX)
            .height(80)
            .backgroundColor($r('app.color.surface_alt'))
            .onChange((v: string) => {
              this.note = v;
            })
          PrimaryButton({
            label: $r('app.string.doc_feel_save'), active: this.mood !== undefined, onTap: () => {
              this.save();
            }
          })

          SectionHeader({ title: $r('app.string.doc_feel_recent') })
          if (this.loaded && this.recent.length === 0) {
            Text($r('app.string.doc_feel_empty'))
              .fontSize($r('app.float.font_small'))
              .fontColor($r('app.color.ink_3'))
              .width('100%')
          }
          ForEach(this.recent, (e: AppEvent) => {
            Text(this.describe(e))
              .fontSize($r('app.float.font_small'))
              .fontColor($r('app.color.ink'))
              .width('100%')
              .padding(12)
              .backgroundColor($r('app.color.surface'))
              .border({ width: 1, color: $r('app.color.border') })
              .borderRadius($r('app.float.radius_s'))
          }, (e: AppEvent) => `${e.id}`)
        }
        .padding({ left: 16, right: 16, bottom: 32 })
        .width('100%')
      }
      .width('100%')
      .height('100%')
      .align(Alignment.Top)
      .scrollBar(BarState.Off)
    }
    .title($r('app.string.doc_feel_title'))
    .backgroundColor($r('app.color.bg'))
  }
}
