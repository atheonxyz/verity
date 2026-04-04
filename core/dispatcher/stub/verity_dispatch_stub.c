#include "../include/verity_ffi.h"
#include <stddef.h>

struct VerityProver {
    int unused;
};

struct VerityVerifier {
    int unused;
};

static void clear_buf(VerityBuf *buf) {
    if (!buf) {
        return;
    }
    buf->ptr = NULL;
    buf->len = 0;
    buf->cap = 0;
    buf->backend = 0;
}

int verity_init(VerityBackend backend) {
    (void)backend;
    return VERITY_UNKNOWN_BACKEND;
}

int verity_load_prover(VerityBackend backend, const char *path, VerityProver **out) {
    (void)backend;
    (void)path;
    if (!out) return VERITY_INVALID_INPUT;
    *out = NULL;
    return VERITY_UNKNOWN_BACKEND;
}

int verity_load_verifier(VerityBackend backend, const char *path, VerityVerifier **out) {
    (void)backend;
    (void)path;
    if (!out) return VERITY_INVALID_INPUT;
    *out = NULL;
    return VERITY_UNKNOWN_BACKEND;
}

int verity_load_prover_bytes(VerityBackend backend,
                             const uint8_t *ptr,
                             uintptr_t len,
                             VerityProver **out) {
    (void)backend;
    (void)ptr;
    (void)len;
    if (!out) return VERITY_INVALID_INPUT;
    *out = NULL;
    return VERITY_UNKNOWN_BACKEND;
}

int verity_load_verifier_bytes(VerityBackend backend,
                               const uint8_t *ptr,
                               uintptr_t len,
                               VerityVerifier **out) {
    (void)backend;
    (void)ptr;
    (void)len;
    if (!out) return VERITY_INVALID_INPUT;
    *out = NULL;
    return VERITY_UNKNOWN_BACKEND;
}

int verity_save_prover(const VerityProver *prover, const char *path) {
    (void)prover;
    (void)path;
    return VERITY_UNKNOWN_BACKEND;
}

int verity_save_verifier(const VerityVerifier *verifier, const char *path) {
    (void)verifier;
    (void)path;
    return VERITY_UNKNOWN_BACKEND;
}

int verity_serialize_prover(const VerityProver *prover, VerityBuf *out) {
    (void)prover;
    clear_buf(out);
    return VERITY_UNKNOWN_BACKEND;
}

int verity_serialize_verifier(const VerityVerifier *verifier, VerityBuf *out) {
    (void)verifier;
    clear_buf(out);
    return VERITY_UNKNOWN_BACKEND;
}

int verity_prove_toml(const VerityProver *prover, const char *toml_path, VerityBuf *out_proof) {
    (void)prover;
    (void)toml_path;
    clear_buf(out_proof);
    return VERITY_UNKNOWN_BACKEND;
}

int verity_prove_json(const VerityProver *prover, const char *inputs_json, VerityBuf *out_proof) {
    (void)prover;
    (void)inputs_json;
    clear_buf(out_proof);
    return VERITY_UNKNOWN_BACKEND;
}

int verity_verify(const VerityVerifier *verifier, const uint8_t *proof_ptr, uintptr_t proof_len) {
    (void)verifier;
    (void)proof_ptr;
    (void)proof_len;
    return VERITY_UNKNOWN_BACKEND;
}

int verity_last_error_message(VerityBackend backend, VerityBuf *out_message) {
    (void)backend;
    clear_buf(out_message);
    return VERITY_UNKNOWN_BACKEND;
}

void verity_free_prover(VerityProver *prover) {
    (void)prover;
}

void verity_free_verifier(VerityVerifier *verifier) {
    (void)verifier;
}

void verity_free_buf(VerityBuf buf) {
    (void)buf;
}

int verity_pk_configure_memory(uintptr_t ram_limit_bytes,
                               bool use_file_backed,
                               const char *swap_file_path) {
    (void)ram_limit_bytes;
    (void)use_file_backed;
    (void)swap_file_path;
    return VERITY_UNKNOWN_BACKEND;
}

int verity_pk_get_memory_stats(uintptr_t *ram_used,
                               uintptr_t *swap_used,
                               uintptr_t *peak_ram) {
    if (!ram_used || !swap_used || !peak_ram) {
        return VERITY_INVALID_INPUT;
    }
    *ram_used = 0;
    *swap_used = 0;
    *peak_ram = 0;
    return VERITY_UNKNOWN_BACKEND;
}
