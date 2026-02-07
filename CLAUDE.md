# vips-cocoa

Build system for compiling libvips as universal xcframeworks for Apple platforms.

## Overview

This project automates building libvips and all its dependencies for Apple platforms, producing per-platform `vips.xcframework` (dynamic) and `vips.xcframework` (static) for direct use of the libvips C API. No Objective-C wrapper — for that, see VIPSKit.

## Supported Platforms

| Platform | Architectures | SDK | Min Version |
|----------|--------------|-----|-------------|
| iOS Device | arm64 | iphoneos | 15.0 |
| iOS Simulator | arm64, x86_64 | iphonesimulator | 15.0 |
| Mac Catalyst | arm64, x86_64 | macosx (-macabi) | 15.0 |
| macOS | arm64, x86_64 | macosx | 12.0 |
| visionOS Device | arm64 | xros | 1.0 |
| visionOS Simulator | arm64 | xrsimulator | 1.0 |

## Image Format Support

- JPEG (libjpeg-turbo with SIMD acceleration)
- PNG (libpng)
- WebP (libwebp)
- JPEG-XL (libjxl)
- AVIF (decode-only via dav1d + libheif)
- HEIF (libheif)
- GIF (built-in)

## Dependencies (Build Order)

### Tier 1 - No dependencies
1. **expat** (2.7.3) - XML parser
2. **libffi** (3.5.2) - Foreign function interface
3. **pcre2** (10.47) - Regular expressions
4. **libjpeg-turbo** (3.1.3) - JPEG codec with SIMD
5. **libpng** (1.6.54) - PNG codec
6. **brotli** (1.2.0) - Compression library
7. **highway** (1.3.0) - SIMD library

### Tier 2 - Depends on Tier 1
8. **glib** (2.87.1) - Core utility library (needs libffi, pcre2)
9. **libwebp** (1.6.0) - WebP codec
10. **dav1d** (1.5.1) - AV1 decoder

### Tier 3 - Depends on Tier 2
11. **libjxl** (0.11.1) - JPEG-XL codec (needs brotli, highway)
12. **libheif** (1.21.2) - HEIF/AVIF container (needs dav1d)

### Final
13. **libvips** (8.18.0) - Image processing library

## Project Structure

```
vips-cocoa/
├── CLAUDE.md                   # This file
├── README.md                   # User-facing documentation
├── build.sh                    # Main build orchestrator
├── LICENSE                     # LGPL-2.1
├── .gitignore
└── Scripts/
    ├── env.sh                  # Environment, paths, versions
    ├── utils.sh                # Common build functions
    ├── download-sources.sh     # Download all source tarballs
    ├── create-xcframework.sh   # Creates dynamic + static xcframeworks
    ├── package-prebuilt.sh     # Package release artifacts
    ├── build-expat.sh
    ├── build-libffi.sh
    ├── build-pcre2.sh
    ├── build-libjpeg-turbo.sh
    ├── build-libpng.sh
    ├── build-brotli.sh
    ├── build-highway.sh
    ├── build-glib.sh
    ├── build-libwebp.sh
    ├── build-dav1d.sh
    ├── build-libjxl.sh
    ├── build-libheif.sh
    ├── build-libvips.sh
    ├── cross-files/            # Meson cross-compilation files
    │   ├── ios.ini             # iOS, macOS, visionOS targets
    │   ├── ios-sim-arm64.ini   # Plus simulator and catalyst variants
    │   └── ...
    └── toolchains/             # CMake toolchain files
        └── ios.toolchain.cmake
```

## Building

### Prerequisites

- Xcode with command-line tools
- Homebrew packages: `brew install meson ninja cmake nasm glib`
  - `nasm` is required for dav1d assembly
  - `glib` provides glib-mkenums for building target glib

### Full Build

```bash
./build.sh
```

### Build Options

```bash
./build.sh --clean              # Clean all build artifacts first
./build.sh --skip-download      # Skip downloading sources (use existing)
./build.sh --jobs 8             # Set parallel job count
./build.sh --platform ios       # Build iOS only
./build.sh --platform ios,macos # Build iOS + macOS
./build.sh -f                   # Rebuild xcframeworks only (fast)
./build.sh -f --dynamic-only    # Rebuild dynamic only
./build.sh -f --static-only     # Rebuild static only
./build.sh -f --platform macos  # Rebuild macOS xcframeworks only
```

### Build Individual Libraries

```bash
./Scripts/build-libpng.sh   # Build just libpng
```

## Output

The build produces per-platform xcframeworks under `build/xcframeworks/`:

```
build/xcframeworks/
├── ios/
│   ├── dynamic/vips.xcframework/
│   └── static/vips.xcframework/
├── macos/
│   ├── dynamic/vips.xcframework/
│   └── static/vips.xcframework/
└── visionos/
    ├── dynamic/vips.xcframework/
    └── static/vips.xcframework/
```

### Dynamic: `vips.xcframework`
```
vips.xcframework/
├── Info.plist
├── ios-arm64/
│   └── vips.framework/
│       ├── vips                    # Dynamic library (all deps linked in)
│       ├── Headers/
│       │   ├── vips.h              # Umbrella header
│       │   ├── vips/               # libvips headers
│       │   ├── glib.h              # glib top-level headers
│       │   ├── glib/               # glib sub-headers
│       │   ├── gobject/
│       │   ├── gio/
│       │   └── glibconfig.h
│       ├── Modules/module.modulemap
│       └── Info.plist
├── ios-arm64_x86_64-simulator/
└── ios-arm64_x86_64-maccatalyst/
```

### Static: `vips.xcframework`
All static libraries merged into a single archive per platform, with the same headers.

### Release Artifacts
After packaging (`Scripts/package-prebuilt.sh`):
```
vips-dynamic-ios.zip      # contains vips.xcframework for iOS
vips-static-ios.zip
vips-dynamic-macos.zip
vips-static-macos.zip
vips-dynamic-visionos.zip
vips-static-visionos.zip
```

### Generated Files
After a full build, `build/output/libvips-generated/` contains:

| File | Source | Purpose |
|------|--------|---------|
| `config.h` | Meson configure | Feature detection macros |
| `vipsmarshal.c` | glib-genmarshal | GObject signal marshalling |
| `vipsmarshal.h` | glib-genmarshal | Marshal function declarations |
| `enumtypes.c` | glib-mkenums | GObject enum types |
| `enumtypes.h` | glib-mkenums | Enum type declarations |

These are needed by downstream consumers that build libvips from source (e.g., VIPSKit's Xcode project).

## Architecture Notes

### Build Approach

1. All 13 dependencies are compiled as static libraries for each target architecture
2. **Dynamic framework:** All static libraries are linked into a single dylib per arch, then packaged as an xcframework
3. **Static framework:** All static libraries are merged via `libtool -static` per arch, then packaged as an xcframework
4. Headers for both libvips and glib are included so consumers can use the libvips C API directly

### Cross-Compilation

- **CMake builds** use `Scripts/toolchains/ios.toolchain.cmake` from leetal/ios-cmake
- **Meson builds** use custom cross-files in `Scripts/cross-files/`
- **Autotools builds** use configure flags with appropriate CC/CFLAGS

### force_load

The dynamic framework uses `-force_load` for two libraries:
- **glib**: Ensures `__attribute__((constructor))` initialization functions are included. Without this, glib's hash table infrastructure is not properly initialized, causing crashes.
- **libvips**: Ensures all public symbols are exported from the dylib.

### Platform Families

| Family | `--platform` value | Targets |
|--------|-------------------|---------|
| iOS | `ios` | ios, ios-sim-arm64, ios-sim-x86_64, catalyst-arm64, catalyst-x86_64 |
| macOS | `macos` | macos-arm64, macos-x86_64 |
| visionOS | `visionos` | visionos, visionos-sim-arm64 |

### Target Identifiers

| Target ID | Description |
|-----------|-------------|
| `ios` | iOS Device arm64 |
| `ios-sim-arm64` | iOS Simulator arm64 |
| `ios-sim-x86_64` | iOS Simulator x86_64 |
| `catalyst-arm64` | Mac Catalyst arm64 |
| `catalyst-x86_64` | Mac Catalyst x86_64 |
| `macos-arm64` | macOS arm64 |
| `macos-x86_64` | macOS x86_64 |
| `visionos` | visionOS Device arm64 |
| `visionos-sim-arm64` | visionOS Simulator arm64 |

## Troubleshooting

### Build fails with "glib-mkenums not found"
```bash
brew install glib
```

### Build fails with "nasm not found" (dav1d)
```bash
brew install nasm
```

### libjxl build fails with "Please run deps.sh"
The build script automatically runs `deps.sh` to fetch libjxl's third-party dependencies. If this fails, run manually:
```bash
cd Vendor/libjxl-*/
./deps.sh
```

### Undefined symbols for architecture
Check that all dependencies built successfully for the failing target. The build scripts create static libraries in `build/staging/<library>/<target>/lib/`.

## Cleaning

```bash
./build.sh --clean              # Clean and rebuild
rm -rf build                    # Manual clean
```

## License

- libvips: LGPL-2.1
- Dependencies have various open-source licenses (MIT, BSD, etc.)
- This build system: MIT
