package com.aspect.verity

/** Available proving backends. */
enum class Backend {
    /** ProveKit WHIR backend (transparent, hash-based). */
    PROVEKIT,

    /** Barretenberg UltraHonk backend (KZG commitments). */
    BARRETENBERG,
}
