// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.security

import android.util.Base64
import java.security.SecureRandom
import java.util.Arrays
import javax.crypto.Cipher
import javax.crypto.spec.GCMParameterSpec
import javax.crypto.spec.SecretKeySpec

/**
 * Low-level cryptographic primitives used across the wallet application. Provides AES-256-GCM
 * encryption and decryption, secure random key generation, base64url encoding, and memory-safe
 * zeroisation helpers for sensitive byte and char arrays.
 */
object CryptoUtils {
    private const val GCM_TAG_LEN_BITS = 128
    private const val GCM_IV_LEN_BYTES = 12
    private val secureRandom = SecureRandom()

    /**
     * MASVS-CODE-2: Memory Safety
     *
     * Extension function to securely zero out sensitive data from memory.
     * This helps prevent sensitive information from lingering in memory
     * where it could be accessed by memory dumps or other attacks.
     */
    fun ByteArray.zeroize() {
        Arrays.fill(this, 0.toByte())
    }

    /**
     * MASVS-CODE-2: Memory Safety
     *
     * Extension function to securely zero out char arrays (for passwords).
     */
    fun CharArray.zeroize() {
        Arrays.fill(this, '\u0000')
    }

    /**
     * MASVS-CODE-2: Memory Safety
     *
     * Securely zero out multiple byte arrays at once.
     */
    fun zeroizeAll(vararg arrays: ByteArray) {
        arrays.forEach { it.zeroize() }
    }

    /**
     * MASVS-CODE-2: Memory Safety
     *
     * Execute a block with sensitive data and ensure cleanup afterward.
     * The sensitive data will be zeroised regardless of success or failure.
     */
    inline fun <T> withSensitiveData(
        data: ByteArray,
        block: (ByteArray) -> T,
    ): T {
        return try {
            block(data)
        } finally {
            data.zeroize()
        }
    }

    /**
     * MASVS-CODE-2: Memory Safety
     *
     * Execute a block with multiple sensitive byte arrays and ensure cleanup afterward.
     */
    inline fun <T> withMultipleSensitiveData(
        vararg data: ByteArray,
        block: () -> T,
    ): T {
        return try {
            block()
        } finally {
            data.forEach { it.zeroize() }
        }
    }

    fun randomKey32(): ByteArray {
        val b = ByteArray(32) // AES-256
        secureRandom.nextBytes(b)
        return b
    }

    /**
     * Encrypts [plaintext] with AES-256-GCM using the supplied [key].
     *
     * Returns the concatenation of the 12-byte IV and the ciphertext (with 16-byte GCM tag).
     *
     * **Memory lifecycle: caller's responsibility.** This function does NOT zeroise [plaintext]
     * or [key] after use. Callers that own sensitive buffers must zeroise them after the call
     * returns (or use [withSensitiveData] to do so automatically). Zeroing inside this function
     * was removed because it silently mutated caller-owned arrays, causing hard-to-diagnose
     * data corruption when callers reused the same buffer.
     *
     * @param plaintext The data to encrypt. Not modified by this function.
     * @param key A 32-byte AES-256 key. Not modified by this function. Zeroise after use.
     * @return iv || ciphertext || tag (IV is 12 bytes, tag is 16 bytes).
     */
    fun encryptAesGcm(
        plaintext: ByteArray,
        key: ByteArray,
    ): ByteArray {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"))
        val iv = cipher.iv // 12 bytes
        val ct = cipher.doFinal(plaintext) // ciphertext || tag(16)
        return iv + ct
    }

    fun decryptAesGcm(
        ivPlusCt: ByteArray,
        key: ByteArray,
    ): SensitiveDataHolder {
        require(ivPlusCt.size > GCM_IV_LEN_BYTES) { "ciphertext too short" }
        val iv = ivPlusCt.copyOfRange(0, GCM_IV_LEN_BYTES)
        val ct = ivPlusCt.copyOfRange(GCM_IV_LEN_BYTES, ivPlusCt.size)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        val spec = GCMParameterSpec(GCM_TAG_LEN_BITS, iv)
        cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), spec)
        val result = cipher.doFinal(ct)

        // Zero out intermediate buffers from memory after decryption
        Arrays.fill(iv, 0.toByte())
        Arrays.fill(ct, 0.toByte())

        return SensitiveDataHolder.takeOwnership(result)
    }

    fun b64UrlEncode(bytes: ByteArray): String =
        Base64.encodeToString(bytes, Base64.NO_WRAP or Base64.NO_PADDING or Base64.URL_SAFE)

    private val BASE64URL_REGEX = Regex("^[A-Za-z0-9_-]*$")

    fun b64UrlDecode(s: String): ByteArray {
        require(s.isNotEmpty()) { "base64url input must not be empty" }
        require(s.matches(BASE64URL_REGEX)) { "base64url input contains invalid characters" }
        return Base64.decode(s, Base64.NO_WRAP or Base64.NO_PADDING or Base64.URL_SAFE)
    }
}
