#!/usr/bin/env python3
"""
Re-render grass footstep: more blade-swish, less dirt-thud.
Mono 44.1kHz, peak-normalized to 0.7.
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


def grass():
    # Distinct grass: heel swipe + toe release, blade friction noise
    rng = random.Random(42)
    n = int(SR * 0.18)
    out, prev = [], 0.0
    for i in range(n):
        t = i / SR
        # Two soft impacts: heel ~15ms, toe ~85ms
        heel = math.exp(-((t - 0.015) ** 2) / 0.00035)
        toe  = 0.65 * math.exp(-((t - 0.085) ** 2) / 0.00055)
        bump = heel + toe

        # High-frequency blade friction (broadband, airy)
        nz = rng.random() * 2 - 1
        hp = nz - prev      # crude 1-pole highpass = swish
        prev = nz
        blade = 0.55 * bump * hp

        # Tiny tonal whisper from bending blades (2-5 kHz)
        whisper = 0.08 * bump * math.sin(2 * math.pi * 3400 * t) * math.exp(-t * 40)

        # Subtle low-end body so it doesn't feel weightless
        body = 0.12 * bump * math.exp(-t * 50) * math.sin(2 * math.pi * 120 * t)

        out.append(blade + whisper + body)
    return out


if __name__ == "__main__":
    save("assets/audio/step_grass.wav", grass())