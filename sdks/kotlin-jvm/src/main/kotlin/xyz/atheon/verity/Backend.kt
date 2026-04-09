package xyz.atheon.verity

/** Available proving backends. */
enum class Backend(val code: Int) {
    /** ProveKit WHIR backend (transparent, hash-based). */
    PROVEKIT(0),

    /** Barretenberg UltraHonk backend (KZG commitments). */
    BARRETENBERG(1),
}
