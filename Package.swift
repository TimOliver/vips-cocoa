// swift-tools-version: 5.9

import PackageDescription

let version = "8.18.0"
let dynamicChecksum = "08e67487366a78e7b055da1d4089b016bb4aad8b45f7db0daa89fd7cbfc60b76"
let staticChecksum = "6be91238cea21079b97028911fb22345a65ef5f6f407a8912511b2edf8e1061a"

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
