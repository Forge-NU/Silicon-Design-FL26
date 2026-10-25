# cds.lib helpers shared by the analog library scripts.

# Turn a cds.lib path (quoted, relative, $HOME or $VAR) into an absolute path.
cdslib_resolve() {
    local p=$1 base=$2 var
    p=${p%\"}; p=${p#\"}
    while [[ $p =~ \$\{?([A-Za-z_][A-Za-z0-9_]*)\}? ]]; do
        var=${BASH_REMATCH[1]}
        p=${p/"${BASH_REMATCH[0]}"/${!var:-}}
    done
    [[ $p == /* ]] || p="$base/$p"
    realpath -m -- "$p"
}

# Succeed if CDSLIB already includes SHARED (an absolute path).
cdslib_includes() {
    local cdslib=$1 shared=$2 keyword arg _
    while read -r keyword arg _ || [[ -n ${keyword:-} ]]; do
        [[ $keyword == SOFTINCLUDE || $keyword == INCLUDE ]] || continue
        [[ $(cdslib_resolve "$arg" "$(dirname -- "$cdslib")") == "$shared" ]] && return 0
    done < "$cdslib"
    return 1
}
