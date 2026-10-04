// The agent's silk orb (DESIGN §6.6 / §6.6a), ported from site/assets/silk-orb.js, itself a port of the app's
// components/SilkOrb.ets. Same palette ("Dawn"), state looks, easing, bands, blobs, soft edge, glow and halo.
// Made frame-pure for Remotion: the eased state at frame f is integrated from frame 0 with a fixed 1/30 s step,
// so any frame renders the same on its own. A slow single breath; never a double beat, nothing like an ECG.
import React, { useLayoutEffect, useRef } from 'react';
import { useCurrentFrame } from 'remotion';
import { FPS } from '../theme/motion';
import { color } from '../theme/tokens';

export type OrbPhase = 'OFF' | 'CONNECTING' | 'LISTENING' | 'HEARING' | 'THINKING' | 'SPEAKING' | 'MUTED';

type RGB = [number, number, number];
const rgb = (hex: string): RGB => [
  parseInt(hex.slice(1, 3), 16),
  parseInt(hex.slice(3, 5), 16),
  parseInt(hex.slice(5, 7), 16),
];

const INNER = rgb(color.orbLight);
const MID = rgb(color.orbMid);
const EDGE = rgb(color.orbDark);
const BLOB_A = rgb(color.orbBlobA);
const BLOB_B = rgb(color.orbBlobB);
const BLOB_C = rgb(color.orbBlobC);
const LINE = rgb(color.orbBand);
const HALO_INK = rgb(color.ink4);

const TWO_PI = Math.PI * 2;
const SEGMENTS = 44;
const GROUPS = 3;
/** Canvas side as a multiple of the orb, so glow and halo have room. */
export const ORB_CANVAS = 1.9;

interface Look {
  ink: number;
  dim: number;
  swirl: number;
  out: number;
  inw: number;
  halo: number;
  lines: number;
}
const LOOKS: Record<OrbPhase, Look> = {
  OFF: { ink: 0, dim: 1, swirl: 0, out: 0, inw: 0, halo: 0, lines: 0.45 },
  CONNECTING: { ink: 0, dim: 1, swirl: 0.5, out: 0, inw: 0, halo: 0.3, lines: 0.8 },
  LISTENING: { ink: 1, dim: 1, swirl: 0, out: 0, inw: 0, halo: 0.7, lines: 0.55 },
  HEARING: { ink: 1, dim: 1, swirl: 0, out: 0, inw: 1, halo: 1, lines: 0.9 },
  THINKING: { ink: 0, dim: 0.88, swirl: 1, out: 0, inw: 0, halo: 0.3, lines: 0.9 },
  SPEAKING: { ink: 0, dim: 1, swirl: 0, out: 1, inw: 0, halo: 1, lines: 1 },
  MUTED: { ink: 0, dim: 0.45, swirl: 0, out: 0, inw: 0, halo: 0, lines: 0.15 },
};

interface OrbState {
  look: Look;
  lvl: number;
  drift: number;
  spin: number;
  clock: number;
}

const levelTarget = (phase: OrbPhase, level: number): number => {
  if (phase === 'MUTED') return 0;
  if (phase === 'HEARING' || phase === 'SPEAKING') return Math.max(0.25, Math.min(1, level));
  return phase === 'LISTENING' ? Math.min(1, level) * 0.5 : 0;
};

/** The orb's eased state at `frame`, integrated from frame 0 (pure). */
export const orbStateAt = (
  frame: number,
  phaseAt: (f: number) => OrbPhase,
  levelAt: (f: number) => number,
  seed = 0,
): OrbState => {
  const dt = 1 / FPS;
  const p0 = LOOKS[phaseAt(0)];
  const s: OrbState = { look: { ...p0 }, lvl: 0, drift: seed * 3.7, spin: 0, clock: seed };
  const k = Math.min(1, dt * 6);
  const kl = Math.min(1, dt * 9);
  for (let f = 0; f < Math.max(0, Math.floor(frame)); f++) {
    const ph = phaseAt(f);
    const t = LOOKS[ph];
    const p = s.look;
    p.ink += (t.ink - p.ink) * k;
    p.dim += (t.dim - p.dim) * k;
    p.swirl += (t.swirl - p.swirl) * k;
    p.out += (t.out - p.out) * k;
    p.inw += (t.inw - p.inw) * k;
    p.halo += (t.halo - p.halo) * k;
    p.lines += (t.lines - p.lines) * k;
    s.lvl += (levelTarget(ph, levelAt(f)) - s.lvl) * kl;
    s.drift += dt * (0.55 + 1.5 * s.lvl + 0.5 * p.lines);
    s.spin += dt * 2.4;
    s.clock += dt;
  }
  return s;
};

const rgba = (c: RGB, a: number): string =>
  `rgba(${Math.round(c[0])},${Math.round(c[1])},${Math.round(c[2])},${Math.max(0, Math.min(1, a)).toFixed(3)})`;
const mix = (a: RGB, b: RGB, t: number): RGB => [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t, a[2] + (b[2] - a[2]) * t];

const soft = (g: CanvasRenderingContext2D, x: number, y: number, r: number, c: RGB, a: number): void => {
  if (a <= 0.002 || r <= 0) return;
  const grad = g.createRadialGradient(x, y, 0, x, y, r);
  grad.addColorStop(0, rgba(c, a));
  grad.addColorStop(1, rgba(c, 0));
  g.beginPath();
  g.arc(x, y, r, 0, TWO_PI);
  g.fillStyle = grad;
  g.fill();
};

// One group of silk bands: latitude circles of a unit sphere around a slowly tumbling axis, front half only.
const bands = (g: CanvasRenderingContext2D, s: OrbState, c: number, r: number, k: number, count: number): void => {
  const p = s.look;
  const yaw = s.drift * (0.35 + 0.12 * k) * (1 - p.swirl) + s.spin * p.swirl + k * 2.1 * (1 - p.swirl * 0.85);
  const pitch = Math.sin(s.drift * 0.23 + k * 1.7) * 0.9 * (1 - p.swirl) + 0.35 * p.swirl;
  const nx = Math.cos(pitch) * Math.cos(yaw);
  const ny = Math.cos(pitch) * Math.sin(yaw);
  const nz = Math.sin(pitch);
  let ux = -ny;
  let uy = nx;
  const ul = Math.sqrt(ux * ux + uy * uy) || 1;
  ux /= ul;
  uy /= ul;
  const vx = -nz * uy;
  const vy = nz * ux;
  const vz = nx * uy - ny * ux;
  const amp = 0.012 + 0.05 * s.lvl;
  for (let i = 0; i < count; i++) {
    const phi = 0.5 + 0.78 * (i / (count - 1)) + 0.06 * Math.sin(s.drift * 0.6 + k);
    const cp = Math.cos(phi);
    const sp = Math.sin(phi);
    let open = false;
    g.beginPath();
    for (let q = 0; q <= SEGMENTS; q++) {
      const th = (q / SEGMENTS) * TWO_PI;
      const rr = 1 + amp * Math.sin(th * 3 + s.drift * 2.2 + i * 0.7 + k);
      const ct = Math.cos(th);
      const st = Math.sin(th);
      const x = rr * (cp * (ux * ct + vx * st) + sp * nx);
      const y = rr * (cp * (uy * ct + vy * st) + sp * ny);
      const z = cp * (vz * st) + sp * nz;
      if (z > -0.02) {
        if (open) g.lineTo(c + x * r, c + y * r);
        else {
          g.moveTo(c + x * r, c + y * r);
          open = true;
        }
      } else open = false;
    }
    g.strokeStyle = rgba(LINE, (0.16 + 0.5 * (i / count)) * p.lines * (0.55 + 0.6 * s.lvl + 0.2 * p.swirl));
    g.lineWidth = 0.8 + 1.1 * (i / count);
    g.stroke();
  }
};

const paint = (g: CanvasRenderingContext2D, s: OrbState, dim: number, small: boolean, glow: boolean): void => {
  const p = s.look;
  const side = dim * ORB_CANVAS;
  const c = side / 2;
  const breathe = 1 + 0.025 * Math.sin(s.clock * 1.57);
  const r = (dim / 2) * breathe * (1 + 0.08 * s.lvl * p.out - 0.03 * p.inw);
  const d = s.drift;
  g.globalCompositeOperation = 'source-over';
  g.clearRect(0, 0, side, side);
  const base = g.createRadialGradient(c - r * 0.2, c - r * 0.25, 0, c, c, r * 1.1);
  base.addColorStop(0, rgba(INNER, 1));
  base.addColorStop(0.6, rgba(MID, 1));
  base.addColorStop(1, rgba(EDGE, 1));
  g.fillStyle = base;
  g.fillRect(c - r * 1.12, c - r * 1.12, r * 2.24, r * 2.24);
  soft(g, c + Math.cos(d * 0.9) * r * 0.42, c + Math.sin(d * 0.7) * r * 0.42, r * 0.9, BLOB_A, 0.8);
  soft(g, c + Math.cos(d * 0.6 + 2.1) * r * 0.5, c + Math.sin(d * 0.4 + 2.1) * r * 0.5, r * 0.85, BLOB_B, 0.5);
  soft(g, c + Math.cos(d * 1.1 + 4.2) * r * 0.4, c + Math.sin(d * 1.0 + 4.2) * r * 0.4, r * 0.75, BLOB_C, 0.7);
  g.lineCap = 'round';
  const count = small ? 4 : 8;
  for (let k = 0; k < GROUPS; k++) bands(g, s, c, r, k, count);
  g.globalCompositeOperation = 'destination-in';
  const mask = g.createRadialGradient(c, c, r * 0.74, c, c, r * 1.06);
  mask.addColorStop(0, `rgba(0,0,0,${p.dim.toFixed(3)})`);
  mask.addColorStop(1, 'rgba(0,0,0,0)');
  g.fillStyle = mask;
  g.fillRect(0, 0, side, side);
  if (glow) {
    g.globalCompositeOperation = 'destination-over';
    soft(g, c, c + r * 0.14, Math.min(c, r * 1.4), MID, 0.16 * p.dim);
    soft(g, c, c, Math.min(c, r * (1.45 + 0.45 * s.lvl)), mix(MID, HALO_INK, p.ink), 0.26 * p.halo * (0.5 + s.lvl));
  }
  g.globalCompositeOperation = 'source-over';
};

const constant = <T,>(v: T) => (): T => v;

/**
 * The silk orb, `dim` vp across, centred in a `dim × ORB_CANVAS` canvas (laid out at `dim`, overflowing evenly).
 * `phaseAt` / `levelAt` take the local frame; defaults keep it OFF and still.
 */
export const SilkOrb: React.FC<{
  dim: number;
  phase?: OrbPhase;
  phaseAt?: (f: number) => OrbPhase;
  levelAt?: (f: number) => number;
  small?: boolean;
  glow?: boolean;
  seed?: number;
  /** Device pixel ratio of the canvas; raise when the orb is shown scaled up. */
  pixelRatio?: number;
  /** Clock override, for an orb whose story runs on another timeline than its Sequence. */
  frame?: number;
}> = ({ dim, phase = 'OFF', phaseAt, levelAt, small = false, glow = true, seed = 0, pixelRatio = 2, frame: at }) => {
  const seqFrame = useCurrentFrame();
  const frame = at ?? seqFrame;
  const ref = useRef<HTMLCanvasElement>(null);
  const side = dim * ORB_CANVAS;
  useLayoutEffect(() => {
    const cv = ref.current;
    if (cv === null) return;
    const g = cv.getContext('2d');
    if (g === null) return;
    g.setTransform(pixelRatio, 0, 0, pixelRatio, 0, 0);
    const s = orbStateAt(frame, phaseAt ?? constant(phase), levelAt ?? constant(0), seed);
    paint(g, s, dim, small, glow);
  }, [frame, dim, phase, phaseAt, levelAt, small, glow, seed, pixelRatio]);
  return (
    <div style={{ position: 'relative', width: dim, height: dim, flex: 'none' }}>
      <canvas
        ref={ref}
        width={Math.round(side * pixelRatio)}
        height={Math.round(side * pixelRatio)}
        style={{ position: 'absolute', width: side, height: side, left: (dim - side) / 2, top: (dim - side) / 2 }}
      />
    </div>
  );
};
