/// Core dispatcher — routes verity_* calls to the correct backend via vtable.

#include "verity_backend.h"
#include <stdlib.h>
#include <string.h>

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
    if (backend >= 0 && backend < VERITY_MAX_BACKENDS) {
        g_backends[backend] = vtable;
    }
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
        return VERITY_INVALID_INPUT;
    }

    return VERITY_SUCCESS;
}

// ── Load ───────────────────────────────────────────────────────────────────

int verity_load_prover(VerityBackend backend, const char *path,
                       VerityProver **out) {
    if (!out) return VERITY_INVALID_INPUT;
    *out = NULL;

    const VerityVtable *vt = get_vt(backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;

    void *raw = NULL;
    int code = vt->load_prover(path, &raw);
    if (code != VERITY_SUCCESS) return code;

    *out = wrap_prover(backend, raw);
    return *out ? VERITY_SUCCESS : VERITY_INVALID_INPUT;
}

int verity_load_verifier(VerityBackend backend, const char *path,
                         VerityVerifier **out) {
    if (!out) return VERITY_INVALID_INPUT;
    *out = NULL;

    const VerityVtable *vt = get_vt(backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;

    void *raw = NULL;
    int code = vt->load_verifier(path, &raw);
    if (code != VERITY_SUCCESS) return code;

    *out = wrap_verifier(backend, raw);
    return *out ? VERITY_SUCCESS : VERITY_INVALID_INPUT;
}

int verity_load_prover_bytes(VerityBackend backend,
                             const uint8_t *ptr, uintptr_t len,
                             VerityProver **out) {
    if (!out) return VERITY_INVALID_INPUT;
    *out = NULL;

    const VerityVtable *vt = get_vt(backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;

    void *raw = NULL;
    int code = vt->load_prover_bytes(ptr, len, &raw);
    if (code != VERITY_SUCCESS) return code;

    *out = wrap_prover(backend, raw);
    return *out ? VERITY_SUCCESS : VERITY_INVALID_INPUT;
}

int verity_load_verifier_bytes(VerityBackend backend,
                               const uint8_t *ptr, uintptr_t len,
                               VerityVerifier **out) {
    if (!out) return VERITY_INVALID_INPUT;
    *out = NULL;

    const VerityVtable *vt = get_vt(backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;

    void *raw = NULL;
    int code = vt->load_verifier_bytes(ptr, len, &raw);
    if (code != VERITY_SUCCESS) return code;

    *out = wrap_verifier(backend, raw);
    return *out ? VERITY_SUCCESS : VERITY_INVALID_INPUT;
}

// ── Save ───────────────────────────────────────────────────────────────────

int verity_save_prover(const VerityProver *prover, const char *path) {
    if (!prover) return VERITY_INVALID_INPUT;
    const VerityVtable *vt = get_vt(prover->backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;
    return vt->save_prover(prover->handle, path);
}

int verity_save_verifier(const VerityVerifier *verifier, const char *path) {
    if (!verifier) return VERITY_INVALID_INPUT;
    const VerityVtable *vt = get_vt(verifier->backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;
    return vt->save_verifier(verifier->handle, path);
}

// ── Serialize ──────────────────────────────────────────────────────────────

int verity_serialize_prover(const VerityProver *prover, VerityBuf *out) {
    if (!prover || !out) return VERITY_INVALID_INPUT;
    out->ptr = NULL; out->len = 0; out->cap = 0;

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
    if (!prover || !out_proof) return VERITY_INVALID_INPUT;
    out_proof->ptr = NULL; out_proof->len = 0; out_proof->cap = 0;

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
    if (!prover || !out_proof) return VERITY_INVALID_INPUT;
    out_proof->ptr = NULL; out_proof->len = 0; out_proof->cap = 0;

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
    if (!verifier) return VERITY_INVALID_INPUT;
    const VerityVtable *vt = get_vt(verifier->backend);
    if (!vt) return VERITY_UNKNOWN_BACKEND;
    return vt->verify(verifier->handle, proof_ptr, proof_len);
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
    // VerityBuf has the same ptr/len/cap layout produced by the backend's
    // allocator. We need to call the right backend's free_buf. Since we don't
    // track which backend allocated the buf, we use a universal approach:
    // both backends use Rust's Vec which uses the process-global allocator.
    // Reconstructing and dropping via any backend's free_buf is equivalent.
    // We prefer pk_free_buf since ProveKit is always linked.
    if (buf.ptr != NULL && buf.cap > 0) {
        // All backends produce buffers via Rust Vec::from_raw_parts.
        // The global Rust allocator handles deallocation regardless of which
        // backend allocated it, since they share the same process allocator.
        extern void pk_free_buf(RawBuf raw);
        RawBuf raw = { .ptr = buf.ptr, .len = buf.len, .cap = buf.cap };
        pk_free_buf(raw);
    }
}

// ── Memory (delegates to ProveKit) ─────────────────────────────────────────

int verity_configure_memory(uintptr_t ram_limit_bytes,
                            bool use_file_backed,
                            const char *swap_file_path) {
    extern int pk_configure_memory(uintptr_t, bool, const char *);
    return pk_configure_memory(ram_limit_bytes, use_file_backed, swap_file_path);
}

int verity_get_memory_stats(uintptr_t *ram_used,
                            uintptr_t *swap_used,
                            uintptr_t *peak_ram) {
    extern int pk_get_memory_stats(uintptr_t *, uintptr_t *, uintptr_t *);
    return pk_get_memory_stats(ram_used, swap_used, peak_ram);
}
