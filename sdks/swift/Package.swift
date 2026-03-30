// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Verity",
    platforms: [.iOS(.v15), .macOS(.v13)],
    products: [
        .library(name: "Verity", targets: ["Verity"]),
    ],
    targets: [
        // Pre-built static library containing pk_* and bb_* symbols.
        .binaryTarget(
            name: "VerityFFI",
            path: "../../output/Verity.xcframework"
        ),

        // C dispatcher — routes unified verity_* calls to the correct backend
        // via vtable. Contains pk_backend.c and bb_backend.c registrations.
        // Uses symlink: VerityDispatch -> ../../core/dispatcher
        // Headers via:  core/dispatcher/include -> core/include (symlink)
        .target(
            name: "VerityDispatch",
            dependencies: ["VerityFFI"],
            path: "VerityDispatch",
            sources: [
                "verity_dispatch.c",
                "backends/pk_backend.c",
                "backends/bb_backend.c",
            ],
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("include"),
                .headerSearchPath("."),
            ]
        ),

        // Swift SDK — calls verity_* functions only (no backend-specific code).
        .target(
            name: "Verity",
            dependencies: ["VerityDispatch"],
            path: "Sources/Verity"
        ),

        .testTarget(
            name: "VerityTests",
            dependencies: ["Verity"],
            path: "Tests/VerityTests",
            resources: [.copy("Fixtures")]
        ),
    ]
)
