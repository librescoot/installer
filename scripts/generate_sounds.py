#!/usr/bin/env python3
"""Generate the installer's short, original PCM cue assets."""

import math
import struct
import wave
from pathlib import Path

OUT = Path(__file__).resolve().parent.parent / 'assets' / 'sounds'
RATE = 24000


def make(name, notes):
    samples = []
    for hz, duration in notes:
        count = int(RATE * duration)
        for i in range(count):
            t = i / RATE
            envelope = min(1.0, i / (RATE * .008), (count - i) / (RATE * .035))
            value = 0 if hz == 0 else math.sin(2 * math.pi * hz * t) * envelope * .24
            samples.append(struct.pack('<h', int(value * 32767)))
    with wave.open(str(OUT / f'{name}.wav'), 'wb') as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(RATE)
        wav.writeframes(b''.join(samples))


if __name__ == '__main__':
    OUT.mkdir(exist_ok=True)
    make('beat', [(560, .055)])
    make('release', [(880, .16)])
    make('pull', [(440, .11), (660, .12)])
    make('confirmed', [(660, .09), (880, .15)])
    make('attention', [(740, .11), (0, .065), (740, .14)])
