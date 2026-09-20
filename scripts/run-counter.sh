#!/usr/bin/env bash
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo/lib/common.sh"
forge_workdir
mkdir -p build
run=$(mktemp -d "$PWD/build/counter-XXXXXXXX")
cd "$run"
set +e
timeout --kill-after=10s 180s bash "$repo/bin/forge-eda" xrun -64bit -sv \
  "$repo/examples/counter/counter4.v" "$repo/examples/counter/tb_counter4.sv" \
  -top tb_counter4 >run.log 2>&1
rc=$?
set -e
echo "Log: $run/run.log"
if [[ $rc -ne 0 ]] || ! grep -q 'FORGE_COUNTER_PASS checks=26' run.log; then
  echo "Counter FAIL (exit $rc); inspect run.log" >&2
  exit 1
fi
echo 'Counter PASS: reset, count, wraparound, hold, reset priority.'
