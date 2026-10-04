"""Interface and device sounds, one short file each, in public/audio/sfx/<name>.mp3. Quiet and warm: taps, the orb
waking, a tool step finishing, the verdict card, a scan lock, a watch haptic and its alert tone, SOS ticks,
transitions. Nothing alarming or siren-like; red moments stay calm."""
import pathlib
import sys

import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).parent))
from synth import (SR, bell, env_adsr, highpass, kalimba, lowpass, noise_sweep, pan, place, reverb,  # noqa: E402
                   reverb_ir, t_axis, thump, write, RNG)

OUT = pathlib.Path(__file__).resolve().parents[2] / 'public/audio/sfx'
IR = reverb_ir(1.6, 6000)


def tone(f: float, sec: float, decay: float, a: float = 0.004) -> np.ndarray:
    t = t_axis(sec)
    return np.sin(2 * np.pi * f * t) * np.exp(-t * decay) * env_adsr(len(t), a, 0, 1, 0.02)


def tap() -> np.ndarray:
    t = t_axis(0.09)
    click = highpass(RNG.standard_normal(len(t)) * np.exp(-t * 400), 2000) * 0.25
    body = tone(1900, 0.09, 70) * 0.5 + tone(950, 0.09, 50) * 0.3
    return reverb(click + body, IR, 0.15)


def orb_on() -> np.ndarray:
    x = np.zeros(int(1.4 * SR))
    for i, m in enumerate([81, 88]):
        b = bell(m, 1.2, 0.6, ratio=2.0)
        x[int(i * 0.09 * SR): int(i * 0.09 * SR) + len(b)] += b
    return reverb(lowpass(x, 7000), IR, 0.35)


def tool_done() -> np.ndarray:
    x = kalimba(88, 0.5, 0.8) + 0.5 * kalimba(95, 0.5, 0.5)
    return reverb(x, IR, 0.25)


def card_in() -> np.ndarray:
    # A low, warm "here it is": not an alarm, even for Known risk.
    x = tone(220, 0.9, 5) * 0.6 + tone(330, 0.9, 6) * 0.35 + tone(440, 0.9, 8) * 0.2
    x[: len(thump(0.4, 80, 0.5))] += thump(0.4, 80, 0.5)
    return reverb(lowpass(x, 3000), IR, 0.3)


def sheet() -> np.ndarray:
    return noise_sweep(0.45, 400, 2400, rise=False) * 0.6


def whoosh() -> np.ndarray:
    return noise_sweep(0.8, 2400, 300, rise=False)


def scan_lock() -> np.ndarray:
    x = np.zeros(int(0.5 * SR))
    for i, f in enumerate([1320, 1760]):
        b = tone(f, 0.12, 25, a=0.003) * (1.0 - 0.3 * i)
        i0 = int(i * 0.085 * SR)
        x[i0:i0 + len(b)] += b
    return reverb(x, IR, 0.2)


def haptic() -> np.ndarray:
    # Watch buzz: three short 170 Hz pulses, felt more than heard.
    x = np.zeros(int(0.55 * SR))
    for i in range(3):
        t = t_axis(0.09)
        p = np.sign(np.sin(2 * np.pi * 170 * t)) * 0.5 + np.sin(2 * np.pi * 170 * t) * 0.5
        p = lowpass(p, 900) * env_adsr(len(t), 0.004, 0, 1, 0.02)
        i0 = int(i * 0.15 * SR)
        x[i0:i0 + len(p)] += p
    return x


def watch_alert() -> np.ndarray:
    # A gentle rising three-note watch tone (E, G#, B).
    x = np.zeros(int(1.6 * SR))
    for i, m in enumerate([76, 80, 83]):
        b = bell(m, 0.9, 0.7, ratio=1.0)
        i0 = int(i * 0.16 * SR)
        x[i0:i0 + len(b)] += b
    return reverb(lowpass(x, 6000), IR, 0.3)


def sos_tick() -> np.ndarray:
    return reverb(tone(1100, 0.12, 40) * 0.6 + tone(550, 0.12, 30) * 0.3, IR, 0.2)


def chime() -> np.ndarray:
    # QR shown / the card opening on the second phone: a soft rising sparkle.
    x = np.zeros(int(1.6 * SR))
    for i, m in enumerate([86, 90, 93, 98]):
        b = bell(m, 1.0, 0.45 - 0.06 * i, ratio=2.0)
        i0 = int(i * 0.06 * SR)
        x[i0:i0 + len(b)] += b
    return reverb(x, IR, 0.4)


def ledger_tick() -> np.ndarray:
    return reverb(kalimba(83, 0.35, 0.6), IR, 0.2)


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, fn in [('tap', tap), ('orb_on', orb_on), ('tool_done', tool_done), ('card_in', card_in),
                     ('sheet', sheet), ('whoosh', whoosh), ('scan_lock', scan_lock), ('haptic', haptic),
                     ('watch_alert', watch_alert), ('sos_tick', sos_tick), ('chime', chime),
                     ('ledger_tick', ledger_tick)]:
        x = fn()
        if x.ndim == 1:
            x = pan(x, 0)
        write(OUT / f'{name}.wav', x, peak_db=-1.0)
    print('sfx: done', file=sys.stderr)


if __name__ == '__main__':
    main()
