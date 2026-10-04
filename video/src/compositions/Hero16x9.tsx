// Hero cut: 16:9, 1920 × 1080, 30 fps, ≈ 117 s → site/media/demo.mp4.
import React from 'react';
import { HERO_XFADE, heroOrder, totalFrames, type SceneId } from '../copy/script';
import { Ask } from '../scenes/Ask';
import { Celia } from '../scenes/Celia';
import { Emergency } from '../scenes/Emergency';
import { EndCard } from '../scenes/EndCard';
import { Hook } from '../scenes/Hook';
import { Market } from '../scenes/Market';
import { Reveal } from '../scenes/Reveal';
import { Scan } from '../scenes/Scan';
import { Stakes } from '../scenes/Stakes';
import { Trust } from '../scenes/Trust';
import { Verdict } from '../scenes/Verdict';
import { Visit } from '../scenes/Visit';
import { WatchGuard } from '../scenes/WatchGuard';
import { Cut, place } from './Cut';

export const HERO_FRAMES = totalFrames(heroOrder, HERO_XFADE);
const placed = place(heroOrder, HERO_XFADE);

const scene = (id: SceneId): React.ReactNode => {
  switch (id) {
    case 'hook':
      return <Hook layout="wide" />;
    case 'stakes':
      return <Stakes layout="wide" />;
    case 'reveal':
      return <Reveal layout="wide" />;
    case 'ask':
      return <Ask layout="wide" />;
    case 'verdict':
      return <Verdict layout="wide" />;
    case 'scan':
      return <Scan layout="wide" />;
    case 'watch':
      return <WatchGuard layout="wide" />;
    case 'emergency':
      return <Emergency layout="wide" />;
    case 'visit':
      return <Visit layout="wide" />;
    case 'celia':
      return <Celia layout="wide" />;
    case 'trust':
      return <Trust layout="wide" />;
    case 'market':
      return <Market layout="wide" />;
    case 'end':
      return <EndCard layout="wide" />;
  }
};

export const Hero16x9: React.FC = () => <Cut placed={placed} xfade={HERO_XFADE} render={scene} total={HERO_FRAMES} cut="hero" />;
