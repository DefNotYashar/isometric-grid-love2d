#!/usr/bin/env python3
"""
Render the battle loop to WAV (44.1kHz stereo).
Style: dark trap-rock hybrid ("rock on baby trap") — detuned power-chord
guitars (stacked saw-ish harmonics + tanh distortion), sliding 808 bass,
half-time kick/snare, trap hi-hats with 32nd rolls, and a short lead motif
that answers the last bar of every 4-bar group.
E minor-ish, 140 BPM (half-time drums), 16 bars, seamless loop.
Peak-normalized to 0.89 like the lo-fi tracks. Stdlib only.
"""
import wave
import struct
import math
import random

SR = 44100
BPM = 140
BARS = 16
PEAK = 0.89
FILE = "assets/audio/battle_rock_loop.wav"

SPB = 60.0 / BPM
BAR = 4 * SPB
BAR_N = int(round(SR * BAR))          # 75600 samples exactly
N = BARS * BAR_N                      # 1209600 -> 27.43 s
BEAT_N = BAR_N // 4                   # 18900
E8_N = BAR_N // 8                     # 9450  (guitar chugs, early hats)
E16_N = BAR_N // 16                   # 4725  (late hats)
R32_N = 2362                          # ~32nd-note roll step

# 16-bar roots: Em Em C D / Em Em C D / Em G C D / Em Em C D.
# Power chords only (root+fifth+octave), so everything stays menacing,
# never cheesy. Bar 16 (D) drops back into bar 1 (Em) cleanly.
E2, G2, C2, D2 = 82.41, 98.00, 65.41, 73.42
PROG = [E2, E2, C2, D2,
        E2, E2, C2, D2,
        E2, G2, C2, D2,
        E2, E2, C2, D2]

# Lead answers (last bar of each 4-bar group); final motif climbs back to
# E5 so the loop restarts resolved. Short notes only -> decayed by the
# loop point, no click.
E5, D5, B4, A4, G5 = 659.26, 587.33, 493.88, 440.00, 783.99
LEAD = {3: (E5, D5, B4, A4),
        7: (E5, D5, B4, A4),
        11: (G5, E5, D5, B4),
        15: (A4, B4, D5, E5)}

WT = 2048
SINE = [math.sin(2 * math.pi * i / WT) for i in range(WT)]
MASK = WT - 1

rng = random.Random(13)
NOISE = [rng.random() * 2 - 1 for _ in range(SR)]


def render():
    print(f"{FILE}: {BPM} BPM half-time, {N / SR:.2f}s, {N} samples")

    mix = [0.0] * N
    pos = 0
    sine = SINE
    noise = NOISE

    for bar in range(BARS):
        root = PROG[bar]
        prev = PROG[bar - 1]
        slide = root != prev  # glide 808 into changed roots
        sect = bar // 4       # 0 intro, 1 verse, 2 chorus, 3 bridge/out

        # Chord tones (equal-tempered power chord, guitar octave).
        g0, g1, g2 = root * 2, root * 2 * 2 ** (7 / 12), root * 4
        oct_boost = 1.0 if bar < 8 else 1.35  # chorus/bridge doubling

        # Kick hits (sample offsets): beat 1 always; pickups grow by
        # section; final bar ends early so tails decay before the loop.
        Bk = [0]
        if bar == 15:
            Bk.append(int(round(1.75 * SPB * SR)))
        else:
            if bar % 2 == 1:
                Bk.append(int(round(3.0 * SPB * SR)))
            if sect >= 1:
                Bk.append(int(round(1.5 * SPB * SR)))
            if sect >= 3 and bar % 2 == 0:
                Bk.append(int(round(3.5 * SPB * SR)))

        # Snare on beat 3 (half-time); ghost at 3.75 from the chorus on,
        # except the final bar which clears out for the loop point.
        Sn = [int(round(2.0 * SPB * SR))]
        if sect >= 2 and bar != 15:
            Sn.append(int(round(3.75 * SPB * SR)))

        # Hat segments: (start, step, count). 8ths -> 16ths by section;
        # 32nd rolls close bars 4/8/12 and a longer one rides bar 16 out,
        # ending ~0.27 s before the loop point so it fully decays.
        if bar in (3, 7, 11):
            Hseg = [(0, E16_N, 14), (14 * E16_N, R32_N, 3)]
        elif bar == 15:
            Hseg = [(0, E16_N, 10), (10 * E16_N, R32_N, 8)]
        elif bar < 4:
            Hseg = [(0, E8_N, 8)]
        else:
            Hseg = [(0, E16_N, 16)]

        crash = bar in (0, 4, 8, 12)  # noise swell on section starts
        lead = LEAD.get(bar)

        for t in range(BAR_N):
            ts = t / SR
            s = 0.0

            # --- guitars: 8th-note chugs, slot-restarted phases (env from
            # zero, so no clicks at slots, bars, or the loop point).
            slot = t // E8_N
            dtg = (t - slot * E8_N) / SR
            env = math.exp(-dtg * 16)
            if dtg < 0.004:
                env *= dtg / 0.004  # 4 ms attack
            acc = 1.25 if slot % 2 == 0 else 0.9
            if slot % 2 == 1:  # off-8ths lean on the fifth
                fA, fB, fC = g1, g1 * 2, g0
            else:
                fA, fB, fC = g0, g1, g2
            pa, pb, pc = fA * dtg, fB * dtg, fC * dtg
            g = (sine[int(pa * WT) & MASK]
                 + 0.45 * sine[int(pa * 2 * WT) & MASK]
                 + 0.22 * sine[int(pa * 3 * WT) & MASK]
                 + sine[int(pb * WT) & MASK]
                 + 0.45 * sine[int(pb * 2 * WT) & MASK]
                 + 0.22 * sine[int(pb * 3 * WT) & MASK]
                 + oct_boost * sine[int(pc * WT) & MASK])
            s += 0.16 * acc * env * math.tanh(2.0 * g * 0.5)

            # --- 808: bar-long note, glide into changed roots, 60 ms gate
            # release every bar end (keeps bar joints + loop point clean).
            tail = BAR_N - t
            genv = math.exp(-ts * 1.1)
            if ts < 0.006:
                genv *= ts / 0.006
            if tail < 2646:
                genv *= tail / 2646
            if slide and ts < 0.09:
                fr = prev * (root / prev) ** (ts / 0.09)
                ph = (prev * ts + (fr - prev) * ts * 0.5)
            else:
                fr = root
                ph = fr * ts
            b = sine[int(ph * WT) & MASK] \
                + 0.35 * sine[int(ph * 2 * WT) & MASK]
            s += 0.42 * genv * math.tanh(1.4 * b)

            # --- lead motif: quarter-note answers in bars 4/8/12/16.
            if lead:
                q = t // BEAT_N
                if q < 4:
                    dtl = (t - q * BEAT_N) / SR
                    fl = lead[q] * (1 + 0.004 * sine[int(dtl * 6 * WT) & MASK])
                    pl = fl * dtl
                    lenv = math.exp(-dtl * 7)
                    if dtl < 0.010:
                        lenv *= dtl / 0.010
                    if q == 3:  # final note cut short to clear the loop
                        left = (q * BEAT_N + E8_N - t) / SR
                        if left < 0.05:
                            lenv *= max(0.0, left / 0.05)
                    s += 0.20 * lenv * (
                        sine[int(pl * WT) & MASK]
                        + 0.30 * sine[int(pl * 2 * WT) & MASK]
                        + 0.15 * sine[int(pl * 3 * WT) & MASK])

            # --- kick: pitch-swept sine punch.
            for k0 in Bk:
                dtk = (t - k0) / SR
                if 0 <= dtk < 0.32:
                    kenv = math.exp(-dtk * 15)
                    fkp = 45 + 110 * math.exp(-dtk * 34)
                    php = 45 * dtk + (110 / 34) * (1 - math.exp(-dtk * 34))
                    s += 0.85 * kenv * sine[int(php * WT) & MASK]

            # --- snare: 190 Hz body + noise snap.
            for s0 in Sn:
                dts = (t - s0) / SR
                if 0 <= dts < 0.25:
                    ni = (t * 7 + bar * 131) % SR
                    s += 0.45 * math.exp(-dts * 22) \
                        * sine[int(190 * dts * WT) & MASK]
                    s += 0.40 * math.exp(-dts * 30) * noise[ni]
                    s += 0.18 * math.exp(-dts * 70) * noise[(ni * 3) % SR]

            # --- hats: segment grids, velocity accents, rolls crescendo.
            for hstart, hstep, hcount in Hseg:
                if t >= hstart:
                    hi = (t - hstart) // hstep
                    if hi < hcount:
                        dth = (t - hstart - hi * hstep) / SR
                        if dth < 0.06:
                            ni = (t * 13 + hi * 7919) % SR
                            hh = noise[ni] - noise[(ni - 1) % SR]
                            if hstep == R32_N:
                                amp = 0.20 + 0.22 * (hi / hcount)
                            else:
                                amp = 0.24 if hi % 4 == 0 else 0.15
                            s += amp * math.exp(-dth * 110) * hh

            # --- crash swell on section starts.
            if crash and ts < 1.2:
                ni = (t * 5 + 17) % SR
                s += 0.16 * math.exp(-ts * 3.2) * (noise[ni] * 0.6
                        + noise[(ni * 2 + 5) % SR] * 0.4)

            mix[pos + t] = s
        pos += BAR_N

    peak = max(1e-9, max(abs(s) for s in mix))
    g = PEAK / peak
    print(f"  peak {peak:.3f} -> gain {g:.2f}")
    w = wave.open(FILE, "w")
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    data = bytearray()
    for s in mix:
        v = max(-1.0, min(1.0, s * g))
        iv = int(v * 32767)
        data.extend(struct.pack("<h", iv))
        data.extend(struct.pack("<h", int(iv * 0.82)))
    w.writeframes(data)
    w.close()
    print(f"  wrote {FILE} ({len(data)} bytes)")


if __name__ == "__main__":
    render()
