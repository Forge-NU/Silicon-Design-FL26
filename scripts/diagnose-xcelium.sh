#!/usr/bin/env bash
# Tiny, PDK-independent test. All generated files remain in a private run folder.
set -euo pipefail
source "$(dirname -- "$0")/../lib/common.sh"
forge_home_path "$FORGE_EDA_STATE"
command -v timeout >/dev/null || forge_die 'GNU timeout is required.'
umask 077
mkdir -p "$FORGE_EDA_STATE/results"
run=$(mktemp -d "$FORGE_EDA_STATE/results/xcelium-XXXXXXXX")
cd "$run"
cp "$forge_repo/examples/rtl.sv" ./rtl.sv
# Make this test independent of any selected project PDK.
unset FORGE_PDK_ENV
{
    date -u
    uname -srmo
    hostname
    printf 'Working directory: %s\n' "$run"
} > host.txt
printf 'stage\texit_code\tresult\n' > summary.tsv
step() {
    local name=$1 marker=$2 rc=0
    shift 2
    printf '%q ' bash "$forge_repo/bin/forge-eda" xrun "$@" > "$name.command.txt"
    printf '\n' >> "$name.command.txt"
    timeout -k 10s 180s bash "$forge_repo/bin/forge-eda" xrun "$@" \
        </dev/null > "$name.log" 2>&1 || rc=$?
    if [[ $rc == 0 ]] && { [[ -z $marker ]] || grep -q "$marker" "$name.log"; }; then
        printf '%s\t%s\tPASS\n' "$name" "$rc" | tee -a summary.tsv
        return 0
    fi
    printf '%s\t%s\tFAIL\n' "$name" "$rc" | tee -a summary.tsv
    return 1
}
echo "Diagnostic logs: $run"
step version '' -64bit -version || exit 1
step compile '' -64bit -sv -compile rtl.sv || exit 1
# -elaborate may recheck compilation, then stops before executing simulation.
step elaborate '' -64bit -sv -elaborate rtl.sv -top tb || exit 1
# Same run directory: use the last elaborated snapshot.
step simulate 'FORGE_RTL_PASS' -64bit -R || exit 1
echo 'PASS: tiny RTL simulation advanced time and checked its result.'
