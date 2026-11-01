"""Procedural sound effects for Vortex (CC0, generated).

Writes 16-bit mono WAVs into godot/assets/sfx. Loops carry a 'smpl' chunk so
Godot's WAV importer picks up forward looping automatically.

    python tools/gen_sfx.py
"""
from __future__ import annotations

import os
import struct
import sys

import numpy as np

SR = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "godot", "assets", "sfx")
rng = np.random.default_rng(7)


def t_axis(sec: float) -> np.ndarray:
    return np.arange(int(SR * sec)) / SR


def env_ad(n: int, a: float, d: float, curve: float = 1.0) -> np.ndarray:
    t = np.arange(n) / SR
    e = np.minimum(t / max(a, 1e-4), 1.0) * np.exp(-np.maximum(t - a, 0) / max(d, 1e-4) * curve)
    return e


def lowpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    # one-pole IIR lowpass
    rc = 1.0 / (2 * np.pi * cutoff)
    a = (1.0 / SR) / (rc + 1.0 / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i in range(len(x)):
        acc += a * (x[i] - acc)
        y[i] = acc
    return y


def lowpass_fast(x: np.ndarray, cutoff: float) -> np.ndarray:
    from scipy.signal import butter, lfilter  # type: ignore

    b, a = butter(2, min(cutoff / (SR / 2), 0.99))
    return lfilter(b, a, x)


try:
    import scipy  # noqa: F401

    LP = lowpass_fast
except Exception:  # pragma: no cover
    LP = lowpass


def highpass(x: np.ndarray, cutoff: float) -> np.ndarray:
    return x - LP(x, cutoff)


def normalize(x: np.ndarray, peak: float = 0.9) -> np.ndarray:
    m = np.max(np.abs(x)) or 1.0
    return x / m * peak


def write_wav(name: str, x: np.ndarray, loop: bool = False) -> None:
    os.makedirs(OUT, exist_ok=True)
    x = np.clip(x, -1, 1)
    pcm = (x * 32767).astype("<i2").tobytes()
    chunks = []
    chunks.append(b"fmt " + struct.pack("<I", 16) + struct.pack("<HHIIHH", 1, 1, SR, SR * 2, 2, 16))
    chunks.append(b"data" + struct.pack("<I", len(pcm)) + pcm + (b"\x00" if len(pcm) % 2 else b""))
    if loop:
        n = len(x)
        smpl = struct.pack("<IIIIIIIII", 0, 0, int(1e9 / SR), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<IIIIII", 0, 0, 0, n - 1, 0, 0)
        chunks.append(b"smpl" + struct.pack("<I", len(smpl)) + smpl)
    body = b"WAVE" + b"".join(chunks)
    with open(os.path.join(OUT, name + ".wav"), "wb") as f:
        f.write(b"RIFF" + struct.pack("<I", len(body)) + body)


def seamless(x: np.ndarray, fade: int = 2048) -> np.ndarray:
    # crossfade the tail into the head so the loop is click free
    y = x.copy()
    w = np.linspace(0, 1, fade)
    y[:fade] = x[:fade] * w + x[-fade:] * (1 - w)
    return y[: len(x) - fade]


# ------------------------------------------------------------------ engine
def engine_loop(f0: float = 55.0, sec: float = 2.0, grit: float = 0.3) -> np.ndarray:
    n = int(SR * sec)
    # integer number of cycles so the loop is seamless
    cycles = round(f0 * sec)
    f = cycles / sec
    t = np.arange(n) / SR
    ph = 2 * np.pi * f * t
    x = np.zeros(n)
    for k, a in [(1, 1.0), (2, 0.55), (3, 0.35), (4, 0.22), (5, 0.14), (6, 0.1), (8, 0.06)]:
        x += a * np.sin(ph * k + 0.3 * k)
    # firing pulses (4 per revolution → v8 feel)
    pulse = np.exp(-((np.mod(ph * 2, 2 * np.pi)) ** 2) * 6.0)
    x += 0.8 * pulse
    noise = LP(rng.standard_normal(n), 900) * grit
    x = x + noise * (0.5 + 0.5 * pulse)
    x = LP(x, 2600)
    return normalize(x, 0.8)


def engine_idle_loop() -> np.ndarray:
    return engine_loop(32.0, 2.0, 0.45)


# ------------------------------------------------------------------ tyres
def screech_loop(sec: float = 1.5) -> np.ndarray:
    n = int(SR * sec)
    t = np.arange(n) / SR
    base = 1250 + 90 * np.sin(2 * np.pi * 7.3 * t) + 40 * np.sin(2 * np.pi * 23 * t)
    ph = np.cumsum(2 * np.pi * base / SR)
    x = np.sin(ph) + 0.5 * np.sin(2 * ph + 0.2) + 0.25 * np.sin(3 * ph)
    x *= 0.6 + 0.4 * np.sin(2 * np.pi * 31 * t)
    x += 0.5 * highpass(rng.standard_normal(n), 1800)
    x = LP(x, 5000)
    return seamless(normalize(x, 0.7))


def scrape_loop(sec: float = 1.2) -> np.ndarray:
    n = int(SR * sec)
    x = highpass(rng.standard_normal(n), 900)
    t = np.arange(n) / SR
    x *= 0.6 + 0.4 * np.sin(2 * np.pi * 47 * t) * np.sin(2 * np.pi * 3 * t)
    x += 0.4 * np.sin(np.cumsum(2 * np.pi * (3200 + 500 * np.sin(2 * np.pi * 9 * t)) / SR))
    return seamless(normalize(LP(x, 7000), 0.7))


def wind_loop(sec: float = 3.0) -> np.ndarray:
    n = int(SR * sec)
    x = LP(rng.standard_normal(n), 600)
    t = np.arange(n) / SR
    x *= 0.7 + 0.3 * np.sin(2 * np.pi * 0.7 * t)
    return seamless(normalize(x, 0.6))


def rain_loop(sec: float = 3.0) -> np.ndarray:
    n = int(SR * sec)
    x = highpass(rng.standard_normal(n), 2500) * 0.6 + LP(rng.standard_normal(n), 1200) * 0.4
    return seamless(normalize(x, 0.5))


# ------------------------------------------------------------------ one shots
def impact(hard: bool) -> np.ndarray:
    sec = 0.6 if hard else 0.35
    n = int(SR * sec)
    t = np.arange(n) / SR
    thump = np.sin(2 * np.pi * (70 if hard else 110) * t * np.exp(-t * 3)) * env_ad(n, 0.004, 0.12)
    crunch = highpass(rng.standard_normal(n), 400) * env_ad(n, 0.002, 0.06 if hard else 0.03)
    metal = sum(np.sin(2 * np.pi * f * t) * env_ad(n, 0.002, 0.15) * a for f, a in [(820, 0.3), (1340, 0.2), (2210, 0.12)])
    x = thump * 1.0 + crunch * (0.9 if hard else 0.6) + metal * (0.7 if hard else 0.3)
    return normalize(x, 0.95 if hard else 0.75)


def boom(big: bool) -> np.ndarray:
    sec = 1.4 if big else 0.9
    n = int(SR * sec)
    t = np.arange(n) / SR
    sub = np.sin(2 * np.pi * (45 if big else 70) * t * np.exp(-t * 1.5)) * env_ad(n, 0.005, 0.35)
    body = LP(rng.standard_normal(n), 900 if big else 1400) * env_ad(n, 0.003, 0.25 if big else 0.15)
    crack = highpass(rng.standard_normal(n), 2000) * env_ad(n, 0.001, 0.03)
    return normalize(sub * 1.1 + body + crack * 0.6, 0.95)


def zap() -> np.ndarray:
    n = int(SR * 0.7)
    t = np.arange(n) / SR
    f = 2400 * np.exp(-t * 4) + 300
    x = np.sign(np.sin(np.cumsum(2 * np.pi * f / SR))) * 0.5 + highpass(rng.standard_normal(n), 3000) * 0.7
    x *= env_ad(n, 0.002, 0.18)
    x *= 0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 55 * t))
    return normalize(x, 0.85)


def bolt_fire() -> np.ndarray:
    n = int(SR * 0.35)
    t = np.arange(n) / SR
    f = 1800 * np.exp(-t * 9) + 240
    x = np.sin(np.cumsum(2 * np.pi * f / SR)) * env_ad(n, 0.002, 0.08)
    x += highpass(rng.standard_normal(n), 2500) * env_ad(n, 0.001, 0.05) * 0.6
    return normalize(x, 0.8)


def eagle_fire() -> np.ndarray:
    n = int(SR * 1.1)
    t = np.arange(n) / SR
    whoosh = LP(rng.standard_normal(n), 400 + 3000 * np.minimum(t * 2, 1).mean()) * env_ad(n, 0.15, 0.4)
    # screech of the eagle
    f = 1600 + 500 * np.sin(2 * np.pi * 6 * t) * np.exp(-t * 2)
    cry = np.sin(np.cumsum(2 * np.pi * f / SR)) * env_ad(n, 0.05, 0.3) * 0.5
    cry += np.sin(np.cumsum(2 * np.pi * f * 2.01 / SR)) * env_ad(n, 0.05, 0.25) * 0.25
    return normalize(whoosh + cry, 0.85)


def barge() -> np.ndarray:
    n = int(SR * 1.0)
    t = np.arange(n) / SR
    rumble = LP(rng.standard_normal(n), 180) * env_ad(n, 0.02, 0.5)
    sub = np.sin(2 * np.pi * 38 * t) * env_ad(n, 0.01, 0.4)
    return normalize(rumble * 1.2 + sub, 0.95)


def nitro() -> np.ndarray:
    n = int(SR * 1.6)
    t = np.arange(n) / SR
    f = 200 + 900 * (1 - np.exp(-t * 3))
    x = LP(rng.standard_normal(n), 2500) * env_ad(n, 0.05, 0.9)
    x += 0.4 * np.sin(np.cumsum(2 * np.pi * f / SR)) * env_ad(n, 0.1, 0.8)
    return normalize(x, 0.85)


def shield() -> np.ndarray:
    n = int(SR * 0.9)
    t = np.arange(n) / SR
    x = sum(np.sin(2 * np.pi * f * t + i) * env_ad(n, 0.01 + 0.03 * i, 0.4) for i, f in enumerate([523.25, 659.25, 783.99, 1046.5]))
    x += 0.2 * np.sin(2 * np.pi * 130 * t) * env_ad(n, 0.01, 0.5)
    return normalize(x, 0.7)


def repair() -> np.ndarray:
    n = int(SR * 0.8)
    t = np.arange(n) / SR
    x = np.zeros(n)
    # ratchet clicks then a chime
    for i in range(6):
        s = int(SR * 0.07 * i)
        seg = highpass(rng.standard_normal(600), 2500) * env_ad(600, 0.001, 0.004)
        x[s : s + 600] += seg * 0.6
    chime = np.sin(2 * np.pi * 1318.5 * t) * env_ad(n, 0.42, 0.25) * (t > 0.42)
    return normalize(x + chime * 0.7, 0.75)


def pickup() -> np.ndarray:
    n = int(SR * 0.4)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * 880 * t) * env_ad(n, 0.005, 0.08)
    x += np.sin(2 * np.pi * 1320 * t) * env_ad(n, 0.08, 0.12) * (t > 0.08)
    return normalize(x, 0.7)


def denied() -> np.ndarray:
    n = int(SR * 0.35)
    t = np.arange(n) / SR
    x = np.sign(np.sin(2 * np.pi * 160 * t)) * env_ad(n, 0.005, 0.12) * 0.5
    x += np.sign(np.sin(2 * np.pi * 120 * t)) * env_ad(n, 0.12, 0.12) * (t > 0.12) * 0.5
    return normalize(LP(x, 1800), 0.6)


def beep(freq: float, sec: float) -> np.ndarray:
    n = int(SR * sec)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * freq * t) * env_ad(n, 0.005, sec * 0.5)
    x += 0.3 * np.sin(2 * np.pi * freq * 2 * t) * env_ad(n, 0.005, sec * 0.3)
    return normalize(x, 0.7)


def lap() -> np.ndarray:
    n = int(SR * 0.6)
    t = np.arange(n) / SR
    x = np.sin(2 * np.pi * 659.25 * t) * env_ad(n, 0.005, 0.1)
    x += np.sin(2 * np.pi * 987.77 * t) * env_ad(n, 0.12, 0.2) * (t > 0.12)
    return normalize(x, 0.7)


def finish() -> np.ndarray:
    n = int(SR * 1.8)
    t = np.arange(n) / SR
    x = np.zeros(n)
    for i, f in enumerate([523.25, 659.25, 783.99, 1046.5, 1318.5]):
        st = 0.12 * i
        x += np.sin(2 * np.pi * f * t) * env_ad(n, st + 0.01, 0.5) * (t > st)
    return normalize(x, 0.8)


def wreck() -> np.ndarray:
    x = boom(True)
    n = len(x)
    t = np.arange(n) / SR
    glass = highpass(rng.standard_normal(n), 4000) * env_ad(n, 0.01, 0.25) * 0.5
    return normalize(x + glass, 0.95)


def respawn() -> np.ndarray:
    n = int(SR * 0.7)
    t = np.arange(n) / SR
    f = 300 + 900 * t
    x = np.sin(np.cumsum(2 * np.pi * f / SR)) * env_ad(n, 0.02, 0.3)
    return normalize(x, 0.6)


def ui_click() -> np.ndarray:
    n = int(SR * 0.12)
    t = np.arange(n) / SR
    return normalize(np.sin(2 * np.pi * 1500 * t) * env_ad(n, 0.002, 0.02) + highpass(rng.standard_normal(n), 3000) * env_ad(n, 0.001, 0.01) * 0.4, 0.5)


def ui_back() -> np.ndarray:
    n = int(SR * 0.15)
    t = np.arange(n) / SR
    return normalize(np.sin(2 * np.pi * 700 * t) * env_ad(n, 0.002, 0.04), 0.5)


def mine_drop() -> np.ndarray:
    n = int(SR * 0.3)
    t = np.arange(n) / SR
    return normalize(np.sin(2 * np.pi * 220 * t * np.exp(-t * 2)) * env_ad(n, 0.003, 0.08) + LP(rng.standard_normal(n), 800) * env_ad(n, 0.002, 0.05) * 0.5, 0.7)


def hop() -> np.ndarray:
    n = int(SR * 0.4)
    t = np.arange(n) / SR
    return normalize(LP(rng.standard_normal(n), 500) * env_ad(n, 0.003, 0.1) + np.sin(2 * np.pi * 90 * t) * env_ad(n, 0.003, 0.15), 0.8)


def main() -> None:
    items = {
        "engine_loop": (engine_loop(), True),
        "engine_idle_loop": (engine_idle_loop(), True),
        "screech_loop": (screech_loop(), True),
        "scrape_loop": (scrape_loop(), True),
        "wind_loop": (wind_loop(), True),
        "rain_loop": (rain_loop(), True),
        "impact_soft": (impact(False), False),
        "impact_hard": (impact(True), False),
        "boom": (boom(False), False),
        "boom_big": (boom(True), False),
        "zap": (zap(), False),
        "fire_bolt": (bolt_fire(), False),
        "fire_eagle": (eagle_fire(), False),
        "barge": (barge(), False),
        "nitro": (nitro(), False),
        "shield": (shield(), False),
        "repair": (repair(), False),
        "pickup": (pickup(), False),
        "denied": (denied(), False),
        "beep": (beep(880, 0.25), False),
        "go": (beep(1320, 0.6), False),
        "lap": (lap(), False),
        "finish": (finish(), False),
        "wreck": (wreck(), False),
        "respawn": (respawn(), False),
        "ui_click": (ui_click(), False),
        "ui_back": (ui_back(), False),
        "mine_drop": (mine_drop(), False),
        "hop": (hop(), False),
    }
    for name, (x, loop) in items.items():
        write_wav(name, x, loop)
        print(f"{name:18s} {len(x) / SR:5.2f}s {'loop' if loop else ''}")


if __name__ == "__main__":
    sys.exit(main())
