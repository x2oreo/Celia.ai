// Beat 9: warm dark close. The silk orb breathing, wordmark, promise, platform line, disclaimer.
import React from 'react';
import { useCurrentFrame } from 'remotion';
import { heroVo, vertVo, voAt } from '../audio/cues';
import { voWordAt } from '../audio/vo';
import { endCard, scenes } from '../copy/script';
import { progress } from '../theme/motion';
import { color, film, fontFamily } from '../theme/tokens';
import { Stage } from '../primitives/Stage';
import { Caption, Headline } from '../primitives/Type';
import { SilkOrb } from '../ui/SilkOrb';
import { Wordmark } from './Reveal';
import type { SceneProps } from './common';

export const EndCard: React.FC<SceneProps> = ({ layout }) => {
  const frame = useCurrentFrame();
  const tall = layout === 'tall';
  const c = scenes.end;
  const orbIn = progress(frame, 0, 24);
  const vo = voAt(tall ? vertVo : heroVo, 'end');
  const meta = progress(frame, vo + 50, 18);
  return (
    <Stage surface="night" glow={{ x: '50%', y: tall ? '36%' : '34%', r: tall ? 900 : 760, strength: 0.26 }} push={1.03}>
      <div
        style={{
          position: 'absolute',
          inset: 0,
          display: 'flex',
          flexDirection: 'column',
          alignItems: 'center',
          justifyContent: 'center',
          gap: tall ? 34 : 26,
          paddingBottom: tall ? 120 : 40,
        }}
      >
        <div style={{ opacity: orbIn, transform: `scale(${0.9 + 0.1 * orbIn})`, marginBottom: tall ? 30 : 18 }}>
          <SilkOrb dim={tall ? 200 : 168} phase="OFF" seed={7} pixelRatio={3} />
        </div>
        <Wordmark start={12} tone="dark" align="center" size={tall ? 150 : 132} />
        <Headline text={c.lines[1] ?? ''} start={vo + voWordAt('end', 1) - 4} tone="dark" style={tall ? film.subTall : { ...film.sub, fontSize: 40, lineHeight: '50px' }} align="center" />
        <div
          style={{
            display: 'flex',
            flexDirection: tall ? 'column' : 'row',
            alignItems: 'center',
            gap: tall ? 10 : 18,
            marginTop: 10,
            opacity: meta,
            fontFamily: fontFamily.sans,
            fontSize: tall ? 28 : 22,
            fontWeight: 600,
            color: color.nightInk2,
          }}
        >
          <span>{endCard.built}</span>
          {!tall && <span style={{ width: 5, height: 5, borderRadius: 3, background: color.nightInk3 }} />}
          <span>{endCard.event}</span>
          {endCard.url !== '' && <span style={{ color: color.brand }}>{endCard.url}</span>}
        </div>
      </div>
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: tall ? 110 : 56 }}>
        <Caption text={c.caption ?? ''} start={vo + 64} tone="dark" tall={tall} align="center" />
      </div>
    </Stage>
  );
};
