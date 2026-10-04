// Beat 3: the orb that went still in the cold open lights back up and speaks: it is the agent now. The phone rises on
// Today (v2 01), the silk orb waiting in the tab bar. Wordmark + one-line promise.
import React from 'react';
import { useCurrentFrame } from 'remotion';
import { heroVo, voAt } from '../audio/cues';
import { voLevel } from '../audio/vo';
import { scenes } from '../copy/script';
import { settle, wordIn } from '../theme/motion';
import { color, film, fontFamily } from '../theme/tokens';
import { PhoneFrame } from '../primitives/Devices';
import { Stage } from '../primitives/Stage';
import { Headline, Kicker } from '../primitives/Type';
import { StatusBar } from '../primitives/Devices';
import { TodayWithTabs } from '../ui/Heart';
import { SilkOrb, type OrbPhase } from '../ui/SilkOrb';
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
  // Muted at first (as the cold open left it), then it wakes and speaks the reveal line.
  const vo = voAt(heroVo, 'reveal');
  const orbIn = settle(frame, 0, 20);
  const phaseAt = (f: number): OrbPhase => (f < 8 ? 'MUTED' : f < vo ? 'CONNECTING' : 'SPEAKING');
  const levelAt = (f: number): number => voLevel('reveal', f - vo);
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
        <div style={{ marginBottom: tall ? 10 : 6, opacity: orbIn, transform: `scale(${0.8 + 0.2 * orbIn})`, transformOrigin: tall ? '50% 50%' : '0% 50%' }}>
          <SilkOrb dim={tall ? 150 : 120} phaseAt={phaseAt} levelAt={levelAt} seed={3} pixelRatio={3} />
        </div>
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
