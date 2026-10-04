// Social cut: 9:16, 1080 × 1920, ≈ 27 s. Beats 1, 3+4 merged, 6, 7, 9, re-laid out (not cropped).
// Captions are the big headlines, burned in; it works with the sound off.
import React from 'react';
import { VERT_XFADE, totalFrames, vertOrder, type SceneId } from '../copy/script';
import { Ask } from '../scenes/Ask';
import { Emergency } from '../scenes/Emergency';
import { EndCard } from '../scenes/EndCard';
import { Hook } from '../scenes/Hook';
import { WatchGuard } from '../scenes/WatchGuard';
import { Cut, place } from './Cut';

export const VERT_FRAMES = totalFrames(vertOrder, VERT_XFADE);
const placed = place(vertOrder, VERT_XFADE);

const scene = (id: SceneId): React.ReactNode => {
  switch (id) {
    case 'hook':
      return <Hook layout="tall" compact />;
    case 'ask':
      return <Ask layout="tall" merged />;
    case 'watch':
      return <WatchGuard layout="tall" fast />;
    case 'emergency':
      return <Emergency layout="tall" fast />;
    case 'end':
      return <EndCard layout="tall" />;
    default:
      return null;
  }
};

export const Vertical9x16: React.FC = () => <Cut placed={placed} xfade={VERT_XFADE} render={scene} total={VERT_FRAMES} cut="vertical" />;
