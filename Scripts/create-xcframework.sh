#!/bin/bash
# create-xcframework.sh - Create vips xcframeworks (dynamic and static)
# Produces per-platform vips.xcframework (dynamic and/or static)
# without any Objective-C wrapper - raw libvips + glib headers exposed directly.

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/env.sh"
source "${SCRIPT_DIR}/utils.sh"

# =============================================================================
# Parse Arguments
# =============================================================================
BUILD_DYNAMIC=true
BUILD_STATIC=true
TARGET_PLATFORM=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --dynamic-only)
            BUILD_STATIC=false
            shift
            ;;
        --static-only)
            BUILD_DYNAMIC=false
            shift
            ;;
        --platform)
            TARGET_PLATFORM="$2"
            shift 2
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [ -z "$TARGET_PLATFORM" ]; then
    log_error "--platform is required (ios, macos, visionos)"
    exit 1
fi

# =============================================================================
# Common Configuration
# =============================================================================
FRAMEWORK_NAME="vips"
TEMP_DIR="${BUILD_OUTPUT_DIR}/xcframework_temp/${TARGET_PLATFORM}"
XCF_OUTPUT_DIR="${BUILD_DIR}/xcframeworks/${TARGET_PLATFORM}"

# Per-platform slice configurations: slice_name:targets:archs
get_platform_slices() {
    case "$1" in
        ios)
            echo "ios-arm64:ios:arm64"
            echo "ios-arm64_x86_64-simulator:ios-sim-arm64,ios-sim-x86_64:arm64,x86_64"
            echo "ios-arm64_x86_64-maccatalyst:catalyst-arm64,catalyst-x86_64:arm64,x86_64"
            ;;
        macos)
            echo "macos-arm64_x86_64:macos-arm64,macos-x86_64:arm64,x86_64"
            ;;
        visionos)
            echo "xros-arm64:visionos:arm64"
            echo "xros-arm64-simulator:visionos-sim-arm64:arm64"
            ;;
    esac
}

# Read slices into array
SLICES=()
while IFS= read -r line; do
    [ -n "$line" ] && SLICES+=("$line")
done < <(get_platform_slices "$TARGET_PLATFORM")

if [ ${#SLICES[@]} -eq 0 ]; then
    log_error "Unknown platform: ${TARGET_PLATFORM}"
    exit 1
fi

# Get the deployment target for this platform (use first target of the platform)
get_platform_min_version() {
    local first_slice="${SLICES[0]}"
    IFS=':' read -r _ target_types _ <<< "$first_slice"
    IFS=',' read -ra target_array <<< "$target_types"
    get_target_deployment_target "${target_array[0]}"
}

PLATFORM_MIN_VERSION=$(get_platform_min_version)

# Static libraries to include (per target)
get_static_libs() {
    local target="$1"
    echo "${STAGING_DIR}/expat/${target}/lib/libexpat.a"
    echo "${STAGING_DIR}/libffi/${target}/lib/libffi.a"
    echo "${STAGING_DIR}/pcre2/${target}/lib/libpcre2-8.a"
    echo "${STAGING_DIR}/brotli/${target}/lib/libbrotlicommon.a"
    echo "${STAGING_DIR}/brotli/${target}/lib/libbrotlidec.a"
    echo "${STAGING_DIR}/brotli/${target}/lib/libbrotlienc.a"
    echo "${STAGING_DIR}/highway/${target}/lib/libhwy.a"
    echo "${STAGING_DIR}/glib/${target}/lib/libintl.a"
    echo "${STAGING_DIR}/glib/${target}/lib/libglib-2.0.a"
    echo "${STAGING_DIR}/glib/${target}/lib/libgmodule-2.0.a"
    echo "${STAGING_DIR}/glib/${target}/lib/libgobject-2.0.a"
    echo "${STAGING_DIR}/glib/${target}/lib/libgio-2.0.a"
    echo "${STAGING_DIR}/libjpeg-turbo/${target}/lib/libjpeg.a"
    echo "${STAGING_DIR}/libpng/${target}/lib/libpng16.a"
    echo "${STAGING_DIR}/libwebp/${target}/lib/libsharpyuv.a"
    echo "${STAGING_DIR}/libwebp/${target}/lib/libwebp.a"
    echo "${STAGING_DIR}/libwebp/${target}/lib/libwebpmux.a"
    echo "${STAGING_DIR}/libwebp/${target}/lib/libwebpdemux.a"
    echo "${STAGING_DIR}/dav1d/${target}/lib/libdav1d.a"
    echo "${STAGING_DIR}/libjxl/${target}/lib/libjxl.a"
    echo "${STAGING_DIR}/libjxl/${target}/lib/libjxl_threads.a"
    echo "${STAGING_DIR}/libjxl/${target}/lib/libjxl_cms.a"
    echo "${STAGING_DIR}/libheif/${target}/lib/libheif.a"
    echo "${STAGING_DIR}/fftw/${target}/lib/libfftw3.a"
    echo "${STAGING_DIR}/lcms2/${target}/lib/liblcms2.a"
    echo "${STAGING_DIR}/libtiff/${target}/lib/libtiff.a"
    echo "${STAGING_DIR}/libexif/${target}/lib/libexif.a"
    echo "${STAGING_DIR}/libvips/${target}/lib/libvips.a"
}

# =============================================================================
# Copy Headers
# =============================================================================
copy_headers() {
    local target="$1"
    local headers_dir="$2"

    mkdir -p "${headers_dir}"

    # vips headers
    if [ -d "${STAGING_DIR}/libvips/${target}/include/vips" ]; then
        cp -R "${STAGING_DIR}/libvips/${target}/include/vips" "${headers_dir}/vips"
    fi

    # glib top-level headers
    local glib_include="${STAGING_DIR}/glib/${target}/include/glib-2.0"
    if [ -d "$glib_include" ]; then
        for header in glib.h glib-object.h glib-unix.h gmodule.h; do
            if [ -f "${glib_include}/${header}" ]; then
                cp "${glib_include}/${header}" "${headers_dir}/"
            fi
        done
        # glib subdirectories
        for subdir in glib gobject gio gmodule; do
            if [ -d "${glib_include}/${subdir}" ]; then
                cp -R "${glib_include}/${subdir}" "${headers_dir}/${subdir}"
            fi
        done
    fi

    # glibconfig.h (lives in lib/glib-2.0/include/)
    local glibconfig="${STAGING_DIR}/glib/${target}/lib/glib-2.0/include/glibconfig.h"
    if [ -f "$glibconfig" ]; then
        cp "$glibconfig" "${headers_dir}/"
    fi
}

# =============================================================================
# Create Info.plist
# =============================================================================
create_framework_plist() {
    local output_dir="$1"
    local framework_name="$2"
    cat > "${output_dir}/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${framework_name}</string>
    <key>CFBundleIdentifier</key>
    <string>org.libvips.vips</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${framework_name}</string>
    <key>CFBundlePackageType</key>
    <string>FMWK</string>
    <key>CFBundleShortVersionString</key>
    <string>${LIBVIPS_VERSION}</string>
    <key>CFBundleVersion</key>
    <string>${LIBVIPS_VERSION}</string>
    <key>MinimumOSVersion</key>
    <string>${PLATFORM_MIN_VERSION}</string>
</dict>
</plist>
EOF
}

# =============================================================================
# Create Umbrella Header
# =============================================================================
create_umbrella_header() {
    local output_dir="$1"
    cat > "${output_dir}/Headers/vips.h" << 'EOF'
#ifndef VIPS_H
#define VIPS_H

#include <vips/vips.h>

#endif /* VIPS_H */
EOF
}

# =============================================================================
# Create Module Map
# =============================================================================
create_dynamic_module_map() {
    local output_dir="$1"
    mkdir -p "${output_dir}/Modules"
    cat > "${output_dir}/Modules/module.modulemap" << 'EOF'
framework module vips {
    umbrella header "vips.h"

    export *
    module * { export * }

    link "z"
    link "iconv"
    link "resolv"
    link "c++"
}
EOF
}

create_static_module_map() {
    local output_dir="$1"
    mkdir -p "${output_dir}/Modules"
    cat > "${output_dir}/Modules/module.modulemap" << 'EOF'
framework module vips {
    umbrella header "vips.h"

    export *
    module * { export * }

    link "z"
    link "iconv"
    link "resolv"
    link "c++"
}
EOF
}

# =============================================================================
# Dynamic Framework: Build dylib for a single target
# =============================================================================
build_dylib_for_target() {
    local target="$1"
    local arch=$(get_target_arch "$target")
    local sdk=$(get_target_sdk "$target")
    local output_dir="$2"

    echo "    Linking dylib for ${target} (${arch})..." >&2

    local sdk_path=$(get_sdk_path "$sdk")
    local cc=$(get_cc "$sdk")
    local cflags=$(get_cflags "$arch" "$sdk" "$target")

    # Build static lib list with -force_load for glib and libvips
    local static_libs=""
    static_libs+=" ${STAGING_DIR}/expat/${target}/lib/libexpat.a"
    static_libs+=" ${STAGING_DIR}/libffi/${target}/lib/libffi.a"
    static_libs+=" ${STAGING_DIR}/pcre2/${target}/lib/libpcre2-8.a"
    static_libs+=" ${STAGING_DIR}/brotli/${target}/lib/libbrotlicommon.a"
    static_libs+=" ${STAGING_DIR}/brotli/${target}/lib/libbrotlidec.a"
    static_libs+=" ${STAGING_DIR}/brotli/${target}/lib/libbrotlienc.a"
    static_libs+=" ${STAGING_DIR}/highway/${target}/lib/libhwy.a"
    static_libs+=" ${STAGING_DIR}/glib/${target}/lib/libintl.a"
    # CRITICAL: Use -force_load for glib to ensure __attribute__((constructor))
    # initialization functions are included. Without this, glib's hash table
    # infrastructure is not properly initialized, causing crashes.
    static_libs+=" -force_load ${STAGING_DIR}/glib/${target}/lib/libglib-2.0.a"
    static_libs+=" ${STAGING_DIR}/glib/${target}/lib/libgmodule-2.0.a"
    static_libs+=" -force_load ${STAGING_DIR}/glib/${target}/lib/libgobject-2.0.a"
    static_libs+=" ${STAGING_DIR}/glib/${target}/lib/libgio-2.0.a"
    static_libs+=" ${STAGING_DIR}/libjpeg-turbo/${target}/lib/libjpeg.a"
    static_libs+=" ${STAGING_DIR}/libpng/${target}/lib/libpng16.a"
    static_libs+=" ${STAGING_DIR}/libwebp/${target}/lib/libsharpyuv.a"
    static_libs+=" ${STAGING_DIR}/libwebp/${target}/lib/libwebp.a"
    static_libs+=" ${STAGING_DIR}/libwebp/${target}/lib/libwebpmux.a"
    static_libs+=" ${STAGING_DIR}/libwebp/${target}/lib/libwebpdemux.a"
    static_libs+=" ${STAGING_DIR}/dav1d/${target}/lib/libdav1d.a"
    static_libs+=" ${STAGING_DIR}/libjxl/${target}/lib/libjxl.a"
    static_libs+=" ${STAGING_DIR}/libjxl/${target}/lib/libjxl_threads.a"
    static_libs+=" ${STAGING_DIR}/libjxl/${target}/lib/libjxl_cms.a"
    static_libs+=" ${STAGING_DIR}/libheif/${target}/lib/libheif.a"
    static_libs+=" ${STAGING_DIR}/fftw/${target}/lib/libfftw3.a"
    static_libs+=" ${STAGING_DIR}/lcms2/${target}/lib/liblcms2.a"
    static_libs+=" ${STAGING_DIR}/libtiff/${target}/lib/libtiff.a"
    static_libs+=" ${STAGING_DIR}/libexif/${target}/lib/libexif.a"
    # Use -force_load for libvips to ensure all public symbols are exported
    static_libs+=" -force_load ${STAGING_DIR}/libvips/${target}/lib/libvips.a"

    local dylib="${output_dir}/vips_${arch}.dylib"

    # Determine platform-specific frameworks
    # glib 2.87+ uses Objective-C on Apple platforms (Foundation, CoreFoundation)
    # and AppKit on macOS (NSWorkspace etc.)
    local platform_libs="-lobjc -framework Foundation -framework CoreFoundation"
    local sdk=$(get_target_sdk "$target")
    case "$target" in
        macos-*|catalyst-*)
            platform_libs+=" -framework AppKit"
            ;;
    esac

    # Link everything into a dylib
    # -Wl,-w suppresses linker warnings (e.g., libffi alignment warning on x86_64)
    "$cc" $cflags \
        -dynamiclib \
        -Wl,-w \
        -install_name "@rpath/vips.framework/vips" \
        -o "$dylib" \
        $static_libs \
        -lz -liconv -lresolv -lc++ $platform_libs

    # Return the path via stdout
    echo "$dylib"
}

# Create fat dylib from multiple architectures
create_fat_dylib() {
    local output="$1"
    shift
    local inputs=("$@")

    if [ ${#inputs[@]} -eq 1 ]; then
        cp "${inputs[0]}" "$output"
    else
        lipo -create "${inputs[@]}" -output "$output"
    fi
}

# =============================================================================
# Dynamic Framework
# =============================================================================
build_dynamic_xcframework() {
    log_step "Creating vips.xcframework (dynamic) for ${TARGET_PLATFORM}"

    local xcf_dir="${XCF_OUTPUT_DIR}/dynamic/vips.xcframework"
    local temp="${TEMP_DIR}/dynamic"

    rm -rf "$xcf_dir"
    rm -rf "$temp"
    mkdir -p "$temp"

    for slice_config in "${SLICES[@]}"; do
        IFS=':' read -r slice_name target_types archs <<< "$slice_config"

        log_info "Processing slice: ${slice_name}"

        # Create framework structure
        local framework_dir="${temp}/${slice_name}/vips.framework"
        mkdir -p "${framework_dir}/Headers"

        # Split target types and archs
        IFS=',' read -ra target_array <<< "$target_types"
        IFS=',' read -ra arch_array <<< "$archs"

        local slice_build_dir="${temp}/${slice_name}/build"
        mkdir -p "$slice_build_dir"

        local arch_dylibs=()

        for i in "${!target_array[@]}"; do
            local target_type="${target_array[$i]}"
            local dylib=$(build_dylib_for_target "$target_type" "$slice_build_dir")
            arch_dylibs+=("$dylib")
        done

        # Create fat binary
        log_info "  Creating framework binary..."
        create_fat_dylib "${framework_dir}/vips" "${arch_dylibs[@]}"

        # Copy headers (use first target for headers)
        copy_headers "${target_array[0]}" "${framework_dir}/Headers"

        # Create umbrella header
        create_umbrella_header "$framework_dir"

        # Create Info.plist
        create_framework_plist "$framework_dir" "$FRAMEWORK_NAME"

        # Create module map
        create_dynamic_module_map "$framework_dir"

        # Show info
        local size=$(ls -lh "${framework_dir}/vips" | awk '{print $5}')
        local archs_info=$(lipo -info "${framework_dir}/vips" 2>/dev/null | sed 's/.*: //' || echo "unknown")
        log_info "  Framework: ${archs_info} (${size})"
    done

    # Create xcframework
    log_info "Creating xcframework..."

    local xcframework_args=()
    for slice_config in "${SLICES[@]}"; do
        IFS=':' read -r slice_name _ _ <<< "$slice_config"
        local framework_dir="${temp}/${slice_name}/vips.framework"
        xcframework_args+=(-framework "$framework_dir")
    done

    mkdir -p "$(dirname "$xcf_dir")"
    xcodebuild -create-xcframework \
        "${xcframework_args[@]}" \
        -output "$xcf_dir"

    # Cleanup
    rm -rf "$temp"

    # Verify
    log_step "Verifying vips.xcframework (dynamic, ${TARGET_PLATFORM})"
    for dir in "${xcf_dir}"/*; do
        if [ -d "$dir" ] && [ -d "${dir}/vips.framework" ]; then
            local slice=$(basename "$dir")
            local binary="${dir}/vips.framework/vips"
            if [ -f "$binary" ]; then
                local archs=$(lipo -info "$binary" 2>/dev/null | sed 's/.*: //' || echo "unknown")
                local size=$(ls -lh "$binary" | awk '{print $5}')
                log_success "${slice}: ${archs} (${size})"
            fi
        fi
    done

    log_success "Created vips.xcframework (dynamic) for ${TARGET_PLATFORM}"
}

# =============================================================================
# Static Framework
# =============================================================================
build_static_xcframework() {
    log_step "Creating vips.xcframework (static) for ${TARGET_PLATFORM}"

    local xcf_dir="${XCF_OUTPUT_DIR}/static/vips.xcframework"
    local temp="${TEMP_DIR}/static"

    rm -rf "$xcf_dir"
    rm -rf "$temp"
    mkdir -p "$temp"

    for slice_config in "${SLICES[@]}"; do
        IFS=':' read -r slice_name target_types archs <<< "$slice_config"

        log_info "Processing slice: ${slice_name}"

        # Create framework structure
        local framework_dir="${temp}/${slice_name}/vips.framework"
        mkdir -p "${framework_dir}/Headers"

        # Split target types and archs
        IFS=',' read -ra target_array <<< "$target_types"
        IFS=',' read -ra arch_array <<< "$archs"

        local slice_build_dir="${temp}/${slice_name}/build"
        mkdir -p "$slice_build_dir"

        local arch_archives=()

        for i in "${!target_array[@]}"; do
            local target_type="${target_array[$i]}"
            local arch="${arch_array[$i]}"

            echo "    Merging static libraries for ${target_type} (${arch})..." >&2

            # Merge all .a files into one
            local merged="${slice_build_dir}/vips_${arch}.a"
            local libs=()
            while IFS= read -r lib; do
                libs+=("$lib")
            done < <(get_static_libs "$target_type")

            libtool -static -o "$merged" "${libs[@]}"
            arch_archives+=("$merged")
        done

        # Create fat archive (must use .a extension for xcodebuild -create-xcframework)
        log_info "  Creating framework archive..."
        if [ ${#arch_archives[@]} -eq 1 ]; then
            cp "${arch_archives[0]}" "${framework_dir}/vips.a"
        else
            lipo -create "${arch_archives[@]}" -output "${framework_dir}/vips.a"
        fi

        # Copy headers (use first target for headers)
        copy_headers "${target_array[0]}" "${framework_dir}/Headers"

        # Create umbrella header
        create_umbrella_header "$framework_dir"

        # Create Info.plist
        create_framework_plist "$framework_dir" "$FRAMEWORK_NAME"

        # Create module map
        create_static_module_map "$framework_dir"

        # Show info
        local size=$(ls -lh "${framework_dir}/vips.a" | awk '{print $5}')
        local archs_info=$(lipo -info "${framework_dir}/vips.a" 2>/dev/null | sed 's/.*: //' || echo "unknown")
        log_info "  Framework: ${archs_info} (${size})"
    done

    # Create xcframework
    log_info "Creating xcframework..."

    local xcframework_args=()
    for slice_config in "${SLICES[@]}"; do
        IFS=':' read -r slice_name _ _ <<< "$slice_config"
        local framework_dir="${temp}/${slice_name}/vips.framework"
        xcframework_args+=(-library "${framework_dir}/vips.a" -headers "${framework_dir}/Headers")
    done

    mkdir -p "$(dirname "$xcf_dir")"
    xcodebuild -create-xcframework \
        "${xcframework_args[@]}" \
        -output "$xcf_dir"

    # Cleanup
    rm -rf "$temp"

    # Verify
    log_step "Verifying vips.xcframework (static, ${TARGET_PLATFORM})"
    for dir in "${xcf_dir}"/*; do
        if [ -d "$dir" ]; then
            local slice=$(basename "$dir")
            # Static xcframework uses library layout, not framework layout
            local binary=""
            if [ -f "${dir}/vips.a" ]; then
                binary="${dir}/vips.a"
            elif [ -f "${dir}/vips.framework/vips.a" ]; then
                binary="${dir}/vips.framework/vips.a"
            fi
            if [ -n "$binary" ] && [ -f "$binary" ]; then
                local archs=$(lipo -info "$binary" 2>/dev/null | sed 's/.*: //' || echo "unknown")
                local size=$(ls -lh "$binary" | awk '{print $5}')
                log_success "${slice}: ${archs} (${size})"
            fi
        fi
    done

    log_success "Created vips.xcframework (static) for ${TARGET_PLATFORM}"
}

# =============================================================================
# Main
# =============================================================================
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

if [ "$BUILD_DYNAMIC" = true ]; then
    build_dynamic_xcframework
fi

if [ "$BUILD_STATIC" = true ]; then
    build_static_xcframework
fi

rm -rf "$TEMP_DIR"

echo ""
if [ "$BUILD_DYNAMIC" = true ]; then
    echo "Dynamic (${TARGET_PLATFORM}): ${XCF_OUTPUT_DIR}/dynamic/vips.xcframework"
fi
if [ "$BUILD_STATIC" = true ]; then
    echo "Static  (${TARGET_PLATFORM}): ${XCF_OUTPUT_DIR}/static/vips.xcframework"
fi
echo ""
