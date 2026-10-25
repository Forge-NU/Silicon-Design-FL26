#!/usr/bin/env bash
# Move a Virtuoso library from a Forge project into analog/libs so Git tracks
# it, and update both cds.lib files so Virtuoso finds it in its new place.
#
# Usage: bash scripts/share-analog-lib.sh [--dry-run] LIBRARY_DIR
#   e.g. bash scripts/share-analog-lib.sh ~/forge-projects/sky130-9t/adc_comparator
#
# It
#   1. refuses if the library is open in Virtuoso (clears your stale locks first),
#   2. moves LIBRARY_DIR to analog/libs/<name>,
#   3. adds "DEFINE <name> libs/<name>" to analog/cds.lib,
#   4. in the project's cds.lib (next to the library), removes the old
#      DEFINE line for it and adds the SOFTINCLUDE of analog/cds.lib if
#      missing; the old file is kept as cds.lib.bak-<timestamp>.
# Nothing is committed; the script prints the Git commands to run.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd -P)
shared="$repo/analog/cds.lib"

dry=0
if [[ ${1:-} == --dry-run ]]; then dry=1; shift; fi
[[ $# == 1 ]] || { sed -n '5,6p' "$0" | sed 's/^# //' >&2; exit 2; }
run() { if (( dry )); then echo "would: $*"; else "$@"; fi; }
die() { echo "share-analog-lib: $*" >&2; exit 1; }

# Turn a cds.lib path (quoted, relative, $HOME or $VAR) into an absolute path.
resolve() {
    local p=$1 base=$2 var
    p=${p%\"}; p=${p#\"}
    while [[ $p =~ \$\{?([A-Za-z_][A-Za-z0-9_]*)\}? ]]; do
        var=${BASH_REMATCH[1]}
        p=${p/"${BASH_REMATCH[0]}"/${!var:-}}
    done
    [[ $p == /* ]] || p="$base/$p"
    realpath -m -- "$p"
}

# A library folder has cdsinfo.tag, or .oalib when made by Stream In / DEF In.
is_lib() { [[ -f $1/cdsinfo.tag || -f $1/.oalib ]]; }

# Print "name path" for each library a cds.lib defines inside your home.
libs_in() {
    local cdslib=$1 keyword lname lpath _
    while read -r keyword lname lpath _; do
        [[ $keyword == DEFINE && -n ${lpath:-} ]] || continue
        lpath=$(resolve "$lpath" "$(dirname -- "$cdslib")")
        [[ $lpath == "$HOME/"* && $lpath != */.local/share/* ]] && is_lib "$lpath" &&
            echo "  $lname    $lpath"
    done < "$cdslib"
}

src=$(realpath -e -- "$1" 2>/dev/null) || die "no such directory: $1"
if [[ ! -d $src ]] || ! is_lib "$src"; then
    msg="$src is not a Virtuoso library folder."
    up=$(dirname -- "$src")
    while [[ $up == "$HOME/"* ]] && ! is_lib "$up"; do up=$(dirname -- "$up"); done
    if [[ $up == "$HOME/"* ]]; then
        msg+=" It is inside library $(basename -- "$up"); pass the library folder:
  bash scripts/share-analog-lib.sh $up"
    elif [[ -f $src/cds.lib ]]; then
        found=$(libs_in "$src/cds.lib")
        if [[ -n $found ]]; then
            msg+=" That looks like a project folder; pass one of its libraries:
$found"
        else
            msg+=" That looks like a project folder, but its cds.lib defines no libraries of yours."
        fi
    else
        msg+=" Pass the folder named after the library (it holds the cell folders)."
    fi
    die "$msg"
fi
name=$(basename -- "$src")
dest="$repo/analog/libs/$name"
[[ $name =~ ^[A-Za-z][A-Za-z0-9_]*$ ]] || die "library name '$name' must be letters, digits and _"
[[ $src != "$repo/"* ]] || die "$src is already inside the repository"
[[ ! -e $dest ]] || die "analog/libs/$name already exists; rename your library or pick another name"
! grep -qE "^DEFINE[[:space:]]+$name[[:space:]]" "$shared" ||
    die "analog/cds.lib already defines $name; library names must be unique across the team"

# Refuse to move a library someone has open: clear only dead sessions' locks.
(( dry )) || bash "$repo/scripts/clear-stale-locks.sh" "$src"
locks=$(find "$src" -type f -name '*.cdslck' | head -n 5)
if (( dry )) && [[ -n $locks ]]; then
    echo "note: lock files present; a real run clears stale ones and stops if any session is live"
elif [[ -n $locks ]]; then die "library is open in Virtuoso; close its cellviews (or Virtuoso) and rerun. Locked:
$locks"
fi

project_lib="$(dirname -- "$src")/cds.lib"

run mv -- "$src" "$dest"
if [[ ! -f $src/cdsinfo.tag && ! -f $dest/cdsinfo.tag ]]; then
    if (( dry )); then echo "would: add cdsinfo.tag (library has only .oalib)"
    else printf 'CDSLIBRARY\nDMTYPE none\nNAMESPACE LibraryUnix\n' > "$dest/cdsinfo.tag"; fi
fi
if (( dry )); then echo "would: append 'DEFINE $name libs/$name' to $shared"
else printf 'DEFINE %s libs/%s\n' "$name" "$name" >> "$shared"; fi

if [[ -f $project_lib ]]; then
    base=$(dirname -- "$project_lib")
    new=$(mktemp)
    removed=0 included=0
    while IFS= read -r line || [[ -n $line ]]; do
        read -r keyword arg1 arg2 _ <<< "$line" || true
        if [[ $keyword == DEFINE && $arg1 == "$name" ]] ||
           [[ $keyword == DEFINE && -n ${arg2:-} && $(resolve "$arg2" "$base") == "$src" ]]; then
            removed=$((removed + 1)); continue
        fi
        if [[ $keyword == SOFTINCLUDE || $keyword == INCLUDE ]] &&
           [[ $(resolve "$arg1" "$base") == "$shared" ]]; then
            included=1
        fi
        printf '%s\n' "$line" >> "$new"
    done < "$project_lib"
    (( included )) || printf 'SOFTINCLUDE "%s"\n' "$shared" >> "$new"
    if (( dry )); then
        echo "would: update $project_lib:"; diff "$project_lib" "$new" | sed 's/^/    /' || true
        rm -f -- "$new"
    else
        backup="$project_lib.bak-$(date +%Y%m%d-%H%M%S)"
        cp -p -- "$project_lib" "$backup"
        cat "$new" > "$project_lib"; rm -f -- "$new"
        echo "Updated $project_lib (removed $removed old DEFINE line(s)$( ((included)) || echo ', added SOFTINCLUDE')); backup: $backup"
    fi
else
    echo "Note: no cds.lib next to the library; remove any 'DEFINE $name ...' line from the cds.lib that defined it." >&2
fi

(( dry )) && exit 0
bash "$repo/scripts/check-analog-libs.sh"
cat <<EOF

Moved $name to analog/libs/$name. Restart Virtuoso (or reopen Library Manager) to see it there.
To share it:
  cd $repo
  git switch -c add-$name          # skip if already on a branch for this
  git add analog/cds.lib analog/libs/$name
  git commit -m "Add $name library"
  git push -u origin add-$name
EOF
