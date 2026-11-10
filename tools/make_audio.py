#!/usr/bin/env python3
"""Synthesise every sound in the game into game/audio/*.wav (docs/STYLE_GUIDE.md §6).

Deterministic: same code, same bytes. Everything musical is C major pentatonic so any overlap is
consonant. Run via `make audio`; the WAVs are committed so a fresh clone needs no Python to play.
"""
from __future__ import annotations

import argparse
import sys
import wave
from pathlib import Path

import numpy as np

SR = 44100
PAD_SR = 22050
PAD_SECONDS = 24.0
REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT = REPO_ROOT / "game" / "audio"

# chime_0..4: player captures (high octave), chime_5..9: everyone else (low octave).
# Within each octave index 0 is the lowest note, used for the biggest planets.
CHIME_MIDI = [72, 74, 76, 79, 81, 60, 62, 64, 67, 69]


def hz(midi: float) -> float:
    return 440.0 * 2.0 ** ((midi - 69) / 12.0)


def t_axis(seconds: float, sr: int = SR) -> np.ndarray:
    return np.arange(int(round(seconds * sr))) / sr


def normalize(y: np.ndarray, peak: float) -> np.ndarray:
    m = float(np.max(np.abs(y)))
    return y if m == 0 else y * (peak / m)


def one_pole_lowpass(x: np.ndarray, cutoff_hz: np.ndarray | float, sr: int = SR) -> np.ndarray:
    cut = np.broadcast_to(np.asarray(cutoff_hz, dtype=float), x.shape)
    a = 1.0 - np.exp(-2.0 * np.pi * cut / sr)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a[i] * (x[i] - acc)
        y[i] = acc
    return y


def bell(freq: float, seconds: float = 2.2, brightness: float = 1.0) -> np.ndarray:
    t = t_axis(seconds)
    partials = [(1.0, 1.0, 1.5), (2.0, 0.32, 0.8), (3.0, 0.12 * brightness, 0.45), (4.07, 0.06 * brightness, 0.3), (5.43, 0.03 * brightness, 0.18)]
    y = np.zeros_like(t)
    for ratio, amp, decay in partials:
        y += amp * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t / decay)
        y += 0.5 * amp * np.sin(2 * np.pi * freq * ratio * 1.0015 * t + 0.7) * np.exp(-t / decay)  # gentle chorus
    y *= np.minimum(1.0, t / 0.004)
    return y


def chime(midi: int, low: bool) -> np.ndarray:
    return normalize(bell(hz(midi), 2.2, 0.6 if low else 1.0), 0.55 if low else 0.7)


def pad(midis: list[int], seed: int, pulse_hz: float = 0.0) -> np.ndarray:
    """Seamless loop: every frequency completes a whole number of cycles in PAD_SECONDS."""
    rng = np.random.default_rng(seed)
    t = t_axis(PAD_SECONDS, PAD_SR)
    y = np.zeros_like(t)
    for m in midis:
        for detune in (-0.0035, 0.0, 0.004):
            f = round(hz(m) * (1.0 + detune) * PAD_SECONDS) / PAD_SECONDS
            ph = rng.uniform(0, 2 * np.pi)
            voice = np.sin(2 * np.pi * f * t + ph) + 0.16 * np.sin(4 * np.pi * f * t + ph) + 0.05 * np.sin(6 * np.pi * f * t + ph)
            swell_cycles = int(rng.integers(1, 4))
            swell = 0.55 + 0.45 * np.sin(2 * np.pi * swell_cycles / PAD_SECONDS * t + rng.uniform(0, 2 * np.pi))
            y += voice * swell / (1.0 + (m - 48) / 24.0)
    if pulse_hz > 0:
        cycles = round(pulse_hz * PAD_SECONDS)
        beat_phase = (t * cycles / PAD_SECONDS) % 1.0
        f = round(hz(45) * PAD_SECONDS) / PAD_SECONDS
        y += 2.2 * np.sin(2 * np.pi * f * t) * np.exp(-beat_phase / 0.18)
    return normalize(y, 0.33)


def whoosh() -> np.ndarray:
    rng = np.random.default_rng(7)
    t = t_axis(0.45)
    noise = rng.standard_normal(len(t))
    sweep = 500 + 2600 * np.sin(np.pi * np.minimum(t / 0.45, 1.0)) ** 2
    band = one_pole_lowpass(noise, sweep) - one_pole_lowpass(noise, sweep * 0.25)
    env = np.minimum(1.0, t / 0.07) * np.exp(-np.maximum(0.0, t - 0.07) / 0.12)
    return normalize(band * env, 0.5)


def thud() -> np.ndarray:
    rng = np.random.default_rng(11)
    t = t_axis(0.5)
    f = 45 + 70 * np.exp(-t / 0.08)
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.16)
    click = one_pole_lowpass(rng.standard_normal(len(t)), 1800.0) * np.exp(-t / 0.012)
    y = body + 0.35 * click
    y *= np.minimum(1.0, t / 0.002)
    return normalize(y, 0.6)


def blip(freq: float, decay: float, seconds: float, peak: float, second: float | None = None) -> np.ndarray:
    t = t_axis(seconds)
    y = np.sin(2 * np.pi * freq * t) + 0.18 * np.sin(4 * np.pi * freq * t)
    y *= np.minimum(1.0, t / 0.002) * np.exp(-t / decay)
    if second is not None:
        start = int(0.09 * SR)
        y2 = blip(second, decay, seconds - 0.09, 1.0)
        y[start:start + len(y2)] += y2[: len(y) - start]
    return normalize(y, peak)


def arpeggio(midis: list[int], spacing: float, seconds: float, low: bool) -> np.ndarray:
    out = np.zeros(int(seconds * SR))
    for i, m in enumerate(midis):
        note = bell(hz(m), seconds - i * spacing, 0.5 if low else 1.0) * (0.85 if low else 1.0)
        start = int(i * spacing * SR)
        out[start:start + len(note)] += note[: len(out) - start]
    return normalize(out, 0.6 if low else 0.7)


def build() -> dict[str, tuple[np.ndarray, int]]:
    sounds: dict[str, tuple[np.ndarray, int]] = {}
    for i, m in enumerate(CHIME_MIDI):
        sounds[f"chime_{i}"] = (chime(m, low=i >= 5), SR)
    sounds["pad_calm"] = (pad([48, 55, 60, 64, 67], seed=1), PAD_SR)
    sounds["pad_tense"] = (pad([45, 52, 57, 60, 62, 64], seed=2, pulse_hz=2.0), PAD_SR)
    sounds["whoosh"] = (whoosh(), SR)
    sounds["thud"] = (thud(), SR)
    sounds["ui_click"] = (blip(1320, 0.035, 0.12, 0.35), SR)
    sounds["ui_hover"] = (blip(990, 0.022, 0.08, 0.16), SR)
    sounds["select"] = (blip(hz(76), 0.06, 0.2, 0.3), SR)
    sounds["deny"] = (blip(hz(55), 0.05, 0.3, 0.35, second=hz(52)), SR)
    sounds["win"] = (arpeggio([72, 76, 79, 81, 84], 0.11, 2.6, low=False), SR)
    sounds["lose"] = (arpeggio([69, 67, 64, 60], 0.2, 2.8, low=True), SR)
    return sounds


def write_wav(path: Path, samples: np.ndarray, sr: int) -> None:
    pcm = (np.clip(samples, -1.0, 1.0) * 32767.0).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    args = parser.parse_args(argv)
    args.out.mkdir(parents=True, exist_ok=True)
    for name, (samples, sr) in build().items():
        write_wav(args.out / f"{name}.wav", samples, sr)
        print(f"make_audio: {name}.wav  {len(samples) / sr:.2f}s")
    return 0


if __name__ == "__main__":
    sys.exit(main())
