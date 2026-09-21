#!/usr/bin/env python3
"""
Combat + UI SFX for the game (16-bit mono WAVs, peak-normalized to 0.89).
Stdlib only. Each sound is a tiny synth recipe below.
Run: python3 assets/audio/render_sfx.py
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


def noise():
    return random.uniform(-1, 1)


# short percussive low thump: sine drop 160->60Hz + noise click
def hit_thud():
    n = secs(0.20)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 28)
        f = 60 + 100 * math.exp(-t * 40)
        out.append((sine(f, t) * 0.9 + noise() * 0.25 * math.exp(-t * 90)) * env)
    return out


# airy whoosh: noise with rising then falling amplitude, slight pitch feel via AM
def swing_whoosh():
    n = secs(0.22)
    out = []
    for i in range(n):
        t = i / SR
        k = t / 0.22
        env = math.sin(k * math.pi) ** 1.5
        out.append(noise() * env * 0.7 * (0.6 + 0.4 * math.sin(2 * math.pi * 900 * t)))
    return out


# plucked string: triangle-ish burst with pitch drop + fast decay
def bow_twang():
    n = secs(0.28)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 16)
        f = 220 - 60 * min(1, t * 8)
        v = (2 * abs(2 * ((f * t) % 1) - 1) - 1)
        out.append(v * env * 0.6)
    return out


# happy pop: sine blip gliding up 400->900Hz
def merge_pop():
    n = secs(0.22)
    out = []
    for i in range(n):
        t = i / SR
        k = t / 0.22
        env = math.sin(k * math.pi)
        f = 400 + 500 * k
        out.append(sine(f, t) * env * 0.7)
    return out


# wet split: two descending blips 700->300, 500->250
def split_pop():
    n = secs(0.30)
    out = []
    for i in range(n):
        t = i / SR
        v = 0.0
        for j, (f0, f1, t0) in enumerate([(700, 300, 0.0), (500, 250, 0.12)]):
            if t >= t0:
                lt = t - t0
                k = lt / 0.16
                if k < 1:
                    f = f0 + (f1 - f0) * k
                    v += sine(f, lt) * math.sin(k * math.pi) * 0.5
        out.append(v)
    return out


# death poof: soft noise burst, lowpassed by averaging, decaying
def death_poof():
    n = secs(0.32)
    out = []
    prev = 0.0
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 12)
        prev = prev * 0.82 + noise() * 0.18
        out.append(prev * env * 2.2)
    return out


# UI blip: 660Hz square-ish, very short
def select_blip():
    n = secs(0.08)
    out = []
    for i in range(n):
        t = i / SR
        env = math.exp(-t * 40)
        v = 1.0 if sine(660, t) > 0 else -1.0
        out.append(v * env * 0.4)
    return out


# UI click: 1200Hz tick
def ui_click():
    n = secs(0.05)
    out = []
    for i in range(n):
        t = i / SR
        out.append(sine(1200, t) * math.exp(-t * 80) * 0.5)
    return out


# heal chime: two rising sines E5->A5
def heal_chime():
    n = secs(0.35)
    out = []
    for i in range(n):
        t = i / SR
        v = 0.0
        for j, (f, t0) in enumerate([(659.25, 0.0), (880.0, 0.12)]):
            if t >= t0:
                lt = t - t0
                v += sine(f, lt) * math.exp(-lt * 9) * 0.45
        out.append(v)
    return out


# taunt horn: low saw-ish blast 98Hz + fifth, 0.4s
def taunt_horn():
    n = secs(0.45)
    out = []
    for i in range(n):
        t = i / SR
        k = t / 0.45
        env = min(1, k * 12) * (1 - k) ** 1.5
        v = sine(98, t) * 0.6 + sine(147, t) * 0.35 + sine(196, t) * 0.2
        # rough edge
        v += 0.12 if v > 0 else -0.12
        out.append(v * env * 0.7)
    return out


if __name__ == "__main__":
    random.seed(7)
    save("sfx_hit", hit_thud())
    save("sfx_whoosh", swing_whoosh())
    save("sfx_twang", bow_twang())
    save("sfx_merge", merge_pop())
    save("sfx_split", split_pop())
    save("sfx_poof", death_poof())
    save("sfx_select", select_blip())
    save("sfx_click", ui_click())
    save("sfx_heal", heal_chime())
    save("sfx_taunt", taunt_horn())
