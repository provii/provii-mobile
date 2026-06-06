// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust
package app.provii.wallet.data

import android.graphics.Bitmap
import com.google.zxing.BarcodeFormat
import com.google.zxing.EncodeHintType
import com.google.zxing.MultiFormatWriter
import com.google.zxing.WriterException
import com.google.zxing.common.BitMatrix
import com.google.zxing.qrcode.decoder.ErrorCorrectionLevel
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton

/**
 * Generates QR codes from text payloads using the ZXing library. Automatically adjusts
 * error correction levels based on payload size: short `provii://` URLs use Low
 * correction for smaller codes, while larger payloads fall back from Medium to Low when
 * they exceed capacity. Enforces a hard limit at the Low correction capacity ceiling
 * (2,953 bytes) and throws if the data cannot fit.
 */
@Singleton
class QrCoder
    @Inject
    constructor() {
        companion object {
            // QR Code capacity limits (approximate, in bytes)
            private const val QR_CAPACITY_L = 2953 // Low error correction
            private const val QR_CAPACITY_M = 2331 // Medium error correction
            private const val QR_CAPACITY_Q = 1663 // Quartile error correction
            private const val QR_CAPACITY_H = 1273 // High error correction
        }

        /**
         * Encode text to QR code with automatic optimisation for provii:// URLs.
         */
        @JvmOverloads
        fun encode(
            text: String,
            sizePx: Int = 512,
            errorCorrection: ErrorCorrectionLevel = ErrorCorrectionLevel.M,
        ): Bitmap {
            val textBytes = text.toByteArray(Charsets.UTF_8)
            Timber.d("Encoding QR: ${textBytes.size} bytes, scheme: ${text.substringBefore("://")}")

            // For provii:// URLs, we can use lower error correction since they're shorter
            val adjustedErrorCorrection =
                when {
                    text.startsWith("provii://") && textBytes.size < 500 -> ErrorCorrectionLevel.L
                    textBytes.size > QR_CAPACITY_M -> {
                        Timber.w("QR data large (${textBytes.size} bytes), using Low error correction")
                        ErrorCorrectionLevel.L
                    }
                    else -> errorCorrection
                }

            if (textBytes.size > QR_CAPACITY_L) {
                throw IllegalArgumentException(
                    "QR data too large: ${textBytes.size} bytes exceeds maximum of $QR_CAPACITY_L",
                )
            }

            return try {
                val hints =
                    mapOf(
                        EncodeHintType.ERROR_CORRECTION to adjustedErrorCorrection,
                        EncodeHintType.CHARACTER_SET to "UTF-8",
                        EncodeHintType.MARGIN to 1, // Minimal margin
                    )

                val bitMatrix =
                    MultiFormatWriter().encode(
                        text,
                        BarcodeFormat.QR_CODE,
                        sizePx,
                        sizePx,
                        hints,
                    )

                createBitmap(bitMatrix, sizePx)
            } catch (e: WriterException) {
                Timber.e(e, "Failed to encode QR code")
                when {
                    e.message?.contains("Data too big") == true -> {
                        throw IllegalArgumentException("QR data is too large (${textBytes.size} bytes)", e)
                    }
                    else -> throw e
                }
            }
        }

        /**
         * Create a bitmap from a BitMatrix
         */
        private fun createBitmap(
            bitMatrix: BitMatrix,
            sizePx: Int,
        ): Bitmap {
            val pixels = IntArray(sizePx * sizePx)

            for (y in 0 until sizePx) {
                val offset = y * sizePx
                for (x in 0 until sizePx) {
                    pixels[offset + x] =
                        if (bitMatrix[x, y]) {
                            0xFF000000.toInt() // Black
                        } else {
                            0xFFFFFFFF.toInt() // White
                        }
                }
            }

            return Bitmap.createBitmap(pixels, sizePx, sizePx, Bitmap.Config.ARGB_8888)
        }

        /**
         * Estimate if a provii:// URL will fit in QR
         */
        fun willFitInQr(text: String): Boolean {
            val textBytes = text.toByteArray(Charsets.UTF_8)
            // For provii:// URLs, we typically use Low error correction
            return textBytes.size <= QR_CAPACITY_L
        }
    }
