#!/usr/bin/env bash
set -euo pipefail
source "$(dirname -- "$0")/../lib/common.sh"
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || forge_die 'Requires x86_64 Rocky Linux 8.'
source /etc/os-release
[[ $ID == rocky && $VERSION_ID == 8* ]] || forge_die 'This package is selected for Rocky Linux 8 only.'
for cmd in curl rpm rpm2cpio cpio realpath; do command -v "$cmd" >/dev/null || forge_die "Missing $cmd"; done
forge_home_path "$FORGE_EDA_STATE"
forge_home_path "$FORGE_MOTIF_ROOT"
[[ ! -e "$FORGE_MOTIF_ROOT" ]] || forge_die "Already exists; inspect or reuse it: $FORGE_MOTIF_ROOT"
umask 077
mkdir -p -- "$FORGE_EDA_STATE"
[[ -O "$FORGE_EDA_STATE" ]] || forge_die 'State directory is not owned by this user.'
stage=$(mktemp -d "$FORGE_EDA_STATE/motif-download.XXXXXX")
package=motif-2.3.4-24.el8_10.x86_64.rpm
url="https://dl.rockylinux.org/pub/rocky/8/AppStream/x86_64/os/Packages/m/$package"
curl --fail --location --proto '=https' --tlsv1.2 --max-time 120 "$url" -o "$stage/$package"
verification=$(LC_ALL=C rpm -K "$stage/$package" 2>&1) || forge_die "$verification"
[[ $verification == *'digests signatures OK'* ]] || forge_die "Signature verification incomplete: $verification"
rpm -qpl "$stage/$package" > "$stage/contents.txt"
mkdir "$stage/root"
(cd "$stage/root" && rpm2cpio "../$package" | cpio -id --no-absolute-filenames)
[[ -r "$stage/root/usr/lib64/libXm.so.4" ]] || forge_die 'Expected Motif library not extracted.'
if ldd "$stage/root/usr/lib64/libXm.so.4" | grep 'not found'; then forge_die 'Additional dependencies are missing.'; fi
mkdir -p -- "$(dirname -- "$FORGE_MOTIF_ROOT")"
mv -T -- "$stage/root" "$FORGE_MOTIF_ROOT"
printf '%s\n' "$url" > "$stage/source.txt"
sha256sum "$stage/$package" > "$stage/SHA256SUMS"
printf 'Private Motif library ready: %s\nDownload evidence: %s\n' "$FORGE_MOTIF_ROOT" "$stage"
