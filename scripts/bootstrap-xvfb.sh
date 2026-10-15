#!/usr/bin/env bash
# ADE Explorer refuses to simulate (EXPLORER-9512) without Xvfb, which VLAB
# Rocky 8 hosts do not install. Unpack a private copy; the launcher points
# CDS_XVFB_PATH at it.
set -euo pipefail
source "$(dirname -- "$0")/../lib/common.sh"
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || forge_die 'Requires x86_64 Rocky Linux 8.'
source /etc/os-release
[[ $ID == rocky && $VERSION_ID == 8* ]] || forge_die 'This package is selected for Rocky Linux 8 only.'
for cmd in curl rpm rpm2cpio cpio realpath; do command -v "$cmd" >/dev/null || forge_die "Missing $cmd"; done
# Xvfb compiles its keymaps with the system xkbcomp and XKB data.
[[ -x /usr/bin/xkbcomp && -d /usr/share/X11/xkb ]] || forge_die 'Missing system xkbcomp or /usr/share/X11/xkb.'
forge_home_path "$FORGE_EDA_STATE"
forge_home_path "$FORGE_XVFB_ROOT"
[[ ! -e "$FORGE_XVFB_ROOT" ]] || forge_die "Already exists; inspect or reuse it: $FORGE_XVFB_ROOT"
umask 077
mkdir -p -- "$FORGE_EDA_STATE"
[[ -O "$FORGE_EDA_STATE" ]] || forge_die 'State directory is not owned by this user.'
stage=$(mktemp -d "$FORGE_EDA_STATE/xvfb-download.XXXXXX")
mkdir "$stage/root"
for name in xorg-x11-server-Xvfb xorg-x11-server-common; do
    package=$name-1.20.11-28.el8_10.3.x86_64.rpm
    url="https://dl.rockylinux.org/pub/rocky/8/AppStream/x86_64/os/Packages/x/$package"
    curl --fail --location --proto '=https' --tlsv1.2 --max-time 120 "$url" -o "$stage/$package"
    verification=$(LC_ALL=C rpm -K "$stage/$package" 2>&1) || forge_die "$verification"
    [[ $verification == *'digests signatures OK'* ]] || forge_die "Signature verification incomplete: $verification"
    rpm -qpl "$stage/$package" >> "$stage/contents.txt"
    (cd "$stage/root" && rpm2cpio "../$package" | cpio -id --no-absolute-filenames)
    printf '%s\n' "$url" >> "$stage/source.txt"
done
[[ -x "$stage/root/usr/bin/Xvfb" ]] || forge_die 'Expected Xvfb executable not extracted.'
if ldd "$stage/root/usr/bin/Xvfb" | grep 'not found'; then forge_die 'Additional dependencies are missing.'; fi
mkdir -p -- "$(dirname -- "$FORGE_XVFB_ROOT")"
chmod -R go+rX "$stage/root"
mv -T -- "$stage/root" "$FORGE_XVFB_ROOT"
(cd "$stage" && sha256sum ./*.rpm > SHA256SUMS)
printf 'Private Xvfb ready: %s\nDownload evidence: %s\n' "$FORGE_XVFB_ROOT/usr/bin/Xvfb" "$stage"
