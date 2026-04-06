#ifndef VERITY_FFI_H
#define VERITY_FFI_H

/**
 * @file verity_ffi.h
 * @brief Verity SDK — public C API for zero-knowledge proof generation and verification.
 *
 * This is the stable public interface. All SDK bindings (Swift, Kotlin, JS)
 * call these functions. Backend-specific symbols are in verity_ffi_raw.h.
 *
 * Typical workflow:
 *   1. verity_init()           — initialize the backend (once)
 *   2. verity_load_prover()    — load a pre-compiled prover scheme
 *      verity_load_verifier()  — load a pre-compiled verifier scheme
 *   3. verity_prove_*()        — generate a proof
 *   4. verity_verify()         — verify the proof
 *   5. verity_free_*()         — clean up handles and buffers
 */

#include <stdint.h>
#include <stdbool.h>

/* ── Version ─────────────────────────────────────────────────────────── */

#define VERITY_VERSION_MAJOR 0
#define VERITY_VERSION_MINOR 2
#define VERITY_VERSION_PATCH 0
#define VERITY_VERSION_STRING "0.2.0"

#ifdef __cplusplus
extern "C" {
#endif

/* ── Types ────────────────────────────────────────────────────────────── */

/** Proving backend selection. */
typedef enum {
    VERITY_BACKEND_PROVEKIT       = 0,  /**< ProveKit WHIR (transparent, hash-based) */
    VERITY_BACKEND_BARRETENBERG   = 1,  /**< Barretenberg UltraHonk (KZG commitments) */
} VerityBackend;

/**
 * Error codes returned by all verity_* functions.
 * SDKs map these to typed exceptions/errors.
 */
typedef enum {
    VERITY_SUCCESS             = 0,  /**< Operation succeeded */
    VERITY_INVALID_INPUT       = 1,  /**< NULL pointer or empty data */
    VERITY_SCHEME_READ_ERROR   = 2,  /**< Failed to read scheme or circuit file */
    VERITY_WITNESS_READ_ERROR  = 3,  /**< Failed to parse witness/input file */
    VERITY_PROOF_ERROR         = 4,  /**< Proof generation or verification failed */
    VERITY_SERIALIZATION_ERROR = 5,  /**< Serialization/deserialization error */
    VERITY_UTF8_ERROR          = 6,  /**< String contains invalid UTF-8 */
    VERITY_FILE_WRITE_ERROR    = 7,  /**< Failed to write file */
    VERITY_COMPILATION_ERROR   = 8,  /**< Reserved (formerly circuit compilation) */
    VERITY_UNKNOWN_BACKEND     = 9,  /**< Unknown or unregistered backend */
    VERITY_OUT_OF_MEMORY       = 10, /**< Memory allocation failed */
} VerityError;

/**
 * Buffer for returning variable-length data from FFI calls.
 *
 * When a verity_* function fills this buffer, the caller owns the memory
 * and MUST free it with verity_free_buf(). Do not call free() directly.
 */
typedef struct {
    uint8_t  *ptr;   /**< Pointer to data (NULL if empty) */
    uintptr_t len;   /**< Number of valid bytes */
    uintptr_t cap;   /**< Allocated capacity (internal) */
    int       backend; /**< Backend that allocated this buffer (for correct deallocation) */
} VerityBuf;

/** Opaque prover handle. Created by verity_load_prover(). */
typedef struct VerityProver VerityProver;

/** Opaque verifier handle. Created by verity_load_verifier(). */
typedef struct VerityVerifier VerityVerifier;

/* ── Lifecycle ────────────────────────────────────────────────────────── */

/**
 * Initialize a proving backend. Must be called once per backend before use.
 * Safe to call multiple times (idempotent after first success).
 *
 * Thread safety: NOT thread-safe. Callers must synchronize concurrent calls.
 * The Swift and Kotlin SDKs handle this internally.
 *
 * @param backend  The backend to initialize.
 * @return VERITY_SUCCESS on success, or an error code.
 */
int verity_init(VerityBackend backend);

/* ── Load ─────────────────────────────────────────────────────────────── */

/**
 * Load a prover scheme from a file previously saved with verity_save_prover().
 *
 * @param backend  The backend that produced the saved scheme.
 * @param path     Path to the saved prover file.
 * @param out      Receives the prover handle on success.
 * @return VERITY_SUCCESS on success, or an error code.
 */
int verity_load_prover(VerityBackend backend,
                       const char *path,
                       VerityProver **out);

/**
 * Load a verifier scheme from a file previously saved with verity_save_verifier().
 *
 * @param backend  The backend that produced the saved scheme.
 * @param path     Path to the saved verifier file.
 * @param out      Receives the verifier handle on success.
 * @return VERITY_SUCCESS on success, or an error code.
 */
int verity_load_verifier(VerityBackend backend,
                         const char *path,
                         VerityVerifier **out);

/**
 * Load a prover scheme from bytes (same format as saved files).
 *
 * Useful for schemes downloaded from a URL or bundled in an app.
 *
 * @param backend  The backend that produced the serialized scheme.
 * @param ptr      Pointer to serialized prover bytes.
 * @param len      Length of the byte buffer.
 * @param out      Receives the prover handle on success.
 * @return VERITY_SUCCESS on success, or an error code.
 */
int verity_load_prover_bytes(VerityBackend backend,
                             const uint8_t *ptr, uintptr_t len,
                             VerityProver **out);

/**
 * Load a verifier scheme from bytes (same format as saved files).
 *
 * @param backend  The backend that produced the serialized scheme.
 * @param ptr      Pointer to serialized verifier bytes.
 * @param len      Length of the byte buffer.
 * @param out      Receives the verifier handle on success.
 * @return VERITY_SUCCESS on success, or an error code.
 */
int verity_load_verifier_bytes(VerityBackend backend,
                               const uint8_t *ptr, uintptr_t len,
                               VerityVerifier **out);

/* ── Save ─────────────────────────────────────────────────────────────── */

/**
 * Save a prover scheme to a file for later reuse via verity_load_prover().
 *
 * @param prover  Prover handle from verity_load_prover().
 * @param path    Destination file path. Parent directory must exist.
 * @return VERITY_SUCCESS on success, or an error code.
 */
int verity_save_prover(const VerityProver *prover, const char *path);

/**
 * Save a verifier scheme to a file for later reuse via verity_load_verifier().
 *
 * @param verifier  Verifier handle from verity_load_verifier().
 * @param path      Destination file path. Parent directory must exist.
 * @return VERITY_SUCCESS on success, or an error code.
 */
int verity_save_verifier(const VerityVerifier *verifier, const char *path);

/* ── Serialize ────────────────────────────────────────────────────────── */

/**
 * Serialize a prover scheme to bytes. Same format as verity_save_prover() writes.
 *
 * @param prover  Prover handle.
 * @param out     Receives the serialized bytes. Caller must free with verity_free_buf().
 * @return VERITY_SUCCESS on success, or an error code.
 */
int verity_serialize_prover(const VerityProver *prover, VerityBuf *out);

/**
 * Serialize a verifier scheme to bytes. Same format as verity_save_verifier() writes.
 *
 * @param verifier  Verifier handle.
 * @param out       Receives the serialized bytes. Caller must free with verity_free_buf().
 * @return VERITY_SUCCESS on success, or an error code.
 */
int verity_serialize_verifier(const VerityVerifier *verifier, VerityBuf *out);

/* ── Prove ────────────────────────────────────────────────────────────── */

/**
 * Generate a proof using a TOML input file.
 *
 * The TOML file should contain witness values matching the circuit's ABI.
 * Typically this is the `Prover.toml` file from `nargo execute`.
 *
 * Thread safety: safe to call concurrently with distinct prover handles.
 *
 * @param prover     Prover handle from verity_load_prover().
 * @param toml_path  Path to TOML input file.
 * @param out_proof  Receives proof bytes. Caller must free with verity_free_buf().
 * @return VERITY_SUCCESS on success, or an error code.
 */
int verity_prove_toml(const VerityProver *prover,
                      const char *toml_path,
                      VerityBuf *out_proof);

/**
 * Generate a proof using a JSON input string.
 *
 * The JSON object should map parameter names to values matching the circuit's ABI.
 * Field elements should be strings (e.g., "5" or "0x1a2b...").
 *
 * Thread safety: safe to call concurrently with distinct prover handles.
 *
 * @param prover       Prover handle from verity_load_prover().
 * @param inputs_json  JSON string of inputs (e.g., {"x": "5", "y": "10"}).
 * @param out_proof    Receives proof bytes. Caller must free with verity_free_buf().
 * @return VERITY_SUCCESS on success, or an error code.
 */
int verity_prove_json(const VerityProver *prover,
                      const char *inputs_json,
                      VerityBuf *out_proof);

/* ── Verify ───────────────────────────────────────────────────────────── */

/**
 * Verify a proof against the verifier scheme.
 *
 * Thread safety: safe to call concurrently with distinct verifier handles.
 *
 * @param verifier   Verifier handle from verity_load_verifier().
 * @param proof_ptr  Pointer to proof bytes (from verity_prove_*).
 * @param proof_len  Length of proof bytes.
 * @return VERITY_SUCCESS (0) if proof is valid,
 *         VERITY_PROOF_ERROR (4) if proof is invalid,
 *         or another error code on failure.
 */
int verity_verify(const VerityVerifier *verifier,
                  const uint8_t *proof_ptr,
                  uintptr_t proof_len);

/* ── Cleanup ──────────────────────────────────────────────────────────── */

/**
 * Free a prover handle. Safe to call with NULL (no-op).
 * @param prover  Handle to free, or NULL.
 */
void verity_free_prover(VerityProver *prover);

/**
 * Free a verifier handle. Safe to call with NULL (no-op).
 * @param verifier  Handle to free, or NULL.
 */
void verity_free_verifier(VerityVerifier *verifier);

/**
 * Free a buffer returned by verity_prove_*, verity_serialize_*, etc.
 * Do not call free() on VerityBuf.ptr directly — use this function.
 * @param buf  The buffer to free. After this call, buf.ptr is invalid.
 */
void verity_free_buf(VerityBuf buf);

/**
 * Retrieve the last error message from a backend, if any.
 *
 * After a verity_* call returns a non-zero error code, call this function to
 * obtain a human-readable description of the failure.  The message is cleared
 * once retrieved (i.e. a second call returns an empty buffer).
 *
 * @note **Thread-safety:** The error store is global (per-process), not
 *       per-thread.  In a multi-threaded program a successful call on one
 *       thread may clear the pending error set by a failing call on another.
 *       Retrieve the error message immediately after a failing call, before
 *       making any other backend call from any thread.
 *
 * @param backend      The backend to query.
 * @param out_message  On success, receives the error string as a VerityBuf.
 *                     If no error is pending, out_message->ptr is NULL and
 *                     out_message->len is 0.  The caller must free a non-NULL
 *                     buffer with verity_free_buf().
 * @return VERITY_SUCCESS on success, or an error code.
 */
int verity_last_error_message(VerityBackend backend, VerityBuf *out_message);

/* ── Memory (ProveKit-specific — use verity_pk_ prefix) ──────────────── */

/**
 * Configure the ProveKit memory allocator. Call before verity_init().
 *
 * Allows limiting RAM usage and enabling file-backed memory for large circuits
 * on memory-constrained devices (e.g., mobile).
 *
 * @param ram_limit_bytes  Maximum RAM for the prover (0 = unlimited).
 * @param use_file_backed  If true, spill allocations to a swap file.
 * @param swap_file_path   Path to swap file (required if use_file_backed is true).
 * @return VERITY_SUCCESS on success, or an error code.
 */
int verity_pk_configure_memory(uintptr_t ram_limit_bytes,
                            bool use_file_backed,
                            const char *swap_file_path);

/**
 * Get current ProveKit memory usage statistics.
 *
 * @param ram_used   Receives current RAM usage in bytes.
 * @param swap_used  Receives current swap usage in bytes.
 * @param peak_ram   Receives peak RAM usage in bytes.
 * @return VERITY_SUCCESS on success, or an error code.
 */
int verity_pk_get_memory_stats(uintptr_t *ram_used,
                            uintptr_t *swap_used,
                            uintptr_t *peak_ram);

#ifdef __cplusplus
}
#endif

#endif /* VERITY_FFI_H */
