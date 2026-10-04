// Beat 9: the everyday side. The doctor-visit brief builds row by row (since your last visit, then questions to
// ask), then the pharmacy card lands beside it on "At the pharmacy".
import React from 'react';
import { useCurrentFrame } from 'remotion';
import { heroVo, voAt } from '../audio/cues';
import { voWordAt } from '../audio/vo';
import { scenes } from '../copy/script';
import { progress, settle } from '../theme/motion';
import { PhoneFrame } from '../primitives/Devices';
import { Stage } from '../primitives/Stage';
import { DoctorBriefScreen, PharmacyCardScreen } from '../ui/Visit';
import { Float, TextColumn, type SceneProps } from './common';

/** Beat timing in scene frames, shared with the soundtrack. */
export const visitTimes = () => {
  const vo = voAt(heroVo, 'visit');
  return {
    // Rows land with "what happened", "which medicines were flagged", "what to ask".
    ROWS: [vo + voWordAt('visit', 8) - 4, vo + voWordAt('visit', 9), vo + voWordAt('visit', 10) - 2, vo + voWordAt('visit', 12)],
    ASK: vo + voWordAt('visit', 15) - 4,
    SHARE: vo + voWordAt('visit', 17) + 6,
    CARD: vo + voWordAt('visit', 18) - 6,
  };
};

export const Visit: React.FC<SceneProps> = ({ layout }) => {
  const frame = useCurrentFrame();
  const tall = layout === 'tall';
  const c = scenes.visit;
  const vo = voAt(heroVo, 'visit');
  const t = visitTimes();
  const rows = [...t.ROWS.map((at) => progress(frame, at, 12)), progress(frame, t.ASK, 12), progress(frame, t.ASK + 8, 12), progress(frame, t.SHARE, 12)];
  const cardIn = settle(frame, t.CARD, 26);
  const a = tall ? { x: 112, y: 820, s: 1.0 } : { x: 960, y: 128, s: 0.98 };
  const b = tall ? { x: 560, y: 900, s: 1.0 } : { x: 1400, y: 168, s: 0.98 };
  return (
    <Stage surface="bg" glow={{ x: tall ? '50%' : '72%', y: tall ? '66%' : '50%', r: 800 }} push={1.04}>
      <TextColumn layout={layout} kicker={c.kicker} lines={c.lines} at={[vo + 2, t.CARD - 4]} keep style={tall ? { top: 130 } : { left: 120, width: 760 }} />
      <Float x={a.x} y={a.y} seed={8}>
        <PhoneFrame scale={a.s}>
          <DoctorBriefScreen rows={rows} />
        </PhoneFrame>
      </Float>
      <Float x={b.x} y={b.y} seed={9} enter={cardIn} enterFrom={{ x: 90, y: 0 }}>
        <div style={{ transform: 'rotate(3deg)' }}>
          <PhoneFrame scale={b.s}>
            <PharmacyCardScreen />
          </PhoneFrame>
        </div>
      </Float>
    </Stage>
  );
};
