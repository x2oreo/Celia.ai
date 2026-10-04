// Beat 1: a single coral heartbeat ripple on the warm background, then the problem, one line at a time.
// A ripple, never an ECG trace (DESIGN §9, §10.2b).
import React from 'react';
import { interpolate, useCurrentFrame } from 'remotion';
import { heroVo, vertVo, voAt } from '../audio/cues';
import { voWordAt } from '../audio/vo';
import { scenes } from '../copy/script';
import { clampOpts, heartbeat, progress } from '../theme/motion';
import { brandAlpha, color } from '../theme/tokens';
import { Stage } from '../primitives/Stage';
import { OneLineAtATime, type SceneProps } from './common';
import { Kicker } from '../primitives/Type';

const BEAT = 33; // ~1.1 s lub-dub

const Ripple: React.FC<{ born: number; size: number }> = ({ born, size }) => {
  const frame = useCurrentFrame();
  const t = frame - born;
  if (t < 0) {
    return null;
  }
  const p = interpolate(t, [0, 48], [0, 1], clampOpts);
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
        border: `${3 - 2 * p}px solid ${color.brand}`,
        transform: `scale(${0.2 + p * 1.6})`,
        opacity: (1 - p) * 0.8,
      }}
    />
  );
};

export const Hook: React.FC<SceneProps & { compact?: boolean }> = ({ layout, compact = false }) => {
  const frame = useCurrentFrame();
  const c = scenes.hook;
  const tall = layout === 'tall';
  // Line 1 with the first word of the voice, line 2 with its second sentence ("For them" / "Everyday").
  const at = voAt(compact ? vertVo : heroVo, 'hook');
  const lineAt = [at + 2, at + (compact ? voWordAt('hook_v', 9) : voWordAt('hook', 10)) - 4];
  // A soft ripple pair every beat while the scene runs (kept to the last few so the DOM stays small).
  const born: number[] = [];
  for (let b = 6; b <= frame; b += BEAT) born.push(b, b + 7);
  const recent = born.filter((b) => frame - b < 90);
  const dotIn = progress(frame, 0, 10);
  const beat = heartbeat(frame - 6);
  const pulseY = tall ? 640 : 300;
  return (
    <Stage surface="bg" glow={{ x: '50%', y: tall ? '33%' : '28%', r: tall ? 900 : 700, strength: 0.1 }}>
      <div style={{ position: 'absolute', left: 0, right: 0, top: pulseY - 160, height: 320 }}>
        {recent.map((b) => (
          <Ripple key={b} born={b} size={(b - 6) % BEAT === 0 ? 300 : 240} />
        ))}
        <div
          style={{
            position: 'absolute',
            left: '50%',
            top: '50%',
            width: 44,
            height: 44,
            marginLeft: -22,
            marginTop: -22,
            borderRadius: '50%',
            background: color.brand,
            boxShadow: `0 6px 24px ${brandAlpha(0.35)}`,
            transform: `scale(${dotIn * beat})`,
          }}
        />
      </div>
      <div
        style={{
          position: 'absolute',
          left: tall ? 70 : 260,
          right: tall ? 70 : 260,
          top: tall ? 900 : 540,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          gap: 26,
        }}
      >
        <Kicker text={c.kicker} start={lineAt[0]! - 10} tall={tall} />
        <OneLineAtATime lines={c.lines} at={lineAt} layout={layout} align="center" maxWidth={tall ? 940 : 1300} accentWord="2,000" />
      </div>
    </Stage>
  );
};
