"""Speak every line of src/copy/vo.json with Kokoro (kokoro-onnx, Apache-2.0 weights) on this machine.

Writes public/audio/vo/<id>.mp3 (48 kHz mono, trimmed, -1 dBFS peak; a WAV beside it is git-ignored) and src/audio/vo-timing.json
(seconds and frames at 30 fps, per-word start times weighted by length for live captions, and a per-frame
loudness envelope that drives the orb).
Lines whose text, voice and speed did not change are skipped. Model files live in video/.audio-models/.
"""
import hashlib
import json
import pathlib
import subprocess
import sys

import numpy as np
import soundfile as sf
from scipy.signal import resample_poly

ROOT = pathlib.Path(__file__).resolve().parents[2]
SPEC = json.loads((ROOT / 'src/copy/vo.json').read_text())
OUT = ROOT / 'public/audio/vo'
TIMING = ROOT / 'src/audio/vo-timing.json'
MODELS = ROOT / '.audio-models'
FPS = 30
SR = 48000


def trim(a: np.ndarray, sr: int) -> np.ndarray:
    env = np.abs(a)
    thr = 0.01 * env.max()
    idx = np.where(env > thr)[0]
    pad = int(0.04 * sr)
    return a[max(0, idx[0] - pad): idx[-1] + pad]


def to_mp3(wav: pathlib.Path) -> None:
    # The committed copy: 192 kbit/s MP3 next to the (git-ignored) WAV.
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', str(wav), '-codec:a', 'libmp3lame', '-b:a', '192k',
                    str(wav.with_suffix('.mp3'))], check=True)


def envelope(a: np.ndarray) -> list:
    # Loudness per video frame, 0..1 (RMS over the frame, normalised to the line's loudest frame). Drives the orb.
    hop = SR // FPS
    n = int(np.ceil(len(a) / hop))
    rms = np.array([np.sqrt(np.mean(a[i * hop:(i + 1) * hop] ** 2) + 1e-12) for i in range(n)])
    rms = rms / rms.max()
    return [round(float(v), 2) for v in np.clip(rms ** 0.7, 0, 1)]


def word_starts(text: str, seconds: float) -> list:
    # Live captions: a word's start is proportional to the characters before it (pauses after punctuation count
    # as three characters). Good to a few frames for steady narration.
    words = text.split(' ')
    weights = [len(w) + 1 + (3 if w[-1] in '.,!?' else 0) for w in words]
    total = sum(weights)
    out, acc = [], 0.0
    for w in weights:
        out.append(round(acc / total * seconds, 3))
        acc += w
    return out


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    old = json.loads(TIMING.read_text()) if TIMING.exists() else {}
    kokoro = None
    timing = {}
    for line in SPEC['lines']:
        voice = SPEC['voices'][line['voice']]
        key = hashlib.sha1(f"{line['text']}|{voice}|{SPEC['speed']}".encode()).hexdigest()[:12]
        path = OUT / f"{line['id']}.wav"
        if path.exists() and old.get(line['id'], {}).get('key') == key:
            timing[line['id']] = old[line['id']]
            continue
        if kokoro is None:
            from kokoro_onnx import Kokoro
            kokoro = Kokoro(str(MODELS / 'kokoro-v1.0.onnx'), str(MODELS / 'voices-v1.0.bin'))
        lang = 'en-gb' if voice.startswith('b') else 'en-us'
        audio, sr = kokoro.create(line['text'], voice=voice, speed=SPEC['speed'], lang=lang)
        audio = trim(np.asarray(audio, dtype=np.float64), sr)
        audio = resample_poly(audio, SR, sr)
        audio = audio / np.abs(audio).max() * 10 ** (-1 / 20)
        sf.write(path, audio.astype(np.float32), SR)
        to_mp3(path)
        sec = len(audio) / SR
        timing[line['id']] = {
            'key': key,
            'seconds': round(sec, 3),
            'frames': int(np.ceil(sec * FPS)),
            'words': word_starts(line['text'], sec),
            'env': envelope(audio),
        }
        print(f"{line['id']:10s} {voice:9s} {sec:5.2f} s", file=sys.stderr)
    TIMING.parent.mkdir(parents=True, exist_ok=True)
    TIMING.write_text(json.dumps(timing, indent=1) + '\n')


if __name__ == '__main__':
    main()
