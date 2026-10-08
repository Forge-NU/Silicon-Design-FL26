#!/usr/bin/env bash
forge_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
if [[ -f "$forge_repo/config/local.sh" ]]; then source "$forge_repo/config/local.sh"; fi
# Cadence 2025/2026 releases that COE installed in October 2026.
FORGE_CADENCE_ROOT=${FORGE_CADENCE_ROOT:-/ECEnet/Apps1/linux/Cadence}
# The older tree still holds the PDKs and Tempus (SSV251), which the new tree lacks.
FORGE_CADENCE_LEGACY_ROOT=${FORGE_CADENCE_LEGACY_ROOT:-/ECEnet/Apps1/linux/cad2024/tools}
FORGE_PDK_ROOT=${FORGE_PDK_ROOT:-$FORGE_CADENCE_LEGACY_ROOT/PDKs}
# The campus license serves Virtuoso features only up to 25.1, so IC261 fails
# checkout (ELI-00138). Set IC261 once the server offers 26.x features.
FORGE_VIRTUOSO_RELEASE=${FORGE_VIRTUOSO_RELEASE:-IC251}
FORGE_CADENCE_LICENSE=${FORGE_CADENCE_LICENSE:-5280@cadencelm.coe.neu.edu}
# Optional extra setup script sourced before the tool environment; empty by
# default because the EECE7353 cadence24.sh selects IC618 and its OpenAccess.
FORGE_COURSE_SETUP=${FORGE_COURSE_SETUP:-}
FORGE_EDA_STATE=${FORGE_EDA_STATE:-$HOME/.local/share/forge-silicon}
FORGE_MOTIF_ROOT=${FORGE_MOTIF_ROOT:-$FORGE_EDA_STATE/motif-2.3.4-24.el8_10.x86_64}
FORGE_HSPICE_ROOT=${FORGE_HSPICE_ROOT:-$FORGE_EDA_STATE/hspice32}
forge_die() { printf 'Forge EDA: %s\n' "$*" >&2; exit 1; }
forge_home_path() {
    local target home
    target=$(realpath -m -- "$1") || return 1
    home=$(realpath -e -- "$HOME") || return 1
    [[ "$target" == "$home/"* ]] || forge_die "Path must be inside your home: $1"
}
forge_workdir() {
    forge_home_path "$PWD"
    [[ -O . && -w . ]] || forge_die 'Run from a writable directory you own inside your home.'
}
