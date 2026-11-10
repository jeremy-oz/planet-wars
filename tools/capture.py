#!/usr/bin/env python3
"""Capture screenshots of every screen and a 60-second recording for the UI review loop.

    uv run python capture.py --iteration 2

Writes docs/ui-reviews/iter-N/:
  screens/*.png      every screen, from the game's own `--capture-screens` walk
  game.mp4           60 s of a demo match (fake cursor plays the human seat), 1280 px wide
  frames/*.png       one frame every 5 s of the recording, for reviewers who cannot watch video
  frames.png         those frames as one contact sheet
  index.md           what is where
Raw Movie Maker output goes to raw/ (gitignored). Needs a display, Godot, and ffmpeg for the video.
"""
from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCREENS = ["main_menu", "training", "level_1", "setup", "settings", "game_start", "game_midgame", "pause", "victory", "defeat", "game_huge", "training_after_win"]
RECORD_SECONDS = 60
FPS = 30


def run(cmd: list[str], timeout: int) -> None:
    print("capture: $", " ".join(cmd))
    subprocess.run(cmd, check=True, timeout=timeout)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--iteration", "-n", type=int, required=True, help="iteration number, e.g. 2")
    parser.add_argument("--out", type=Path, default=None, help="override output directory")
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--dry-run", action="store_true", help="only print the plan")
    parser.add_argument("--skip-video", action="store_true")
    args = parser.parse_args(argv)

    out = args.out or REPO_ROOT / "docs" / "ui-reviews" / f"iter-{args.iteration}"
    out.mkdir(parents=True, exist_ok=True)
    print(f"capture: output folder {out}")
    print("capture: screens:", ", ".join(SCREENS))
    print(f"capture: recording: {RECORD_SECONDS} s demo match at {FPS} fps")
    if args.dry_run:
        return 0

    screens = out / "screens"
    raw = out / "raw"
    for d in (screens, raw):
        d.mkdir(parents=True, exist_ok=True)
    godot = [args.godot, "--path", str(REPO_ROOT), "--resolution", "1600x900"]
    run(godot + ["--", "--capture-screens", str(screens)], timeout=240)

    notes = []
    if not args.skip_video:
        avi = raw / "game.avi"
        run(godot + ["--write-movie", str(avi), "--fixed-fps", str(FPS), "--quit-after", str(RECORD_SECONDS * FPS), "--", "--demo"], timeout=900)
        if shutil.which("ffmpeg"):
            run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(avi), "-vf", "scale=1280:-2", "-c:v", "libx264",
                 "-pix_fmt", "yuv420p", "-crf", "27", "-preset", "veryfast", "-c:a", "aac", "-b:a", "96k", str(out / "game.mp4")], timeout=600)
            frames = out / "frames"
            frames.mkdir(exist_ok=True)
            for old in frames.glob("*.png"):
                old.unlink()
            run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(avi), "-vf", "fps=1/5,scale=960:-2", str(frames / "t%02d.png")], timeout=300)
            if shutil.which("magick"):
                run(["magick", "montage", *sorted(str(f) for f in frames.glob("t*.png")), "-tile", "3x", "-geometry", "640x360+4+4",
                     "-background", "#000", str(out / "frames.png")], timeout=120)
        else:
            notes.append("ffmpeg not found: raw AVI only, no mp4 or frames.")

    lines = [f"# UI review captures — iteration {args.iteration}", "",
             "| file | what |", "|---|---|"]
    for f in sorted(screens.glob("*.png")):
        lines.append(f"| screens/{f.name} | {f.stem.split('_', 1)[1].replace('_', ' ')} |")
    if (out / "game.mp4").exists():
        lines.append("| game.mp4 | 60 s demo match, a scripted cursor plays the blue seat through the real UI |")
        lines.append("| frames/ , frames.png | one frame every 5 s of that recording |")
    lines += ["", *notes]
    (out / "index.md").write_text("\n".join(lines) + "\n")
    print(f"capture: wrote {out / 'index.md'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
