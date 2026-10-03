import { hilog } from '@kit.PerformanceAnalysisKit';

// Single hilog domain for the whole app. Filter on device with:  hdc hilog | grep CeliaAI
const DOMAIN: number = 0xC1A0;
const PREFIX: string = 'CeliaAI';

export class Logger {
  private tag: string;

  constructor(module: string) {
    this.tag = `${PREFIX}/${module}`;
  }

  debug(message: string): void {
    hilog.debug(DOMAIN, this.tag, '%{public}s', message);
  }

  info(message: string): void {
    hilog.info(DOMAIN, this.tag, '%{public}s', message);
  }

  warn(message: string): void {
    hilog.warn(DOMAIN, this.tag, '%{public}s', message);
  }

  error(message: string): void {
    hilog.error(DOMAIN, this.tag, '%{public}s', message);
  }
}
