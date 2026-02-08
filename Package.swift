// swift-tools-version: 5.9

import PackageDescription

let version = "0.0.0"
let dynamicChecksum = "PLACEHOLDER"
let staticChecksum = "PLACEHOLDER"

let package = Package(
    name: "vips-cocoa",
    platforms: [.iOS(.v15), .macOS(.v12), .visionOS(.v1)],
    products: [
        .library(name: "vips", targets: ["vips"]),
        .library(name: "vips-static", targets: ["vips-static"]),
    ],
    targets: [
        .binaryTarget(
            name: "vips",
            url: "https://github.com/TimOliver/vips-cocoa/releases/download/v\(version)/vips-dynamic.zip",
            checksum: dynamicChecksum
        ),
        .binaryTarget(
            name: "vips-static",
            url: "https://github.com/TimOliver/vips-cocoa/releases/download/v\(version)/vips-static.zip",
            checksum: staticChecksum
        ),
    ]
)
