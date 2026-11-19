#!/bin/bash
# Live two-simulator run (Mac only). Injects LiveTwoSim.swift into the UI test file
# for the build, restores that file on exit, runs B (Grok Test 2) and A (Grok Test,
# owner) together, then scans the app logs. Live data is touched only through the
# app as the signed-in test users; A's games fixture is restored by the test itself.
#
# Env (defaults are the Mac mini's current sims):
#   ROOT   checkout root (default: two levels above this script)
#   OUT    log dir (default: $ROOT/logs/live)
#   DD     DerivedData (default: $ROOT-DerivedData)
#   SIM_A, SIM_B, SIM_D   simulator UDIDs (A owner, B member, D build destination)
#   LIVE_BASELINE_GAMES   "Call of Duty" (|-separated): A's games are set to exactly
#   LIVE_BASELINE_DEFAULT "Call of Duty"   these after every run, whatever they were
#   RUN_ID                unique per run (default: a timestamp); in every body and game name
#
# App logs come from inside each simulator (`xcrun simctl spawn <udid> log stream`),
# never the host's log command (which needs admin). The scan fails when a capture
# is missing, empty, errored, or its stream died during the run.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=${ROOT:-$(cd "$HERE/../.." && pwd)}
L=${OUT:-$ROOT/logs/live}
DD=${DD:-$ROOT-DerivedData}
A=${SIM_A:-88D51253-7571-4C5C-8450-2A9B7ECC0A42}
B=${SIM_B:-2EC8F61C-5A37-4C95-B9C9-79CA31522872}
D=${SIM_D:-80DEE5F2-AAC7-42BF-A2A1-4FA9EE62FF47}
SRC=$ROOT/app/SquadSyncUITests/AccessibilityUITests.swift
BASE_GAMES=${LIVE_BASELINE_GAMES:-Call of Duty}
BASE_DEFAULT=${LIVE_BASELINE_DEFAULT:-Call of Duty}
RUN_ID=${RUN_ID:-$(date '+%m%d-%H%M%S')}
ct() { date '+%I:%M:%S %p CT'; }
mkdir -p "$L"
echo "live start $(ct) run=$RUN_ID" | tee "$L/live.out"
printf '%s\n' "$RUN_ID" > "$L/run-id"

# Inject for this run only; put the tracked file back however the script ends.
cp "$SRC" "$L/AccessibilityUITests.swift.orig"
restore_src() { cp "$L/AccessibilityUITests.swift.orig" "$SRC"; }
PIDS=()
cleanup() {
  restore_src
  for p in "${PIDS[@]:-}"; do [ -n "$p" ] && kill "$p" 2>/dev/null || true; done
}
trap cleanup EXIT
if ! grep -q "final class LiveTwoSim" "$SRC"; then
  printf '\n' >> "$SRC"
  cat "$HERE/LiveTwoSim.swift" >> "$SRC"
  echo "injected LiveTwoSim (restored on exit)" | tee -a "$L/live.out"
fi

echo "rebuild start $(ct)" | tee -a "$L/live.out"
cd "$ROOT/app"
set +e
xcodebuild build-for-testing -project SquadSync.xcodeproj -scheme SquadSync \
  -destination "id=$D" -derivedDataPath "$DD" SWIFT_STRICT_CONCURRENCY=complete \
  > "$L/rebuild.log" 2>&1
REBUILD=$?
set -e
echo "rebuild exit $REBUILD $(ct)" | tee -a "$L/live.out"
if ! grep -q "TEST BUILD SUCCEEDED" "$L/rebuild.log"; then
  echo "REBUILD FAILED" | tee -a "$L/live.out"; tail -40 "$L/rebuild.log" >> "$L/live.out"; exit 1
fi
restore_src   # the build has it; the checkout goes back to the tracked file now

XR=$(ls "$DD"/Build/Products/*.xctestrun | head -1)
echo "xctestrun=$(basename "$XR")" | tee -a "$L/live.out"
find "$L" -maxdepth 1 \( -name 'flag-*' -o -name 'notes-*.txt' -o -name 'applog-*.txt' -o -name 'stream-*' \) -delete
# The teardown forces the baseline either way; this only reports an earlier miss.
[ -f "$L/fixture-games-a.json" ] && echo "an earlier run didn't verify its restore (before-run state: $(cat "$L/fixture-games-a.json")); this run forces the baseline" | tee -a "$L/live.out"

for s in "$A" "$B"; do
  xcrun simctl boot "$s" 2>/dev/null || true
  xcrun simctl ui "$s" content_size large >/dev/null 2>&1 || true
done
# Everything the app process logs (its own subsystem and the frameworks it drives),
# so a pass has a real trace to scan, not just "nothing failed".
PRED='process == "SquadSync" OR subsystem == "com.spencereese.squadsync"'
STREAMS=()
for side in A B; do
  udid=$([ "$side" = A ] && echo "$A" || echo "$B")
  xcrun simctl spawn "$udid" log stream --level debug --style compact --predicate "$PRED" > "$L/applog-$side.txt" 2>&1 &
  PIDS+=($!); STREAMS+=("$side:$!")
done
sleep 3
for s in "${STREAMS[@]}"; do
  kill -0 "${s#*:}" 2>/dev/null || echo "stream ${s%%:*} died at start: $(head -3 "$L/applog-${s%%:*}.txt")" | tee -a "$L/live.out"
done

run_test() { # sim name
  TEST_RUNNER_LIVE_DIR="$L" TEST_RUNNER_LIVE_RUN_ID="$RUN_ID" \
  TEST_RUNNER_LIVE_BASELINE_GAMES="$BASE_GAMES" TEST_RUNNER_LIVE_BASELINE_DEFAULT="$BASE_DEFAULT" \
  xcodebuild test-without-building -xctestrun "$XR" -destination "id=$1" \
    -only-testing:"SquadSyncUITests/LiveTwoSim/$2" -resultBundlePath "$L/$2.xcresult" > "$L/$2.log" 2>&1
}

echo "B start $(ct)" | tee -a "$L/live.out"
( run_test "$B" testLiveB; echo $? > "$L/exit-B" ) &
B_PID=$!
for _ in $(seq 1 90); do [ -f "$L/flag-b-ready" ] && break; sleep 1; done
echo "B ready=$([ -f "$L/flag-b-ready" ] && echo yes || echo no) $(ct)" | tee -a "$L/live.out"

echo "A start $(ct)" | tee -a "$L/live.out"
A_EXIT=0
run_test "$A" testLiveA || A_EXIT=$?      # a failed A no longer kills the script
echo "A exit $A_EXIT $(ct)" | tee -a "$L/live.out"
wait "$B_PID" || true
echo "B exit $(cat "$L/exit-B" 2>/dev/null || echo '?') $(ct)" | tee -a "$L/live.out"
sleep 2
# A stream that exited before now captured only part of the run.
for s in "${STREAMS[@]}"; do
  if kill -0 "${s#*:}" 2>/dev/null; then echo alive > "$L/stream-${s%%:*}"; else echo died > "$L/stream-${s%%:*}"; fi
done
for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null || true; done
PIDS=()
[ -f "$L/fixture-games-a.json" ] && echo "WARNING: A's games were NOT verified back to the baseline ($BASE_GAMES / default $BASE_DEFAULT)" | tee -a "$L/live.out"

python3 - "$L" <<'ENDSCAN' | tee -a "$L/live.out"
import re, sys
from pathlib import Path
root = Path(sys.argv[1])
# Expected zero in every stream. The app logs failures and probe answers (HTTPFailureLog),
# not successful requests, so zero means "none failed or probed", not a full HTTP trace.
CHECKS = {
    "steam":        lambda ln: "sq8-steam-presence" in ln,
    "leave":        lambda ln: "sq8_leave_squad" in ln,
    "rename":       lambda ln: "sq8_rename_squad" in ln,
    "pushTokenGET": lambda ln: "register_device_token" in ln and ("GET" in ln or "405" in ln or "probe" in ln.lower()),
    "nullUUID":     lambda ln: re.search(r"=(eq\.)?null\b|\"null\"", ln) is not None and "rpc/" in ln,
}
INFO = {
    "probe":  lambda ln: "probe HTTP" in ln or re.search(r"\bprobe ", ln) is not None,
    "http_E": lambda ln: re.search(r"(^|\s)E (GET|POST|PATCH|DELETE|HTTP)\b", ln) is not None,
}
ok = True
print("log scan (expect steam=0 leave=0 rename=0 pushTokenGET=0 nullUUID=0):")
# A capture that errored or never streamed is a failure, not a clean scan.
BROKEN = re.compile(r"Must be admin|Invalid predicate|Unable to|An error occurred|No such process|"
                    r"Invalid device|not booted|command not found|^log: |^error:", re.I)
MIN_LINES = 20
for side in ["A", "B"]:
    name = f"applog-{side}.txt"
    p = root / name
    if not p.exists():
        print(f"  {name}: missing"); ok = False; continue
    raw = p.read_text(errors="replace").splitlines()
    # Only the stream's own messages (no timestamp); an app entry may say "Unable to".
    broken = [ln for ln in raw if BROKEN.search(ln) and not re.match(r"^\d{4}-\d{2}-\d{2} ", ln)]
    lines = [ln for ln in raw if ln.strip() and not ln.startswith("Filtering the log data")]
    status = (root / f"stream-{side}").read_text().strip() if (root / f"stream-{side}").exists() else "unknown"
    if broken:
        ok = False
        for ln in broken[:5]: print(f"    CAPTURE ERROR: {ln[:300]}")
    if len(lines) < MIN_LINES:
        ok = False
        print(f"    CAPTURE EMPTY: {len(lines)} lines (need {MIN_LINES}); no trace to scan")
    if status != "alive":
        ok = False
        print(f"    CAPTURE STREAM {status}: it stopped before the run ended")
    counts = {k: [ln[:300] for ln in lines if f(ln)] for k, f in {**CHECKS, **INFO}.items()}
    print(f"  {name}: lines={len(lines)} " + " ".join(f"{k}={len(v)}" for k, v in counts.items()))
    for k in CHECKS:
        if counts[k]:
            ok = False
            for ln in counts[k][:10]: print(f"    {k.upper()}: {ln}")
    for k in INFO:
        for ln in counts[k][:10]: print(f"    {k}: {ln}")
print("flags:", sorted(p.name for p in root.glob("flag-*")))
print("SCAN", "PASS" if ok else "FAIL")
ENDSCAN

echo "LIVE_DONE A=$A_EXIT B=$(cat "$L/exit-B" 2>/dev/null || echo '?') $(ct)" | tee -a "$L/live.out"
