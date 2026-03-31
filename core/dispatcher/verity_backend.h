#ifndef VERITY_BACKEND_H
#define VERITY_BACKEND_H

/// Internal header — defines the vtable that each backend must fill in.
/// Community contributors: implement your xx_* functions and provide a vtable.

#include "../include/verity_ffi.h"

/// Raw buffer — matches PKBuf / BBBuf layout exactly (3 fields, no tag).
/// Used internally by vtable functions; converted to VerityBuf by dispatcher.
typedef struct {
    uint8_t  *ptr;
    uintptr_t len;
    uintptr_t cap;
} RawBuf;

/// Function pointer table that each backend implements.
typedef struct {
    int  (*init)(void);
    int  (*prepare)(const char *circuit_path, void **out_prover, void **out_verifier);
    int  (*load_prover)(const char *path, void **out);
    int  (*load_verifier)(const char *path, void **out);
    int  (*load_prover_bytes)(const uint8_t *ptr, uintptr_t len, void **out);
    int  (*load_verifier_bytes)(const uint8_t *ptr, uintptr_t len, void **out);
    int  (*save_prover)(const void *prover, const char *path);
    int  (*save_verifier)(const void *verifier, const char *path);
    int  (*serialize_prover)(const void *prover, RawBuf *out);
    int  (*serialize_verifier)(const void *verifier, RawBuf *out);
    int  (*prove_toml)(const void *prover, const char *toml_path, RawBuf *out);
    int  (*prove_json)(const void *prover, const char *inputs_json, RawBuf *out);
    int  (*verify)(const void *verifier, const uint8_t *proof_ptr, uintptr_t proof_len);
    int  (*last_error_message)(RawBuf *out);
    void (*free_prover)(void *prover);
    void (*free_verifier)(void *verifier);
    void (*free_buf)(RawBuf buf);
} VerityVtable;

/// Register a backend vtable. Called once per backend at library load time.
void verity_register_backend(VerityBackend backend, const VerityVtable *vtable);

/// Maximum number of supported backends.
#define VERITY_MAX_BACKENDS 8

#endif // VERITY_BACKEND_H
