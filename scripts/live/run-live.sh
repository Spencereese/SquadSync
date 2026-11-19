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
#   LIVE_BASELINE_GAMES   "Call of Duty" (|-separated), used only if A reads back empty
#   LIVE_BASELINE_DEFAULT "Call of Duty"
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
ROOT=${ROOT:-$(cd "$HERE/../.." && pwd)}
L=${OUT:-$ROOT/logs/live}
DD=${DD:-$ROOT-DerivedData}
A=${SIM_A:-88D51253-7571-4C5C-8450-2A9B7ECC0A42}
B=${SIM_B:-2EC8F61C-5A37-4C95-B9C9-79CA31522872}
D=${SIM_D:-80DEE5F2-AAC7-42BF-A2A1-4FA9EE62FF47}
SRC=$ROOT/app/SquadSyncUITests/AccessibilityUITests.swift
LOG=/usr/bin/log   # zsh has a `log` builtin that shadowed this before
BASE_GAMES=${LIVE_BASELINE_GAMES:-Call of Duty}
BASE_DEFAULT=${LIVE_BASELINE_DEFAULT:-Call of Duty}
ct() { date '+%I:%M:%S %p CT'; }
mkdir -p "$L"
echo "live start $(ct)" | tee "$L/live.out"

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
find "$L" -maxdepth 1 \( -name 'flag-*' -o -name 'notes-*.txt' \) -delete
# fixture-games-a.json is kept on purpose: it's the snapshot from a run that didn't restore.
[ -f "$L/fixture-games-a.json" ] && echo "pending fixture from an earlier run: $(cat "$L/fixture-games-a.json")" | tee -a "$L/live.out"

for s in "$A" "$B"; do
  xcrun simctl boot "$s" 2>/dev/null || true
  xcrun simctl ui "$s" content_size large >/dev/null 2>&1 || true
done
PRED='subsystem == "com.spencereese.squadsync"'
xcrun simctl spawn "$A" "$LOG" stream --level debug --style compact --predicate "$PRED" > "$L/applog-A.txt" 2>&1 & PIDS+=($!)
xcrun simctl spawn "$B" "$LOG" stream --level debug --style compact --predicate "$PRED" > "$L/applog-B.txt" 2>&1 & PIDS+=($!)
"$LOG" stream --level debug --style compact --predicate "$PRED" > "$L/host-logstream.txt" 2>&1 & PIDS+=($!)
sleep 2

run_test() { # sim name
  TEST_RUNNER_LIVE_DIR="$L" \
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
for p in "${PIDS[@]}"; do kill "$p" 2>/dev/null || true; done
PIDS=()
[ -f "$L/fixture-games-a.json" ] && echo "WARNING: A's games fixture was NOT restored: $(cat "$L/fixture-games-a.json")" | tee -a "$L/live.out"

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
for name in ["applog-A.txt", "applog-B.txt", "host-logstream.txt"]:
    p = root / name
    if not p.exists():
        print(f"  {name}: missing"); ok = False; continue
    lines = p.read_text(errors="replace").splitlines()
    counts = {k: [ln[:300] for ln in lines if f(ln)] for k, f in {**CHECKS, **INFO}.items()}
    print(f"  {name}: lines={len(lines)} " + " ".join(f"{k}={len(v)}" for k, v in counts.items()))
    for k in CHECKS:
        if counts[k]:
            ok = False
            for ln in counts[k][:10]: print(f"    {k.upper()}: {ln}")
    for k in INFO:
        for ln in counts[k][:10]: print(f"    {k}: {ln}")
    if len(lines) < 20: print(f"    note: {name} is thin; absence is weak evidence")
print("flags:", sorted(p.name for p in root.glob("flag-*")))
print("SCAN", "PASS" if ok else "FAIL")
ENDSCAN

echo "LIVE_DONE A=$A_EXIT B=$(cat "$L/exit-B" 2>/dev/null || echo '?') $(ct)" | tee -a "$L/live.out"
