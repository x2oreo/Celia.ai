// Beat 1, the cold open, cut like a film: five shots on the voice, a heartbeat under all of them.
//   A  "Ola is twenty-four"            profile card: person avatar, "Ola, 24", the condition, her details
//   B  "takes longer to recharge"      the silk orb as her heart, a ring refilling slowly after each beat
//   Q  "a long QT interval"            a textbook schematic: typical beat beside Long QT, the QT bracket stretching
//   C  "her doctor gave her ..."       the box turning under a key light, the prescription slides in
//   D  "that one pill could ..."       the orb again, beats turn erratic, the camera closes in, then a hard cut to black
// The vertical cut plays A, C, D. A film-only use of the orb (DESIGN §10.2d): one swell per beat, never a double
// beat, never an ECG trace.
import React from 'react';
import { AbsoluteFill, interpolate, useCurrentFrame } from 'remotion';
import { heroVo, vertVo, voAt } from '../audio/cues';
import { voWordAt } from '../audio/vo';
import { box, hookBeats, ola, scenes } from '../copy/script';
import { clampOpts, drift, easeInOut, progress } from '../theme/motion';
import { color, film, fontFamily, shadow } from '../theme/tokens';
import { Headline, Kicker } from '../primitives/Type';
import { SilkOrb, type OrbPhase } from '../ui/SilkOrb';
import type { SceneProps } from './common';

type Shot = 'A' | 'B' | 'Q' | 'C' | 'D' | 'BLACK';

/** Orb level 0..1 from the beats: a quick swell after each beat that falls away (one swell, never lub-dub). */
const levelFrom = (beats: number[]) => (f: number): number => {
  let v = 0;
  for (const b of beats) {
    const t = f - b;
    if (t >= 0 && t < 14) v = Math.max(v, t < 3 ? t / 3 : 1 - (t - 3) / 11);
  }
  return v;
};

/** A slow camera on each shot: scale from `from` to `to`, plus a little drift. */
const Camera: React.FC<{ local: number; len: number; from: number; to: number; seed: number; shake?: number; children: React.ReactNode }> = ({
  local,
  len,
  from,
  to,
  seed,
  shake = 0,
  children,
}) => {
  const k = interpolate(local, [0, len], [from, to], { ...clampOpts, easing: easeInOut });
  const d = drift(local, seed, 6);
  return (
    <AbsoluteFill style={{ transform: `translate(${d.x + shake}px, ${d.y + shake * 0.6}px) scale(${k})`, transformOrigin: '50% 50%' }}>
      {children}
    </AbsoluteFill>
  );
};

/** Warm key light from above: the only light in the cold open. */
const KeyLight: React.FC<{ x: string; y: string; r: number; pulse?: number }> = ({ x, y, r, pulse = 0 }) => (
  <AbsoluteFill style={{ background: `radial-gradient(${r * (1 + 0.04 * pulse)}px circle at ${x} ${y}, ${color.keyLight} 0%, ${color.keyLightClear} 70%)` }} />
);

// ---- Shot A: who she is -------------------------------------------------------------------------------------

/** A plain person silhouette (head and shoulders) in a round frame; the ring beats with her heart. */
const PersonAvatar: React.FC<{ dim: number; p: number; pulse: number }> = ({ dim, p, pulse }) => (
  <div style={{ position: 'relative', width: dim, height: dim, opacity: p, transform: `scale(${0.85 + 0.15 * p})` }}>
    <div
      style={{
        position: 'absolute',
        inset: -14,
        borderRadius: '50%',
        border: `2px solid ${color.orbMid}`,
        opacity: 0.35 + 0.5 * pulse,
        transform: `scale(${1 + 0.04 * pulse})`,
      }}
    />
    <div style={{ position: 'absolute', inset: 0, borderRadius: '50%', overflow: 'hidden', background: color.night2, border: `1.5px solid ${color.nightLine}` }}>
      <svg width={dim} height={dim} viewBox="0 0 100 100" style={{ display: 'block' }}>
        <circle cx={50} cy={40} r={17} fill={color.nightInk3} />
        <path d="M 16 100 C 16 74, 32 62, 50 62 C 68 62, 84 74, 84 100 Z" fill={color.nightInk3} />
      </svg>
    </div>
  </div>
);

const NameShot: React.FC<{ local: number; len: number; conditionAt: number; pulse: number; tall: boolean }> = ({ local, len, conditionAt, pulse, tall }) => {
  const avatar = progress(local, 2, 18);
  const name = progress(local, 8, 16);
  const cond = progress(local, conditionAt, 16);
  return (
    <Camera local={local} len={len} from={1.06} to={1.0} seed={1}>
      <KeyLight x="50%" y="40%" r={tall ? 900 : 820} pulse={pulse} />
      <AbsoluteFill style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: tall ? 30 : 24, fontFamily: fontFamily.sans }}>
        <PersonAvatar dim={tall ? 260 : 220} p={avatar} pulse={pulse} />
        <div style={{ marginTop: tall ? 26 : 20, fontSize: tall ? 120 : 104, lineHeight: 1, fontWeight: 800, letterSpacing: '-0.04em', color: color.nightInk, opacity: name, transform: `translateY(${(1 - name) * 16}px)` }}>
          {ola.name}, <span style={{ color: color.nightInk3 }}>{ola.age}</span>
        </div>
        <div style={{ fontSize: tall ? 44 : 38, fontWeight: 700, color: color.brand, opacity: cond, transform: `translateY(${(1 - cond) * 12}px)` }}>{ola.condition}</div>
        <div style={{ display: 'flex', flexWrap: 'wrap', justifyContent: 'center', gap: 12, maxWidth: tall ? 900 : 1300, marginTop: 10 }}>
          {ola.life.map((l, i) => {
            const a = progress(local, 18 + i * 5, 14);
            return (
              <span
                key={l}
                style={{
                  height: tall ? 64 : 54,
                  padding: tall ? '0 26px' : '0 22px',
                  borderRadius: 32,
                  border: `1.5px solid ${color.nightLine}`,
                  background: color.night2,
                  color: color.nightInk2,
                  fontSize: tall ? 30 : 24,
                  fontWeight: 600,
                  display: 'inline-flex',
                  alignItems: 'center',
                  whiteSpace: 'nowrap',
                  opacity: a,
                  transform: `translateY(${(1 - a) * 10}px)`,
                }}
              >
                {l}
              </span>
            );
          })}
        </div>
      </AbsoluteFill>
    </Camera>
  );
};

// ---- Shot B: the heart that recharges slowly ----------------------------------------------------------------

const RechargeRing: React.FC<{ dim: number; frame: number; beats: number[] }> = ({ dim, frame, beats }) => {
  const last = [...beats].reverse().find((b) => b <= frame) ?? 0;
  const next = beats.find((b) => b > frame) ?? last + 25;
  const p = Math.max(0, Math.min(1, (frame - last) / Math.max(1, next - last)));
  const r = dim / 2 - 3;
  const c = 2 * Math.PI * r;
  return (
    <svg width={dim} height={dim} style={{ position: 'absolute', left: '50%', top: '50%', marginLeft: -dim / 2, marginTop: -dim / 2, transform: 'rotate(-90deg)' }}>
      <circle cx={dim / 2} cy={dim / 2} r={r} fill="none" stroke={color.nightLine} strokeWidth={3} />
      <circle cx={dim / 2} cy={dim / 2} r={r} fill="none" stroke={color.orbMid} strokeWidth={3} strokeLinecap="round" strokeDasharray={`${p * c} ${c}`} opacity={0.85} />
    </svg>
  );
};

const Ripple: React.FC<{ born: number; frame: number; size: number; strength: number }> = ({ born, frame, size, strength }) => {
  const t = frame - born;
  if (t < 0) return null;
  const p = interpolate(t, [0, 46], [0, 1], clampOpts);
  return (
    <div
      style={{
        position: 'absolute',
        left: '50%',
        top: '50%',
        width: size,
        height: size,
        marginLeft: -size / 2,
        marginTop: -size / 2,
        borderRadius: '50%',
        border: `${2.5 - 1.5 * p}px solid ${color.orbMid}`,
        transform: `scale(${0.55 + p * 0.95})`,
        opacity: (1 - p) * 0.55 * strength,
      }}
    />
  );
};

const HeartOrb: React.FC<{
  frame: number;
  beats: number[];
  dim: number;
  phaseAt: (f: number) => OrbPhase;
  levelAt: (f: number) => number;
  ring?: boolean;
  erratic?: boolean;
}> = ({ frame, beats, dim, phaseAt, levelAt, ring = false, erratic = false }) => {
  const recent = beats.filter((b) => frame - b >= 0 && frame - b < 48);
  return (
    <div style={{ position: 'absolute', left: '50%', top: '50%', width: 0, height: 0 }}>
      <div style={{ position: 'absolute', left: -dim, top: -dim, width: dim * 2, height: dim * 2 }}>
        {recent.map((b) => (
          <Ripple key={b} born={b} frame={frame} size={dim * 1.5} strength={erratic ? 0.7 : 1} />
        ))}
        {ring && <RechargeRing dim={dim * 1.42} frame={frame} beats={beats} />}
        <div style={{ position: 'absolute', left: dim / 2, top: dim / 2 }}>
          <SilkOrb dim={dim} phaseAt={phaseAt} levelAt={levelAt} seed={3} pixelRatio={2.5} frame={frame} />
        </div>
      </div>
    </div>
  );
};

const RechargeShot: React.FC<{ frame: number; local: number; len: number; beats: number[]; phaseAt: (f: number) => OrbPhase; levelAt: (f: number) => number; tall: boolean }> = ({
  frame,
  local,
  len,
  beats,
  phaseAt,
  levelAt,
  tall,
}) => (
  <>
    <Camera local={local} len={len} from={1.0} to={1.08} seed={2}>
      <KeyLight x="50%" y="44%" r={760} />
      <div style={{ position: 'absolute', left: 0, right: 0, top: tall ? 700 : 420, height: 0 }}>
        <HeartOrb frame={frame} beats={beats} dim={tall ? 340 : 300} phaseAt={phaseAt} levelAt={levelAt} ring />
      </div>
    </Camera>
    <div style={{ position: 'absolute', left: 0, right: 0, bottom: tall ? 380 : 120, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18 }}>
      <Kicker text={scenes.hook.kicker} start={6} tone="dark" tall={tall} />
      <Headline text={scenes.hook.lines[0] ?? ''} start={0} tone="dark" style={tall ? film.subTall : { ...film.sub, fontSize: 44, lineHeight: '52px', fontWeight: 700 }} align="center" />
    </div>
  </>
);

// ---- Shot Q: the QT interval ----------------------------------------------------------------------------------

/** One schematic beat (P, QRS, T) from x0, the T wave pushed `late` px later. Returns the path and Q / T-end x. */
const beatPath = (x0: number, late: number): { d: string; q: number; tEnd: number } => {
  const q = x0 + 190;
  const t0 = x0 + 290 + late;
  const tEnd = t0 + 110;
  const d = [
    `M ${x0} 0`,
    `L ${x0 + 90} 0`,
    `Q ${x0 + 120} -34 ${x0 + 150} 0`,
    `L ${q} 0`,
    `L ${q + 12} 22`,
    `L ${q + 34} -210`,
    `L ${q + 56} 56`,
    `L ${q + 72} 0`,
    `L ${t0} 0`,
    `Q ${t0 + 55} -96 ${tEnd} 0`,
    `L ${x0 + 760} 0`,
  ].join(' ');
  return { d, q, tEnd };
};

const QtPanel: React.FC<{ title: string; late: number; draw: number; accent: boolean; tall: boolean }> = ({ title, late, draw, accent, tall }) => {
  const W = 760;
  const H = 340;
  const b = beatPath(0, late);
  const ink = accent ? color.orbMid : color.nightInk2;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14, alignItems: 'flex-start' }}>
      <span style={{ fontFamily: fontFamily.sans, fontSize: tall ? 34 : 30, fontWeight: 700, color: accent ? color.brand : color.nightInk }}>{title}</span>
      <svg width={tall ? W * 1.2 : W} height={tall ? H * 1.2 : H} viewBox={`0 -250 ${W} ${H}`} style={{ overflow: 'visible' }}>
        <line x1={0} y1={0} x2={W} y2={0} stroke={color.nightLine} strokeWidth={2} />
        {accent && late > 4 && (
          <path d={`M 480 0 Q 535 -96 590 0`} fill="none" stroke={color.nightInk3} strokeWidth={3} strokeDasharray="8 10" opacity={Math.min(1, late / 60)} />
        )}
        <path d={b.d} fill="none" stroke={color.nightInk} strokeWidth={5} strokeLinejoin="round" strokeLinecap="round" pathLength={1} strokeDasharray={`${draw} 1`} />
        <g opacity={Math.min(1, draw * 1.4 - 0.4)}>
          <line x1={b.q} y1={58} x2={b.tEnd} y2={58} stroke={ink} strokeWidth={4} />
          <line x1={b.q} y1={44} x2={b.q} y2={72} stroke={ink} strokeWidth={4} />
          <line x1={b.tEnd} y1={44} x2={b.tEnd} y2={72} stroke={ink} strokeWidth={4} />
          <text x={(b.q + b.tEnd) / 2} y={84 + 10} textAnchor="middle" fontFamily={fontFamily.mono} fontSize={26} fontWeight={700} fill={ink}>
            {ola.qt.label}
          </text>
        </g>
      </svg>
    </div>
  );
};

const QtShot: React.FC<{ local: number; len: number; tall: boolean }> = ({ local, len, tall }) => {
  const draw = progress(local, 4, 26);
  // The Long QT beat starts like the typical one; its T wave then slides later and the QT bracket stretches with it.
  const late = interpolate(local, [30, 74], [0, 150], { ...clampOpts, easing: easeInOut });
  return (
    <Camera local={local} len={len} from={1.0} to={1.05} seed={6}>
      <KeyLight x="50%" y="45%" r={900} />
      <AbsoluteFill style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: tall ? 70 : 40 }}>
        <Kicker text={ola.qt.caps} start={0} tone="dark" tall={tall} />
        <div style={{ display: 'flex', flexDirection: tall ? 'column' : 'row', gap: tall ? 90 : 120 }}>
          <QtPanel title={ola.qt.typical} late={0} draw={draw} accent={false} tall={tall} />
          <QtPanel title={ola.qt.long} late={late} draw={draw} accent tall={tall} />
        </div>
        <span style={{ fontFamily: fontFamily.sans, fontSize: tall ? 24 : 20, fontWeight: 500, color: color.nightInk3 }}>{ola.qt.note}</span>
      </AbsoluteFill>
    </Camera>
  );
};

// ---- Shot C: the prescription --------------------------------------------------------------------------------

const BOX = { w: 520, h: 340, d: 130 };

const BoxFront: React.FC = () => (
  <div style={{ width: BOX.w, height: BOX.h, background: color.boxFace, overflow: 'hidden', fontFamily: fontFamily.sans }}>
    <div style={{ height: 60, background: color.boxBand }} />
    <div style={{ padding: '22px 30px', color: color.boxInk }}>
      <div style={{ fontSize: 46, fontWeight: 800, letterSpacing: '-0.02em' }}>{box.boxLabel}</div>
      <div style={{ fontSize: 28, fontWeight: 700, marginTop: 6 }}>{box.boxStrength}</div>
      <div style={{ fontSize: 20, fontWeight: 500, marginTop: 10, opacity: 0.75 }}>{box.boxForm}</div>
    </div>
  </div>
);

const Box3D: React.FC<{ turn: number; tilt: number }> = ({ turn, tilt }) => (
  <div style={{ perspective: 1600, width: BOX.w, height: BOX.h }}>
    <div style={{ position: 'relative', width: BOX.w, height: BOX.h, transformStyle: 'preserve-3d', transform: `rotateX(${tilt}deg) rotateY(${turn}deg)` }}>
      <div style={{ position: 'absolute', inset: 0, transform: `translateZ(${BOX.d / 2}px)`, boxShadow: shadow.floatDark }}>
        <BoxFront />
      </div>
      <div style={{ position: 'absolute', top: 0, left: BOX.w / 2 - BOX.d / 2, width: BOX.d, height: BOX.h, background: color.boxSide, transform: `rotateY(90deg) translateZ(${BOX.w / 2}px)` }}>
        <div style={{ height: 60, background: color.boxBand, filter: 'brightness(0.85)' }} />
      </div>
      <div style={{ position: 'absolute', left: 0, top: BOX.h / 2 - BOX.d / 2, width: BOX.w, height: BOX.d, background: color.boxFace, filter: 'brightness(0.96)', transform: `rotateX(90deg) translateZ(${BOX.h / 2}px)` }} />
    </div>
  </div>
);

const Prescription: React.FC<{ p: number }> = ({ p }) => {
  const rx = ola.rx;
  return (
    <div
      style={{
        width: 420,
        padding: '26px 28px',
        background: color.cardBg,
        borderRadius: 6,
        boxShadow: shadow.floatDark,
        fontFamily: fontFamily.sans,
        color: color.cardInk,
        display: 'flex',
        flexDirection: 'column',
        gap: 10,
        opacity: p,
        transform: `translateX(${(1 - p) * 160}px) rotate(${5 - 2 * p}deg)`,
      }}
    >
      <div style={{ display: 'flex', justifyContent: 'space-between', fontFamily: fontFamily.mono, fontSize: 15, fontWeight: 700, letterSpacing: '0.1em', color: color.cardInk3 }}>
        <span>{rx.caps}</span>
        <span>Rx</span>
      </div>
      <div style={{ fontSize: 18, color: color.cardInk3 }}>{rx.doctor}</div>
      <div style={{ height: 1, background: color.cardBorder }} />
      <div style={{ fontSize: 30, fontWeight: 800, letterSpacing: '-0.01em' }}>{rx.drug}</div>
      <div style={{ fontSize: 20, fontWeight: 600, color: color.cardInk2 }}>{rx.dose}</div>
      <div style={{ fontSize: 18, color: color.cardInk3 }}>For: {rx.reason}</div>
    </div>
  );
};

const BoxShot: React.FC<{ local: number; len: number; pulse: number; tall: boolean }> = ({ local, len, pulse, tall }) => {
  const turn = interpolate(local, [0, len], [-42, -14], { ...clampOpts, easing: easeInOut });
  const tilt = interpolate(local, [0, len], [16, 9], clampOpts);
  const rx = progress(local, 24, 22);
  return (
    <Camera local={local} len={len} from={1.04} to={1.12} seed={4}>
      <KeyLight x={tall ? '50%' : '42%'} y="30%" r={900} pulse={pulse} />
      <div style={{ position: 'absolute', left: tall ? 280 : 470, top: tall ? 640 : 330, transform: tall ? 'scale(1.05)' : undefined }}>
        <Box3D turn={turn} tilt={tilt} />
      </div>
      <div style={{ position: 'absolute', left: tall ? 330 : 1120, top: tall ? 1110 : 300 }}>
        <Prescription p={rx} />
      </div>
    </Camera>
  );
};

// ---- Shot D: one pill ---------------------------------------------------------------------------------------

const ChaosShot: React.FC<{ frame: number; local: number; len: number; beats: number[]; stop: number; phaseAt: (f: number) => OrbPhase; levelAt: (f: number) => number; tall: boolean }> = ({
  frame,
  local,
  len,
  beats,
  stop,
  phaseAt,
  levelAt,
  tall,
}) => {
  const last = [...beats].reverse().find((b) => b <= frame) ?? -99;
  const t = frame - last;
  // A jolt on each erratic beat, gone within a few frames.
  const shake = frame < stop && t >= 0 && t < 6 ? Math.sin(t * 2.4 + last) * 7 * (1 - t / 6) : 0;
  return (
    <>
      <Camera local={local} len={len} from={1.0} to={1.32} seed={5} shake={shake}>
        <KeyLight x="50%" y="46%" r={700} />
        <div style={{ position: 'absolute', left: 0, right: 0, top: tall ? 760 : 470, height: 0 }}>
          <HeartOrb frame={frame} beats={beats} dim={tall ? 360 : 320} phaseAt={phaseAt} levelAt={levelAt} erratic />
        </div>
      </Camera>
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: tall ? 360 : 110, display: 'flex', justifyContent: 'center' }}>
        <Headline text={scenes.hook.lines[1] ?? ''} start={6} tone="dark" style={tall ? film.headlineTall : film.headline} align="center" accentWord="heart" maxWidth={tall ? 900 : 1400} />
      </div>
    </>
  );
};

export const Hook: React.FC<SceneProps & { compact?: boolean }> = ({ layout, compact = false }) => {
  const frame = useCurrentFrame();
  const tall = layout === 'tall';
  const { beats, stop } = hookBeats(compact ? 'vertical' : 'hero');
  const at = voAt(compact ? vertVo : heroVo, 'hook');
  const line = compact ? 'hook_v' : 'hook';
  // Cut points on the voice: "Her heart" / "between beats" / "Yesterday" / "For Ola" (hero); "One common" / "could" (vertical).
  const cuts: { shot: Shot; from: number }[] = compact
    ? [
        { shot: 'A', from: 0 },
        { shot: 'C', from: at + voWordAt(line, 5) - 4 },
        { shot: 'D', from: at + voWordAt(line, 8) - 4 },
        { shot: 'BLACK', from: stop + 4 },
      ]
    : [
        { shot: 'A', from: 0 },
        { shot: 'B', from: at + voWordAt(line, 8) - 4 },
        { shot: 'Q', from: at + voWordAt(line, 16) - 4 },
        { shot: 'C', from: at + voWordAt(line, 25) - 4 },
        { shot: 'D', from: at + voWordAt(line, 33) - 4 },
        { shot: 'BLACK', from: stop + 4 },
      ];
  let idx = 0;
  for (let i = 0; i < cuts.length; i++) if (frame >= (cuts[i]?.from ?? 0)) idx = i;
  const cur = cuts[idx] ?? { shot: 'A' as Shot, from: 0 };
  const local = frame - cur.from;
  const len = (cuts[idx + 1]?.from ?? frame + 60) - cur.from;
  const phaseAt = (f: number): OrbPhase => (f >= stop ? 'MUTED' : 'SPEAKING');
  const levelAt = levelFrom(beats);
  const pulse = levelAt(frame);
  const conditionAt = at + voWordAt(line, compact ? 2 : 5) - 4 - cur.from;
  return (
    <AbsoluteFill style={{ background: color.night, overflow: 'hidden' }}>
      {cur.shot === 'A' && <NameShot local={local} len={len} conditionAt={conditionAt} pulse={pulse} tall={tall} />}
      {cur.shot === 'B' && <RechargeShot frame={frame} local={local} len={len} beats={beats} phaseAt={phaseAt} levelAt={levelAt} tall={tall} />}
      {cur.shot === 'Q' && <QtShot local={local} len={len} tall={tall} />}
      {cur.shot === 'C' && <BoxShot local={local} len={len} pulse={pulse} tall={tall} />}
      {cur.shot === 'D' && <ChaosShot frame={frame} local={local} len={len} beats={beats} stop={stop} phaseAt={phaseAt} levelAt={levelAt} tall={tall} />}
    </AbsoluteFill>
  );
};
