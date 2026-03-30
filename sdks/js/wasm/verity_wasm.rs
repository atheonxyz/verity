//! WASM bindings for Verity — wraps Rust FFI backends that compile to WASM.
//!
//! For backends that provide vendor WASM (like Barretenberg via @aztec/bb.js),
//! the JS adapter in src/backends/ handles it directly. This crate is only
//! for backends whose Rust code compiles cleanly to wasm32-unknown-unknown.

use wasm_bindgen::prelude::*;

#[wasm_bindgen]
pub fn verity_wasm_version() -> String {
    env!("CARGO_PKG_VERSION").to_string()
}

// TODO: Implement WASM bindings for backends that support rust-wasm target type.
// Each backend that declares [targets.wasm] type = "rust-wasm" in its backend.toml
// will be compiled into this crate and exposed via wasm-bindgen.
