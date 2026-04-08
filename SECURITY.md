# Security Policy

## Supported Versions

| Version | Supported          |
|---------|--------------------|
| 0.3.x   | :white_check_mark: |
| < 0.3   | :x:                |

## Reporting a Vulnerability

**Do not open a public issue for security vulnerabilities.**

If you discover a security vulnerability in Verity, please report it responsibly:

1. Email **security@atheon.xyz** with a description of the vulnerability
2. Include steps to reproduce, if possible
3. We will acknowledge receipt within 48 hours
4. We will provide a fix timeline within 7 days

## Scope

The following are in scope for security reports:

- Memory safety issues in the C dispatcher or Rust FFI layer
- Proof soundness bugs (invalid proofs that verify as valid)
- Key/scheme leakage through serialization or save/load
- JNI boundary issues in the Kotlin SDK
- Unsafe buffer handling in any SDK

## Out of Scope

- Denial of service via large circuits (expected behavior)
- Issues in upstream dependencies (report to them directly)
- Issues requiring physical device access

## Disclosure

We follow coordinated disclosure. We will credit reporters in the changelog unless they prefer anonymity.
