#!/usr/bin/env bash
# Check that analog/cds.lib and analog/libs/ agree, and that no tracked
# library carries lock files or simulation results.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd -P)
cd "$repo/analog"
status=0
declared=$(awk '$1 == "DEFINE" { print $2 " " $3 }' cds.lib)
while read -r name path; do
  [[ -n $name ]] || continue
  if [[ $path != "libs/$name" ]]; then
    echo "cds.lib: use 'DEFINE $name libs/$name' (relative), not '$path'"; status=1
  elif [[ ! -f libs/$name/cdsinfo.tag && ! -f libs/$name/.oalib ]]; then
    echo "cds.lib: $name is listed but libs/$name is not a Virtuoso library"; status=1
  fi
done <<< "$declared"
for dir in libs/*/; do
  [[ -d $dir ]] || continue
  name=$(basename "$dir")
  grep -qE "^DEFINE[[:space:]]+$name[[:space:]]" cds.lib ||
    { echo "analog/libs/$name is not listed; add: DEFINE $name libs/$name"; status=1; }
done
tracked=$(git -C "$repo" ls-files analog/libs | grep -E '\.cdslck|/maestro/(results|history)/' || true)
if [[ -n $tracked ]]; then
  echo "Remove these from Git (git rm --cached):"; echo "$tracked"; status=1
fi
[[ $status == 0 ]] && echo "analog/: $(grep -c '^DEFINE' cds.lib || true) libraries OK"
exit $status
