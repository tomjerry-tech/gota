from __future__ import annotations

import math
import random
import struct
import wave
from pathlib import Path


SAMPLE_RATE = 22050
ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / "assets" / "audio"


def clamp(value: float) -> float:
    return max(-1.0, min(1.0, value))


def triangle(phase: float) -> float:
    return 2.0 * abs(2.0 * (phase - math.floor(phase + 0.5))) - 1.0


def envelope(time: float, duration: float, attack: float = 0.02, release: float = 0.08) -> float:
    return min(1.0, time / max(attack, 0.001), (duration - time) / max(release, 0.001))


def note_frequency(midi: int) -> float:
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def write_wav(name: str, samples: list[float] | list[tuple[float, float]]) -> None:
    OUTPUT.mkdir(parents=True, exist_ok=True)
    path = OUTPUT / name
    stereo = bool(samples and isinstance(samples[0], tuple))
    with wave.open(str(path), "wb") as output:
        output.setnchannels(2 if stereo else 1)
        output.setsampwidth(2)
        output.setframerate(SAMPLE_RATE)
        if stereo:
            payload = b"".join(
                struct.pack("<hh", round(clamp(left) * 32767), round(clamp(right) * 32767))
                for left, right in samples
            )
        else:
            payload = b"".join(struct.pack("<h", round(clamp(sample) * 32767)) for sample in samples)
        output.writeframes(payload)
    print(f"Wrote {path.relative_to(ROOT)}")


def render_tone(duration: float, frequency, volume: float = 0.45, waveform: str = "triangle") -> list[float]:
    count = round(duration * SAMPLE_RATE)
    samples: list[float] = []
    phase = 0.0
    for index in range(count):
        time = index / SAMPLE_RATE
        hz = frequency(time) if callable(frequency) else float(frequency)
        phase += hz / SAMPLE_RATE
        value = math.sin(phase * math.tau) if waveform == "sine" else triangle(phase)
        samples.append(value * volume * envelope(time, duration))
    return samples


def mix(length: int, layers: list[tuple[int, list[float], float]]) -> list[float]:
    result = [0.0] * length
    for offset, layer, gain in layers:
        for index, value in enumerate(layer):
            target = offset + index
            if target >= length:
                break
            result[target] += value * gain
    return [clamp(value) for value in result]


def _add_stereo(
    left: list[float],
    right: list[float],
    samples: list[float],
    start_time: float,
    gain: float = 1.0,
    pan: float = 0.0,
) -> None:
    start = round(start_time * SAMPLE_RATE)
    left_gain = gain * math.sqrt((1.0 - clamp(pan)) * 0.5)
    right_gain = gain * math.sqrt((1.0 + clamp(pan)) * 0.5)
    for index, value in enumerate(samples):
        target = start + index
        if target >= len(left):
            break
        left[target] += value * left_gain
        right[target] += value * right_gain


def _finish_stereo(left: list[float], right: list[float], peak: float) -> list[tuple[float, float]]:
    current_peak = max(max(abs(value) for value in left), max(abs(value) for value in right), 0.001)
    scale = peak / current_peak
    return [
        (math.tanh(left[index] * scale), math.tanh(right[index] * scale))
        for index in range(len(left))
    ]


def _pluck(midi: int, duration: float, seed: int) -> list[float]:
    rng = random.Random(seed)
    frequency = note_frequency(midi)
    samples: list[float] = []
    phase = 0.0
    for index in range(round(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        phase += frequency / SAMPLE_RATE
        body = (
            math.sin(phase * math.tau)
            + 0.38 * math.sin(phase * math.tau * 2.0 + 0.3)
            + 0.16 * math.sin(phase * math.tau * 3.0 + 0.8)
        )
        pick = rng.uniform(-1.0, 1.0) * math.exp(-time * 55.0)
        decay = math.exp(-time * 3.7 / duration)
        samples.append((body * 0.34 + pick * 0.12) * decay * envelope(time, duration, 0.006, 0.10))
    return samples


def _shepherd_flute(midi: int, duration: float, seed: int) -> list[float]:
    rng = random.Random(seed)
    frequency = note_frequency(midi)
    samples: list[float] = []
    phase = 0.0
    breath = 0.0
    for index in range(round(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        vibrato = 1.0 + 0.0045 * math.sin(time * math.tau * 5.1)
        phase += frequency * vibrato / SAMPLE_RATE
        breath = breath * 0.82 + rng.uniform(-1.0, 1.0) * 0.18
        tone = math.sin(phase * math.tau) + 0.16 * math.sin(phase * math.tau * 2.0 + 0.2)
        shape = envelope(time, duration, 0.11, 0.18)
        samples.append((tone * 0.25 + breath * 0.018) * shape)
    return samples


def _warm_drone(midis: list[int], duration: float) -> list[float]:
    phases = [0.0] * len(midis)
    samples: list[float] = []
    for index in range(round(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        value = 0.0
        for note_index, midi in enumerate(midis):
            phases[note_index] += note_frequency(midi) / SAMPLE_RATE
            phase = phases[note_index] * math.tau
            value += math.sin(phase) + 0.10 * math.sin(phase * 2.0)
        shape = envelope(time, duration, 0.35, 0.42)
        samples.append(value / len(midis) * 0.13 * shape)
    return samples


def _flock_bell(midi: int, duration: float = 1.4) -> list[float]:
    frequency = note_frequency(midi)
    samples: list[float] = []
    for index in range(round(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        value = (
            math.sin(time * math.tau * frequency)
            + 0.48 * math.sin(time * math.tau * frequency * 2.73)
            + 0.23 * math.sin(time * math.tau * frequency * 4.08)
        )
        samples.append(value * 0.22 * math.exp(-time * 3.2) * envelope(time, duration, 0.004, 0.12))
    return samples


def _soft_frame_drum(duration: float = 0.34) -> list[float]:
    samples: list[float] = []
    rng = random.Random(811)
    phase = 0.0
    for index in range(round(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        frequency = 105.0 - time * 95.0
        phase += frequency / SAMPLE_RATE
        noise = rng.uniform(-1.0, 1.0) * math.exp(-time * 34.0)
        body = math.sin(phase * math.tau) * math.exp(-time * 12.0)
        samples.append((body * 0.34 + noise * 0.08) * envelope(time, duration, 0.003, 0.09))
    return samples


def make_music() -> None:
    beat = 60.0 / 80.0
    bars = 16
    duration = bars * 4 * beat
    length = round(duration * SAMPLE_RATE)
    left = [0.0] * length
    right = [0.0] * length
    chords = [
        [43, 50, 55, 59], [38, 45, 50, 54], [40, 47, 52, 55], [36, 43, 48, 52],
        [43, 50, 55, 59], [36, 43, 48, 52], [38, 45, 50, 54], [38, 45, 50, 54],
        [43, 50, 55, 59], [38, 45, 50, 54], [40, 47, 52, 55], [36, 43, 48, 52],
        [43, 50, 55, 59], [38, 45, 50, 54], [36, 43, 48, 52], [43, 50, 55, 59],
    ]
    arpeggio_order = [0, 2, 1, 2]
    drum = _soft_frame_drum()
    for bar, chord in enumerate(chords):
        bar_start = bar * 4 * beat
        _add_stereo(
            left,
            right,
            _warm_drone(chord[1:], 4 * beat),
            bar_start,
            0.52,
            -0.08 if bar % 2 else 0.08,
        )
        for beat_index, chord_index in enumerate(arpeggio_order):
            note = chord[chord_index + 1] + 12
            _add_stereo(
                left,
                right,
                _pluck(note, beat * 0.86, 4000 + bar * 8 + beat_index),
                bar_start + beat_index * beat,
                0.72,
                -0.42 if beat_index % 2 == 0 else 0.36,
            )
        for beat_index in (0, 2):
            _add_stereo(
                left,
                right,
                _pluck(chord[0], beat * 0.92, 6000 + bar * 2 + beat_index),
                bar_start + beat_index * beat,
                0.58,
                -0.12,
            )
        if bar % 2 == 0:
            _add_stereo(left, right, drum, bar_start, 0.40, 0.0)

    melody = [
        (0, 1.0, 67, 1.0), (0, 2.0, 69, 0.8), (0, 3.0, 71, 0.9),
        (1, 0.5, 74, 1.3), (1, 2.0, 71, 0.8), (1, 3.0, 69, 0.8),
        (2, 0.5, 67, 1.4), (2, 2.0, 64, 0.9), (2, 3.0, 67, 0.8),
        (3, 0.5, 69, 1.2), (3, 2.0, 67, 1.5),
        (4, 1.0, 71, 0.8), (4, 2.0, 74, 0.8), (4, 3.0, 76, 0.8),
        (5, 0.5, 74, 1.4), (5, 2.0, 71, 0.8), (5, 3.0, 69, 0.8),
        (6, 0.5, 67, 0.8), (6, 1.5, 69, 0.8), (6, 2.5, 71, 1.2),
        (7, 0.5, 69, 0.8), (7, 1.5, 67, 1.8),
        (8, 1.0, 67, 0.8), (8, 2.0, 71, 0.8), (8, 3.0, 74, 0.8),
        (9, 0.5, 76, 1.3), (9, 2.0, 74, 0.8), (9, 3.0, 71, 0.8),
        (10, 0.5, 69, 1.3), (10, 2.0, 67, 0.8), (10, 3.0, 64, 0.8),
        (11, 0.5, 67, 1.2), (11, 2.0, 69, 1.5),
        (12, 1.0, 71, 0.8), (12, 2.0, 74, 0.8), (12, 3.0, 76, 0.8),
        (13, 0.5, 74, 1.3), (13, 2.0, 71, 0.8), (13, 3.0, 69, 0.8),
        (14, 0.5, 67, 0.8), (14, 1.5, 69, 0.8), (14, 2.5, 71, 1.0),
        (15, 0.5, 69, 0.8), (15, 1.5, 67, 1.5),
    ]
    for event_index, (bar, beat_offset, midi, note_beats) in enumerate(melody):
        _add_stereo(
            left,
            right,
            _shepherd_flute(midi, note_beats * beat, 9000 + event_index),
            (bar * 4 + beat_offset) * beat,
            0.82,
            0.16,
        )
    for bar, beat_offset, midi, pan in [(3, 3.0, 79, -0.35), (7, 3.0, 74, 0.38), (11, 3.0, 79, -0.30), (15, 2.0, 74, 0.32)]:
        _add_stereo(left, right, _flock_bell(midi), (bar * 4 + beat_offset) * beat, 0.38, pan)
    write_wav("pasture_theme.wav", _finish_stereo(left, right, 0.76))


def _circular_blur(values: list[float], radius: int, passes: int = 1) -> list[float]:
    length = len(values)
    result = values
    for _pass in range(passes):
        window = radius * 2 + 1
        running = sum(result[index % length] for index in range(-radius, radius + 1))
        blurred = [0.0] * length
        for index in range(length):
            blurred[index] = running / window
            running += result[(index + radius + 1) % length]
            running -= result[(index - radius) % length]
        result = blurred
    return result


def _periodic_wind(length: int, seed: int, night: bool) -> tuple[list[float], list[float]]:
    rng = random.Random(seed)
    crossfade = SAMPLE_RATE
    source_length = length + crossfade
    raw_left = [rng.uniform(-1.0, 1.0) for _ in range(source_length)]
    raw_right = [rng.uniform(-1.0, 1.0) for _ in range(source_length)]
    breeze_left = _circular_blur(raw_left, 92 if night else 68, 2)
    breeze_right = _circular_blur(raw_right, 92 if night else 68, 2)
    rustle_left = _circular_blur(raw_left, 4, 2)
    rustle_right = _circular_blur(raw_right, 4, 2)
    source_left: list[float] = []
    source_right: list[float] = []
    for index in range(source_length):
        time = index / SAMPLE_RATE
        sway = 0.72 + 0.20 * math.sin(time * math.tau / 9.0) + 0.08 * math.sin(time * math.tau / 3.0)
        base_gain = 1.35 if night else 1.65
        rustle_gain = 0.032 if night else 0.050
        source_left.append(breeze_left[index] * base_gain * sway + rustle_left[index] * rustle_gain)
        source_right.append(breeze_right[index] * base_gain * sway + rustle_right[index] * rustle_gain)
    left = source_left[:length]
    right = source_right[:length]
    for index in range(crossfade):
        amount = index / (crossfade - 1)
        amount = amount * amount * (3.0 - 2.0 * amount)
        left[index] = source_left[length + index] * (1.0 - amount) + source_left[index] * amount
        right[index] = source_right[length + index] * (1.0 - amount) + source_right[index] * amount
    return left, right


def _bird_phrase(seed: int) -> list[float]:
    rng = random.Random(seed)
    duration = 0.78
    samples = [0.0] * round(duration * SAMPLE_RATE)
    for syllable, offset in enumerate((0.0, 0.19, 0.39, 0.57)):
        syllable_duration = 0.11 if syllable != 2 else 0.16
        phase = 0.0
        for index in range(round(syllable_duration * SAMPLE_RATE)):
            time = index / SAMPLE_RATE
            frequency = 1650.0 + syllable * 170.0 + 740.0 * time / syllable_duration
            frequency += 55.0 * math.sin(time * math.tau * 27.0) + rng.uniform(-7.0, 7.0)
            phase += frequency / SAMPLE_RATE
            target = round(offset * SAMPLE_RATE) + index
            samples[target] += math.sin(phase * math.tau) * 0.20 * envelope(time, syllable_duration, 0.012, 0.045)
    return samples


def _cricket_phrase(seed: int) -> list[float]:
    rng = random.Random(seed)
    duration = 1.2
    samples = [0.0] * round(duration * SAMPLE_RATE)
    for group in (0.0, 0.63):
        for pulse in range(5):
            offset = group + pulse * 0.075
            pulse_duration = 0.038
            phase = rng.random()
            for index in range(round(pulse_duration * SAMPLE_RATE)):
                time = index / SAMPLE_RATE
                phase += (3420.0 + rng.uniform(-18.0, 18.0)) / SAMPLE_RATE
                target = round(offset * SAMPLE_RATE) + index
                samples[target] += math.sin(phase * math.tau) * 0.12 * envelope(time, pulse_duration, 0.006, 0.012)
    return samples


def _owl_call() -> list[float]:
    duration = 1.75
    samples = [0.0] * round(duration * SAMPLE_RATE)
    for offset, frequency in ((0.0, 475.0), (0.82, 425.0)):
        hoot_duration = 0.62
        phase = 0.0
        for index in range(round(hoot_duration * SAMPLE_RATE)):
            time = index / SAMPLE_RATE
            phase += (frequency - time * 34.0) / SAMPLE_RATE
            target = round(offset * SAMPLE_RATE) + index
            samples[target] += (
                math.sin(phase * math.tau) + 0.22 * math.sin(phase * math.tau * 2.0)
            ) * 0.15 * envelope(time, hoot_duration, 0.10, 0.22)
    return samples


def _distant_bleat(seed: int) -> list[float]:
    rng = random.Random(seed)
    duration = 0.92
    samples: list[float] = []
    phase = 0.0
    for index in range(round(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        frequency = 205.0 + 24.0 * math.sin(time * math.tau * 7.2) - time * 32.0
        phase += frequency / SAMPLE_RATE
        voice = math.sin(phase * math.tau) + 0.34 * math.sin(phase * math.tau * 2.0 + 0.4)
        breath = rng.uniform(-1.0, 1.0) * 0.025
        samples.append((voice * 0.16 + breath) * envelope(time, duration, 0.10, 0.24))
    return samples


def make_ambience(name: str, night: bool) -> None:
    duration = 36.0
    length = round(duration * SAMPLE_RATE)
    left, right = _periodic_wind(length, 7301 if night else 4207, night)
    if night:
        for event_index, (start, pan) in enumerate(((2.8, -0.72), (7.6, 0.58), (14.4, -0.42), (21.8, 0.72), (29.6, -0.64))):
            _add_stereo(left, right, _cricket_phrase(1200 + event_index), start, 0.62, pan)
        _add_stereo(left, right, _owl_call(), 10.8, 0.46, -0.58)
        _add_stereo(left, right, _owl_call(), 26.4, 0.34, 0.66)
        _add_stereo(left, right, _flock_bell(72), 18.6, 0.10, -0.30)
    else:
        for event_index, (start, pan) in enumerate(((2.4, -0.68), (8.7, 0.54), (15.8, -0.35), (23.4, 0.72), (30.6, -0.58))):
            _add_stereo(left, right, _bird_phrase(2200 + event_index), start, 0.62, pan)
        _add_stereo(left, right, _distant_bleat(3101), 6.3, 0.22, 0.68)
        _add_stereo(left, right, _distant_bleat(3102), 25.7, 0.18, -0.62)
        for start, midi, pan in ((11.4, 76, -0.32), (19.8, 79, 0.46), (32.4, 74, -0.52)):
            _add_stereo(left, right, _flock_bell(midi), start, 0.16, pan)
    write_wav(name, _finish_stereo(left, right, 0.34 if night else 0.38))


def make_ui_click() -> None:
    """Create a short, bright wooden tap for UI button presses."""
    random.seed(20260714)
    duration = 0.085
    samples: list[float] = []
    previous_noise = 0.0

    for index in range(round(duration * SAMPLE_RATE)):
        time = index / SAMPLE_RATE

        # A tiny high-passed noise burst supplies the crisp initial contact.
        noise = random.uniform(-1.0, 1.0)
        high_passed_noise = noise - previous_noise
        previous_noise = noise
        contact = high_passed_noise * math.exp(-time * 150.0)

        # Inharmonic, fast-decaying partials read as a small wooden knock.
        body = (
            math.sin(math.tau * 1180.0 * time) * math.exp(-time * 54.0)
            + math.sin(math.tau * 1930.0 * time + 0.35) * math.exp(-time * 75.0) * 0.48
            + math.sin(math.tau * 3260.0 * time + 0.8) * math.exp(-time * 110.0) * 0.20
        )

        # Remove the digital edge at sample zero while keeping the attack immediate.
        attack = min(1.0, time / 0.0012)
        samples.append((contact * 0.24 + body * 0.38) * attack)

    peak = max(abs(sample) for sample in samples)
    write_wav("ui_click.wav", [sample * 0.72 / peak for sample in samples])


def make_sfx() -> None:
    write_wav("whistle.wav", render_tone(0.78, lambda t: 1120 + 680 * math.sin(min(1.0, t / 0.55) * math.pi), 0.34, "sine"))
    write_wav("sheep_bleat.wav", render_tone(0.68, lambda t: 245 + 34 * math.sin(t * 54) - 55 * t, 0.30, "triangle"))

    random.seed(931)
    bark: list[float] = []
    for index in range(round(0.34 * SAMPLE_RATE)):
        time = index / SAMPLE_RATE
        carrier = triangle(time * (185 - 65 * time))
        noise = random.uniform(-1.0, 1.0) * 0.28
        bark.append((carrier + noise) * 0.34 * envelope(time, 0.34, 0.008, 0.16))
    write_wav("dog_bark.wav", bark)

    gate_open = render_tone(0.34, lambda t: 210 - 95 * t, 0.22, "triangle")
    gate_close = mix(round(0.22 * SAMPLE_RATE), [
        (0, render_tone(0.13, 150, 0.30, "triangle"), 1.0),
        (round(0.09 * SAMPLE_RATE), render_tone(0.10, 82, 0.34, "sine"), 1.0),
    ])
    write_wav("gate_open.wav", gate_open)
    write_wav("gate_close.wav", gate_close)

    coin = mix(round(0.36 * SAMPLE_RATE), [
        (0, render_tone(0.16, 988, 0.27, "sine"), 1.0),
        (round(0.12 * SAMPLE_RATE), render_tone(0.22, 1480, 0.28, "sine"), 1.0),
    ])
    write_wav("coin.wav", coin)

    build = mix(round(0.48 * SAMPLE_RATE), [
        (0, render_tone(0.10, 125, 0.34, "triangle"), 1.0),
        (round(0.16 * SAMPLE_RATE), render_tone(0.12, 105, 0.31, "triangle"), 1.0),
        (round(0.31 * SAMPLE_RATE), render_tone(0.14, 82, 0.36, "triangle"), 1.0),
    ])
    write_wav("build.wav", build)

    treatment = mix(round(0.62 * SAMPLE_RATE), [
        (round(0.06 * SAMPLE_RATE), render_tone(0.22, 660, 0.18, "sine"), 1.0),
        (round(0.22 * SAMPLE_RATE), render_tone(0.24, 880, 0.20, "sine"), 1.0),
        (round(0.38 * SAMPLE_RATE), render_tone(0.24, 1320, 0.18, "sine"), 1.0),
    ])
    write_wav("treatment.wav", treatment)
    make_ui_click()
    write_wav("day_bell.wav", mix(round(0.9 * SAMPLE_RATE), [
        (0, render_tone(0.58, 784, 0.20, "sine"), 1.0),
        (round(0.20 * SAMPLE_RATE), render_tone(0.62, 1047, 0.18, "sine"), 1.0),
    ]))


def main() -> None:
    make_music()
    make_ambience("ambience_day.wav", False)
    make_ambience("ambience_night.wav", True)
    make_sfx()


if __name__ == "__main__":
    main()
