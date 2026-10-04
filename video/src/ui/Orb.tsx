// Inline agent avatar (DESIGN §6.6: 28 / 40, a still Dawn gradient with the sheen, no bands) and the voice level
// stand-in. The animated orb is SilkOrb.tsx.
import React from 'react';
import { orbGradient, orbSheenGradient } from '../theme/tokens';

export type { OrbPhase } from './SilkOrb';

export const AgentAvatar: React.FC<{ dim: number }> = ({ dim }) => (
  <div style={{ position: 'relative', width: dim, height: dim, flex: 'none', borderRadius: '50%', overflow: 'hidden' }}>
    <div style={{ position: 'absolute', inset: 0, background: orbGradient }} />
    <div style={{ position: 'absolute', inset: 0, background: orbSheenGradient }} />
  </div>
);

/** Deterministic stand-in for voice loudness (0..1): layered sines, never random per render. */
export const voiceLevel = (frame: number, seed = 0): number => {
  const v =
    0.55 +
    0.25 * Math.sin(frame * 0.71 + seed) +
    0.15 * Math.sin(frame * 1.93 + seed * 2.1) +
    0.1 * Math.sin(frame * 0.27 + seed * 0.7);
  return Math.max(0, Math.min(1, v));
};
