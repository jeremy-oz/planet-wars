"""Download the real space imagery the game uses, convert it to game textures, and write credits.

Sources are NASA (public domain), ESA/Webb and ESA/Hubble (CC BY 4.0), and Solar System Scope
(CC BY 4.0) where NASA has no map. Outputs are committed, so a fresh clone needs no network:

    uv run python fetch_art.py            # fetch (cached in tools/.cache/art) and convert
    uv run python fetch_art.py --list     # print the manifest

Bodies become 1024x512 equirectangular JPEGs in game/art/bodies/; backdrops become 2560 px wide
JPEGs in game/art/backdrops/; game/art/CREDITS.md lists every source with its credit and licence.
"""

from __future__ import annotations

import argparse
import sys
import urllib.parse
import urllib.request
from dataclasses import dataclass
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
CACHE = Path(__file__).resolve().parent / ".cache" / "art"
ART = ROOT / "game" / "art"
NASA_3D = "https://raw.githubusercontent.com/nasa/NASA-3D-Resources/master/Images%20and%20Textures/"
NASA_CREDIT = "NASA (NASA-3D-Resources)"
PD = "Public domain (NASA media guidelines)"
CC_BY = "CC BY 4.0"
UA = "planet-wars-tools/0.1 (local build tooling)"


@dataclass(frozen=True)
class Source:
    id: str
    kind: str  # "body" or "backdrop"
    name: str
    url: str
    credit: str
    licence: str


def nasa3d(folder: str) -> str:
    q = urllib.parse.quote(folder)
    return f"{NASA_3D}{q}/{q}.jpg"


def _body(id: str, name: str, folder: str) -> Source:
    return Source(id, "body", name, nasa3d(folder), NASA_CREDIT, PD)


MANIFEST: list[Source] = [
    Source("mercury", "body", "Mercury",
           "https://upload.wikimedia.org/wikipedia/commons/d/d3/Mercury_map_by_MESSENGER_global_mosaic_enhancedcolor_over_completebasemap.png",
           "NASA/Johns Hopkins University Applied Physics Laboratory/Carnegie Institution of Washington", PD),
    _body("venus", "Venus", "Venus"),
    _body("earth", "Earth", "Earth (A)"),
    Source("moon", "body", "Moon", "https://svs.gsfc.nasa.gov/vis/a000000/a004700/a004720/lroc_color_2k.jpg",
           "NASA's Scientific Visualization Studio (LRO / LROC WAC)", PD),
    _body("mars", "Mars", "Mars"),
    _body("phobos", "Phobos", "Mars - Phobos"),
    _body("jupiter", "Jupiter", "Jupiter"),
    _body("io", "Io", "Jupiter - Io (A)"),
    _body("europa", "Europa", "Jupiter - Europa"),
    _body("ganymede", "Ganymede", "Jupiter - Ganymede"),
    _body("callisto", "Callisto", "Jupiter - Callisto"),
    _body("saturn", "Saturn", "Saturn"),
    _body("rhea", "Rhea", "Saturn - Rhea"),
    _body("iapetus", "Iapetus", "Saturn - Iapetus"),
    Source("uranus", "body", "Uranus",
           "https://upload.wikimedia.org/wikipedia/commons/9/95/Solarsystemscope_texture_2k_uranus.jpg",
           "Solar System Scope (based on NASA imagery)", CC_BY),
    _body("neptune", "Neptune", "Neptune"),
    _body("pluto", "Pluto", "Pluto"),
    _body("charon", "Charon", "Pluto - Charon"),
    Source("cosmic-cliffs", "backdrop", "Cosmic Cliffs in Carina (Webb)",
           "https://cdn.esawebb.org/archives/images/large/weic2205a.jpg", "NASA, ESA, CSA, and STScI", CC_BY),
    Source("pillars-webb", "backdrop", "Pillars of Creation (Webb)",
           "https://cdn.esawebb.org/archives/images/large/weic2216a.jpg",
           "NASA, ESA, CSA, STScI; J. DePasquale, A. Koekemoer, A. Pagan (STScI)", CC_BY),
    Source("pillars-hubble", "backdrop", "Pillars of Creation (Hubble)",
           "https://cdn.esahubble.org/archives/images/large/heic1501a.jpg",
           "NASA, ESA/Hubble and the Hubble Heritage Team", CC_BY),
    Source("carina", "backdrop", "Carina Nebula (Hubble)",
           "https://cdn.esahubble.org/archives/images/large/heic0707a.jpg",
           "NASA, ESA, N. Smith (University of California, Berkeley), and The Hubble Heritage Team (STScI/AURA)", CC_BY),
    Source("whirlpool", "backdrop", "Whirlpool Galaxy M51 (Hubble)",
           "https://cdn.esahubble.org/archives/images/large/heic0506a.jpg",
           "NASA, ESA, S. Beckwith (STScI), and The Hubble Heritage Team (STScI/AURA)", CC_BY),
]

# Dropped after review: Ariel, Miranda, Triton (partial maps with unmapped black), Enceladus
# (blank fill), Titan (flat haze), and NASA-3D's Moon (a disc photo, not a map).
BODY_SIZE = (1024, 512)
BACKDROP_WIDTH = 2560


def fetch(src: Source) -> Path:
    CACHE.mkdir(parents=True, exist_ok=True)
    suffix = Path(urllib.parse.urlparse(src.url).path).suffix or ".jpg"
    path = CACHE / f"{src.id}{suffix}"
    if not path.exists():
        req = urllib.request.Request(src.url, headers={"User-Agent": UA})
        with urllib.request.urlopen(req, timeout=120) as r:
            path.write_bytes(r.read())
    return path


def convert(src: Source, raw: Path) -> Path:
    Image.MAX_IMAGE_PIXELS = None
    img = Image.open(raw).convert("RGB")
    if src.kind == "body":
        out = ART / "bodies" / f"{src.id}.jpg"
        img = img.resize(BODY_SIZE, Image.Resampling.LANCZOS)
        quality = 88
    else:
        out = ART / "backdrops" / f"{src.id}.jpg"
        if img.width > BACKDROP_WIDTH:
            img = img.resize((BACKDROP_WIDTH, round(img.height * BACKDROP_WIDTH / img.width)), Image.Resampling.LANCZOS)
        quality = 84
    out.parent.mkdir(parents=True, exist_ok=True)
    img.save(out, "JPEG", quality=quality, optimize=True, progressive=False)
    return out


def credits_markdown(manifest: list[Source]) -> str:
    lines = [
        "# Image credits",
        "",
        "Generated by `tools/fetch_art.py`. Every image in `game/art/` is a real photograph or map,",
        "resized for the game. NASA material is used under NASA's media guidelines (not copyrighted;",
        "no endorsement implied). ESA/Webb, ESA/Hubble and Solar System Scope images are CC BY 4.0.",
        "",
        "| File | Subject | Credit | Licence | Source |",
        "|---|---|---|---|---|",
    ]
    for s in manifest:
        folder = "bodies" if s.kind == "body" else "backdrops"
        lines.append(f"| `{folder}/{s.id}.jpg` | {s.name} | {s.credit} | {s.licence} | <{s.url}> |")
    return "\n".join(lines) + "\n"


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--list", action="store_true", help="print the manifest and exit")
    args = ap.parse_args(argv)
    if args.list:
        for s in MANIFEST:
            print(f"{s.kind:8} {s.id:15} {s.licence:40} {s.url}")
        return 0
    for s in MANIFEST:
        out = convert(s, fetch(s))
        print(f"{s.id:15} -> {out.relative_to(ROOT)} ({out.stat().st_size // 1024} KB)")
    (ART / "CREDITS.md").write_text(credits_markdown(MANIFEST))
    return 0


if __name__ == "__main__":
    sys.exit(main())
