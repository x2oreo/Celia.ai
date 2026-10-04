// Shared scene scaffolding: layout (wide 16:9 / tall 9:16), the text column, floating device slots.
import React from 'react';
import { interpolate, useCurrentFrame } from 'remotion';
import { clampOpts, drift } from '../theme/motion';
import { film, type TypeStyle } from '../theme/tokens';
import { Caption, Headline, Kicker, type Tone } from '../primitives/Type';

export type Layout = 'wide' | 'tall';

export interface SceneProps {
  layout: Layout;
}

export const canvas = (layout: Layout): { w: number; h: number } =>
  layout === 'wide' ? { w: 1920, h: 1080 } : { w: 1080, h: 1920 };

/** Headline style per layout. */
export const headlineStyle = (layout: Layout): TypeStyle => (layout === 'wide' ? film.headline : film.headlineTall);

/** One line at a time: line i is visible in [at[i], at[i+1]) and fades out before the next comes in. */
export const OneLineAtATime: React.FC<{
  lines: string[];
  at: number[];
  layout: Layout;
  tone?: Tone;
  align?: 'left' | 'center';
  maxWidth?: number;
  keep?: boolean; // keep earlier lines (stacked) instead of replacing them
  accentWord?: string;
}> = ({ lines, at, layout, tone = 'light', align = 'left', maxWidth, keep = false, accentWord }) => {
  const frame = useCurrentFrame();
  const st = headlineStyle(layout);
  if (keep) {
    return (
      <div style={{ display: 'flex', flexDirection: 'column', gap: 6 }}>
        {lines.map((l, i) => (
          <Headline
            key={l}
            text={l}
            start={at[i] ?? 0}
            tone={tone}
            style={st}
            muted={i > 0}
            align={align}
            maxWidth={maxWidth}
            accentWord={accentWord}
          />
        ))}
      </div>
    );
  }
  return (
    <div style={{ position: 'relative', display: 'grid' }}>
      {lines.map((l, i) => {
        const start = at[i] ?? 0;
        const next = at[i + 1];
        const out = next === undefined ? 1 : interpolate(frame, [next - 10, next - 2], [1, 0], clampOpts);
        return (
          <div key={l} style={{ gridArea: '1 / 1', opacity: out, visibility: frame < start ? 'hidden' : 'visible' }}>
            <Headline text={l} start={start} tone={tone} style={st} align={align} maxWidth={maxWidth} accentWord={accentWord} />
          </div>
        );
      })}
    </div>
  );
};

/** Text column: kicker, lines, optional caption. */
export const TextColumn: React.FC<{
  layout: Layout;
  kicker: string;
  lines: string[];
  at: number[];
  caption?: string;
  captionAt?: number;
  tone?: Tone;
  keep?: boolean;
  style?: React.CSSProperties;
  accentWord?: string;
  children?: React.ReactNode;
}> = ({ layout, kicker, lines, at, caption, captionAt = 30, tone = 'light', keep = false, style, accentWord, children }) => {
  const tall = layout === 'tall';
  const align = tall ? 'center' : 'left';
  return (
    <div
      style={{
        position: 'absolute',
        display: 'flex',
        flexDirection: 'column',
        alignItems: tall ? 'center' : 'flex-start',
        gap: tall ? 26 : 22,
        ...(tall ? { left: 70, right: 70, top: 150 } : { left: 150, width: 720, top: '50%', transform: 'translateY(-50%)' }),
        ...style,
      }}
    >
      {kicker !== '' && <Kicker text={kicker} start={Math.max(0, (at[0] ?? 0) - 8)} tone={tone} tall={tall} />}
      <OneLineAtATime
        lines={lines}
        at={at}
        layout={layout}
        tone={tone}
        align={align}
        maxWidth={tall ? 940 : 720}
        keep={keep}
        accentWord={accentWord}
      />
      {children}
      {caption !== undefined && (
        <div style={{ marginTop: tall ? 6 : 10 }}>
          <Caption text={caption} start={captionAt} tone={tone} tall={tall} align={align} />
        </div>
      )}
    </div>
  );
};

/** Absolutely placed device that floats with a slow parallax drift (≤ 8 px). */
export const Float: React.FC<{
  x: number;
  y: number;
  seed: number;
  children: React.ReactNode;
  enter?: number; // 0..1 entrance progress
  enterFrom?: { x: number; y: number };
  shake?: number;
  amp?: number;
}> = ({ x, y, seed, children, enter = 1, enterFrom = { x: 0, y: 60 }, shake = 0, amp = 8 }) => {
  const frame = useCurrentFrame();
  const d = drift(frame, seed, amp);
  const ex = (1 - enter) * enterFrom.x;
  const ey = (1 - enter) * enterFrom.y;
  return (
    <div
      style={{
        position: 'absolute',
        left: x,
        top: y,
        opacity: enter,
        transform: `translate(${d.x + ex + shake}px, ${d.y + ey}px)`,
      }}
    >
      {children}
    </div>
  );
};

/** Where the main phone sits in each layout (shared so scenes match-cut on the same spot). */
export const phoneSlot = (layout: Layout): { x: number; y: number; scale: number } =>
  layout === 'wide' ? { x: 1170, y: 92, scale: 1.1 } : { x: 260, y: 650, scale: 1.46 };
