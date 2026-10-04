// Film typography: caps kicker, kinetic headline (words fade up with a 40 ms stagger), small caption.
import React from 'react';
import { useCurrentFrame } from 'remotion';
import { progress, wordIn } from '../theme/motion';
import { color, film, fontFamily, type TypeStyle } from '../theme/tokens';

export type Tone = 'light' | 'dark';

const inkFor = (tone: Tone): string => (tone === 'dark' ? color.nightInk : color.ink);
const subFor = (tone: Tone): string => (tone === 'dark' ? color.nightInk2 : color.ink3);

export const Kicker: React.FC<{ text: string; start: number; tone?: Tone; tall?: boolean; accent?: string }> = ({
  text,
  start,
  tone = 'light',
  tall = false,
  accent,
}) => {
  const frame = useCurrentFrame();
  const p = progress(frame, start, 14);
  const st = tall ? film.kickerTall : film.kicker;
  return (
    <div
      style={{
        ...st,
        fontFamily: fontFamily.sans,
        color: accent ?? (tone === 'dark' ? color.brand : color.brandText),
        opacity: p,
        transform: `translateY(${(1 - p) * 8}px)`,
        display: 'flex',
        alignItems: 'center',
        gap: 14,
      }}
    >
      <span
        style={{
          width: tall ? 40 : 32,
          height: 3,
          borderRadius: 2,
          background: accent ?? color.brand,
          transform: `scaleX(${p})`,
          transformOrigin: 'left center',
        }}
      />
      {text}
    </div>
  );
};

export const Headline: React.FC<{
  text: string;
  start: number;
  tone?: Tone;
  style?: TypeStyle;
  muted?: boolean;
  align?: 'left' | 'center';
  maxWidth?: number;
  accentWord?: string;
}> = ({ text, start, tone = 'light', style = film.headline, muted = false, align = 'left', maxWidth, accentWord }) => {
  const frame = useCurrentFrame();
  const words = text.split(' ');
  return (
    <div
      style={{
        ...style,
        fontFamily: fontFamily.sans,
        color: muted ? subFor(tone) : inkFor(tone),
        textAlign: align,
        maxWidth,
        textWrap: 'balance',
      }}
    >
      {words.map((w, i) => {
        const a = wordIn(frame, start, i);
        const isAccent = accentWord !== undefined && w.replace(/[.,]/g, '') === accentWord;
        return (
          <React.Fragment key={i}>
            <span
              style={{
                display: 'inline-block',
                opacity: a.opacity,
                transform: `translateY(${a.y}px)`,
                color: isAccent ? (tone === 'dark' ? color.brand : color.brandText) : undefined,
              }}
            >
              {w}
            </span>
            {i < words.length - 1 ? ' ' : null}
          </React.Fragment>
        );
      })}
    </div>
  );
};

export const Caption: React.FC<{ text: string; start: number; tone?: Tone; tall?: boolean; align?: 'left' | 'center' }> = ({
  text,
  start,
  tone = 'light',
  tall = false,
  align = 'left',
}) => {
  const frame = useCurrentFrame();
  const p = progress(frame, start, 18);
  return (
    <div
      style={{
        ...(tall ? film.captionTall : film.caption),
        fontFamily: fontFamily.sans,
        color: tone === 'dark' ? color.nightInk3 : color.ink3,
        opacity: p,
        textAlign: align,
      }}
    >
      {text}
    </div>
  );
};
