// Beat 3 (and 3+4 in the vertical cut): voice conversation. Listening → Thinking (tool step) → Speaking.
import React from 'react';
import { useCurrentFrame } from 'remotion';
import { chat, scenes } from '../copy/script';
import { PhoneFrame } from '../primitives/Devices';
import { Stage } from '../primitives/Stage';
import { ConversationScreen } from '../ui/Conversation';
import { conversationAt, heroTimeline, tallTimeline } from './conversation';
import { Float, TextColumn, phoneSlot, type SceneProps } from './common';

export const Ask: React.FC<SceneProps & { merged?: boolean }> = ({ layout, merged = false }) => {
  const frame = useCurrentFrame();
  const slot = phoneSlot(layout);
  const t = merged ? tallTimeline : heroTimeline;
  const quote = `“${chat.user}”`;
  // Vertical (sound off): Ola's words as a big caption, then the verdict line takes over.
  const lines = merged ? [quote, scenes.verdict.lines.join(' ')] : scenes.ask.lines;
  const at = merged ? [t.hear, t.speak + 40] : [8, t.speak + 6];
  return (
    <Stage surface="bg" glow={{ x: layout === 'tall' ? '50%' : '74%', y: layout === 'tall' ? '62%' : '50%', r: 760 }} push={1.04}>
      <TextColumn
        layout={layout}
        kicker={merged ? 'ASK, THEN CHECK' : scenes.ask.kicker}
        lines={lines}
        at={at}
        caption={merged ? scenes.verdict.caption : undefined}
        captionAt={t.speak + 60}
      />
      <Float x={slot.x} y={slot.y} seed={1}>
        <PhoneFrame scale={slot.scale}>
          <ConversationScreen s={conversationAt(frame, t)} />
        </PhoneFrame>
      </Float>
    </Stage>
  );
};
