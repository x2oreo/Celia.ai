import { Activity } from '../model/WatchMetric';

/**
 * Scripted scenarios for the emulator / demo: heart rate, state (rest/active/asleep) and an optional fall. Pure
 * functions so they can be unit-tested. Each scenario is a list of segments; the last segment holds forever.
 */

export interface Segment {
  durationSec: number;
  fromBpm: number;
  toBpm: number;
  state: Activity;
}

export interface Scenario {
  id: string;
  label: string;
  segments: Segment[];
  /** Seconds into the scenario when a fall happens, -1 for none. */
  fallAtSec: number;
}

function seg(state: Activity, durationSec: number, fromBpm: number, toBpm: number): Segment {
  const s: Segment = { durationSec: durationSec, fromBpm: fromBpm, toBpm: toBpm, state: state };
  return s;
}

function rest(durationSec: number, fromBpm: number, toBpm: number): Segment {
  return seg('REST', durationSec, fromBpm, toBpm);
}

function move(durationSec: number, fromBpm: number, toBpm: number): Segment {
  return seg('ACTIVE', durationSec, fromBpm, toBpm);
}

function sleep(durationSec: number, fromBpm: number, toBpm: number): Segment {
  return seg('ASLEEP', durationSec, fromBpm, toBpm);
}

function scenario(id: string, label: string, segments: Segment[], fallAtSec: number): Scenario {
  const s: Scenario = { id: id, label: label, segments: segments, fallAtSec: fallAtSec };
  return s;
}

export const SCENARIOS: Scenario[] = [
  // Everything in one run (~5 min of scenario time, ~75 s at 4× demo speed): exercise high → slow recovery →
  // startle at rest → low HR asleep → irregular rhythm → faint with a fall.
  scenario('tour', 'Full demo', [
    rest(8, 68, 70), move(20, 70, 150), move(15, 150, 152),
    rest(60, 150, 146), rest(10, 146, 146), rest(15, 146, 72),
    rest(4, 72, 165), rest(20, 165, 160), rest(15, 160, 75),
    sleep(15, 58, 36), sleep(30, 36, 38),
    rest(6, 70, 72), rest(4, 72, 190), rest(12, 190, 185), rest(60, 50, 48)
  ], 234),
  scenario('rest', 'Resting', [rest(60, 68, 72), rest(60, 72, 66)], -1),
  // Normal workout + healthy recovery (~35 bpm drop in the first minute).
  scenario('workout', 'Workout',
    [rest(5, 72, 74), move(15, 74, 128), move(25, 128, 132), rest(60, 130, 95), rest(60, 95, 80)], -1),
  // LQT1: exercise-triggered. Passes the exercise limit, then recovers slowly (< 12 bpm in 1 min).
  scenario('lqt1_exercise', 'LQT1 exercise',
    [rest(5, 75, 78), move(20, 78, 150), move(20, 150, 152), rest(60, 150, 141), rest(60, 141, 110)], -1),
  // LQT2: sudden noise/startle at rest. Fast jump with no movement.
  scenario('lqt2_startle', 'LQT2 startle',
    [rest(10, 66, 68), rest(3, 68, 165), rest(30, 165, 160), rest(30, 160, 90)], -1),
  // LQT3: events during sleep with slow heart rate.
  scenario('lqt3_night_brady', 'LQT3 night', [sleep(10, 56, 52), sleep(20, 52, 36), sleep(60, 36, 38)], -1),
  // Arrhythmic syncope: racing heart while still (irregular rhythm), collapse, then lying still with a low rate.
  scenario('faint', 'Faint', [rest(8, 70, 72), rest(4, 72, 190), rest(4, 190, 185), rest(60, 50, 48)], 15)
];

export function findScenario(id: string): Scenario {
  for (const s of SCENARIOS) {
    if (s.id === id) {
      return s;
    }
  }
  return SCENARIOS[0];
}

function segmentAt(s: Scenario, tSec: number): Segment {
  let t = Math.max(0, tSec);
  for (const segment of s.segments) {
    if (t <= segment.durationSec) {
      return segment;
    }
    t -= segment.durationSec;
  }
  return s.segments[s.segments.length - 1];
}

/** Heart rate at `tSec` seconds into the scenario, linearly interpolated, without noise. */
export function bpmAt(s: Scenario, tSec: number): number {
  let t = Math.max(0, tSec);
  for (const segment of s.segments) {
    if (t <= segment.durationSec) {
      const k = segment.durationSec === 0 ? 1 : t / segment.durationSec;
      return segment.fromBpm + (segment.toBpm - segment.fromBpm) * k;
    }
    t -= segment.durationSec;
  }
  return s.segments[s.segments.length - 1].toBpm;
}

/** Wearer state (rest / active / asleep) at `tSec`. */
export function stateAt(s: Scenario, tSec: number): Activity {
  return segmentAt(s, tSec).state;
}
