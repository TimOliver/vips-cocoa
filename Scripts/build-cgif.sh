#!/bin/bash
# build-cgif.sh - Build cgif for all targets
# Provides GIF encoding support for libvips

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/utils.sh"

LIB_NAME="cgif"
SRC_ARCHIVE="cgif-${CGIF_VERSION}.tar.gz"
SRC_DIR="${SOURCES_DIR}/cgif-${CGIF_VERSION}"

# Extract source
extract_source "$LIB_NAME" "$SRC_ARCHIVE" "$SRC_DIR"

# Get cross file path for target
get_cross_file() {
    local target="$1"
    echo "${CROSS_FILES_DIR}/${target}.ini"
}

build_cgif() {
    local target="$1"
    local arch=$(get_target_arch "$target")

    local build_dir="${BUILD_OUTPUT_DIR}/${LIB_NAME}/${target}"
    local install_dir="${STAGING_DIR}/${LIB_NAME}/${target}"
    local cross_file=$(get_cross_file "$target")

    # Clean existing build
    rm -rf "$build_dir"

    meson setup "$build_dir" "$SRC_DIR" \
        --cross-file="$cross_file" \
        --prefix="$install_dir" \
        --default-library=static \
        --buildtype=release \
        -Dtests=false

    meson compile -C "$build_dir" -j "$JOBS"
    meson install -C "$build_dir"

    verify_library "${install_dir}/lib/libcgif.a" "$arch"
}

build_for_all_targets "$LIB_NAME" build_cgif

log_success "cgif build complete"
