/**
 * N-API bridge between Node.js and Verity FFI.
 *
 * Similar to verity_jni.c but for Node.js. Uses N-API for ABI stability.
 * Build with node-gyp or prebuildify.
 */

#include <node_api.h>
#include "verity_ffi.h"

/* ── Helpers ─────────────────────────────────────────────────────────── */

static napi_value throw_verity_error(napi_env env, int code) {
    const char *msg;
    switch (code) {
        case VERITY_INVALID_INPUT:      msg = "Invalid input"; break;
        case VERITY_SCHEME_READ_ERROR:  msg = "Scheme read error"; break;
        case VERITY_PROOF_ERROR:        msg = "Proof error"; break;
        case VERITY_SERIALIZATION_ERROR: msg = "Serialization error"; break;
        case VERITY_COMPILATION_ERROR:  msg = "Compilation error"; break;
        case VERITY_UNKNOWN_BACKEND:    msg = "Unknown backend"; break;
        default:                        msg = "FFI error"; break;
    }
    napi_throw_error(env, NULL, msg);
    return NULL;
}

/* ── Init ────────────────────────────────────────────────────────────── */

static napi_value napi_verity_init(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value argv[1];
    napi_get_cb_info(env, info, &argc, argv, NULL, NULL);

    int32_t backend;
    napi_get_value_int32(env, argv[0], &backend);

    int code = verity_init((VerityBackend)backend);
    if (code != 0) return throw_verity_error(env, code);

    napi_value result;
    napi_get_undefined(env, &result);
    return result;
}

/* ── Module registration ─────────────────────────────────────────────── */

static napi_value init_module(napi_env env, napi_value exports) {
    napi_property_descriptor props[] = {
        { "init", NULL, napi_verity_init, NULL, NULL, NULL, napi_default, NULL },
        /* TODO: Add prepare, prove, verify, load, save, serialize, free */
    };

    napi_define_properties(env, exports, sizeof(props) / sizeof(props[0]), props);
    return exports;
}

NAPI_MODULE(NODE_GYP_MODULE_NAME, init_module)
