#!/bin/bash
# Replays Wi-Fi state sequences through the watcher with a simulated clock and checks what it
# logs. Touches nothing real: no pmset, no networksetup, settings in a temp folder.
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
TM="$ROOT/src/bin/travel-mode"
pass=0; fail=0

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

run() { # $1 = name, $2 = comma list of Wi-Fi states (one per 10 s check)
  local dir="$TMP/$1"; mkdir -p "$dir"
  local n; n=$(echo "$2" | awk -F, '{print NF}')
  TM_TEST=1 TM_TEST_WIFI="$2" TM_TEST_TICKS=$((n * 5)) TM_CONF_DIR="$dir" TM_LOG="$dir/log" "$TM" _watch
  LOGFILE="$dir/log"
}

ok() { if eval "$2"; then pass=$((pass + 1)); echo "  ok   $1"; else fail=$((fail + 1)); echo "  FAIL $1"; fi; }

check() { # $1 = description, $2 = expected count, $3 = pattern
  local got; got=$(grep -c -- "$3" "$LOGFILE" 2>/dev/null || true); got=${got:-0}
  if [ "$got" = "$2" ]; then pass=$((pass + 1)); echo "  ok   $1"
  else fail=$((fail + 1)); echo "  FAIL $1 (expected $2, got $got)"; sed 's/^/       | /' "$LOGFILE" 2>/dev/null; fi
}

seq_of() { local out="" i; for i in $(seq 1 "$2"); do out="$out,$1"; done; echo "${out#,}"; }

echo "1. Hotspot drops, then macOS rejoins it after 5 minutes"
run drop "hotspot,hotspot,$(seq_of none 30),hotspot"
check "logs the disconnect once"           1 "Wi-Fi disconnected (was: hotspot)"
check "logs the recovery and how long"     1 "back on the hotspot after 300 s"
check "never tries to join anything"       0 "join"
check "nothing else in the log"            2 "."

echo "2. Long outage: one line, not one per check"
run long "hotspot,$(seq_of none 60)"
check "logs the disconnect once"           1 "Wi-Fi disconnected"
check "nothing else in the log"            1 "."

echo "3. Hotspot drops and macOS picks another saved network"
run other "hotspot,none,none,other,other"
check "logs the disconnect"                1 "Wi-Fi disconnected (was: hotspot)"
check "logs the other network"             1 "now on: other"

echo "4. User turns Wi-Fi off"
run off "hotspot,off,off,off"
check "logs it once"                       1 "now on: off"

echo "5. User joins the hotspot later from the Wi-Fi menu"
run later "other,other,hotspot"
check "logs the switch"                    1 "now on: hotspot"
check "no recovery time without a drop"    0 "back on the hotspot"

echo "6. Watcher starts while Wi-Fi is down: nothing to report until something changes"
run start "none,none,none"
ok "log is empty" '[ ! -s "$LOGFILE" ]'

echo "7. The launchd file stays valid when the app sits in a folder with & < > in its name"
mkdir -p "$TMP/R&D <Tools>" "$TMP/home"
cp "$TM" "$TMP/R&D <Tools>/travel-mode"
HOME="$TMP/home" TM_TEST=1 /bin/bash "$TMP/R&D <Tools>/travel-mode" _plist >/dev/null
P="$TMP/home/Library/LaunchAgents/io.github.ahendraatmaja.mac-travel-mode.lid-lock.plist"
ok "plist is valid" '/usr/bin/plutil -lint -s "$P"'
ok "plist runs the right file" '[ "$(/usr/bin/plutil -extract ProgramArguments.1 raw -o - "$P")" = "$(cd "$TMP/R&D <Tools>" && pwd -P)/travel-mode" ]'

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
