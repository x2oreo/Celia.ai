// Beat 7: Emergency tab (v2 06), Start SOS → "Are you OK?" ring draining → emergency card + QR → a second phone
// opens the card in Polish (v3 glance layer), 112 first. A row of the 13 card languages sits under the line.
import React from 'react';
import { interpolate, useCurrentFrame } from 'remotion';
import { heroVo, vertVo, voAt } from '../audio/cues';
import { voWordAt } from '../audio/vo';
import { card, scenes } from '../copy/script';
import { clampOpts, progress, settle } from '../theme/motion';
import { color, fontFamily } from '../theme/tokens';
import { PhoneFrame } from '../primitives/Devices';
import { Stage } from '../primitives/Stage';
import { CardQrScreen, EmergencyTab, SosCountdown, WebCardPl } from '../ui/Emergency';
import { Float, TextColumn, type SceneProps } from './common';

const LanguageRow: React.FC<{ start: number; tall: boolean }> = ({ start, tall }) => {
  const frame = useCurrentFrame();
  const plIndex = card.languages.indexOf('Polski');
  // Highlight sweeps through all 13, then rests on Polski.
  const sweep = Math.floor(interpolate(frame, [start + 10, start + 60], [0, card.languages.length + plIndex], clampOpts));
  const active = sweep >= card.languages.length ? plIndex : sweep;
  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8, maxWidth: tall ? 940 : 640, justifyContent: tall ? 'center' : 'flex-start', marginTop: 8 }}>
      {card.languages.map((l, i) => {
        const p = progress(frame, start + i * 1.5, 10);
        const on = i === active;
        return (
          <span
            key={l}
            style={{
              height: tall ? 48 : 40,
              padding: tall ? '0 18px' : '0 14px',
              borderRadius: 24,
              display: 'inline-flex',
              alignItems: 'center',
              fontFamily: fontFamily.sans,
              fontSize: tall ? 22 : 17,
              fontWeight: 700,
              background: on ? color.ink : color.surface,
              color: on ? color.onBrand : color.ink2,
              border: `1px solid ${on ? color.ink : color.border}`,
              opacity: p,
              transform: `translateY(${(1 - p) * 8}px)`,
            }}
          >
            {l}
          </span>
        );
      })}
    </div>
  );
};

/** Beat timing in scene frames, shared with the soundtrack. */
export const emergencyTimes = (fast: boolean) => {
  const k = fast ? 0.62 : 1;
  return {
    PRESS: 8 * k, // Start SOS
    COUNT: 22 * k, // countdown screen
    SKIP: 74 * k, // 30 s compressed: the ring drains 30 → 26, then a dissolve marks the time skip
    QR: 92 * k,
    // The second phone lands on "In thirteen languages".
    SECOND: fast ? 112 * k : voAt(heroVo, 'emergency') + voWordAt('emergency', 9) - 6,
  };
};

export const Emergency: React.FC<SceneProps & { fast?: boolean }> = ({ layout, fast = false }) => {
  const frame = useCurrentFrame();
  const tall = layout === 'tall';
  const c = scenes.emergency;
  const vo = voAt(fast ? vertVo : heroVo, 'emergency');
  const { PRESS, COUNT, SKIP, QR, SECOND } = emergencyTimes(fast);
  const press = progress(frame, PRESS, 6) * (1 - progress(frame, PRESS + 8, 6));
  const toCount = progress(frame, COUNT, 10);
  const seconds = interpolate(frame, [COUNT, SKIP], [30, 26], clampOpts);
  const toCard = progress(frame, SKIP, 14);
  const secondIn = settle(frame, SECOND, 26);
  const a = tall ? { x: 112, y: 820, s: 1.0 } : { x: 960, y: 128, s: 0.98 };
  const b = tall ? { x: 560, y: 900, s: 1.0 } : { x: 1400, y: 168, s: 0.98 };
  return (
    <Stage surface="bg" glow={{ x: tall ? '50%' : '72%', y: tall ? '66%' : '50%', r: 800 }} push={1.04}>
      <TextColumn layout={layout} kicker={c.kicker} lines={c.lines} at={[vo + 2, SECOND - 8]} keep style={tall ? { top: 130 } : { left: 120, width: 700 }}>
        <LanguageRow start={SECOND} tall={tall} />
      </TextColumn>
      <Float x={a.x} y={a.y} seed={5}>
        <PhoneFrame scale={a.s}>
          <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', opacity: 1 - toCount }}>
            <EmergencyTab press={press} />
          </div>
          <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', opacity: toCount * (1 - toCard) }}>
            <SosCountdown seconds={seconds} total={30} />
          </div>
          <div style={{ position: 'absolute', inset: 0, display: 'flex', flexDirection: 'column', opacity: toCard }}>
            <CardQrScreen qr={progress(frame, QR, 12)} />
          </div>
        </PhoneFrame>
      </Float>
      <Float x={b.x} y={b.y} seed={6} enter={secondIn} enterFrom={{ x: 90, y: 0 }}>
        <div style={{ transform: 'rotate(3deg)' }}>
          <PhoneFrame scale={b.s}>
            <WebCardPl langIndex={card.languages.indexOf('Polski')} />
          </PhoneFrame>
        </div>
      </Float>
    </Stage>
  );
};
