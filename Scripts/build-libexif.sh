#!/bin/bash
# build-libexif.sh - Build libexif for all targets
# Provides EXIF metadata reading/writing for libvips

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/utils.sh"

LIB_NAME="libexif"
SRC_ARCHIVE="libexif-${LIBEXIF_VERSION}.tar.bz2"
SRC_DIR="${SOURCES_DIR}/libexif-${LIBEXIF_VERSION}"

# Extract source
extract_source "$LIB_NAME" "$SRC_ARCHIVE" "$SRC_DIR"

build_libexif() {
    local target="$1"
    local arch=$(get_target_arch "$target")

    local build_dir="${BUILD_OUTPUT_DIR}/${LIB_NAME}/${target}"
    local install_dir="${STAGING_DIR}/${LIB_NAME}/${target}"

    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"

    "$SRC_DIR/configure" \
        --prefix="$install_dir" \
        --host="$HOST" \
        --enable-static \
        --disable-shared \
        --disable-docs \
        --disable-nls

    make -j "$JOBS"
    make install

    verify_library "${install_dir}/lib/libexif.a" "$arch"
}

build_for_all_targets "$LIB_NAME" build_libexif

log_success "libexif build complete"
