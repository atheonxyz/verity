package com.atheon.verity

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class VerityInstrumentedTest {

    private fun copyFixture(relativePath: String): String {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val outFile = File(context.cacheDir, "fixtures/$relativePath")
        outFile.parentFile?.mkdirs()
        context.assets.open("fixtures/$relativePath").use { input ->
            outFile.outputStream().use { output ->
                input.copyTo(output)
            }
        }
        return outFile.absolutePath
    }

    private fun loadCircuit(): Circuit = Circuit.load(copyFixture("circuit.json"))

    private fun witness(): Witness = Witness.load(copyFixture("Prover.toml"))

    // -- Circuit Loading --

    @Test
    fun testCircuitLoadFromPath() {
        val circuit = Circuit.load(copyFixture("circuit.json"))
        assertFalse("Circuit data should not be empty", circuit.data.isEmpty())
    }

    @Test
    fun testCircuitLoadFromFile() {
        val file = File(copyFixture("circuit.json"))
        val circuit = Circuit.load(file)
        assertFalse("Circuit data should not be empty", circuit.data.isEmpty())
    }

    @Test
    fun testCircuitLoadNonexistentPath() {
        assertThrows(VerityException::class.java) {
            Circuit.load("/nonexistent/circuit.json")
        }
    }

    // -- ProveKit --

    @Test
    fun testProveKitBackendPrepareProveVerify() {
        val verity = Verity(Backend.PROVEKIT)

        verity.prepare(loadCircuit()).use { scheme ->
            val proof = scheme.prover.prove(witness())
            assertFalse("Proof should not be empty", proof.data.isEmpty())
            assertTrue("Proof size should be positive", proof.size > 0)
            assertFalse("Proof hex should not be empty", proof.hex.isEmpty())

            val valid = scheme.verifier.verify(proof)
            assertTrue("ProveKit proof should verify", valid)
        }
    }

    @Test
    fun testProveKitWithStringConvenience() {
        val verity = Verity(Backend.PROVEKIT)

        verity.prepare(copyFixture("circuit.json")).use { scheme ->
            val proof = scheme.prover.prove(Witness.load(copyFixture("Prover.toml")))
            assertTrue("Should verify", scheme.verifier.verify(proof))
        }
    }

    @Test
    fun testBarretenbergBackendPrepareProveVerify() {
        val verity = Verity(Backend.BARRETENBERG)

        verity.prepare(loadCircuit()).use { scheme ->
            val proof = scheme.prover.prove(witness())
            assertFalse("Proof should not be empty", proof.data.isEmpty())

            val valid = scheme.verifier.verify(proof)
            assertTrue("Barretenberg proof should verify", valid)
        }
    }

    @Test
    fun testSchemeReuse() {
        val verity = Verity(Backend.PROVEKIT)

        verity.prepare(loadCircuit()).use { scheme ->
            val input = witness()
            val proof1 = scheme.prover.prove(input)
            val proof2 = scheme.prover.prove(input)

            assertFalse("Proof 1 should not be empty", proof1.data.isEmpty())
            assertFalse("Proof 2 should not be empty", proof2.data.isEmpty())

            assertTrue("Proof 1 should verify", scheme.verifier.verify(proof1))
            assertTrue("Proof 2 should verify", scheme.verifier.verify(proof2))
        }
    }

    @Test
    fun testSaveLoadRoundTrip() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val verity = Verity(Backend.PROVEKIT)

        val proverPath = File(context.cacheDir, "test_prover.pkp").absolutePath
        val verifierPath = File(context.cacheDir, "test_verifier.pkv").absolutePath

        try {
            verity.prepare(loadCircuit()).use { scheme ->
                scheme.prover.save(proverPath)
                scheme.verifier.save(verifierPath)
            }

            val prover = verity.loadProver(proverPath)
            val verifier = verity.loadVerifier(verifierPath)

            prover.use { p ->
                verifier.use { v ->
                    val proof = p.prove(witness())
                    assertTrue("Loaded scheme proof should verify", v.verify(proof))
                }
            }
        } finally {
            File(proverPath).delete()
            File(verifierPath).delete()
        }
    }

    @Test
    fun testSerializeBytesRoundTrip() {
        val verity = Verity(Backend.PROVEKIT)

        val proverBytes: ByteArray
        val verifierBytes: ByteArray
        verity.prepare(loadCircuit()).use { scheme ->
            proverBytes = scheme.prover.serialize()
            verifierBytes = scheme.verifier.serialize()
        }

        assertFalse("Prover bytes should not be empty", proverBytes.isEmpty())
        assertFalse("Verifier bytes should not be empty", verifierBytes.isEmpty())

        val prover = verity.loadProver(proverBytes)
        val verifier = verity.loadVerifier(verifierBytes)

        prover.use { p ->
            verifier.use { v ->
                val proof = p.prove(witness())
                assertTrue("Bytes-loaded scheme proof should verify", v.verify(proof))
            }
        }
    }

    // -- Proof Type --

    @Test
    fun testProofHexPreview() {
        val verity = Verity(Backend.PROVEKIT)
        verity.prepare(loadCircuit()).use { scheme ->
            val proof = scheme.prover.prove(witness())
            val preview = proof.hexPreview(8)
            assertTrue("Preview should be truncated", preview.endsWith("..."))
        }
    }

    @Test
    fun testProofToString() {
        val verity = Verity(Backend.PROVEKIT)
        verity.prepare(loadCircuit()).use { scheme ->
            val proof = scheme.prover.prove(witness())
            assertTrue("toString should contain 'bytes'", proof.toString().contains("bytes"))
        }
    }

    @Test
    fun testProofFromBytes() {
        val bytes = ByteArray(64) { it.toByte() }
        val proof = Proof.fromBytes(bytes)
        assertTrue("Proof should have correct size", proof.size == 64)
        // Verify defensive copy — mutating original should not affect proof
        bytes[0] = 0xFF.toByte()
        assertTrue("Proof should be independent of original array", proof.data[0] == 0.toByte())
    }

    // -- Witness & Circuit types --

    @Test
    fun testWitnessLoadNonexistentPath() {
        assertThrows(VerityException::class.java) {
            Witness.load("/nonexistent/Prover.toml")
        }
    }

    @Test
    fun testCircuitFromBytes() {
        val file = java.io.File(copyFixture("circuit.json"))
        val bytes = file.readBytes()
        val circuit = Circuit.fromBytes(bytes)
        assertFalse("Circuit data should not be empty", circuit.data.isEmpty())
    }

    @Test
    fun testCircuitFromBytesEmpty() {
        assertThrows(IllegalArgumentException::class.java) {
            Circuit.fromBytes(ByteArray(0))
        }
    }

    @Test
    fun testWitnessFromJson() {
        val verity = Verity(Backend.PROVEKIT)
        // Just verify it doesn't throw — actual proving would need matching circuit inputs
        val witness = Witness.fromJson("""{"x": "5"}""")
        // Witness created successfully
        assertTrue("fromJson should create valid witness", true)
    }

    // -- Negative tests --

    @Test
    fun testPrepareEmptyCircuitPath() {
        val verity = Verity(Backend.PROVEKIT)
        assertThrows(IllegalArgumentException::class.java) {
            verity.prepare(circuit = "")
        }
    }

    @Test
    fun testPrepareNonexistentCircuit() {
        val verity = Verity(Backend.PROVEKIT)
        assertThrows(VerityException::class.java) {
            verity.prepare(circuit = "/nonexistent/circuit.json")
        }
    }

    @Test
    fun testProveNonexistentWitness() {
        val verity = Verity(Backend.PROVEKIT)
        verity.prepare(loadCircuit()).use { scheme ->
            assertThrows(VerityException::class.java) {
                scheme.prover.prove(Witness.load("/nonexistent/Prover.toml"))
            }
        }
    }

    @Test
    fun testVerifyGarbageProof() {
        val verity = Verity(Backend.PROVEKIT)
        verity.prepare(loadCircuit()).use { scheme ->
            val garbage = Proof(ByteArray(128) { 0x42 })
            val result = scheme.verifier.verify(garbage)
            assertFalse("Garbage proof should not verify", result)
        }
    }

    @Test
    fun testClosedProverSchemeThrows() {
        val verity = Verity(Backend.PROVEKIT)
        val scheme = verity.prepare(loadCircuit())
        val prover = scheme.prover
        scheme.close()

        assertThrows(IllegalStateException::class.java) {
            prover.save("/tmp/should_not_exist.pkp")
        }
    }

    @Test
    fun testClosedVerifierSchemeThrows() {
        val verity = Verity(Backend.PROVEKIT)
        val scheme = verity.prepare(loadCircuit())
        val verifier = scheme.verifier
        scheme.close()

        assertThrows(IllegalStateException::class.java) {
            verifier.save("/tmp/should_not_exist.pkv")
        }
    }

    @Test
    fun testClosedProverSerializeThrows() {
        val verity = Verity(Backend.PROVEKIT)
        val scheme = verity.prepare(loadCircuit())
        val prover = scheme.prover
        scheme.close()

        assertThrows(IllegalStateException::class.java) {
            prover.serialize()
        }
    }

    @Test
    fun testClosedVerifierSerializeThrows() {
        val verity = Verity(Backend.PROVEKIT)
        val scheme = verity.prepare(loadCircuit())
        val verifier = scheme.verifier
        scheme.close()

        assertThrows(IllegalStateException::class.java) {
            verifier.serialize()
        }
    }

    @Test
    fun testLoadProverEmptyPath() {
        val verity = Verity(Backend.PROVEKIT)
        assertThrows(IllegalArgumentException::class.java) {
            verity.loadProver("")
        }
    }

    @Test
    fun testLoadVerifierEmptyPath() {
        val verity = Verity(Backend.PROVEKIT)
        assertThrows(IllegalArgumentException::class.java) {
            verity.loadVerifier("")
        }
    }

    @Test
    fun testLoadProverEmptyBytes() {
        val verity = Verity(Backend.PROVEKIT)
        assertThrows(IllegalArgumentException::class.java) {
            verity.loadProver(ByteArray(0))
        }
    }

    @Test
    fun testLoadVerifierEmptyBytes() {
        val verity = Verity(Backend.PROVEKIT)
        assertThrows(IllegalArgumentException::class.java) {
            verity.loadVerifier(ByteArray(0))
        }
    }

    @Test
    fun testLoadProverNonexistentPath() {
        val verity = Verity(Backend.PROVEKIT)
        assertThrows(VerityException::class.java) {
            verity.loadProver("/nonexistent/prover.pkp")
        }
    }

    @Test
    fun testLoadVerifierNonexistentPath() {
        val verity = Verity(Backend.PROVEKIT)
        assertThrows(VerityException::class.java) {
            verity.loadVerifier("/nonexistent/verifier.pkv")
        }
    }

    @Test
    fun testDoubleCloseIsHarmless() {
        val verity = Verity(Backend.PROVEKIT)
        val scheme = verity.prepare(loadCircuit())
        scheme.close()
        scheme.close() // should not throw
    }

    @Test
    fun testErrorCodeMapping() {
        assertTrue(VerityException.fromCode(1) is VerityException.InvalidInput)
        assertTrue(VerityException.fromCode(2) is VerityException.SchemeReadError)
        assertTrue(VerityException.fromCode(4) is VerityException.VerificationFailed)
        assertTrue(VerityException.fromCode(5) is VerityException.SerializationError)
        assertTrue(VerityException.fromCode(8) is VerityException.CompilationFailed)
        assertTrue(VerityException.fromCode(9) is VerityException.UnknownBackend)
        assertTrue(VerityException.fromCode(10) is VerityException.OutOfMemory)
        assertTrue(VerityException.fromCode(999) is VerityException.FfiError)
    }

    @Test
    fun testVersionIsNotEmpty() {
        assertTrue("Version should not be empty", Verity.VERSION.isNotEmpty())
    }
}
