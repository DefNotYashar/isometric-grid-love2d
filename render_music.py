#!/usr/bin/env python3
"""
Render the menu + in-game lo-fi loops to WAV (44.1kHz stereo).
Same vibe: block-chord pads, stepped arps, vinyl bed; the game track
adds a soft kick/hat pulse and a brighter 8th-note arp.
Both renders are peak-normalized to 0.89 (loud, no clipping).
Stdlib only.
"""
import wave
import struct
import math
import random

SR = 44100
BARS = 16
PEAK = 0.89

# (freq, amp) per chord; menu: Fmaj7 Dm7 Bbmaj7 C7 @72bpm (quarter arp)
MENU = {
    "bpm": 72,
    "file": "assets/audio/menu_lofi_loop.wav",
    "arp_steps": 4,
    "kick": False,
    "hats": False,
    "prog": [
        [(174.61, .30), (220.00, .20), (261.63, .20), (329.63, .15)],
        [(146.83, .30), (174.61, .20), (220.00, .20), (261.63, .15)],
        [(116.54, .30), (146.83, .20), (174.61, .20), (220.00, .15)],
        [(130.81, .30), (164.81, .20), (196.00, .20), (233.08, .15)],
    ],
}

# game: Am7 Dm7 G7 Cmaj7 @76bpm (8th arp + pulse)
GAME = {
    "bpm": 76,
    "file": "assets/audio/game_lofi_loop.wav",
    "arp_steps": 8,
    "kick": True,
    "hats": True,
    "prog": [
        [(110.00, .30), (220.00, .18), (261.63, .18), (329.63, .14)],
        [(146.83, .30), (293.66, .18), (349.23, .18), (440.00, .12)],
        [( 98.00, .30), (246.94, .18), (293.66, .18), (349.23, .14)],
        [(130.81, .30), (261.63, .18), (329.63, .18), (493.88, .12)],
    ],
}


def render(song):
    rng = random.Random(7)
    spb = 60.0 / song["bpm"]
    bar_dur = 4 * spb
    duration = BARS * bar_dur
    n = int(SR * duration)
    print(f"{song['file']}: {song['bpm']} BPM, {duration:.1f}s, "
          f"{n} samples")

    mix_l = [0.0] * n
    pos = 0
    for bar in range(BARS):
        chord = song["prog"][bar % 4]
        nb = int(SR * bar_dur)
        phase = [rng.random() * 2 * math.pi for _ in chord]
        kick_t0 = []
        if song["kick"]:
            kick_t0 = [0.0, 2 * spb]
            if bar % 2 == 1:
                kick_t0.append(3.5 * spb)
        hat_times = []
        if song["hats"]:
            for b in range(4):
                hat_times.append(b * spb)
                hat_times.append(b * spb + spb / 2 + 0.045)  # swung
        for t in range(nb):
            ts = t / SR
            idx = int(ts / bar_dur * song["arp_steps"]) % len(chord)
            s = 0.0
            for j, (freq, amp) in enumerate(chord):
                phase[j] += 2 * math.pi * freq / SR
                s += amp * (0.30 if j == idx else 0.06) * math.sin(phase[j])
            # soft kick: 55 Hz sine, pitch+amp decay
            for k0 in kick_t0:
                dt = ts - k0
                if 0 <= dt < 0.30:
                    env = math.exp(-dt * 14)
                    s += 0.55 * env * math.sin(
                        2 * math.pi * (55 - 20 * math.exp(-dt * 30)) * dt)
            # hats: short noise bursts, crude highpass
            for h0 in hat_times:
                dt = ts - h0
                if 0 <= dt < 0.05:
                    s += 0.10 * math.exp(-dt * 90) * (rng.random() * 2 - 1)
            # vinyl bed + occasional pop
            s += 0.008 * math.sin(2 * math.pi * 800 * (pos + t) / SR)
            if rng.random() < 0.00004:
                s += rng.choice([-1, 1]) * 0.05
            s *= 1.0 - (ts / bar_dur) * 0.22
            mix_l[pos + t] += s
        pos += nb

    peak = max(1e-9, max(abs(s) for s in mix_l))
    g = PEAK / peak
    print(f"  peak {peak:.3f} -> gain {g:.2f}")
    w = wave.open(song["file"], "w")
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    data = bytearray()
    for s in mix_l:
        v = max(-1.0, min(1.0, s * g))
        iv = int(v * 32767)
        data.extend(struct.pack("<h", iv))
        data.extend(struct.pack("<h", int(iv * 0.82)))
    w.writeframes(data)
    w.close()
    print(f"  wrote {len(data)} bytes")


if __name__ == "__main__":
    render(MENU)
    render(GAME)
