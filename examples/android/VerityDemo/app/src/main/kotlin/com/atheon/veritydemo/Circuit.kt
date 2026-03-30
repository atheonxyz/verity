package com.atheon.veritydemo

data class Circuit(
    val name: String,
    val description: String,
    val assetDir: String,
) {
    override fun toString() = name
}

val BUNDLED_CIRCUITS = listOf(
    Circuit("Poseidon2", "Hash function proof \u2014 fast, small circuit", "circuits/poseidon2"),
    Circuit("SHA-256", "SHA-256 hash proof \u2014 medium complexity", "circuits/noir_sha256"),
    Circuit("Age Check", "Passport age verification \u2014 larger circuit", "circuits/complete_age_check"),
)
