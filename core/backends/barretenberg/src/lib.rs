//! Barretenberg UltraHonk FFI — handle-based C-compatible bindings.
//!
//! Provides `bb_prepare`, `bb_prove_toml`, `bb_prove_json`, `bb_verify`, and
//! load/save/serialize functions matching the Verity SDK FFI contract.
//! Completely independent from ProveKit crates.

use {
    anyhow::{bail, Context, Result},
    noir_rs::{
        native_types::{Witness, WitnessMap},
        AcirField, FieldElement,
    },
    std::{
        ffi::CStr,
        os::raw::{c_char, c_int},
        panic,
        path::Path,
    },
};

// Error codes — matches VerityError enum in verity_ffi.h.
const SUCCESS: c_int = 0;
const INVALID_INPUT: c_int = 1;
const SCHEME_READ_ERROR: c_int = 2;
const PROOF_ERROR: c_int = 4;
const SERIALIZATION_ERROR: c_int = 5;
const FILE_WRITE_ERROR: c_int = 7;
const COMPILATION_ERROR: c_int = 8;

/// Buffer for returning data across FFI. Layout-compatible with PKBuf.
#[repr(C)]
pub struct BBBuf {
    pub ptr: *mut u8,
    pub len: usize,
    pub cap: usize,
}

impl BBBuf {
    fn empty() -> Self {
        Self {
            ptr: std::ptr::null_mut(),
            len: 0,
            cap: 0,
        }
    }

    fn from_vec(mut v: Vec<u8>) -> Self {
        let ptr = v.as_mut_ptr();
        let len = v.len();
        let cap = v.capacity();
        std::mem::forget(v);
        Self { ptr, len, cap }
    }
}

// ---------------------------------------------------------------------------
// Opaque handle types
// ---------------------------------------------------------------------------

/// Opaque prover handle. Holds ACIR bytecode, ABI, and pre-computed VK.
/// Cloned for each prove call.
pub struct BBProver {
    bytecode: String,
    abi: serde_json::Value,
    vk: Vec<u8>,
}

/// Opaque verifier handle. Holds the verification key.
/// Cloned for each verify call.
pub struct BBVerifier {
    vk: Vec<u8>,
}

// ---------------------------------------------------------------------------
// Internal helpers
// ---------------------------------------------------------------------------

#[inline]
fn catch_panic<F, T>(default: T, f: F) -> T
where
    F: FnOnce() -> T + panic::UnwindSafe,
{
    panic::catch_unwind(f).unwrap_or(default)
}

fn c_str_to_string(ptr: *const c_char) -> Result<String, c_int> {
    if ptr.is_null() {
        return Err(INVALID_INPUT);
    }
    // Safety: caller guarantees valid null-terminated UTF-8
    unsafe { CStr::from_ptr(ptr) }
        .to_str()
        .map(|s| s.to_owned())
        .map_err(|_| INVALID_INPUT)
}

fn read_acir_json(path: &Path) -> Result<(String, serde_json::Value)> {
    let json_str = std::fs::read_to_string(path).context("Failed to read ACIR JSON file")?;
    let v: serde_json::Value =
        serde_json::from_str(&json_str).context("Failed to parse ACIR JSON")?;

    let bytecode = v["bytecode"]
        .as_str()
        .context("ACIR JSON missing 'bytecode' field")?
        .to_owned();
    let abi = v["abi"].clone();

    Ok((bytecode, abi))
}

// --- TOML input parsing ---

fn read_inputs(input_path: &Path, abi: &serde_json::Value) -> Result<WitnessMap<FieldElement>> {
    let toml_str = std::fs::read_to_string(input_path).context("Failed to read input TOML")?;
    let toml_table: toml::Table =
        toml::from_str(&toml_str).context("Failed to parse input TOML")?;
    build_witness_from_toml(&toml_table, abi)
}

fn build_witness_from_toml(
    toml_table: &toml::Table,
    abi: &serde_json::Value,
) -> Result<WitnessMap<FieldElement>> {
    let params = abi["parameters"]
        .as_array()
        .context("ABI missing 'parameters' array")?;

    let mut witness_map = WitnessMap::new();
    let mut idx: u32 = 0;

    for param in params {
        let name = param["name"]
            .as_str()
            .context("ABI parameter missing 'name'")?;
        let typ = &param["type"];
        let toml_val = toml_table
            .get(name)
            .with_context(|| format!("Input TOML missing parameter '{name}'"))?;

        encode_toml_value(toml_val, typ, &mut witness_map, &mut idx)
            .with_context(|| format!("Failed to encode parameter '{name}'"))?;
    }

    Ok(witness_map)
}

fn encode_toml_value(
    toml_val: &toml::Value,
    abi_type: &serde_json::Value,
    map: &mut WitnessMap<FieldElement>,
    idx: &mut u32,
) -> Result<()> {
    let kind = abi_type["kind"]
        .as_str()
        .context("ABI type missing 'kind'")?;

    match kind {
        "field" | "boolean" | "integer" => {
            let fe = toml_to_field_element(toml_val)?;
            map.insert(Witness(*idx), fe);
            *idx += 1;
        }
        "string" => {
            let s = toml_val
                .as_str()
                .context("Expected string for 'string' type")?;
            for byte in s.as_bytes() {
                map.insert(Witness(*idx), FieldElement::from(*byte as u128));
                *idx += 1;
            }
        }
        "array" => {
            let inner_type = &abi_type["type"];
            let arr = toml_val
                .as_array()
                .context("Expected array for 'array' type")?;
            for elem in arr {
                encode_toml_value(elem, inner_type, map, idx)?;
            }
        }
        "tuple" => {
            let fields = abi_type["fields"]
                .as_array()
                .context("Tuple type missing 'fields'")?;
            let arr = toml_val
                .as_array()
                .context("Expected array for tuple type")?;
            for (field_type, val) in fields.iter().zip(arr.iter()) {
                encode_toml_value(val, field_type, map, idx)?;
            }
        }
        "struct" => {
            let fields = abi_type["fields"]
                .as_array()
                .context("Struct type missing 'fields'")?;
            let table = toml_val
                .as_table()
                .context("Expected table for struct type")?;
            for field in fields {
                let field_name = field["name"]
                    .as_str()
                    .context("Struct field missing 'name'")?;
                let field_type = &field["type"];
                let field_val = table
                    .get(field_name)
                    .with_context(|| format!("Struct missing field '{field_name}'"))?;
                encode_toml_value(field_val, field_type, map, idx)?;
            }
        }
        other => bail!("Unsupported ABI type kind: {other}"),
    }
    Ok(())
}

fn toml_to_field_element(val: &toml::Value) -> Result<FieldElement> {
    match val {
        toml::Value::Integer(n) => Ok(FieldElement::from(*n as u128)),
        toml::Value::String(s) => FieldElement::try_from_str(s)
            .ok_or_else(|| anyhow::anyhow!("Invalid field element string: {s}")),
        toml::Value::Boolean(b) => Ok(if *b {
            FieldElement::one()
        } else {
            FieldElement::zero()
        }),
        _ => bail!("Cannot convert TOML value to field element: {val:?}"),
    }
}

// --- JSON input parsing ---

fn read_inputs_json(
    json_str: &str,
    abi: &serde_json::Value,
) -> Result<WitnessMap<FieldElement>> {
    let json_obj: serde_json::Value =
        serde_json::from_str(json_str).context("Failed to parse inputs JSON")?;
    let json_map = json_obj
        .as_object()
        .context("Expected JSON object for inputs")?;

    let params = abi["parameters"]
        .as_array()
        .context("ABI missing 'parameters' array")?;

    let mut witness_map = WitnessMap::new();
    let mut idx: u32 = 0;

    for param in params {
        let name = param["name"]
            .as_str()
            .context("ABI parameter missing 'name'")?;
        let typ = &param["type"];
        let val = json_map
            .get(name)
            .with_context(|| format!("JSON input missing parameter '{name}'"))?;

        encode_json_value(val, typ, &mut witness_map, &mut idx)
            .with_context(|| format!("Failed to encode parameter '{name}'"))?;
    }

    Ok(witness_map)
}

fn encode_json_value(
    val: &serde_json::Value,
    abi_type: &serde_json::Value,
    map: &mut WitnessMap<FieldElement>,
    idx: &mut u32,
) -> Result<()> {
    let kind = abi_type["kind"]
        .as_str()
        .context("ABI type missing 'kind'")?;

    match kind {
        "field" | "boolean" | "integer" => {
            let fe = json_to_field_element(val)?;
            map.insert(Witness(*idx), fe);
            *idx += 1;
        }
        "string" => {
            let s = val.as_str().context("Expected string for 'string' type")?;
            for byte in s.as_bytes() {
                map.insert(Witness(*idx), FieldElement::from(*byte as u128));
                *idx += 1;
            }
        }
        "array" => {
            let inner_type = &abi_type["type"];
            let arr = val.as_array().context("Expected array for 'array' type")?;
            for elem in arr {
                encode_json_value(elem, inner_type, map, idx)?;
            }
        }
        "tuple" => {
            let fields = abi_type["fields"]
                .as_array()
                .context("Tuple type missing 'fields'")?;
            let arr = val
                .as_array()
                .context("Expected array for tuple type")?;
            for (field_type, v) in fields.iter().zip(arr.iter()) {
                encode_json_value(v, field_type, map, idx)?;
            }
        }
        "struct" => {
            let fields = abi_type["fields"]
                .as_array()
                .context("Struct type missing 'fields'")?;
            let obj = val
                .as_object()
                .context("Expected object for struct type")?;
            for field in fields {
                let field_name = field["name"]
                    .as_str()
                    .context("Struct field missing 'name'")?;
                let field_type = &field["type"];
                let field_val = obj
                    .get(field_name)
                    .with_context(|| format!("Struct missing field '{field_name}'"))?;
                encode_json_value(field_val, field_type, map, idx)?;
            }
        }
        other => bail!("Unsupported ABI type kind: {other}"),
    }
    Ok(())
}

fn json_to_field_element(val: &serde_json::Value) -> Result<FieldElement> {
    match val {
        serde_json::Value::Number(n) => {
            let i = n.as_u64().or_else(|| n.as_i64().map(|v| v as u64))
                .context("Cannot convert number to field element")?;
            Ok(FieldElement::from(i as u128))
        }
        serde_json::Value::String(s) => FieldElement::try_from_str(s)
            .ok_or_else(|| anyhow::anyhow!("Invalid field element string: {s}")),
        serde_json::Value::Bool(b) => Ok(if *b {
            FieldElement::one()
        } else {
            FieldElement::zero()
        }),
        _ => bail!("Cannot convert JSON value to field element: {val:?}"),
    }
}

// --- Serialization helpers ---

fn serialize_prover(prover: &BBProver) -> Result<Vec<u8>> {
    let data = serde_json::json!({
        "bytecode": prover.bytecode,
        "abi": prover.abi,
        "vk": prover.vk,
    });
    serde_json::to_vec(&data).context("Failed to serialize prover")
}

fn deserialize_prover(bytes: &[u8]) -> Result<BBProver> {
    let v: serde_json::Value =
        serde_json::from_slice(bytes).context("Failed to parse prover data")?;
    let bytecode = v["bytecode"]
        .as_str()
        .context("Missing 'bytecode'")?
        .to_owned();
    let abi = v["abi"].clone();
    let vk: Vec<u8> = serde_json::from_value(v["vk"].clone()).context("Missing 'vk'")?;
    Ok(BBProver { bytecode, abi, vk })
}

fn do_prove(prover: &BBProver, witness: WitnessMap<FieldElement>) -> Result<Vec<u8>, c_int> {
    noir_rs::barretenberg::srs::setup_srs_from_bytecode(&prover.bytecode, None, false)
        .map_err(|_| PROOF_ERROR)?;

    noir_rs::barretenberg::prove::prove_ultra_honk(
        &prover.bytecode,
        witness,
        prover.vk.clone(),
        false,
    )
    .map_err(|_| PROOF_ERROR)
}

// ---------------------------------------------------------------------------
// FFI: Lifecycle
// ---------------------------------------------------------------------------

// No bb_init needed — SRS setup happens lazily in prepare/prove.

// ---------------------------------------------------------------------------
// FFI: Prepare
// ---------------------------------------------------------------------------

/// Compile a Noir circuit into prover and verifier handles.
///
/// # Safety
///
/// - `circuit_path` must be a valid null-terminated C string.
/// - `out_prover` and `out_verifier` must be valid, non-null pointers.
#[no_mangle]
pub unsafe extern "C" fn bb_prepare(
    circuit_path: *const c_char,
    out_prover: *mut *mut BBProver,
    out_verifier: *mut *mut BBVerifier,
) -> c_int {
    if out_prover.is_null() || out_verifier.is_null() {
        return INVALID_INPUT;
    }

    catch_panic(COMPILATION_ERROR, || {
        *out_prover = std::ptr::null_mut();
        *out_verifier = std::ptr::null_mut();

        let result = (|| -> Result<(*mut BBProver, *mut BBVerifier), c_int> {
            let circuit_path = c_str_to_string(circuit_path)?;

            let (bytecode, abi) =
                read_acir_json(Path::new(&circuit_path)).map_err(|_| SCHEME_READ_ERROR)?;

            noir_rs::barretenberg::srs::setup_srs_from_bytecode(&bytecode, None, false)
                .map_err(|_| COMPILATION_ERROR)?;

            let vk =
                noir_rs::barretenberg::verify::get_ultra_honk_verification_key(&bytecode, false)
                    .map_err(|_| COMPILATION_ERROR)?;

            let pk = Box::into_raw(Box::new(BBProver {
                bytecode,
                abi,
                vk: vk.clone(),
            }));
            let vk_handle = Box::into_raw(Box::new(BBVerifier { vk }));

            Ok((pk, vk_handle))
        })();

        match result {
            Ok((pk, vk)) => {
                *out_prover = pk;
                *out_verifier = vk;
                SUCCESS
            }
            Err(code) => code,
        }
    })
}

// ---------------------------------------------------------------------------
// FFI: Load (from file)
// ---------------------------------------------------------------------------

/// Load a BB prover from a file.
///
/// # Safety
///
/// - `path` must be a valid null-terminated C string.
/// - `out` must be a valid, non-null pointer.
#[no_mangle]
pub unsafe extern "C" fn bb_load_prover(path: *const c_char, out: *mut *mut BBProver) -> c_int {
    if out.is_null() {
        return INVALID_INPUT;
    }

    catch_panic(SCHEME_READ_ERROR, || {
        *out = std::ptr::null_mut();

        let result = (|| -> Result<*mut BBProver, c_int> {
            let path = c_str_to_string(path)?;
            let bytes = std::fs::read(Path::new(&path)).map_err(|_| SCHEME_READ_ERROR)?;
            let prover = deserialize_prover(&bytes).map_err(|_| SCHEME_READ_ERROR)?;
            Ok(Box::into_raw(Box::new(prover)))
        })();

        match result {
            Ok(handle) => {
                *out = handle;
                SUCCESS
            }
            Err(code) => code,
        }
    })
}

/// Load a BB verifier from a file (raw VK bytes).
///
/// # Safety
///
/// - `path` must be a valid null-terminated C string.
/// - `out` must be a valid, non-null pointer.
#[no_mangle]
pub unsafe extern "C" fn bb_load_verifier(
    path: *const c_char,
    out: *mut *mut BBVerifier,
) -> c_int {
    if out.is_null() {
        return INVALID_INPUT;
    }

    catch_panic(SCHEME_READ_ERROR, || {
        *out = std::ptr::null_mut();

        let result = (|| -> Result<*mut BBVerifier, c_int> {
            let path = c_str_to_string(path)?;
            let vk = std::fs::read(Path::new(&path)).map_err(|_| SCHEME_READ_ERROR)?;
            Ok(Box::into_raw(Box::new(BBVerifier { vk })))
        })();

        match result {
            Ok(handle) => {
                *out = handle;
                SUCCESS
            }
            Err(code) => code,
        }
    })
}

// ---------------------------------------------------------------------------
// FFI: Load (from bytes)
// ---------------------------------------------------------------------------

/// Load a BB prover from bytes.
///
/// # Safety
///
/// - `ptr` must point to `len` valid bytes.
/// - `out` must be a valid, non-null pointer.
#[no_mangle]
pub unsafe extern "C" fn bb_load_prover_bytes(
    ptr: *const u8,
    len: usize,
    out: *mut *mut BBProver,
) -> c_int {
    if out.is_null() || ptr.is_null() || len == 0 {
        return INVALID_INPUT;
    }

    catch_panic(SCHEME_READ_ERROR, || {
        *out = std::ptr::null_mut();

        let data = std::slice::from_raw_parts(ptr, len);
        match deserialize_prover(data) {
            Ok(prover) => {
                *out = Box::into_raw(Box::new(prover));
                SUCCESS
            }
            Err(_) => SCHEME_READ_ERROR,
        }
    })
}

/// Load a BB verifier from bytes (raw VK).
///
/// # Safety
///
/// - `ptr` must point to `len` valid bytes.
/// - `out` must be a valid, non-null pointer.
#[no_mangle]
pub unsafe extern "C" fn bb_load_verifier_bytes(
    ptr: *const u8,
    len: usize,
    out: *mut *mut BBVerifier,
) -> c_int {
    if out.is_null() || ptr.is_null() || len == 0 {
        return INVALID_INPUT;
    }

    catch_panic(SCHEME_READ_ERROR, || {
        *out = std::ptr::null_mut();

        let data = std::slice::from_raw_parts(ptr, len);
        *out = Box::into_raw(Box::new(BBVerifier {
            vk: data.to_vec(),
        }));
        SUCCESS
    })
}

// ---------------------------------------------------------------------------
// FFI: Save (to file)
// ---------------------------------------------------------------------------

/// Save a BB prover to a file.
///
/// # Safety
///
/// - `prover` must be a valid handle.
/// - `path` must be a valid null-terminated C string.
#[no_mangle]
pub unsafe extern "C" fn bb_save_prover(prover: *const BBProver, path: *const c_char) -> c_int {
    if prover.is_null() {
        return INVALID_INPUT;
    }

    catch_panic(FILE_WRITE_ERROR, || {
        let result = (|| -> Result<(), c_int> {
            let path = c_str_to_string(path)?;
            let bytes = serialize_prover(&*prover).map_err(|_| SERIALIZATION_ERROR)?;
            std::fs::write(Path::new(&path), bytes).map_err(|_| FILE_WRITE_ERROR)
        })();

        match result {
            Ok(()) => SUCCESS,
            Err(code) => code,
        }
    })
}

/// Save a BB verifier to a file (raw VK bytes).
///
/// # Safety
///
/// - `verifier` must be a valid handle.
/// - `path` must be a valid null-terminated C string.
#[no_mangle]
pub unsafe extern "C" fn bb_save_verifier(
    verifier: *const BBVerifier,
    path: *const c_char,
) -> c_int {
    if verifier.is_null() {
        return INVALID_INPUT;
    }

    catch_panic(FILE_WRITE_ERROR, || {
        let result = (|| -> Result<(), c_int> {
            let path = c_str_to_string(path)?;
            std::fs::write(Path::new(&path), &(*verifier).vk).map_err(|_| FILE_WRITE_ERROR)
        })();

        match result {
            Ok(()) => SUCCESS,
            Err(code) => code,
        }
    })
}

// ---------------------------------------------------------------------------
// FFI: Serialize (to bytes)
// ---------------------------------------------------------------------------

/// Serialize a BB prover to bytes.
///
/// # Safety
///
/// - `prover` must be a valid handle.
/// - `out` must be a valid, non-null pointer.
/// - Caller must free the buffer via `bb_free_buf`.
#[no_mangle]
pub unsafe extern "C" fn bb_serialize_prover(prover: *const BBProver, out: *mut BBBuf) -> c_int {
    if prover.is_null() || out.is_null() {
        return INVALID_INPUT;
    }

    catch_panic(SERIALIZATION_ERROR, || {
        let out = &mut *out;
        *out = BBBuf::empty();

        match serialize_prover(&*prover) {
            Ok(bytes) => {
                *out = BBBuf::from_vec(bytes);
                SUCCESS
            }
            Err(_) => SERIALIZATION_ERROR,
        }
    })
}

/// Serialize a BB verifier to bytes (raw VK).
///
/// # Safety
///
/// - `verifier` must be a valid handle.
/// - `out` must be a valid, non-null pointer.
/// - Caller must free the buffer via `bb_free_buf`.
#[no_mangle]
pub unsafe extern "C" fn bb_serialize_verifier(
    verifier: *const BBVerifier,
    out: *mut BBBuf,
) -> c_int {
    if verifier.is_null() || out.is_null() {
        return INVALID_INPUT;
    }

    catch_panic(SERIALIZATION_ERROR, || {
        let out = &mut *out;
        *out = BBBuf::empty();

        *out = BBBuf::from_vec((*verifier).vk.clone());
        SUCCESS
    })
}

// ---------------------------------------------------------------------------
// FFI: Prove
// ---------------------------------------------------------------------------

/// Prove using a prover handle and a TOML input file.
///
/// # Safety
///
/// - `prover` must be a valid handle.
/// - `toml_path` must be a valid null-terminated C string.
/// - `out_proof` must be a valid, non-null pointer.
/// - Caller must free the buffer via `bb_free_buf`.
#[no_mangle]
pub unsafe extern "C" fn bb_prove_toml(
    prover: *const BBProver,
    toml_path: *const c_char,
    out_proof: *mut BBBuf,
) -> c_int {
    if prover.is_null() || out_proof.is_null() {
        return INVALID_INPUT;
    }

    catch_panic(PROOF_ERROR, || {
        let out_proof = &mut *out_proof;
        *out_proof = BBBuf::empty();

        let result = (|| -> Result<Vec<u8>, c_int> {
            let toml_path = c_str_to_string(toml_path)?;
            let witness =
                read_inputs(Path::new(&toml_path), &(*prover).abi).map_err(|_| INVALID_INPUT)?;
            do_prove(&*prover, witness)
        })();

        match result {
            Ok(proof_bytes) => {
                *out_proof = BBBuf::from_vec(proof_bytes);
                SUCCESS
            }
            Err(code) => code,
        }
    })
}

/// Prove using a prover handle and a JSON string of inputs.
///
/// # Safety
///
/// - `prover` must be a valid handle.
/// - `inputs_json` must be a valid null-terminated UTF-8 C string.
/// - `out_proof` must be a valid, non-null pointer.
/// - Caller must free the buffer via `bb_free_buf`.
#[no_mangle]
pub unsafe extern "C" fn bb_prove_json(
    prover: *const BBProver,
    inputs_json: *const c_char,
    out_proof: *mut BBBuf,
) -> c_int {
    if prover.is_null() || out_proof.is_null() {
        return INVALID_INPUT;
    }

    catch_panic(PROOF_ERROR, || {
        let out_proof = &mut *out_proof;
        *out_proof = BBBuf::empty();

        let result = (|| -> Result<Vec<u8>, c_int> {
            let json_str = c_str_to_string(inputs_json)?;
            let witness =
                read_inputs_json(&json_str, &(*prover).abi).map_err(|_| INVALID_INPUT)?;
            do_prove(&*prover, witness)
        })();

        match result {
            Ok(proof_bytes) => {
                *out_proof = BBBuf::from_vec(proof_bytes);
                SUCCESS
            }
            Err(code) => code,
        }
    })
}

// ---------------------------------------------------------------------------
// FFI: Verify
// ---------------------------------------------------------------------------

/// Verify a proof using a verifier handle.
///
/// Returns `SUCCESS` (0) if valid, `PROOF_ERROR` (4) if invalid.
///
/// # Safety
///
/// - `verifier` must be a valid handle.
/// - `proof_ptr` must point to `proof_len` valid bytes.
#[no_mangle]
pub unsafe extern "C" fn bb_verify(
    verifier: *const BBVerifier,
    proof_ptr: *const u8,
    proof_len: usize,
) -> c_int {
    if verifier.is_null() || proof_ptr.is_null() || proof_len == 0 {
        return INVALID_INPUT;
    }

    catch_panic(PROOF_ERROR, || {
        let proof_bytes = std::slice::from_raw_parts(proof_ptr, proof_len);

        match noir_rs::barretenberg::verify::verify_ultra_honk(
            proof_bytes.to_vec(),
            (*verifier).vk.clone(),
        ) {
            Ok(true) => SUCCESS,
            Ok(false) => PROOF_ERROR,
            Err(_) => PROOF_ERROR,
        }
    })
}

// ---------------------------------------------------------------------------
// FFI: Cleanup
// ---------------------------------------------------------------------------

/// Free a prover handle.
///
/// # Safety
///
/// `prover` must have been created by `bb_prepare` or `bb_load_prover`.
#[no_mangle]
pub unsafe extern "C" fn bb_free_prover(prover: *mut BBProver) {
    if !prover.is_null() {
        drop(Box::from_raw(prover));
    }
}

/// Free a verifier handle.
///
/// # Safety
///
/// `verifier` must have been created by `bb_prepare` or `bb_load_verifier`.
#[no_mangle]
pub unsafe extern "C" fn bb_free_verifier(verifier: *mut BBVerifier) {
    if !verifier.is_null() {
        drop(Box::from_raw(verifier));
    }
}

/// Free a buffer allocated by Barretenberg FFI functions.
///
/// # Safety
///
/// The buffer must have been allocated by a `bb_*` FFI function.
#[no_mangle]
pub unsafe extern "C" fn bb_free_buf(buf: BBBuf) {
    if !buf.ptr.is_null() && buf.cap > 0 {
        drop(Vec::from_raw_parts(buf.ptr, buf.len, buf.cap));
    }
}
