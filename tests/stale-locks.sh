#!/usr/bin/env bash
# Mock test for scripts/clear-stale-locks.sh; no vendor software needed.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd -P)
scratch=${1:?Provide a scratch directory inside the workspace}
mkdir -p "$scratch"
scratch=$(cd "$scratch" && pwd -P)
export HOME="$scratch/home"
proj="$HOME/proj"; lib="$HOME/mylib"
mkdir -p "$proj/Lib/cell/schematic" "$lib/cell/layout"
printf 'DEFINE Lib %s/Lib\nDEFINE mylib "%s"\n' "$proj" "$lib" > "$proj/cds.lib"
host=$(hostname -s)
stake() { # file user host pid created
    printf 'LockStakeVersion 1.1\nLoginName %s\nHostName %s\nProcessIdentifier %s\nProcessCreationTime_UTC %s\n' "$2" "$3" "$4" "$5" > "$1.cdslck"
    : > "$1.cdslck.RHEL30.$3.$4"
}
sleep 300 & live=$!; trap 'kill $live 2>/dev/null' EXIT
live_start=$(( $(date +%s) - $(ps -o etimes= -p $live | tr -d ' ') ))
stake "$proj/Lib/cell/schematic/dead.oa" "$USER" "$host" 999999 1
stake "$proj/Lib/cell/schematic/live.oa" "$USER" "$host" "$live" "$live_start"
stake "$proj/Lib/cell/schematic/reused.oa" "$USER" "$host" "$live" 1
stake "$lib/cell/layout/remote.oa" "$USER" other-vlab-host.coe.neu.edu 1234 1
stake "$proj/Lib/cell/schematic/other.oa" someone-else "$host" 999999 1
cd "$proj"
FORGE_KEEP_REMOTE_LOCKS=1 bash "$repo/scripts/clear-stale-locks.sh" 2>/dev/null
[[ -e $lib/cell/layout/remote.oa.cdslck ]] || { echo 'FAIL: removed remote lock despite FORGE_KEEP_REMOTE_LOCKS'; exit 1; }
bash "$repo/scripts/clear-stale-locks.sh" 2>/dev/null
s="$proj/Lib/cell/schematic"
for gone in "$s/dead.oa.cdslck" "$s/dead.oa.cdslck.RHEL30.$host.999999" "$s/reused.oa.cdslck" "$lib/cell/layout/remote.oa.cdslck" "$lib/cell/layout/remote.oa.cdslck.RHEL30.other-vlab-host.coe.neu.edu.1234"; do
    [[ ! -e $gone ]] || { echo "FAIL: kept stale $gone"; exit 1; }
done
for kept in "$s/live.oa.cdslck" "$s/other.oa.cdslck"; do
    [[ -e $kept ]] || { echo "FAIL: removed $kept"; exit 1; }
done
echo 'PASS: dead, reused-PID and remote locks cleared; live and other users'"'"' locks kept.'
