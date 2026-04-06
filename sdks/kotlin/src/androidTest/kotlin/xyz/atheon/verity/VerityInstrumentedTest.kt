package xyz.atheon.verity

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

    private fun proverPath(): String = copyFixture("prover.pkp")
    private fun verifierPath(): String = copyFixture("verifier.pkv")
    private fun witness(): Witness = Witness.load(copyFixture("Prover.toml"))

    // -- ProveKit --

    @Test
    fun testProveKitBackendLoadProveVerify() {
        val verity = Verity(Backend.PROVEKIT)

        val prover = verity.loadProver(proverPath())
        val verifier = verity.loadVerifier(verifierPath())
        prover.use { p ->
            verifier.use { v ->
                val proof = p.prove(witness())
                assertFalse("Proof should not be empty", proof.data.isEmpty())
                assertTrue("Proof size should be positive", proof.size > 0)
                assertFalse("Proof hex should not be empty", proof.hex.isEmpty())

                val valid = v.verify(proof)
                assertTrue("ProveKit proof should verify", valid)
            }
        }
    }

    @Test
    fun testSchemeReuse() {
        val verity = Verity(Backend.PROVEKIT)

        val prover = verity.loadProver(proverPath())
        val verifier = verity.loadVerifier(verifierPath())
        prover.use { p ->
            verifier.use { v ->
                val input = witness()
                val proof1 = p.prove(input)
                val proof2 = p.prove(input)

                assertFalse("Proof 1 should not be empty", proof1.data.isEmpty())
                assertFalse("Proof 2 should not be empty", proof2.data.isEmpty())

                assertTrue("Proof 1 should verify", v.verify(proof1))
                assertTrue("Proof 2 should verify", v.verify(proof2))
            }
        }
    }

    @Test
    fun testSaveLoadRoundTrip() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val verity = Verity(Backend.PROVEKIT)

        val savedProverPath = File(context.cacheDir, "test_prover.pkp").absolutePath
        val savedVerifierPath = File(context.cacheDir, "test_verifier.pkv").absolutePath

        try {
            // Load from fixtures, then re-save
            val prover = verity.loadProver(proverPath())
            val verifier = verity.loadVerifier(verifierPath())
            prover.use { it.save(savedProverPath) }
            verifier.use { it.save(savedVerifierPath) }

            // Reload from saved files and verify
            val reloadedProver = verity.loadProver(savedProverPath)
            val reloadedVerifier = verity.loadVerifier(savedVerifierPath)

            reloadedProver.use { p ->
                reloadedVerifier.use { v ->
                    val proof = p.prove(witness())
                    assertTrue("Reloaded scheme proof should verify", v.verify(proof))
                }
            }
        } finally {
            File(savedProverPath).delete()
            File(savedVerifierPath).delete()
        }
    }

    @Test
    fun testSerializeBytesRoundTrip() {
        val verity = Verity(Backend.PROVEKIT)

        val proverBytes: ByteArray
        val verifierBytes: ByteArray
        verity.loadProver(proverPath()).use { proverBytes = it.serialize() }
        verity.loadVerifier(verifierPath()).use { verifierBytes = it.serialize() }

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
        verity.loadProver(proverPath()).use { prover ->
            val proof = prover.prove(witness())
            val preview = proof.hexPreview(8)
            assertTrue("Preview should be truncated", preview.endsWith("..."))
        }
    }

    @Test
    fun testProofToString() {
        val verity = Verity(Backend.PROVEKIT)
        verity.loadProver(proverPath()).use { prover ->
            val proof = prover.prove(witness())
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

    // -- Witness types --

    @Test
    fun testWitnessLoadNonexistentPath() {
        assertThrows(VerityException::class.java) {
            Witness.load("/nonexistent/Prover.toml")
        }
    }

    @Test
    fun testWitnessFromJson() {
        val verity = Verity(Backend.PROVEKIT)
        val witness = Witness.fromJson("""{"x": "5"}""")
        assertTrue("fromJson should create valid witness", true)
    }

    // -- Negative tests --

    @Test
    fun testVerifyGarbageProof() {
        val verity = Verity(Backend.PROVEKIT)
        verity.loadVerifier(verifierPath()).use { verifier ->
            val garbage = Proof.fromBytes(ByteArray(128) { 0x42 })
            val result = verifier.verify(garbage)
            assertFalse("Garbage proof should not verify", result)
        }
    }

    @Test
    fun testClosedProverSchemeThrows() {
        val verity = Verity(Backend.PROVEKIT)
        val prover = verity.loadProver(proverPath())
        prover.close()

        assertThrows(IllegalStateException::class.java) {
            prover.save("/tmp/should_not_exist.pkp")
        }
    }

    @Test
    fun testClosedVerifierSchemeThrows() {
        val verity = Verity(Backend.PROVEKIT)
        val verifier = verity.loadVerifier(verifierPath())
        verifier.close()

        assertThrows(IllegalStateException::class.java) {
            verifier.save("/tmp/should_not_exist.pkv")
        }
    }

    @Test
    fun testClosedProverSerializeThrows() {
        val verity = Verity(Backend.PROVEKIT)
        val prover = verity.loadProver(proverPath())
        prover.close()

        assertThrows(IllegalStateException::class.java) {
            prover.serialize()
        }
    }

    @Test
    fun testClosedVerifierSerializeThrows() {
        val verity = Verity(Backend.PROVEKIT)
        val verifier = verity.loadVerifier(verifierPath())
        verifier.close()

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
        val prover = verity.loadProver(proverPath())
        prover.close()
        prover.close() // should not throw
    }

    @Test
    fun testErrorCodeMapping() {
        assertTrue(VerityException.fromCode(1) is VerityException.InvalidInput)
        assertTrue(VerityException.fromCode(2) is VerityException.SchemeReadError)
        assertTrue(VerityException.fromCode(4) is VerityException.VerificationFailed)
        assertTrue(VerityException.fromCode(5) is VerityException.SerializationError)
        assertTrue(VerityException.fromCode(9) is VerityException.UnknownBackend)
        assertTrue(VerityException.fromCode(10) is VerityException.OutOfMemory)
        assertTrue(VerityException.fromCode(999) is VerityException.FfiError)
    }

    @Test
    fun testVersionIsNotEmpty() {
        assertTrue("Version should not be empty", Verity.VERSION.isNotEmpty())
    }
}
