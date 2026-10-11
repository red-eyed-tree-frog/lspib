#!/bin/bash
# Build the Assignment 3 ARM64 kernel and standalone initramfs.
set -euo pipefail
trap 'echo "Build failed at line $LINENO" >&2' ERR
[[ $# -le 1 ]] || { echo "Usage: $0 [outdir]" >&2; exit 1; }
OUTDIR=${1:-/tmp/aeld}
mkdir -p -- "$OUTDIR"
OUTDIR=$(cd -- "$OUTDIR" && pwd -P)
# The kernel build system cannot build under paths containing whitespace.
[[ "$OUTDIR" != / && ! "$OUTDIR" =~ [[:space:]] ]] || {
    echo 'Choose a dedicated output directory without whitespace.' >&2; exit 1;
}
FINDER_APP_DIR=$(cd -- "$(dirname -- "$0")" && pwd -P)
KERNEL_REPO=https://git.kernel.org/pub/scm/linux/kernel/git/stable/linux.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
ARCH=arm64
CROSS_COMPILE=${CROSS_COMPILE:-aarch64-none-linux-gnu-}
JOBS=${JOBS:-$(nproc)}
for tool in git make cpio gzip "${CROSS_COMPILE}gcc" "${CROSS_COMPILE}readelf"; do
    command -v "$tool" >/dev/null || { echo "Missing tool: $tool" >&2; exit 1; }
done
SUDO=()
if [[ $EUID -ne 0 ]]; then SUDO=(sudo); fi

checkout_source() {
    local url=$1 tag=$2 directory=$3
    if [[ ! -d "$directory" ]]; then
        git clone --depth 1 --single-branch --branch "$tag" "$url" "$directory"
    fi
    if ! git -C "$directory" rev-parse --verify "refs/tags/$tag" >/dev/null 2>&1; then
        git -C "$directory" fetch --depth 1 origin "refs/tags/$tag:refs/tags/$tag"
    fi
    git -C "$directory" checkout --detach "$tag"
}
checkout_source "$KERNEL_REPO" "$KERNEL_VERSION" "$OUTDIR/linux-stable"
make -C "$OUTDIR/linux-stable" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" defconfig
# Modules are intentionally not installed into this small initramfs.
make -C "$OUTDIR/linux-stable" -j"$JOBS" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" Image
cp -- "$OUTDIR/linux-stable/arch/$ARCH/boot/Image" "$OUTDIR/Image"

ROOTFS="$OUTDIR/rootfs"
[[ ! -L "$ROOTFS" ]] || { echo 'rootfs must not be a symlink' >&2; exit 1; }
# Only the dedicated staging tree is removed on rebuild.
"${SUDO[@]}" rm -rf -- "$ROOTFS"
mkdir -p "$ROOTFS"/{bin,sbin,lib,lib64,etc,proc,sys,dev,tmp,run,usr/bin,usr/sbin,home/conf}
chmod 1777 "$ROOTFS/tmp"
checkout_source https://git.busybox.net/busybox "$BUSYBOX_VERSION" "$OUTDIR/busybox"
make -C "$OUTDIR/busybox" distclean
make -C "$OUTDIR/busybox" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" defconfig
make -C "$OUTDIR/busybox" -j"$JOBS" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE"
make -C "$OUTDIR/busybox" ARCH="$ARCH" CROSS_COMPILE="$CROSS_COMPILE" CONFIG_PREFIX="$ROOTFS" install

make -C "$FINDER_APP_DIR" clean
make -C "$FINDER_APP_DIR" CROSS_COMPILE="$CROSS_COMPILE"
install -m 0755 "$FINDER_APP_DIR/writer" "$ROOTFS/home/writer"

# Resolve the ELF interpreter and all transitive shared libraries using the
# cross compiler's sysroot. Never copy the build host's x86 libraries.
SYSROOT=$("${CROSS_COMPILE}gcc" -print-sysroot)
READELF="${CROSS_COMPILE}readelf"
declare -A COPIED=()
copy_dependencies() {
    local binary=$1 interpreter library source
    interpreter=$("$READELF" -l "$binary" | sed -n 's/.*Requesting program interpreter: \(.*\)]/\1/p')
    if [[ -n "$interpreter" && ! -e "$ROOTFS$interpreter" ]]; then
        source="$SYSROOT$interpreter"
        [[ -f "$source" ]] || source=$("${CROSS_COMPILE}gcc" -print-file-name="${interpreter##*/}")
        [[ -f "$source" ]] || { echo "Cannot locate $interpreter" >&2; return 1; }
        mkdir -p "$(dirname "$ROOTFS$interpreter")"
        cp -L "$source" "$ROOTFS$interpreter"
        copy_dependencies "$ROOTFS$interpreter"
    fi
    while IFS= read -r library; do
        [[ -n "$library" && -z "${COPIED[$library]:-}" ]] || continue
        source=$("${CROSS_COMPILE}gcc" -print-file-name="$library")
        if [[ ! -f "$source" ]]; then
            source=$(find "$SYSROOT/lib" "$SYSROOT/usr/lib" -name "$library" -print -quit 2>/dev/null || true)
        fi
        [[ -f "$source" ]] || { echo "Cannot locate ARM library $library" >&2; return 1; }
        COPIED[$library]=1
        cp -L "$source" "$ROOTFS/lib/$library"
        cp -L "$source" "$ROOTFS/lib64/$library"
        copy_dependencies "$ROOTFS/lib/$library"
    done < <("$READELF" -d "$binary" | sed -n 's/.*(NEEDED).*\[\(.*\)\]/\1/p')
}
copy_dependencies "$ROOTFS/bin/busybox"
copy_dependencies "$ROOTFS/home/writer"

"${SUDO[@]}" mknod -m 666 "$ROOTFS/dev/null" c 1 3
"${SUDO[@]}" mknod -m 600 "$ROOTFS/dev/console" c 5 1
for script in finder.sh finder-test.sh autorun-qemu.sh; do
    install -m 0755 "$FINDER_APP_DIR/$script" "$ROOTFS/home/$script"
done
for config in username.txt assignment.txt; do
    install -m 0644 "$FINDER_APP_DIR/../conf/$config" "$ROOTFS/home/conf/$config"
done
"${SUDO[@]}" chown -R 0:0 "$ROOTFS"
(
    cd "$ROOTFS"
    find . -print0 | cpio --null -ov --format=newc --owner=0:0
) | gzip -n -9 > "$OUTDIR/initramfs.cpio.gz.tmp"
mv -- "$OUTDIR/initramfs.cpio.gz.tmp" "$OUTDIR/initramfs.cpio.gz"
echo "Ready: $OUTDIR/Image and $OUTDIR/initramfs.cpio.gz"
