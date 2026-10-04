// Beat 5: camera over a generic box → barcode locks → GTIN → verdict sheet + "About this medicine".
import React from 'react';
import { interpolate, useCurrentFrame } from 'remotion';
import { heroVo, voAt } from '../audio/cues';
import { voWordAt } from '../audio/vo';
import { box, scenes } from '../copy/script';
import { clampOpts, progress, reveal, sheet } from '../theme/motion';
import { color, radius, type } from '../theme/tokens';
import { PhoneFrame, Sheet } from '../primitives/Devices';
import { Stage } from '../primitives/Stage';
import { ScanCamera } from '../ui/BoxScan';
import { VerdictCard } from '../ui/VerdictCard';
import { Float, TextColumn, phoneSlot, type SceneProps } from './common';

/** Barcode lock and verdict sheet, in scene frames. Shared with the soundtrack. */
export const SCAN = { LOCK: 58, SHEET: 98 };
const { LOCK, SHEET } = SCAN;

export const Scan: React.FC<SceneProps> = ({ layout }) => {
  const frame = useCurrentFrame();
  const slot = phoneSlot(layout);
  const c = scenes.scan;
  const VO = voAt(heroVo, 'scan');
  const scanLine = 0.5 - 0.5 * Math.cos((frame / 26) * Math.PI);
  const lock = frame >= LOCK ? 1 : 0;
  const digits = Math.round(interpolate(frame, [LOCK, LOCK + 22], [0, 13], clampOpts));
  const found = progress(frame, LOCK + 24, 10);
  const sh = sheet(frame, SHEET);
  const r = reveal(frame, SHEET + 6);
  return (
    <Stage surface="bg" glow={{ x: '74%', y: '50%', r: 760 }}>
      <TextColumn layout={layout} kicker={c.kicker} lines={c.lines} at={[VO + 2, VO + voWordAt('scan', 4) - 4]} keep />
      <Float x={slot.x} y={slot.y} seed={2}>
        <PhoneFrame scale={slot.scale} screenBg={color.scanBg}>
          <ScanCamera lock={lock} scanLine={scanLine} found={found} digits={digits} />
          <div style={{ position: 'absolute', inset: 0, background: color.scrim, opacity: sh.scrim * 0.5 }} />
          <Sheet style={{ transform: `translateY(${sh.y * 100}%)`, gap: 12 }}>
            <div style={{ opacity: r.opacity, transform: `translateY(${r.y}px)` }}>
              <VerdictCard level="KNOWN" variant="SHEET" badge={r.badge} showTrace={false} showExtras={false} />
            </div>
            <div style={{ background: color.surface, border: `1px solid ${color.border}`, borderRadius: radius.m, padding: '10px 14px', opacity: progress(frame, SHEET + 26, 12) }}>
              <div style={{ ...type.label, color: color.ink3, marginBottom: 6 }}>ABOUT THIS MEDICINE</div>
              {box.about.slice(0, 4).map((row) => (
                <div key={row.k} style={{ display: 'flex', justifyContent: 'space-between', fontSize: 13, lineHeight: '22px' }}>
                  <span style={{ color: color.ink3 }}>{row.k}</span>
                  <span style={{ color: color.ink, fontWeight: 600 }}>{row.v}</span>
                </div>
              ))}
            </div>
          </Sheet>
        </PhoneFrame>
      </Float>
    </Stage>
  );
};
