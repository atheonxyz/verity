package com.atheon.verity

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test
import xyz.atheon.verity.Proof
import xyz.atheon.verity.Verity
import xyz.atheon.verity.VerityException
import xyz.atheon.verity.Witness

class ModelUnitTest {

    @Test
    fun proofFromBytesCopiesInput() {
        val bytes = byteArrayOf(1, 2, 3)
        val proof = Proof.fromBytes(bytes)

        bytes[0] = 9

        assertArrayEquals(byteArrayOf(1, 2, 3), proof.data)
        assertEquals(3, proof.size)
    }

    @Test
    fun witnessFromJsonDoesNotThrow() {
        // Witness.fromJson should accept valid JSON objects without throwing
        Witness.fromJson("""{"x":"5"}""")
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
