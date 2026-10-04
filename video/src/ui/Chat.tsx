// Thread pieces (DESIGN §6.3, §6.8, §8 live words): user bubble, plain agent text, tool step, typing dots.
import React from 'react';
import { useCurrentFrame } from 'remotion';
import { typingDot } from '../theme/motion';
import { color, radius, type } from '../theme/tokens';
import { Icon, type IconName } from '../primitives/Icon';

/** Words visible after `progress` (0..1) of a line. */
export const wordsShown = (text: string, p: number): string => {
  const words = text.split(' ');
  const n = Math.round(Math.max(0, Math.min(1, p)) * words.length);
  return words.slice(0, n).join(' ');
};

export const TypingDots: React.FC<{ dotColor?: string; dim?: number }> = ({ dotColor = color.ink4, dim = 7 }) => {
  const frame = useCurrentFrame();
  return (
    <div style={{ display: 'flex', gap: 5, alignItems: 'center' }}>
      {[0, 1, 2].map((i) => (
        <span
          key={i}
          style={{ width: dim, height: dim, borderRadius: '50%', background: dotColor, opacity: typingDot(frame, i) }}
        />
      ))}
    </div>
  );
};

/**
 * User bubble: ink fill, radius 20/20/6/20. While words are still being recognised it sits at 60 % opacity
 * (three dots before the first word), then becomes solid.
 */
export const UserBubble: React.FC<{ text: string; recognised: number; solid: number }> = ({
  text,
  recognised,
  solid,
}) => {
  const shown = wordsShown(text, recognised);
  return (
    <div style={{ display: 'flex', justifyContent: 'flex-end' }}>
      <div
        style={{
          maxWidth: 260,
          background: color.ink,
          color: color.white,
          fontSize: 15,
          lineHeight: '21px',
          fontWeight: 500,
          padding: '10px 14px',
          borderRadius: `${radius.ml}px ${radius.ml}px ${radius.xs}px ${radius.ml}px`,
          opacity: 0.6 + 0.4 * solid,
          minHeight: 41,
          boxSizing: 'border-box',
          display: 'flex',
          alignItems: 'center',
        }}
      >
        {shown === '' ? <TypingDots dotColor={color.white} dim={6} /> : shown}
      </div>
    </div>
  );
};

/** Agent text: plain body text, no bubble, grows word by word. No cursor. */
export const AgentText: React.FC<{ text: string; progress: number }> = ({ text, progress }) => {
  const words = text.split(' ');
  const n = Math.max(0, Math.min(1, progress)) * words.length;
  return (
    <div style={{ ...type.body, color: color.ink }}>
      {words.map((w, i) => {
        // The newest word eases in over a fraction of a word; earlier words are solid.
        const o = Math.max(0, Math.min(1, n - i));
        return (
          <span key={i} style={{ opacity: o }}>
            {w}
            {i < words.length - 1 ? ' ' : ''}
          </span>
        );
      })}
    </div>
  );
};

/** Tool step pill: neutral ink only. Running = present tense + dots, done = past tense in ink-3 + check. */
export const ToolStep: React.FC<{ running: string; done: string; isDone: boolean; icon?: IconName }> = ({
  running,
  done,
  isDone,
  icon = 'search',
}) => (
  <div
    style={{
      display: 'inline-flex',
      alignItems: 'center',
      gap: 8,
      height: 36,
      padding: '0 12px 0 4px',
      borderRadius: 18,
      background: color.surface,
      border: `1px solid ${color.border}`,
      alignSelf: 'flex-start',
      boxSizing: 'border-box',
    }}
  >
    <span
      style={{
        width: 28,
        height: 28,
        borderRadius: 8,
        background: color.surfaceAlt,
        display: 'grid',
        placeItems: 'center',
        color: color.ink2,
      }}
    >
      <Icon name={icon} size={14} />
    </span>
    <span style={{ fontSize: 13, fontWeight: 500, color: isDone ? color.ink3 : color.ink, whiteSpace: 'nowrap' }}>
      {isDone ? done : running}
    </span>
    {isDone ? <Icon name="check" size={16} color={color.ink3} stroke={2.2} /> : <TypingDots dim={5} />}
  </div>
);
