#!/bin/bash
# create-xcframework.sh - Create libvips xcframeworks (dynamic and static)
# Produces libvips.xcframework (dynamic) and libvips-static.xcframework (static)
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
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# =============================================================================
# Common Configuration
# =============================================================================
TEMP_DIR="${BUILD_OUTPUT_DIR}/xcframework_temp"

# Platform configurations: platform_name:targets:archs
PLATFORMS=(
    "ios-arm64:ios:arm64"
    "ios-arm64_x86_64-simulator:ios-sim-arm64,ios-sim-x86_64:arm64,x86_64"
    "ios-arm64_x86_64-maccatalyst:catalyst-arm64,catalyst-x86_64:arm64,x86_64"
)

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
    <string>org.libvips.libvips</string>
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
    <string>${IOS_MIN_VERSION}</string>
</dict>
</plist>
EOF
}

# =============================================================================
# Create Umbrella Header
# =============================================================================
create_umbrella_header() {
    local output_dir="$1"
    cat > "${output_dir}/Headers/libvips.h" << 'EOF'
#ifndef LIBVIPS_H
#define LIBVIPS_H

#include <vips/vips.h>

#endif /* LIBVIPS_H */
EOF
}

# =============================================================================
# Create Module Map
# =============================================================================
create_dynamic_module_map() {
    local output_dir="$1"
    mkdir -p "${output_dir}/Modules"
    cat > "${output_dir}/Modules/module.modulemap" << 'EOF'
framework module libvips {
    umbrella header "libvips.h"

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
framework module libvips {
    umbrella header "libvips.h"

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
    # Use -force_load for libvips to ensure all public symbols are exported
    static_libs+=" -force_load ${STAGING_DIR}/libvips/${target}/lib/libvips.a"

    local dylib="${output_dir}/libvips_${arch}.dylib"

    # Link everything into a dylib
    # -Wl,-w suppresses linker warnings (e.g., libffi alignment warning on x86_64)
    "$cc" $cflags \
        -dynamiclib \
        -Wl,-w \
        -install_name "@rpath/libvips.framework/libvips" \
        -o "$dylib" \
        $static_libs \
        -lz -liconv -lresolv -lc++

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
    log_step "Creating libvips.xcframework (dynamic)"

    local xcf_dir="${OUTPUT_DIR}/libvips.xcframework"
    local temp="${TEMP_DIR}/dynamic"

    rm -rf "$xcf_dir"
    rm -rf "$temp"
    mkdir -p "$temp"

    for platform_config in "${PLATFORMS[@]}"; do
        IFS=':' read -r platform_name target_types archs <<< "$platform_config"

        log_info "Processing platform: ${platform_name}"

        # Create framework structure
        local framework_dir="${temp}/${platform_name}/libvips.framework"
        mkdir -p "${framework_dir}/Headers"

        # Split target types and archs
        IFS=',' read -ra target_array <<< "$target_types"
        IFS=',' read -ra arch_array <<< "$archs"

        local platform_build_dir="${temp}/${platform_name}/build"
        mkdir -p "$platform_build_dir"

        local arch_dylibs=()

        for i in "${!target_array[@]}"; do
            local target_type="${target_array[$i]}"
            local dylib=$(build_dylib_for_target "$target_type" "$platform_build_dir")
            arch_dylibs+=("$dylib")
        done

        # Create fat binary
        log_info "  Creating framework binary..."
        create_fat_dylib "${framework_dir}/libvips" "${arch_dylibs[@]}"

        # Copy headers (use first target for headers)
        copy_headers "${target_array[0]}" "${framework_dir}/Headers"

        # Create umbrella header
        create_umbrella_header "$framework_dir"

        # Create Info.plist
        create_framework_plist "$framework_dir" "libvips"

        # Create module map
        create_dynamic_module_map "$framework_dir"

        # Show info
        local size=$(ls -lh "${framework_dir}/libvips" | awk '{print $5}')
        local archs_info=$(lipo -info "${framework_dir}/libvips" 2>/dev/null | sed 's/.*: //' || echo "unknown")
        log_info "  Framework: ${archs_info} (${size})"
    done

    # Create xcframework
    log_info "Creating xcframework..."

    local xcframework_args=()
    for platform_config in "${PLATFORMS[@]}"; do
        IFS=':' read -r platform_name _ _ <<< "$platform_config"
        local framework_dir="${temp}/${platform_name}/libvips.framework"
        xcframework_args+=(-framework "$framework_dir")
    done

    mkdir -p "$OUTPUT_DIR"
    xcodebuild -create-xcframework \
        "${xcframework_args[@]}" \
        -output "$xcf_dir"

    # Cleanup
    rm -rf "$temp"

    # Verify
    log_step "Verifying libvips.xcframework"
    for dir in "${xcf_dir}"/*; do
        if [ -d "$dir" ] && [ -d "${dir}/libvips.framework" ]; then
            local platform=$(basename "$dir")
            local binary="${dir}/libvips.framework/libvips"
            if [ -f "$binary" ]; then
                local archs=$(lipo -info "$binary" 2>/dev/null | sed 's/.*: //' || echo "unknown")
                local size=$(ls -lh "$binary" | awk '{print $5}')
                log_success "${platform}: ${archs} (${size})"
            fi
        fi
    done

    log_success "Created libvips.xcframework"
}

# =============================================================================
# Static Framework
# =============================================================================
build_static_xcframework() {
    log_step "Creating libvips-static.xcframework (static)"

    local xcf_dir="${OUTPUT_DIR}/libvips-static.xcframework"
    local temp="${TEMP_DIR}/static"

    rm -rf "$xcf_dir"
    rm -rf "$temp"
    mkdir -p "$temp"

    for platform_config in "${PLATFORMS[@]}"; do
        IFS=':' read -r platform_name target_types archs <<< "$platform_config"

        log_info "Processing platform: ${platform_name}"

        # Create framework structure
        local framework_dir="${temp}/${platform_name}/libvips.framework"
        mkdir -p "${framework_dir}/Headers"

        # Split target types and archs
        IFS=',' read -ra target_array <<< "$target_types"
        IFS=',' read -ra arch_array <<< "$archs"

        local platform_build_dir="${temp}/${platform_name}/build"
        mkdir -p "$platform_build_dir"

        local arch_archives=()

        for i in "${!target_array[@]}"; do
            local target_type="${target_array[$i]}"
            local arch="${arch_array[$i]}"

            echo "    Merging static libraries for ${target_type} (${arch})..." >&2

            # Merge all .a files into one
            local merged="${platform_build_dir}/libvips_${arch}.a"
            local libs=()
            while IFS= read -r lib; do
                libs+=("$lib")
            done < <(get_static_libs "$target_type")

            libtool -static -o "$merged" "${libs[@]}"
            arch_archives+=("$merged")
        done

        # Create fat archive
        log_info "  Creating framework archive..."
        if [ ${#arch_archives[@]} -eq 1 ]; then
            cp "${arch_archives[0]}" "${framework_dir}/libvips"
        else
            lipo -create "${arch_archives[@]}" -output "${framework_dir}/libvips"
        fi

        # Copy headers (use first target for headers)
        copy_headers "${target_array[0]}" "${framework_dir}/Headers"

        # Create umbrella header
        create_umbrella_header "$framework_dir"

        # Create Info.plist
        create_framework_plist "$framework_dir" "libvips"

        # Create module map
        create_static_module_map "$framework_dir"

        # Show info
        local size=$(ls -lh "${framework_dir}/libvips" | awk '{print $5}')
        local archs_info=$(lipo -info "${framework_dir}/libvips" 2>/dev/null | sed 's/.*: //' || echo "unknown")
        log_info "  Framework: ${archs_info} (${size})"
    done

    # Create xcframework
    log_info "Creating xcframework..."

    local xcframework_args=()
    for platform_config in "${PLATFORMS[@]}"; do
        IFS=':' read -r platform_name _ _ <<< "$platform_config"
        local framework_dir="${temp}/${platform_name}/libvips.framework"
        xcframework_args+=(-library "${framework_dir}/libvips" -headers "${framework_dir}/Headers")
    done

    mkdir -p "$OUTPUT_DIR"
    xcodebuild -create-xcframework \
        "${xcframework_args[@]}" \
        -output "$xcf_dir"

    # Cleanup
    rm -rf "$temp"

    # Verify
    log_step "Verifying libvips-static.xcframework"
    for dir in "${xcf_dir}"/*; do
        if [ -d "$dir" ]; then
            local platform=$(basename "$dir")
            # Static xcframework uses library layout, not framework layout
            local binary=""
            if [ -f "${dir}/libvips.framework/libvips" ]; then
                binary="${dir}/libvips.framework/libvips"
            elif [ -f "${dir}/libvips" ]; then
                binary="${dir}/libvips"
            fi
            if [ -n "$binary" ] && [ -f "$binary" ]; then
                local archs=$(lipo -info "$binary" 2>/dev/null | sed 's/.*: //' || echo "unknown")
                local size=$(ls -lh "$binary" | awk '{print $5}')
                log_success "${platform}: ${archs} (${size})"
            fi
        fi
    done

    log_success "Created libvips-static.xcframework"
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
    echo "Dynamic: ${OUTPUT_DIR}/libvips.xcframework"
fi
if [ "$BUILD_STATIC" = true ]; then
    echo "Static:  ${OUTPUT_DIR}/libvips-static.xcframework"
fi
echo ""
