#!/usr/bin/env bash
# Legacy HSPICE only. No package installation or system library replacement.
set -euo pipefail
source "$(dirname -- "$0")/../lib/common.sh"
[[ $(uname -s) == Linux && $(uname -m) == x86_64 ]] || forge_die 'Requires x86_64 Rocky Linux 8.'
source /etc/os-release
[[ $ID == rocky && $VERSION_ID == 8* ]] || forge_die 'Requires Rocky Linux 8.'
for cmd in curl rpm rpm2cpio cpio realpath; do command -v "$cmd" >/dev/null || forge_die "Missing $cmd"; done
glibc=$(rpm -q --qf '%{VERSION}-%{RELEASE}' glibc.i686) || forge_die '32-bit glibc must already be installed by IT.'
forge_home_path "$FORGE_EDA_STATE"
forge_home_path "$FORGE_HSPICE_ROOT"
[[ ! -e "$FORGE_HSPICE_ROOT" ]] || forge_die "Already exists: $FORGE_HSPICE_ROOT"
umask 077
mkdir -p "$FORGE_EDA_STATE"
[[ -O "$FORGE_EDA_STATE" ]] || forge_die 'State directory must be owned by this user.'
stage=$(mktemp -d "$FORGE_EDA_STATE/hspice-download.XXXXXX")
mkdir "$stage/root"
base=https://dl.rockylinux.org/pub/rocky/8
for path in "BaseOS/x86_64/os/Packages/l/libnsl-$glibc.i686.rpm" 'AppStream/x86_64/os/Packages/n/nspr-4.36.0-2.el8_10.i686.rpm'; do
    package=${path##*/}
    curl --fail --location --proto '=https' --tlsv1.2 --max-time 120 "$base/$path" -o "$stage/$package"
    verification=$(LC_ALL=C rpm -K "$stage/$package" 2>&1) || forge_die "$verification"
    [[ $verification == *'digests signatures OK'* ]] || forge_die "Signature verification incomplete: $verification"
    (cd "$stage/root" && rpm2cpio "../$package" | cpio -id --no-absolute-filenames)
    printf '%s\n' "$base/$path" >> "$stage/sources.txt"
    sha256sum "$stage/$package" >> "$stage/SHA256SUMS"
done
[[ -r "$stage/root/usr/lib/libnsl.so.1" && -r "$stage/root/usr/lib/libnspr4.so" ]] || forge_die 'Expected libraries missing.'
mkdir -p "$(dirname -- "$FORGE_HSPICE_ROOT")"
mv -T -- "$stage/root" "$FORGE_HSPICE_ROOT"
printf 'Legacy HSPICE libraries ready: %s\nEvidence: %s\n' "$FORGE_HSPICE_ROOT" "$stage"
