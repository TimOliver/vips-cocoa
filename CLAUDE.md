# vips-cocoa

Build system for compiling libvips as universal xcframeworks for Apple platforms.

## Overview

This project automates building libvips and all its dependencies for Apple platforms, producing `vips.xcframework` (dynamic and static) for direct use of the libvips C API. Distributed via Swift Package Manager as binary targets. No Objective-C wrapper — for that, see VIPSKit.

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
- TIFF (libtiff)
- AVIF (decode-only via dav1d + libheif)
- HEIF (libheif)
- GIF (built-in)
- EXIF metadata (libexif)
- ICC color management (lcms2)
- FFT support (fftw3)

## Dependencies (Build Order)

### Tier 1 - No dependencies
| # | Library | Version | Build System | Output |
|---|---------|---------|---|---|
| 1 | **expat** | 2.7.4 | CMake | `libexpat.a` |
| 2 | **libffi** | 3.5.2 | Manual (CC) | `libffi.a` |
| 3 | **pcre2** | 10.47 | CMake | `libpcre2-8.a` |
| 4 | **libjpeg-turbo** | 3.1.3 | CMake | `libjpeg.a` |
| 5 | **libpng** | 1.6.54 | CMake | `libpng16.a` |
| 6 | **brotli** | 1.2.0 | CMake | `libbrotli{common,dec,enc}.a` |
| 7 | **highway** | 1.3.0 | CMake | `libhwy.a` |
| 8 | **fftw** | 3.3.10 | Autotools | `libfftw3.a` |
| 9 | **lcms2** | 2.18 | Meson | `liblcms2.a` |
| 10 | **libexif** | 0.6.25 | Autotools | `libexif.a` |

### Tier 2 - Depends on Tier 1
| # | Library | Version | Build System | Dependencies | Output |
|---|---------|---------|---|---|---|
| 11 | **glib** | 2.87.2 | Meson | libffi, pcre2 | `libglib-2.0.a`, `libgio-2.0.a`, `libgobject-2.0.a`, `libgmodule-2.0.a`, `libintl.a` |
| 12 | **libwebp** | 1.6.0 | CMake | — | `libwebp.a`, `libwebpmux.a`, `libwebpdemux.a`, `libsharpyuv.a` |
| 13 | **dav1d** | 1.5.3 | Meson | — | `libdav1d.a` |
| 14 | **libtiff** | 4.7.1 | CMake | libjpeg-turbo | `libtiff.a` |

### Tier 3 - Depends on Tier 2
| # | Library | Version | Build System | Dependencies | Output |
|---|---------|---------|---|---|---|
| 15 | **libjxl** | 0.11.1 | CMake | brotli, highway | `libjxl.a`, `libjxl_threads.a`, `libjxl_cms.a` |
| 16 | **libheif** | 1.21.2 | CMake | dav1d | `libheif.a` |

### Final
| # | Library | Version | Build System | Output |
|---|---------|---------|---|---|
| 17 | **libvips** | 8.18.0 | Meson | `libvips.a` |

## Project Structure

```
vips-cocoa/
├── CLAUDE.md                   # This file
├── README.md                   # User-facing documentation
├── Package.swift               # SPM package manifest (binary targets)
├── build.sh                    # Main build orchestrator
├── LICENSE                     # LGPL-2.1
├── .gitignore
└── Scripts/
    ├── env.sh                  # Environment, paths, versions
    ├── utils.sh                # Common build functions
    ├── download-sources.sh     # Download all source tarballs
    ├── create-xcframework.sh   # Creates per-platform dynamic + static xcframeworks
    ├── create-spm-xcframework.sh # Combines per-platform into all-platform xcframeworks for SPM
    ├── package-prebuilt.sh     # Package release artifacts
    ├── build-expat.sh
    ├── build-libffi.sh
    ├── build-pcre2.sh
    ├── build-libjpeg-turbo.sh
    ├── build-libpng.sh
    ├── build-brotli.sh
    ├── build-highway.sh
    ├── build-fftw.sh
    ├── build-lcms2.sh
    ├── build-libexif.sh
    ├── build-glib.sh
    ├── build-libwebp.sh
    ├── build-dav1d.sh
    ├── build-libtiff.sh
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
├── visionos/
│   ├── dynamic/vips.xcframework/
│   └── static/vips.xcframework/
└── spm/                            # Combined all-platform (created by package-prebuilt.sh)
    ├── dynamic/vips.xcframework/   # All 6 slices in one xcframework
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
vips-dynamic.zip          # Combined all-platform xcframework (for SPM)
vips-static.zip           # Combined all-platform xcframework (for SPM)
vips-dynamic-ios.zip      # Per-platform xcframework for iOS
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

1. All 17 dependencies are compiled as static libraries for each target architecture
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

### ObjC and Framework Linking

glib (2.87+) includes Objective-C source files (`.m`) on Apple platforms for Cocoa integration (notifications, settings, app info). The dynamic framework link therefore requires:
- `-lobjc -framework Foundation -framework CoreFoundation` on all platforms
- `-framework AppKit` additionally on macOS and Mac Catalyst targets (for `NSWorkspace` etc.)

### libtiff Optional Dependencies

libtiff's CMake build auto-detects system lzma, zstd, webp, jbig, and lerc. These must be explicitly disabled (`-Dlzma=OFF -Dzstd=OFF -Dwebp=OFF -Djbig=OFF -Dlerc=OFF`) to prevent phantom `Requires.private` entries in the pkg-config file that would cause libvips's meson configure to fail.

### FFTW Precision

libvips expects double-precision FFTW (`fftw3` pkg-config name, `libfftw3.a`). Do **not** build with `--enable-float`, which produces single-precision (`fftw3f` / `libfftw3f.a`) and will not be found by libvips.

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

## Swift Package Manager Distribution

The project vends xcframeworks via SPM binary targets in `Package.swift`. Two products are available:

- **`vips`** (dynamic) — For direct use of the libvips dylib (default)
- **`vips-static`** — For consumers like VIPSKit that link vips into their own dynamic framework

### How It Works

1. Per-platform xcframeworks are built by `create-xcframework.sh` (one per platform family)
2. `create-spm-xcframework.sh` combines them into single all-platform xcframeworks (6 slices: ios-arm64, ios-sim, catalyst, macos, visionos-device, visionos-sim)
3. These are zipped as `vips-static.zip` and `vips-dynamic.zip` and attached to GitHub releases
4. `Package.swift` uses URL-based binary targets pointing to the release artifacts

### Release Flow

The CI workflow (`.github/workflows/release.yml`) handles version/checksum updates automatically:

1. Builds all platforms
2. Packages artifacts (including combined SPM zips)
3. Computes checksums via `swift package compute-checksum`
4. Updates `Package.swift` with the version and checksums via `sed`
5. Commits `VERSION` + `Package.swift`, tags, and pushes
6. Creates the GitHub Release with all artifacts

The `Package.swift` in the repo uses placeholder values (`0.0.0` / `PLACEHOLDER`) that are replaced at release time.

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
