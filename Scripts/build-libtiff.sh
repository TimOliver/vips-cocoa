#!/bin/bash
# build-libtiff.sh - Build libtiff for all targets
# Provides TIFF read/write support for libvips

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/utils.sh"

LIB_NAME="libtiff"
SRC_ARCHIVE="tiff-${LIBTIFF_VERSION}.tar.gz"
SRC_DIR="${SOURCES_DIR}/tiff-${LIBTIFF_VERSION}"

# Extract source
extract_source "$LIB_NAME" "$SRC_ARCHIVE" "$SRC_DIR"

build_libtiff() {
    local target="$1"
    local arch=$(get_target_arch "$target")
    local platform=$(get_target_cmake_platform "$target")

    local build_dir="${BUILD_OUTPUT_DIR}/${LIB_NAME}/${target}"
    local install_dir="${STAGING_DIR}/${LIB_NAME}/${target}"

    # Get dependency paths
    local libjpeg_dir="${STAGING_DIR}/libjpeg-turbo/${target}"

    rm -rf "$build_dir"
    mkdir -p "$build_dir"
    cd "$build_dir"

    cmake "$SRC_DIR" \
        -DCMAKE_TOOLCHAIN_FILE="${TOOLCHAINS_DIR}/ios.toolchain.cmake" \
        -DPLATFORM="$platform" \
        -DDEPLOYMENT_TARGET="$(get_target_deployment_target "$target")" \
        -DCMAKE_INSTALL_PREFIX="$install_dir" \
        -DCMAKE_BUILD_TYPE=Release \
        -DENABLE_BITCODE=OFF \
        -DBUILD_SHARED_LIBS=OFF \
        -DJPEG_INCLUDE_DIR="${libjpeg_dir}/include" \
        -DJPEG_LIBRARY="${libjpeg_dir}/lib/libjpeg.a" \
        -Dtiff-tools=OFF \
        -Dtiff-tests=OFF \
        -Dtiff-docs=OFF \
        -Dtiff-contrib=OFF \
        -Dtiff-deprecated=OFF \
        -Dlzma=OFF \
        -Dzstd=OFF \
        -Dwebp=OFF \
        -Djbig=OFF \
        -Dlerc=OFF

    cmake --build . --parallel "$JOBS"
    cmake --install .

    verify_library "${install_dir}/lib/libtiff.a" "$arch"
}

build_for_all_targets "$LIB_NAME" build_libtiff

log_success "libtiff build complete"
