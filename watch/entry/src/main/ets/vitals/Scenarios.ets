/**
 * Scripted heart-rate scenarios for the emulator / demo. Pure functions so they can be unit-tested.
 * Each scenario is a list of segments; the last segment's end value holds forever.
 */

export interface Segment {
  durationSec: number;
  fromBpm: number;
  toBpm: number;
}

export interface Scenario {
  id: string;
  label: string;
  segments: Segment[];
}

function seg(durationSec: number, fromBpm: number, toBpm: number): Segment {
  const s: Segment = { durationSec: durationSec, fromBpm: fromBpm, toBpm: toBpm };
  return s;
}

function scenario(id: string, label: string, segments: Segment[]): Scenario {
  const s: Scenario = { id: id, label: label, segments: segments };
  return s;
}

export const SCENARIOS: Scenario[] = [
  scenario('rest', 'Resting', [seg(60, 68, 72), seg(60, 72, 66)]),
  // LQT1: exercise-triggered. Climb past the high limit and stay there.
  scenario('lqt1_exercise', 'LQT1 exercise', [seg(10, 72, 75), seg(25, 75, 150), seg(60, 150, 152)]),
  // LQT2: sudden noise/startle at rest. Very fast jump.
  scenario('lqt2_startle', 'LQT2 startle', [seg(10, 66, 68), seg(3, 68, 165), seg(30, 165, 160), seg(30, 160, 90)]),
  // LQT3: events during rest/sleep with slow heart rate.
  scenario('lqt3_night_brady', 'LQT3 night', [seg(10, 58, 54), seg(20, 54, 38), seg(60, 38, 40)])
];

export function findScenario(id: string): Scenario {
  for (const s of SCENARIOS) {
    if (s.id === id) {
      return s;
    }
  }
  return SCENARIOS[0];
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
