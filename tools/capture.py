#!/usr/bin/env python3
"""Capture screenshots of every screen and a 60-second recording for the UI review loop.

Stub for Iteration 0: parses arguments, creates the output folder, and explains what it will
do once there is a game to capture (Iteration 2). Exit code 0 so CI can wire it in now.

Planned implementation (Iteration 2):
  * launch the exported build with `--capture-screens <dir>`; the game walks its screen list and
    saves one PNG per screen via Viewport.get_texture().get_image()
  * record 60 s of a bot-vs-bot game with Godot's Movie Maker mode (`--write-movie`) and
    transcode to mp4 with ffmpeg
  * write `index.md` listing every file, so reviewer agents can be pointed at one folder
"""
from __future__ import annotations

import argparse
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCREENS = ["main_menu", "settings", "game", "pause", "win_lose"]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--iteration", "-n", type=int, required=True, help="iteration number, e.g. 2")
    parser.add_argument("--out", type=Path, default=None, help="override output directory")
    parser.add_argument("--dry-run", action="store_true", help="only print the plan (default until Iteration 2)")
    args = parser.parse_args(argv)

    out = args.out or REPO_ROOT / "docs" / "ui-reviews" / f"iter-{args.iteration}"
    out.mkdir(parents=True, exist_ok=True)
    print(f"capture: output folder {out}")
    print("capture: screens to capture:", ", ".join(SCREENS))
    print("capture: recording: 60 s bot-vs-bot game (Movie Maker mode)")
    print("capture: STUB — nothing captured yet; implemented in Iteration 2.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
