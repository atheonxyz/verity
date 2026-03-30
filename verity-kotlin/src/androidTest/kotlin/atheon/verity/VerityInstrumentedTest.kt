package atheon.verity

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

    @Test
    fun testProveKitBackendPrepareProveVerify() {
        val verity = Verity(Backend.PROVEKIT)

        verity.prepare(circuit = copyFixture("circuit.json")).use { scheme ->
            val proof = verity.prove(
                with = scheme.prover,
                input = copyFixture("Prover.toml")
            )
            assertFalse("Proof should not be empty", proof.isEmpty())

            val valid = verity.verify(
                with = scheme.verifier,
                proof = proof
            )
            assertTrue("ProveKit proof should verify", valid)
        }
    }

    @Test
    fun testBarretenbergBackendPrepareProveVerify() {
        val verity = Verity(Backend.BARRETENBERG)

        verity.prepare(circuit = copyFixture("circuit.json")).use { scheme ->
            val proof = verity.prove(
                with = scheme.prover,
                input = copyFixture("Prover.toml")
            )
            assertFalse("Proof should not be empty", proof.isEmpty())

            val valid = verity.verify(
                with = scheme.verifier,
                proof = proof
            )
            assertTrue("Barretenberg proof should verify", valid)
        }
    }

    @Test
    fun testSchemeReuse() {
        val verity = Verity(Backend.PROVEKIT)

        verity.prepare(circuit = copyFixture("circuit.json")).use { scheme ->
            // Generate two proofs from the same scheme
            val proof1 = verity.prove(with = scheme.prover, input = copyFixture("Prover.toml"))
            val proof2 = verity.prove(with = scheme.prover, input = copyFixture("Prover.toml"))

            assertFalse("Proof 1 should not be empty", proof1.isEmpty())
            assertFalse("Proof 2 should not be empty", proof2.isEmpty())

            assertTrue("Proof 1 should verify", verity.verify(with = scheme.verifier, proof = proof1))
            assertTrue("Proof 2 should verify", verity.verify(with = scheme.verifier, proof = proof2))
        }
    }

    @Test
    fun testSaveLoadRoundTrip() {
        val context = InstrumentationRegistry.getInstrumentation().targetContext
        val verity = Verity(Backend.PROVEKIT)

        val proverPath = File(context.cacheDir, "test_prover.pkp").absolutePath
        val verifierPath = File(context.cacheDir, "test_verifier.pkv").absolutePath

        try {
            // Prepare and save
            verity.prepare(circuit = copyFixture("circuit.json")).use { scheme ->
                scheme.prover.save(proverPath)
                scheme.verifier.save(verifierPath)
            }

            // Load and use
            val prover = verity.loadProver(proverPath)
            val verifier = verity.loadVerifier(verifierPath)

            prover.use { p ->
                verifier.use { v ->
                    val proof = verity.prove(with = p, input = copyFixture("Prover.toml"))
                    assertTrue("Loaded scheme proof should verify", verity.verify(with = v, proof = proof))
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

        // Prepare and serialize to bytes
        val proverBytes: ByteArray
        val verifierBytes: ByteArray
        verity.prepare(circuit = copyFixture("circuit.json")).use { scheme ->
            proverBytes = scheme.prover.serialize()
            verifierBytes = scheme.verifier.serialize()
        }

        assertFalse("Prover bytes should not be empty", proverBytes.isEmpty())
        assertFalse("Verifier bytes should not be empty", verifierBytes.isEmpty())

        // Load from bytes and use
        val prover = verity.loadProver(proverBytes)
        val verifier = verity.loadVerifier(verifierBytes)

        prover.use { p ->
            verifier.use { v ->
                val proof = verity.prove(with = p, input = copyFixture("Prover.toml"))
                assertTrue("Bytes-loaded scheme proof should verify", verity.verify(with = v, proof = proof))
            }
        }
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
    fun testProveEmptyInputPath() {
        val verity = Verity(Backend.PROVEKIT)
        verity.prepare(circuit = copyFixture("circuit.json")).use { scheme ->
            assertThrows(IllegalArgumentException::class.java) {
                verity.prove(with = scheme.prover, input = "")
            }
        }
    }

    @Test
    fun testProveNonexistentInput() {
        val verity = Verity(Backend.PROVEKIT)
        verity.prepare(circuit = copyFixture("circuit.json")).use { scheme ->
            assertThrows(VerityException::class.java) {
                verity.prove(with = scheme.prover, input = "/nonexistent/Prover.toml")
            }
        }
    }

    @Test
    fun testVerifyEmptyProof() {
        val verity = Verity(Backend.PROVEKIT)
        verity.prepare(circuit = copyFixture("circuit.json")).use { scheme ->
            assertThrows(IllegalArgumentException::class.java) {
                verity.verify(with = scheme.verifier, proof = ByteArray(0))
            }
        }
    }

    @Test
    fun testVerifyGarbageProof() {
        val verity = Verity(Backend.PROVEKIT)
        verity.prepare(circuit = copyFixture("circuit.json")).use { scheme ->
            val garbage = ByteArray(128) { 0x42 }
            val result = verity.verify(with = scheme.verifier, proof = garbage)
            assertFalse("Garbage proof should not verify", result)
        }
    }

    @Test
    fun testClosedProverSchemeThrows() {
        val verity = Verity(Backend.PROVEKIT)
        val scheme = verity.prepare(circuit = copyFixture("circuit.json"))
        val prover = scheme.prover
        scheme.close()

        assertThrows(IllegalStateException::class.java) {
            prover.save("/tmp/should_not_exist.pkp")
        }
    }

    @Test
    fun testClosedVerifierSchemeThrows() {
        val verity = Verity(Backend.PROVEKIT)
        val scheme = verity.prepare(circuit = copyFixture("circuit.json"))
        val verifier = scheme.verifier
        scheme.close()

        assertThrows(IllegalStateException::class.java) {
            verifier.save("/tmp/should_not_exist.pkv")
        }
    }

    @Test
    fun testClosedProverSerializeThrows() {
        val verity = Verity(Backend.PROVEKIT)
        val scheme = verity.prepare(circuit = copyFixture("circuit.json"))
        val prover = scheme.prover
        scheme.close()

        assertThrows(IllegalStateException::class.java) {
            prover.serialize()
        }
    }

    @Test
    fun testClosedVerifierSerializeThrows() {
        val verity = Verity(Backend.PROVEKIT)
        val scheme = verity.prepare(circuit = copyFixture("circuit.json"))
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
        val scheme = verity.prepare(circuit = copyFixture("circuit.json"))
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
        assertTrue(VerityException.fromCode(999) is VerityException.FfiError)
    }
}
