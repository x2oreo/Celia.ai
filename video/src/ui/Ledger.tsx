// "What left my phone" (F-46): endpoint, field names and size. Never values.
import React from 'react';
import { ledger } from '../copy/script';
import { color, fontFamily, radius, type } from '../theme/tokens';
import { StatusBar } from '../primitives/Devices';
import { Icon } from '../primitives/Icon';

export const LedgerScreen: React.FC<{ rows: number[] }> = ({ rows }) => (
  <div style={{ display: 'flex', flexDirection: 'column', flex: 1, background: color.bg }}>
    <StatusBar time="14:40" />
    <div style={{ display: 'flex', alignItems: 'center', height: 52, padding: '0 12px', gap: 6 }}>
      <Icon name="back" size={22} stroke={2} />
    </div>
    <div style={{ padding: '0 20px', display: 'flex', flexDirection: 'column', gap: 6 }}>
      <div style={{ ...type.title1 }}>{ledger.title}</div>
      <div style={{ ...type.bodySm, color: color.ink3 }}>{ledger.sub}</div>
    </div>
    <div style={{ padding: '18px 20px 0', display: 'flex', flexDirection: 'column', gap: 10 }}>
      {ledger.rows.map((r, i) => {
        const p = rows[i] ?? 0;
        return (
          <div
            key={r.endpoint + r.time}
            style={{
              background: color.surface,
              border: `1px solid ${color.border}`,
              borderRadius: radius.m,
              padding: 14,
              display: 'flex',
              flexDirection: 'column',
              gap: 6,
              opacity: p,
              transform: `translateX(${(1 - p) * 24}px)`,
            }}
          >
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <span style={{ fontFamily: fontFamily.mono, fontSize: 13, fontWeight: 700, color: color.ink }}>{r.endpoint}</span>
              <span style={{ marginLeft: 'auto', fontSize: 12, color: color.ink3, fontVariantNumeric: 'tabular-nums' }}>{r.time}</span>
            </div>
            <div style={{ display: 'flex', alignItems: 'center', gap: 8 }}>
              <span style={{ ...type.bodySm, color: color.ink2, flex: 1 }}>{r.fields}</span>
              <span style={{ height: 24, padding: '0 8px', borderRadius: 12, background: color.surfaceAlt, fontSize: 12, fontWeight: 700, color: color.ink2, display: 'grid', placeItems: 'center', fontVariantNumeric: 'tabular-nums' }}>
                {r.size}
              </span>
            </div>
          </div>
        );
      })}
      <div style={{ display: 'flex', gap: 10, alignItems: 'flex-start', padding: '12px 14px', borderRadius: radius.s, background: color.statusOfflineBg, color: color.statusOfflineText, fontSize: 13, fontWeight: 600, lineHeight: '18px', opacity: rows[ledger.rows.length] ?? 0 }}>
        <Icon name="lock" size={16} />
        {ledger.never}
      </div>
    </div>
  </div>
);
