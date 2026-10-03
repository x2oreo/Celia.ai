// Health metrics (DESIGN.md §6.10): the watch numbers per day, the usual range of each, the fixed-rule status
// (good / okay / worth a look) and the chart geometry. Pure and unit-tested. Nothing here is a diagnosis and nothing
// here measures QT: the status is a comparison with a reference range or with the user's own earlier days.

import { VitalsSample } from '../model/Vitals';
import { WatchVitalsDay } from '../model/WatchData';
import { TrendDay } from './Trends';

export type MetricKind = 'HEART_RATE' | 'RESTING_HR' | 'HRV' | 'SPO2' | 'BREATHING' | 'SLEEP' | 'STEPS' | 'STRESS';

export const METRIC_KINDS: MetricKind[] = ['HEART_RATE', 'RESTING_HR', 'HRV', 'SPO2', 'BREATHING', 'SLEEP', 'STEPS',
  'STRESS'];

/** Signals Huawei watches measure but watch apps can't read yet: the watch simulates them, so they are always labelled. */
export const MOCKED_KINDS: MetricKind[] = ['HRV', 'SPO2', 'BREATHING'];

export type ChartForm = 'LINE' | 'RANGE' | 'BARS';

export const NO_VALUE: number = -1;

export interface MetricDay {
  day: string;     // YYYY-MM-DD, or a clock text for the live line
  value: number;   // NO_VALUE when the watch has no reading that day
  lo: number;      // lowest reading of the day (RANGE), else NO_VALUE
  hi: number;      // highest reading of the day (RANGE), else NO_VALUE
}

export interface MetricSeries {
  kind: MetricKind;
  days: MetricDay[];   // one per calendar day, oldest first
  simulated: boolean;
}

/** The usual range: inside lo..hi is good, inside okLo..okHi is okay, beyond that is worth a look. */
export interface MetricBand {
  lo: number;
  hi: number;
  okLo: number;
  okHi: number;
  personal: boolean;   // from the user's own earlier days, not a fixed reference
}

export type StatusLevel = 'GOOD' | 'OKAY' | 'ATTENTION' | 'NONE';

export type StatusReason = 'IN_RANGE' | 'SLIGHTLY_HIGH' | 'SLIGHTLY_LOW' | 'HIGH' | 'LOW' | 'NO_DATA';

export type Direction = 'UP' | 'DOWN' | 'STEADY' | 'NONE';

export interface MetricStatus {
  level: StatusLevel;
  reason: StatusReason;
  direction: Direction;   // last 7 days against the days before
  delta: number;          // size of that change, never negative
  value: number;          // the reading the level is about
  band: MetricBand;
}

export interface MetricStats {
  avg: number;
  min: number;
  max: number;
  count: number;   // days with a reading
}

export interface MetricScale {
  min: number;
  max: number;
  ticks: number[];
}

export interface ChartPoint {
  index: number;   // position in days
  x: number;
  y: number;
  yLo: number;     // y of the day's lowest reading (RANGE), else y
  yHi: number;
}

/** No upper limit: more is never worse (HRV, steps). */
export const OPEN: number = 1000000;

const RECENT_DAYS: number = 2;
const MIN_BASELINE_DAYS: number = 5;
const CHANGE_DAYS: number = 7;
const MIN_CHANGE_DAYS: number = 3;
const MONTHS: string[] = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const WEEKDAYS: string[] = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
const NICE_STEPS: number[] = [0.5, 1, 2, 5, 10, 20, 25, 50, 100, 200, 250, 500, 1000, 2000, 2500, 5000, 10000, 20000];

export function hasValue(d: MetricDay): boolean {
  return d.value >= 0;
}

export function metricDay(day: string, value: number, lo: number = NO_VALUE, hi: number = NO_VALUE): MetricDay {
  const d: MetricDay = { day: day, value: value, lo: lo, hi: hi };
  return d;
}

export function chartForm(kind: MetricKind): ChartForm {
  if (kind === 'HEART_RATE') {
    return 'RANGE';
  }
  return kind === 'SLEEP' || kind === 'STEPS' || kind === 'STRESS' ? 'BARS' : 'LINE';
}

export function unitText(kind: MetricKind): string {
  switch (kind) {
    case 'HRV':
      return 'ms';
    case 'SPO2':
      return '%';
    case 'BREATHING':
      return '/min';
    case 'SLEEP':
      return 'h';
    case 'STEPS':
      return 'steps';
    case 'STRESS':
      return 'min';
    default:
      return 'bpm';
  }
}

function round1(v: number): number {
  return Math.round(v * 10) / 10;
}

function thousands(n: number): string {
  const s: string = `${Math.round(n)}`;
  return s.length > 3 ? `${s.substring(0, s.length - 3)},${s.substring(s.length - 3)}` : s;
}

/** "–" for no reading, one decimal for hours, a thousands comma for steps, whole numbers otherwise. */
export function formatValue(kind: MetricKind, v: number): string {
  if (v < 0) {
    return '–';
  }
  if (kind === 'SLEEP') {
    return round1(v).toFixed(1);
  }
  return kind === 'STEPS' ? thousands(v) : `${Math.round(v)}`;
}

/** YYYY-MM-DD → "Thu 1 Oct" (or "1 Oct" when `weekday` is false). Anything else is returned as is. */
export function dayText(day: string, weekday: boolean): string {
  if (day.length !== 10 || day.charAt(4) !== '-') {
    return day;
  }
  const y: number = parseInt(day.substring(0, 4));
  const m: number = parseInt(day.substring(5, 7));
  const d: number = parseInt(day.substring(8, 10));
  if (isNaN(y) || isNaN(m) || isNaN(d) || m < 1 || m > 12) {
    return day;
  }
  const short: string = `${d} ${MONTHS[m - 1]}`;
  return weekday ? `${WEEKDAYS[new Date(y, m - 1, d).getDay()]} ${short}` : short;
}

function valuesOf(days: MetricDay[]): number[] {
  return days.filter((d: MetricDay) => hasValue(d)).map((d: MetricDay) => d.value);
}

function mean(values: number[]): number {
  let sum: number = 0;
  for (const v of values) {
    sum += v;
  }
  return values.length === 0 ? 0 : sum / values.length;
}

function median(values: number[]): number {
  const s: number[] = values.slice().sort((a: number, b: number) => a - b);
  const mid: number = Math.floor(s.length / 2);
  return s.length % 2 === 1 ? s[mid] : (s[mid - 1] + s[mid]) / 2;
}

/** The latest reading, or NO_VALUE. */
export function lastValue(days: MetricDay[]): number {
  const i: number = lastIndex(days);
  return i < 0 ? NO_VALUE : days[i].value;
}

export function lastIndex(days: MetricDay[]): number {
  for (let i = days.length - 1; i >= 0; i--) {
    if (hasValue(days[i])) {
      return i;
    }
  }
  return -1;
}

/** The user's own usual value: median of the days before the last two. NO_VALUE with fewer than five such days. */
export function baselineOf(days: MetricDay[]): number {
  const earlier: number[] = valuesOf(days.slice(0, Math.max(0, days.length - RECENT_DAYS)));
  return earlier.length < MIN_BASELINE_DAYS ? NO_VALUE : median(earlier);
}

function band(lo: number, hi: number, okLo: number, okHi: number, personal: boolean): MetricBand {
  const b: MetricBand = { lo: lo, hi: hi, okLo: okLo, okHi: okHi, personal: personal };
  return b;
}

/**
 * The usual range of a metric. Heart rate, resting heart rate and HRV compare with the user's own baseline when there
 * are enough days; the rest use fixed reference values. Demo heuristics, not clinical limits.
 */
export function metricBand(kind: MetricKind, days: MetricDay[]): MetricBand {
  const base: number = baselineOf(days);
  switch (kind) {
    case 'RESTING_HR':
      // ±10 bpm is the same step RestingTrend uses for the missed beta-blocker question.
      return base > 0 ? band(Math.round(base) - 5, Math.round(base) + 5, Math.round(base) - 10, Math.round(base) + 10,
        true) : band(50, 80, 45, 90, false);
    case 'HEART_RATE':
      return base > 0 ? band(Math.round(base) - 8, Math.round(base) + 8, Math.round(base) - 15, Math.round(base) + 15,
        true) : band(55, 95, 48, 110, false);
    case 'HRV':
      // Only a drop counts: higher variability is never flagged.
      return base > 0 ? band(Math.round(base * 0.85), OPEN, Math.round(base * 0.65), OPEN, true) :
        band(30, OPEN, 20, OPEN, false);
    case 'SPO2':
      return band(95, 100, 92, 100, false);
    case 'BREATHING':
      return band(12, 20, 9, 24, false);
    case 'SLEEP':
      return band(7, 9.5, 5.5, 11, false);
    case 'STEPS':
      // Activity is never judged past "okay": how much exercise is right is the cardiologist's call.
      return base > 0 ? band(Math.round(base * 0.6), OPEN, 0, OPEN, true) : band(0, OPEN, 0, OPEN, false);
    default:
      return band(0, 45, 0, 120, false);   // STRESS, minutes per day
  }
}

/** The range for a live heart-rate reading: it depends on what the wearer is doing. */
export function liveHrBand(asleep: boolean, active: boolean): MetricBand {
  if (asleep) {
    return band(40, 90, 38, 100, false);
  }
  return active ? band(50, 150, 45, 170, false) : band(50, 100, 45, 119, false);
}

export function reasonFor(value: number, b: MetricBand): StatusReason {
  if (value < 0) {
    return 'NO_DATA';
  }
  if (value > b.hi) {
    return value > b.okHi ? 'HIGH' : 'SLIGHTLY_HIGH';
  }
  if (value < b.lo) {
    return value < b.okLo ? 'LOW' : 'SLIGHTLY_LOW';
  }
  return 'IN_RANGE';
}

export function levelFor(value: number, b: MetricBand): StatusLevel {
  const r: StatusReason = reasonFor(value, b);
  if (r === 'NO_DATA') {
    return 'NONE';
  }
  if (r === 'IN_RANGE') {
    return 'GOOD';
  }
  return r === 'HIGH' || r === 'LOW' ? 'ATTENTION' : 'OKAY';
}

// A change smaller than this reads as "steady".
function steadyStep(kind: MetricKind): number {
  switch (kind) {
    case 'HRV':
      return 3;
    case 'SPO2':
    case 'BREATHING':
      return 1;
    case 'SLEEP':
      return 0.4;
    case 'STEPS':
      return 500;
    case 'STRESS':
      return 10;
    default:
      return 2;
  }
}

/**
 * The status of a metric: the latest reading (or `live` when given) against its usual range, and the last 7 days
 * against the days before. `liveBand` replaces the range for a live reading.
 */
export function metricStatus(kind: MetricKind, days: MetricDay[], live: number = NO_VALUE,
  liveBand?: MetricBand): MetricStatus {
  const b: MetricBand = live >= 0 && liveBand !== undefined ? liveBand : metricBand(kind, days);
  const value: number = live >= 0 ? live : lastValue(days);
  const recent: number[] = valuesOf(days.slice(-CHANGE_DAYS));
  const before: number[] = valuesOf(days.slice(0, Math.max(0, days.length - CHANGE_DAYS)));
  let direction: Direction = 'NONE';
  let delta: number = 0;
  if (recent.length >= MIN_CHANGE_DAYS && before.length >= MIN_CHANGE_DAYS) {
    const diff: number = mean(recent) - mean(before);
    direction = Math.abs(diff) < steadyStep(kind) ? 'STEADY' : (diff > 0 ? 'UP' : 'DOWN');
    delta = kind === 'SLEEP' ? round1(Math.abs(diff)) : Math.round(Math.abs(diff));
  }
  const s: MetricStatus = {
    level: levelFor(value, b), reason: reasonFor(value, b), direction: direction, delta: delta, value: value, band: b
  };
  return s;
}

/** "53–63 bpm", "30 ms or more", "up to 45 min": the good range in words. */
export function bandText(kind: MetricKind, b: MetricBand): string {
  const unit: string = unitText(kind);
  if (b.hi >= OPEN) {
    return b.lo <= 0 ? '' : `${formatValue(kind, b.lo)} ${unit} or more`;
  }
  if (b.lo <= 0) {
    return `up to ${formatValue(kind, b.hi)} ${unit}`;
  }
  return `${formatValue(kind, b.lo)}–${formatValue(kind, b.hi)} ${unit}`;
}

export function metricStats(days: MetricDay[]): MetricStats {
  const withValue: MetricDay[] = days.filter((d: MetricDay) => hasValue(d));
  if (withValue.length === 0) {
    const none: MetricStats = { avg: NO_VALUE, min: NO_VALUE, max: NO_VALUE, count: 0 };
    return none;
  }
  let min: number = OPEN;
  let max: number = 0;
  for (const d of withValue) {
    min = Math.min(min, d.lo >= 0 ? d.lo : d.value);
    max = Math.max(max, d.hi >= 0 ? d.hi : d.value);
  }
  const stats: MetricStats = { avg: mean(withValue.map((d: MetricDay) => d.value)), min: min, max: max,
    count: withValue.length };
  return stats;
}

// The smallest height of the y axis, so a wobble of 2 bpm doesn't look like a cliff.
function minSpan(kind: MetricKind): number {
  switch (kind) {
    case 'HEART_RATE':
      return 40;
    case 'HRV':
      return 30;
    case 'SPO2':
      return 8;
    case 'BREATHING':
      return 10;
    case 'SLEEP':
      return 8;
    case 'STEPS':
      return 4000;
    case 'STRESS':
      return 60;
    default:
      return 20;
  }
}

/**
 * Y axis: the readings and the usual range with a little air, snapped to round numbers, at most five steps. Bars
 * start at zero; oxygen never goes above 100.
 */
export function metricScale(kind: MetricKind, days: MetricDay[], b: MetricBand): MetricScale {
  const stats: MetricStats = metricStats(days);
  const bars: boolean = chartForm(kind) === 'BARS';
  let lo: number = stats.count > 0 ? stats.min : (b.lo > 0 ? b.lo : 0);
  let hi: number = stats.count > 0 ? stats.max : (b.hi < OPEN ? b.hi : lo + minSpan(kind));
  // Keep the usual range in view when the readings are near it.
  if (b.lo > 0) {
    lo = Math.min(lo, b.lo);
    hi = Math.max(hi, b.lo);
  }
  if (b.hi < OPEN) {
    hi = Math.max(hi, b.hi);
  }
  if (bars) {
    lo = 0;
  }
  const short: number = minSpan(kind) - (hi - lo);
  if (short > 0) {
    hi += bars ? short : short / 2;
    lo -= bars ? 0 : short / 2;
  }
  const pad: number = (hi - lo) * 0.06;
  hi += pad;
  lo = bars ? 0 : Math.max(0, lo - pad);
  if (kind === 'SPO2') {
    hi = Math.min(100, hi);
    lo = Math.min(lo, 100 - minSpan(kind));
  }
  let min: number = lo;
  let max: number = hi;
  let step: number = NICE_STEPS[NICE_STEPS.length - 1];
  for (const s of NICE_STEPS) {
    const sMin: number = Math.floor(lo / s) * s;
    const sMax: number = Math.ceil(hi / s) * s;
    if ((sMax - sMin) / s <= 5) {
      min = sMin;
      max = sMax;
      step = s;
      break;
    }
  }
  const ticks: number[] = [];
  for (let t = min; t <= max + step / 1000; t += step) {
    ticks.push(Math.round(t * 10) / 10);
  }
  const scale: MetricScale = { min: min, max: max, ticks: ticks };
  return scale;
}

/** Centre x of slot i when `count` slots share `width`. */
export function slotX(i: number, count: number, width: number): number {
  return count <= 0 ? 0 : (i + 0.5) * width / count;
}

export function valueY(v: number, scale: MetricScale, height: number): number {
  if (scale.max <= scale.min) {
    return height;
  }
  return Math.max(0, Math.min(height, height - (v - scale.min) / (scale.max - scale.min) * height));
}

export function chartPoints(days: MetricDay[], scale: MetricScale, width: number, height: number): ChartPoint[] {
  const out: ChartPoint[] = [];
  for (let i = 0; i < days.length; i++) {
    if (!hasValue(days[i])) {
      continue;
    }
    const y: number = valueY(days[i].value, scale, height);
    const p: ChartPoint = {
      index: i,
      x: slotX(i, days.length, width),
      y: y,
      yLo: days[i].lo >= 0 ? valueY(days[i].lo, scale, height) : y,
      yHi: days[i].hi >= 0 ? valueY(days[i].hi, scale, height) : y
    };
    out.push(p);
  }
  return out;
}

/** Splits the points where a day has no reading, so the line is never drawn across a gap. */
export function lineRuns(points: ChartPoint[]): ChartPoint[][] {
  const runs: ChartPoint[][] = [];
  let run: ChartPoint[] = [];
  for (const p of points) {
    if (run.length > 0 && p.index !== run[run.length - 1].index + 1) {
      runs.push(run);
      run = [];
    }
    run.push(p);
  }
  if (run.length > 0) {
    runs.push(run);
  }
  return runs;
}

/**
 * A smooth line through the points of one run (monotone cubic, Fritsch–Carlson): it passes through every reading
 * and never overshoots between two of them, so the curve can't invent a peak the watch didn't see.
 */
export function smoothRun(run: ChartPoint[], perSegment: number): Array<[number, number]> {
  const out: Array<[number, number]> = [];
  const n: number = run.length;
  if (n < 3 || perSegment < 2) {
    for (const p of run) {
      out.push([p.x, p.y]);
    }
    return out;
  }
  const slope: number[] = [];
  for (let i = 0; i < n - 1; i++) {
    slope.push((run[i + 1].y - run[i].y) / (run[i + 1].x - run[i].x));
  }
  const tan: number[] = [slope[0]];
  for (let i = 1; i < n - 1; i++) {
    if (slope[i - 1] * slope[i] <= 0) {
      tan.push(0);
    } else {
      const a: number = run[i].x - run[i - 1].x;
      const b: number = run[i + 1].x - run[i].x;
      tan.push(3 * (a + b) / ((2 * b + a) / slope[i - 1] + (b + 2 * a) / slope[i]));
    }
  }
  tan.push(slope[n - 2]);
  out.push([run[0].x, run[0].y]);
  for (let i = 0; i < n - 1; i++) {
    const h: number = run[i + 1].x - run[i].x;
    for (let k = 1; k <= perSegment; k++) {
      const t: number = k / perSegment;
      const t2: number = t * t;
      const t3: number = t2 * t;
      const y: number = (2 * t3 - 3 * t2 + 1) * run[i].y + (t3 - 2 * t2 + t) * h * tan[i] +
        (-2 * t3 + 3 * t2) * run[i + 1].y + (t3 - t2) * h * tan[i + 1];
      out.push([run[i].x + t * h, y]);
    }
  }
  return out;
}

/** The day with a reading closest to a touch at `x`, or -1 when no day has one. */
export function nearestIndex(days: MetricDay[], x: number, width: number): number {
  let best: number = -1;
  let bestGap: number = OPEN;
  for (let i = 0; i < days.length; i++) {
    if (!hasValue(days[i])) {
      continue;
    }
    const gap: number = Math.abs(slotX(i, days.length, width) - x);
    if (gap < bestGap) {
      bestGap = gap;
      best = i;
    }
  }
  return best;
}

function seriesOf(kind: MetricKind, days: MetricDay[], simulated: boolean): MetricSeries {
  const s: MetricSeries = { kind: kind, days: days, simulated: simulated || MOCKED_KINDS.includes(kind) };
  return s;
}

/**
 * One series per metric over the calendar days of `trend` (oldest first). Resting heart rate comes from the daily
 * summary; the rest from the watch's daily vitals. A day the watch has no row for stays empty.
 */
export function buildSeries(trend: TrendDay[], vitals: WatchVitalsDay[], simulated: boolean): MetricSeries[] {
  const hr: MetricDay[] = [];
  const resting: MetricDay[] = [];
  const hrv: MetricDay[] = [];
  const spo2: MetricDay[] = [];
  const breathing: MetricDay[] = [];
  const sleep: MetricDay[] = [];
  const steps: MetricDay[] = [];
  const stress: MetricDay[] = [];
  let anySim: boolean = simulated;
  for (const t of trend) {
    const v: WatchVitalsDay | undefined = vitals.find((r: WatchVitalsDay) => r.day === t.day);
    anySim = anySim || (v !== undefined && v.simulated);
    resting.push(metricDay(t.day, t.restingBpm > 0 ? t.restingBpm : NO_VALUE));
    hr.push(v !== undefined && v.avgBpm > 0 ? metricDay(t.day, v.avgBpm, v.minBpm > 0 ? v.minBpm : NO_VALUE,
      v.maxBpm > 0 ? v.maxBpm : NO_VALUE) : metricDay(t.day, NO_VALUE));
    hrv.push(metricDay(t.day, v !== undefined && v.hrvMs > 0 ? v.hrvMs : NO_VALUE));
    spo2.push(metricDay(t.day, v !== undefined && v.spo2 > 0 ? v.spo2 : NO_VALUE));
    breathing.push(metricDay(t.day, v !== undefined && v.breathingRate > 0 ? v.breathingRate : NO_VALUE));
    sleep.push(metricDay(t.day, v !== undefined && v.sleepMinutes > 0 ? round1(v.sleepMinutes / 60) : NO_VALUE));
    steps.push(metricDay(t.day, v !== undefined && v.steps > 0 ? v.steps : NO_VALUE));
    stress.push(metricDay(t.day, v !== undefined ? v.stressMinutes : NO_VALUE));
  }
  return [
    seriesOf('HEART_RATE', hr, anySim), seriesOf('RESTING_HR', resting, anySim), seriesOf('HRV', hrv, anySim),
    seriesOf('SPO2', spo2, anySim), seriesOf('BREATHING', breathing, anySim), seriesOf('SLEEP', sleep, anySim),
    seriesOf('STEPS', steps, anySim), seriesOf('STRESS', stress, anySim)
  ];
}

export function seriesFor(all: MetricSeries[], kind: MetricKind): MetricSeries {
  const found: MetricSeries | undefined = all.find((s: MetricSeries) => s.kind === kind);
  return found !== undefined ? found : seriesOf(kind, [], false);
}

/** Above this many steps in the last minute the wearer counts as active (the same line AlarmRules draws). */
const ACTIVE_STEPS: number = 60;

/** The range for the heart rate in a live sample. */
export function sampleBand(s: VitalsSample): MetricBand {
  return liveHrBand(s.asleep === true, (s.steps ?? 0) > ACTIVE_STEPS);
}

/** The last minutes of heart rate as chart slots: `capacity` slots, the newest on the right. */
export function liveDays(samples: VitalsSample[], capacity: number): MetricDay[] {
  const out: MetricDay[] = [];
  const recent: VitalsSample[] = samples.slice(-capacity);
  for (let i = recent.length; i < capacity; i++) {
    out.push(metricDay('', NO_VALUE));
  }
  for (const s of recent) {
    const d: Date = new Date(s.ts);
    const two = (n: number): string => n < 10 ? `0${n}` : `${n}`;
    out.push(metricDay(`${two(d.getHours())}:${two(d.getMinutes())}:${two(d.getSeconds())}`, Math.round(s.hr)));
  }
  return out;
}
