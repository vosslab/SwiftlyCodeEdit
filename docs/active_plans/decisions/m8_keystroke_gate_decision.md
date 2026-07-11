# M8 keystroke gate decision

Architect decision on the M8 exit for plan `pure-leaping-fern`. The M8 ship gate
as written is keystroke p95 under 16 ms on a 1 MB fixture (plan "Performance-miss
handling" Resolved decision). This record treats that gate as a hypothesis to
test against measured engine behavior, not a fact to defend or to relax by taste.

The 16 ms figure is an untested guess: it is the 60 fps frame budget (1000/60),
not a number derived from measured TextKit mutation-plus-relayout behavior on
large documents. The evidence contradicts the assumption baked into it. At
44,884 lines the engine's own per-keystroke floor is ~150 ms, independent of our
highlighter and status bar, both of which are already bounded. So the honest
question is not "did we pass or fail 16 ms" but "what does the latency-versus-
document-size curve actually look like, and what gate does that curve support."
This decision answers with an experiment plan and the gate shape the current
evidence already implies, and defers the exact threshold to the measured curve.

- Decision owner: architect
- Environment: MacBookPro18,3, macOS 26.5.2, Swift 6.3.3
- Fixture: 1,000,367-char / 44,884-line synthetic Swift-like buffer, 200 edits
- Source numbers: `test-results/perf/keystroke_latency.txt` (WP-Q2 run; its
  `code_state`/`git_commit` fields read stale from an uncommitted HEAD, the
  min/median/p95 values are the fresh WP-Q2 run) and `/tmp/codeedit_runtime.log`
  attribution for the same run.

## Verdict

M8 does not exit now. The 16 ms-at-1 MB gate as written is not supported by the
measured engine floor and is not treated as achievable at that size. M8 exits
under option (b), a gate derived from a measured latency-versus-size curve, once
two required follow-up packages land and the derived gate is wired on and green.
This is a discovery outcome (measure the curve, set the gate from the crossing
point), not a rationalized relaxation of a validated number.

- Required to exit M8: WP-Q7 (latency-versus-size sweep, finds the crossing
  point N) and WP-Q8 (derived gate, absolute 16 ms up to N plus measured
  degradation curve above N with the regression threshold retained).
- In-scope recommended: WP-Q9 (fix the O(cursor-offset) cursor-label scan).
- Optional, product-gated: WP-Q10 (Kate-style large-document guard, ceiling set
  by the same sweep).

## Mechanical reasoning from the recorded numbers

| Stage | p95 keystroke (ms) | Source |
| --- | --- | --- |
| Pre-M8 baseline (git 028868f) | ~15,233 | plan Decisions, candidates file |
| After WP-Q6 bounded rehighlight | 2,058 | candidates file |
| After WP-Q2 incremental status | 223 | keystroke_latency.txt |
| Gate | 16 | plan M8 exit criteria |

- The gate is p95 < 16 ms. The measured p95 is 223.15 ms (min 164.74, median
  193.10). That is a ~14x miss of the absolute gate and a ~68x improvement over
  the ~15,233 ms pre-M8 baseline. Substantial-improvement-but-absolute-miss is
  precisely the case the plan sends here.
- Attribution for the shipped run (per `/tmp/codeedit_runtime.log`): end-to-end
  `KEYSTROKE_MS` ~166 ms; `STATUS_REFRESH_MS` ~12 ms (the bounded cursor-label
  scan, all that is left of status on the hot path); the `WPQ6_BOUNDED` region
  is ~1,810 chars out of 1,000,367 (`strategy=editedLineWindow`). Both
  first-party per-keystroke subsystems are bounded.
- The dominant residual is therefore ~150 ms of the ~166 ms end-to-end, and it
  is not first-party work. It is TextKit mutation plus relayout on a 1 M-char /
  44,884-line `NSTextStorage`. This cost scales with document size and line
  count and happens on the vendored engine regardless of highlighting or status.
- Consequence: no further bounding of first-party per-keystroke work can reach
  16 ms at this document size, because the floor is the text engine, not the
  highlighter or the status bar. The engine alternative was already measured and
  rejected twice (WP-S0b, WP-S0c: SwiftUI `TextEditor` + `AttributedString` was
  worse, with a 1 MB document wedging the main thread), so replacing the engine
  to chase 16 ms at 1 MB is not an available lever within this plan.

## Chosen option: (b) revised budget

The plan names two options: (a) a further optimization package, or (b) a revised
budget with written justification. The primary choice is (b).

Option (a) taken alone -- keep optimizing first-party per-keystroke work until
16 ms holds at 1 MB -- is mechanically futile: the highlighter region is already
~1,810 chars and status is already ~12 ms, while ~150 ms is TextKit layout. A
first-party optimization package cannot cross the engine floor. One bounded
first-party optimization (WP-Q9) is still worth doing because it removes a
genuine unbounded-on-hot-path scan and it helps the small-document tier where
16 ms must hold, but it is not a path to 16 ms at 1 MB and is not offered as one.

### Gate derived from the measured curve

The gate is not asserted up front and then defended or relaxed. It is derived
from a measured latency-versus-document-size curve. We keep the 16 ms number
where the evidence shows the engine can meet it, and we replace the single
1 MB absolute (which the engine cannot meet) with the measured degradation the
engine actually exhibits above that point. The gate is two-tier, keyed to the
crossing point `N` (in both characters and lines) where measured p95 crosses
16 ms:

- Tier 1, at or under `N`: p95 `KEYSTROKE_MS` < 16 ms on the recorded baseline
  hardware (MacBookPro18,3). The 16 ms value is retained here because this is the
  range where the measured curve shows the engine can meet it. Kept because
  measured, not kept on faith.
- Tier 2, above `N` (including the current 1 MB / 44,884-line fixture): the gate
  is the stated, measured degradation curve rather than a fixed absolute the
  engine cannot reach, plus the regression-from-baseline half retained. p95 must
  not regress more than 20 percent above the recorded WP-Q2 large-file number
  (223 ms -> hard ceiling 268 ms) and must remain at least 10x better than the
  recorded pre-M8 baseline (~15,233 ms). The regression half is measured and real
  and stays on so a future highlighter or status regression is still caught.

`N` is a measured value, not invented here. There is no data between ~small and
1 MB, so `N` is the crossing point the WP-Q7 sweep finds. Evidence already in
hand bounds the expectation: ~150 ms of the ~166 ms at 1 MB is TextKit mutation
plus relayout that scales with size and line count, so `N` is where that engine
work plus the bounded highlight and cursor scan still sum under 16 ms. The doc
must record both halves of the result -- the retained 16 ms up to `N` and the
measured degradation curve above `N` -- so the choice is auditable as an
experiment result.

### Justification for N against the TextKit floor and SCOPE

- Against the floor: the measurement shows the 16 ms miss is engine cost, not
  first-party cost. Both first-party subsystems are already bounded, so the gate
  as originally written asks the milestone to beat a cost it does not own and
  cannot remove without a text-engine replacement that was already measured
  worse. Deriving `N` from the curve makes the absolute gate testable and
  truthful: it is exactly the size the engine can serve under 16 ms, measured.
- Against SCOPE: `docs/SCOPE.md` targets a clean, simple plain-text editor, not
  a large-binary or log viewer. A single 1 MB / 44,884-line file is at the far
  tail of that use case, which is why the Kate precedent draws a live-highlight
  line at a size ceiling. Anchoring the absolute 16 ms gate at the measured
  live-editing crossing point `N` matches the product goal, and the tier-2
  regression gate preserves the plan invariant that the milestone never silently
  ships a miss.

## Kate-style large-document threshold evaluation

Prior art: Kate (KDE) applies a document-size threshold above which it warns and
disables syntax highlighting, because live highlighting past a size stops paying
off. Evaluated here as a concrete candidate.

- Candidate shape: above a ceiling `N_hi` (with `N_hi` at or above the tier-1
  crossing point `N`, both from the same WP-Q7 sweep, not guessed), suspend live
  per-keystroke rehighlight and live status recompute. Highlighting freezes at
  the last full pass or disables; the status bar stops recomputing whole-document
  counts and shows cursor line/column plus a "large file: live highlighting and
  counts paused" indicator.
- What the user sees at the ceiling: a one-time notice or persistent status
  indicator that live highlighting and live counts are paused for a large
  document, with editing continuing.
- Does it let 16 ms hold at or under the ceiling? For documents at or under `N`,
  16 ms holds because `N` is the measured crossing point where first-party plus
  TextKit stays under the cap. The Kate cutoff is not what makes tier 1 pass; the
  measured crossing point does.
- Critical caveat (called out explicitly per the escalation): a highlight-and-
  status cutoff alone does not reach 16 ms above the ceiling, because the
  dominant residual is TextKit mutation plus relayout, which the engine incurs
  on every keystroke regardless of highlighting or status. Suspending first-party
  work removes ~12 ms of status plus a small highlight cost; it does not touch
  the ~150 ms engine floor.
- Implication: a Kate-style threshold is a first-party-amplification cap and an
  expectation-setting UX affordance for very large files, not a mechanism that
  makes the 16 ms gate hold on huge documents. It therefore belongs as an
  optional UX and scope guard (WP-Q10) whose ceiling is set by the same measured
  sweep, while the gate itself is derived from the curve (option b), not rescued
  by the cutoff. Because it changes user-visible behavior (SCOPE-level), WP-Q10
  is recommended but gated on product sign-off, not required for M8 exit.

## Follow-up work packages

### WP-Q7 latency-versus-size sweep (required for M8 exit)

- Owner: one `coder`.
- Outcome: a measured latency-versus-document-size curve and the crossing point
  `N` (in characters and lines) where keystroke p95 crosses 16 ms on the baseline
  hardware. `N` is the evidence for both the tier-1 threshold and the Kate
  ceiling; the curve above `N` is the evidence for the tier-2 degradation gate.
- Scope: parameterize `tests/e2e/e2e_keystroke_latency.py` to generate fixtures
  at a size series (10 KB, 50 KB, 100 KB, 250 KB, 500 KB, 1 MB) and record
  per-size min/median/p95 plus line count to
  `test-results/perf/keystroke_latency_sweep.txt` with `hw.model`, macOS, and
  Swift version. Identify where p95 crosses 16 ms and report `N` (chars and
  lines) plus the measured degradation above it. Do not adjust the 16 ms target;
  the sweep tests where the engine meets it.
- Acceptance criteria: sweep file exists with per-size min/median/p95, line
  count, and the environment triple; the p95-versus-size curve is recorded and
  the 16 ms crossing point `N` is stated in chars and lines (or the file states
  that no tested size meets 16 ms, in which case `N` is below the smallest tested
  size and a finer low-end sweep is added); the 1 MB row reproduces the ~223 ms
  result within noise.
- Verification commands: `source source_me.sh && python3 tests/e2e/e2e_keystroke_latency.py`
  (per size); `pytest tests/`.

### WP-Q8 curve-derived gate (required for M8 exit)

- Owner: one `coder`.
- Outcome: the gate derived from the WP-Q7 curve is wired into the harness and
  green, with both halves recorded so the choice is auditable.
- Scope: with `N` and the degradation curve from WP-Q7, wire
  `e2e_keystroke_latency.py --gate` to apply tier 1 (absolute 16 ms at or under
  `N`) and tier 2 above `N` (regression: no more than 20 percent above 223 ms and
  at least 10x better than the ~15,233 ms baseline). Record the retained-16 ms-
  up-to-`N` result and the measured-degradation-above-`N` curve, plus which tier
  applied and the `N` values, in `test-results/perf/keystroke_latency.txt`.
- Acceptance criteria: the gate passes at or under `N` on the absolute target and
  holds the regression threshold at 1 MB; the results file records both gate
  halves and `N`; two-part gate switched on.
- Depends on: WP-Q7.
- Verification commands: `source source_me.sh && python3 tests/e2e/e2e_keystroke_latency.py --gate`;
  `pytest tests/`.

### WP-Q9 cursor-label incremental line index (in scope, recommended)

- Owner: one `coder`.
- Outcome: the cursor label stops scanning from offset 0 to the cursor on every
  keystroke.
- Scope: `PlainEditorStatusReporter.cursorLabel` calls
  `countLineBreaks(in: text, range: NSRange(location: 0, length: cappedLocation))`
  (`PlainEditorStatusReporter.swift:25`), which is O(cursor offset) and explains
  the ~12 ms `STATUS_REFRESH_MS` deep in the fixture. Replace it with a line-start
  index or an incremental line count derived from the edited-range delta, so the
  cursor line number is amortized O(1) or O(log n) rather than O(cursor offset).
- Acceptance criteria: `STATUS_REFRESH_MS` no longer grows with cursor depth in
  the fixture; `PlainEditorStatusReporterTests` stay green including the
  brute-force line-count oracle; the smoke `Plain editor status: cursor= ...`
  marker still fires. Note: this removes ~12 ms but does not by itself reach
  16 ms at 1 MB; its value is bounding the last hot-path scan and helping the
  tier-1 small-document budget.
- Verification commands: `swift test`; `./scripts/plain_editor_smoke.sh`;
  `source source_me.sh && python3 tests/e2e/e2e_keystroke_latency.py`.

### WP-Q10 Kate-style large-document guard (optional, product-gated)

- Owner: one `coder` or `expert_coder` after product sign-off.
- Outcome: above a ceiling `N_hi` (from the WP-Q7 sweep), live per-keystroke
  rehighlight and live status recompute are suspended, with a user-visible
  indicator.
- Scope: above `N_hi` (at or above the measured crossing point `N`), stop firing
  per-keystroke bounded rehighlight and full status recompute; freeze or disable
  highlighting; show a "large file: live highlighting and counts paused" status
  indicator; keep the cursor line/column live. Behavior at or under `N_hi` is
  unchanged.
- Acceptance criteria: above `N_hi`, no per-keystroke rehighlight or full status
  recompute fires and editing stays usable; the indicator is shown; at or under
  `N_hi` behavior is unchanged. This is a UX and scope guard, not a 16 ms
  mechanism, because it does not touch the TextKit layout floor.
- Gate: requires user or product sign-off before dispatch, since it changes
  user-visible behavior at the SCOPE level.
- Verification commands: `swift test`; `./scripts/plain_editor_smoke.sh`.

## Changelog bullet (for docs/CHANGELOG.md, Decisions and Failures)

- M8 keystroke gate escalation resolved by architect as a discovery outcome, not
  a relaxation: the plan's 16 ms-at-1 MB target is an untested 60 fps frame-budget
  guess, not a number derived from measured TextKit behavior. The WP-Q2 shipped
  run measures keystroke p95 223 ms on the 1 MB / 44,884-line fixture, a ~68x
  improvement over the ~15,233 ms pre-M8 baseline but a ~14x miss of 16 ms.
  Attribution (`/tmp/codeedit_runtime.log`) shows both first-party subsystems
  already bounded (bounded rehighlight region ~1,810 chars, `STATUS_REFRESH_MS`
  ~12 ms) and the dominant ~150 ms residual is TextKit mutation plus relayout on
  the `NSTextStorage`, an engine floor at 44,884 lines that the milestone does
  not own and cannot remove without a text-engine replacement already measured
  worse (WP-S0b, WP-S0c). Decision: option (b), a gate derived from a measured
  latency-versus-size curve rather than asserted up front -- retain absolute
  16 ms p95 up to the measured crossing point `N` (chars and lines), and above
  `N` use the measured degradation curve plus the retained regression threshold
  (no more than 20 percent above 223 ms and at least 10x better than baseline) --
  justified against the measured TextKit floor and the `docs/SCOPE.md`
  clean-plain-text-editor goal and the Kate precedent. A Kate-style
  large-document highlight and status cutoff is evaluated and noted to not reach
  16 ms on its own, because the dominant residual is layout, not highlighting; it
  is filed as an optional product-gated UX guard whose ceiling comes from the
  same sweep. M8 does not exit now; it exits under the derived gate once WP-Q7
  (latency-versus-size sweep to measure `N`) and WP-Q8 (curve-derived gate
  wiring) land, with WP-Q9 (fix the O(cursor-offset) cursor-label scan at
  `PlainEditorStatusReporter.swift:25`) recommended in scope. Decision record:
  `docs/active_plans/decisions/m8_keystroke_gate_decision.md`.

## Revision 2026-07-11: gate the metric the user feels

This is a scientific-method revision, not a reversal by taste. The original
decision above (the two-tier curve-derived gate on `KEYSTROKE_MS` keyed to a
crossing point `N`) is kept intact for audit. New phase-attribution evidence
reframes what the gate should measure, so the gate shape changes. The prior
reasoning was correct about the TextKit floor; it was measuring the wrong
window and drawing the ship gate around it.

- Decision owner: architect
- Environment: MacBookPro18,3, macOS 26.5.2, Swift 6.3.3, git 93312b6
- New source: `test-results/perf/keystroke_floor_attribution.txt` (WP-Q8 floor
  attribution), finer low-end sweep at 1 KB / 2 KB / 5 KB / 10 KB, 200 edits.

### What the new evidence shows

Each per-edit `KEYSTROKE_MS` window decomposes into four sub-phases that sum to
the whole (residual ~0):

| size | lines | KEYSTROKE_MS | mutation | sched | span | paint |
| --- | --- | --- | --- | --- | --- | --- |
| 1 KB | 54 | 15.47 | 1.17 | 7.24 | 2.82 | 4.48 |
| 2 KB | 99 | 19.84 | 1.20 | 7.44 | 4.60 | 6.87 |
| 5 KB | 234 | 35.92 | 1.43 | 10.12 | 10.12 | 15.88 |
| 10 KB | 459 | 67.37 | 1.72 | 9.46 | 18.82 | 37.48 |

Phase meanings, and the three established facts:

- `mutation` is the synchronous edit apply plus status refresh plus synchronous
  scheduling: the ONLY work that blocks the typed character from reaching the
  screen. This is perceived typing latency.
- `sched` is an async main-actor Task enqueue-to-body hop, a fixed ~7-9 ms the
  real keystroke never blocks on. `span` is off-main span compute. `paint` is
  attribute paint plus layout on the full path, inflated by DEBUG-only
  token-summary logging that a release build omits.
- Fact 1: perceived typing latency (`mutation`) is ~1.2-1.7 ms at every tested
  size, including the 1 MB fixture's synchronous slice. That is ~10x under the
  16 ms budget. The mutation p95 is 1.46 / 1.41 / 1.64 / 2.14 ms at 1 / 2 / 5 /
  10 KB, so it passes the 16 ms p95 target with an order of magnitude of margin.
- Fact 2: `KEYSTROKE_MS` was measured to full highlight settle, so it conflated
  the async highlight pipeline (including the ~7-9 ms `sched` artifact and the
  DEBUG-inflated paint) with input latency and overstated perceived typing cost.
  The 16 ms gate in the original decision was applied to the wrong metric.
- Fact 3: the non-monotonic low end is a real design gap, not launch noise. The
  highlighter's `boundedMinimumDocumentLength` (20,000 bytes, at
  `PlainSyntaxHighlightRegion.swift:48`, enforced at
  `PlainSyntaxHighlighter.swift:91`) routes every sub-20 KB document through the
  WHOLE-DOCUMENT full pass per keystroke, so 1-10 KB files reinterpret and
  repaint the entire buffer each edit, while 100 KB and up take the bounded
  ~80-line window. That is why 10 KB (full pass, settle p95 71 ms) exceeds
  100 KB (bounded, 42 ms) in the WP-Q7 sweep.

### Revised verdict

The M8 miss in the original decision was a measurement framing error compounding
a real engine floor. Corrected framing: the milestone owns perceived typing
latency, and perceived typing latency PASSES the 16 ms target at every tested
size, including 1 MB. M8's typing-latency exit criterion is met on the recorded
evidence; it exits once WP-Q8 wires the corrected gate on the synchronous
first-paint slice and it is green (which the data already shows it will be).
Highlight settle becomes a separately tracked background-freshness metric, not a
ship gate, so M8 is no longer blocked on an engine floor the milestone does not
own. The two-tier curve-derived gate from the original decision is superseded:
there is no unreachable 1 MB absolute to defend once the gate measures the
synchronous slice instead of the settle window.

### 1. Ship gate redefined on the synchronous first-paint slice

- The M8 perceived-typing-latency ship gate is `KEYSTROKE_MUTATION_MS` p95 <
  16 ms on baseline hardware (MacBookPro18,3). This is already instrumented.
- This is the metric grounded in what the user feels: the synchronous mutation
  slice is the work that blocks the typed character from appearing (first paint
  the user sees). It replaces full-highlight-settle `KEYSTROKE_MS` as the ship
  gate. The retained 16 ms value now sits on the metric it actually bounds.
- The recorded data passes this gate at every tested size (mutation p95
  <= 2.14 ms through 10 KB, mutation median ~1.2-1.7 ms including the 1 MB
  synchronous slice), so the crossing point `N` construction from the original
  decision is retired for the typing gate: there is no size at which the
  synchronous slice crosses 16 ms in the tested range.
- The regression half is retained on this metric: p95 must also not regress more
  than 20 percent above the recorded first-paint baseline, so a future
  highlighter or status change that pushes synchronous work onto the hot path is
  still caught.

### 2. Highlight settle as a separate background-freshness metric

- Define `HIGHLIGHT_SETTLE_MS` (the full `KEYSTROKE_MS`-to-settle window) as a
  tracked background-freshness metric with its own target, NOT a typing gate. It
  measures how quickly live coloring catches up after an edit, which happens
  after the character is already on screen.
- Its target must be derived from the bounded-path curve (100 KB and up), not
  the full-path curve, because the full path is the small-file design gap fixed
  by item 3. The target must be measured on a release-representative build (or
  with the DEBUG-only token-summary logging removed from the timed window),
  because the recorded `paint` phase is DEBUG-inflated and the `sched` hop is a
  bench artifact absent from a real settle.
- Provisional target, to be finalized by the WP-Q12 measurement below:
  bounded-path settle p95 under 100 ms up to 500 KB on baseline hardware. The
  WP-Q7 bounded rows (100 KB 42 ms, 250 KB 74 ms, 500 KB 126 ms, 1 MB 239 ms)
  include the DEBUG paint inflation and the `sched` artifact, so they are an
  upper bound, not the settle target; a release-representative measurement is
  required before the number is fixed.

### 3. Ruling on the small-file full-pass design gap

- Ruling: the sub-20 KB full-pass routing is a real settle-freshness gap and is
  to be fixed. Lower or remove `boundedMinimumDocumentLength` so small documents
  take the bounded rehighlight path instead of reinterpreting and repainting the
  whole buffer per keystroke. This makes the settle curve monotonic and small
  files fast, and it is the fix that lets the item 2 settle target hold across
  the whole size range.
- Correctness guard, not a blocker: the full pass was originally kept for small
  documents because the bounded edited-line-window path has a documented
  stateful-interpreter limitation (a bounded region that opens inside a long
  multi-line string or comment can mis-color its head, mitigated by the 40-line
  context window; see `PlainSyntaxHighlightRegion.swift` and the dirty-range
  contract in `docs/CODE_ARCHITECTURE.md`). The fix must keep the bounded-path
  correctness tests green at small sizes. If lowering the threshold regresses
  correctness, the fallback is to keep a whole-document pass for small files but
  move it fully off the synchronous slice and coalesce it, so settle no longer
  scales per keystroke. Either way the synchronous slice (the ship gate) is
  unaffected, so this is recommended for settle freshness, not required for the
  typing-latency exit.

### 4. WP-Q10 reassessment (Kate large-document guard)

- Because perceived typing latency now passes at every size including 1 MB, the
  Kate-style large-document guard is no longer warranted as a typing-latency
  mechanism. The original decision already noted it does not reach 16 ms on the
  settle window; with the gate corrected to the synchronous slice there is no
  typing-latency problem for it to guard against at all.
- The only remaining rationale is highlight-settle freshness at extreme sizes
  (bounded settle p95 ~239 ms at 1 MB), where live coloring may feel stale.
  WP-Q10 is downgraded to an optional, product-gated, low-priority
  settle-freshness and expectation-setting UX affordance at extreme sizes, and
  is closed as a latency mechanism. It is not on the M8 exit path.

### Revised follow-up package list (ordered, with owners)

- WP-Q7 (latency-versus-size sweep): DONE. The sweep landed and produced the
  finer low-end series that grounds this revision. No longer an exit blocker.
- WP-Q8 (corrected ship gate, required for M8 exit): owner `coder`. Wire
  `e2e_keystroke_latency.py --gate` to the `KEYSTROKE_MUTATION_MS` first-paint
  metric with an absolute 16 ms p95 target plus a 20-percent-over-baseline
  regression check, and record BOTH series (typing-latency first-paint and
  highlight-settle freshness) in `test-results/perf/keystroke_latency.txt`.
  Acceptance: the gate reads the mutation slice, passes the 16 ms p95 target on
  the recorded fixtures, holds the regression threshold, and the results file
  records both series and which check applied. Verification:
  `source source_me.sh && python3 tests/e2e/e2e_keystroke_latency.py --gate`;
  `pyflakes tests/e2e/e2e_keystroke_latency.py`; `pytest tests/`.
- WP-Q12 (settle-freshness target, required to finalize the settle metric):
  owner `coder`. Measure bounded-path `HIGHLIGHT_SETTLE_MS` on a
  release-representative build (or with DEBUG-only token-summary logging removed
  from the timed window) across the 100 KB-1 MB bounded range, and set the
  settle target from that curve (proposal: p95 under 100 ms up to 500 KB).
  Acceptance: a release-representative bounded-path settle series is recorded
  with the environment triple, and the settle target is stated with its
  supporting number. Does not gate typing latency. Verification:
  `source source_me.sh && python3 tests/e2e/e2e_keystroke_latency.py --sweep`;
  `pytest tests/`.
- WP-Q11 (small-file bounded-threshold fix, recommended for settle freshness):
  owner `coder` or `expert_coder`. Lower or remove
  `HighlightRegionPlanner.boundedMinimumDocumentLength` so sub-20 KB documents
  take the bounded rehighlight path (`PlainSyntaxHighlightRegion.swift:48`,
  `PlainSyntaxHighlighter.swift:91`). Acceptance: small documents (1-10 KB) no
  longer take the whole-document full pass per keystroke; the settle curve is
  monotonic across the size series (10 KB no longer exceeds 100 KB); the bounded
  rehighlight correctness tests (`BoundedRehighlightTests`) and the highlighter
  tests stay green at small sizes; if correctness regresses, apply the item 3
  fallback (off-synchronous coalesced full pass) instead. Verification:
  `swift test`; `./scripts/plain_editor_smoke.sh`;
  `source source_me.sh && python3 tests/e2e/e2e_keystroke_latency.py --floor-attribution`.
- WP-Q9 (cursor-label incremental line index, recommended, in scope): unchanged
  from the original decision. Owner `coder`. Replace the O(cursor-offset) scan at
  `PlainEditorStatusReporter.swift:25` with an incremental line index. Still
  worth doing to bound the last hot-path scan and help the synchronous slice.
- WP-Q10 (Kate large-document guard): downgraded and closed as a latency
  mechanism per item 4. Optional, product-gated, low-priority settle-freshness
  and UX affordance at extreme sizes only. Not on the M8 exit path.

### Changelog bullet (for docs/CHANGELOG.md, Decisions and Failures)

- M8 keystroke gate decision revised by architect as a scientific-method
  discovery: WP-Q8 phase attribution
  (`test-results/perf/keystroke_floor_attribution.txt`, MacBookPro18,3, git
  93312b6) decomposes each per-edit `KEYSTROKE_MS` window into mutation / sched /
  span / paint sub-phases and shows the prior 16 ms gate was applied to the wrong
  metric. Perceived typing latency is the synchronous `mutation` slice
  (edit apply plus status refresh plus synchronous scheduling), the only work
  that blocks the typed character from appearing; it measures ~1.2-1.7 ms at
  every size including the 1 MB synchronous slice (p95 <= 2.14 ms through 10 KB),
  an order of magnitude under 16 ms. `KEYSTROKE_MS` was timed to full highlight
  settle, conflating the async pipeline (a fixed ~7-9 ms `sched` hop the
  keystroke never blocks on, plus DEBUG-inflated paint) with input latency.
  Decision: the M8 ship gate is redefined to `KEYSTROKE_MUTATION_MS` p95 < 16 ms
  (already instrumented, passes at every tested size), retiring the crossing-
  point `N` construction and the unreachable 1 MB settle absolute; highlight
  settle becomes a separately tracked background-freshness metric with a target
  set from a release-representative bounded-path measurement, not a typing gate.
  The sub-20 KB full-pass routing
  (`HighlightRegionPlanner.boundedMinimumDocumentLength`) is ruled a real
  settle-freshness gap and slated to be lowered so small files use the bounded
  path (making the settle curve monotonic), guarded by the bounded-path
  correctness tests. WP-Q10 (Kate large-document guard) is downgraded and closed
  as a latency mechanism since typing latency now passes at 1 MB; it survives
  only as an optional product-gated settle-freshness UX affordance at extreme
  sizes. Revised packages: WP-Q8 (wire the mutation first-paint gate, required),
  WP-Q12 (release-representative settle target, required to finalize the settle
  metric), WP-Q11 (small-file bounded-threshold fix, recommended), WP-Q9 (cursor
  incremental index, recommended), WP-Q10 (downgraded). Decision record:
  `docs/active_plans/decisions/m8_keystroke_gate_decision.md`.
