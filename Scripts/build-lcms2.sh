#!/bin/bash
# build-lcms2.sh - Build Little CMS 2 for all targets
# Provides ICC color management for libvips

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/utils.sh"

LIB_NAME="lcms2"
SRC_ARCHIVE="lcms2-${LCMS2_VERSION}.tar.gz"
SRC_DIR="${SOURCES_DIR}/lcms2-${LCMS2_VERSION}"

# Extract source
extract_source "$LIB_NAME" "$SRC_ARCHIVE" "$SRC_DIR"

# Get cross file path for target
get_cross_file() {
    local target="$1"
    echo "${CROSS_FILES_DIR}/${target}.ini"
}

build_lcms2() {
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
        --buildtype=release

    meson compile -C "$build_dir" -j "$JOBS"
    meson install -C "$build_dir"

    verify_library "${install_dir}/lib/liblcms2.a" "$arch"
}

build_for_all_targets "$LIB_NAME" build_lcms2

log_success "lcms2 build complete"
