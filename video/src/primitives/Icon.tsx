// Icons: Lucide, the app's one icon set (DESIGN §6.6b). Same outlined-fill paths as the app's ic_*.svg, tinted
// with a token colour (currentColor by default).
import React from 'react';
import { lucide, type LucideName } from './lucide';

// Older names used by the scenes, mapped to the Lucide job they do.
const alias = {
  back: 'chevronLeft',
  chevron: 'chevronRight',
  x: 'close',
  globe: 'languages',
  barcode: 'scan',
  heartO: 'tabHeart',
  hands: 'hand',
  pin: 'location',
  device: 'watch',
} as const satisfies Record<string, LucideName>;

export type IconName = LucideName | keyof typeof alias;

const resolve = (name: IconName): LucideName => (name in alias ? alias[name as keyof typeof alias] : (name as LucideName));

export const Icon: React.FC<{ name: IconName; size?: number; color?: string; stroke?: number }> = ({
  name,
  size = 20,
  color,
}) => (
  <svg width={size} height={size} viewBox="0 0 24 24" style={{ flex: 'none', display: 'block' }}>
    <path fill={color ?? 'currentColor'} fillRule="evenodd" d={lucide[resolve(name)]} />
  </svg>
);

export const HeartFill: React.FC<{ size: number; color: string }> = ({ size, color }) => (
  <svg width={size} height={size} viewBox="0 0 24 24" style={{ flex: 'none', display: 'block' }}>
    <path fill={color} fillRule="evenodd" d={lucide.heartFill} />
  </svg>
);
