#!/usr/bin/env bash
forge_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
if [[ -f "$forge_repo/config/local.sh" ]]; then source "$forge_repo/config/local.sh"; fi
FORGE_CADENCE_ROOT=${FORGE_CADENCE_ROOT:-/ECEnet/Apps1/linux/cad2024/tools}
FORGE_COURSE_SETUP=${FORGE_COURSE_SETUP:-/ECEnet/Apps1/linux/EECE7353/cadence24.sh}
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
