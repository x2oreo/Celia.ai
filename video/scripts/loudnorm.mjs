// Two-pass EBU R128 loudness for a rendered film: −16 LUFS integrated, −1.5 dBTP, picture copied untouched.
// Usage: node scripts/loudnorm.mjs <in.mp4> <out.mp4>
import { spawnSync } from 'node:child_process';

const [input, output] = process.argv.slice(2);
if (!input || !output) {
  console.error('usage: node scripts/loudnorm.mjs <in.mp4> <out.mp4>');
  process.exit(1);
}
const target = 'I=-16:TP=-1.5:LRA=11';
const first = spawnSync('ffmpeg', ['-hide_banner', '-i', input, '-af', `loudnorm=${target}:print_format=json`, '-f', 'null', '-'], {
  encoding: 'utf8',
});
const json = first.stderr.slice(first.stderr.lastIndexOf('{'), first.stderr.lastIndexOf('}') + 1);
const m = JSON.parse(json);
const second = `loudnorm=${target}:measured_I=${m.input_i}:measured_TP=${m.input_tp}:measured_LRA=${m.input_lra}:measured_thresh=${m.input_thresh}:offset=${m.target_offset}:linear=true`;
const run = spawnSync(
  'ffmpeg',
  ['-y', '-loglevel', 'error', '-i', input, '-c:v', 'copy', '-af', `${second},aresample=48000`, '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart', output],
  { stdio: 'inherit' },
);
if (run.status !== 0) process.exit(run.status ?? 1);
console.log(`loudnorm: ${input} (${m.input_i} LUFS) → ${output} (−16 LUFS)`);
