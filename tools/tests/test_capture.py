import capture


def test_stub_runs_and_creates_folder(tmp_path):
    out = tmp_path / "iter-9"
    assert capture.main(["--iteration", "9", "--out", str(out)]) == 0
    assert out.is_dir()
