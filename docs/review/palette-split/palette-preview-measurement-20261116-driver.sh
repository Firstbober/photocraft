#!/usr/bin/env bash
# Registered driver palette-preview-20261116-v1: 6 pairs, trial 0 warmup excluded,
# retained 1..5 alternating (1,3,5 after->before; 2,4 before->after).
# Failures and timeouts are recorded and the run continues; no result is dropped.
set -uo pipefail
BEFORE=$1
AFTER=$2
RUNS=$3
BEFORE_OUT=$4
AFTER_OUT=$5
: > "$RUNS/exit-status.txt"
run() { # rev trial binary outdir
  local rev=$1 trial=$2 bin=$3 out=$4
  local log="$RUNS/trial-$trial-$rev.log"
  local t0 t1 rc
  t0=$(date +%s.%N)
  set +e
  PHOTOCRAFT_PREVIEW_PROBE_OUT="$out" TRIAL="$trial" RAYON_NUM_THREADS=8 \
    taskset -c 0-7 "$bin" palette_preview_resource_probe --ignored --nocapture --test-threads=1 \
    >"$log" 2>&1
  rc=$?
  set -e
  t1=$(date +%s.%N)
  printf '%s trial=%s exit=%s wall_s=%s log=%s\n' "$rev" "$trial" "$rc" "$(echo "$t1 $t0" | awk '{printf "%.1f", $1-$2}')" "$log" | tee -a "$RUNS/exit-status.txt"
  return 0
}
run before 0 "$BEFORE" "$BEFORE_OUT"
run after 0 "$AFTER" "$AFTER_OUT"
for trial in 1 3 5; do run after "$trial" "$AFTER" "$AFTER_OUT"; run before "$trial" "$BEFORE" "$BEFORE_OUT"; done
for trial in 2 4; do run before "$trial" "$BEFORE" "$BEFORE_OUT"; run after "$trial" "$AFTER" "$AFTER_OUT"; done
echo DRIVER_COMPLETE
