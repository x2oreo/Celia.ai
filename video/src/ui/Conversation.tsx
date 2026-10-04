// The agent stage (DESIGN §10.1a 02 empty, 03 live voice): header, captions instead of a chat list, cards sliding
// in under them, and the floating orb dock at the bottom with its soft backdrop. Verdict details open as a sheet.
import React from 'react';
import { chat, verdict as vcopy } from '../copy/script';
import type { ConversationState } from '../scenes/conversation';
import { color, fontFamily, radius, risk, size, type } from '../theme/tokens';
import { Sheet, StatusBar } from '../primitives/Devices';
import { Icon } from '../primitives/Icon';
import { RiskShape } from '../primitives/RiskShape';
import { ToolStep } from './Chat';
import { SilkOrb } from './SilkOrb';
import { VerdictCard } from './VerdictCard';

export type { ConversationState };

const RoundButton: React.FC<{ children: React.ReactNode; dim?: number; ink?: boolean }> = ({ children, dim = 44, ink = false }) => (
  <div
    style={{
      width: dim,
      height: dim,
      borderRadius: dim / 2,
      background: ink ? color.ink : color.surface,
      border: ink ? 'none' : `1px solid ${color.border}`,
      color: ink ? color.onBrand : color.ink,
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      gap: 2,
      boxSizing: 'border-box',
      flex: 'none',
    }}
  >
    {children}
  </div>
);

const Caps: React.FC<{ text: string }> = ({ text }) => (
  <div style={{ fontSize: 12, lineHeight: '16px', fontWeight: 700, letterSpacing: '0.06em', color: color.ink3 }}>{text}</div>
);

/** Compact verdict card of drawing 03: shape + word + name → ingredient, ink "Ask your doctor" + "Details". */
const VerdictCompact: React.FC<{ badge: number }> = ({ badge }) => {
  const s = risk.KNOWN;
  return (
    <div style={{ background: color.surface, border: `1.5px solid ${s.border}`, borderRadius: radius.ml, padding: 14, display: 'flex', flexDirection: 'column', gap: 12 }}>
      <div style={{ display: 'flex', alignItems: 'center', gap: 12 }}>
        <RiskShape level="KNOWN" dim={40} badge={badge} />
        <div>
          <div style={{ fontSize: 18, lineHeight: '22px', fontWeight: 800, color: s.text }}>{s.title}</div>
          <div style={{ fontSize: 14, lineHeight: '19px', fontWeight: 600, color: color.ink, display: 'flex', alignItems: 'center', gap: 4 }}>
            {vcopy.name} <span style={{ color: color.ink3 }}>→</span> {vcopy.ingredient}
          </div>
        </div>
      </div>
      <div style={{ display: 'flex', gap: 8 }}>
        <div style={{ flex: 1, height: 48, borderRadius: radius.s, background: color.ink, color: color.onBrand, display: 'grid', placeItems: 'center', ...type.button }}>
          {vcopy.askDoctor}
        </div>
        <div style={{ height: 48, padding: '0 18px', borderRadius: radius.s, border: `1.5px solid ${color.borderStrong}`, display: 'grid', placeItems: 'center', fontSize: 15, fontWeight: 600, boxSizing: 'border-box' }}>
          {chat.details}
        </div>
      </div>
    </div>
  );
};

/** The agent's sentence: the whole line is set, words not yet spoken sit at 30 % (DESIGN §10.1a 03). */
const AgentCaption: React.FC<{ words: number }> = ({ words }) => (
  <div style={{ ...type.title2, fontWeight: 700, color: color.ink, letterSpacing: '-0.01em' }}>
    {chat.agent.split(' ').map((w, i) => {
      const o = 0.3 + 0.7 * Math.max(0, Math.min(1, words - i));
      return (
        <span key={i} style={{ opacity: o }}>
          {w}{' '}
        </span>
      );
    })}
  </div>
);

const UserCaption: React.FC<{ words: number }> = ({ words }) => {
  const all = chat.user.split(' ');
  return (
    <div style={{ ...type.body, color: color.ink3 }}>
      You:{' '}
      {all.map((w, i) => (
        <span key={i} style={{ opacity: Math.max(0, Math.min(1, words - i)) }}>
          {w}{' '}
        </span>
      ))}
    </div>
  );
};

export const ConversationScreen: React.FC<{ s: ConversationState }> = ({ s }) => {
  const live = s.started;
  const voiceIsUser = s.phase === 'HEARING' || s.phase === 'LISTENING';
  const glowColor = voiceIsUser ? color.orbGlowUser : color.orbGlow;
  const glowClear = voiceIsUser ? color.orbGlowUserClear : color.orbGlowClear;
  const glowOpacity = live ? 0.6 + 0.4 * s.level : 1; // orb_glow already carries the idle 30 %
  const glowScale = live ? 1.1 + 0.2 * s.level : 1;
  const mm = Math.floor(s.elapsed / 60);
  const ss = String(Math.floor(s.elapsed % 60)).padStart(2, '0');
  const dotColor = s.phase === 'SPEAKING' || s.phase === 'THINKING' ? color.brand : color.ink4;

  return (
    <div style={{ position: 'relative', display: 'flex', flexDirection: 'column', flex: 1, minHeight: 0 }}>
      <StatusBar time="13:52" />
      {/* Header: close, then Chats + new chat (empty) or the session clock (live) */}
      <div style={{ position: 'relative', display: 'flex', alignItems: 'center', height: 56, padding: '0 16px 0 12px', flex: 'none' }}>
        <div style={{ width: 44, height: 44, display: 'grid', placeItems: 'center', color: color.ink }}>
          <Icon name="chevronDown" size={22} />
        </div>
        <div style={{ marginLeft: 'auto', display: 'flex', gap: 8, opacity: s.intro }}>
          <div style={{ height: 44, padding: '0 16px', borderRadius: 22, background: color.surface, border: `1px solid ${color.border}`, display: 'grid', placeItems: 'center', fontSize: 15, fontWeight: 700, boxSizing: 'border-box' }}>
            Chats
          </div>
          <RoundButton>
            <Icon name="plus" size={20} />
          </RoundButton>
        </div>
        <div style={{ position: 'absolute', left: 0, right: 0, textAlign: 'center', fontFamily: fontFamily.mono, fontSize: 12, fontWeight: 700, letterSpacing: '0.12em', color: color.ink3, opacity: 1 - s.intro }}>
          VOICE · {mm}:{ss}
        </div>
        <div style={{ position: 'absolute', right: 16, opacity: 1 - s.intro }}>
          <RoundButton>
            <Icon name="chat" size={20} />
          </RoundButton>
        </div>
      </div>

      {/* Content runs the full height under the dock */}
      <div style={{ position: 'relative', flex: 1, overflow: 'hidden' }}>
        {s.intro > 0 && (
          <div style={{ position: 'absolute', left: 20, right: 20, top: 26, display: 'flex', flexDirection: 'column', gap: 12, opacity: s.intro }}>
            <div style={{ ...type.title3, textAlign: 'center', color: color.ink, padding: '0 6px', marginBottom: 18 }}>{chat.agentLine}</div>
            <Caps text="ASK ME" />
            {chat.starters.map((t) => (
              <span key={t} style={{ alignSelf: 'flex-start', height: 44, padding: '0 16px', borderRadius: 22, border: `1.5px solid ${color.borderStrong}`, background: color.surface, display: 'inline-flex', alignItems: 'center', fontSize: 15, fontWeight: 600, boxSizing: 'border-box' }}>
                {t}
              </span>
            ))}
            <div style={{ marginTop: 10 }}>
              <Caps text="OR GO STRAIGHT TO" />
            </div>
            <div style={{ display: 'flex', flexWrap: 'wrap', gap: 8 }}>
              {chat.features.map((t) => (
                <span key={t} style={{ height: 44, padding: '0 16px', borderRadius: 22, background: color.surfaceAlt, display: 'inline-flex', alignItems: 'center', fontSize: 15, fontWeight: 600 }}>
                  {t}
                </span>
              ))}
            </div>
          </div>
        )}
        {s.waiting > 0 && (
          <div style={{ position: 'absolute', left: 20, right: 20, top: 120, textAlign: 'center', ...type.title2, color: color.ink, opacity: s.waiting }}>
            {chat.orbLabels.listening}
          </div>
        )}
        <div style={{ position: 'absolute', left: 20, right: 20, top: 18, display: 'flex', flexDirection: 'column', gap: 14, transform: `translateY(${-s.scrollY}px)` }}>
          {s.user !== null && (
            <div style={{ opacity: s.user.visible }}>
              <UserCaption words={s.user.words} />
            </div>
          )}
          {s.agent !== null && <AgentCaption words={s.agent.words} />}
          {s.tool !== null && (
            <div style={{ opacity: s.tool.visible, display: 'flex' }}>
              <ToolStep running={chat.toolRunning} done={chat.toolDone} isDone={s.tool.done} />
            </div>
          )}
          {s.verdict !== null && (
            <div style={{ opacity: s.verdict.opacity, transform: `translateY(${s.verdict.y}px)` }}>
              <VerdictCompact badge={s.verdict.badge} />
            </div>
          )}
        </div>
      </div>

      {/* Backdrop: the conversation fades into bg over the bottom 310 vp, a soft glow sits on the orb */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 0, height: 310, background: `linear-gradient(180deg, ${color.bgClear} 0%, ${color.bg} 30%)` }} />
      <div
        style={{
          position: 'absolute',
          left: 180 - 150,
          bottom: 34 + 52 - 150,
          width: 300,
          height: 300,
          borderRadius: '50%',
          background: `radial-gradient(circle, ${glowColor} 0%, ${glowClear} 70%)`,
          opacity: Math.min(1, glowOpacity),
          transform: `scale(${glowScale})`,
        }}
      />

      {/* Orb dock */}
      <div style={{ position: 'absolute', left: 0, right: 0, bottom: 34, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 12 }}>
        <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 2 }}>
          <div style={{ display: 'flex', alignItems: 'center', gap: 8, fontSize: 15, lineHeight: '20px', fontWeight: 700, color: color.brandText }}>
            {live && <span style={{ width: 8, height: 8, borderRadius: 4, background: dotColor }} />}
            {s.label}
          </div>
          <div style={{ ...type.caption, color: color.ink3, opacity: live ? 1 : 0 }}>{chat.dockHint}</div>
        </div>
        <div style={{ display: 'flex', alignItems: 'center', gap: 26 }}>
          {live ? (
            <RoundButton dim={size.dockSideV2} ink>
              <Icon name="close" size={18} />
              <span style={{ fontSize: 11, lineHeight: '13px', fontWeight: 700 }}>End</span>
            </RoundButton>
          ) : (
            <RoundButton dim={size.dockSideV2}>
              <Icon name="scan" size={22} />
            </RoundButton>
          )}
          <SilkOrb dim={size.orbDock} frame={s.frame} phaseAt={s.phaseAt} levelAt={s.levelAt} pixelRatio={3} />
          <RoundButton dim={size.dockSideV2}>
            <span style={{ fontSize: 16, fontWeight: 700 }}>Aa</span>
          </RoundButton>
        </div>
      </div>

      {/* Details: the full verdict in a sheet (§6.4 sheet size) */}
      {s.details !== null && (
        <>
          <div style={{ position: 'absolute', inset: 0, background: color.scrim, opacity: s.details.scrim }} />
          <Sheet style={{ transform: `translateY(${s.details.y * 100}%)`, top: 96 }}>
            <VerdictCard level="KNOWN" variant="SHEET" badge={s.details.badge} traceOpen={s.details.traceOpen} showTrace />
          </Sheet>
        </>
      )}
    </div>
  );
};
