// swift-tools-version: 5.9

import PackageDescription

let package = Package(
    name: "tinglang_native_macos",
    platforms: [
        .macOS("14.2")
    ],
    products: [
        .library(name: "tinglang-native-macos", targets: ["tinglang_native_macos"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework")
    ],
    targets: [
        .target(
            name: "tinglang_native_macos",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework")
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
