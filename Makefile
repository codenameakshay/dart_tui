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
VHS      := $(HOME)/go-packages/bin/vhs
FFMPEG   := $(HOME)/ffmpeg-local
DART     := fvm dart
TAPES    := $(wildcard example/tapes/*.tape)

.PHONY: help test analyze format run kernels run-fast bench gifs new-example clean

# ── Help ───────────────────────────────────────────────────────────────────────
help:
	@echo ""
	@echo "  dart_tui — Makefile targets"
	@echo ""
	@echo "  Development"
	@echo "    make test                    Run all unit tests"
	@echo "    make analyze                 Run dart analyze on lib/"
	@echo "    make format                  Run formatting"
	@echo "    make run EXAMPLE=foo         Run example/foo.dart (JIT source)"
	@echo "    make run-fast EXAMPLE=foo    Run tool/bin/foo.dill (kernel snapshot)"
	@echo ""
	@echo "  Build"
	@echo "    make kernels                 Compile all examples to kernel snapshots"
	@echo "    make kernel EXAMPLE=foo      Compile one example to kernel snapshot"
	@echo "    make clean                   Remove tool/bin/ build artifacts"
	@echo ""
	@echo "  Benchmark"
	@echo "    make bench EXAMPLE=foo       Startup benchmark (dill vs JIT)"
	@echo "    make bench-jit EXAMPLE=foo   Startup benchmark (JIT source only)"
	@echo ""
	@echo "  GIF recording (requires VHS + ffmpeg)"
	@echo "    make gifs                    Build all kernels then record all GIFs"
	@echo "    make gif EXAMPLE=foo         Record one GIF (builds kernel first)"
	@echo ""
	@echo "  Scaffolding"
	@echo "    make new-example NAME=foo    Create example/foo.dart from template"
	@echo ""

# ── Testing & analysis ─────────────────────────────────────────────────────────
test:
	$(DART) test

analyze:
	$(DART) analyze lib/

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

# ── GIF recording ──────────────────────────────────────────────────────────────
gifs: kernels
	@for tape in $(TAPES); do \
		echo "  recording $$tape ..."; \
		PATH=$(FFMPEG):$$PATH $(VHS) "$$tape"; \
	done

gif: tool/bin/$(EXAMPLE).dill
	PATH=$(FFMPEG):$$PATH $(VHS) example/tapes/$(EXAMPLE).tape

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
		"    options: const ProgramOptions(altScreen: true)," \
		"  ).run(_Model());" \
		"}" \
		"" \
		"final class _Model extends TeaModel {" \
		"  @override" \
		"  (TeaModel, Cmd?) update(Msg msg) {" \
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
	@echo "Record:   make gif EXAMPLE=$(NAME)  (after adding example/tapes/$(NAME).tape)"
