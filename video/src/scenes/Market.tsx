// Beat 12: market + model, from the deck (sport-health slides 8 and 9). Who it is for (estimates at 1 in 2,000),
// why now, and how it pays: safety stays free, the care around it pays. Sources in the caption. Shown as one
// finished slide that settles in together; the voice walks through it.
import React from 'react';
import { useCurrentFrame } from 'remotion';
import { market, scenes } from '../copy/script';
import { progress } from '../theme/motion';
import { color, fontFamily, radius, shadow } from '../theme/tokens';
import { Stage } from '../primitives/Stage';
import { TextColumn, type SceneProps } from './common';

const rise = (p: number): React.CSSProperties => ({ opacity: p, transform: `translateY(${(1 - p) * 18}px)` });

export const Market: React.FC<SceneProps> = ({ layout }) => {
  const frame = useCurrentFrame();
  const tall = layout === 'tall';
  const c = scenes.market;
  // Everything arrives together in the first half second, then holds while the voice talks.
  const IN = 4;
  const peopleAt = [IN, IN, IN];
  const whyAt = IN;
  const tierAt = [IN, IN, IN];
  return (
    <Stage surface="bg" glow={{ x: '72%', y: '40%', r: 900 }} push={1.03}>
      <TextColumn
        layout={layout}
        kicker={c.kicker}
        lines={c.lines}
        at={[IN, IN]}
        keep
        caption={c.caption}
        captionAt={IN}
        style={tall ? { top: 130 } : { left: 120, width: 640 }}
      >
        <div style={{ display: 'flex', flexDirection: 'column', gap: 16, marginTop: 18 }}>
          {market.why.map((m) => (
            <div key={m.value} style={{ display: 'flex', alignItems: 'baseline', gap: 16, ...rise(progress(frame, whyAt, 18)) }}>
              <span style={{ fontFamily: fontFamily.sans, fontSize: 40, fontWeight: 800, letterSpacing: '-0.03em', color: color.ink, whiteSpace: 'nowrap' }}>{m.value}</span>
              <span style={{ fontFamily: fontFamily.sans, fontSize: 22, lineHeight: '28px', fontWeight: 500, color: color.ink3 }}>{m.label}</span>
            </div>
          ))}
        </div>
      </TextColumn>
      <div style={{ position: 'absolute', left: tall ? 70 : 860, right: tall ? 70 : 120, top: tall ? 1000 : 170, display: 'flex', flexDirection: 'column', gap: 56 }}>
        <div style={{ display: 'flex', gap: 36 }}>
          {market.people.map((p, i) => (
            <div key={p.label} style={{ flex: 1, display: 'flex', flexDirection: 'column', gap: 6, ...rise(progress(frame, peopleAt[i] ?? 0, 18)) }}>
              <span style={{ fontFamily: fontFamily.sans, fontSize: 84, lineHeight: 1, fontWeight: 800, letterSpacing: '-0.045em', color: i === 2 ? color.brand : color.ink }}>{p.value}</span>
              <span style={{ fontFamily: fontFamily.sans, fontSize: 24, fontWeight: 600, color: color.ink2 }}>{p.label}</span>
            </div>
          ))}
        </div>
        <div style={{ display: 'flex', gap: 20 }}>
          {market.tiers.map((t, i) => (
            <div
              key={t.who}
              style={{
                flex: 1,
                background: i === 0 ? color.ink : color.surface,
                color: i === 0 ? color.onBrand : color.ink,
                border: `1px solid ${i === 0 ? color.ink : color.border}`,
                borderRadius: radius.l,
                padding: 26,
                display: 'flex',
                flexDirection: 'column',
                gap: 10,
                boxShadow: shadow.e1,
                fontFamily: fontFamily.sans,
                ...rise(progress(frame, tierAt[i] ?? 0, 16)),
              }}
            >
              <span style={{ fontSize: 40, lineHeight: 1, fontWeight: 800, letterSpacing: '-0.03em' }}>{t.price}</span>
              <span style={{ fontSize: 22, fontWeight: 700 }}>{t.who}</span>
              <span style={{ fontSize: 18, lineHeight: '24px', fontWeight: 500, color: i === 0 ? color.nightInk2 : color.ink3 }}>{t.what}</span>
            </div>
          ))}
        </div>
      </div>
    </Stage>
  );
};
