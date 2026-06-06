package app.provii.wallet.security

import app.provii.wallet.security.integrity.SignatureVerifier
import app.provii.wallet.security.integrity.SignatureVerifier.IntegrityLevel
import org.junit.Assert.*
import org.junit.Test

/**
 * Unit tests for SignatureVerifier.IntegrityResult computed properties:
 * isIntact, isTampered, and integrityLevel.
 */
class SignatureVerifierIntegrityResultTest {
    private fun buildResult(
        signatureValid: Boolean = true,
        dexHashValid: Boolean = true,
        manifestValid: Boolean = true,
        packageNameValid: Boolean = true,
        installerValid: Boolean = true,
    ): SignatureVerifier.IntegrityResult {
        return SignatureVerifier.IntegrityResult(
            signatureValid = signatureValid,
            expectedSignatureHash = "expected",
            actualSignatureHash = if (signatureValid) "expected" else "wrong",
            dexHashValid = dexHashValid,
            expectedDexHash = "dex_expected",
            actualDexHash = if (dexHashValid) "dex_expected" else "dex_wrong",
            manifestValid = manifestValid,
            packageNameValid = packageNameValid,
            installerValid = installerValid,
            installerPackage = if (installerValid) "com.android.vending" else null,
            issues = emptyList(),
        )
    }

    @Test
    fun `isIntact returns true when all core checks pass`() {
        val result = buildResult()
        assertTrue(result.isIntact)
    }

    @Test
    fun `isTampered returns true when signature invalid`() {
        val result = buildResult(signatureValid = false)
        assertTrue(result.isTampered)
        assertFalse(result.isIntact)
    }

    @Test
    fun `isTampered returns true when dex hash invalid`() {
        val result = buildResult(dexHashValid = false)
        assertTrue(result.isTampered)
    }

    @Test
    fun `integrityLevel is COMPROMISED when signature invalid`() {
        val result = buildResult(signatureValid = false)
        assertEquals(IntegrityLevel.COMPROMISED, result.integrityLevel)
    }

    @Test
    fun `integrityLevel is SUSPICIOUS when manifest invalid`() {
        val result = buildResult(manifestValid = false)
        assertEquals(IntegrityLevel.SUSPICIOUS, result.integrityLevel)
    }

    @Test
    fun `integrityLevel is VERIFIED when all checks pass including installer`() {
        val result = buildResult()
        assertEquals(IntegrityLevel.VERIFIED, result.integrityLevel)
    }
}
