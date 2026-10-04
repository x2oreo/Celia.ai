// What every home-screen card shows (DESIGN.md §11 widgets v2, B6, B13), built from the user's own records only:
// the profile, medicines, reminders and dose log, logged checks and diary entries, the watch's daily trend and the
// HomeBrief line. Pure - unit tested. Cards cannot import app code, so the snapshot is flat strings and numbers;
// the snapshot itself is widget/WidgetSnapshot.ets.

import { Profile } from '../model/Profile';
import { Medication } from '../model/Medication';
import { ScanRecord } from '../model/ScanRecord';
import { AppEvent } from '../model/AppEvent';
import { RiskLevel } from '../model/DrugVerdict';
import { VitalsSample } from '../model/Vitals';
import { DoseLog, DoseReminder } from '../reminders/DoseSchedule';
import { TrendDay, TrendStats, trendStats } from '../vitals/Trends';
import {
  MetricBand, metricBand, MetricDay, metricDay, MetricScale, metricScale, metricStatus, NO_VALUE, OPEN, valueY
} from '../vitals/Metrics';
import { FeelingEntry, moodLabel, parseFeeling } from '../diary/Diary';
import { medLine } from '../emergency/CardContent';
import { shortDateTime } from '../common/Format';
import { medIdLines, MedIdLines } from './MedIdData';
import { applyDose, WidgetSnapshot } from './WidgetSnapshot';

export const WEEK_DAYS: number = 7;
export const RECENT_CHECKS: number = 3;

export class WidgetInputs {
  profile: Profile | undefined = undefined;
  meds: Medication[] = [];
  ambulance: string = '112';
  reminders: DoseReminder[] = [];
  logs: DoseLog[] = [];
  scans: ScanRecord[] = [];
  events: AppEvent[] = [];
  trend: TrendDay[] = [];      // oldest first, one per day
  trendSimulated: boolean = true;
  sample: VitalsSample | undefined = undefined;
  agentRest: string = '';   // AgentLogic.agentLine without a dose and with a clock-free greeting
}

export function riskCode(r: RiskLevel): string {
  switch (r) {
    case 'KNOWN_RISK':
      return 'KNOWN';
    case 'POSSIBLE_RISK':
      return 'POSSIBLE';
    case 'CONDITIONAL_RISK':
      return 'CONDITIONAL';
    case 'NOT_LISTED':
      return 'OK';
    default:
      return 'UNKNOWN';
  }
}

function capitalised(s: string): string {
  const t: string = s.trim();
  return t.length === 0 ? t : t.charAt(0).toUpperCase() + t.slice(1);
}

function fillAlert(s: WidgetSnapshot, p: Profile | undefined, meds: Medication[], ambulance: string): void {
  s.number = ambulance;
  if (p === undefined) {
    return;
  }
  s.condition = p.genotype === 'UNKNOWN' ? 'Long QT syndrome' : `Long QT syndrome, type ${p.genotype.replace('LQT', '')}`;
  const icd: string = p.hasIcd ? 'ICD' : 'No ICD';
  s.facts = meds.length === 0 ? icd : `${icd} · ${meds.slice(0, 2).map((m: Medication) => medLine(m)).join(', ')}`;
  s.ice = p.contacts.length > 0 ? p.contacts[0].name : '';
  const mid: MedIdLines = medIdLines(p, meds);
  s.midName = mid.name;
  s.midIcd = mid.icd;
  s.midMeds = mid.meds;
  s.midOther = mid.other;
}

// Same words as Today's resting card: numbers reported, never judged.
function changeLine(all: TrendStats): string {
  if (!all.hasChange || all.change === 0) {
    return 'Same as last week';
  }
  return `${Math.abs(all.change)} ${all.change < 0 ? 'lower' : 'higher'} than last week`;
}

function pct(v: number, scale: MetricScale): number {
  return Math.round(100 - valueY(v, scale, 100));
}

function fillHeart(s: WidgetSnapshot, trend: TrendDay[], simulated: boolean, sample: VitalsSample | undefined): void {
  const all: MetricDay[] = trend.map((d: TrendDay) => metricDay(d.day, d.restingBpm > 0 ? d.restingBpm : NO_VALUE));
  const week: TrendDay[] = trend.slice(-WEEK_DAYS);
  const days: MetricDay[] = all.slice(-WEEK_DAYS);
  if (sample !== undefined && sample.hr > 0) {
    s.hrLast = `${Math.round(sample.hr)} bpm · ${shortDateTime(sample.ts)}`;
  }
  if (!week.some((d: TrendDay) => d.restingBpm > 0)) {
    return;
  }
  s.hrAvg = trendStats(week).avgResting;
  s.hrChange = changeLine(trendStats(trend));
  s.hrSource = simulated ? 'SIMULATED' : 'WATCH';
  s.hrLevel = metricStatus('RESTING_HR', all).level;
  const band: MetricBand = metricBand('RESTING_HR', all);
  const scale: MetricScale = metricScale('RESTING_HR', days, band);
  s.hbLo = band.lo > 0 ? pct(band.lo, scale) : 0;
  s.hbHi = band.hi < OPEN ? pct(band.hi, scale) : 100;
  // Right-aligned: with fewer than seven days the newest still sits in the last slot.
  const heights: number[] = days.map((d: MetricDay) => d.value >= 0 ? pct(d.value, scale) : -1);
  while (heights.length < WEEK_DAYS) {
    heights.unshift(-1);
  }
  s.hd0 = heights[0];
  s.hd1 = heights[1];
  s.hd2 = heights[2];
  s.hd3 = heights[3];
  s.hd4 = heights[4];
  s.hd5 = heights[5];
  s.hd6 = heights[6];
}

// Newest first, one row per medicine name.
export function recentChecks(scans: ScanRecord[]): ScanRecord[] {
  const out: ScanRecord[] = [];
  const seen: string[] = [];
  for (const r of scans.slice().sort((a: ScanRecord, b: ScanRecord) => b.ts - a.ts)) {
    const key: string = r.query.trim().toLowerCase();
    if (key.length === 0 || seen.includes(key)) {
      continue;
    }
    seen.push(key);
    out.push(r);
    if (out.length === RECENT_CHECKS) {
      break;
    }
  }
  return out;
}

function fillChecks(s: WidgetSnapshot, scans: ScanRecord[]): void {
  const recent: ScanRecord[] = recentChecks(scans);
  if (recent.length > 0) {
    s.chk0Name = capitalised(recent[0].query);
    s.chk0Risk = riskCode(recent[0].risk);
  }
  if (recent.length > 1) {
    s.chk1Name = capitalised(recent[1].query);
    s.chk1Risk = riskCode(recent[1].risk);
  }
  if (recent.length > 2) {
    s.chk2Name = capitalised(recent[2].query);
    s.chk2Risk = riskCode(recent[2].risk);
  }
}

function fillFeeling(s: WidgetSnapshot, events: AppEvent[]): void {
  let last: AppEvent | undefined = undefined;
  for (const e of events) {
    if (e.kind === 'FEELING' && (last === undefined || e.ts > last.ts)) {
      last = e;
    }
  }
  if (last === undefined) {
    return;
  }
  const f: FeelingEntry | undefined = parseFeeling(last.detail);
  if (f !== undefined) {
    s.feelLast = `Last: ${moodLabel(f.mood)} · ${shortDateTime(last.ts)}`;
  }
}

export function buildSnapshot(i: WidgetInputs, now: number): WidgetSnapshot {
  const s: WidgetSnapshot = new WidgetSnapshot();
  fillAlert(s, i.profile, i.meds, i.ambulance);
  s.agentRest = i.agentRest;
  applyDose(s, i.reminders, i.logs, now);
  fillHeart(s, i.trend, i.trendSimulated, i.sample);
  fillChecks(s, i.scans);
  fillFeeling(s, i.events);
  return s;
}
