package com.atheon.verity

import org.json.JSONObject
import java.io.File

/**
 * Witness values — the private inputs to a zero-knowledge proof.
 *
 * Load from a TOML file (output of `nargo execute`) or construct from a map.
 *
 * ```kotlin
 * val witness = Witness.load("Prover.toml")
 * val witness = Witness.of(mapOf("x" to "5", "y" to "10"))
 * val proof   = scheme.prover.prove(witness)
 * ```
 */
class Witness private constructor(
    private val storage: Storage
) {

    private sealed class Storage {
        data class Toml(val path: String) : Storage()
        data class Values(val map: Map<String, String>) : Storage()
        data class RawJson(val json: String) : Storage()
    }

    internal sealed class Resolved {
        data class TomlPath(val path: String) : Resolved()
        data class Json(val json: String) : Resolved()
    }

    internal fun resolve(): Resolved = when (storage) {
        is Storage.Toml -> Resolved.TomlPath(storage.path)
        is Storage.Values -> Resolved.Json(JSONObject(storage.map).toString())
        is Storage.RawJson -> Resolved.Json(storage.json)
    }

    companion object {
        /**
         * Load witness values from a TOML file path (e.g., `Prover.toml` from `nargo execute`).
         *
         * @param path Path to the TOML witness file.
         * @throws VerityException.InvalidInput if the file does not exist.
         */
        @JvmStatic
        fun load(path: String): Witness {
            val file = File(path)
            if (!file.exists() || !file.canRead()) {
                throw VerityException.InvalidInput("witness file not found: $path")
            }
            return Witness(Storage.Toml(path))
        }

        /**
         * Load witness values from a [File].
         *
         * @param file The TOML witness file.
         * @throws VerityException.InvalidInput if the file does not exist.
         */
        @JvmStatic
        fun load(file: File): Witness = load(file.absolutePath)

        /**
         * Create a witness from a map of field element strings.
         *
         * Keys are circuit parameter names. Values are field element strings
         * (e.g., `"5"`, `"0x1a2b..."`, or decimal strings).
         *
         * @param values Map of parameter names to field element strings.
         */
        @JvmStatic
        fun of(values: Map<String, String>): Witness {
            require(values.isNotEmpty()) { "witness values cannot be empty" }
            return Witness(Storage.Values(values))
        }

        /**
         * Create a witness from a JSON string.
         *
         * Supports all JSON types including arrays and nested objects,
         * which are needed for circuits with array or struct inputs.
         *
         * ```kotlin
         * val witness = Witness.fromJson("""{"x": ["1", "2", "3"]}""")
         * ```
         *
         * @param json JSON string of witness inputs.
         */
        @JvmStatic
        fun fromJson(json: String): Witness {
            require(json.isNotEmpty()) { "JSON string cannot be empty" }
            return Witness(Storage.RawJson(json))
        }
    }
}
