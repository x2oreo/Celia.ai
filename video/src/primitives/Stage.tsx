// A scene's backdrop: flat surface, one soft coral wash (the only decoration), slow camera push-in.
import React from 'react';
import { AbsoluteFill, useCurrentFrame, useVideoConfig } from 'remotion';
import { pushIn } from '../theme/motion';
import { brandAlpha, color } from '../theme/tokens';

export type Surface = 'bg' | 'night' | 'black' | 'alt';

const surfaceColor: Record<Surface, string> = {
  bg: color.bg,
  night: color.night,
  black: color.black,
  alt: color.surfaceAlt,
};

export const Stage: React.FC<{
  surface: Surface;
  children: React.ReactNode;
  push?: number;
  glow?: { x: string; y: string; r: number; strength?: number } | null;
}> = ({ surface, children, push = 1.06, glow = { x: '70%', y: '50%', r: 900 } }) => {
  const frame = useCurrentFrame();
  const { durationInFrames } = useVideoConfig();
  const k = pushIn(frame, durationInFrames, push);
  const dark = surface === 'night' || surface === 'black';
  const strength = glow?.strength ?? (dark ? 0.22 : 0.12);
  return (
    <AbsoluteFill style={{ background: surfaceColor[surface], overflow: 'hidden' }}>
      {glow !== null && (
        <AbsoluteFill
          style={{
            background: `radial-gradient(${glow.r}px circle at ${glow.x} ${glow.y}, ${brandAlpha(strength)} 0%, ${brandAlpha(0)} 70%)`,
          }}
        />
      )}
      <AbsoluteFill style={{ transform: `scale(${k})`, transformOrigin: '50% 50%' }}>{children}</AbsoluteFill>
    </AbsoluteFill>
  );
};
