#!/usr/bin/env python3
"""
16-bar lo-fi menu + in-game loops (MIDI, Ableton-ready).
Same vibe: warm 7th-chord pads, sparse melody, swung hats.
Menu: 72 BPM, Fmaj7-Dm7-Bbmaj7-C7. Game: 76 BPM, Am7-Dm7-G7-Cmaj7.
Events are scheduled at ABSOLUTE ticks, sorted, then serialized.
No external dependencies.
"""
import struct

TICKS_PER_BEAT = 480
BEATS_PER_BAR = 4
BARS = 16
BAR_TICKS = BEATS_PER_BAR * TICKS_PER_BEAT
TOTAL_TICKS = BARS * BAR_TICKS


def var_len(n):
    out = [n & 0x7F]
    n >>= 7
    while n > 0:
        out.append((n & 0x7F) | 0x80)
        n >>= 7
    out.reverse()
    return bytes(out)


class Track:
    def __init__(self, name):
        self.name = name
        self.events = []

    def add(self, tick, data, order=0):
        self.events.append((tick, order, bytes(data)))

    def note(self, tick, dur, channel, note, vel):
        self.add(tick, [0x90 | channel, note, vel], order=0)
        self.add(tick + dur, [0x80 | channel, note, 0], order=1)

    def serialize(self):
        ev = [(0, -1, bytes([0xFF, 0x03, len(self.name.encode())])
               + self.name.encode())]
        ev += self.events
        ev.append((TOTAL_TICKS, 2, bytes([0xFF, 0x2F, 0])))
        ev.sort(key=lambda e: (e[0], e[1]))
        out = bytearray()
        last = 0
        for tick, _, data in ev:
            out += var_len(tick - last) + data
            last = tick
        return bytes(out)


SONGS = {
    "menu": {
        "bpm": 72,
        "file": "assets/audio/menu_lofi_loop.mid",
        # (bass_note, [chord tones]); 60 = middle C
        "prog": [
            [41, [65, 69, 72, 76]],  # F2; Fmaj7
            [38, [62, 65, 69, 72]],  # D2; Dm7
            [46, [58, 62, 65, 69]],  # Bb2; Bbmaj7
            [36, [60, 64, 67, 70]],  # C2; C7
        ],
        # (bar_in_phrase, beat, dur_beats, note, vel)
        "melody": [
            (0, 0, 1.5, 76, 72), (0, 2, 1.0, 74, 64),
            (1, 0, 2.0, 72, 70), (1, 3, 0.5, 69, 62),
            (2, 0, 1.5, 69, 68), (2, 2, 1.5, 74, 66),
            (3, 0, 1.0, 76, 72), (3, 1, 1.0, 74, 64),
            (3, 2, 1.0, 72, 66), (3, 3, 1.0, 69, 60),
        ],
        "swing": 55,
        "extra_kick": False,
    },
    "game": {
        "bpm": 76,
        "file": "assets/audio/game_lofi_loop.mid",
        "prog": [
            [33, [57, 60, 64, 67]],  # A1; Am7
            [38, [62, 65, 69, 72]],  # D2; Dm7
            [43, [55, 59, 62, 65]],  # G2; G7
            [36, [60, 64, 67, 71]],  # C2; Cmaj7
        ],
        "melody": [
            (0, 0, 1.5, 79, 72), (0, 2, 1.0, 77, 64),
            (1, 0, 2.0, 76, 70), (1, 3, 0.5, 74, 62),
            (2, 0, 1.0, 74, 68), (2, 1, 1.0, 77, 66),
            (2, 2, 2.0, 79, 70),
            (3, 0, 1.0, 81, 72), (3, 1, 1.0, 79, 64),
            (3, 2, 1.0, 77, 66), (3, 3, 1.0, 76, 60),
        ],
        "swing": 60,
        "extra_kick": True,
    },
}


def build(song):
    bpm = song["bpm"]
    us = int(60_000_000 / bpm)
    conductor = Track("Conductor")
    conductor.add(0, [0xFF, 0x51, 3, (us >> 16) & 0xFF,
                      (us >> 8) & 0xFF, us & 0xFF])
    conductor.add(0, [0xFF, 0x58, 4, 4, 2, 24, 8])
    conductor.add(0, [0xFF, 0x59, 2, 0xFF, 0])  # F major key sig

    bass, rhodes, melody, drums = (Track("Sub Bass"), Track("Rhodes"),
                                   Track("Melody"), Track("LoFi Drums"))
    DR = 9
    KICK, SNARE, CHH, OHH = 36, 38, 42, 46

    for bar in range(BARS):
        t0 = bar * BAR_TICKS
        root, tones = song["prog"][(bar // 4) % 4]
        bass.note(t0, BAR_TICKS, 1, root, 82)
        for i, n in enumerate(tones):
            rhodes.note(t0, BAR_TICKS, 2, n, 64 + (i % 2) * 5 - bar % 3)
        for b, beat, dur, note, vel in song["melody"]:
            if b == bar % 4:
                melody.note(t0 + int(beat * TICKS_PER_BEAT),
                            int(dur * TICKS_PER_BEAT), 3, note, vel)
        for beat in range(4):
            bt = t0 + beat * TICKS_PER_BEAT
            if beat in (0, 2):
                drums.note(bt, 120, DR, KICK, 92)
            else:
                drums.note(bt, 120, DR, SNARE, 82)
            if song["extra_kick"] and beat == 3 and bar % 2 == 1:
                drums.note(bt + TICKS_PER_BEAT // 2, 120, DR, KICK, 80)
            for eighth in range(2):
                ht = bt + eighth * (TICKS_PER_BEAT // 2)
                if eighth == 1:
                    ht += song["swing"]
                drums.note(ht, 90, DR, CHH, 48 if eighth == 0 else 40)
        if bar % 4 == 3:
            drums.note(t0 + 3 * TICKS_PER_BEAT + TICKS_PER_BEAT // 2,
                       240, DR, OHH, 55)

    tracks = [conductor, bass, rhodes, melody, drums]
    out = bytearray(b"MThd")
    out += struct.pack(">IHHH", 6, 1, len(tracks), TICKS_PER_BEAT)
    for t in tracks:
        body = t.serialize()
        out += b"MTrk" + struct.pack(">I", len(body)) + body
    return bytes(out)


if __name__ == "__main__":
    for name, song in SONGS.items():
        midi = build(song)
        with open(song["file"], "wb") as f:
            f.write(midi)
        print(f"{name}: {song['file']} ({len(midi)} bytes, "
              f"{song['bpm']} BPM, {BARS} bars)")
