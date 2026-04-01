// swift-tools-version: 5.9
import Foundation
import PackageDescription

enum SwiftSDKMode: String {
    case sourceOnly = "source-only"
    case native
}

let repoRoot = URL(fileURLWithPath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
let relativeXCFrameworkPath = "../../output/Verity.xcframework"
let xcframeworkPath = repoRoot.appendingPathComponent("output/Verity.xcframework").path
let hasNativeXCFramework = FileManager.default.fileExists(atPath: xcframeworkPath)
let configuredMode = ProcessInfo.processInfo.environment["VERITY_SWIFT_SDK_MODE"]

// Read which backends were built into the xcframework (written by build-ios.sh)
let backendsMarkerPath = repoRoot.appendingPathComponent("output/Verity.xcframework/backends").path
let builtBackends: String = (try? String(contentsOfFile: backendsMarkerPath, encoding: .utf8))?
    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "provekit"
let hasPK = builtBackends == "provekit" || builtBackends == "all"
let hasBB = builtBackends == "bb" || builtBackends == "all"

let swiftSDKMode: SwiftSDKMode = {
    guard let configuredMode else {
        return .sourceOnly
    }
    guard let mode = SwiftSDKMode(rawValue: configuredMode) else {
        fatalError("Unsupported VERITY_SWIFT_SDK_MODE='\(configuredMode)'. Use 'source-only' or 'native'.")
    }
    return mode
}()

if swiftSDKMode == .native && !hasNativeXCFramework {
    fatalError("VERITY_SWIFT_SDK_MODE=native requires ../../output/Verity.xcframework. Build it first with core/build/build-ios.sh.")
}

var targets: [Target] = []

if swiftSDKMode == .native {
    targets.append(
        .binaryTarget(
            name: "VerityFFI",
            path: relativeXCFrameworkPath
        )
    )
}

let package = Package(
    name: "Verity",
    platforms: [.iOS(.v15), .macOS(.v13)],
    products: [
        .library(name: "Verity", targets: ["Verity"]),
    ],
    targets: targets + [
        .target(
            name: "VerityDispatch",
            dependencies: swiftSDKMode == .native ? ["VerityFFI"] : [],
            path: "VerityDispatch",
            // Which backend .c files to compile depends on what was built into
            // the xcframework (detected from output/Verity.xcframework/backends marker).
            sources: swiftSDKMode == .native
                ? {
                    var srcs = ["verity_dispatch.c"]
                    if hasPK { srcs.append("backends/pk_backend.c") }
                    if hasBB { srcs.append("backends/bb_backend.c") }
                    return srcs
                }()
                : [
                    "stub/verity_dispatch_stub.c",
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
            path: "Sources/Verity",
            swiftSettings: [
                .define(
                    swiftSDKMode == .native ? "VERITY_SWIFT_NATIVE_RUNTIME" : "VERITY_SWIFT_SOURCE_ONLY_RUNTIME"
                )
            ]
        ),

        .testTarget(
            name: "VerityUnitTests",
            dependencies: ["Verity"],
            path: "Tests/VerityTests",
            exclude: [
                "VerityNativeIntegrationTests.swift",
                "Fixtures",
            ],
            sources: ["VerityUnitTests.swift"]
        ),
    ] + (
        swiftSDKMode == .native
            ? [
                .testTarget(
                    name: "VerityNativeIntegrationTests",
                    dependencies: ["Verity"],
                    path: "Tests/VerityTests",
                    exclude: ["VerityUnitTests.swift"],
                    sources: ["VerityNativeIntegrationTests.swift"],
                    resources: [.copy("Fixtures")]
                )
            ]
            : []
    )
)
