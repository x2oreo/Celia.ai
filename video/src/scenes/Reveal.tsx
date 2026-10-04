// Beat 2: the phone rises on Today (v2 01), the silk orb waiting in the tab bar. Wordmark + one-line promise.
import React from 'react';
import { useCurrentFrame } from 'remotion';
import { scenes } from '../copy/script';
import { settle, wordIn } from '../theme/motion';
import { color, film, fontFamily } from '../theme/tokens';
import { PhoneFrame } from '../primitives/Devices';
import { Stage } from '../primitives/Stage';
import { Headline, Kicker } from '../primitives/Type';
import { StatusBar } from '../primitives/Devices';
import { TodayWithTabs } from '../ui/Heart';
import { Float, phoneSlot, type SceneProps } from './common';

export const Wordmark: React.FC<{ start: number; size?: number; tone?: 'light' | 'dark'; align?: 'left' | 'center' }> = ({
  start,
  size = film.wordmark.fontSize,
  tone = 'light',
  align = 'left',
}) => {
  const frame = useCurrentFrame();
  const a = wordIn(frame, start, 0);
  return (
    <div
      style={{
        ...film.wordmark,
        fontSize: size,
        lineHeight: `${size}px`,
        fontFamily: fontFamily.sans,
        color: tone === 'dark' ? color.nightInk : color.ink,
        opacity: a.opacity,
        transform: `translateY(${a.y}px)`,
        textAlign: align,
      }}
    >
      Celia<span style={{ color: color.brand }}>.ai</span>
    </div>
  );
};

export const Reveal: React.FC<SceneProps> = ({ layout }) => {
  const frame = useCurrentFrame();
  const c = scenes.reveal;
  const tall = layout === 'tall';
  const slot = phoneSlot(layout);
  const enter = settle(frame, 4, 30);
  return (
    <Stage surface="bg" glow={{ x: tall ? '50%' : '74%', y: tall ? '62%' : '50%', r: 760 }}>
      <div
        style={{
          position: 'absolute',
          display: 'flex',
          flexDirection: 'column',
          gap: 24,
          alignItems: tall ? 'center' : 'flex-start',
          ...(tall ? { left: 70, right: 70, top: 170 } : { left: 150, width: 820, top: '50%', transform: 'translateY(-50%)' }),
        }}
      >
        <Kicker text={c.kicker} start={10} tall={tall} />
        <Wordmark start={16} align={tall ? 'center' : 'left'} />
        <Headline text={c.lines[1] ?? ''} start={30} style={tall ? film.subTall : { ...film.sub, fontSize: 36, lineHeight: '46px' }} muted align={tall ? 'center' : 'left'} maxWidth={tall ? 900 : 640} />
      </div>
      <Float x={slot.x} y={slot.y} seed={1} enter={enter} enterFrom={{ x: 0, y: 80 }}>
        <PhoneFrame scale={slot.scale}>
          <StatusBar time="13:50" />
          <TodayWithTabs bpm={72} zone="CALM" />
        </PhoneFrame>
      </Float>
    </Stage>
  );
};
