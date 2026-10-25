#!/usr/bin/env bash
# Make Virtuoso show the shared libraries in analog/libs. Projects created
# before analog/ existed lack the line in their cds.lib that loads
# analog/cds.lib; this adds it. Run it once after pulling; it is safe to rerun.
#
# Usage: bash scripts/connect-analog-libs.sh [--dry-run] [PROJECT_DIR...]
#   With no directory, connects every project in ~/forge-projects.
#
# Each changed cds.lib is kept as cds.lib.bak-<timestamp>. Restart Virtuoso,
# or run ddUpdateLibList() in the CIW, to see the libraries.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd -P)
shared="$repo/analog/cds.lib"
source "$repo/lib/cdslib.sh"

dry=0
if [[ ${1:-} == --dry-run ]]; then dry=1; shift; fi
projects=("$@")
if [[ ${#projects[@]} == 0 ]]; then
    for c in "$HOME"/forge-projects/*/cds.lib; do
        [[ -f $c ]] && projects+=("$(dirname -- "$c")")
    done
    [[ ${#projects[@]} -gt 0 ]] ||
        { echo "No projects with a cds.lib in ~/forge-projects; pass your project folder." >&2; exit 1; }
fi

# Shared library names, to warn when a project defines the same name.
declare -A shared_names=()
while read -r keyword lname _ || [[ -n ${keyword:-} ]]; do
    [[ $keyword == DEFINE && -n ${lname:-} ]] && shared_names[$lname]=1
done < "$shared"

status=0
for project in "${projects[@]}"; do
    cdslib="${project%/}/cds.lib"
    [[ ${project##*/} == cds.lib ]] && cdslib=$project
    if [[ ! -f $cdslib ]]; then
        echo "skip $project: no cds.lib there (pass the folder you launch Virtuoso from)"; status=1; continue
    fi
    cdslib=$(realpath -e -- "$cdslib")
    while read -r keyword lname lpath _ || [[ -n ${keyword:-} ]]; do
        [[ $keyword == DEFINE && -n ${lname:-} && -n ${shared_names[$lname]:-} ]] || continue
        echo "warning: $cdslib defines $lname, which is also a shared library;"
        echo "         Virtuoso will open the shared one. Rename yours, or delete it if it is the same library."
    done < "$cdslib"
    if cdslib_includes "$cdslib" "$shared"; then
        echo "ok   $cdslib (already connected)"
    elif (( dry )); then
        echo "would connect $cdslib"
    else
        backup="$cdslib.bak-$(date +%Y%m%d-%H%M%S)"
        cp -p -- "$cdslib" "$backup"
        [[ -z $(tail -c 1 -- "$cdslib") ]] || echo >> "$cdslib"
        printf 'SOFTINCLUDE "%s"\n' "$shared" >> "$cdslib"
        echo "connected $cdslib (backup: $(basename -- "$backup"))"
    fi
done
(( dry )) || echo "Restart Virtuoso, or run ddUpdateLibList() in the CIW, to see the shared libraries."
exit $status
