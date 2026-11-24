#!/bin/bash
# Replays Wi-Fi state sequences through the watcher with a simulated clock and checks what it
# decides. Touches nothing real: no pmset, no networksetup, settings in a temp folder.
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
TM="$ROOT/src/bin/travel-mode"
pass=0; fail=0

run() { # $1 = name, $2 = comma list of states (one per 10 s check), $3 = network name while on hotspot, $4 = preset hotspot name
  local dir; dir=$(mktemp -d)
  [ -n "${4:-}" ] && printf '%s\n' "$4" > "$dir/hotspot-name"
  local n; n=$(echo "$2" | awk -F, '{print NF}')
  TM_TEST=1 TM_TEST_WIFI="$2" TM_TEST_NAME="${3:-}" TM_TEST_TICKS=$((n * 5)) \
    TM_CONF_DIR="$dir" TM_LOG="$dir/log" "$TM" _watch
  LOGFILE="$dir/log"; CONF="$dir"
}

check() { # $1 = description, $2 = expected count, $3 = pattern
  local got; got=$(grep -c -- "$3" "$LOGFILE" 2>/dev/null || true)
  if [ "$got" = "$2" ]; then pass=$((pass + 1)); echo "  ok   $1"
  else fail=$((fail + 1)); echo "  FAIL $1 (expected $2, got $got)"; sed 's/^/       | /' "$LOGFILE" 2>/dev/null; fi
}

seq_of() { local out="" i; for i in $(seq 1 "$2"); do out="$out,$1"; done; echo "${out#,}"; }

echo "1. Hotspot drops (iPhone stops broadcasting), then comes back after 5 minutes"
run drop "hotspot,hotspot,$(seq_of none 30),hotspot" "MyPhone"
check "learns the hotspot name"            1 "remembered hotspot: MyPhone"
check "logs the disconnect once"           1 "Wi-Fi disconnected (was: hotspot)"
check "retries every 30 s (10 tries)"      10 "would join MyPhone"
check "logs the recovery"                  1 "back on the hotspot after 300 s"
[ "$(cat "$CONF/hotspot-name")" = "MyPhone" ] && { pass=$((pass+1)); echo "  ok   saves the name"; } || { fail=$((fail+1)); echo "  FAIL saves the name"; }

echo "2. Long outage backs off to every 2 minutes after 10 tries"
run long "hotspot,$(seq_of none 60)" "MyPhone"
# lost at check 2; tries at +10 s then every 30 s up to try 10 (+280 s), then every 120 s until +590 s: tries 11-12
check "12 tries in 10 minutes"             12 "would join MyPhone"

echo "3. User moves to another network: leave it alone"
run other "hotspot,other,other,other" "MyPhone"
check "no reconnect attempts"              0 "would join"
check "notes the switch"                   1 "now on: other (not reconnecting)"

echo "4. User turns Wi-Fi off: leave it alone"
run off "hotspot,off,off,off" "MyPhone"
check "no reconnect attempts"              0 "would join"

echo "5. No hotspot known yet: nothing to rejoin"
run unknown "other,none,none,none,none" ""
check "logs the disconnect"                1 "Wi-Fi disconnected"
check "no reconnect attempts"              0 "would join"

echo "6. Remembered from an earlier trip: rejoins after a drop on another network"
run earlier "other,none,none,none,none" "" "OldPhone"
check "tries the remembered hotspot"       1 "would join OldPhone"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
