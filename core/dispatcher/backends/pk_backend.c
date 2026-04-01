/// ProveKit backend registration — connects pk_* functions to the vtable.

#include "../verity_backend.h"
#include <stddef.h>

typedef struct PKProver PKProver;
typedef struct PKVerifier PKVerifier;
typedef struct { uint8_t *ptr; uintptr_t len; uintptr_t cap; } PKBuf;

extern int  pk_init(void);
extern int  pk_get_last_error(PKBuf *out) __attribute__((weak_import));
extern int  pk_prepare(const char *circuit_path, PKProver **out_prover, PKVerifier **out_verifier);
extern int  pk_load_prover(const char *path, PKProver **out);
extern int  pk_load_verifier(const char *path, PKVerifier **out);
extern int  pk_load_prover_bytes(const uint8_t *ptr, uintptr_t len, PKProver **out);
extern int  pk_load_verifier_bytes(const uint8_t *ptr, uintptr_t len, PKVerifier **out);
extern int  pk_save_prover(const PKProver *prover, const char *path);
extern int  pk_save_verifier(const PKVerifier *verifier, const char *path);
extern int  pk_serialize_prover(const PKProver *prover, PKBuf *out);
extern int  pk_serialize_verifier(const PKVerifier *verifier, PKBuf *out);
extern int  pk_prove_toml(const PKProver *prover, const char *toml_path, PKBuf *out);
extern int  pk_prove_json(const PKProver *prover, const char *inputs_json, PKBuf *out);
extern int  pk_verify(const PKVerifier *verifier, const uint8_t *proof_ptr, uintptr_t proof_len);
extern void pk_free_prover(PKProver *prover);
extern void pk_free_verifier(PKVerifier *verifier);
extern void pk_free_buf(PKBuf *buf);

_Static_assert(sizeof(PKBuf) == sizeof(RawBuf), "PKBuf and RawBuf size mismatch");
_Static_assert(offsetof(PKBuf, ptr) == offsetof(RawBuf, ptr), "PKBuf.ptr offset mismatch");
_Static_assert(offsetof(PKBuf, len) == offsetof(RawBuf, len), "PKBuf.len offset mismatch");
_Static_assert(offsetof(PKBuf, cap) == offsetof(RawBuf, cap), "PKBuf.cap offset mismatch");
_Static_assert(_Alignof(PKBuf) == _Alignof(RawBuf), "PKBuf/RawBuf alignment mismatch");

static int w_pk_prepare(const char *path, void **p, void **v) {
    return pk_prepare(path, (PKProver **)p, (PKVerifier **)v);
}
static int w_pk_load_prover(const char *path, void **out) {
    return pk_load_prover(path, (PKProver **)out);
}
static int w_pk_load_verifier(const char *path, void **out) {
    return pk_load_verifier(path, (PKVerifier **)out);
}
static int w_pk_load_prover_bytes(const uint8_t *ptr, uintptr_t len, void **out) {
    return pk_load_prover_bytes(ptr, len, (PKProver **)out);
}
static int w_pk_load_verifier_bytes(const uint8_t *ptr, uintptr_t len, void **out) {
    return pk_load_verifier_bytes(ptr, len, (PKVerifier **)out);
}
static int w_pk_save_prover(const void *p, const char *path) {
    return pk_save_prover((const PKProver *)p, path);
}
static int w_pk_save_verifier(const void *v, const char *path) {
    return pk_save_verifier((const PKVerifier *)v, path);
}
static int w_pk_serialize_prover(const void *p, RawBuf *out) {
    return pk_serialize_prover((const PKProver *)p, (PKBuf *)out);
}
static int w_pk_serialize_verifier(const void *v, RawBuf *out) {
    return pk_serialize_verifier((const PKVerifier *)v, (PKBuf *)out);
}
static int w_pk_prove_toml(const void *p, const char *toml, RawBuf *out) {
    return pk_prove_toml((const PKProver *)p, toml, (PKBuf *)out);
}
static int w_pk_prove_json(const void *p, const char *json, RawBuf *out) {
    return pk_prove_json((const PKProver *)p, json, (PKBuf *)out);
}
static int w_pk_verify(const void *v, const uint8_t *proof, uintptr_t len) {
    return pk_verify((const PKVerifier *)v, proof, len);
}
static int w_pk_last_error_message(RawBuf *out) {
    if (!out) return VERITY_INVALID_INPUT;
    out->ptr = NULL;
    out->len = 0;
    out->cap = 0;
    // Weak import: if the ProveKit build does not expose pk_get_last_error,
    // return success with an empty buffer (no error message available).
    if (!pk_get_last_error) return VERITY_SUCCESS;
    return pk_get_last_error((PKBuf *)out);
}
static void w_pk_free_prover(void *p) {
    pk_free_prover((PKProver *)p);
}
static void w_pk_free_verifier(void *v) {
    pk_free_verifier((PKVerifier *)v);
}
static void w_pk_free_buf(RawBuf buf) {
    PKBuf b = { .ptr = buf.ptr, .len = buf.len, .cap = buf.cap };
    pk_free_buf(&b);
}

static const VerityVtable pk_vtable = {
    .init                = pk_init,
    .prepare             = w_pk_prepare,
    .load_prover         = w_pk_load_prover,
    .load_verifier       = w_pk_load_verifier,
    .load_prover_bytes   = w_pk_load_prover_bytes,
    .load_verifier_bytes = w_pk_load_verifier_bytes,
    .save_prover         = w_pk_save_prover,
    .save_verifier       = w_pk_save_verifier,
    .serialize_prover    = w_pk_serialize_prover,
    .serialize_verifier  = w_pk_serialize_verifier,
    .prove_toml          = w_pk_prove_toml,
    .prove_json          = w_pk_prove_json,
    .verify              = w_pk_verify,
    .last_error_message  = w_pk_last_error_message,
    .free_prover         = w_pk_free_prover,
    .free_verifier       = w_pk_free_verifier,
    .free_buf            = w_pk_free_buf,
};

__attribute__((constructor))
static void pk_register(void) {
    verity_register_backend(VERITY_BACKEND_PROVEKIT, &pk_vtable);
}
