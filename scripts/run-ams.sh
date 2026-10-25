#!/usr/bin/env bash
# Run an AMS Designer (Xcelium + Spectre) lab from examples/ams from the command line.
# Usage: bash scripts/run-ams.sh {lab1|lab2} [extra xrun arguments, e.g. -gui]
set -euo pipefail
repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "$repo/lib/common.sh"
forge_workdir
case "${1:-}" in
  lab1) lab=lab1-inverter top=tb_inv sources=(tb_inv.vams) marker=FORGE_AMS_INV_PASS;;
  lab2) lab=lab2-dac top=tb_dac sources=("$repo/examples/counter/counter4.v" tb_dac.vams)
        marker=FORGE_AMS_DAC_PASS;;
  *) forge_die 'Usage: bash scripts/run-ams.sh {lab1|lab2} [xrun arguments]';;
esac
shift
# The SKY130 models come from the project created by scripts/setup-sky130.py.
export FORGE_PDK_ENV=${FORGE_PDK_ENV:-$HOME/forge-projects/sky130-9t/.forge-sky130/env.sh}
[[ -f $FORGE_PDK_ENV ]] || forge_die "No PDK profile at $FORGE_PDK_ENV; run scripts/setup-sky130.py or set FORGE_PDK_ENV."
source "$FORGE_PDK_ENV"
[[ -r ${FORGE_SKY130_MODEL:-} ]] || forge_die 'FORGE_SKY130_MODEL is unset or unreadable.'
src="$repo/examples/ams/$lab"
mkdir -p build
run=$(mktemp -d "$PWD/build/ams-$lab-XXXXXXXX")
cp "$src"/* "$repo/examples/ams/probe.tcl" "$run"/
printf 'simulator lang=spectre\ninclude "%s" section=%s\n' \
  "$FORGE_SKY130_MODEL" "${FORGE_SKY130_CORNER:-tt}" >"$run/models.scs"
cd "$run"
# AMS Designer starts the Spectre found on PATH as its analog engine.
export PATH="$FORGE_CADENCE_ROOT/SPECTRE251/bin:$PATH"
set +e
timeout --kill-after=10s 600s bash "$repo/bin/forge-eda" xrun -64bit -ams \
  "${sources[@]}" amscf.scs -top "$top" \
  -timescale 1ns/1ps -access +r -iereport -input probe.tcl "$@" >run.log 2>&1
rc=$?
set -e
echo "Log: $run/run.log"
echo "Waveforms: $run/waves.shm (view: cd $run && bash $repo/bin/forge-eda simvision waves.shm)"
if [[ $rc -ne 0 ]] || ! grep -q "$marker" run.log; then
  echo "AMS $lab FAIL (exit $rc); inspect run.log" >&2
  exit 1
fi
grep "$marker" run.log
echo "AMS $lab PASS"
