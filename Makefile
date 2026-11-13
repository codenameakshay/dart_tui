# dart_tui — development commands
# Usage: make <target> [EXAMPLE=name] [NAME=name]
#
# Quick start:
#   make run EXAMPLE=simple       # run an example (JIT, slow first run)
#   make kernels                  # pre-compile all examples (~500ms startup)
#   make run-fast EXAMPLE=simple  # run from kernel snapshot
#   make gifs                     # re-record all GIF previews

.DEFAULT_GOAL := help
EXAMPLE ?= simple

# ── Paths ──────────────────────────────────────────────────────────────────────
# vhs and ffmpeg come from PATH. Override with VHS=/path/to/vhs or
# FFMPEG_DIR=/dir/containing/ffmpeg (prepended to PATH for recording).
VHS        ?= vhs
FFMPEG_DIR ?=
GIF_ENV    := $(if $(FFMPEG_DIR),PATH="$(FFMPEG_DIR):$$PATH")
DART     ?= dart
export DART
TAPES    := $(wildcard example/tapes/*.tape)

.PHONY: help test analyze format coverage run kernels run-fast bench bench-all gifs gif check-gif-tools tape new-example clean bench-hotpath bench-startup-pty

# ── Help ───────────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  dart_tui — Makefile targets"
	@echo ""
	@echo "  Development"
	@echo "    make test                    Run all unit tests"
	@echo "    make analyze                 Run dart analyze across the repository"
	@echo "    make format                  Run formatting"
	@echo "    make run EXAMPLE=foo         Run example/foo.dart (JIT source)"
	@echo "    make run-fast EXAMPLE=foo    Run tool/bin/foo.dill (kernel snapshot)"
	@echo "    DART='fvm dart' make test     Optional FVM launcher override"
	@echo ""
	@echo "  Build"
	@echo "    make kernels                 Compile all examples to kernel snapshots"
	@echo "    make kernel EXAMPLE=foo      Compile one example to kernel snapshot"
	@echo "    make clean                   Remove tool/bin/ build artifacts"
	@echo ""
	@echo "  Benchmark"
	@echo "    make bench EXAMPLE=foo       Startup benchmark (dill vs JIT)"
	@echo "    make bench-jit EXAMPLE=foo   Startup benchmark (JIT source only)"
	@echo "    make bench-all               Startup benchmark all kernel snapshots"
	@echo "    make bench-hotpath           Naive Dart vs dart_tui hot-path table"
	@echo "    make bench-startup-pty       First-visible-frame startup (PTY)"
	@echo ""
	@echo "  GIF recording (requires vhs + ffmpeg + ttyd on PATH)"
	@echo "    make gifs                    Build all kernels then record all GIFs"
	@echo "    make gif EXAMPLE=foo         Record one GIF (builds kernel first)"
	@echo "    make tape NAME=foo           Create example/tapes/foo.tape from simple.tape"
	@echo "    VHS=/path/to/vhs FFMPEG_DIR=/dir make gif   Override tool locations"
	@echo ""
	@echo "  Scaffolding"
	@echo "    make new-example NAME=foo    Create example/foo.dart from template"
	@echo ""

# ── Testing & analysis ─────────────────────────────────────────────────────────
# Unset NO_COLOR: outside a Program it switches every Style to no colour,
# and the suite pins true-colour output.
test:
	env -u NO_COLOR $(DART) test

analyze:
	$(DART) analyze

# Measure lib/ line coverage and fail below the floor (default 90%).
# Usage: make coverage [FLOOR=90]
FLOOR ?= 90
coverage:
	DART="$(DART)" bash tool/coverage.sh $(FLOOR)

format:
	$(DART) format .

# ── Running examples ───────────────────────────────────────────────────────────
run:
	$(DART) run example/$(EXAMPLE).dart

run-fast: tool/bin/$(EXAMPLE).dill
	$(DART) run tool/bin/$(EXAMPLE).dill

# ── Kernel snapshot build ──────────────────────────────────────────────────────
kernels:
	@bash tool/build.sh --kernel

kernel:
	@bash tool/build.sh --kernel example/$(EXAMPLE).dart

tool/bin/$(EXAMPLE).dill:
	@bash tool/build.sh --kernel example/$(EXAMPLE).dart

clean:
	rm -rf tool/bin/

# ── Benchmarking ───────────────────────────────────────────────────────────────
bench: tool/bin/$(EXAMPLE).dill
	$(DART) run tool/startup_bench.dart --dill tool/bin/$(EXAMPLE).dill

bench-jit:
	$(DART) run tool/startup_bench.dart example/$(EXAMPLE).dart

bench-all: kernels
	@echo ""
	@echo "Kernel snapshot startup times:"
	@for f in tool/bin/*.dill; do \
		name=$$(basename $$f .dill); \
		$(DART) run tool/startup_bench.dart --dill "$$f" 2>/dev/null | grep "median" | sed "s/^/  $$name: /"; \
	done

bench-hotpath:
	$(DART) run tool/hotpath_bench.dart

bench-startup-pty:
	python3 tool/bench_command.py -- dart run example/simple.dart

# ── GIF recording ──────────────────────────────────────────────────────────────
check-gif-tools:
	@command -v "$(VHS)" >/dev/null 2>&1 || { \
		echo "error: vhs not found: '$(VHS)'. Install it (https://github.com/charmbracelet/vhs) or set VHS=/path/to/vhs." >&2; \
		exit 1; \
	}
	@$(if $(FFMPEG_DIR),export PATH="$(FFMPEG_DIR):$$PATH";) command -v ffmpeg >/dev/null 2>&1 || { \
		echo "error: ffmpeg not found on PATH$(if $(FFMPEG_DIR), or in FFMPEG_DIR=$(FFMPEG_DIR)). Install ffmpeg or set FFMPEG_DIR=/dir/containing/ffmpeg." >&2; \
		exit 1; \
	}

gifs: check-gif-tools
	$(MAKE) kernels
	@for tape in $(TAPES); do \
		echo "  recording $$tape ..."; \
		$(GIF_ENV) "$(VHS)" "$$tape" || exit 1; \
	done

gif: check-gif-tools
	$(MAKE) tool/bin/$(EXAMPLE).dill
	$(GIF_ENV) "$(VHS)" example/tapes/$(EXAMPLE).tape

# Scaffold example/tapes/$(NAME).tape with simple.tape's settings.
tape:
	@if [ -z "$(NAME)" ]; then \
		echo "Usage: make tape NAME=my_feature" >&2; \
		exit 1; \
	fi
	@if [ ! -f "example/$(NAME).dart" ]; then \
		echo "example/$(NAME).dart does not exist (create it with make new-example NAME=$(NAME))" >&2; \
		exit 1; \
	fi
	@if [ -e "example/tapes/$(NAME).tape" ]; then \
		echo "example/tapes/$(NAME).tape already exists" >&2; \
		exit 1; \
	fi
	@sed -e 's|output/simple\.gif|output/$(NAME).gif|' \
		-e 's|tool/bin/simple\.dill|tool/bin/$(NAME).dill|' \
		example/tapes/simple.tape > example/tapes/$(NAME).tape
	@echo "Created example/tapes/$(NAME).tape"
	@echo "Record with: make gif EXAMPLE=$(NAME)"

# ── New example scaffold ───────────────────────────────────────────────────────
new-example:
	@if [ -z "$(NAME)" ]; then \
		echo "Usage: make new-example NAME=my_feature"; \
		exit 1; \
	fi
	@if [ -f "example/$(NAME).dart" ]; then \
		echo "example/$(NAME).dart already exists"; \
		exit 1; \
	fi
	@printf '%s\n' \
		"import 'package:dart_tui/dart_tui.dart';" \
		"" \
		"void main() async {" \
		"  await Program(" \
		"    options: [withAltScreen()]," \
		"  ).run(_Model());" \
		"}" \
		"" \
		"final class _Model extends Model {" \
		"  @override" \
		"  (Model, Cmd?) update(Msg msg) {" \
		"    if (msg is KeyMsg && (msg.key == 'q' || msg.key == 'ctrl+c')) {" \
		"      return (this, () => quit());" \
		"    }" \
		"    return (this, null);" \
		"  }" \
		"" \
		"  @override" \
		"  View view() {" \
		"    return newView(" \
		"      const Style(foregroundRgb: RgbColor(203, 166, 247), isBold: true)" \
		"          .render('$(NAME)\\n\\n') +" \
		"          const Style(foregroundRgb: RgbColor(108, 112, 134))" \
		"          .render('Press q to quit.')," \
		"    );" \
		"  }" \
		"}" \
		> example/$(NAME).dart
	@echo "Created example/$(NAME).dart"
	@echo "Run with: make run EXAMPLE=$(NAME)"
	@echo "Record:   make tape NAME=$(NAME) && make gif EXAMPLE=$(NAME)"
