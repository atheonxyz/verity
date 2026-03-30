# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Thread-safe backend initialization in Swift SDK
- `Sendable` conformance for all Swift SDK types
- `Verity.version` / `Verity.VERSION` runtime version constant (Swift, Kotlin)
- Negative tests for Swift SDK (error paths, garbage proofs, invalid inputs)
- ProGuard consumer rules for Kotlin SDK
- macOS platform support in Swift Package.swift
- Actionable error messages with fix suggestions
- CHANGELOG.md, SECURITY.md

## [0.2.0] - 2025-03-30

### Added
- Monorepo structure: `core/`, `sdks/`, `examples/`, `circuits/`
- Swift SDK via Swift Package Manager with XCFramework binary target
- Kotlin SDK via Gradle with JNI bridge and Maven Central publishing
- TypeScript/JavaScript SDK scaffolding (types, errors, async API)
- C vtable dispatcher supporting pluggable backends
- ProveKit (WHIR) and Barretenberg (UltraHonk) backends
- Prepare/prove/verify workflow with TOML and JSON inputs
- Scheme save/load/serialize for offline key management
- iOS and Android demo apps (SwiftUI, Material Design)
- CI/CD workflows for core builds and all SDKs
- Build scripts for iOS, Android, WASM, and native targets
- Binary size optimization via `release-mobile` cargo profile
- Architecture, building, contributing, and extension docs

## [0.1.0] - 2025-03-01

### Added
- Initial Swift SDK with ProveKit backend
- Basic proof generation and verification
