// A cut = scenes in order, each fading in over the previous one (12–18 frame crossfades), plus its soundtrack.
import React from 'react';
import { AbsoluteFill, Sequence, interpolate, useCurrentFrame } from 'remotion';
import { Soundtrack } from '../audio/Soundtrack';
import type { SceneId } from '../copy/script';
import { clampOpts } from '../theme/motion';
import { color } from '../theme/tokens';
import { loadFonts } from '../theme/fonts';

loadFonts();

export interface Placed {
  id: SceneId;
  from: number;
  frames: number;
}

export const place = (order: { id: SceneId; frames: number }[], xfade: number): Placed[] => {
  let at = 0;
  return order.map((s) => {
    const p = { id: s.id, from: at, frames: s.frames };
    at += s.frames - xfade;
    return p;
  });
};

const FadeIn: React.FC<{ frames: number; children: React.ReactNode }> = ({ frames, children }) => {
  const frame = useCurrentFrame();
  const o = frames === 0 ? 1 : interpolate(frame, [0, frames], [0, 1], clampOpts);
  return <AbsoluteFill style={{ opacity: o }}>{children}</AbsoluteFill>;
};

export const Cut: React.FC<{
  placed: Placed[];
  xfade: number;
  render: (id: SceneId) => React.ReactNode;
  total: number;
  cut: 'hero' | 'vertical';
}> = ({ placed, xfade, render, total, cut }) => {
  return (
    <AbsoluteFill style={{ background: color.bg }}>
      {placed.map((p, i) => (
        <Sequence key={p.id} from={p.from} durationInFrames={p.frames} name={p.id}>
          <FadeIn frames={i === 0 ? 0 : xfade}>{render(p.id)}</FadeIn>
        </Sequence>
      ))}
      <Soundtrack placed={placed} total={total} cut={cut} xfade={xfade} />
    </AbsoluteFill>
  );
};
