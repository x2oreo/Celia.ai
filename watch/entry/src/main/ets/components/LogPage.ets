import { WatchController } from '../controller/WatchController';
import { SymptomKind } from '../model/WatchMetric';
import { Theme } from './Theme';

@ComponentV2
export struct LogPage {
  @Param @Require ctrl: WatchController;

  toast(msg: string): void {
    try {
      this.getUIContext().getPromptAction().showToast({ message: msg, duration: 1500 });
    } catch (e) {
      // A missing toast is harmless; the metric is already queued.
    }
  }

  @Builder
  symptomButton(label: string, kind: SymptomKind) {
    Button(label)
      .fontSize(11)
      .width(74)
      .height(30)
      .padding({ left: 2, right: 2 })
      .backgroundColor(Theme.CARD)
      .fontColor(Theme.TEXT)
      .onClick(() => {
        this.ctrl.logSymptom(kind);
        this.toast('Logged. Tell your doctor.');
      })
  }

  build() {
    Column({ space: 8 }) {
      Text('I feel unwell').fontSize(16).fontColor(Theme.HEART).fontWeight(FontWeight.Medium)
      Row({ space: 8 }) {
        this.symptomButton('Palpitations', 'palpitations')
        this.symptomButton('Dizzy', 'dizziness')
      }
      Row({ space: 8 }) {
        this.symptomButton('Fainted', 'fainting')
        this.symptomButton('Other', 'other')
      }
      Button(`Took ${this.ctrl.medicationName}`)
        .fontSize(12)
        .width(120)
        .height(30)
        .margin({ top: 2 })
        .backgroundColor(Theme.OK)
        .fontColor('#000000')
        .onClick(() => {
          this.ctrl.logMedication();
          this.toast('Medication logged');
        })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
