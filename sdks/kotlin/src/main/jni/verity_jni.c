/**
 * JNI bridge between Kotlin (Android) and Verity FFI (Rust).
 *
 * Uses the handle-based verity_* dispatch API. Opaque VerityProver
 * and VerityVerifier pointers are passed to Kotlin as jlong values.
 */

#include <jni.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "verity_ffi.h"

/* ------------------------------------------------------------------ */
/*  Helpers                                                           */
/* ------------------------------------------------------------------ */

/** Convert a Java string to a C string. Returns NULL if str is NULL or OOM. */
static const char *jstring_to_cstr(JNIEnv *env, jstring str) {
    if (str == NULL) return NULL;
    return (*env)->GetStringUTFChars(env, str, NULL);
}

/** Release a C string obtained from jstring_to_cstr. Safe to call with NULLs. */
static void release_cstr(JNIEnv *env, jstring jstr, const char *cstr) {
    if (jstr != NULL && cstr != NULL) {
        (*env)->ReleaseStringUTFChars(env, jstr, cstr);
    }
}

/** Throw a typed VerityException from an FFI error code via fromCode(). */
static void throw_verity_error(JNIEnv *env, int code) {
    jclass cls = (*env)->FindClass(env, "xyz/atheon/verity/VerityException");
    if (cls == NULL) {
        (*env)->ExceptionClear(env);
        /* Fall back to RuntimeException if VerityException class not found */
        jclass rte = (*env)->FindClass(env, "java/lang/RuntimeException");
        if (rte != NULL) {
            char msg[64];
            snprintf(msg, sizeof(msg), "Verity FFI error (code %d)", code);
            (*env)->ThrowNew(env, rte, msg);
            (*env)->DeleteLocalRef(env, rte);
        }
        return;
    }
    jmethodID fromCode = (*env)->GetStaticMethodID(env, cls, "fromCode",
        "(I)Lxyz/atheon/verity/VerityException;");
    if (fromCode == NULL) {
        (*env)->DeleteLocalRef(env, cls);
        (*env)->ExceptionClear(env);
        jclass rte = (*env)->FindClass(env, "java/lang/RuntimeException");
        if (rte != NULL) {
            char msg[64];
            snprintf(msg, sizeof(msg), "Verity FFI error (code %d)", code);
            (*env)->ThrowNew(env, rte, msg);
            (*env)->DeleteLocalRef(env, rte);
        }
        return;
    }
    jthrowable exc = (jthrowable)(*env)->CallStaticObjectMethod(env, cls, fromCode, (jint)code);
    (*env)->DeleteLocalRef(env, cls);
    if ((*env)->ExceptionCheck(env)) {
        return; /* fromCode() itself threw; let that propagate */
    }
    if (exc != NULL) {
        (*env)->Throw(env, exc);
        // exc local ref cleaned up automatically on native method return
    }
}

/* ------------------------------------------------------------------ */
/*  Lifecycle                                                         */
/* ------------------------------------------------------------------ */

/*
 * Thread-safety note: setenv() is not thread-safe on Android (bionic libc).
 * This is only called from Kotlin's loadLibrary() which is protected by
 * synchronized(Companion), ensuring single-threaded access. Do not call
 * this function outside that synchronized context.
 */
JNIEXPORT void JNICALL
Java_xyz_atheon_verity_Verity_nativeConfigureHome(
    JNIEnv *env, jclass clazz, jstring homeDir)
{
    const char *home = jstring_to_cstr(env, homeDir);
    if (home != NULL) {
        setenv("HOME", home, 1);
        release_cstr(env, homeDir, home);
    }
}

JNIEXPORT jint JNICALL
Java_xyz_atheon_verity_Verity_nativeInit(
    JNIEnv *env, jclass clazz, jint backend)
{
    return (jint)verity_init((VerityBackend)backend);
}

/* ------------------------------------------------------------------ */
/*  Prove (TOML file) — takes prover handle, returns proof bytes      */
/* ------------------------------------------------------------------ */

JNIEXPORT jbyteArray JNICALL
Java_xyz_atheon_verity_Verity_nativeProveToml(
    JNIEnv *env, jclass clazz, jlong proverHandle, jstring inputPath)
{
    if (proverHandle == 0) {
        throw_verity_error(env, VERITY_INVALID_INPUT);
        return NULL;
    }

    const char *input = jstring_to_cstr(env, inputPath);
    if (input == NULL) {
        throw_verity_error(env, VERITY_INVALID_INPUT);
        return NULL;
    }

    VerityProver *prover = (VerityProver *)(uintptr_t)proverHandle;
    VerityBuf buf = { .ptr = NULL, .len = 0, .cap = 0, .backend = 0 };
    int code = verity_prove_toml(prover, input, &buf);

    release_cstr(env, inputPath, input);

    if (code != 0) {
        throw_verity_error(env, code);
        return NULL;
    }

    if (buf.ptr == NULL || buf.len == 0) {
        throw_verity_error(env, VERITY_PROOF_ERROR);
        return NULL;
    }

    jbyteArray result = (*env)->NewByteArray(env, (jsize)buf.len);
    if (result == NULL) {
        verity_free_buf(buf);
        return NULL; /* OOM */
    }

    (*env)->SetByteArrayRegion(env, result, 0, (jsize)buf.len, (const jbyte *)buf.ptr);
    verity_free_buf(buf);

    if ((*env)->ExceptionCheck(env)) {
        return NULL;
    }

    return result;
}

/* ------------------------------------------------------------------ */
/*  Prove (JSON string) — takes prover handle, returns proof bytes    */
/* ------------------------------------------------------------------ */

JNIEXPORT jbyteArray JNICALL
Java_xyz_atheon_verity_Verity_nativeProveJson(
    JNIEnv *env, jclass clazz, jlong proverHandle, jstring inputsJson)
{
    if (proverHandle == 0) {
        throw_verity_error(env, VERITY_INVALID_INPUT);
        return NULL;
    }

    const char *json = jstring_to_cstr(env, inputsJson);
    if (json == NULL) {
        throw_verity_error(env, VERITY_INVALID_INPUT);
        return NULL;
    }

    VerityProver *prover = (VerityProver *)(uintptr_t)proverHandle;
    VerityBuf buf = { .ptr = NULL, .len = 0, .cap = 0, .backend = 0 };
    int code = verity_prove_json(prover, json, &buf);

    release_cstr(env, inputsJson, json);

    if (code != 0) {
        throw_verity_error(env, code);
        return NULL;
    }

    if (buf.ptr == NULL || buf.len == 0) {
        throw_verity_error(env, VERITY_PROOF_ERROR);
        return NULL;
    }

    jbyteArray result = (*env)->NewByteArray(env, (jsize)buf.len);
    if (result == NULL) {
        verity_free_buf(buf);
        return NULL;
    }

    (*env)->SetByteArrayRegion(env, result, 0, (jsize)buf.len, (const jbyte *)buf.ptr);
    verity_free_buf(buf);

    if ((*env)->ExceptionCheck(env)) {
        return NULL;
    }

    return result;
}

/* ------------------------------------------------------------------ */
/*  Verify — takes verifier handle + proof bytes                      */
/* ------------------------------------------------------------------ */

JNIEXPORT jint JNICALL
Java_xyz_atheon_verity_Verity_nativeVerify(
    JNIEnv *env, jclass clazz, jlong verifierHandle, jbyteArray proof)
{
    if (verifierHandle == 0 || proof == NULL) {
        return (jint)VERITY_INVALID_INPUT;
    }

    VerityVerifier *verifier = (VerityVerifier *)(uintptr_t)verifierHandle;
    jsize len = (*env)->GetArrayLength(env, proof);
    jbyte *bytes = (*env)->GetByteArrayElements(env, proof, NULL);
    if (bytes == NULL) {
        return (jint)VERITY_INVALID_INPUT;
    }

    int code = verity_verify(verifier, (const uint8_t *)bytes, (uintptr_t)len);

    (*env)->ReleaseByteArrayElements(env, proof, bytes, JNI_ABORT);
    return (jint)code;
}

/* ------------------------------------------------------------------ */
/*  Load prover/verifier from file                                    */
/* ------------------------------------------------------------------ */

JNIEXPORT jlong JNICALL
Java_xyz_atheon_verity_Verity_nativeLoadProver(
    JNIEnv *env, jclass clazz, jint backend, jstring path)
{
    const char *cpath = jstring_to_cstr(env, path);
    if (cpath == NULL) {
        throw_verity_error(env, VERITY_INVALID_INPUT);
        return 0;
    }

    VerityProver *prover = NULL;
    int code = verity_load_prover((VerityBackend)backend, cpath, &prover);

    release_cstr(env, path, cpath);

    if (code != 0) {
        throw_verity_error(env, code);
        return 0;
    }

    return (jlong)(uintptr_t)prover;
}

JNIEXPORT jlong JNICALL
Java_xyz_atheon_verity_Verity_nativeLoadVerifier(
    JNIEnv *env, jclass clazz, jint backend, jstring path)
{
    const char *cpath = jstring_to_cstr(env, path);
    if (cpath == NULL) {
        throw_verity_error(env, VERITY_INVALID_INPUT);
        return 0;
    }

    VerityVerifier *verifier = NULL;
    int code = verity_load_verifier((VerityBackend)backend, cpath, &verifier);

    release_cstr(env, path, cpath);

    if (code != 0) {
        throw_verity_error(env, code);
        return 0;
    }

    return (jlong)(uintptr_t)verifier;
}

/* ------------------------------------------------------------------ */
/*  Load prover/verifier from bytes                                   */
/* ------------------------------------------------------------------ */

JNIEXPORT jlong JNICALL
Java_xyz_atheon_verity_Verity_nativeLoadProverBytes(
    JNIEnv *env, jclass clazz, jint backend, jbyteArray data)
{
    if (data == NULL) {
        throw_verity_error(env, VERITY_INVALID_INPUT);
        return 0;
    }

    jsize len = (*env)->GetArrayLength(env, data);
    jbyte *bytes = (*env)->GetByteArrayElements(env, data, NULL);
    if (bytes == NULL) {
        throw_verity_error(env, VERITY_INVALID_INPUT);
        return 0;
    }

    VerityProver *prover = NULL;
    int code = verity_load_prover_bytes(
        (VerityBackend)backend, (const uint8_t *)bytes, (uintptr_t)len, &prover);

    (*env)->ReleaseByteArrayElements(env, data, bytes, JNI_ABORT);

    if (code != 0) {
        throw_verity_error(env, code);
        return 0;
    }

    return (jlong)(uintptr_t)prover;
}

JNIEXPORT jlong JNICALL
Java_xyz_atheon_verity_Verity_nativeLoadVerifierBytes(
    JNIEnv *env, jclass clazz, jint backend, jbyteArray data)
{
    if (data == NULL) {
        throw_verity_error(env, VERITY_INVALID_INPUT);
        return 0;
    }

    jsize len = (*env)->GetArrayLength(env, data);
    jbyte *bytes = (*env)->GetByteArrayElements(env, data, NULL);
    if (bytes == NULL) {
        throw_verity_error(env, VERITY_INVALID_INPUT);
        return 0;
    }

    VerityVerifier *verifier = NULL;
    int code = verity_load_verifier_bytes(
        (VerityBackend)backend, (const uint8_t *)bytes, (uintptr_t)len, &verifier);

    (*env)->ReleaseByteArrayElements(env, data, bytes, JNI_ABORT);

    if (code != 0) {
        throw_verity_error(env, code);
        return 0;
    }

    return (jlong)(uintptr_t)verifier;
}

/* ------------------------------------------------------------------ */
/*  Save prover/verifier to file                                      */
/* ------------------------------------------------------------------ */

JNIEXPORT jint JNICALL
Java_xyz_atheon_verity_Verity_nativeSaveProver(
    JNIEnv *env, jclass clazz, jlong proverHandle, jstring path)
{
    if (proverHandle == 0) return (jint)VERITY_INVALID_INPUT;

    const char *cpath = jstring_to_cstr(env, path);
    if (cpath == NULL) return (jint)VERITY_INVALID_INPUT;

    int code = verity_save_prover(
        (const VerityProver *)(uintptr_t)proverHandle, cpath);

    release_cstr(env, path, cpath);
    return (jint)code;
}

JNIEXPORT jint JNICALL
Java_xyz_atheon_verity_Verity_nativeSaveVerifier(
    JNIEnv *env, jclass clazz, jlong verifierHandle, jstring path)
{
    if (verifierHandle == 0) return (jint)VERITY_INVALID_INPUT;

    const char *cpath = jstring_to_cstr(env, path);
    if (cpath == NULL) return (jint)VERITY_INVALID_INPUT;

    int code = verity_save_verifier(
        (const VerityVerifier *)(uintptr_t)verifierHandle, cpath);

    release_cstr(env, path, cpath);
    return (jint)code;
}

/* ------------------------------------------------------------------ */
/*  Serialize prover/verifier to bytes                                */
/* ------------------------------------------------------------------ */

JNIEXPORT jbyteArray JNICALL
Java_xyz_atheon_verity_Verity_nativeSerializeProver(
    JNIEnv *env, jclass clazz, jlong proverHandle)
{
    if (proverHandle == 0) {
        throw_verity_error(env, VERITY_INVALID_INPUT);
        return NULL;
    }

    VerityBuf buf = { .ptr = NULL, .len = 0, .cap = 0, .backend = 0 };
    int code = verity_serialize_prover(
        (const VerityProver *)(uintptr_t)proverHandle, &buf);

    if (code != 0) {
        throw_verity_error(env, code);
        return NULL;
    }

    if (buf.ptr == NULL || buf.len == 0) {
        throw_verity_error(env, VERITY_SERIALIZATION_ERROR);
        return NULL;
    }

    jbyteArray result = (*env)->NewByteArray(env, (jsize)buf.len);
    if (result == NULL) {
        verity_free_buf(buf);
        return NULL;
    }

    (*env)->SetByteArrayRegion(env, result, 0, (jsize)buf.len, (const jbyte *)buf.ptr);
    verity_free_buf(buf);

    if ((*env)->ExceptionCheck(env)) {
        return NULL;
    }

    return result;
}

JNIEXPORT jbyteArray JNICALL
Java_xyz_atheon_verity_Verity_nativeSerializeVerifier(
    JNIEnv *env, jclass clazz, jlong verifierHandle)
{
    if (verifierHandle == 0) {
        throw_verity_error(env, VERITY_INVALID_INPUT);
        return NULL;
    }

    VerityBuf buf = { .ptr = NULL, .len = 0, .cap = 0, .backend = 0 };
    int code = verity_serialize_verifier(
        (const VerityVerifier *)(uintptr_t)verifierHandle, &buf);

    if (code != 0) {
        throw_verity_error(env, code);
        return NULL;
    }

    if (buf.ptr == NULL || buf.len == 0) {
        throw_verity_error(env, VERITY_SERIALIZATION_ERROR);
        return NULL;
    }

    jbyteArray result = (*env)->NewByteArray(env, (jsize)buf.len);
    if (result == NULL) {
        verity_free_buf(buf);
        return NULL;
    }

    (*env)->SetByteArrayRegion(env, result, 0, (jsize)buf.len, (const jbyte *)buf.ptr);
    verity_free_buf(buf);

    if ((*env)->ExceptionCheck(env)) {
        return NULL;
    }

    return result;
}

/* ------------------------------------------------------------------ */
/*  Free handles                                                      */
/* ------------------------------------------------------------------ */

JNIEXPORT void JNICALL
Java_xyz_atheon_verity_Verity_nativeFreeProver(
    JNIEnv *env, jclass clazz, jlong proverHandle)
{
    if (proverHandle != 0) {
        verity_free_prover((VerityProver *)(uintptr_t)proverHandle);
    }
}

JNIEXPORT void JNICALL
Java_xyz_atheon_verity_Verity_nativeFreeVerifier(
    JNIEnv *env, jclass clazz, jlong verifierHandle)
{
    if (verifierHandle != 0) {
        verity_free_verifier((VerityVerifier *)(uintptr_t)verifierHandle);
    }
}

/* ------------------------------------------------------------------ */
/*  Memory configuration (ProveKit-specific)                          */
/* ------------------------------------------------------------------ */

JNIEXPORT jint JNICALL
Java_xyz_atheon_verity_Verity_nativeConfigureMemory(
    JNIEnv *env, jclass clazz, jlong ramLimitBytes,
    jboolean useFileBacked, jstring swapFilePath)
{
    const char *swap = jstring_to_cstr(env, swapFilePath);
    int code = verity_pk_configure_memory(
        (uintptr_t)ramLimitBytes, (bool)useFileBacked, swap);
    release_cstr(env, swapFilePath, swap);
    return (jint)code;
}

JNIEXPORT jobject JNICALL
Java_xyz_atheon_verity_Verity_nativeGetMemoryStats(
    JNIEnv *env, jclass clazz)
{
    uintptr_t ram_used = 0, swap_used = 0, peak_ram = 0;
    int code = verity_pk_get_memory_stats(&ram_used, &swap_used, &peak_ram);
    if (code != 0) {
        throw_verity_error(env, code);
        return NULL;
    }

    jclass cls = (*env)->FindClass(env, "xyz/atheon/verity/MemoryStats");
    if (cls == NULL) return NULL;
    jmethodID ctor = (*env)->GetMethodID(env, cls, "<init>", "(JJJ)V");
    if (ctor == NULL) { (*env)->DeleteLocalRef(env, cls); return NULL; }
    jobject result = (*env)->NewObject(env, cls, ctor,
        (jlong)ram_used, (jlong)swap_used, (jlong)peak_ram);
    (*env)->DeleteLocalRef(env, cls);
    return result;
}
