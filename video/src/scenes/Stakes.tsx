// Beat 2: the stakes, as three shots on the voice, all built from one field of 2,000 dots (one of them is Ola).
//   E  "She is one in two thousand"        the camera starts on Ola's coral dot and pulls back to the whole field
//   F  "up to four thousand lives a year"  dots go dark across the field while a counter runs to 4,000
//   G  "For one in ten ..."                ten large dots; one goes dark
//   H  "Most ... are preventable"          a coral wave relights the field, which falls away into the reveal
// One coral number at most per shot; sources in the caption.
import React, { useLayoutEffect, useRef } from 'react';
import { AbsoluteFill, interpolate, useCurrentFrame } from 'remotion';
import { heroVo, voAt } from '../audio/cues';
import { voWordAt } from '../audio/vo';
import { scenes, stakes } from '../copy/script';
import { clampOpts, easeInOut, easeOut, progress } from '../theme/motion';
import { color, film, fontFamily } from '../theme/tokens';
import { Caption, Headline, Kicker } from '../primitives/Type';
import type { SceneProps } from './common';

const hash = (i: number): number => {
  const x = Math.sin(i * 127.1 + 311.7) * 43758.5453;
  return x - Math.floor(x);
};

interface FieldLook {
  zoom: number; // 1 = whole field
  lost: number; // 0..1 share of dots gone dark
  wave: number; // 0..1 radius of the relighting wave (0 = none)
  fade: number; // 0..1 overall alpha
}

const DotField: React.FC<{ look: FieldLook; tall: boolean }> = ({ look, tall }) => {
  const ref = useRef<HTMLCanvasElement>(null);
  const W = tall ? 1080 : 1920;
  const H = tall ? 1920 : 1080;
  const cols = tall ? 40 : 80;
  const rows = tall ? 50 : 25;
  const gap = tall ? 24 : 21;
  const ola = Math.floor(rows / 2) * cols + Math.floor(cols / 2);
  useLayoutEffect(() => {
    const cv = ref.current;
    const g = cv?.getContext('2d');
    if (cv === null || cv === undefined || g === null || g === undefined) return;
    const pr = 1.5;
    g.setTransform(pr, 0, 0, pr, 0, 0);
    g.clearRect(0, 0, W, H);
    const cx = W / 2;
    const cy = H / 2 - (tall ? 160 : 110);
    const ox = ((cols - 1) * gap) / 2;
    const oy = ((rows - 1) * gap) / 2;
    const olaX = (Math.floor(cols / 2) * gap - ox);
    const olaY = (Math.floor(rows / 2) * gap - oy);
    const maxR = Math.hypot(ox, oy);
    for (let i = 0; i < cols * rows; i++) {
      const c = i % cols;
      const r = Math.floor(i / cols);
      const px = c * gap - ox;
      const py = r * gap - oy;
      const x = cx + (px - olaX) * look.zoom + olaX * Math.min(1, look.zoom);
      const y = cy + (py - olaY) * look.zoom + olaY * Math.min(1, look.zoom);
      const rad = Math.min(60, (tall ? 4.6 : 4.2) * look.zoom);
      if (x < -rad || x > W + rad || y < -rad || y > H + rad) continue;
      const isOla = i === ola;
      const gone = !isOla && hash(i) < look.lost;
      const dist = Math.hypot(px, py) / maxR;
      const lit = look.wave > 0 && dist < look.wave;
      const edge = look.wave > 0 && Math.abs(dist - look.wave) < 0.06;
      g.beginPath();
      g.arc(x, y, rad * (edge ? 1.5 : 1), 0, Math.PI * 2);
      g.fillStyle = isOla || edge || lit ? color.orbMid : gone ? color.dotLost : color.dotIdle;
      g.globalAlpha = look.fade * (lit && !isOla && !edge ? 0.75 : 1);
      g.fill();
    }
    g.globalAlpha = 1;
  }, [look.zoom, look.lost, look.wave, look.fade, W, H, cols, rows, gap, ola, tall]);
  return <canvas ref={ref} width={W * 1.5} height={H * 1.5} style={{ position: 'absolute', inset: 0, width: W, height: H }} />;
};

const BigNumber: React.FC<{ value: string; label: string; p: number; tall: boolean; accent?: boolean }> = ({ value, label, p, tall, accent = false }) => (
  <div style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 10, opacity: p, transform: `translateY(${(1 - p) * 20}px)` }}>
    <span style={{ fontFamily: fontFamily.sans, fontSize: tall ? 170 : 150, lineHeight: 1, fontWeight: 800, letterSpacing: '-0.05em', color: accent ? color.brand : color.nightInk, fontVariantNumeric: 'tabular-nums' }}>
      {value}
    </span>
    <span style={{ fontFamily: fontFamily.sans, fontSize: tall ? 34 : 30, fontWeight: 600, color: color.nightInk2 }}>{label}</span>
  </div>
);

const TenDots: React.FC<{ local: number; goneAt: number; tall: boolean }> = ({ local, goneAt, tall }) => {
  const size = tall ? 70 : 84;
  return (
    <div style={{ display: 'flex', gap: tall ? 20 : 34, flexWrap: tall ? 'wrap' : 'nowrap', justifyContent: 'center', maxWidth: tall ? 5 * (size + 20) : undefined }}>
      {Array.from({ length: 10 }, (_, i) => {
        const a = progress(local, i * 3, 12);
        const gone = i === 6 ? progress(local, goneAt, 18) : 0;
        return (
          <span
            key={i}
            style={{
              width: size,
              height: size,
              borderRadius: '50%',
              background: gone > 0 ? color.dotLost : color.nightInk,
              border: gone > 0 ? `2px solid ${color.nightLine}` : 'none',
              boxSizing: 'border-box',
              opacity: a,
              transform: `scale(${(0.6 + 0.4 * a) * (1 - 0.18 * gone)})`,
            }}
          />
        );
      })}
    </div>
  );
};

export const Stakes: React.FC<SceneProps> = ({ layout }) => {
  const frame = useCurrentFrame();
  const tall = layout === 'tall';
  const c = scenes.stakes;
  const vo = voAt(heroVo, 'stakes');
  const w = (i: number): number => vo + voWordAt('stakes', i);
  const cutF = w(6) - 4;
  const cutG = w(20) - 4;
  const cutH = w(30) - 4;
  const [deaths, first] = stakes.stats;
  const textTop = tall ? 1400 : 790;

  if (frame >= cutG && frame < cutH) {
    const local = frame - cutG;
    return (
      <AbsoluteFill style={{ background: color.night, overflow: 'hidden' }}>
        <AbsoluteFill style={{ display: 'flex', flexDirection: 'column', alignItems: 'center', justifyContent: 'center', gap: tall ? 90 : 80 }}>
          <TenDots local={local} goneAt={w(28) - cutG} tall={tall} />
          <BigNumber value={first?.value ?? ''} label={`${first?.unit ?? ''} ${first?.note ?? ''}`} p={progress(local, 8, 18)} tall={tall} />
        </AbsoluteFill>
      </AbsoluteFill>
    );
  }

  // E, F and H share the field and its camera.
  const zoom = interpolate(frame, [0, 70], [26, 1], { ...clampOpts, easing: easeInOut });
  const lost = frame < cutF ? 0 : interpolate(frame, [cutF + 6, w(19)], [0, 0.42], { ...clampOpts, easing: easeOut });
  const wave = frame < cutH ? 0 : interpolate(frame, [cutH + 4, cutH + 50], [0.001, 1.1], { ...clampOpts, easing: easeInOut });
  const end = 410;
  const fade = interpolate(frame, [end - 26, end - 4], [1, 0], clampOpts);
  const count = Math.round(interpolate(frame, [cutF + 6, w(16) + 6], [0, 4000], { ...clampOpts, easing: easeOut }));
  return (
    <AbsoluteFill style={{ background: color.night, overflow: 'hidden' }}>
      <DotField look={{ zoom, lost: frame >= cutH ? 0.42 * (1 - Math.min(1, wave)) : lost, wave, fade }} tall={tall} />
      <div style={{ position: 'absolute', left: 0, right: 0, top: textTop, display: 'flex', flexDirection: 'column', alignItems: 'center', gap: 18, opacity: fade }}>
        {frame < cutF && (
          <>
            <Kicker text={c.kicker} start={w(0) - 6} tone="dark" tall={tall} />
            <Headline text={c.lines[1] ?? ''} start={w(2) - 4} tone="dark" style={tall ? film.headlineTall : film.headline} align="center" accentWord="2,000" />
          </>
        )}
        {frame >= cutF && frame < cutH && (
          <BigNumber value={count.toLocaleString('en-US')} label={`${deaths?.unit ?? ''} · ${deaths?.note ?? ''}`} p={progress(frame, cutF, 14)} tall={tall} accent />
        )}
        {frame >= cutH && (
          <Headline text={c.lines[0] ?? ''} start={cutH + 2} tone="dark" style={tall ? film.headlineTall : film.headline} align="center" accentWord="preventable" maxWidth={tall ? 940 : 1400} />
        )}
      </div>
      {frame >= cutH && (
        <div style={{ position: 'absolute', left: 0, right: 0, bottom: tall ? 110 : 50, opacity: fade }}>
          <Caption text={c.caption ?? ''} start={cutH + 20} tone="dark" tall={tall} align="center" />
        </div>
      )}
    </AbsoluteFill>
  );
};
