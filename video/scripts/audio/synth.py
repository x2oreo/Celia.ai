"""Small offline synth shared by score.py and sfx.py: every sound in the film is made here from maths, so the
score and effects are original and need no licence. 48 kHz, float64, mono unless stated."""
import numpy as np
from scipy.signal import butter, fftconvolve, sosfilt

SR = 48000
RNG = np.random.default_rng(20261004)  # fixed seed: the same render every time


def hz(midi: float) -> float:
    return 440.0 * 2 ** ((midi - 69) / 12)


def t_axis(sec: float) -> np.ndarray:
    return np.arange(int(sec * SR)) / SR


def env_adsr(n: int, a: float, d: float, s: float, r: float) -> np.ndarray:
    """Attack / decay / sustain level / release (seconds), over n samples; release sits at the end."""
    e = np.full(n, float(s))
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, n)
    e[:na] = np.linspace(0, 1, na, endpoint=False) ** 1.5 if na else e[:na]
    nd = min(nd, max(0, n - na))
    e[na:na + nd] = np.linspace(1, s, nd, endpoint=False)
    nr = min(nr, n)
    if nr:
        e[n - nr:] *= np.linspace(1, 0, nr) ** 2
    return e


def lowpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    return sosfilt(butter(order, cutoff, 'low', fs=SR, output='sos'), x, axis=0)


def highpass(x: np.ndarray, cutoff: float, order: int = 2) -> np.ndarray:
    return sosfilt(butter(order, cutoff, 'high', fs=SR, output='sos'), x, axis=0)


def bandpass(x: np.ndarray, lo: float, hi: float, order: int = 2) -> np.ndarray:
    return sosfilt(butter(order, [lo, hi], 'band', fs=SR, output='sos'), x, axis=0)


def pad_note(midi: float, sec: float, detune_cents: float = 7.0, bright: float = 5.0) -> np.ndarray:
    """Warm stereo pad: three detuned voices of a soft saw (harmonics rolled off), slow swell. Returns (n, 2)."""
    t = t_axis(sec)
    out = np.zeros((len(t), 2))
    f0 = hz(midi)
    for ch, cents in ((0, -detune_cents), (1, detune_cents)):
        for v, dc in enumerate((0.0, cents, -cents * 0.6)):
            f = f0 * 2 ** (dc / 1200)
            ph = RNG.uniform(0, 2 * np.pi)
            w = np.zeros_like(t)
            for h in range(1, 14):
                if f * h > 9000:
                    break
                w += np.sin(2 * np.pi * f * h * t + ph * h) * (1 / h) * np.exp(-h / bright)
            # slow chorus wobble
            w *= 1 + 0.08 * np.sin(2 * np.pi * (0.13 + 0.05 * v) * t + v)
            out[:, ch] += w / 3
    return out


def piano(midi: float, sec: float = 4.0, vel: float = 1.0) -> np.ndarray:
    """Felt piano: inharmonic partials with per-partial decay, a soft hammer, muted top. Mono."""
    t = t_axis(sec)
    f0 = hz(midi)
    x = np.zeros_like(t)
    B = 0.00035
    for h in range(1, 10):
        f = f0 * h * np.sqrt(1 + B * h * h)
        if f > 12000:
            break
        decay = 0.7 + 0.55 * h + f0 / 900
        x += np.sin(2 * np.pi * f * t) * (1 / h ** 1.6) * np.exp(-t * decay)
    hammer = lowpass(RNG.standard_normal(len(t)) * np.exp(-t * 90), 2500) * 0.08
    x = (x + hammer) * env_adsr(len(t), 0.004, 0.0, 1.0, 0.25)
    return lowpass(x, 3200 + 1800 * vel) * vel


def kalimba(midi: float, sec: float = 0.9, vel: float = 1.0) -> np.ndarray:
    """Soft plucked note for the arpeggio: sine + an inharmonic tine partial, quick decay. Mono."""
    t = t_axis(sec)
    f = hz(midi)
    x = np.sin(2 * np.pi * f * t) * np.exp(-t * 5.5)
    x += 0.25 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 14)
    x += 0.12 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 30)
    x *= env_adsr(len(t), 0.003, 0.0, 1.0, 0.08)
    return lowpass(x, 5000) * vel


def bell(midi: float, sec: float = 3.0, vel: float = 1.0, ratio: float = 3.5) -> np.ndarray:
    """FM bell for shimmer and chimes. Mono."""
    t = t_axis(sec)
    f = hz(midi)
    index = 2.2 * np.exp(-t * 3.0)
    x = np.sin(2 * np.pi * f * t + index * np.sin(2 * np.pi * f * ratio * t))
    return x * np.exp(-t * 1.6) * env_adsr(len(t), 0.002, 0.0, 1.0, 0.3) * vel


def sub(midi: float, sec: float, a: float = 0.6, r: float = 1.2) -> np.ndarray:
    t = t_axis(sec)
    f = hz(midi)
    x = np.sin(2 * np.pi * f * t) + 0.15 * np.sin(2 * np.pi * 2 * f * t)
    return x * env_adsr(len(t), a, 0.0, 1.0, r)


def thump(sec: float = 0.5, f0: float = 62.0, vel: float = 1.0) -> np.ndarray:
    """Soft low body thump (a pitch-dropping sine). Mono."""
    t = t_axis(sec)
    f = f0 * (1 + 0.6 * np.exp(-t * 30))
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) * np.exp(-t * 11) * env_adsr(len(t), 0.003, 0, 1, 0.05) * vel


def noise_sweep(sec: float, f_from: float, f_to: float, rise: bool = True) -> np.ndarray:
    """Filtered noise whose band slides from f_from to f_to; amplitude rises (riser) or falls (whoosh). Stereo."""
    n = int(sec * SR)
    out = np.zeros((n, 2))
    blocks = 48
    edges = np.linspace(0, n, blocks + 1).astype(int)
    for ch in range(2):
        noise = RNG.standard_normal(n)
        y = np.zeros(n)
        for b in range(blocks):
            lo, hi = edges[b], edges[b + 1]
            fc = f_from * (f_to / f_from) ** (b / (blocks - 1))
            seg = noise[max(0, lo - 2048):hi]
            filt = bandpass(seg, max(40, fc * 0.6), min(SR / 2 - 100, fc * 1.6))
            y[lo:hi] = filt[-(hi - lo):]
        out[:, ch] = y
    shape = np.linspace(0, 1, n) ** 2.2 if rise else np.exp(-np.linspace(0, 6, n)) * np.minimum(1, np.linspace(0, 12, n))
    return out * shape[:, None]


def reverb_ir(sec: float = 3.2, damp: float = 4500) -> np.ndarray:
    """Stereo hall impulse response: decaying, darkening noise with a short pre-delay."""
    n = int(sec * SR)
    t = np.arange(n) / SR
    ir = np.zeros((n, 2))
    for ch in range(2):
        x = RNG.standard_normal(n) * np.exp(-t * 2.1)
        x = lowpass(x, damp) * 0.6 + lowpass(x, damp / 3) * 0.4
        ir[:, ch] = x
    pre = int(0.018 * SR)
    ir = np.vstack([np.zeros((pre, 2)), ir])
    return ir / np.sqrt(np.sum(ir ** 2, axis=0, keepdims=True))


def reverb(x: np.ndarray, ir: np.ndarray, wet: float) -> np.ndarray:
    if x.ndim == 1:
        x = np.stack([x, x], axis=1)
    y = np.stack([fftconvolve(x[:, c], ir[:, c])[: len(x)] for c in range(2)], axis=1)
    return x * (1 - wet) + y * wet


def pan(x: np.ndarray, p: float) -> np.ndarray:
    """Mono → stereo, p in -1..1 (equal power)."""
    a = (p + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)], axis=1)


def place(buf: np.ndarray, x: np.ndarray, at_sec: float, gain: float = 1.0) -> None:
    i = int(at_sec * SR)
    if i >= len(buf):
        return
    if x.ndim == 1:
        x = pan(x, 0)
    j = min(len(buf), i + len(x))
    buf[i:j] += x[: j - i] * gain


def write(path, x: np.ndarray, peak_db: float = -1.0) -> None:
    import soundfile as sf
    import subprocess
    peak = np.abs(x).max()
    if peak > 0:
        x = x / peak * 10 ** (peak_db / 20)
    sf.write(str(path), x.astype(np.float32), SR)
    subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-i', str(path), '-codec:a', 'libmp3lame', '-b:a', '256k',
                    str(path.with_suffix('.mp3'))], check=True)
