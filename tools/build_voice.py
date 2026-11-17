"""Build the announcer's lines from Kenney's "Voiceover Pack" (CC0 1.0).

Source: opengameart.org/content/voiceover-pack-40-lines (Kenney's own upload;
kenney.nl/assets/voiceover-pack is the same pack). Unzip it and pass the
folder that holds Male/ and Female/:

    python3 tools/build_voice.py --src tools/cache/voice/src --voice male

Writes godot/assets/voice/<lang>/<key>.ogg: silence trimmed, a high-pass
under the voice, loudness normalised so every line sits at the same level,
mono 44.1 kHz Vorbis. The keys are the ones Announcer.LINES uses; a line
from another language drops into its own folder under the same keys.
Needs ffmpeg on PATH.
"""
from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]

# Announcer key -> file name in the pack (without .ogg).
LINES = {
    "3": "3",
    "2": "2",
    "1": "1",
    "go": "go",
    "final_lap": "final_round",
    "power_up": "power_up",
    "look_out": "war_look_out",
    "target_destroyed": "war_target_destroyed",
    "you_win": "you_win",
    "you_lose": "you_lose",
    "congratulations": "congratulations",
    "new_record": "new_highscore",
    "hurry_up": "hurry_up",
    "time_over": "time_over",
    "tie": "its_a_tie",
}

FILTER = ",".join([
    # Trim leading and trailing silence (reverse trick for the tail).
    "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.02",
    "areverse",
    "silenceremove=start_periods=1:start_threshold=-45dB:start_silence=0.05",
    "areverse",
    "highpass=f=110",
    "loudnorm=I=-16:TP=-1.5:LRA=7",
])


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--src", required=True, type=Path)
    ap.add_argument("--voice", choices=["male", "female"], default="male")
    ap.add_argument("--lang", default="en")
    args = ap.parse_args()
    src = args.src / args.voice.capitalize()
    out = ROOT / "godot" / "assets" / "voice" / args.lang
    out.mkdir(parents=True, exist_ok=True)
    missing = [name for name in LINES.values() if not (src / f"{name}.ogg").exists()]
    if missing:
        sys.exit(f"missing in {src}: {', '.join(missing)}")
    for key, name in LINES.items():
        target = out / f"{key}.ogg"
        subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", str(src / f"{name}.ogg"), "-af", FILTER,
                        "-ac", "1", "-ar", "44100", "-c:a", "libvorbis", "-q:a", "5", str(target)], check=True)
        print(f"{key:18} <- {args.voice}/{name}.ogg")


if __name__ == "__main__":
    main()
