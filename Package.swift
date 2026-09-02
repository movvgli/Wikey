// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Wikey",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Wikey", targets: ["Wikey"]),
        .executable(name: "WikeyLoginHelper", targets: ["WikeyLoginHelper"]),
    ],
    dependencies: [
        .package(url: "https://github.com/sparkle-project/Sparkle", exact: "2.9.6"),
    ],
    targets: [
        .target(
            name: "WikeyCore",
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement"),
            ]
        ),
        .executableTarget(
            name: "Wikey",
            dependencies: [
                "WikeyCore",
                .product(name: "Sparkle", package: "Sparkle"),
            ]
        ),
        .executableTarget(
            name: "WikeyLoginHelper"
        ),
        .testTarget(
            name: "WikeyCoreTests",
            dependencies: ["WikeyCore"]
        ),
    ],
    swiftLanguageModes: [.v5]
)
