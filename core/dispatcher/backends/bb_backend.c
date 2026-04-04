/// Barretenberg backend registration — connects bb_* functions to the vtable.

#include "../verity_backend.h"
#include <stddef.h>

typedef struct BBProver BBProver;
typedef struct BBVerifier BBVerifier;
typedef struct { uint8_t *ptr; uintptr_t len; uintptr_t cap; } BBBuf;

extern int  bb_load_prover(const char *path, BBProver **out);
extern int  bb_load_verifier(const char *path, BBVerifier **out);
extern int  bb_load_prover_bytes(const uint8_t *ptr, uintptr_t len, BBProver **out);
extern int  bb_load_verifier_bytes(const uint8_t *ptr, uintptr_t len, BBVerifier **out);
extern int  bb_save_prover(const BBProver *prover, const char *path);
extern int  bb_save_verifier(const BBVerifier *verifier, const char *path);
extern int  bb_serialize_prover(const BBProver *prover, BBBuf *out);
extern int  bb_serialize_verifier(const BBVerifier *verifier, BBBuf *out);
extern int  bb_prove_toml(const BBProver *prover, const char *toml_path, BBBuf *out);
extern int  bb_prove_json(const BBProver *prover, const char *inputs_json, BBBuf *out);
extern int  bb_verify(const BBVerifier *verifier, const uint8_t *proof_ptr, uintptr_t proof_len);
extern int  bb_last_error_message(BBBuf *out);
extern void bb_free_prover(BBProver *prover);
extern void bb_free_verifier(BBVerifier *verifier);
extern void bb_free_buf(BBBuf buf);

_Static_assert(sizeof(BBBuf) == sizeof(RawBuf), "BBBuf and RawBuf size mismatch");
_Static_assert(offsetof(BBBuf, ptr) == offsetof(RawBuf, ptr), "BBBuf.ptr offset mismatch");
_Static_assert(offsetof(BBBuf, len) == offsetof(RawBuf, len), "BBBuf.len offset mismatch");
_Static_assert(offsetof(BBBuf, cap) == offsetof(RawBuf, cap), "BBBuf.cap offset mismatch");
_Static_assert(_Alignof(BBBuf) == _Alignof(RawBuf), "BBBuf/RawBuf alignment mismatch");

static int bb_init_noop(void) { return VERITY_SUCCESS; }

static int w_bb_load_prover(const char *path, void **out) {
    return bb_load_prover(path, (BBProver **)out);
}
static int w_bb_load_verifier(const char *path, void **out) {
    return bb_load_verifier(path, (BBVerifier **)out);
}
static int w_bb_load_prover_bytes(const uint8_t *ptr, uintptr_t len, void **out) {
    return bb_load_prover_bytes(ptr, len, (BBProver **)out);
}
static int w_bb_load_verifier_bytes(const uint8_t *ptr, uintptr_t len, void **out) {
    return bb_load_verifier_bytes(ptr, len, (BBVerifier **)out);
}
static int w_bb_save_prover(const void *p, const char *path) {
    return bb_save_prover((const BBProver *)p, path);
}
static int w_bb_save_verifier(const void *v, const char *path) {
    return bb_save_verifier((const BBVerifier *)v, path);
}
static int w_bb_serialize_prover(const void *p, RawBuf *out) {
    return bb_serialize_prover((const BBProver *)p, (BBBuf *)out);
}
static int w_bb_serialize_verifier(const void *v, RawBuf *out) {
    return bb_serialize_verifier((const BBVerifier *)v, (BBBuf *)out);
}
static int w_bb_prove_toml(const void *p, const char *toml, RawBuf *out) {
    return bb_prove_toml((const BBProver *)p, toml, (BBBuf *)out);
}
static int w_bb_prove_json(const void *p, const char *json, RawBuf *out) {
    return bb_prove_json((const BBProver *)p, json, (BBBuf *)out);
}
static int w_bb_verify(const void *v, const uint8_t *proof, uintptr_t len) {
    return bb_verify((const BBVerifier *)v, proof, len);
}
static int w_bb_last_error_message(RawBuf *out) {
    return bb_last_error_message((BBBuf *)out);
}
static void w_bb_free_prover(void *p) {
    bb_free_prover((BBProver *)p);
}
static void w_bb_free_verifier(void *v) {
    bb_free_verifier((BBVerifier *)v);
}
static void w_bb_free_buf(RawBuf buf) {
    BBBuf b = { .ptr = buf.ptr, .len = buf.len, .cap = buf.cap };
    bb_free_buf(b);
}

static const VerityVtable bb_vtable = {
    .init                = bb_init_noop,
    .load_prover         = w_bb_load_prover,
    .load_verifier       = w_bb_load_verifier,
    .load_prover_bytes   = w_bb_load_prover_bytes,
    .load_verifier_bytes = w_bb_load_verifier_bytes,
    .save_prover         = w_bb_save_prover,
    .save_verifier       = w_bb_save_verifier,
    .serialize_prover    = w_bb_serialize_prover,
    .serialize_verifier  = w_bb_serialize_verifier,
    .prove_toml          = w_bb_prove_toml,
    .prove_json          = w_bb_prove_json,
    .verify              = w_bb_verify,
    .last_error_message  = w_bb_last_error_message,
    .free_prover         = w_bb_free_prover,
    .free_verifier       = w_bb_free_verifier,
    .free_buf            = w_bb_free_buf,
};

__attribute__((constructor))
static void bb_register(void) {
    verity_register_backend(VERITY_BACKEND_BARRETENBERG, &bb_vtable);
}
