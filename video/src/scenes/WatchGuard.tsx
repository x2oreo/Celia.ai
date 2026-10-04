// Beat 6: true-black watch v2. Home gauge, calm 72 → near your max (amber) → the heart-rate-high alert (red ring,
// v2-watches 7), a small wrist buzz on the frame only. The phone's agent checks in (B3) over Today.
// Simulated scenario: DEMO DATA on the watch, SIMULATED on the phone, and the caption says so.
import React from 'react';
import { interpolate, useCurrentFrame } from 'remotion';
import { heroVo, vertVo, voAt } from '../audio/cues';
import { voWordAt } from '../audio/vo';
import { scenes } from '../copy/script';
import { clampOpts, easeInOut, progress, settle, sheet } from '../theme/motion';
import { color } from '../theme/tokens';
import { PhoneFrame, Sheet, StatusBar } from '../primitives/Devices';
import { Stage } from '../primitives/Stage';
import { CheckInBody, TodayWithTabs } from '../ui/Heart';
import { WatchLive } from '../ui/Watch';
import { WatchFrame } from '../primitives/Devices';
import { Float, TextColumn, type SceneProps } from './common';

/** Beat timing in scene frames (the vertical cut plays the same beat faster). Shared with the soundtrack. */
export const watchTimes = (fast: boolean) => {
  const k = fast ? 0.7 : 1;
  return { CLIMB_START: 40 * k, CLIMB_END: 104 * k, ALERT: 110 * k, PHONE: 128 * k, SHEET: 146 * k };
};

export const WatchGuard: React.FC<SceneProps & { fast?: boolean }> = ({ layout, fast = false }) => {
  const frame = useCurrentFrame();
  const tall = layout === 'tall';
  const c = scenes.watch;
  const vo = voAt(fast ? vertVo : heroVo, 'watch');
  const { CLIMB_START, CLIMB_END, ALERT, PHONE, SHEET } = watchTimes(fast);

  const bpm = interpolate(frame, [CLIMB_START, CLIMB_END], [72, 165], { ...clampOpts, easing: easeInOut });
  const alert = progress(frame, ALERT, 10);
  // Wrist buzz: a short ±3 px shake on the watch frame only, never on a verdict.
  const buzzT = frame - ALERT;
  const shake = buzzT >= 0 && buzzT < 24 ? Math.sin(buzzT * 2.6) * 3 * (1 - buzzT / 24) : 0;

  const phoneIn = settle(frame, PHONE, 26);
  const sh = sheet(frame, SHEET);

  const watchPos = tall ? { x: 540 - 233 * 1.05, y: 560, s: 1.05 } : { x: 760, y: 300, s: 1.0 };
  const phonePos = tall ? { x: 540 - 384 * 0.82 / 2, y: 1130, s: 0.82 } : { x: 1330, y: 120, s: 0.98 };

  return (
    <Stage surface="black" glow={{ x: tall ? '50%' : '50%', y: tall ? '40%' : '50%', r: 700, strength: 0.14 }} push={1.04}>
      <TextColumn
        layout={layout}
        kicker={c.kicker}
        lines={c.lines}
        at={fast ? [vo, ALERT + 8] : [vo + 2, vo + voWordAt('watch', 9) - 4]}
        keep
        tone="dark"
        caption={c.caption}
        captionAt={fast ? 21 : 30}
        style={tall ? { top: 140 } : { left: 120, width: 560 }}
      />
      <Float x={watchPos.x} y={watchPos.y} seed={3} shake={shake} amp={6}>
        <WatchFrame scale={watchPos.s}>
          <WatchLive bpm={bpm} alert={alert} />
        </WatchFrame>
      </Float>
      <Float x={phonePos.x} y={phonePos.y} seed={4} enter={phoneIn} enterFrom={{ x: tall ? 0 : 80, y: tall ? 80 : 0 }}>
        <PhoneFrame scale={phonePos.s} dark>
          <StatusBar time="14:32" right="5G · 64%" />
          <TodayWithTabs bpm={bpm} zone={bpm >= 110 ? 'ALERT' : bpm >= 99 ? 'ELEVATED' : 'CALM'} />
          <div style={{ position: 'absolute', inset: 0, background: color.scrim, opacity: sh.scrim }} />
          <Sheet style={{ transform: `translateY(${sh.y * 100}%)` }}>
            <CheckInBody bpm={165} />
          </Sheet>
        </PhoneFrame>
      </Float>
    </Stage>
  );
};
