#!/usr/bin/env bash
# Export a Virtuoso schematic as a Spectre subckt for co-simulation:
# integration/netlists/LIB/CELL.scs ("subckt CELL <pins>", sub-cells included).
# Uses the batch netlister si, so Virtuoso does not need to be open.
#
# Usage: bash integration/netlists/export.sh LIB CELL
#   e.g. bash integration/netlists/export.sh Matt_Mux muxDiff2to1
# The library must be defined in your project cds.lib (default
# ~/forge-projects/sky130-9t/cds.lib; override with FORGE_CDSLIB).
# Re-run after every schematic change, so benches never use a stale netlist.
set -euo pipefail
[[ $# == 2 ]] || { sed -n '6,7p' "$0" | sed 's/^# //' >&2; exit 2; }
lib=$1 cell=$2
here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
repo=$(cd "$here/../.." && pwd)
cdslib=${FORGE_CDSLIB:-$HOME/forge-projects/sky130-9t/cds.lib}
[[ -r $cdslib ]] || { echo "No cds.lib at $cdslib; set FORGE_CDSLIB" >&2; exit 1; }
# Verilog instantiates the subckt by cell name, so it must be an identifier.
[[ $cell =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]] || { echo "Cell name $cell is not a Verilog identifier" >&2; exit 1; }
mkdir -p "$HOME/.cache"
run=$(mktemp -d "$HOME/.cache/forge-netlist-XXXXXXXX")
trap 'rm -rf "$run"' EXIT
cd "$run"
echo "SOFTINCLUDE \"$cdslib\"" > cds.lib
cat > si.env <<ENV
simLibName = "$lib"
simCellName = "$cell"
simViewName = "schematic"
simSimulator = "spectre"
simNotIncremental = 't
simReNetlistAll = 't
simViewList = '("spectre" "cmos_sch" "cmos.sch" "schematic" "veriloga")
simStopList = '("spectre")
simNetlistHier = 't
nlFormatterClass = 'spectreFormatter
nlCreateAmap = 't
nlDesignVarNameList = nil
simRunDir = "./"
ENV
# Netlist the top cell as a subckt; si reads this only from ./.cdsenv with CDS_LOAD_ENV=CWD.
echo 'spectre.envOpts setTopLevelAsSubckt boolean t' > .cdsenv
# Same Cadence install, release and license as bin/forge-eda (site defaults in lib/common.sh).
source "$repo/lib/common.sh"
vhome="$FORGE_CADENCE_ROOT/$FORGE_VIRTUOSO_RELEASE"
export CDSHOME="$vhome" CDS_HOME="$vhome" CDS_SKIP_OS_CHECK_ON_STARTUP=1
export LM_LICENSE_FILE="$FORGE_CADENCE_LICENSE" CDS_LIC_FILE="$FORGE_CADENCE_LICENSE"
export PATH="$vhome/bin:$vhome/tools/bin:$vhome/tools/dfII/bin:$PATH"
if ! CDS_LOAD_ENV=CWD timeout 300s si -batch -command nl . > si.log 2>&1 || ! grep -q "^subckt $cell " netlist; then
    grep -iE 'error|warning' si.log | head -20 >&2
    trap - EXIT
    echo "Netlisting $lib/$cell failed; see $run/si.log" >&2
    exit 1
fi
out="$here/$lib/$cell.scs"
mkdir -p "$(dirname "$out")"
{
    echo "// $lib/$cell/schematic, written by integration/netlists/export.sh on $(date +%F)."
    echo "// Do not edit: change the cell in Virtuoso and export it again."
    echo 'simulator lang=spectre'
    sed '/./,$!d' netlist
} > "$out"
echo "Wrote ${out#"$repo/"}: $(grep "^subckt $cell " "$out")"
