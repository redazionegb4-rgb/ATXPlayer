// swift-tools-version: 5.9

import PackageDescription

let ffmpegFrameworks = [
    "ffmpegkit",
    "libavcodec",
    "libavdevice",
    "libavfilter",
    "libavformat",
    "libavutil",
    "libswresample",
    "libswscale",
]

let binaryTargetNames = ffmpegFrameworks.map { "\($0)Binary" }

let package = Package(
    name: "FFmpegKit",
    platforms: [
        .iOS(.v12),
        .macOS(.v10_15),
    ],
    products: [
        .library(
            name: "ffmpegkit",
            targets: ["ffmpegkit"] + binaryTargetNames
        ),
    ],
    targets: ffmpegFrameworks.map { name in
        .binaryTarget(
            name: "\(name)Binary",
            path: "Frameworks/\(name).xcframework"
        )
    } + [
        .target(
            name: "CFFmpegBridge",
            publicHeadersPath: "include"
        ),
        .target(
            name: "ffmpegkit",
            dependencies: ["CFFmpegBridge"],
            path: "Sources/FFmpegKit"
        ),
        .testTarget(
            name: "FFmpegKitTests",
            dependencies: ["ffmpegkit"]
        ),
    ]
)