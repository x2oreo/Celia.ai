import { HrSourceKind } from '../model/WatchMetric';

export type SampleCallback = (bpm: number, tsMs: number) => void;
export type ErrorCallback = (message: string) => void;

/** A stream of heart-rate samples. Implementations: watch sensor, simulated scenarios. */
export interface HeartRateSource {
  readonly kind: HrSourceKind;

  start(onSample: SampleCallback, onError: ErrorCallback): void;

  stop(): void;
}
