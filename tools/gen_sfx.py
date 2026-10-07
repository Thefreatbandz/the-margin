#!/usr/bin/env python3
"""Generate tiny procedural WAV sound effects for THE MARGIN.
Pure stdlib (wave/struct/math). 22050 Hz, 16-bit mono.
Run: python3 tools/gen_sfx.py  (writes to audio/)
"""
import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "audio")


def write_wav(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name)
    peak = max(1e-6, max(abs(s) for s in samples))
    scale = 0.9 / peak
    frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s * scale)) * 32767)) for s in samples)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)
    print(f"wrote {path} ({len(samples) / SR:.2f}s)")


def env_exp(n, decay):
    return [math.exp(-i / n * decay) for i in range(n)]


def tone(freq0, freq1, dur, decay=6.0, kind="sine"):
    n = int(SR * dur)
    e = env_exp(n, decay)
    out = []
    phase = 0.0
    for i in range(n):
        f = freq0 + (freq1 - freq0) * (i / n)
        phase += 2 * math.pi * f / SR
        if kind == "sine":
            v = math.sin(phase)
        elif kind == "square":
            v = 1.0 if math.sin(phase) > 0 else -1.0
            v *= 0.6
        elif kind == "saw":
            v = 2 * ((phase / (2 * math.pi)) % 1.0) - 1.0
            v *= 0.7
        out.append(v * e[i])
    return out


def noise(dur, decay=8.0, seed=7):
    rnd = random.Random(seed)
    n = int(SR * dur)
    e = env_exp(n, decay)
    return [(rnd.random() * 2 - 1) * e[i] for i in range(n)]


def mix(*tracks):
    n = max(len(t) for t in tracks)
    out = [0.0] * n
    for t in tracks:
        for i, s in enumerate(t):
            out[i] += s
    return out


def seq(notes, note_dur=0.1, decay=5.0):
    """Arpeggio of sine notes."""
    out = []
    for f in notes:
        out += tone(f, f, note_dur + 0.08, decay)
    return out


def main():
    # quill shot: quick bright blip falling
    write_wav("shoot.wav", tone(740, 520, 0.09, decay=9.0))
    # enemy hit: low thud
    write_wav("hit.wav", mix(tone(190, 120, 0.07, decay=10.0, kind="square"), noise(0.05, decay=12.0)))
    # ink drop pickup: two rising pings
    write_wav("gem.wav", seq([1318.5, 1760.0], note_dur=0.07, decay=7.0))
    # level up: rising major arpeggio
    write_wav("levelup.wav", seq([523.25, 659.25, 783.99, 1046.5], note_dur=0.11, decay=4.0))
    # player hurt: nasty low saw
    write_wav("hurt.wav", tone(140, 90, 0.18, decay=7.0, kind="saw"))
    # death: long descending sweep
    write_wav("death.wav", tone(320, 70, 0.7, decay=3.5))
    # boss horn: deep swell
    write_wav("boss.wav", mix(tone(65, 65, 0.9, decay=2.2), tone(98, 92, 0.9, decay=2.2)))
    # ink nova: bright swelling burst
    write_wav("nova.wav", mix(tone(300, 900, 0.28, decay=5.0), noise(0.2, decay=6.0, seed=21)))


if __name__ == "__main__":
    main()
