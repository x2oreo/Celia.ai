/**
 * Scripted scenarios for the emulator / demo: heart rate, activity and an optional fall. Pure functions so they can
 * be unit-tested. Each scenario is a list of segments; the last segment holds forever.
 */

export interface Segment {
  durationSec: number;
  fromBpm: number;
  toBpm: number;
  active: boolean;
}

export interface Scenario {
  id: string;
  label: string;
  segments: Segment[];
  /** Seconds into the scenario when a fall happens, -1 for none. */
  fallAtSec: number;
}

function rest(durationSec: number, fromBpm: number, toBpm: number): Segment {
  const s: Segment = { durationSec: durationSec, fromBpm: fromBpm, toBpm: toBpm, active: false };
  return s;
}

function move(durationSec: number, fromBpm: number, toBpm: number): Segment {
  const s: Segment = { durationSec: durationSec, fromBpm: fromBpm, toBpm: toBpm, active: true };
  return s;
}

function scenario(id: string, label: string, segments: Segment[], fallAtSec: number): Scenario {
  const s: Scenario = { id: id, label: label, segments: segments, fallAtSec: fallAtSec };
  return s;
}

export const SCENARIOS: Scenario[] = [
  scenario('rest', 'Resting', [rest(60, 68, 72), rest(60, 72, 66)], -1),
  // Normal workout: high HR while moving is expected, stays under the exercise limit.
  scenario('workout', 'Normal workout', [move(10, 72, 80), move(20, 80, 132), move(60, 132, 128)], -1),
  // LQT1: exercise-triggered. Climbs past the exercise limit while moving.
  scenario('lqt1_exercise', 'LQT1 exercise', [move(10, 75, 80), move(25, 80, 150), move(60, 150, 152)], -1),
  // LQT2: sudden noise/startle at rest. Fast jump with no movement.
  scenario('lqt2_startle', 'LQT2 startle',
    [rest(10, 66, 68), rest(3, 68, 165), rest(30, 165, 160), rest(30, 160, 90)], -1),
  // LQT3: events during rest/sleep with slow heart rate.
  scenario('lqt3_night_brady', 'LQT3 night', [rest(10, 58, 54), rest(20, 54, 38), rest(60, 38, 40)], -1),
  // Arrhythmic syncope: racing heart while still, collapse, then lying still with a low rate.
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

/** Whether the wearer is moving at `tSec`. */
export function activeAt(s: Scenario, tSec: number): boolean {
  return segmentAt(s, tSec).active;
}
