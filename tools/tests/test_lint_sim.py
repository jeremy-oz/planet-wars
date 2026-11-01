import lint_sim


def test_flags_unseeded_rng(tmp_path):
    f = tmp_path / "world.gd"
    f.write_text("func tick():\n\tvar x = randf()\n")
    problems = lint_sim.lint_file(f)
    assert len(problems) == 1
    assert "randf" in problems[0]


def test_allow_marker_suppresses(tmp_path):
    f = tmp_path / "world.gd"
    f.write_text("var rng := RandomNumberGenerator.new()\nrng.seed = seed_value  # lint: allow seed(\n")
    assert lint_sim.lint_file(f) == []


def test_clean_file_passes(tmp_path):
    f = tmp_path / "world.gd"
    f.write_text("func tick(dt: int) -> void:\n\tpass\n")
    assert lint_sim.lint_file(f) == []


def test_seeded_rng_methods_are_allowed(tmp_path):
    f = tmp_path / "bot.gd"
    f.write_text("var rng := RandomNumberGenerator.new()\nfunc pick():\n\treturn rng.randi_range(0, 3) + rng.randf()\n")
    assert lint_sim.lint_file(f) == []
