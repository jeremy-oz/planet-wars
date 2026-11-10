import capture


def test_dry_run_plans_and_creates_folder(tmp_path):
    out = tmp_path / "iter-9"
    assert capture.main(["--iteration", "9", "--out", str(out), "--dry-run"]) == 0
    assert out.is_dir()
