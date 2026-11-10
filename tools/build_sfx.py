"""Build the game's sound effects from CC0 recordings and sound-design packs.

Sources (all CC0 1.0), unpacked into one directory passed as --src:

    sci-fi-sounds/      Kenney "Sci-Fi Sounds"      kenney.nl/assets/sci-fi-sounds
    impact-sounds/      Kenney "Impact Sounds"      kenney.nl/assets/impact-sounds
    interface-sounds/   Kenney "Interface Sounds"   kenney.nl/assets/interface-sounds
    oga/car_engine_loop_1.ogg, oga/car_engine_loop_2_0.ogg
                        GGBotNet "Car Sound Effects Pack (Low Quality)"
                        opengameart.org/content/car-sound-effects-pack-low-quality
    eng_5_0.wav         domasx2 "racing car engine sound loops"
                        opengameart.org/content/racing-car-engine-sound-loops
    oga/wind_woosh_loop_0.ogg
                        SketchMan3 "wind whoosh loop"
                        opengameart.org/content/wind-whoosh-loop

Tyre screech, wall scrape and rain stay procedural (tools/gen_sfx.py), and
wall_impact.wav is an existing recording that this script leaves alone.

    python tools/build_sfx.py --src /path/to/sources

Needs ffmpeg on PATH for decoding.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from gen_sfx import SR, env_ad, seamless, write_wav  # noqa: E402

rng = np.random.default_rng(11)
SRC = Path()


def load(rel: str) -> np.ndarray:
    path = SRC / rel
    if not path.exists():
        raise SystemExit(f"missing source: {path}")
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-ac", "1", "-ar", str(SR), "-f", "f32le", "-"],
                         capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype="<f4").astype(np.float64)


def sci(name: str) -> np.ndarray:
    return load(f"sci-fi-sounds/Audio/{name}.ogg")


def imp(name: str) -> np.ndarray:
    return load(f"impact-sounds/Audio/{name}.ogg")


def ui(name: str) -> np.ndarray:
    return load(f"interface-sounds/Audio/{name}.ogg")


def mix(*layers: tuple) -> np.ndarray:
    """Sum (samples, gain, delay_seconds) layers."""
    end = max(int(d * SR) + len(x) for x, _, d in layers)
    out = np.zeros(end)
    for x, gain, delay in layers:
        start = int(delay * SR)
        out[start:start + len(x)] += x * gain
    return out


def shape(x: np.ndarray, sec: float | None = None, attack: float = 0.0, release: float = 0.02) -> np.ndarray:
    """Cut to `sec` and fade the ends so nothing clicks."""
    if sec is not None:
        x = x[: int(sec * SR)]
    x = x.copy()
    a = int(attack * SR)
    r = min(int(release * SR), len(x))
    if a > 1:
        x[:a] *= np.linspace(0.0, 1.0, a)
    if r > 1:
        x[-r:] *= np.linspace(1.0, 0.0, r)
    return x


def peak(x: np.ndarray, level: float) -> np.ndarray:
    return x / (np.max(np.abs(x)) or 1.0) * level


def loudness(x: np.ndarray, rms: float) -> np.ndarray:
    """Match an RMS level, rounding off the few peaks that would clip."""
    x = x / (np.sqrt(np.mean(x ** 2)) or 1.0) * rms
    return np.tanh(x * 1.2) / 1.2


def tile(x: np.ndarray, n: int) -> np.ndarray:
    return np.tile(x, int(np.ceil(n / len(x))))[:n]


# ---------------------------------------------------------------------- loops
def engine_loop() -> np.ndarray:
    # A short real-engine cycle carries the pitch; a longer recording of the
    # same kind of engine sits under it so the repeat is not audible.
    cycle = load("eng_5_0.wav")
    body = tile(cycle, len(cycle) * 6)
    bed = load("oga/car_engine_loop_2_0.ogg")
    fade = 4096
    bed = seamless(bed[: len(body) + fade], fade)
    return loudness(body / np.sqrt(np.mean(body ** 2)) + 0.35 * bed / np.sqrt(np.mean(bed ** 2)), 0.25)


def engine_idle_loop() -> np.ndarray:
    return loudness(seamless(load("oga/car_engine_loop_1.ogg"), 4096), 0.25)


def wind_loop() -> np.ndarray:
    return loudness(seamless(load("oga/wind_woosh_loop_0.ogg"), 4096), 0.10)


# ------------------------------------------------------------------ one shots
def zap() -> np.ndarray:
    # Large discharge followed by a decaying crackle of short glitches.
    n = int(SR * 0.6)
    crackle = np.zeros(n)
    bursts = [ui(f"glitch_00{i}") for i in range(1, 5)]
    t = 0.03
    while t < 0.55:
        b = bursts[int(rng.integers(len(bursts)))]
        s = int(t * SR)
        seg = b[: n - s]
        crackle[s:s + len(seg)] += seg * np.exp(-t * 4.0)
        t += float(rng.uniform(0.012, 0.05))
    return mix((sci("laserLarge_002"), 1.0, 0.0), (peak(crackle, 0.7), 1.0, 0.0), (sci("forceField_002"), 0.35, 0.0))


def repair() -> np.ndarray:
    ratchet = [(ui("tick_004"), 0.7, 0.07 * i) for i in range(6)]
    return mix(*ratchet, (imp("impactMetal_light_002"), 0.4, 0.0), (ui("confirmation_002"), 1.0, 0.42))


def build() -> dict:
    thrust = sci("thrusterFire_001")
    n_nitro = int(SR * 1.6)
    nitro = thrust[:n_nitro] * env_ad(n_nitro, 0.05, 0.9)
    n_eagle = int(SR * 1.1)
    whoosh = sci("thrusterFire_003")[:n_eagle] * env_ad(n_eagle, 0.12, 0.4)
    return {
        "engine_loop": (engine_loop(), None, True),
        "engine_idle_loop": (engine_idle_loop(), None, True),
        "wind_loop": (wind_loop(), None, True),
        # collisions
        "impact_soft": (mix((imp("impactPunch_heavy_002"), 1.0, 0.0), (imp("impactMetal_medium_003"), 0.45, 0.0)), 0.45, False),
        "impact_hard": (mix((imp("impactPlate_heavy_000"), 1.0, 0.0), (imp("impactMetal_heavy_001"), 0.8, 0.0), (sci("impactMetal_003"), 0.7, 0.0)), 0.6, False),
        "wreck": (mix((imp("impactPlate_heavy_004"), 1.0, 0.0), (imp("impactGlass_heavy_001"), 0.7, 0.05), (sci("explosionCrunch_002"), 0.6, 0.02)), 0.7, False),
        "hop": (mix((imp("impactSoft_medium_001"), 1.0, 0.0), (imp("impactPunch_heavy_002"), 0.5, 0.0)), 0.8, False),
        # explosions
        "boom": (mix((sci("explosionCrunch_000"), 1.0, 0.0), (sci("lowFrequency_explosion_001"), 0.7, 0.0)), 0.95, False),
        "boom_big": (mix((sci("explosionCrunch_004"), 1.0, 0.0), (sci("lowFrequency_explosion_000"), 0.8, 0.0)), 0.95, False),
        # power-ups
        "zap": (zap(), 0.85, False),
        "fire_bolt": (mix((sci("laserSmall_002"), 1.0, 0.0), (sci("laserSmall_004"), 0.6, 0.0)), 0.8, False),
        "fire_eagle": (mix((sci("laserLarge_001"), 1.0, 0.0), (peak(whoosh, 0.6), 1.0, 0.0)), 0.85, False),
        "barge": (mix((sci("lowFrequency_explosion_001"), 1.0, 0.0), (imp("impactPunch_heavy_000"), 0.8, 0.0)), 0.95, False),
        "nitro": (mix((peak(nitro, 1.0), 1.0, 0.0), (sci("laserLarge_000"), 0.35, 0.0)), 0.85, False),
        "shield": (mix((sci("forceField_000"), 1.0, 0.0), (sci("forceField_002"), 0.6, 0.0)), 0.7, False),
        "repair": (repair(), 0.75, False),
        "mine_drop": (mix((ui("drop_004"), 1.0, 0.0), (imp("impactMetal_medium_000"), 0.5, 0.0)), 0.7, False),
        "pickup": (ui("confirmation_003"), 0.7, False),
        "denied": (ui("error_006"), 0.6, False),
        "respawn": (mix((ui("maximize_006"), 1.0, 0.0), (ui("maximize_002"), 0.4, 0.05)), 0.6, False),
        # race events and menus
        "beep": (ui("select_005"), 0.7, False),
        "go": (mix((ui("select_003"), 1.0, 0.0), (ui("confirmation_002"), 0.5, 0.0)), 0.7, False),
        "lap": (ui("confirmation_002"), 0.7, False),
        "finish": (mix((ui("confirmation_004"), 1.0, 0.0), (ui("confirmation_002"), 0.9, 0.3), (ui("glass_004"), 0.5, 0.55)), 0.8, False),
        "ui_click": (ui("click_001"), 0.5, False),
        "ui_back": (ui("back_002"), 0.5, False),
    }


def main() -> None:
    global SRC
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, help="directory holding the unpacked CC0 sources")
    SRC = Path(ap.parse_args().src)
    for name, (x, level, loop) in build().items():
        if not loop:
            x = peak(shape(x), level)
        write_wav(name, x, loop)
        print(f"{name:18s} {len(x) / SR:5.2f}s rms {np.sqrt(np.mean(x ** 2)):.3f} peak {np.max(np.abs(x)):.2f} {'loop' if loop else ''}")


if __name__ == "__main__":
    main()
