import wave

import numpy as np

import make_audio


def test_builds_every_sound_and_pads_loop_seamlessly(tmp_path):
    assert make_audio.main(["--out", str(tmp_path)]) == 0
    names = {p.stem for p in tmp_path.glob("*.wav")}
    expected = {f"chime_{i}" for i in range(10)} | {
        "pad_calm", "pad_tense", "whoosh", "thud", "ui_click", "ui_hover", "select", "deny", "win", "lose"}
    assert names == expected
    for pad in ("pad_calm", "pad_tense"):
        with wave.open(str(tmp_path / f"{pad}.wav")) as w:
            assert w.getframerate() == make_audio.PAD_SR
            assert abs(w.getnframes() / w.getframerate() - make_audio.PAD_SECONDS) < 1e-3
            data = np.frombuffer(w.readframes(w.getnframes()), dtype="<i2").astype(float)
        # periodic signal: the jump from last sample back to the first is no bigger than a normal step
        step = np.max(np.abs(np.diff(data)))
        assert abs(data[0] - data[-1]) <= step * 1.5


def test_output_is_deterministic(tmp_path):
    a, b = tmp_path / "a", tmp_path / "b"
    make_audio.main(["--out", str(a)])
    make_audio.main(["--out", str(b)])
    for f in a.glob("*.wav"):
        assert f.read_bytes() == (b / f.name).read_bytes()
