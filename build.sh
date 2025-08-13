#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

#CONFIG
SCRIPT_DIR="$(dirname "$(realpath "$BASH_SOURCE")")"
REPO_ROOT="$(realpath "$SCRIPT_DIR/..")"
KERNEL_SRC="$REPO_ROOT/android_kernel_xiaomi_gale"
CLANG_ARCHIVE="$SCRIPT_DIR/../clng.tar.xz"
ANYKERNEL_DIR="$SCRIPT_DIR/AnyKernel"
LOG_DIR="$REPO_ROOT/Logs"
DIST_DIR="$REPO_ROOT/dist"

ARCH="arm64"
CORES="$(nproc --all)"
export KBUILD_BUILD_USER="Celestial"
export KBUILD_BUILD_HOST="l0yxf"

OUT_DIR="$REPO_ROOT/out"
DTB_PATH="$OUT_DIR/arch/$ARCH/boot/dts/mediatek/mt6768.dtb"
KERN_IMG="$OUT_DIR/arch/$ARCH/boot/Image.gz"

ZIP_BASE="Aurora_kernel"
ZIP_NAME="${ZIP_BASE}-$(env TZ='Asia/Kolkata' date +%Y%m%d).zip"
ZIP_WORKDIR="$DIST_DIR/$ZIP_BASE"

# Helper funs
function ensure_dirs() {
  mkdir -p "$LOG_DIR" "$DIST_DIR" "$OUT_DIR"
}

function cleanup() {
  rm -rf "$OUT_DIR"         \
         "$REPO_ROOT/clang" \
         "$ZIP_WORKDIR"
}

# Unpack clang
function do_clang() {
  echo ">>> Unpacking Clang from $CLANG_ARCHIVE"
  rm -rf "$REPO_ROOT/clang"
  mkdir -p "$REPO_ROOT/clang"
  tar -xJf "$CLANG_ARCHIVE" -C "$REPO_ROOT/clang"
  export PATH="$REPO_ROOT/clang/bin:/usr/lib/ccache:$PATH"
}

# Build kerrrrnellll...
function do_kernel() {
  echo ">>> Building kernel in $KERNEL_SRC"
  pushd "$KERNEL_SRC" >/dev/null

    export CC=clang CXX=clang++ \
           CROSS_COMPILE=aarch64-linux-gnu- \
           CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
           CLANG_TRIPLE=aarch64-linux-gnu- \
           LD=ld.lld LLVM=1

    make O="$OUT_DIR" ARCH=$ARCH gale_defconfig

    make O="$OUT_DIR" ARCH=$ARCH -j"$CORES" \
      > >(tee "$LOG_DIR/stdout.log") \
      2> >(tee "$LOG_DIR/stderr.log" >&2)

  popd >/dev/null
}

# Packaging
function do_anykernel() {
  echo ">>> Packaging with AnyKernel"
  if [[ ! -f "$KERN_IMG" ]]; then
    echo "ERROR: Kernel image not found at $KERN_IMG" >&2
    exit 1
  fi

  rm -rf "$ZIP_WORKDIR"
  mkdir -p "$ZIP_WORKDIR"

  cp -r "$ANYKERNEL_DIR/." "$ZIP_WORKDIR/"
  cp "$KERN_IMG" "$ZIP_WORKDIR/Image.gz"
  cp "$DTB_PATH" "$ZIP_WORKDIR/mt6768.dtb"

  pushd "$ZIP_WORKDIR" >/dev/null
    zip -r "$ZIP_NAME" .
    mv "$ZIP_NAME" "$DIST_DIR/"
  popd >/dev/null

  # upload
  bash "$SCRIPT_DIR/upload.sh" "$DIST_DIR/$ZIP_NAME"
}


function main() {
  ensure_dirs
  cleanup
  do_clang
  do_kernel
  do_anykernel
  echo ">>> Build complete! Artifacts in $DIST_DIR/$ZIP_NAME"
}

main "$@"
