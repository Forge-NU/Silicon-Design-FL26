#!/usr/bin/env bash
# Remove Cadence edit locks (*.cdslck) left by your own Virtuoso sessions that
# no longer exist. Logging off VLAB kills Virtuoso without letting it release
# its locks, and the next login usually lands on a different rocky8 host, so
# cellviews then open read-only as "locked by another process".
#
# Usage: bash scripts/clear-stale-locks.sh [directory...]
#   With no directory, scans the current directory and the libraries its
#   cds.lib defines inside your home. bin/forge-eda runs this before Virtuoso.
#
# A lock is removed only when it belongs to you and either
#   - names this host and its process is gone (or the PID was reused), or
#   - names another host. VLAB gives one session at a time, and other hosts'
#     processes cannot be checked from here. If you run Virtuoso on two hosts
#     at once, set FORGE_KEEP_REMOTE_LOCKS=1 to keep other hosts' locks.
set -euo pipefail
source "$(dirname -- "$0")/../lib/common.sh"

this_host=$(hostname -s)
now=$(date +%s)
home=$(realpath -e -- "$HOME")
state=$(realpath -m -- "$FORGE_EDA_STATE")

field() { sed -n "s/^$1[[:space:]]\{1,\}//p" "$2" | head -n 1; }

process_alive() {
    local pid=$1 created=$2 elapsed
    elapsed=$(ps -o etimes= -p "$pid" 2>/dev/null | tr -d ' ') || return 1
    [[ -n $elapsed ]] || return 1
    # A different start time means the PID now belongs to another process.
    [[ ! $created =~ ^[0-9]+$ ]] || (( created - (now - elapsed) < 10 && (now - elapsed) - created < 10 ))
}

roots=("$@")
if [[ ${#roots[@]} == 0 ]]; then
    roots=("$PWD")
    if [[ -r cds.lib ]]; then
        while read -r keyword _ path _; do
            [[ $keyword == DEFINE && -n ${path:-} ]] || continue
            path=${path%\"}; path=${path#\"}
            [[ $path == /* && -d $path ]] || continue
            path=$(realpath -e -- "$path")
            # Only your own libraries; skip the extracted PDKs.
            [[ $path == "$home/"* && $path != "$state" && $path != "$state/"* ]] || continue
            roots+=("$path")
        done < cds.lib
    fi
fi

removed=0
while IFS= read -r -d '' lock; do
    [[ -O $lock ]] || continue
    [[ $(field LoginName "$lock") == "$USER" ]] || continue
    host=$(field HostName "$lock"); host=${host%%.*}
    pid=$(field ProcessIdentifier "$lock")
    created=$(field ProcessCreationTime_UTC "$lock")
    [[ -n $host && $pid =~ ^[0-9]+$ ]] || continue
    if [[ $host == "$this_host" ]]; then
        if process_alive "$pid" "$created"; then continue; fi
    elif [[ ${FORGE_KEEP_REMOTE_LOCKS:-0} == 1 ]]; then
        continue
    fi
    # Cadence also leaves a per-process companion: <lock>.<os>.<host>.<pid>
    rm -f -- "$lock" "$lock".*."$host"*."$pid"
    printf 'Forge EDA: removed stale lock from %s (PID %s): %s\n' "$host" "$pid" "${lock%.cdslck}" >&2
    removed=$((removed + 1))
done < <(find "${roots[@]}" -xdev -type f -name '*.cdslck' -print0 2>/dev/null | sort -zu)
(( removed == 0 )) || printf 'Forge EDA: cleared %d stale lock(s).\n' "$removed" >&2
