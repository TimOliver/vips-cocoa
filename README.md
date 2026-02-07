# vips-cocoa

Build system for compiling [libvips](https://www.libvips.org/) and all its dependencies as universal xcframeworks for Apple platforms (iOS, iOS Simulator, Mac Catalyst).

Produces **two** xcframeworks:
- **`libvips.xcframework`** (dynamic) — single dylib per platform, all dependencies statically linked in
- **`libvips-static.xcframework`** (static) — merged static archive per platform

For a high-level Objective-C/Swift wrapper, see [VIPSKit](https://github.com/anthropics/VIPSKit).

## Supported Platforms

| Platform | Architectures | SDK |
|----------|--------------|-----|
| iOS Device | arm64 | iphoneos |
| iOS Simulator | arm64, x86_64 | iphonesimulator |
| Mac Catalyst | arm64, x86_64 | macosx (with -macabi target) |

Minimum deployment target: iOS 15.0

## Image Format Support

JPEG (libjpeg-turbo with SIMD), PNG, WebP, JPEG-XL, AVIF (decode-only via dav1d + libheif), HEIF, GIF (built-in).

## Prerequisites

- Xcode with command-line tools
- Homebrew packages:
  ```bash
  brew install meson ninja cmake nasm glib
  ```

## Building

```bash
# Full build (downloads sources, builds all 13 libraries, creates both xcframeworks)
./build.sh

# Clean build
./build.sh --clean

# Download sources only
./build.sh -d

# Rebuild xcframeworks only (after a previous full build)
./build.sh -f

# Build only dynamic xcframework
./build.sh -f --dynamic-only

# Build only static xcframework
./build.sh -f --static-only

# List library versions
./build.sh --list
```

## Output

```
vips-cocoa/
├── libvips.xcframework/           # Dynamic framework
│   ├── ios-arm64/
│   │   └── libvips.framework/
│   │       ├── libvips             # Dynamic library
│   │       ├── Headers/            # vips/ + glib headers
│   │       ├── Modules/module.modulemap
│   │       └── Info.plist
│   ├── ios-arm64_x86_64-simulator/
│   └── ios-arm64_x86_64-maccatalyst/
│
├── libvips-static.xcframework/    # Static framework
│   ├── ios-arm64/
│   ├── ios-arm64_x86_64-simulator/
│   └── ios-arm64_x86_64-maccatalyst/
│
└── build/output/libvips-generated/ # Generated files for source builds
    ├── config.h
    ├── vipsmarshal.c
    ├── vipsmarshal.h
    ├── enumtypes.c
    └── enumtypes.h
```

## Using the Dynamic Framework

1. Drag `libvips.xcframework` into your Xcode project
2. Add to "Frameworks, Libraries, and Embedded Content"
3. Set "Embed" to "Embed & Sign"

```c
#include <libvips/libvips.h>
// or: #include <vips/vips.h>

VIPS_INIT("myapp");
VipsImage *in = vips_image_new_from_file("input.jpg", NULL);
// ... use libvips C API directly ...
```

**Note:** libvips is LGPL-2.1, so the dynamic framework satisfies LGPL requirements for proprietary apps. If you use the static framework, ensure your linking complies with LGPL terms.

## Using the Static Framework

Add `libvips-static.xcframework` to your project and link the following system libraries:
- `libz`
- `libiconv`
- `libresolv`
- `libc++`

## Packaging Releases

```bash
./Scripts/package-prebuilt.sh 0.1.0
```

This creates:
- `vips-cocoa-prebuilt-0.1.0.tar.gz` — all pre-built static libraries
- `libvips-generated-0.1.0.tar.gz` — generated config/marshal/enum files
- `libvips-0.1.0.xcframework.zip` — dynamic xcframework
- `libvips-static-0.1.0.xcframework.zip` — static xcframework

## Dependencies (Build Order)

| # | Library | Version | Depends On |
|---|---------|---------|------------|
| 1 | expat | 2.7.3 | — |
| 2 | libffi | 3.5.2 | — |
| 3 | pcre2 | 10.47 | — |
| 4 | libjpeg-turbo | 3.1.3 | — |
| 5 | libpng | 1.6.54 | — |
| 6 | brotli | 1.2.0 | — |
| 7 | highway | 1.3.0 | — |
| 8 | glib | 2.87.1 | libffi, pcre2 |
| 9 | libwebp | 1.6.0 | — |
| 10 | dav1d | 1.5.1 | — |
| 11 | libjxl | 0.11.1 | brotli, highway |
| 12 | libheif | 1.21.2 | dav1d |
| 13 | libvips | 8.18.0 | all above |

## License

- libvips: LGPL-2.1
- Dependencies have various open-source licenses (MIT, BSD, etc.)
- This build system: MIT
