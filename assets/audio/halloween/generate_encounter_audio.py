"""Generate original ECO encounter sounds using only the Python standard library.

Run from any directory. Output is 22,050 Hz mono signed 16-bit PCM WAV beside
this script. No recorded or downloaded audio is read; seeds make builds stable.
"""
from pathlib import Path
import math
import random
import struct
import wave

RATE = 22050
OUTPUT = Path(__file__).resolve().parent


def write_sound(filename, seconds, seed, kind):
    rng = random.Random(seed)
    samples = []
    slow_noise = mid_noise = air_noise = 0.0
    phase = 0.0
    for i in range(int(seconds * RATE)):
        t = i / RATE
        noise = rng.uniform(-1.0, 1.0)
        slow_noise += 0.018 * (noise - slow_noise)
        mid_noise += 0.15 * (noise - mid_noise)
        air_noise += 0.035 * (noise - air_noise)
        if kind == 'far':
            onset = 1.0 - math.exp(-t * 6.0)
            tail = math.exp(-t * 0.56)
            rumbles = 0.70 + 0.20 * math.sin(t * 4.2) + 0.10 * math.sin(t * 10.1)
            body = 0.66 * slow_noise + 0.045 * math.sin(math.tau * 37.0 * t) + 0.025 * math.sin(math.tau * 53.0 * t)
            value = onset * tail * rumbles * body
        elif kind == 'near':
            crack = (mid_noise - slow_noise) * math.exp(-t * 16.0) * 0.22
            first_roll = math.exp(-max(0.0, t - 0.16) * 0.64) * (1.0 - math.exp(-t * 12.0))
            rumble = 0.79 * slow_noise + 0.045 * math.sin(math.tau * 31.0 * t) + 0.024 * math.sin(math.tau * 47.0 * t)
            value = crack + rumble * first_roll * (0.78 + 0.22 * math.sin(t * 5.7))
        else:
            ramp = math.sin(math.pi * min(1.0, t / seconds)) ** 1.5
            frequency = 27.0 + 10.0 * math.sin(math.pi * t / seconds)
            phase += math.tau * frequency / RATE
            bass = math.sin(phase) * 0.07 + math.sin(phase * 1.97 + 0.3) * 0.025
            displaced_air = (mid_noise - air_noise) * 0.05 + slow_noise * 0.4
            value = ramp * (bass + displaced_air) * (0.92 + 0.08 * math.sin(t * 2.1))
        fade = min(1.0, t / 0.018, (seconds - t) / 0.65)
        samples.append(value * max(0.0, fade))
    # Quiet delayed tails soften the thunder; no sample is read at playback time.
    if kind in ('far', 'near'):
        dry = samples[:]
        for delay, gain in ((0.29, 0.28), (0.61, 0.17), (1.04, 0.09)):
            offset = int(delay * RATE)
            for i in range(offset, len(samples)):
                samples[i] += dry[i - offset] * gain
        for i in range(max(0, len(samples) - int(0.65 * RATE)), len(samples)):
            samples[i] *= (len(samples) - 1 - i) / (0.65 * RATE)
    peak = max(abs(value) for value in samples)
    target = 0.70 if kind == 'near' else 0.58
    scale = target / peak
    pcm = b''.join(struct.pack('<h', int(value * scale * 32767)) for value in samples)
    with wave.open(str(OUTPUT / filename), 'wb') as audio:
        audio.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        audio.writeframes(pcm)
    rms = math.sqrt(sum((value * scale) ** 2 for value in samples) / len(samples))
    print(f'{filename}: {seconds:.1f}s peak={target:.2f} rms={rms:.4f} bytes={len(pcm)}')


if __name__ == '__main__':
    write_sound('thunder-far.wav', 6.0, 39013, 'far')
    write_sound('thunder-near.wav', 5.5, 39014, 'near')
    write_sound('pressure-pass.wav', 7.0, 39015, 'pressure')
