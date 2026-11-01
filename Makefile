# Planet Wars — developer entry points. `make test` is what CI runs.
# Override the Godot binary with: make test GODOT=/path/to/godot

GODOT ?= godot
ITER  ?= 2
UV    ?= uv

.PHONY: help import test test-godot test-tools lint ci design clean

help:
	@echo "make test        run everything CI runs (import, lint, godot tests, tools tests)"
	@echo "make test-godot  headless GDScript tests only"
	@echo "make test-tools  python tooling tests only"
	@echo "make lint        sim purity lint + repo convention checks"
	@echo "make design      re-render the static design screens to docs/design/"
	@echo "make import      (re)import resources so a fresh clone has a .godot/ cache"
	@echo "make audio       re-synthesise game/audio/*.wav"
	@echo "make perf        200-planet frame-time report to docs/perf/ (needs a display)"
	@echo "make capture     UI review captures to docs/ui-reviews/iter-$$(ITER)/ (needs a display)"
	@echo "make clean       remove generated caches"

import:
	$(GODOT) --headless --path . --import --quit >/dev/null 2>&1

test-godot: import
	$(GODOT) --headless --path . -s tests/run_tests.gd

test-tools:
	cd tools && $(UV) run --quiet pytest -q

lint:
	cd tools && $(UV) run --quiet python lint_sim.py
	cd tools && $(UV) run --quiet python check_repo.py

test: lint test-godot test-tools

ci: test

design: import
	$(GODOT) --path . -s tools/snapshot.gd

clean:
	rm -rf .godot tools/.venv tools/.pytest_cache
	find . -name __pycache__ -type d -prune -exec rm -rf {} +

.PHONY: audio perf capture

audio:
	cd tools && $(UV) run --quiet python make_audio.py

perf: import
	$(GODOT) --path . --resolution 1600x900 -- --perf $(CURDIR)/docs/perf/iter-$(ITER).md

capture: import
	cd tools && $(UV) run --quiet python capture.py --iteration $(ITER)
