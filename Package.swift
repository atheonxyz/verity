// swift-tools-version: 5.9
import Foundation
import PackageDescription

// Root-level Package.swift — forwards to sdks/swift/ sources so SPM can
// resolve this repo as a package dependency directly.

// NOTE: This enum is duplicated in sdks/swift/Package.swift — keep in sync.
enum SwiftSDKMode: String {
    case sourceOnly = "source-only"
    case native
    case release
}

// Release binary target — update URL and checksum for each release.
let releaseXCFrameworkURL = "https://github.com/atheonxyz/verity/releases/download/v0.3.1/Verity.xcframework.zip"
let releaseXCFrameworkChecksum = "6193a1bf785a88d917aab632cb8830913ae76158c5a146872d200bc4fcb512cf"

let repoRoot = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
let xcframeworkPath = repoRoot.appendingPathComponent("output/Verity.xcframework").path
let hasNativeXCFramework = FileManager.default.fileExists(atPath: xcframeworkPath)
let configuredMode = ProcessInfo.processInfo.environment["VERITY_SWIFT_SDK_MODE"]

// Detect if consumed as a remote SPM dependency (checked out into SourcePackages or .build).
let isRemoteCheckout: Bool = {
    let path = #filePath
    return path.contains("/SourcePackages/checkouts/") || path.contains("/.build/checkouts/")
}()

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
    // Auto-detect: local xcframework → native, remote checkout → release, otherwise source-only (monorepo dev)
    if hasNativeXCFramework { return .native }
    if isRemoteCheckout { return .release }
    return .sourceOnly
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
                    // Release xcframework currently ships with ProveKit only.
                    // Native mode reads the backends marker from the local xcframework.
                    if swiftSDKMode == .release || hasPK { srcs.append("backends/pk_backend.c") }
                    if swiftSDKMode == .native && hasBB { srcs.append("backends/bb_backend.c") }
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
