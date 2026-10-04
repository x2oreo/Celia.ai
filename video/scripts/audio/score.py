"""Original score for each cut, built from src/copy/timeline.json so the music follows the picture.

D major / B minor, 96 BPM pulse. Hook: a dark B-minor drone with soft low thumps on the ripples. Reveal: a riser
into a bright D bloom with bell shimmer. Ask → scan: pad chords and a kalimba arpeggio. Watch: the same pulse turns
minor and drops away at the alert. Emergency: warm and lifting. Trust: piano and pad. End: the D chord resolves with
a piano motif and a long tail.

Writes public/audio/music-<cut>.mp3 (and a git-ignored WAV). The voice ducking happens in the composition.
"""
import json
import pathlib
import sys

import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from synth import (SR, bell, env_adsr, kalimba, noise_sweep, pad_note, pan, piano, place, reverb, reverb_ir, sub, thump,  # noqa: E402
                   write)

ROOT = pathlib.Path(__file__).resolve().parents[2]
TL = json.loads((ROOT / 'src/copy/timeline.json').read_text())
FPS = TL['fps']
OUT = ROOT / 'public/audio'

# Chords: pad voicing (MIDI), bass root, arpeggio notes.
CH = {
    'Bm9': ([59, 62, 66, 73], 35, [59, 66, 71, 73, 74, 78]),
    'Dadd9': ([62, 66, 69, 76], 38, [62, 69, 74, 76, 78, 81]),
    'A/C#': ([61, 64, 69, 71], 37, [61, 64, 69, 71, 73, 76]),
    'Bm7': ([59, 62, 66, 69], 35, [59, 62, 66, 69, 71, 74]),
    'Gmaj7': ([59, 62, 66, 67], 31, [55, 62, 66, 67, 71, 74]),
    'Em7': ([59, 62, 64, 67], 28, [55, 59, 64, 67, 71, 74]),
    'F#sus': ([59, 61, 66, 71], 30, [54, 61, 66, 71, 73, 78]),
    'D/F#': ([57, 62, 66, 69], 30, [54, 62, 66, 69, 74, 78]),
    'Asus': ([57, 62, 64, 69], 33, [57, 64, 69, 71, 74, 76]),
    'Dmaj7': ([61, 62, 66, 69], 38, [62, 66, 69, 73, 74, 78]),
}

SECTION = {
    'hook': {'chords': ['Bm9'], 'arp': 0.0, 'pad': 0.55, 'bass': 0.5},
    'reveal': {'chords': ['Dadd9'], 'arp': 0.0, 'pad': 0.8, 'bass': 0.7},
    'ask': {'chords': ['Dadd9', 'A/C#', 'Bm7'], 'arp': 1.0, 'pad': 0.6, 'bass': 0.6},
    'verdict': {'chords': ['Gmaj7', 'Asus'], 'arp': 1.0, 'pad': 0.6, 'bass': 0.6},
    'scan': {'chords': ['Dadd9', 'A/C#'], 'arp': 1.0, 'pad': 0.6, 'bass': 0.6},
    'watch': {'chords': ['Bm7', 'Gmaj7', 'Em7', 'F#sus'], 'arp': 0.85, 'pad': 0.65, 'bass': 0.75},
    'emergency': {'chords': ['Gmaj7', 'D/F#', 'Em7', 'Asus'], 'arp': 0.6, 'pad': 0.8, 'bass': 0.7},
    'trust': {'chords': ['Gmaj7', 'Dmaj7'], 'arp': 0.0, 'pad': 0.6, 'bass': 0.5},
    'end': {'chords': ['Dadd9'], 'arp': 0.0, 'pad': 0.85, 'bass': 0.7},
}

BEAT = 60 / 96
HOOK_BEAT_FRAMES = 33  # scenes/Hook.tsx BEAT: one ripple pair per beat, the second 7 frames later
WATCH_ALERT = {'hero': 110, 'vertical': 77}  # scenes/WatchGuard.tsx ALERT (× 0.7 in the vertical cut)


def placed(cut: str):
    at = 0
    out = []
    for s in TL[cut]['scenes']:
        out.append((s['id'], at, s['frames']))
        at += s['frames'] - TL[cut]['xfade']
    return out, at + TL[cut]['xfade']


def render(cut: str) -> np.ndarray:
    scenes, total = placed(cut)
    sec_total = total / FPS + 4.0  # room for the tail, trimmed below
    n = int(sec_total * SR)
    dry = np.zeros((n, 2))
    send = np.zeros((n, 2))  # reverb send
    xf = TL[cut]['xfade'] / FPS

    for sid, start_f, frames in scenes:
        cfg = SECTION[sid]
        start, dur = start_f / FPS, frames / FPS
        chords = cfg['chords']
        span = (dur - xf) / len(chords)
        for ci, name in enumerate(chords):
            pad_notes, root, arp = CH[name]
            c0 = start + ci * span
            c_len = span + xf + 1.2  # overlap into the next chord for a smooth change
            for m in pad_notes:
                note = pad_note(m, c_len, bright=4.5 if sid != 'end' else 6.0)
                note *= env_adsr(len(note), 1.1 if ci == 0 else 0.6, 0.0, 1.0, 1.4)[:, None]
                place(send, note, c0, 0.05 * cfg['pad'])
                place(dry, note, c0, 0.04 * cfg['pad'])
            if cfg['bass'] > 0:
                place(dry, pan(sub(root + 12 if root < 30 else root, c_len, a=0.5, r=1.2), 0), c0, 0.16 * cfg['bass'])
            # Arpeggio: 8ths on a global grid so it flows across cuts between scenes.
            if cfg['arp'] > 0:
                step = BEAT / 2
                k0 = int(np.ceil(c0 / step))
                k = k0
                while k * step < c0 + span:
                    i = k % 8
                    pattern = [0, 2, 4, 1, 3, 5, 2, 4]
                    m = arp[pattern[i] % len(arp)]
                    if sid == 'emergency' and k % 2:
                        k += 1
                        continue
                    vel = (0.9 if i % 4 == 0 else 0.62) * cfg['arp']
                    p = -0.45 + 0.9 * ((i * 3) % 8) / 7
                    note = pan(kalimba(m + 12, 0.9, vel), p)
                    place(dry, note, k * step, 0.07)
                    place(send, note, k * step, 0.05)
                    k += 1

        if sid == 'hook':
            # Low thumps with the ripples (lub-dub), fading before the reveal.
            b = 6
            while b < frames - 30:
                fade = max(0.0, 1 - b / (frames - 30)) ** 0.6
                for off, v in ((0, 1.0), (7, 0.55)):
                    place(dry, pan(thump(0.5, 58, v), 0), (start_f + b + off) / FPS, 0.5 * fade)
                b += HOOK_BEAT_FRAMES
            # Sparse felt piano: B minor motif.
            for i, (m, t) in enumerate([(78, 1.4), (74, 3.1), (71, 4.6), (73, 6.2), (66, 7.8)]):
                if t < dur - 0.6:
                    place(send, pan(piano(m, 4.0, 0.7), -0.2 + 0.1 * i), start + t, 0.12)
                    place(dry, pan(piano(m, 4.0, 0.7), -0.2 + 0.1 * i), start + t, 0.1)
            # Riser into the reveal.
            r = noise_sweep(2.2, 300, 6000, rise=True)
            place(dry, r, start + dur - xf - 2.2, 0.05)
            place(send, r, start + dur - xf - 2.2, 0.04)

        if sid in ('reveal', 'end'):
            # Bloom: bell shimmer on the wordmark, low swell.
            for i, m in enumerate([81, 86, 90, 93] if sid == 'reveal' else [74, 78, 81, 86, 88]):
                place(send, pan(bell(m, 3.5, 0.5), -0.5 + 0.33 * i), start + 0.45 + 0.09 * i, 0.06)
                place(dry, pan(bell(m, 3.5, 0.5), -0.5 + 0.33 * i), start + 0.45 + 0.09 * i, 0.035)
            place(dry, pan(thump(1.6, 46, 1.0), 0), start + 0.4, 0.35)

        if sid == 'end':
            for i, (m, t) in enumerate([(74, 0.9), (78, 1.5), (81, 2.1), (76, 2.9), (74, 4.0)]):
                place(send, pan(piano(m, 5.0, 0.75), -0.15 + 0.08 * i), start + t, 0.13)
                place(dry, pan(piano(m, 5.0, 0.75), -0.15 + 0.08 * i), start + t, 0.1)

        if sid == 'trust':
            for i, (m, t) in enumerate([(71, 0.6), (74, 1.8), (78, 3.0), (76, 4.4)]):
                place(send, pan(piano(m, 4.0, 0.6), 0.1 * i - 0.15), start + t, 0.1)
                place(dry, pan(piano(m, 4.0, 0.6), 0.1 * i - 0.15), start + t, 0.08)

        if sid == 'watch':
            # At the alert the bed thins out for a moment and a low swell sits under the alert tone.
            a = start + WATCH_ALERT[cut] / FPS
            i0, i1 = int((a - 0.15) * SR), int((a + 2.4) * SR)
            dip = np.ones(n)
            seg = np.linspace(0, 1, i1 - i0)
            dip[i0:i1] = 1 - 0.55 * np.sin(np.pi * np.clip(seg * 1.3, 0, 1)) ** 0.5
            dry *= dip[:, None]
            send *= dip[:, None]
            place(dry, pan(thump(2.0, 41, 1.0), 0), a, 0.3)

    ir = reverb_ir()
    wet = reverb(send, ir, 1.0)
    mix = dry + wet * 0.9
    # Gentle glue: soft saturation, then fade the very end.
    mix = np.tanh(mix * 1.6) / 1.6
    end_n = int((total / FPS) * SR)
    fade = int(1.6 * SR)
    mix = mix[: end_n]
    mix[-fade:] *= np.linspace(1, 0, fade)[:, None] ** 1.5
    lead = int(0.25 * SR)
    mix[:lead] *= np.linspace(0, 1, lead)[:, None]
    return mix


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for cut in ('hero', 'vertical'):
        x = render(cut)
        write(OUT / f'music-{cut}.wav', x, peak_db=-3.0)
        print(f'music-{cut}: {len(x) / SR:.1f} s', file=sys.stderr)


if __name__ == '__main__':
    main()
