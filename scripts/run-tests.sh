#!/usr/bin/env bash
# Runs every example headless and checks the emulator's final register dump.
#
# The emulator reads the keyboard through a raw terminal, so each run gets a
# pseudo-terminal from `script`; keyboard input is typed into it after start-up.
set -u
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
LOGS="$ROOT/build/test-logs"
failed=0

make -s -C "$ROOT" all || exit 1
mkdir -p "$LOGS"

# check <example> <keyboard-input-function> <expected strings...>
check() {
    local name="$1" input="$2"
    shift 2
    $input | timeout 30 script -qec "$ROOT/scripts/run-example.sh $name" /dev/null \
        | tr -d '\r' >"$LOGS/$name.log" 2>&1

    for expected in "$@"; do
        if ! grep -qF -- "$expected" "$LOGS/$name.log"; then
            echo "FAIL  $name (missing '$expected', see build/test-logs/$name.log)"
            tail -n 8 "$LOGS/$name.log"
            failed=1
            return
        fi
    done
    echo "PASS  $name"
}

no_input() { sleep 10; }
press_y_20_times() {
    sleep 2
    for _ in $(seq 20); do printf y; sleep 0.1; done
    sleep 10
}

check hello   no_input \
    "Hello world" "r1:0x00000007" "r2:0x00000007"

check level-a no_input \
    "r1:0x0000abcd" "r2:0x00000002" "r3:0x00000003" \
    "r4:0x00000004" "r5:0x00000005" "r6:0x00000006"

check level-b press_y_20_times \
    "presspresspresspresspresspresspresspresspresspresspresspresspresspresspresspresspresspresspresspress" \
    "r1:0x00000014"

exit $failed
