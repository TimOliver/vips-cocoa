#!/bin/bash
# create-spm-xcframework.sh - Combine per-platform xcframeworks into
# single all-platform xcframeworks for SPM binary target distribution.
#
# This script does NOT rebuild anything. It extracts the framework/library
# slices from each per-platform xcframework and feeds them to
# xcodebuild -create-xcframework to produce combined xcframeworks.
#
# Usage: ./Scripts/create-spm-xcframework.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

log_info() {
    echo -e "${GREEN}[SPM XCFramework]${NC} $1"
}

log_error() {
    echo -e "${RED}[SPM XCFramework]${NC} $1"
}

XCF_BASE="${PROJECT_ROOT}/build/xcframeworks"
SPM_OUTPUT="${XCF_BASE}/spm"
PLATFORMS="ios macos visionos"

# =============================================================================
# Dynamic: Combine per-platform dynamic xcframeworks
# =============================================================================
build_combined_dynamic() {
    log_info "Creating combined dynamic vips.xcframework..."

    local output_dir="${SPM_OUTPUT}/dynamic"
    rm -rf "$output_dir"
    mkdir -p "$output_dir"

    local xcf_args=()

    for platform in $PLATFORMS; do
        local xcf="${XCF_BASE}/${platform}/dynamic/vips.xcframework"
        if [ ! -d "$xcf" ]; then
            log_error "Missing: ${xcf}"
            exit 1
        fi

        # Each slice directory inside the xcframework contains a vips.framework
        for slice_dir in "${xcf}"/*/; do
            [ -d "$slice_dir" ] || continue
            local slice_name=$(basename "$slice_dir")

            # Skip Info.plist (it's a file, not a directory, but be safe)
            [ "$slice_name" = "Info.plist" ] && continue

            local framework="${slice_dir}vips.framework"
            if [ -d "$framework" ]; then
                log_info "  ${platform}: ${slice_name}"
                xcf_args+=(-framework "$framework")
            fi
        done
    done

    if [ ${#xcf_args[@]} -eq 0 ]; then
        log_error "No framework slices found!"
        exit 1
    fi

    xcodebuild -create-xcframework \
        "${xcf_args[@]}" \
        -output "${output_dir}/vips.xcframework"

    log_info "Created: ${output_dir}/vips.xcframework"

    # Verify
    local slice_count=0
    for dir in "${output_dir}/vips.xcframework"/*/; do
        [ -d "$dir" ] || continue
        local name=$(basename "$dir")
        [ "$name" = "Info.plist" ] && continue
        slice_count=$((slice_count + 1))
        log_info "  Slice: ${name}"
    done
    log_info "Total slices: ${slice_count}"
}

# =============================================================================
# Static: Combine per-platform static xcframeworks
# =============================================================================
build_combined_static() {
    log_info "Creating combined static vips.xcframework..."

    local output_dir="${SPM_OUTPUT}/static"
    rm -rf "$output_dir"
    mkdir -p "$output_dir"

    local xcf_args=()

    for platform in $PLATFORMS; do
        local xcf="${XCF_BASE}/${platform}/static/vips.xcframework"
        if [ ! -d "$xcf" ]; then
            log_error "Missing: ${xcf}"
            exit 1
        fi

        # Static xcframework slices contain vips.a + Headers/
        for slice_dir in "${xcf}"/*/; do
            [ -d "$slice_dir" ] || continue
            local slice_name=$(basename "$slice_dir")

            # Skip Info.plist
            [ "$slice_name" = "Info.plist" ] && continue

            # Find the static library (could be at vips.a or inside a framework bundle)
            local static_lib=""
            local headers_dir=""

            if [ -f "${slice_dir}vips.a" ]; then
                static_lib="${slice_dir}vips.a"
                headers_dir="${slice_dir}Headers"
            elif [ -f "${slice_dir}vips.framework/vips.a" ]; then
                static_lib="${slice_dir}vips.framework/vips.a"
                headers_dir="${slice_dir}vips.framework/Headers"
            fi

            if [ -n "$static_lib" ] && [ -f "$static_lib" ] && [ -d "$headers_dir" ]; then
                log_info "  ${platform}: ${slice_name}"
                xcf_args+=(-library "$static_lib" -headers "$headers_dir")
            fi
        done
    done

    if [ ${#xcf_args[@]} -eq 0 ]; then
        log_error "No static library slices found!"
        exit 1
    fi

    xcodebuild -create-xcframework \
        "${xcf_args[@]}" \
        -output "${output_dir}/vips.xcframework"

    log_info "Created: ${output_dir}/vips.xcframework"

    # Verify
    local slice_count=0
    for dir in "${output_dir}/vips.xcframework"/*/; do
        [ -d "$dir" ] || continue
        local name=$(basename "$dir")
        [ "$name" = "Info.plist" ] && continue
        slice_count=$((slice_count + 1))
        log_info "  Slice: ${name}"
    done
    log_info "Total slices: ${slice_count}"
}

# =============================================================================
# Main
# =============================================================================
log_info "Combining per-platform xcframeworks for SPM..."

build_combined_dynamic
build_combined_static

echo ""
log_info "Dynamic: ${SPM_OUTPUT}/dynamic/vips.xcframework"
log_info "Static:  ${SPM_OUTPUT}/static/vips.xcframework"
echo ""
