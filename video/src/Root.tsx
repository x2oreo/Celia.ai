import React from 'react';
import { Composition } from 'remotion';
import { FPS } from './theme/motion';
import { HERO_FRAMES, Hero16x9 } from './compositions/Hero16x9';
import { VERT_FRAMES, Vertical9x16 } from './compositions/Vertical9x16';

export const Root: React.FC = () => (
  <>
    <Composition id="Hero16x9" component={Hero16x9} durationInFrames={HERO_FRAMES} fps={FPS} width={1920} height={1080} />
    <Composition id="Vertical9x16" component={Vertical9x16} durationInFrames={VERT_FRAMES} fps={FPS} width={1080} height={1920} />
  </>
);
