package xyz.atheon.veritydemo

data class DemoCircuit(
    val name: String,
    val description: String,
    val assetDir: String,
    /** For fragmented circuits: ordered list of sub-circuit directory names within assetDir. */
    val steps: List<String>? = null,
) {
    val isFragmented get() = steps != null
    override fun toString() = name
}

val BUNDLED_CIRCUITS = listOf(
    DemoCircuit("Poseidon2", "Hash function proof — fast, small circuit", "circuits/poseidon2"),
    DemoCircuit("SHA-256", "SHA-256 hash proof — medium complexity", "circuits/noir_sha256"),
    DemoCircuit("Passport Age Check", "Passport age verification — larger circuit", "circuits/complete_age_check"),
    DemoCircuit(
        "Passport Age Check (Fragmented)",
        "Multi-step passport verification — 4 chained proofs",
        "circuits/fragmented_complete_age_check",
        steps = listOf("t_add_dsc_720", "t_add_id_data_720", "t_add_integrity_commit", "t_attest"),
    ),
)
