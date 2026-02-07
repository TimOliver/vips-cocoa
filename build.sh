#!/bin/bash
# build.sh - Main build orchestrator for vips-cocoa
# Builds libvips and all dependencies as universal xcframeworks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/Scripts/env.sh"
source "${SCRIPT_DIR}/Scripts/utils.sh"

# =============================================================================
# Help and Usage
# =============================================================================
show_help() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Build libvips as universal xcframeworks for Apple platforms.

Options:
    -h, --help              Show this help message
    -c, --clean             Clean all build artifacts before building
    -d, --download-only     Download sources only, don't build
    -s, --skip-download     Skip downloading sources (use existing)
    -l, --list              List all libraries and versions
    -j, --jobs N            Number of parallel jobs (default: auto)
    -f, --framework         Rebuild xcframeworks only (fast iteration)
    --platform PLATFORMS    Comma-separated list of platforms to build
                            (ios,macos,visionos; default: all)
    --dynamic-only          Build only dynamic xcframework
    --static-only           Build only static xcframework
    --skip-to LIB           Skip to building specific library
    --only LIB              Build only specific library

Libraries (in build order):
    expat, libffi, pcre2, libjpeg-turbo, libpng, brotli, highway,
    fftw, lcms2, libexif, glib, libwebp, dav1d, libtiff,
    libjxl, libheif, libvips

Examples:
    $(basename "$0")                        # Full build (all platforms)
    $(basename "$0") --platform ios         # Build iOS only
    $(basename "$0") --platform ios,macos   # Build iOS + macOS
    $(basename "$0") -c                     # Clean build
    $(basename "$0") -f                     # Rebuild xcframeworks only (fast)
    $(basename "$0") -f --dynamic-only      # Rebuild dynamic xcframework only
    $(basename "$0") -f --platform macos    # Rebuild macOS xcframeworks only
    $(basename "$0") --skip-to glib         # Skip to glib (assume deps built)
    $(basename "$0") --only libvips         # Build only libvips

EOF
}

list_libraries() {
    cat << EOF
Library Versions:
    expat:          ${EXPAT_VERSION}
    libffi:         ${LIBFFI_VERSION}
    pcre2:          ${PCRE2_VERSION}
    libjpeg-turbo:  ${LIBJPEG_TURBO_VERSION}
    libpng:         ${LIBPNG_VERSION}
    libwebp:        ${LIBWEBP_VERSION}
    brotli:         ${BROTLI_VERSION}
    highway:        ${HIGHWAY_VERSION}
    fftw:           ${FFTW_VERSION}
    lcms2:          ${LCMS2_VERSION}
    libexif:        ${LIBEXIF_VERSION}
    glib:           ${GLIB_VERSION}
    dav1d:          ${DAV1D_VERSION}
    libtiff:        ${LIBTIFF_VERSION}
    libjxl:         ${LIBJXL_VERSION}
    libheif:        ${LIBHEIF_VERSION}
    libvips:        ${LIBVIPS_VERSION}

Platforms:
    iOS (min ${IOS_MIN_VERSION}):        device arm64, simulator arm64/x86_64, Mac Catalyst arm64/x86_64
    macOS (min ${MACOS_MIN_VERSION}):      arm64, x86_64
    visionOS (min ${VISIONOS_MIN_VERSION}):   device arm64, simulator arm64

Active: ${ACTIVE_PLATFORMS}
EOF
}

# =============================================================================
# Parse Arguments
# =============================================================================
CLEAN=false
DOWNLOAD_ONLY=false
SKIP_DOWNLOAD=false
FRAMEWORK_ONLY=false
SKIP_TO=""
ONLY_LIB=""
XCF_ARGS=()

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--help)
            show_help
            exit 0
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        -d|--download-only)
            DOWNLOAD_ONLY=true
            shift
            ;;
        -s|--skip-download)
            SKIP_DOWNLOAD=true
            shift
            ;;
        -l|--list)
            list_libraries
            exit 0
            ;;
        -j|--jobs)
            JOBS="$2"
            shift 2
            ;;
        -f|--framework)
            FRAMEWORK_ONLY=true
            shift
            ;;
        --dynamic-only)
            XCF_ARGS+=("--dynamic-only")
            shift
            ;;
        --static-only)
            XCF_ARGS+=("--static-only")
            shift
            ;;
        --platform)
            ACTIVE_PLATFORMS="${2//,/ }"
            export ACTIVE_PLATFORMS
            export TARGETS=$(get_active_targets)
            shift 2
            ;;
        --skip-to)
            SKIP_TO="$2"
            shift 2
            ;;
        --only)
            ONLY_LIB="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# =============================================================================
# Prerequisites Check
# =============================================================================
check_prerequisites() {
    log_step "Checking prerequisites"

    local missing=()

    # Check for required tools
    command -v cmake >/dev/null 2>&1 || missing+=("cmake")
    command -v meson >/dev/null 2>&1 || missing+=("meson")
    command -v ninja >/dev/null 2>&1 || missing+=("ninja")
    command -v pkg-config >/dev/null 2>&1 || missing+=("pkg-config")
    command -v xcodebuild >/dev/null 2>&1 || missing+=("xcodebuild (Xcode)")
    command -v xcrun >/dev/null 2>&1 || missing+=("xcrun (Xcode Command Line Tools)")

    if [ ${#missing[@]} -gt 0 ]; then
        log_error "Missing required tools: ${missing[*]}"
        echo ""
        echo "Install with:"
        echo "  brew install cmake meson ninja pkg-config"
        echo "  xcode-select --install"
        exit 1
    fi

    # Check Xcode SDK availability per active platform
    for platform in $ACTIVE_PLATFORMS; do
        case "$platform" in
            ios)
                if ! xcrun --sdk iphoneos --show-sdk-path >/dev/null 2>&1; then
                    log_error "iOS SDK not found. Please install Xcode with iOS support."
                    exit 1
                fi
                ;;
            macos)
                if ! xcrun --sdk macosx --show-sdk-path >/dev/null 2>&1; then
                    log_error "macOS SDK not found. Please install Xcode."
                    exit 1
                fi
                ;;
            visionos)
                if ! xcrun --sdk xros --show-sdk-path >/dev/null 2>&1; then
                    log_error "visionOS SDK not found. Please install Xcode with visionOS support."
                    exit 1
                fi
                ;;
        esac
    done

    log_success "All prerequisites satisfied"
}

# =============================================================================
# Collect Generated Files
# =============================================================================
collect_generated_files() {
    log_step "Collecting generated files"

    local gen_dir="${BUILD_OUTPUT_DIR}/libvips-generated"

    # Use the first available target's build output
    local first_target
    first_target=$(echo "$TARGETS" | awk '{print $1}')
    local src_dir="${BUILD_OUTPUT_DIR}/libvips/${first_target}"

    mkdir -p "$gen_dir"

    # config.h from meson configure
    if [ -f "${src_dir}/config.h" ]; then
        cp "${src_dir}/config.h" "${gen_dir}/"
        log_info "Copied config.h"
    else
        log_warning "config.h not found in ${src_dir}"
    fi

    # vipsmarshal.c/h from glib-genmarshal
    for f in vipsmarshal.c vipsmarshal.h; do
        if [ -f "${src_dir}/${f}" ]; then
            cp "${src_dir}/${f}" "${gen_dir}/"
            log_info "Copied ${f}"
        else
            log_warning "${f} not found in ${src_dir}"
        fi
    done

    # enumtypes.c/h from glib-mkenums
    for f in enumtypes.c enumtypes.h; do
        if [ -f "${src_dir}/${f}" ]; then
            cp "${src_dir}/${f}" "${gen_dir}/"
            log_info "Copied ${f}"
        else
            log_warning "${f} not found in ${src_dir}"
        fi
    done

    log_success "Generated files collected in ${gen_dir}"
}

# =============================================================================
# Build Libraries
# =============================================================================
# Build order (respecting dependencies)
BUILD_ORDER=(
    "expat"
    "libffi"
    "pcre2"
    "libjpeg-turbo"
    "libpng"
    "brotli"
    "highway"
    "fftw"
    "lcms2"
    "libexif"
    "glib"
    "libwebp"
    "dav1d"
    "libtiff"
    "libjxl"
    "libheif"
    "libvips"
)

should_build() {
    local lib="$1"

    # If --only specified, only build that library
    if [ -n "$ONLY_LIB" ]; then
        [ "$lib" = "$ONLY_LIB" ]
        return
    fi

    # If --skip-to specified, skip until we reach that library
    if [ -n "$SKIP_TO" ]; then
        if [ "$SKIP_TO_REACHED" != "true" ]; then
            if [ "$lib" = "$SKIP_TO" ]; then
                SKIP_TO_REACHED=true
                return 0
            fi
            return 1
        fi
    fi

    return 0
}

build_library() {
    local lib="$1"
    local script="${SCRIPTS_DIR}/build-${lib}.sh"

    if [ ! -f "$script" ]; then
        log_error "Build script not found: ${script}"
        return 1
    fi

    log_step "Building ${lib}"
    bash "$script"
}

# =============================================================================
# Main Build Process
# =============================================================================
main() {
    local start_time=$(date +%s)

    echo "=================================================="
    echo "  vips-cocoa build system"
    echo "  Building libvips ${LIBVIPS_VERSION}"
    echo "  Platforms: ${ACTIVE_PLATFORMS}"
    echo "=================================================="
    echo ""

    check_prerequisites

    # Clean if requested
    if [ "$CLEAN" = true ]; then
        log_step "Cleaning build artifacts"
        clean_all
    fi

    # Framework-only mode: just rebuild the xcframeworks
    if [ "$FRAMEWORK_ONLY" = true ]; then
        log_step "Rebuilding xcframeworks only"
        for platform in $ACTIVE_PLATFORMS; do
            bash "${SCRIPTS_DIR}/create-xcframework.sh" --platform "$platform" "${XCF_ARGS[@]}"
        done

        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        echo ""
        log_success "Xcframeworks rebuilt in ${duration}s"
        return
    fi

    # Download sources
    if [ "$SKIP_DOWNLOAD" != true ]; then
        bash "${SCRIPTS_DIR}/download-sources.sh"
    fi

    if [ "$DOWNLOAD_ONLY" = true ]; then
        log_success "Download complete"
        exit 0
    fi

    # Build all libraries
    SKIP_TO_REACHED=false
    for lib in "${BUILD_ORDER[@]}"; do
        if should_build "$lib"; then
            build_library "$lib"
        else
            log_info "Skipping ${lib}"
        fi
    done

    # Collect generated files for downstream consumers
    collect_generated_files

    # Create xcframeworks (per platform)
    if [ -z "$ONLY_LIB" ] || [ "$ONLY_LIB" = "xcframework" ]; then
        for platform in $ACTIVE_PLATFORMS; do
            bash "${SCRIPTS_DIR}/create-xcframework.sh" --platform "$platform" "${XCF_ARGS[@]}"
        done
    fi

    # Report completion
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local minutes=$((duration / 60))
    local seconds=$((duration % 60))

    echo ""
    echo "=================================================="
    log_success "Build completed in ${minutes}m ${seconds}s"
    echo "=================================================="
    echo ""
    echo "Output:"
    local xcf_base="${BUILD_DIR}/xcframeworks"
    for platform in $ACTIVE_PLATFORMS; do
        [ -d "${xcf_base}/${platform}/dynamic/vips.xcframework" ] && echo "  Dynamic (${platform}): ${xcf_base}/${platform}/dynamic/vips.xcframework"
        [ -d "${xcf_base}/${platform}/static/vips.xcframework" ] && echo "  Static  (${platform}): ${xcf_base}/${platform}/static/vips.xcframework"
    done
    echo ""
}

main "$@"
