#!/usr/bin/env python3
"""Purity lint for `sim/`: the simulation must be deterministic and renderer-free.

Fails (exit 1) if any `.gd` file under sim/ mentions a forbidden API. The list is deliberately
blunt; add an `# lint: allow <token>` comment on the same line for a justified exception
(e.g. a seeded RandomNumberGenerator). Run via `make lint`.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SIM_DIR = REPO_ROOT / "sim"

# token -> why it is forbidden
FORBIDDEN: dict[str, str] = {
    r"\brandf\b": "global RNG is unseeded; use a seeded RandomNumberGenerator owned by the world",
    r"\brandi\b": "global RNG is unseeded",
    r"\brandf_range\b": "global RNG is unseeded",
    r"\brandi_range\b": "global RNG is unseeded",
    r"\brandomize\b": "seeds from the clock",
    r"\brand_from_seed\b": "fine in principle, but route it through the world's RNG",
    r"\bseed\(": "global seed() mutates process-wide state",
    r"\bTime\.": "wall clock / ticks make results time-dependent",
    r"\bOS\.": "OS access has no place in the sim",
    r"\bEngine\.": "engine state (fps, frames) must not leak into rules",
    r"\bInput\.": "input is the game's job, the sim only receives orders",
    r"\bNode2D\b|\bControl\b|\bSprite2D\b|\bCanvasItem\b": "sim code must not depend on scene nodes",
    r"\bget_tree\(": "sim code must not depend on the scene tree",
    r"\bawait\b": "asynchrony makes order of evaluation implicit",
    r"\bFileAccess\.": "sim does not do I/O; the map loader receives a String",
    r"\bprint\(": "use the ASCII renderer or return values; sim must be silent",
}
ALLOW_MARK = re.compile(r"#\s*lint:\s*allow\s+(\S+)")


def lint_file(path: Path) -> list[str]:
    problems: list[str] = []
    for lineno, line in enumerate(path.read_text(encoding="utf-8").splitlines(), start=1):
        code = line.split("#", 1)[0] if not ALLOW_MARK.search(line) else line
        allowed = ALLOW_MARK.search(line)
        for pattern, why in FORBIDDEN.items():
            if re.search(pattern, code):
                if allowed and re.search(pattern, allowed.group(1)):
                    continue
                token = re.search(pattern, code).group(0)
                problems.append(f"{_rel(path)}:{lineno}: `{token}` — {why}")
    return problems


def _rel(path: Path) -> str:
    try:
        return str(path.relative_to(REPO_ROOT))
    except ValueError:
        return str(path)


def main() -> int:
    if not SIM_DIR.exists():
        print("lint_sim: sim/ does not exist yet")
        return 0
    files = sorted(SIM_DIR.rglob("*.gd"))
    problems = [p for f in files for p in lint_file(f)]
    for p in problems:
        print(p)
    print(f"lint_sim: {len(files)} file(s), {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
