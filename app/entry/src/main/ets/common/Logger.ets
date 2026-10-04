import { hilog } from '@kit.PerformanceAnalysisKit';

// Single hilog domain for the whole app. Filter on device with:  hdc hilog | grep CeliaAI
// Messages are logged as public text, so never put health data in them: no medicine names, risk levels, heart
// rates, genotype, contacts or what the user typed. Log ids, counts and kinds instead.
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
