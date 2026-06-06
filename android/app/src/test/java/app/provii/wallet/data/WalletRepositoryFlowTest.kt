// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.data

import android.content.Context
import android.content.SharedPreferences
import app.provii.wallet.KeystoreBridge
import app.provii.wallet.config.EnvironmentManager
import app.provii.wallet.config.SandboxCredentialFetcher
import app.provii.wallet.sdk.CredentialInfo
import app.provii.wallet.sdk.CredentialStatus
import app.provii.wallet.security.AuditLogger
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.BeforeClass
import org.junit.Test
import org.junit.runner.RunWith
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * Flow-level tests for [WalletRepository] verification and issuance paths.
 *
 * Tests inject [MockProviiWallet] via [WalletRepository.Companion.createForTesting],
 * bypassing Hilt DI, the native FFI, and the proving key. No real biometric or
 * network calls execute in these tests.
 */
@RunWith(RobolectricTestRunner::class)
@Config(manifest = Config.NONE, sdk = [29])
class WalletRepositoryFlowTest {
    private lateinit var mockWallet: MockProviiWallet
    private lateinit var mockContext: Context
    private lateinit var auditLogger: AuditLogger
    private lateinit var keystoreBridge: KeystoreBridge
    private lateinit var repository: WalletRepository

    companion object {
        @JvmStatic
        @BeforeClass
        fun setUpClass() {
            if (!EnvironmentManager.isInitialized()) {
                val mockEditor =
                    mock<SharedPreferences.Editor> {
                        on { putBoolean(any(), any()) }.thenReturn(mock)
                        on { putString(any(), any()) }.thenReturn(mock)
                        on { remove(any()) }.thenReturn(mock)
                    }
                val mockPrefs =
                    mock<SharedPreferences> {
                        on { getBoolean(any(), any()) }.thenReturn(false)
                        on { getString(any(), any()) }.thenReturn("production")
                        on { edit() }.thenReturn(mockEditor)
                    }
                EnvironmentManager.initializeForTesting(mockPrefs)
                SandboxCredentialFetcher.initializeForTesting(mockPrefs)
            }
        }
    }

    @Before
    fun setUp() {
        mockContext =
            mock {
                on { getString(any<Int>()) }.thenReturn("test error")
                on { getString(any<Int>(), any()) }.thenReturn("test error")
                on { filesDir }.thenReturn(java.io.File(System.getProperty("java.io.tmpdir")))
            }
        auditLogger = mock()
        keystoreBridge = mock()

        mockWallet = MockProviiWallet()
        repository =
            WalletRepository.createForTesting(
                appContext = mockContext,
                walletInterface = mockWallet,
                auditLogger = auditLogger,
                keystoreBridge = keystoreBridge,
            )
    }

    // MARK: - processVerificationChallenge

    @Test
    fun `processVerificationChallenge success returns challengeId`() =
        runBlocking {
            mockWallet.processQrChallengeResult = Result.success("challenge-id-abc123")

            val result = repository.processVerificationChallenge("provii.app/v?id=abc123")

            assertTrue("Expected success from processVerificationChallenge", result.isSuccess)
            assertEquals("challenge-id-abc123", result.getOrNull())
            assertEquals(1, mockWallet.processQrChallengeCallCount)
        }

    @Test
    fun `processVerificationChallenge invalidQr propagates failure`() =
        runBlocking {
            mockWallet.processQrChallengeResult = Result.failure(Exception("invalid QR payload"))

            val result = repository.processVerificationChallenge("not-a-valid-qr")

            assertTrue("Expected failure for invalid QR", result.isFailure)
            assertEquals(0, mockWallet.createAgeProofCallCount)
        }

    // MARK: - processQrCode

    @Test
    fun `processQrCode routes verificationChallenge correctly`() =
        runBlocking {
            val action = repository.processQrCode("provii.app/v?id=abc123")

            assertTrue("Expected VerificationChallenge action", action is WalletRepository.QrAction.VerificationChallenge)
        }

    @Test
    fun `processQrCode routes attestation correctly`() =
        runBlocking {
            val fakeAttestation =
                android.util.Base64.encodeToString(
                    """{"dob_days":20000,"expires_at":9999999999}""".toByteArray(),
                    android.util.Base64.URL_SAFE or android.util.Base64.NO_WRAP,
                )
            val attestationMock =
                object : MockProviiWallet() {
                    override fun processScannedQr(qrContent: String): app.provii.wallet.sdk.QrAction =
                        app.provii.wallet.sdk.QrAction.Attestation(fakeAttestation)
                }
            val attestationRepo =
                WalletRepository.createForTesting(
                    appContext = mockContext,
                    walletInterface = attestationMock,
                    auditLogger = auditLogger,
                    keystoreBridge = keystoreBridge,
                )

            val action = attestationRepo.processQrCode("provii.app/a?data=$fakeAttestation")

            assertTrue("Expected Attestation action", action is WalletRepository.QrAction.Attestation)
        }

    // MARK: - refreshCredentialState / credential state

    @Test
    fun `refreshCredentialState with empty list sets None state`() =
        runBlocking {
            mockWallet.listCredentialsResult = Result.success(emptyList())

            repository.refreshCredentialState()

            assertTrue(
                "Expected CredentialState.None",
                repository.credentialState.value is WalletRepository.CredentialState.None,
            )
        }

    @Test
    fun `refreshCredentialState with primary credential sets HasCredentials`() =
        runBlocking {
            val credential = makeCredentialInfo("primary-001", "primary")
            mockWallet.listCredentialsResult = Result.success(listOf(credential))

            repository.refreshCredentialState()

            val state = repository.credentialState.value
            assertTrue("Expected HasCredentials state", state is WalletRepository.CredentialState.HasCredentials)
            val hasCredentials = state as WalletRepository.CredentialState.HasCredentials
            assertEquals("primary-001", hasCredentials.primary?.id)
            assertTrue("Expected empty managed list", hasCredentials.managed.isEmpty())
        }

    @Test
    fun `refreshCredentialState with primary and managed separates them`() =
        runBlocking {
            val primary = makeCredentialInfo("primary-001", "primary")
            val managed = makeCredentialInfo("managed-001", "managed", nickname = "Work ID")
            mockWallet.listCredentialsResult = Result.success(listOf(primary, managed))

            repository.refreshCredentialState()

            val state = repository.credentialState.value as WalletRepository.CredentialState.HasCredentials
            assertEquals("primary-001", state.primary?.id)
            assertEquals(1, state.managed.size)
            assertEquals("managed-001", state.managed.first().id)
        }

    @Test
    fun `refreshCredentialState on SDK failure sets None state`() =
        runBlocking {
            mockWallet.listCredentialsResult = Result.failure(RuntimeException("storage error"))

            repository.refreshCredentialState()

            assertTrue(
                "Expected CredentialState.None after storage error",
                repository.credentialState.value is WalletRepository.CredentialState.None,
            )
        }

    // MARK: - submitProof

    @Test
    fun `submitProof success returns true`() =
        runBlocking {
            mockWallet.submitProofResult = Result.success(true)

            val result =
                repository.submitProof(
                    """{"proof":"valid","challenge_id":"challenge-id-abc123","credential_id":"cred-id-xyz789"}""",
                )

            assertTrue("Expected successful proof submission", result.isSuccess)
            assertEquals(true, result.getOrNull())
            assertEquals(1, mockWallet.submitProofCallCount)
        }

    @Test
    fun `submitProof networkError propagates failure`() =
        runBlocking {
            mockWallet.submitProofResult = Result.failure(RuntimeException("connection refused"))

            val result = repository.submitProof("""{"proof":"valid"}""")

            assertTrue("Expected failure on network error", result.isFailure)
            assertEquals(1, mockWallet.submitProofCallCount)
        }

    // MARK: - processBlindIssuance (attestation validation)

    @Test
    fun `processBlindIssuance with invalid base64 returns failure`() =
        runBlocking {
            val result = repository.processBlindIssuance("!!not-base64-data!!")

            assertTrue("Expected failure for invalid base64", result.isFailure)
            assertEquals(0, mockWallet.finalizeAndStoreCredentialCallCount)
        }

    @Test
    fun `processBlindIssuance with expired attestation returns failure`() =
        runBlocking {
            val expiredPayload = """{"dob_days":20000,"expires_at":0}"""
            val attestationB64 =
                android.util.Base64.encodeToString(
                    expiredPayload.toByteArray(Charsets.UTF_8),
                    android.util.Base64.URL_SAFE or android.util.Base64.NO_WRAP,
                )

            val result = repository.processBlindIssuance(attestationB64)

            assertTrue("Expected failure for expired attestation", result.isFailure)
            assertEquals(0, mockWallet.finalizeAndStoreCredentialCallCount)
        }

    // MARK: - deleteCredential

    @Test
    fun `deleteCredential succeeds and refreshes state`() =
        runBlocking {
            mockWallet.listCredentialsResult = Result.success(emptyList())

            val result = repository.deleteCredential("cred-id-xyz789")

            assertTrue("Expected successful deletion", result.isSuccess)
        }

    // MARK: - Helpers

    private fun makeCredentialInfo(
        id: String,
        credentialType: String,
        nickname: String? = null,
    ): CredentialInfo =
        CredentialInfo(
            id = id,
            issuerName = "Test Issuer",
            issuerKid = "issuer-kid-001",
            issuedAt = 1_000_000uL,
            expiresAt = 9_999_999_999uL,
            isExpired = false,
            canProve = true,
            schema = "provii.age/1",
            status = CredentialStatus.VALID,
            credentialType = credentialType,
            nickname = nickname,
            managedIndex = if (credentialType == "managed") 0u else null,
        )
}
