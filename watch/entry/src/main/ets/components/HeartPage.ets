import { WatchController } from '../controller/WatchController';
import { Theme } from './Theme';

@ComponentV2
export struct HeartPage {
  @Param @Require ctrl: WatchController;

  sourceLabel(): string {
    if (this.ctrl.sourceKind === 'SENSOR') {
      return 'WATCH SENSOR';
    }
    return `DEMO · ${this.ctrl.scenarioLabel}`;
  }

  sourceColor(): string {
    if (this.ctrl.sourceKind === 'SENSOR') {
      return Theme.OK;
    }
    return Theme.WARN;
  }

  /** "bpm · LQT2 · rest · max 110": the limit that applies right now and why. */
  contextLabel(): string {
    if (!this.ctrl.onWrist) {
      return 'bpm';
    }
    return `bpm · ${this.ctrl.limitReason} · max ${this.ctrl.limitHigh}`;
  }

  elapsed(): string {
    const t = this.ctrl.monitoringSec;
    const h = Math.floor(t / 3600);
    const m = Math.floor((t % 3600) / 60);
    const s = t % 60;
    const mm = h > 0 && m < 10 ? `0${m}` : `${m}`;
    return `${h > 0 ? `${h}:` : ''}${mm}:${s < 10 ? '0' : ''}${s}`;
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
        .fontSize(11)
        .fontColor(this.sourceColor())
        .fontWeight(FontWeight.Medium)
        .maxLines(1)

      Row({ space: 6 }) {
        Text('♥').fontSize(22).fontColor(Theme.HEART)
        Text(this.ctrl.bpm > 0 ? `${this.ctrl.bpm}` : '--')
          .fontSize(48)
          .fontWeight(FontWeight.Bold)
          .fontColor(Theme.TEXT)
      }
      .alignItems(VerticalAlign.Center)

      Text(this.contextLabel())
        .fontSize(12)
        .fontColor(Theme.MUTED)

      if (this.ctrl.riskyDrug.length > 0) {
        Text(`⚠ ${this.ctrl.riskyDrug}: QT risk`)
          .fontSize(10)
          .fontColor(Theme.WARN)
          .maxLines(1)
      }

      if (this.ctrl.statusText.length > 0) {
        Text(this.ctrl.statusText)
          .fontSize(10)
          .fontColor(Theme.WARN)
          .maxLines(2)
          .textAlign(TextAlign.Center)
          .width(150)
      }

      Row({ space: 6 }) {
        Circle().width(8).height(8).fill(this.ctrl.running ? Theme.HEART : Theme.MUTED)
        Text(this.ctrl.running ? `Monitoring · ${this.elapsed()}` : 'Paused')
          .fontSize(13)
          .fontColor(Theme.TEXT)
      }
      .height(32)
      .padding({ left: 14, right: 14 })
      .margin({ top: 6 })
      .borderRadius(16)
      .backgroundColor(Theme.CARD)

      Row({ space: 6 }) {
        Circle().width(6).height(6).fill(this.syncColor())
        Text(this.syncLabel()).fontSize(10).fontColor(Theme.MUTED)
      }
      .margin({ top: 2 })
    }
    .width('100%')
    .height('100%')
    .padding({ bottom: 14 })
    .justifyContent(FlexAlign.Center)
  }
}
