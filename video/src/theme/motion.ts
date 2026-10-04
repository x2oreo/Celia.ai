// DESIGN.md §8 as pure functions of the frame. No CSS animations anywhere: every value comes from here.
import { Easing, interpolate, spring } from 'remotion';

export const FPS = 30;

export const ms = (milliseconds: number): number => (milliseconds / 1000) * FPS;
export const sec = (seconds: number): number => seconds * FPS;

const clamp = { extrapolateLeft: 'clamp', extrapolateRight: 'clamp' } as const;

// Landing page entrance curve, cubic-bezier(0.23, 1, 0.32, 1).
export const easeOut = Easing.bezier(0.23, 1, 0.32, 1);
export const easeInOut = Easing.bezier(0.45, 0, 0.55, 1);

/** 0 → 1 between `start` and `start + duration` frames with the given easing. */
export const progress = (frame: number, start: number, duration: number, easing = easeOut): number =>
  interpolate(frame, [start, start + duration], [0, 1], { ...clamp, easing });

/** Critically damped spring (no overshoot), 0 → 1. */
export const settle = (frame: number, start: number, durationInFrames = 24): number =>
  spring({
    frame: frame - start,
    fps: FPS,
    durationInFrames,
    config: { damping: 200, stiffness: 120, mass: 1, overshootClamping: true },
  });

/** Heartbeat: scale 1 → 1.25 → 1 → 1.15 → 1 over `periodMs` (keyframes 0 / 15 / 30 / 45 / 100 %). */
export const heartbeat = (frame: number, periodMs = 1100): number => {
  const period = ms(periodMs);
  const t = (((frame % period) + period) % period) / period;
  return interpolate(t, [0, 0.15, 0.3, 0.45, 1], [1, 1.25, 1, 1.15, 1], {
    ...clamp,
    easing: Easing.inOut(Easing.quad),
  });
};

/** Breathing 0 → 1 → 0 over 4 s, ease-in-out (sinusoidal). */
export const breathPhase = (frame: number, periodMs = 4000): number => {
  const period = ms(periodMs);
  return 0.5 - 0.5 * Math.cos((frame / period) * Math.PI * 2);
};

/** Agent breathing: scale 0.92 ↔ 1.04, opacity 0.92 ↔ 1. */
export const breath = (frame: number): { scale: number; opacity: number } => {
  const p = breathPhase(frame);
  return { scale: 0.92 + 0.12 * p, opacity: 0.92 + 0.08 * p };
};

/** Linear turn in degrees: sheen 14 s, thinking arc 1.6 s. */
export const turn = (frame: number, periodMs: number): number => ((frame / ms(periodMs)) * 360) % 360;

/** Verdict reveal: slide up 12 vp and fade in over 240 ms, ease-out. Badge settles 100 ms later. */
export const reveal = (frame: number, start: number): { opacity: number; y: number; badge: number } => {
  const p = progress(frame, start, ms(240));
  const b = progress(frame, start + ms(100), ms(240));
  return { opacity: p, y: (1 - p) * 12, badge: b };
};

/** Bottom sheet: rises over 280 ms with a 45 % scrim. */
export const sheet = (frame: number, start: number): { y: number; scrim: number } => {
  const p = progress(frame, start, ms(280), Easing.bezier(0.32, 0.72, 0, 1));
  return { y: 1 - p, scrim: p };
};

/** Typing dots: three dots, 1.2 s loop, staggered 150 ms. Returns opacity for dot `i`. */
export const typingDot = (frame: number, i: number): number => {
  const period = ms(1200);
  const t = ((((frame - ms(150) * i) % period) + period) % period) / period;
  return interpolate(t, [0, 0.3, 0.6, 1], [0.3, 1, 0.3, 0.3], clamp);
};

/** Word stagger for kinetic headlines: words fade up with a 40 ms stagger. */
export const wordIn = (frame: number, start: number, index: number, staggerMs = 40): { opacity: number; y: number } => {
  const p = progress(frame, start + ms(staggerMs) * index, ms(520));
  return { opacity: p, y: (1 - p) * 18 };
};

/** Fade a scene in and out at its edges (frames are scene-local). */
export const edgeFade = (frame: number, duration: number, fadeIn = 15, fadeOut = 15): number =>
  Math.min(
    fadeIn === 0 ? 1 : interpolate(frame, [0, fadeIn], [0, 1], clamp),
    fadeOut === 0 ? 1 : interpolate(frame, [duration - fadeOut, duration], [1, 0], clamp),
  );

/** Slow camera push-in 1.00 → 1.06 across a scene. */
export const pushIn = (frame: number, duration: number, to = 1.06): number =>
  interpolate(frame, [0, duration], [1, to], { ...clamp, easing: easeInOut });

/** Slow parallax drift, at most `amp` px, deterministic. */
export const drift = (frame: number, seed: number, amp = 8): { x: number; y: number } => ({
  x: Math.sin(frame / 70 + seed * 1.7) * amp,
  y: Math.cos(frame / 85 + seed * 2.3) * amp * 0.7,
});

/** Watch pulse speed: 1.1 s calm → 0.5 s alert (DESIGN §7). */
export const pulsePeriodMs = (zone: 'CALM' | 'ELEVATED' | 'ALERT'): number =>
  zone === 'CALM' ? 1100 : zone === 'ELEVATED' ? 750 : 500;

export const clampOpts = clamp;
