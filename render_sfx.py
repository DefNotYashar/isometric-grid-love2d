#!/usr/bin/env python3
"""
Footstep SFX: step_dirt.wav, step_grass.wav, step_water.wav.
Mono 44.1kHz, peak-normalized to 0.7. In-game pitch is randomized
at play time (Source:setPitch), so one sample per surface suffices.
Stdlib only.
"""
import wave
import struct
import math
import random

SR = 44100
PEAK = 0.7


def save(path, samples):
    peak = max(1e-9, max(abs(s) for s in samples))
    g = PEAK / peak
    w = wave.open(path, "w")
    w.setnchannels(1)
    w.setsampwidth(2)
    w.setframerate(SR)
    data = bytearray()
    for s in samples:
        v = max(-1.0, min(1.0, s * g))
        data.extend(struct.pack("<h", int(v * 32767)))
    w.writeframes(data)
    w.close()
    print(f"{path}: {len(samples)/SR:.2f}s, gain {g:.2f}")


def dirt():
    # low thud: 70 Hz knock + gritty onset
    rng = random.Random(11)
    n = int(SR * 0.14)
    out, lp = [], 0.0
    for i in range(n):
        t = i / SR
        tone = 0.8 * math.exp(-t * 32) * math.sin(2 * math.pi * 70 * t)
        nz = rng.random() * 2 - 1
        lp += 0.25 * (nz - lp)
        grit = 0.35 * math.exp(-t * 70) * lp
        out.append(tone + grit)
    return out


def grass():
    # swish: airy noise, heel-toe double bump
    rng = random.Random(23)
    n = int(SR * 0.16)
    out, prev = [], 0.0
    for i in range(n):
        t = i / SR
        bump = math.exp(-((t - 0.02) ** 2) / 0.0006) \
            + 0.6 * math.exp(-((t - 0.08) ** 2) / 0.0009)
        nz = rng.random() * 2 - 1
        hp = nz - prev  # crude highpass = airy
        prev = nz
        out.append(0.55 * bump * hp
                   + 0.10 * bump * math.sin(2 * math.pi * 2400 * t))
    return out


def water():
    # splash: noise wash + droplet blips
    rng = random.Random(37)
    n = int(SR * 0.30)
    drops = [(0.03 + rng.random() * 0.15, 700 + rng.random() * 1400)
             for _ in range(5)]
    out, lp = [], 0.0
    for i in range(n):
        t = i / SR
        nz = rng.random() * 2 - 1
        lp += 0.4 * (nz - lp)
        s = 0.5 * math.exp(-t * 14) * (nz * 0.6 + lp * 0.4)
        for d0, f in drops:
            dt = t - d0
            if 0 <= dt < 0.05:
                s += 0.22 * math.exp(-dt * 120) * math.sin(2 * math.pi * f * dt)
        out.append(s)
    return out


if __name__ == "__main__":
    save("assets/audio/step_dirt.wav", dirt())
    save("assets/audio/step_grass.wav", grass())
    save("assets/audio/step_water.wav", water())
