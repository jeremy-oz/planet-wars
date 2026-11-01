#!/usr/bin/env python3
"""Repo convention checks (exit 1 on any failure). Run via `make lint`."""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def check_changelog() -> list[str]:
    text = (REPO_ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    return [] if "## [Unreleased]" in text else ["CHANGELOG.md: missing '## [Unreleased]' section"]


def check_decisions() -> list[str]:
    """Every decision is one bullet line containing ' — ' (what — why)."""
    problems = []
    for lineno, line in enumerate((REPO_ROOT / "docs" / "decisions.md").read_text(encoding="utf-8").splitlines(), 1):
        if line.startswith("- ") and " — " not in line:
            problems.append(f"docs/decisions.md:{lineno}: decision has no ' — why' part")
    return problems


def check_gdscript_tabs() -> list[str]:
    problems = []
    for path in REPO_ROOT.rglob("*.gd"):
        if ".godot" in path.parts:
            continue
        for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
            if re.match(r"^ +\S", line) and not line.lstrip().startswith("#"):
                problems.append(f"{path.relative_to(REPO_ROOT)}:{lineno}: indented with spaces (GDScript uses tabs)")
                break
    return problems


def check_godot_version_pinned() -> list[str]:
    pinned = (REPO_ROOT / ".godot-version").read_text().strip()
    project = (REPO_ROOT / "project.godot").read_text()
    major_minor = ".".join(pinned.split(".")[:2])
    return [] if f'"{major_minor}"' in project else [f"project.godot features do not mention Godot {major_minor} (pinned {pinned})"]


def main() -> int:
    problems = check_changelog() + check_decisions() + check_gdscript_tabs() + check_godot_version_pinned()
    for p in problems:
        print(p)
    print(f"check_repo: {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
