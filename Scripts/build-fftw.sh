#!/bin/bash
# build-fftw.sh - Build FFTW3 (double-precision) for all targets
# Provides FFT support for libvips frequency-domain operations

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/utils.sh"

LIB_NAME="fftw"
SRC_ARCHIVE="fftw-${FFTW_VERSION}.tar.gz"
SRC_DIR="${SOURCES_DIR}/fftw-${FFTW_VERSION}"

# Extract source
extract_source "$LIB_NAME" "$SRC_ARCHIVE" "$SRC_DIR"

build_fftw() {
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
        --disable-fortran \
        --disable-doc

    make -j "$JOBS"
    make install

    verify_library "${install_dir}/lib/libfftw3.a" "$arch"
}

build_for_all_targets "$LIB_NAME" build_fftw

log_success "fftw build complete"
