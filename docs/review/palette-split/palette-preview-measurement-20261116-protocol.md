# Palette Map preview/cancellation — 2026-11-16

## Registration `palette-preview-20261116-v1`

Status: protocol registered before timing execution; executable only after both source SHAs, instrumentation digests and binary identities are bound in a retained execution manifest. No timing run has executed.

### Question and scope

FredApps requested a comparable current preview/cancellation measurement, not the historical withdrawn 3.0976x ratio or whole-process resource smoke. Compare published #8933 `974de089fef56d1542cb45f4d94e375dc935c1c3` with the fully rebased #8933 on main `6a82de14116499cca0df985a430bfdb5448085f6`. Freeze final candidate source SHA before running. Different upstream bases/shared CMS/renderer revisions are a confounder: this is an observed matched revision comparison, not causal attribution to a specific change. Main lacks Palette Map and is NOT a same-workload comparator.

Additionally compare identical final requests within each revision: isolated request versus final request following cancellation of actual stale rendering. This measures stale-work interference against the in-head isolated-final control.

### Fixed work and observables

- Real native `ensure_filter_preview` -> actual Worker thread -> cancellation-aware preview command -> flatten -> exact result acceptance/publication. No mock renderer, flag-waiting fake job or gate holding the renderer.
- Synthetic dense opaque RGB/U8 fixtures, 2048x1536 and6000x4000, deterministic source samples; source sample identities must match. Actual proxy k and resulting dimensions must be recorded and equal across revisions. Same tool colours/profile/settings/zoom.
- Fixed original Probe8 cube-corner palette snapshot; final Bayer mapping, seed7, consistent serialized settings. Stale Floyd–Steinberg mapping uses identical fixture and palette. Exact parameter JSON captured in executable manifest; no substitutions after execution.
- Three scenarios per fixture: isolated final request; actual stale render then changed-parameter request(s) ending with the same final mapping; close/cancel a dialog while real rendering runs. If a real job finishes before cancellation, record a race/non-cancel observation, never relabel as cancellation or gate work to manufacture it.
- Native 1ms polling is fixed for both revisions; include polling/scheduling in end-to-end request-to-accepted-result latency. This is CPU/headless egui preview acceptance, NOT first screen presentation, GPU upload, human interaction or input-to-display latency.
- Instrument compute start/end, first actual cancel request and end of worker task body; retain raw stamps. Cancellation completion means observed actual work/task exit plus result drain, not just a cancellation flag. Distinguish maximum active computations from short worker epilogues.
- Record maximum sampled synchronous ensure-call duration as a responsiveness diagnostic, not a percentile or frame-rate measurement.
- 30s explicit per-stage deadlines. Record timeout/failure before raising; no dropping observations.

### Environment, retention and execution

Same host/toolchain Rust1.95.0, release opt3/LTOoff/16codegen-units, CARGO_INCREMENTAL=0, debug0,4build jobs; CRAFT_FONTS_DIR fixed. Match RAYON_NUM_THREADS=8 and Linux CPU affinity0-7 (all allowed per initial affinity inspection). No overlapping local builds/tests/other benchmark during timing; record pre-run process snapshot and hardware.

Build fresh source-bound test executables using Cargo compiler-artifact JSON, verify expected source path and freshness, preserve old/new binaries separately with SHA256/size. Retain identical probe/instrumentation sources and their digests. Re-read this registration and validate actual manifest inputs before timing.

Run6alternating process pairs: trial0 old->new warmup excluded; retained trials1,3,5 new->old;2,4 old->new. Each process measures both fixtures and all three scenarios. Retain all12process outputs, nonzero statuses and failures. No pooling with historical Indexed brush probes or resource smokes.

### Estimators and decisions

For each revision/fixture/scenario report median of the5retained process observations. Compare candidate/published medians and absolute differences; also compute within-process burst-latest-ready minus isolated-final-ready then report its median (not difference of unpaired medians). Include exact counts of actually cancelled versus raced jobs.

Hard correctness conditions across ALL trials (including warmup): original session document pixels/mode/profile/table/revision/history unchanged; final isolated/burst native bytes equal within each process and across revisions (external SHA256 of retained native files); no stale result accepted for the latest Palette Map request; no preview published after dialog close; max active computations<=1; all actual worker tasks drained before case end. Failure/timeout or cross-version result difference => investigation required, not pass. Investigate genuine defects; changes to recipe/oracle require closing this run honestly and registering a new ID before measuring again.

Pre-run directional prediction: cancellation remains cooperative with max one computation, final outputs remain identical, and latest-frame latency is similar to isolated work plus cancellation/drain overhead. This is a prediction, not a result.

Timing investigation flags (diagnostic, NOT shipping budgets): candidate/published median request-to-ready, final-request-to-ready or cancel-to-task-exit exceeds1.10x AND adds>20ms; median cancel/close-to-task-exit>500ms; maximum sampled synchronous ensure-call>16ms. A threshold flag is reported even when correctness passes. Unflagged data does not establish zero overhead, Photoshop performance parity, a shipping budget or a speedup. No process RSS unless actually available/measured.

## Findings

Pending source-bound builds and execution. All outcomes will be appended with exact source/binary identities and raw output paths.

### Pre-execution oracle review — 2026-11-16

No timing run executed. Static review identified invalid published-result tuple assumptions,
unserialized optional JSON durations, cancel-event ordering, wrapper-start versus renderer-entry
confusion, undrained-timeout contamination, and incomplete effective-parameter recording.
The first compile-only preparation (bg_24) was cancelled before measurement while these were
corrected; it is not a passing build or performance observation.

Identical temporary engine feature `preview-probe` is authorized for BOTH comparison builds:
it exposes a non-gating observation inside actual Palette Map rendering, since engine
`cfg(test)` is not enabled when compiled as a UI-test dependency. The executable manifest must
record this feature and exact hook sources. It must not change default production behavior,
and all temporary hooks/features are removed before production publication. Observe and
label the precise entered renderer phase; do not infer that mapped pixels were processed
solely from wrapper entry. All fixtures, estimator, pairs, thresholds and retention rules
above remain unchanged. Full actual request JSON, not only palette/mapping fields, is retained.
