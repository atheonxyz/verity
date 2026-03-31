package com.atheon.verity

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class ModelUnitTest {

    @Test
    fun circuitFromBytesCopiesInput() {
        val bytes = byteArrayOf(1, 2, 3)
        val circuit = Circuit.fromBytes(bytes)

        bytes[0] = 9

        assertArrayEquals(byteArrayOf(1, 2, 3), circuit.data)
    }

    @Test
    fun proofFromBytesCopiesInput() {
        val bytes = byteArrayOf(1, 2, 3)
        val proof = Proof.fromBytes(bytes)

        bytes[0] = 9

        assertArrayEquals(byteArrayOf(1, 2, 3), proof.data)
        assertEquals(3, proof.size)
    }

    @Test
    fun witnessFromJsonRoundTripsToResolvedJson() {
        val witness = Witness.fromJson("""{"x":"5"}""")

        val resolved = witness.resolve()
        assertTrue(resolved is Witness.Resolved.Json)
        assertEquals("{\"x\":\"5\"}", (resolved as Witness.Resolved.Json).json)
    }

    @Test
    fun witnessFromInvalidJsonThrows() {
        assertThrows(VerityException.InvalidInput::class.java) {
            Witness.fromJson("""["x"]""")
        }
    }

    @Test
    fun exceptionMappingCoversUnknownBackendAndOutOfMemory() {
        assertTrue(VerityException.fromCode(9) is VerityException.UnknownBackend)
        assertTrue(VerityException.fromCode(10) is VerityException.OutOfMemory)
    }

    @Test
    fun proofToStringMentionsBytes() {
        val proof = Proof.fromBytes(byteArrayOf(1, 2, 3))
        assertTrue(proof.toString().contains("bytes"))
    }

    @Test
    fun versionIsNotEmpty() {
        assertFalse(Verity.VERSION.isEmpty())
    }
}
