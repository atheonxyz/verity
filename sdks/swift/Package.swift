// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "Verity",
    platforms: [.iOS(.v15)],
    products: [
        .library(name: "Verity", targets: ["Verity"]),
    ],
    targets: [
        // Pre-built static library containing pk_* and bb_* symbols.
        .binaryTarget(
            name: "VerityFFI",
            url: "https://github.com/atheonxyz/verity/releases/download/v0.1.0/Verity.xcframework.zip",
            checksum: "ff6fa59c2c9b17bf95b1a7e7768583f4838aa088ebf618c082326a1ccdbcc64b"
        ),

        // C dispatcher — routes unified verity_* calls to the correct backend
        // via vtable. Contains pk_backend.c and bb_backend.c registrations.
        .target(
            name: "VerityDispatch",
            dependencies: ["VerityFFI"],
            path: "../../core/dispatcher",
            sources: [
                "verity_dispatch.c",
                "backends/pk_backend.c",
                "backends/bb_backend.c",
            ],
            publicHeadersPath: "../include",
            cSettings: [
                .headerSearchPath("../include"),
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
