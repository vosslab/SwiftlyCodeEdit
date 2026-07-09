#!/usr/bin/env bash
set -euo pipefail

# Repeatable per-stage benchmark for the syntax-color pipeline. Runs the
# coldPassStaysUnderBudget Swift test (which times three cold passes over a
# generated ~1400-line Swift fixture and prints a HIGHLIGHT_BENCH totals line plus
# a HIGHLIGHT_BENCH_STAGES parse/interpret/span-map breakdown), then records the
# parsed timings to test-results/perf/highlight_cold_pass.txt in the same shape as
# test-results/perf/launch_time.txt. The per-stage numbers are the "ammeter"
# evidence for where the pass spends its time and what each optimization bought.

REPO_ROOT="$(git rev-parse --show-toplevel)"
PACKAGE_PATH="$REPO_ROOT/Packages/CodeEditSyntaxDefinitions"
RESULTS_DIR="$REPO_ROOT/test-results/perf"
OUTPUT_FILE="$RESULTS_DIR/highlight_cold_pass.txt"

mkdir -p "$RESULTS_DIR"

echo "Running Kate interpreter cold-pass benchmark (this builds and runs one Swift test)..."
BENCH_OUTPUT="$(swift test --package-path "$PACKAGE_PATH" --filter coldPassStaysUnderBudget 2>&1)"

# Totals line (grep -w avoids also matching the *_STAGES line).
BENCH_LINE="$(printf '%s\n' "$BENCH_OUTPUT" | grep -w 'HIGHLIGHT_BENCH' | tail -1 || true)"
STAGES_LINE="$(printf '%s\n' "$BENCH_OUTPUT" | grep -F 'HIGHLIGHT_BENCH_STAGES' | tail -1 || true)"
if [ -z "$BENCH_LINE" ] || [ -z "$STAGES_LINE" ]; then
  echo "Benchmark lines not found. Full test output follows:" >&2
  printf '%s\n' "$BENCH_OUTPUT" >&2
  exit 1
fi

fixture_lines="$(printf '%s' "$BENCH_LINE" | sed -n 's/.*lines=\([0-9]*\).*/\1/p')"
runs="$(printf '%s' "$BENCH_LINE" | sed -n 's/.*runs=\(\[[^]]*\]\).*/\1/p')"
min_ms="$(printf '%s' "$BENCH_LINE" | sed -n 's/.*min=\([0-9]*\).*/\1/p')"
median_ms="$(printf '%s' "$BENCH_LINE" | sed -n 's/.*median=\([0-9]*\).*/\1/p')"
max_ms="$(printf '%s' "$BENCH_LINE" | sed -n 's/.*max=\([0-9]*\).*/\1/p')"
model="$(printf '%s' "$BENCH_LINE" | sed -n 's/.*model=\([^ ]*\).*/\1/p')"

parse_ms="$(printf '%s' "$STAGES_LINE" | sed -n 's/.*parseMs=\([0-9]*\).*/\1/p')"
interpret_ms="$(printf '%s' "$STAGES_LINE" | sed -n 's/.*interpretMs=\([0-9]*\).*/\1/p')"
span_map_ms="$(printf '%s' "$STAGES_LINE" | sed -n 's/.*spanMapMs=\([0-9]*\).*/\1/p')"

{
  echo "hardware_model=$model"
  echo "fixture_lines=$fixture_lines"
  echo "runs_ms=$runs"
  echo "min_ms=$min_ms"
  echo "median_ms=$median_ms"
  echo "max_ms=$max_ms"
  echo "budget_median_ms=800"
  echo "stage_parse_ms=$parse_ms"
  echo "stage_interpret_ms=$interpret_ms"
  echo "stage_span_map_ms=$span_map_ms"
} > "$OUTPUT_FILE"

echo "Wrote $OUTPUT_FILE:"
printf '%s\n' "$BENCH_LINE"
printf '%s\n' "$STAGES_LINE"
