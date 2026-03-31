/// Core dispatcher — routes verity_* calls to the correct backend via vtable.

#include "verity_backend.h"
#include <stdlib.h>
#include <string.h>
#include <stddef.h>

// ── Handle types ───────────────────────────────────────────────────────────

struct VerityProver {
    int   backend;
    void *handle;
};

struct VerityVerifier {
    int   backend;
    void *handle;
};

// ── Backend registry ───────────────────────────────────────────────────────

static const VerityVtable *g_backends[VERITY_MAX_BACKENDS] = {0};

void verity_register_backend(VerityBackend backend, const VerityVtable *vtable) {
    if (backend < 0 || backend >= VERITY_MAX_BACKENDS) return;
    if (!vtable) return;

    // Validate that all required function pointers are non-NULL.
    if (!vtable->init || !vtable->prepare ||
        !vtable->load_prover || !vtable->load_verifier ||
        !vtable->load_prover_bytes || !vtable->load_verifier_bytes ||
        !vtable->save_prover || !vtable->save_verifier ||
        !vtable->serialize_prover || !vtable->serialize_verifier ||
        !vtable->prove_toml || !vtable->prove_json ||
        !vtable->verify || !vtable->last_error_message ||
        !vtable->free_prover || !vtable->free_verifier ||
        !vtable->free_buf) return;

    g_backends[backend] = vtable;
}

static const VerityVtable *get_vt(int backend) {
    if (backend < 0 || backend >= VERITY_MAX_BACKENDS) return NULL;
    return g_backends[backend];
}

// ── Handle helpers ─────────────────────────────────────────────────────────

static VerityProver *wrap_prover(int backend, void *handle) {
    VerityProver *p = (VerityProver *)malloc(sizeof(VerityProver));
    if (p) { p->backend = backend; p->handle = handle; }
    return p;
}

static VerityVerifier *wrap_verifier(int backend, void *handle) {
    VerityVerifier *v = (VerityVerifier *)malloc(sizeof(VerityVerifier));
    if (v) { v->backend = backend; v->handle = handle; }
    return v;
}

// ── Lifecycle ──────────────────────────────────────────────────────────────

int verity_init(VerityBackend backend) {
    const VerityVtable *vt = get_vt(backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;
    return vt->init();
}

// ── Prepare ────────────────────────────────────────────────────────────────

int verity_prepare(VerityBackend backend,
                   const char *circuit_path,
                   VerityProver **out_prover,
                   VerityVerifier **out_verifier) {
    if (!out_prover || !out_verifier) return VERITY_INVALID_INPUT;
    if (!circuit_path) return VERITY_INVALID_INPUT;
    *out_prover = NULL;
    *out_verifier = NULL;

    const VerityVtable *vt = get_vt(backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;

    void *raw_prover = NULL;
    void *raw_verifier = NULL;
    int code = vt->prepare(circuit_path, &raw_prover, &raw_verifier);
    if (code != VERITY_SUCCESS) return code;

    *out_prover = wrap_prover(backend, raw_prover);
    *out_verifier = wrap_verifier(backend, raw_verifier);

    if (!*out_prover || !*out_verifier) {
        if (*out_prover)  { free(*out_prover);  *out_prover = NULL; }
        if (*out_verifier) { free(*out_verifier); *out_verifier = NULL; }
        vt->free_prover(raw_prover);
        vt->free_verifier(raw_verifier);
        return VERITY_OUT_OF_MEMORY;
    }

    return VERITY_SUCCESS;
}

// ── Load ───────────────────────────────────────────────────────────────────

int verity_load_prover(VerityBackend backend, const char *path,
                       VerityProver **out) {
    if (!out || !path) return VERITY_INVALID_INPUT;
    *out = NULL;

    const VerityVtable *vt = get_vt(backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;

    void *raw = NULL;
    int code = vt->load_prover(path, &raw);
    if (code != VERITY_SUCCESS) return code;

    *out = wrap_prover(backend, raw);
    if (!*out) { vt->free_prover(raw); return VERITY_OUT_OF_MEMORY; }
    return VERITY_SUCCESS;
}

int verity_load_verifier(VerityBackend backend, const char *path,
                         VerityVerifier **out) {
    if (!out || !path) return VERITY_INVALID_INPUT;
    *out = NULL;

    const VerityVtable *vt = get_vt(backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;

    void *raw = NULL;
    int code = vt->load_verifier(path, &raw);
    if (code != VERITY_SUCCESS) return code;

    *out = wrap_verifier(backend, raw);
    if (!*out) { vt->free_verifier(raw); return VERITY_OUT_OF_MEMORY; }
    return VERITY_SUCCESS;
}

int verity_load_prover_bytes(VerityBackend backend,
                             const uint8_t *ptr, uintptr_t len,
                             VerityProver **out) {
    if (!out || !ptr || len == 0) return VERITY_INVALID_INPUT;
    *out = NULL;

    const VerityVtable *vt = get_vt(backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;

    void *raw = NULL;
    int code = vt->load_prover_bytes(ptr, len, &raw);
    if (code != VERITY_SUCCESS) return code;

    *out = wrap_prover(backend, raw);
    if (!*out) { vt->free_prover(raw); return VERITY_OUT_OF_MEMORY; }
    return VERITY_SUCCESS;
}

int verity_load_verifier_bytes(VerityBackend backend,
                               const uint8_t *ptr, uintptr_t len,
                               VerityVerifier **out) {
    if (!out || !ptr || len == 0) return VERITY_INVALID_INPUT;
    *out = NULL;

    const VerityVtable *vt = get_vt(backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;

    void *raw = NULL;
    int code = vt->load_verifier_bytes(ptr, len, &raw);
    if (code != VERITY_SUCCESS) return code;

    *out = wrap_verifier(backend, raw);
    if (!*out) { vt->free_verifier(raw); return VERITY_OUT_OF_MEMORY; }
    return VERITY_SUCCESS;
}

// ── Save ───────────────────────────────────────────────────────────────────

int verity_save_prover(const VerityProver *prover, const char *path) {
    if (!prover || !path) return VERITY_INVALID_INPUT;
    const VerityVtable *vt = get_vt(prover->backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;
    return vt->save_prover(prover->handle, path);
}

int verity_save_verifier(const VerityVerifier *verifier, const char *path) {
    if (!verifier || !path) return VERITY_INVALID_INPUT;
    const VerityVtable *vt = get_vt(verifier->backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;
    return vt->save_verifier(verifier->handle, path);
}

// ── Serialize ──────────────────────────────────────────────────────────────

int verity_serialize_prover(const VerityProver *prover, VerityBuf *out) {
    if (!prover || !out) return VERITY_INVALID_INPUT;
    out->ptr = NULL; out->len = 0; out->cap = 0;
    out->backend = prover->backend;

    const VerityVtable *vt = get_vt(prover->backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;

    RawBuf raw = {0};
    int code = vt->serialize_prover(prover->handle, &raw);
    if (code == VERITY_SUCCESS) {
        out->ptr = raw.ptr;
        out->len = raw.len;
        out->cap = raw.cap;
    }
    return code;
}

int verity_serialize_verifier(const VerityVerifier *verifier, VerityBuf *out) {
    if (!verifier || !out) return VERITY_INVALID_INPUT;
    out->ptr = NULL; out->len = 0; out->cap = 0;
    out->backend = verifier->backend;

    const VerityVtable *vt = get_vt(verifier->backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;

    RawBuf raw = {0};
    int code = vt->serialize_verifier(verifier->handle, &raw);
    if (code == VERITY_SUCCESS) {
        out->ptr = raw.ptr;
        out->len = raw.len;
        out->cap = raw.cap;
    }
    return code;
}

// ── Prove ──────────────────────────────────────────────────────────────────

int verity_prove_toml(const VerityProver *prover,
                      const char *toml_path,
                      VerityBuf *out_proof) {
    if (!prover || !out_proof || !toml_path) return VERITY_INVALID_INPUT;
    out_proof->ptr = NULL; out_proof->len = 0; out_proof->cap = 0;
    out_proof->backend = prover->backend;

    const VerityVtable *vt = get_vt(prover->backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;

    RawBuf raw = {0};
    int code = vt->prove_toml(prover->handle, toml_path, &raw);
    if (code == VERITY_SUCCESS) {
        out_proof->ptr = raw.ptr;
        out_proof->len = raw.len;
        out_proof->cap = raw.cap;
    }
    return code;
}

int verity_prove_json(const VerityProver *prover,
                      const char *inputs_json,
                      VerityBuf *out_proof) {
    if (!prover || !out_proof || !inputs_json) return VERITY_INVALID_INPUT;
    out_proof->ptr = NULL; out_proof->len = 0; out_proof->cap = 0;
    out_proof->backend = prover->backend;

    const VerityVtable *vt = get_vt(prover->backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;

    RawBuf raw = {0};
    int code = vt->prove_json(prover->handle, inputs_json, &raw);
    if (code == VERITY_SUCCESS) {
        out_proof->ptr = raw.ptr;
        out_proof->len = raw.len;
        out_proof->cap = raw.cap;
    }
    return code;
}

// ── Verify ─────────────────────────────────────────────────────────────────

int verity_verify(const VerityVerifier *verifier,
                  const uint8_t *proof_ptr,
                  uintptr_t proof_len) {
    if (!verifier || !proof_ptr || proof_len == 0) return VERITY_INVALID_INPUT;
    const VerityVtable *vt = get_vt(verifier->backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;
    return vt->verify(verifier->handle, proof_ptr, proof_len);
}

int verity_last_error_message(VerityBackend backend, VerityBuf *out_message) {
    if (!out_message) return VERITY_INVALID_INPUT;
    out_message->ptr = NULL;
    out_message->len = 0;
    out_message->cap = 0;
    out_message->backend = backend;

    const VerityVtable *vt = get_vt(backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;

    RawBuf raw = {0};
    int code = vt->last_error_message(&raw);
    if (code == VERITY_SUCCESS) {
        out_message->ptr = raw.ptr;
        out_message->len = raw.len;
        out_message->cap = raw.cap;
    }
    return code;
}

// ── Cleanup ────────────────────────────────────────────────────────────────

void verity_free_prover(VerityProver *prover) {
    if (!prover) return;
    const VerityVtable *vt = get_vt(prover->backend);
    if (vt) vt->free_prover(prover->handle);
    free(prover);
}

void verity_free_verifier(VerityVerifier *verifier) {
    if (!verifier) return;
    const VerityVtable *vt = get_vt(verifier->backend);
    if (vt) vt->free_verifier(verifier->handle);
    free(verifier);
}

void verity_free_buf(VerityBuf buf) {
    if (buf.ptr == NULL || buf.cap == 0) return;

    RawBuf raw = { .ptr = buf.ptr, .len = buf.len, .cap = buf.cap };
    const VerityVtable *vt = get_vt(buf.backend);
    if (vt) {
        vt->free_buf(raw);
        return;
    }
    // No fallback: if the backend tag is invalid, leak rather than risk
    // heap corruption from using the wrong deallocator.
}

// ── Memory (ProveKit-specific) ─────────────────────────────────────────────

extern int pk_configure_memory(uintptr_t, bool, const char *);
extern int pk_get_memory_stats(uintptr_t *, uintptr_t *, uintptr_t *);

int verity_pk_configure_memory(uintptr_t ram_limit_bytes,
                            bool use_file_backed,
                            const char *swap_file_path) {
    if (use_file_backed && !swap_file_path) return VERITY_INVALID_INPUT;
    if (use_file_backed && swap_file_path[0] == '\0') return VERITY_INVALID_INPUT;
    if (!get_vt(VERITY_BACKEND_PROVEKIT)) return VERITY_UNKNOWN_BACKEND;
    return pk_configure_memory(ram_limit_bytes, use_file_backed,
                               swap_file_path ? swap_file_path : "");
}

int verity_pk_get_memory_stats(uintptr_t *ram_used,
                            uintptr_t *swap_used,
                            uintptr_t *peak_ram) {
    if (!ram_used || !swap_used || !peak_ram) return VERITY_INVALID_INPUT;
    if (!get_vt(VERITY_BACKEND_PROVEKIT)) return VERITY_UNKNOWN_BACKEND;
    return pk_get_memory_stats(ram_used, swap_used, peak_ram);
}
