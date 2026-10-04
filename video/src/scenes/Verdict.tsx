// Beat 4: the conversation continues; "Details" opens the full verdict sheet, the KNOWN RISK badge settles,
// "How we know" ticks in. The narrator says where the verdict comes from.
import React from 'react';
import { interpolate, useCurrentFrame } from 'remotion';
import { heroVo, voAt } from '../audio/cues';
import { voWordAt } from '../audio/vo';
import { heroOrder, HERO_XFADE, scenes } from '../copy/script';
import { clampOpts, easeInOut } from '../theme/motion';
import { PhoneFrame } from '../primitives/Devices';
import { Stage } from '../primitives/Stage';
import { ConversationScreen } from '../ui/Conversation';
import { conversationAt, heroTimeline } from './conversation';
import { Float, TextColumn, phoneSlot, type SceneProps } from './common';

const ASK_FRAMES = heroOrder.find((s) => s.id === 'ask')?.frames ?? 420;
const VO = voAt(heroVo, 'verdict');

export const Verdict: React.FC<SceneProps> = ({ layout }) => {
  const frame = useCurrentFrame();
  const slot = phoneSlot(layout);
  const c = scenes.verdict;
  const f = ASK_FRAMES - HERO_XFADE + frame;
  // Push in on the card: the phone grows and drifts toward frame centre.
  const zoom = interpolate(frame, [20, 220], [1, 1.05], { ...clampOpts, easing: easeInOut });
  return (
    <Stage surface="bg" glow={{ x: '74%', y: '55%', r: 760 }} push={1.03}>
      <TextColumn layout={layout} kicker={c.kicker} lines={c.lines} at={[VO, VO + voWordAt('verdict', 7) - 3]} keep caption={c.caption} captionAt={VO + 110} />
      <div style={{ position: 'absolute', inset: 0, transform: `scale(${zoom})`, transformOrigin: `${slot.x + 210}px 540px` }}>
        <Float x={slot.x} y={slot.y} seed={1}>
          <PhoneFrame scale={slot.scale}>
            <ConversationScreen s={conversationAt(f, heroTimeline)} />
          </PhoneFrame>
        </Float>
      </div>
    </Stage>
  );
};
