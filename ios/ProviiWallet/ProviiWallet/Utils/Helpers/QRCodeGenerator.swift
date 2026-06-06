// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

/// QR code image generator using CoreImage. Automatically adjusts error correction level
/// based on payload size and supports capacity checks.

class QRCodeGenerator {
    static let shared = QRCodeGenerator()

    private let context = CIContext()

    // QR Code capacity limits (approximate, in bytes)
    private let qrCapacityL = 2953  // Low error correction
    private let qrCapacityM = 2331  // Medium error correction
    private let qrCapacityQ = 1663  // Quartile error correction
    private let qrCapacityH = 1273  // High error correction

    enum ErrorCorrectionLevel {
        case L, M, Q, H

        var ciLevel: String {
            switch self {
            case .L: return "L"
            case .M: return "M"
            case .Q: return "Q"
            case .H: return "H"
            }
        }

        var capacity: Int {
            switch self {
            case .L: return 2953
            case .M: return 2331
            case .Q: return 1663
            case .H: return 1273
            }
        }
    }

    func encode(
        text: String,
        size: CGFloat = 512,
        errorCorrection: ErrorCorrectionLevel = .M
    ) throws -> UIImage {
        let textData = text.data(using: .utf8) ?? Data()
        let textBytes = textData.count

        #if DEBUG
        SecureLogger.shared.debug("Encoding QR: \(textBytes) bytes", redact: false)
        #endif

        // For provii:// URLs, use lower error correction
        let adjustedErrorCorrection: ErrorCorrectionLevel
        if text.hasPrefix("provii://") && textBytes < 500 {
            adjustedErrorCorrection = .L
        } else if textBytes > qrCapacityM {
            #if DEBUG
            SecureLogger.shared.debug("Large QR data (\(textBytes) bytes), using Low error correction", redact: false)
            #endif
            adjustedErrorCorrection = .L
        } else {
            adjustedErrorCorrection = errorCorrection
        }

        guard textBytes <= qrCapacityL else {
            throw QRCodeGeneratorError.dataTooLarge(size: textBytes, max: qrCapacityL)
        }

        let filter = CIFilter.qrCodeGenerator()
        filter.message = textData
        filter.correctionLevel = adjustedErrorCorrection.ciLevel

        guard let outputImage = filter.outputImage else {
            throw QRCodeGeneratorError.generationFailed
        }

        // Scale the image
        let scaleX = size / outputImage.extent.size.width
        let scaleY = size / outputImage.extent.size.height
        let transformedImage = outputImage.transformed(by: CGAffineTransform(scaleX: scaleX, y: scaleY))

        guard let cgImage = context.createCGImage(transformedImage, from: transformedImage.extent) else {
            throw QRCodeGeneratorError.generationFailed
        }

        return UIImage(cgImage: cgImage)
    }

    func willFitInQR(_ text: String) -> Bool {
        let textData = text.data(using: .utf8) ?? Data()
        return textData.count <= qrCapacityL
    }

}

enum QRCodeGeneratorError: LocalizedError {
    case dataTooLarge(size: Int, max: Int)
    case generationFailed

    var errorDescription: String? {
        switch self {
        case .dataTooLarge(let size, let max):
            return String(format: LocalizedString.errorQrDataTooLarge.localized, size, max)
        case .generationFailed:
            return LocalizedString.errorQrGenerationFailed.localized
        }
    }
}
