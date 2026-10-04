// Beat 10: built on HarmonyOS. Celia, the system assistant, answers "can I take ibuprofen?" through the app's intent
// (insightintents/CheckDrugIntent.ets) with the app's own verdict; then the watch's check-in lands on the phone.
// The assistant sheet is drawn neutral (no system trade dress): a label, the request, and the app's answer card.
import React from 'react';
import { useCurrentFrame } from 'remotion';
import { heroVo, voAt } from '../audio/cues';
import { voWordAt } from '../audio/vo';
import { celia, scenes } from '../copy/script';
import { progress, settle, sheet } from '../theme/motion';
import { color, fontFamily, radius, risk, type } from '../theme/tokens';
import { SourceBadge } from '../primitives/Badges';
import { PhoneFrame, Sheet, StatusBar, WatchFrame } from '../primitives/Devices';
import { Icon } from '../primitives/Icon';
import { RiskShape } from '../primitives/RiskShape';
import { Stage } from '../primitives/Stage';
import { TodayWithTabs } from '../ui/Heart';
import { AgentAvatar } from '../ui/Orb';
import { WatchCheckIn } from '../ui/Watch';
import { Float, TextColumn, type SceneProps } from './common';

/** Beat timing in scene frames, shared with the soundtrack. */
export const celiaTimes = () => {
  const vo = voAt(heroVo, 'celia');
  const ask = vo + voWordAt('celia', 5) - 10;
  const watchAt = vo + voWordAt('celia', 11) - 8;
  return { CHIPS: vo + voWordAt('celia', 2), ASK: ask, ANSWER: ask + 44, WATCH: watchAt, PICK: watchAt + 34, TOAST: watchAt + 46 };
};

const AssistantSheet: React.FC<{ typed: number; answer: number }> = ({ typed, answer }) => {
  const shown = celia.ask.slice(0, Math.round(celia.ask.length * typed));
  const s = risk.NOT_LISTED;
  return (
    <div style={{ display: 'flex', flexDirection: 'column', gap: 14 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 8, color: color.ink3 }}>
        <Icon name="wave" size={18} />
        <span style={{ ...type.label, letterSpacing: '0.08em' }}>CELIA</span>
      </div>
      <div style={{ ...type.title3, color: color.ink, minHeight: 52 }}>
        {shown}
        {typed < 1 && <span style={{ color: color.ink4 }}>|</span>}
      </div>
      <div
        style={{
          background: color.surface,
          border: `1px solid ${color.border}`,
          borderRadius: radius.ml,
          padding: 14,
          display: 'flex',
          flexDirection: 'column',
          gap: 10,
          opacity: answer,
          transform: `translateY(${(1 - answer) * 12}px)`,
        }}
      >
        <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
          <AgentAvatar dim={24} />
          <span style={{ ...type.bodySm, fontWeight: 700 }}>{celia.from}</span>
          <span style={{ marginLeft: 'auto' }}>
            <SourceBadge label="OFFLINE" />
          </span>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 10, padding: '8px 12px', borderRadius: radius.s, background: s.tint }}>
          <RiskShape level="NOT_LISTED" dim={24} />
          <span style={{ ...type.headline, color: s.text }}>{celia.answerTitle}</span>
        </div>
        <div style={{ ...type.bodySm, color: color.ink2 }}>{celia.answer}</div>
      </div>
    </div>
  );
};

const PlatformChips: React.FC<{ start: number; tall: boolean }> = ({ start, tall }) => {
  const frame = useCurrentFrame();
  return (
    <div style={{ display: 'flex', flexWrap: 'wrap', gap: 10, marginTop: 10, justifyContent: tall ? 'center' : 'flex-start' }}>
      {celia.platform.map((p, i) => {
        const a = progress(frame, start + i * 5, 12);
        return (
          <span key={p} style={{ opacity: a, transform: `translateY(${(1 - a) * 8}px)` }}>
            <SourceBadge label={p.toUpperCase()} dark scale={2.2} solid={i === 0} />
          </span>
        );
      })}
    </div>
  );
};

export const Celia: React.FC<SceneProps> = ({ layout }) => {
  const frame = useCurrentFrame();
  const tall = layout === 'tall';
  const c = scenes.celia;
  const vo = voAt(heroVo, 'celia');
  const t = celiaTimes();
  const sh = sheet(frame, t.ASK);
  const typed = progress(frame, t.ASK + 6, 30);
  const answer = progress(frame, t.ANSWER, 12);
  const watchIn = settle(frame, t.WATCH, 24);
  const chosen = progress(frame, t.PICK, 10);
  const toast = progress(frame, t.TOAST, 12);
  const phone = tall ? { x: 112, y: 820, s: 1.0 } : { x: 1000, y: 128, s: 0.98 };
  const watchPos = tall ? { x: 600, y: 1240, s: 0.8 } : { x: 1440, y: 430, s: 0.82 };
  return (
    <Stage surface="night" glow={{ x: tall ? '50%' : '68%', y: tall ? '62%' : '50%', r: 820, strength: 0.2 }} push={1.04}>
      <TextColumn layout={layout} kicker={c.kicker} lines={c.lines} at={[vo + voWordAt('celia', 5) - 4, t.WATCH - 4]} keep tone="dark" style={tall ? { top: 130 } : { left: 120, width: 760 }}>
        <PlatformChips start={t.CHIPS} tall={tall} />
      </TextColumn>
      <Float x={phone.x} y={phone.y} seed={10}>
        <PhoneFrame scale={phone.s} dark>
          <StatusBar time="11:20" right="5G · 77%" />
          <TodayWithTabs bpm={66} zone="CALM" />
          <div style={{ position: 'absolute', inset: 0, background: color.scrim, opacity: sh.scrim }} />
          <Sheet style={{ transform: `translateY(${sh.y * 100}%)` }}>
            <AssistantSheet typed={typed} answer={answer} />
          </Sheet>
          <div
            style={{
              position: 'absolute',
              left: 14,
              right: 14,
              top: 46,
              padding: '12px 14px',
              borderRadius: radius.m,
              background: color.surface,
              boxShadow: `0 8px 24px ${color.scrim}`,
              display: 'flex',
              alignItems: 'center',
              gap: 10,
              fontFamily: fontFamily.sans,
              opacity: toast,
              transform: `translateY(${(1 - toast) * -16}px)`,
            }}
          >
            <Icon name="watch" size={20} color={color.ink2} />
            <span style={{ ...type.bodySm, fontWeight: 700, flex: 1 }}>From your watch: feeling fine</span>
            <span style={{ ...type.caption, color: color.ink3 }}>now</span>
          </div>
        </PhoneFrame>
      </Float>
      <Float x={watchPos.x} y={watchPos.y} seed={11} enter={watchIn} enterFrom={{ x: 80, y: 0 }} amp={6}>
        <WatchFrame scale={watchPos.s}>
          <WatchCheckIn chosen={chosen} />
        </WatchFrame>
      </Float>
    </Stage>
  );
};
