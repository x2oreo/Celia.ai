// Beat 8: "What left my phone" rows slide in (field names and sizes, never values) + core badges.
import { heroVo, voAt } from '../audio/cues';
import React from 'react';
import { useCurrentFrame } from 'remotion';
import { ledger, scenes } from '../copy/script';
import { progress } from '../theme/motion';
import { PhoneFrame } from '../primitives/Devices';
import { SourceBadge } from '../primitives/Badges';
import { Stage } from '../primitives/Stage';
import { LedgerScreen } from '../ui/Ledger';
import { Float, TextColumn, phoneSlot, type SceneProps } from './common';

/** When each ledger row slides in, in scene frames. Shared with the soundtrack. */
export const TRUST_ROWS = [22, 34, 46, 58, 70];

export const Trust: React.FC<SceneProps> = ({ layout }) => {
  const frame = useCurrentFrame();
  const slot = phoneSlot(layout);
  const c = scenes.trust;
  const rows = [0, 1, 2, 3, 4].map((i) => progress(frame, TRUST_ROWS[i] ?? 0, 14));
  return (
    <Stage surface="bg" glow={{ x: '74%', y: '50%', r: 760 }}>
      <TextColumn layout={layout} kicker={c.kicker} lines={c.lines} at={[voAt(heroVo, 'trust') + 2]}>
        <div style={{ display: 'flex', gap: 14, marginTop: 14 }}>
          {ledger.badges.map((b, i) => {
            const p = progress(frame, 70 + i * 8, 12);
            return (
              <div key={b} style={{ opacity: p, transform: `translateY(${(1 - p) * 10}px)` }}>
                <SourceBadge label={b} solid={i === 0} scale={2.4} />
              </div>
            );
          })}
        </div>
      </TextColumn>
      <Float x={slot.x} y={slot.y} seed={7}>
        <PhoneFrame scale={slot.scale}>
          <LedgerScreen rows={rows} />
        </PhoneFrame>
      </Float>
    </Stage>
  );
};
