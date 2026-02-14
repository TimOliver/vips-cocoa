// swift-tools-version: 5.9

import PackageDescription

let version = "8.18.0"
let dynamicChecksum = "95e8771b208f3ce4257991eed6e9efd69f7bd26775b701aacf45ea805e77b88b"
let staticChecksum = "66495f4016c3658d23250a98576711aaf69308625692b9e1918945c5a35f75cf"

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
