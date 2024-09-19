// swift-tools-version:5.7
import PackageDescription

let package = Package(
    name: "qr_code_scanner_ios",
    platforms: [
        .iOS(.v13)
    ],
    products: [
        .library(
            name: "qr_code_scanner_ios",
            targets: ["qr_code_scanner_ios"]),
    ],
    dependencies: [
    ],
    targets: [
        .target(
            name: "qr_code_scanner_ios",
            dependencies: []),
        .testTarget(
            name: "qr_code_scanner_iosTests",
            dependencies: ["qr_code_scanner_ios"]),
    ]
)
