#!/usr/bin/env python3
"""
Enemy footstep SFX: slime_squelch.wav, skeleton_clack.wav
Mono 44.1kHz, peak-normalized. Short, distinctive per enemy type.
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


def slime():
    # wet squelch: low gurgle + suction pop
    rng = random.Random(101)
    n = int(SR * 0.22)
    out, lp = [], 0.0
    for i in range(n):
        t = i / SR
        # body: resonant low gurgle
        body = 0.5 * math.exp(-t * 8) * math.sin(2 * math.pi * 90 * t * (1 + 0.3 * math.exp(-t * 5)))
        # suction release pop at start
        pop = 0.7 * math.exp(-t * 180) * math.sin(2 * math.pi * 220 * t)
        # wet texture
        nz = rng.random() * 2 - 1
        lp += 0.3 * (nz - lp)
        wet = 0.25 * math.exp(-t * 12) * lp
        out.append(body + pop + wet)
    return out


def skeleton():
    # dry bone clack: sharp transient + hollow ring
    rng = random.Random(202)
    n = int(SR * 0.12)
    out = []
    for i in range(n):
        t = i / SR
        # main clack: very sharp, high freq
        clack = 1.2 * math.exp(-t * 220) * math.sin(2 * math.pi * 1800 * t)
        # hollow body resonance
        ring = 0.35 * math.exp(-t * 35) * math.sin(2 * math.pi * 420 * t)
        # tiny debris rattle
        rattle = 0.15 * math.exp(-t * 60) * (rng.random() * 2 - 1)
        out.append(clack + ring + rattle)
    return out


if __name__ == "__main__":
    save("assets/audio/step_slime.wav", slime())
    save("assets/audio/step_skeleton.wav", skeleton())