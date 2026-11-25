"""Create the project's original short combat cues with Python's standard library."""

import math
from pathlib import Path
import random
import struct
import wave

RATE = 48000
DESTINATION = Path(__file__).resolve().parents[1]


def make_cue(name, duration, base_hz, end_hz, noise_level, seed):
    rng = random.Random(seed)
    samples = []
    phase = 0.0
    noise = 0.0
    for index in range(round(duration * RATE)):
        time = index / RATE
        fraction = time / duration
        phase += 2 * math.pi * (base_hz + (end_hz - base_hz) * fraction) / RATE
        noise = noise * 0.35 + rng.uniform(-1, 1) * 0.65
        envelope = min(1, time / 0.002) * (1 - fraction) ** 2.4
        tone = math.sin(phase) + 0.2 * math.sin(phase * 3.7)
        transient = noise * noise_level * math.exp(-time * 45)
        samples.append((tone * 0.5 + transient) * envelope)
    gain = 0.75 / max(abs(value) for value in samples)
    pcm = b"".join(struct.pack("<h", round(value * gain * 32767)) for value in samples)
    with wave.open(str(DESTINATION / name), "wb") as output:
        output.setnchannels(1)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm)


if __name__ == "__main__":
    make_cue("S_EnemyHit.wav", 0.11, 210, 130, 0.8, 77)
    make_cue("S_PlayerHurt.wav", 0.165, 145, 82, 0.6, 78)
