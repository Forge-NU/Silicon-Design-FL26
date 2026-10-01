#!/usr/bin/env bash
# Mock integration test; no vendor software, licenses, or downloads needed.
set -euo pipefail
repo=$(cd "$(dirname "$0")/.." && pwd -P)
scratch=${1:?Provide a scratch directory inside the workspace}
mkdir -p "$scratch"
scratch=$(cd "$scratch" && pwd -P)
export HOME="$scratch/home"
mkdir -p "$HOME/design" "$HOME/motif/usr/lib64" "$scratch/vendor/INNOVUS211/bin"
printf 'placeholder\n' > "$HOME/motif/usr/lib64/libXm.so.4"
export FORGE_CADENCE_ROOT="$scratch/vendor"
export FORGE_COURSE_SETUP="$scratch/course.sh"
export FORGE_MOTIF_ROOT="$HOME/motif"
printf 'export OA_HOME=/incompatible/course/oa\nexport LD_LIBRARY_PATH=/course/lib\n' > "$FORGE_COURSE_SETUP"
cat > "$scratch/vendor/INNOVUS211/bin/innovus" <<'MOCK'
#!/usr/bin/env bash
[[ ! ${OA_HOME+x} ]] || exit 21
[[ $LD_LIBRARY_PATH == "$FORGE_MOTIF_ROOT/usr/lib64:/course/lib" ]] || exit 22
[[ $# == 2 && $1 == '-files' && $2 == 'file with spaces.tcl' ]] || exit 23
echo MOCK_PASS
MOCK
chmod +x "$scratch/vendor/INNOVUS211/bin/innovus"
export OA_HOME=parent-value
cd "$HOME/design"
bash "$repo/bin/forge-eda" innovus -files 'file with spaces.tcl' | grep -q MOCK_PASS
[[ $OA_HOME == parent-value ]]
# Site setup that does not expose lec: fall back to the installed Conformal.
mkdir -p "$scratch/vendor/CONFRML241/bin"
cat > "$scratch/vendor/CONFRML241/bin/lec" <<'MOCK'
#!/usr/bin/env bash
[[ ! ${OA_HOME+x} ]] || exit 31
[[ $# == 2 && $1 == '-dofile' && $2 == 'my lec.do' ]] || exit 32
echo MOCK_LEC_PASS
MOCK
chmod +x "$scratch/vendor/CONFRML241/bin/lec"
PATH=/usr/bin:/bin bash "$repo/bin/forge-eda" lec -dofile 'my lec.do' | grep -q MOCK_LEC_PASS
cd "$scratch"
if bash "$repo/bin/forge-eda" innovus -files x >/dev/null 2>&1; then echo 'FAIL: allowed work outside home'; exit 1; fi
cd "$HOME/design"
if FORGE_MOTIF_ROOT="$scratch/outside-home" bash "$repo/bin/forge-eda" innovus >/dev/null 2>&1; then echo 'FAIL: accepted outside-home library root'; exit 1; fi
if bash "$repo/bin/forge-eda" unknown >/dev/null 2>&1; then echo 'FAIL: accepted unknown tool'; exit 1; fi
echo 'PASS: argument quoting, installed-LEC fallback, scoped OpenAccess/Motif environment, parent isolation, home guards, tool validation.'
