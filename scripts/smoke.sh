#!/usr/bin/env bash
set -uo pipefail
source "$(dirname -- "$0")/../lib/common.sh"
forge_home_path "$FORGE_EDA_STATE"
umask 077
mkdir -p "$FORGE_EDA_STATE/results"
run=$(mktemp -d "$FORGE_EDA_STATE/results/run.XXXXXX")
printf 'tool\texit_code\tresult\n' > "$run/summary.tsv"
failures=0
for tool in spectre innovus tempus genus xrun; do
    mkdir "$run/$tool"
    case "$tool" in
      spectre) args=("$forge_repo/examples/rc.scs"); marker='spectre completes with 0 errors';;
      innovus|tempus) args=(-no_gui -files "$forge_repo/examples/startup.tcl"); marker=FORGE_STARTUP_PASS;;
      genus) args=(-no_gui -files "$forge_repo/examples/startup.tcl"); marker=FORGE_STARTUP_PASS;;
      xrun) args=(-64bit -sv "$forge_repo/examples/rtl.sv"); marker=FORGE_RTL_PASS;;
    esac
    (cd "$run/$tool" && timeout -k 10 180 bash "$forge_repo/bin/forge-eda" "$tool" "${args[@]}" </dev/null > tool.log 2>&1)
    rc=$?
    result=FAIL
    if [[ $rc == 0 ]] && grep -qi "$marker" "$run/$tool/tool.log"; then result=PASS; fi
    if [[ $result == FAIL ]]; then failures=$((failures + 1)); fi
    printf '%s\t%s\t%s\n' "$tool" "$rc" "$result" | tee -a "$run/summary.tsv"
done
printf 'Logs retained privately at %s\nStartup checks do not validate a full design flow.\n' "$run"
[[ $failures == 0 ]]
