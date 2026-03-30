#ifndef VERITY_FFI_H
#define VERITY_FFI_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// ── Types ──────────────────────────────────────────────────────────────────

/// Proving backend selection.
typedef enum {
    VERITY_BACKEND_PROVEKIT       = 0,
    VERITY_BACKEND_BARRETENBERG   = 1,
} VerityBackend;

/// Error codes returned by all verity_* functions.
typedef enum {
    VERITY_SUCCESS             = 0,
    VERITY_INVALID_INPUT       = 1,
    VERITY_SCHEME_READ_ERROR   = 2,
    VERITY_WITNESS_READ_ERROR  = 3,
    VERITY_PROOF_ERROR         = 4,
    VERITY_SERIALIZATION_ERROR = 5,
    VERITY_UTF8_ERROR          = 6,
    VERITY_FILE_WRITE_ERROR    = 7,
    VERITY_COMPILATION_ERROR   = 8,
    VERITY_UNKNOWN_BACKEND     = 9,
} VerityError;

/// Buffer for returning variable-length data.
/// Caller must free with verity_free_buf().
typedef struct {
    uint8_t  *ptr;
    uintptr_t len;
    uintptr_t cap;
} VerityBuf;

/// Opaque prover handle. Carries its backend tag internally.
typedef struct VerityProver VerityProver;

/// Opaque verifier handle. Carries its backend tag internally.
typedef struct VerityVerifier VerityVerifier;

// ── Lifecycle ──────────────────────────────────────────────────────────────

/// Initialize a backend. Call once per backend before using it.
int verity_init(VerityBackend backend);

// ── Prepare ────────────────────────────────────────────────────────────────

/// Compile a circuit into prover + verifier handles (no files written).
int verity_prepare(VerityBackend backend,
                   const char *circuit_path,
                   VerityProver **out_prover,
                   VerityVerifier **out_verifier);

// ── Load ───────────────────────────────────────────────────────────────────

/// Load prover from file.
int verity_load_prover(VerityBackend backend,
                       const char *path,
                       VerityProver **out);

/// Load verifier from file.
int verity_load_verifier(VerityBackend backend,
                         const char *path,
                         VerityVerifier **out);

/// Load prover from bytes (same format as saved files).
int verity_load_prover_bytes(VerityBackend backend,
                             const uint8_t *ptr, uintptr_t len,
                             VerityProver **out);

/// Load verifier from bytes (same format as saved files).
int verity_load_verifier_bytes(VerityBackend backend,
                               const uint8_t *ptr, uintptr_t len,
                               VerityVerifier **out);

// ── Save ───────────────────────────────────────────────────────────────────

/// Save prover to file.
int verity_save_prover(const VerityProver *prover, const char *path);

/// Save verifier to file.
int verity_save_verifier(const VerityVerifier *verifier, const char *path);

// ── Serialize ──────────────────────────────────────────────────────────────

/// Serialize prover to bytes. Caller frees buf with verity_free_buf().
int verity_serialize_prover(const VerityProver *prover, VerityBuf *out);

/// Serialize verifier to bytes. Caller frees buf with verity_free_buf().
int verity_serialize_verifier(const VerityVerifier *verifier, VerityBuf *out);

// ── Prove ──────────────────────────────────────────────────────────────────

/// Prove with TOML input file. Returns proof bytes in out_proof.
int verity_prove_toml(const VerityProver *prover,
                      const char *toml_path,
                      VerityBuf *out_proof);

/// Prove with JSON input string. Returns proof bytes in out_proof.
int verity_prove_json(const VerityProver *prover,
                      const char *inputs_json,
                      VerityBuf *out_proof);

// ── Verify ─────────────────────────────────────────────────────────────────

/// Verify a proof. Returns VERITY_SUCCESS (0) if valid, VERITY_PROOF_ERROR (4) if not.
int verity_verify(const VerityVerifier *verifier,
                  const uint8_t *proof_ptr,
                  uintptr_t proof_len);

// ── Cleanup ────────────────────────────────────────────────────────────────

/// Free a prover handle.
void verity_free_prover(VerityProver *prover);

/// Free a verifier handle.
void verity_free_verifier(VerityVerifier *verifier);

/// Free a buffer returned by verity_* functions.
void verity_free_buf(VerityBuf buf);

// ── Memory (ProveKit-specific) ─────────────────────────────────────────────

/// Configure ProveKit memory allocator. Call before verity_init().
int verity_configure_memory(uintptr_t ram_limit_bytes,
                            bool use_file_backed,
                            const char *swap_file_path);

/// Get ProveKit memory stats.
int verity_get_memory_stats(uintptr_t *ram_used,
                            uintptr_t *swap_used,
                            uintptr_t *peak_ram);

#ifdef __cplusplus
}
#endif

#endif // VERITY_FFI_H
