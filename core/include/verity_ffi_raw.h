#ifndef VERITY_FFI_RAW_H
#define VERITY_FFI_RAW_H

/// Raw backend symbols from the xcframework (pk_* and bb_*).
/// This header is used by the VerityDispatch C dispatcher to link against
/// the pre-built static libraries. It is NOT the public SDK header.
/// The public header is core/include/verity_ffi.h.

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

// Buffer types (identical layout across backends)
typedef struct { uint8_t *ptr; uintptr_t len; uintptr_t cap; } PKBuf;
typedef struct { uint8_t *ptr; uintptr_t len; uintptr_t cap; } BBBuf;

// --- ProveKit (pk_*) ---

typedef struct PKProver PKProver;
typedef struct PKVerifier PKVerifier;

int  pk_init(void);
int  pk_configure_memory(uintptr_t ram_limit_bytes, bool use_file_backed, const char *swap_file_path);
int  pk_get_memory_stats(uintptr_t *ram_used, uintptr_t *swap_used, uintptr_t *peak_ram);
int  pk_prepare(const char *circuit_path, PKProver **out_prover, PKVerifier **out_verifier);
int  pk_load_prover(const char *path, PKProver **out);
int  pk_load_verifier(const char *path, PKVerifier **out);
int  pk_load_prover_bytes(const uint8_t *ptr, uintptr_t len, PKProver **out);
int  pk_load_verifier_bytes(const uint8_t *ptr, uintptr_t len, PKVerifier **out);
int  pk_save_prover(const PKProver *prover, const char *path);
int  pk_save_verifier(const PKVerifier *verifier, const char *path);
int  pk_serialize_prover(const PKProver *prover, PKBuf *out);
int  pk_serialize_verifier(const PKVerifier *verifier, PKBuf *out);
int  pk_prove_toml(const PKProver *prover, const char *toml_path, PKBuf *out);
int  pk_prove_json(const PKProver *prover, const char *inputs_json, PKBuf *out);
int  pk_verify(const PKVerifier *verifier, const uint8_t *proof_ptr, uintptr_t proof_len);
void pk_free_prover(PKProver *prover);
void pk_free_verifier(PKVerifier *verifier);
void pk_free_buf(PKBuf buf);

// --- Barretenberg (bb_*) ---
// To add a new backend, copy this section with your prefix (e.g., h2_*).

typedef struct BBProver BBProver;
typedef struct BBVerifier BBVerifier;

int  bb_prepare(const char *circuit_path, BBProver **out_prover, BBVerifier **out_verifier);
int  bb_load_prover(const char *path, BBProver **out);
int  bb_load_verifier(const char *path, BBVerifier **out);
int  bb_load_prover_bytes(const uint8_t *ptr, uintptr_t len, BBProver **out);
int  bb_load_verifier_bytes(const uint8_t *ptr, uintptr_t len, BBVerifier **out);
int  bb_save_prover(const BBProver *prover, const char *path);
int  bb_save_verifier(const BBVerifier *verifier, const char *path);
int  bb_serialize_prover(const BBProver *prover, BBBuf *out);
int  bb_serialize_verifier(const BBVerifier *verifier, BBBuf *out);
int  bb_prove_toml(const BBProver *prover, const char *toml_path, BBBuf *out);
int  bb_prove_json(const BBProver *prover, const char *inputs_json, BBBuf *out);
int  bb_verify(const BBVerifier *verifier, const uint8_t *proof_ptr, uintptr_t proof_len);
void bb_free_prover(BBProver *prover);
void bb_free_verifier(BBVerifier *verifier);
void bb_free_buf(BBBuf buf);

#ifdef __cplusplus
}
#endif

#endif // VERITY_FFI_RAW_H
