// Scan (DESIGN §10.1 B5): dark camera surface, a generic medicine box (no real brand's trade dress), scan frame,
// barcode lock, "Found" pill.
import React from 'react';
import { box } from '../copy/script';
import { color, fontFamily, shadow } from '../theme/tokens';
import { StatusBar } from '../primitives/Devices';
import { Icon } from '../primitives/Icon';

// EAN-13 bar widths for a fixed pattern (visual only; digits are printed underneath).
const BARS = '1010110011010011101011000110101011110101010111001011100101000010110110011010100111001011101';

const Barcode: React.FC<{ width: number; height: number }> = ({ width, height }) => {
  const unit = width / BARS.length;
  return (
    <svg width={width} height={height + 16}>
      {BARS.split('').map((b, i) =>
        b === '1' ? <rect key={i} x={i * unit} y={0} width={unit + 0.2} height={i < 3 || i > BARS.length - 4 ? height + 6 : height} fill={color.barcode} /> : null,
      )}
      <text x={width / 2} y={height + 15} textAnchor="middle" fontFamily={fontFamily.mono} fontSize={11} fill={color.barcode} letterSpacing={1.5}>
        {box.gtin}
      </text>
    </svg>
  );
};

/** A plain white carton: teal band, generic name, strength, form, barcode on the side. */
export const MedicineBox: React.FC = () => (
  <div style={{ position: 'relative', width: 250, height: 170, transform: 'rotate(-4deg)' }}>
    <div style={{ position: 'absolute', inset: 0, background: color.boxFace, borderRadius: 4, overflow: 'hidden', boxShadow: shadow.floatDark, borderBottom: `6px solid ${color.boxSide}` }}>
      <div style={{ height: 30, background: color.boxBand }} />
      <div style={{ padding: '10px 14px', color: color.boxInk, display: 'flex', gap: 10 }}>
        <div style={{ flex: 1 }}>
          <div style={{ fontSize: 19, fontWeight: 800, letterSpacing: '-0.01em' }}>{box.boxLabel}</div>
          <div style={{ fontSize: 13, fontWeight: 700, marginTop: 2 }}>{box.boxStrength}</div>
          <div style={{ fontSize: 10, fontWeight: 500, marginTop: 4, opacity: 0.75, lineHeight: '13px' }}>{box.boxForm}</div>
        </div>
        <div style={{ background: color.white, padding: '4px 4px 0', alignSelf: 'flex-end' }}>
          <Barcode width={104} height={40} />
        </div>
      </div>
    </div>
  </div>
);

export const ScanCamera: React.FC<{ lock: number; scanLine: number; found: number; digits: number }> = ({
  lock,
  scanLine,
  found,
  digits,
}) => {
  const frameW = 280;
  const frameH = 200;
  const frameColor = lock > 0.5 ? color.calm : color.white;
  return (
    <div style={{ position: 'absolute', inset: 0, background: color.scanBg, display: 'flex', flexDirection: 'column' }}>
      <StatusBar time="9:42" dark />
      <div style={{ display: 'flex', alignItems: 'center', gap: 14, padding: '10px 18px' }}>
        <div style={{ width: 44, height: 44, borderRadius: 22, background: color.scanFrame, display: 'grid', placeItems: 'center', color: color.white }}>
          <Icon name="x" size={18} stroke={2.4} />
        </div>
        <div
          style={{
            height: 36,
            padding: '0 14px',
            borderRadius: 18,
            background: color.calm,
            color: color.white,
            fontSize: 15,
            fontWeight: 700,
            display: 'flex',
            alignItems: 'center',
            gap: 6,
            opacity: found,
            transform: `translateY(${(1 - found) * -6}px)`,
          }}
        >
          <Icon name="check" size={16} stroke={2.6} />
          {box.found}
        </div>
      </div>
      <div style={{ position: 'relative', flex: 1, display: 'flex', justifyContent: 'center' }}>
        <div style={{ position: 'absolute', top: 44 }}>
          <MedicineBox />
        </div>
        {/* scan frame */}
        <div style={{ position: 'absolute', top: 30, width: frameW, height: frameH, borderRadius: 18, border: `3px solid ${frameColor}`, boxSizing: 'border-box', opacity: 0.95 }}>
          {lock < 0.5 && (
            <div style={{ position: 'absolute', left: 12, right: 12, top: 12 + scanLine * (frameH - 30), height: 2, borderRadius: 1, background: color.brand, boxShadow: `0 0 12px ${color.brand}` }} />
          )}
        </div>
        <div style={{ position: 'absolute', top: 252, fontFamily: fontFamily.mono, fontSize: 20, fontWeight: 700, letterSpacing: '0.12em', color: color.scanText }}>
          {box.gtin.slice(0, digits).padEnd(13, '·')}
        </div>
        <div style={{ position: 'absolute', top: 286, display: 'flex', alignItems: 'center', gap: 6, fontSize: 12, color: color.scanText, opacity: 0.8 }}>
          <Icon name="barcode" size={14} />
          {box.register}
        </div>
      </div>
    </div>
  );
};
