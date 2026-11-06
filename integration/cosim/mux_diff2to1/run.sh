#!/usr/bin/env bash
# Run the mux co-simulation (Xcelium AMS Designer + Spectre) in a fresh
# directory under ~/forge-runs, so nothing is written into the repo.
#
# Usage: bash integration/cosim/mux_diff2to1/run.sh [CORNER] [TEMP_C] [xrun args, e.g. -gui]
#   CORNER: a .lib section of sky130.lib.spice (tt ss ff sf fs; default tt)
# Passes when the log contains FORGE_TB_PASS.
set -euo pipefail
bench=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
export FORGE_REPO=$(cd "$bench/../../.." && pwd)
corner=${1:-tt}; temp=${2:-27}
shift $(( $# < 2 ? $# : 2 ))
# The SKY130 model file comes from the PDK profile scripts/setup-sky130.py wrote.
if [[ -z ${FORGE_SKY130_MODEL:-} ]]; then
    profile=${FORGE_PDK_ENV:-$HOME/forge-projects/sky130-9t/.forge-sky130/env.sh}
    [[ -f $profile ]] || { echo "No PDK profile at $profile; run scripts/setup-sky130.py or set FORGE_SKY130_MODEL" >&2; exit 2; }
    source "$profile"
fi
model=$FORGE_SKY130_MODEL
grep -q "^\.lib $corner\$" "$model" || { echo "No section '$corner' in $model" >&2; exit 2; }
run=${FORGE_RUN_DIR:-$HOME/forge-runs}/mux_diff2to1-$corner-${temp}C-$(date +%Y%m%d-%H%M%S)
mkdir -p "$run"
cd "$run"
# amscf.scs includes "models.scs" from the run directory.
printf 'simulator lang=spectre\ninclude "%s" section=%s\nbenchTemp options temp=%s\n' \
    "$model" "$corner" "$temp" > models.scs
# AMS Designer starts the Spectre found on PATH as its analog engine.
export PATH="${FORGE_CADENCE_ROOT:-/ECEnet/Apps1/linux/Cadence}/SPECTRE251/bin:$PATH"
set +e
timeout --kill-after=10s 1200s bash "$FORGE_REPO/bin/forge-eda" xrun -64bit \
    -F "$bench/bench.f" -timescale 1ns/1ps -access +r -iereport \
    -input "$bench/probe.tcl" "$@" > run.log 2>&1
rc=$?
set -e
grep -oE "[0-9.]+ ns: .*" run.log || true   # Spectre progress dots can share a line
echo "Run directory:   $run"
echo "Log:             $run/run.log"
echo "Connect modules: $run/ams_ieinfo.log"
echo "Waveforms:       $run/waves.shm"
if [[ $rc -ne 0 ]] || ! grep -q FORGE_TB_PASS run.log; then
    echo "cosim mux_diff2to1 FAIL (exit $rc); inspect run.log" >&2
    exit 1
fi
grep -o 'FORGE_TB_PASS.*' run.log | head -1     # Spectre's progress dots can share the line
echo "cosim mux_diff2to1 PASS"
