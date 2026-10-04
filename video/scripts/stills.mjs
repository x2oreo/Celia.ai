// Renders stills with one bundle: `node scripts/stills.mjs Hero16x9 890 1100` → out/stills/Hero16x9-890.png …
// With no frames, renders the contact sheet (one key frame per scene) and tiles it with ffmpeg.
import { bundle } from '@remotion/bundler';
import { renderStill, selectComposition } from '@remotion/renderer';
import { execFileSync } from 'node:child_process';
import { mkdirSync } from 'node:fs';
import path from 'node:path';

const KEY = {
  Hero16x9: [200, 360, 485, 705, 785, 960, 1185, 1350, 1460, 1580, 1730, 1890, 2100],
  Vertical9x16: [100, 288, 448, 591, 769, 860],
};

const [id = 'Hero16x9', ...rest] = process.argv.slice(2);
const frames = rest.length > 0 ? rest.map(Number) : KEY[id];
const outDir = path.resolve('out/stills');
mkdirSync(outDir, { recursive: true });

const serveUrl = await bundle({ entryPoint: path.resolve('src/index.ts') });
const composition = await selectComposition({ serveUrl, id });
const files = [];
for (const frame of frames) {
  const output = path.join(outDir, `${id}-${frame}.png`);
  await renderStill({ composition, serveUrl, output, frame });
  files.push(output);
  console.log(output);
}
if (rest.length === 0) {
  const cols = id === 'Hero16x9' ? 3 : 6;
  const w = id === 'Hero16x9' ? 640 : 360;
  const h = id === 'Hero16x9' ? 360 : 640;
  const inputs = files.flatMap((f) => ['-i', f]);
  const scaled = files.map((_, i) => `[${i}:v]scale=${w}:${h}[v${i}]`).join(';');
  const layout = files.map((_, i) => `${(i % cols) * w}_${Math.floor(i / cols) * h}`).join('|');
  const filter = `${scaled};${files.map((_, i) => `[v${i}]`).join('')}xstack=inputs=${files.length}:layout=${layout}`;
  const sheet = path.join(outDir, `${id}-contact.png`);
  execFileSync('ffmpeg', ['-y', '-loglevel', 'error', ...inputs, '-filter_complex', filter, sheet]);
  console.log(sheet);
}
