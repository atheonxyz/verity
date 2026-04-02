// swift-tools-version: 5.9
import Foundation
import PackageDescription

// Root-level Package.swift — forwards to sdks/swift/ sources so SPM can
// resolve this repo as a package dependency directly.

enum SwiftSDKMode: String {
    case sourceOnly = "source-only"
    case native
    case release
}

// Release binary target — update URL and checksum for each release.
let releaseXCFrameworkURL = "https://github.com/atheonxyz/verity/releases/download/v0.3.0/Verity.xcframework.zip"
let releaseXCFrameworkChecksum = "c8e1f78519a976b2a9970c8f0b110793139bc2a7d3dd5df5f6c62c64eb3705f9"

let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let xcframeworkPath = repoRoot.appendingPathComponent("output/Verity.xcframework").path
let hasNativeXCFramework = FileManager.default.fileExists(atPath: xcframeworkPath)
let configuredMode = ProcessInfo.processInfo.environment["VERITY_SWIFT_SDK_MODE"]

// Detect if we are inside the monorepo (core/ directory exists) or consumed as a remote dependency.
let isMonorepo = FileManager.default.fileExists(atPath: repoRoot.appendingPathComponent("core").path)

// Read which backends were built into the xcframework (written by build-ios.sh)
let backendsMarkerPath = repoRoot.appendingPathComponent("output/Verity.xcframework/backends").path
let builtBackends: String = (try? String(contentsOfFile: backendsMarkerPath, encoding: .utf8))?
    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "provekit"
let hasPK = builtBackends == "provekit" || builtBackends == "all"
let hasBB = builtBackends == "bb" || builtBackends == "all"

let swiftSDKMode: SwiftSDKMode = {
    // Explicit override via environment variable
    if let configuredMode {
        guard let mode = SwiftSDKMode(rawValue: configuredMode) else {
            fatalError("Unsupported VERITY_SWIFT_SDK_MODE='\(configuredMode)'. Use 'source-only', 'native', or 'release'.")
        }
        return mode
    }
    // Auto-detect: local xcframework → native, monorepo without xcframework → source-only, remote consumer → release
    if hasNativeXCFramework { return .native }
    if isMonorepo { return .sourceOnly }
    return .release
}()

if swiftSDKMode == .native && !hasNativeXCFramework {
    fatalError("VERITY_SWIFT_SDK_MODE=native requires output/Verity.xcframework. Build it first with core/build/build-ios.sh.")
}

var targets: [Target] = []

switch swiftSDKMode {
case .native:
    targets.append(
        .binaryTarget(
            name: "VerityFFI",
            path: "output/Verity.xcframework"
        )
    )
case .release:
    targets.append(
        .binaryTarget(
            name: "VerityFFI",
            url: releaseXCFrameworkURL,
            checksum: releaseXCFrameworkChecksum
        )
    )
case .sourceOnly:
    break
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
            dependencies: swiftSDKMode != .sourceOnly ? ["VerityFFI"] : [],
            path: "sdks/swift/VerityDispatch",
            sources: swiftSDKMode != .sourceOnly
                ? {
                    var srcs = ["verity_dispatch.c"]
                    if swiftSDKMode == .release || hasPK { srcs.append("backends/pk_backend.c") }
                    if swiftSDKMode == .release || hasBB { srcs.append("backends/bb_backend.c") }
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

        .target(
            name: "Verity",
            dependencies: ["VerityDispatch"],
            path: "sdks/swift/Sources/Verity",
            swiftSettings: [
                .define(
                    swiftSDKMode != .sourceOnly ? "VERITY_SWIFT_NATIVE_RUNTIME" : "VERITY_SWIFT_SOURCE_ONLY_RUNTIME"
                )
            ]
        ),
    ]
)
