// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.data

import app.provii.wallet.sdk.CredentialInfo
import app.provii.wallet.sdk.CredentialSuitability
import app.provii.wallet.sdk.DeeplinkAction
import app.provii.wallet.sdk.DiagnosticInfo
import app.provii.wallet.sdk.NetworkStatus
import app.provii.wallet.sdk.ProviiWalletInterface
import app.provii.wallet.sdk.ProgressStage
import app.provii.wallet.sdk.ProgressTracker
import app.provii.wallet.sdk.QrAction
import app.provii.wallet.sdk.SecureStorageHandle
import app.provii.wallet.sdk.VerificationStatus
import app.provii.wallet.sdk.WalletConfig

/**
 * Test double for [ProviiWalletInterface]. Returns configurable canned values
 * so that WalletRepository flow tests exercise orchestration logic without
 * loading native FFI or the proving key.
 */
open class MockProviiWallet : ProviiWalletInterface {
    // MARK: - Configuration

    var processQrChallengeResult: Result<String> = Result.success("challenge-id-abc123")
    var createAgeProofResult: Result<String> =
        Result.success(
            """{"proof":"valid","challenge_id":"challenge-id-abc123","credential_id":"cred-id-xyz789"}""",
        )
    var submitProofResult: Result<Boolean> = Result.success(true)
    var listCredentialsResult: Result<List<CredentialInfo>> = Result.success(emptyList())
    var finalizeAndStoreCredentialResult: Result<String> = Result.success("stored-cred-id-001")
    var getCredentialResult: String? = """{"id":"cred-id-xyz789","credentialType":"primary"}"""
    private var _verifierBaseUrl: String = "https://verifier.example.test"

    private val diagnosticInfoValue =
        DiagnosticInfo(
            sdkVersion = "0.0.0-test",
            appVersion = "1.0.0",
            platform = "Android",
            proverInitialized = true,
            credentialCount = 0u,
            storageAvailable = true,
            configEnvironment = "test",
            lastProofGenerated = null,
        )

    // MARK: - Call tracking

    var processQrChallengeCallCount = 0
    var createAgeProofCallCount = 0
    var submitProofCallCount = 0
    var finalizeAndStoreCredentialCallCount = 0

    // MARK: - ProviiWalletInterface implementation

    override fun processQrChallenge(qrContent: String): String {
        processQrChallengeCallCount++
        return processQrChallengeResult.getOrThrow()
    }

    override fun processScannedQr(qrContent: String): QrAction {
        return QrAction.VerificationChallenge("""{"challenge_id":"challenge-id-abc123"}""")
    }

    override fun processManualEntry(input: String): String {
        return processQrChallengeResult.getOrThrow()
    }

    override fun createAgeProof(
        credentialId: String,
        challengeId: String,
    ): String {
        createAgeProofCallCount++
        return createAgeProofResult.getOrThrow()
    }

    override fun createAgeProofAuto(challengeId: String): String {
        return createAgeProofResult.getOrThrow()
    }

    override fun submitProof(proofJson: String): Boolean {
        submitProofCallCount++
        return submitProofResult.getOrThrow()
    }

    override fun listCredentials(): List<CredentialInfo> {
        return listCredentialsResult.getOrThrow()
    }

    override fun getCredential(credentialId: String): String? {
        return getCredentialResult
    }

    override fun getDiagnosticInfo(): DiagnosticInfo {
        return diagnosticInfoValue
    }

    override fun finalizeAndStoreCredential(
        headerJson: String,
        dobDays: Int,
        rBitsB64: String,
        label: String?,
        credentialType: String,
        nickname: String?,
    ): String {
        finalizeAndStoreCredentialCallCount++
        return finalizeAndStoreCredentialResult.getOrThrow()
    }

    override fun storeCredentialWithLabel(
        credentialJson: String,
        label: String?,
        credentialType: String,
        nickname: String?,
    ): String = "stored-cred-id-002"

    override fun storeCredential(credentialJson: String): String = "stored-cred-id-003"

    override fun importCredential(credentialJson: String): String = "imported-cred-id-001"

    override fun importCredentialWithType(
        credentialJson: String,
        credentialType: String,
        nickname: String?,
    ): String = "imported-cred-id-002"

    override fun deleteCredential(credentialId: String) {}

    override fun deleteSandboxCredentials() {}

    override fun updateCredentialNickname(
        credentialId: String,
        nickname: String?,
    ) {}

    override fun initializeProver(pkBytes: ByteArray) {}

    override fun isBiometricAvailable(): Boolean = true

    override fun emergencyZeroize() {}

    override fun refreshIssuerKeys(jwksJson: String) {}

    override fun setStorageHandle(handle: SecureStorageHandle) {}

    override fun setVerifierBaseUrl(baseUrl: String) {
        _verifierBaseUrl = baseUrl
    }

    override fun getVerifierBaseUrl(): String = _verifierBaseUrl

    override fun getConfig(): WalletConfig =
        WalletConfig(
            autoSelect = true,
            networkTimeout = 30uL,
            cacheProvingKeys = false,
            issuerApiUrl = "https://issuer.example.test",
            verifierApiUrl = "https://verifier.example.test",
            verifierApiKey = null,
            verifierOrigin = null,
            environment = "test",
            enableParallelProver = false,
            maxProverThreads = 1u,
        )

    override fun updateConfig(config: WalletConfig) {}

    override fun getAvailableSlotCount(): UByte = 1u

    override fun hasValidCredential(): Boolean = false

    override fun hasCredentialSecrets(credentialId: String): Boolean = true

    override fun getProvableCredentialsForChallenge(challengeId: String): List<CredentialSuitability> = emptyList()

    override fun getVerificationStatus(): VerificationStatus = VerificationStatus.NotStarted

    override fun cancelVerification(challengeId: String) {}

    override fun cleanupExpiredChallenges(): UInt = 0u

    override fun cleanupExpiredCredentials(): UInt = 0u

    override fun calculateAgeFromDob(dobIso: String): UInt = 25u

    override fun checkNetworkStatus(): NetworkStatus = NetworkStatus(connected = true)

    override fun createProgressTracker(): ProgressTracker {
        error("createProgressTracker not implemented in MockProviiWallet")
    }

    override fun reportProgress(
        tracker: ProgressTracker,
        stage: ProgressStage,
        message: String,
    ) {}

    override fun debugPreflight(
        credentialId: String,
        challengeId: String,
    ): String = """{"status":"ok"}"""

    override fun diagnoseProofFailure(
        credentialId: String,
        challengeId: String,
    ): String = """{"diagnosis":"none"}"""

    override fun fetchChallengeByShortCode(shortCode: String): String = """{"challenge_id":"challenge-id-abc123"}"""

    override fun fetchChallengeDetails(challengeId: String): String = """{"challenge_id":"$challengeId"}"""

    override fun getChallengeDiagnostics(challengeId: String): String = """{"cutoff_days":6570}"""

    override fun handleDeeplink(url: String): DeeplinkAction =
        DeeplinkAction.ScanChallenge("""{"challenge_id":"challenge-id-abc123"}""")

    override fun parseQr(qrContent: String): String = """{"type":"verification_challenge"}"""

    override fun parseQrPayload(qrContent: String): String = """{"type":"verification_challenge"}"""

    override fun validateQr(qrContent: String): Boolean = true
}
