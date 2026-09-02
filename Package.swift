// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Wikey",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Wikey", targets: ["Wikey"]),
        .executable(name: "WikeyLoginHelper", targets: ["WikeyLoginHelper"]),
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
            dependencies: ["WikeyCore"]
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
