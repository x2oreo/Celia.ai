import { WatchController } from '../controller/WatchController';
import { Theme } from './Theme';

@ComponentV2
export struct HeartPage {
  @Param @Require ctrl: WatchController;

  sourceLabel(): string {
    if (this.ctrl.sourceKind === 'SENSOR') {
      return 'WATCH SENSOR';
    }
    if (this.ctrl.sourceKind === 'BRIDGE') {
      return 'GT 6 PRO LIVE';
    }
    return `DEMO · ${this.ctrl.scenarioLabel}`;
  }

  sourceColor(): string {
    if (this.ctrl.sourceKind === 'SENSOR') {
      return Theme.OK;
    }
    if (this.ctrl.sourceKind === 'BRIDGE') {
      return Theme.INFO;
    }
    return Theme.WARN;
  }

  elapsed(): string {
    const m = Math.floor(this.ctrl.elapsedSec / 60);
    const s = this.ctrl.elapsedSec % 60;
    return `${m}:${s < 10 ? '0' : ''}${s}`;
  }

  syncLabel(): string {
    switch (this.ctrl.syncState) {
      case 'OK':
        return 'synced';
      case 'PENDING':
        return `${this.ctrl.pending} to send`;
      case 'ERROR':
        return `offline · ${this.ctrl.pending} queued`;
      default:
        return `no server · ${this.ctrl.pending} saved`;
    }
  }

  syncColor(): string {
    switch (this.ctrl.syncState) {
      case 'OK':
        return Theme.OK;
      case 'PENDING':
        return Theme.INFO;
      case 'ERROR':
        return Theme.DANGER;
      default:
        return Theme.MUTED;
    }
  }

  build() {
    Column({ space: 4 }) {
      Text(this.sourceLabel())
        .fontSize(13)
        .fontColor(this.sourceColor())
        .fontWeight(FontWeight.Medium)
        .maxLines(1)

      Row({ space: 6 }) {
        Text('♥').fontSize(30).fontColor(Theme.HEART)
        Text(this.ctrl.bpm > 0 ? `${this.ctrl.bpm}` : '--')
          .fontSize(64)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
      }
      .alignItems(VerticalAlign.Center)

      Text(this.ctrl.running ? `bpm · ${this.elapsed()}` : 'bpm')
        .fontSize(14)
        .fontColor(Theme.MUTED)

      if (this.ctrl.statusText.length > 0) {
        Text(this.ctrl.statusText)
          .fontSize(12)
          .fontColor(Theme.WARN)
          .maxLines(2)
          .textAlign(TextAlign.Center)
          .width('70%')
      }

      Button(this.ctrl.running ? 'Stop' : 'Start')
        .fontSize(18)
        .fontWeight(FontWeight.Medium)
        .width(120)
        .height(44)
        .margin({ top: 6 })
        .backgroundColor(this.ctrl.running ? Theme.CARD : Theme.HEART)
        .fontColor(Theme.TEXT)
        .onClick(() => {
          this.ctrl.toggle();
        })

      Row({ space: 6 }) {
        Circle().width(8).height(8).fill(this.syncColor())
        Text(this.syncLabel()).fontSize(12).fontColor(Theme.MUTED)
      }
      .margin({ top: 4 })
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
  }
}
