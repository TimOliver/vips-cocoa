#!/bin/bash
#
# package-prebuilt.sh - Package pre-built static libraries and xcframeworks for release
#
# Run this after a successful ./build.sh to create release artifacts.
# Upload the resulting files to GitHub releases.
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

VERSION="${1:-1.0.0}"

STAGING_DIR="${PROJECT_ROOT}/build/staging"
GEN_DIR="${PROJECT_ROOT}/build/output/libvips-generated"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[Package]${NC} $1"
}

log_error() {
    echo -e "${RED}[Package]${NC} $1"
}

# Verify staging directory exists
if [ ! -d "${STAGING_DIR}" ]; then
    log_error "build/staging/ not found. Run ./build.sh first."
    exit 1
fi

# Check that all required libraries are present
REQUIRED_LIBS=(
    "glib"
    "libjpeg-turbo"
    "libpng"
    "libwebp"
    "libjxl"
    "libheif"
    "highway"
    "expat"
    "dav1d"
    "brotli"
    "pcre2"
    "libffi"
    "libvips"
)

log_info "Checking for required libraries..."
for lib in "${REQUIRED_LIBS[@]}"; do
    if [ ! -d "${STAGING_DIR}/${lib}" ]; then
        log_error "Missing: ${lib}"
        log_error "Run ./build.sh to build all dependencies first."
        exit 1
    fi
done

log_info "All required libraries present."

# =============================================================================
# 1. Pre-built static libraries tarball
# =============================================================================
PREBUILT_FILE="vips-cocoa-prebuilt-${VERSION}.tar.gz"

log_info "Creating ${PREBUILT_FILE}..."
cd "${PROJECT_ROOT}/build"
tar -czf "${PREBUILT_FILE}" staging/
mv "${PREBUILT_FILE}" "${PROJECT_ROOT}/"

log_info "Created: ${PREBUILT_FILE}"
log_info "Size: $(du -h "${PROJECT_ROOT}/${PREBUILT_FILE}" | cut -f1)"

# =============================================================================
# 2. Generated files tarball
# =============================================================================
GEN_FILE="libvips-generated-${VERSION}.tar.gz"

if [ -d "${GEN_DIR}" ]; then
    log_info "Creating ${GEN_FILE}..."
    cd "${PROJECT_ROOT}/build/output"
    tar -czf "${GEN_FILE}" libvips-generated/
    mv "${GEN_FILE}" "${PROJECT_ROOT}/"

    log_info "Created: ${GEN_FILE}"
    log_info "Size: $(du -h "${PROJECT_ROOT}/${GEN_FILE}" | cut -f1)"
else
    log_error "Generated files not found at ${GEN_DIR}. Skipping."
fi

# =============================================================================
# 3. XCFramework zips
# =============================================================================
if [ -d "${PROJECT_ROOT}/libvips.xcframework" ]; then
    XCF_DYN_FILE="libvips-${VERSION}.xcframework.zip"
    log_info "Creating ${XCF_DYN_FILE}..."
    cd "${PROJECT_ROOT}"
    zip -r -q "${XCF_DYN_FILE}" libvips.xcframework/

    log_info "Created: ${XCF_DYN_FILE}"
    log_info "Size: $(du -h "${PROJECT_ROOT}/${XCF_DYN_FILE}" | cut -f1)"
else
    log_info "libvips.xcframework not found, skipping dynamic zip."
fi

if [ -d "${PROJECT_ROOT}/libvips-static.xcframework" ]; then
    XCF_STATIC_FILE="libvips-static-${VERSION}.xcframework.zip"
    log_info "Creating ${XCF_STATIC_FILE}..."
    cd "${PROJECT_ROOT}"
    zip -r -q "${XCF_STATIC_FILE}" libvips-static.xcframework/

    log_info "Created: ${XCF_STATIC_FILE}"
    log_info "Size: $(du -h "${PROJECT_ROOT}/${XCF_STATIC_FILE}" | cut -f1)"
else
    log_info "libvips-static.xcframework not found, skipping static zip."
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
log_info "Release artifacts:"
[ -f "${PROJECT_ROOT}/${PREBUILT_FILE}" ] && log_info "  ${PREBUILT_FILE}"
[ -f "${PROJECT_ROOT}/${GEN_FILE}" ] && log_info "  ${GEN_FILE}"
[ -f "${PROJECT_ROOT}/${XCF_DYN_FILE}" ] && log_info "  ${XCF_DYN_FILE}"
[ -f "${PROJECT_ROOT}/${XCF_STATIC_FILE}" ] && log_info "  ${XCF_STATIC_FILE}"
echo ""
log_info "Upload these files to GitHub releases."
