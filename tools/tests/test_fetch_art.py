"""fetch_art: the manifest is complete and credited, and the committed outputs match it."""

from pathlib import Path

import fetch_art

ROOT = Path(__file__).resolve().parents[2]


def test_every_source_has_credit_and_licence():
    ids = set()
    for s in fetch_art.MANIFEST:
        assert s.id not in ids, s.id
        ids.add(s.id)
        assert s.kind in ("body", "backdrop")
        assert s.credit and s.licence and s.url.startswith("https://")


def test_committed_art_matches_manifest():
    for s in fetch_art.MANIFEST:
        folder = "bodies" if s.kind == "body" else "backdrops"
        assert (ROOT / "game" / "art" / folder / f"{s.id}.jpg").exists(), s.id
    credits = (ROOT / "game" / "art" / "CREDITS.md").read_text()
    assert credits == fetch_art.credits_markdown(fetch_art.MANIFEST)


def test_game_body_list_matches_manifest():
    bodies_gd = (ROOT / "game" / "fx" / "bodies.gd").read_text()
    for s in fetch_art.MANIFEST:
        if s.kind == "body":
            assert f'"{s.id}"' in bodies_gd, f"{s.id} is fetched but the game never draws it"
