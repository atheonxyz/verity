/**
 * gen_fixtures — generate .pkp/.pkv (or .bbp/.bbv) test fixtures from a circuit.
 *
 * This tool calls the raw backend prepare + save functions directly,
 * bypassing the dispatcher (which no longer exposes prepare).
 *
 * Usage:
 *   gen_fixtures <pk|bb> <circuit.json> <output_dir>
 *
 * Produces:
 *   <output_dir>/prover.pkp   (or .bbp)
 *   <output_dir>/verifier.pkv (or .bbv)
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <stdbool.h>

/* ── ProveKit backend symbols ──────────────────────────────────────────── */

typedef struct PKProver PKProver;
typedef struct PKVerifier PKVerifier;

extern int  pk_init(void);
extern int  pk_prepare(const char *circuit_path, PKProver **out_prover, PKVerifier **out_verifier);
extern int  pk_save_prover(const PKProver *prover, const char *path);
extern int  pk_save_verifier(const PKVerifier *verifier, const char *path);
extern void pk_free_prover(PKProver *prover);
extern void pk_free_verifier(PKVerifier *verifier);

/* ── Barretenberg backend symbols ──────────────────────────────────────── */

typedef struct BBProver BBProver;
typedef struct BBVerifier BBVerifier;

extern int  bb_prepare(const char *circuit_path, BBProver **out_prover, BBVerifier **out_verifier);
extern int  bb_save_prover(const BBProver *prover, const char *path);
extern int  bb_save_verifier(const BBVerifier *verifier, const char *path);
extern void bb_free_prover(BBProver *prover);
extern void bb_free_verifier(BBVerifier *verifier);

/* ── Main ──────────────────────────────────────────────────────────────── */

static void usage(const char *prog) {
    fprintf(stderr, "Usage: %s <pk|bb> <circuit.json> <output_dir>\n", prog);
    exit(1);
}

int main(int argc, char **argv) {
    if (argc != 4) usage(argv[0]);

    const char *backend    = argv[1];
    const char *circuit    = argv[2];
    const char *output_dir = argv[3];

    int is_pk = (strcmp(backend, "pk") == 0);
    int is_bb = (strcmp(backend, "bb") == 0);
    if (!is_pk && !is_bb) {
        fprintf(stderr, "Error: backend must be 'pk' or 'bb', got '%s'\n", backend);
        return 1;
    }

    /* Build output paths */
    char prover_path[4096];
    char verifier_path[4096];
    const char *ext_p = is_pk ? "pkp" : "bbp";
    const char *ext_v = is_pk ? "pkv" : "bbv";
    snprintf(prover_path, sizeof(prover_path), "%s/prover.%s", output_dir, ext_p);
    snprintf(verifier_path, sizeof(verifier_path), "%s/verifier.%s", output_dir, ext_v);

    int code;

    if (is_pk) {
        code = pk_init();
        if (code != 0) { fprintf(stderr, "pk_init failed: %d\n", code); return code; }

        PKProver *prover = NULL;
        PKVerifier *verifier = NULL;

        fprintf(stderr, "Preparing (ProveKit): %s\n", circuit);
        code = pk_prepare(circuit, &prover, &verifier);
        if (code != 0) { fprintf(stderr, "pk_prepare failed: %d\n", code); return code; }

        fprintf(stderr, "Saving prover:   %s\n", prover_path);
        code = pk_save_prover(prover, prover_path);
        if (code != 0) { fprintf(stderr, "pk_save_prover failed: %d\n", code); return code; }

        fprintf(stderr, "Saving verifier: %s\n", verifier_path);
        code = pk_save_verifier(verifier, verifier_path);
        if (code != 0) { fprintf(stderr, "pk_save_verifier failed: %d\n", code); return code; }

        pk_free_prover(prover);
        pk_free_verifier(verifier);
    } else {
        BBProver *prover = NULL;
        BBVerifier *verifier = NULL;

        fprintf(stderr, "Preparing (Barretenberg): %s\n", circuit);
        code = bb_prepare(circuit, &prover, &verifier);
        if (code != 0) { fprintf(stderr, "bb_prepare failed: %d\n", code); return code; }

        fprintf(stderr, "Saving prover:   %s\n", prover_path);
        code = bb_save_prover(prover, prover_path);
        if (code != 0) { fprintf(stderr, "bb_save_prover failed: %d\n", code); return code; }

        fprintf(stderr, "Saving verifier: %s\n", verifier_path);
        code = bb_save_verifier(verifier, verifier_path);
        if (code != 0) { fprintf(stderr, "bb_save_verifier failed: %d\n", code); return code; }

        bb_free_prover(prover);
        bb_free_verifier(verifier);
    }

    fprintf(stderr, "Done.\n");
    return 0;
}
