#!/usr/bin/env python3
"""
Big-moment stingers (16-bit mono WAVs, peak-normalized to 0.89).
Stdlib only. Run: python3 assets/audio/render_stingers.py
- draft_pick: rising chime + impact for ability drafts
- clear_fanfare: short victory swell for level clear
- elite_drone: low warning pulse for elite battle intros (~3s)
"""
import wave
import struct
import math
import random

SR = 44100
PEAK = 0.89
OUT = "assets/audio/"


def save(name, samples):
    peak = max(1e-6, max(abs(s) for s in samples))
    g = PEAK / peak
    frames = b"".join(struct.pack("<h", int(max(-1, min(1, s * g)) * 32767)) for s in samples)
    with wave.open(OUT + name + ".wav", "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames)
    print(f"{name}.wav: {len(samples) / SR:.2f}s")


def secs(s):
    return int(s * SR)


def sine(f, t):
    return math.sin(2 * math.pi * f * t)


# draft pick: quick rising arp (E5 G5 B5 E6) + soft impact thump
def draft_pick():
    n = secs(0.7)
    out = []
    notes = [659.25, 783.99, 987.77, 1318.5]
    for i in range(n):
        t = i / SR
        v = 0.0
        for j, f in enumerate(notes):
            t0 = j * 0.09
            if t >= t0:
                lt = t - t0
                v += sine(f, lt) * math.exp(-lt * 8) * 0.35
        # impact thump under the last note
        if t >= 0.27:
            lt = t - 0.27
            v += sine(90 - 40 * min(1, lt * 6), lt) * math.exp(-lt * 14) * 0.5
        out.append(v)
    return out


# level clear: warm major swell (C E G C up), ~1.4s, soft landing
def clear_fanfare():
    n = secs(1.4)
    out = []
    notes = [261.63, 329.63, 392.0, 523.25]
    for i in range(n):
        t = i / SR
        v = 0.0
        for j, f in enumerate(notes):
            t0 = j * 0.14
            if t >= t0:
                lt = t - t0
                env = min(1, lt * 20) * math.exp(-lt * 2.2)
                v += (sine(f, lt) * 0.5 + sine(f * 2, lt) * 0.18) * env * 0.4
        out.append(v)
    return out


# elite warning: 3 low pulses (55Hz + fifth) with rising tension
def elite_drone():
    n = secs(3.0)
    out = []
    for i in range(n):
        t = i / SR
        # pulse gate: 3 swells
        k = (t % 1.0)
        gate = math.sin(k * math.pi) ** 2
        tension = 0.7 + 0.3 * (t / 3.0)
        v = (sine(55, t) * 0.6 + sine(82.5, t) * 0.3 + sine(110, t) * 0.15)
        out.append(v * gate * tension * 0.8)
    return out


if __name__ == "__main__":
    random.seed(11)
    save("sfx_draft", draft_pick())
    save("sfx_clear", clear_fanfare())
    save("sfx_elite", elite_drone())
