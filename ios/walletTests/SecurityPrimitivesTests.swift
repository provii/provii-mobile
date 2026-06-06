// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import XCTest
@testable import ProviiWallet

// MARK: - ConstantTimeCompare

final class ConstantTimeCompareTests: XCTestCase {

    func testEqualDataReturnsTrue() {
        let a = Data([0x01, 0x02, 0x03, 0x04])
        let b = Data([0x01, 0x02, 0x03, 0x04])
        XCTAssertTrue(constantTimeCompare(a, b), "Equal Data buffers must compare as equal")
    }

    func testDifferentDataReturnsFalse() {
        let a = Data([0xAA, 0xBB, 0xCC, 0xDD])
        let b = Data([0xAA, 0xBB, 0xCC, 0x00])
        XCTAssertFalse(constantTimeCompare(a, b), "Data differing in final byte must compare as unequal")
    }

    func testMismatchedLengthReturnsFalse() {
        let a = Data([0x01, 0x02, 0x03])
        let b = Data([0x01, 0x02, 0x03, 0x04])
        XCTAssertFalse(constantTimeCompare(a, b), "Data of different lengths must compare as unequal")
    }

    func testEmptyDataReturnsTrue() {
        let a = Data()
        let b = Data()
        XCTAssertTrue(constantTimeCompare(a, b), "Two empty Data values must compare as equal")
    }
}

// MARK: - SecureString

final class SecureStringTests: XCTestCase {

    func testWithValueReturnsOriginalString() {
        let original = "super-secret-token-abc"
        let secure = SecureString(original)
        let retrieved = secure.withValue { $0 }
        XCTAssertEqual(retrieved, original, "withValue must return the original plaintext string")
    }

    func testDataMatchesUtf8Bytes() {
        let original = "hello"
        let secure = SecureString(original)
        let expectedBytes = Array("hello".utf8)
        XCTAssertEqual(Array(secure.data), expectedBytes, "data must contain the UTF-8 bytes of the original string")
    }

    func testClearZeroesBuffer() {
        let secure = SecureString("sensitive-pin-1234")
        secure.clear()
        // After clear(), data returns an empty buffer
        XCTAssertTrue(secure.data.isEmpty, "data must be empty after clear()")
    }

    func testConstantTimeComparisonOfEqualSecureStrings() {
        let a = SecureString("token-value-xyz")
        let b = SecureString("token-value-xyz")
        XCTAssertTrue(constantTimeCompare(a, b), "Identical SecureStrings must compare as equal via constantTimeCompare")

        let c = SecureString("token-value-xyz")
        let d = SecureString("token-value-XYZ")
        XCTAssertFalse(constantTimeCompare(c, d), "Different SecureStrings must compare as unequal via constantTimeCompare")
    }
}

// MARK: - SensitiveDataHolder

final class SensitiveDataHolderTests: XCTestCase {

    func testDataRoundTrip() {
        let original = Data([0x10, 0x20, 0x30, 0x40, 0x50])
        let holder = SensitiveDataHolder(original)
        XCTAssertEqual(holder.data, original, "data must return the original bytes unchanged")
    }

    func testCloseInvalidatesHolder() {
        let holder = SensitiveDataHolder(Data([0xDE, 0xAD, 0xBE, 0xEF]))
        XCTAssertTrue(holder.isValid, "holder must be valid before close()")
        holder.close()
        XCTAssertFalse(holder.isValid, "holder must be invalid after close()")
    }

    func testWithDataStaticHelper() {
        let source = Data([0x01, 0x02, 0x03, 0x04, 0x05])
        var capturedBytes: [UInt8] = []
        SensitiveDataHolder.withData(source) { data in
            capturedBytes = Array(data)
        }
        XCTAssertEqual(capturedBytes, [0x01, 0x02, 0x03, 0x04, 0x05],
                       "withData must provide the original bytes inside the closure")
    }

    func testFromCopyPreservesSourceData() {
        let source = Data([0xAA, 0xBB, 0xCC, 0xDD])
        let holder = SensitiveDataHolder.fromCopy(source)
        // fromCopy leaves the source intact and gives a valid holder
        XCTAssertEqual(holder.data, source, "fromCopy must produce a holder with the same bytes as the source")
        XCTAssertTrue(holder.isValid, "holder produced by fromCopy must be valid")
    }
}

// MARK: - RateLimiter

final class RateLimiterTests: XCTestCase {

    func testAllowsAttemptsWithinLimit() {
        // maxAttempts=3, windowSeconds=60, lockoutSeconds=120
        let limiter = RateLimiter(maxAttempts: 3, windowSeconds: 60, lockoutSeconds: 120)
        let id = "test-allows-\(UUID().uuidString)"

        XCTAssertTrue(limiter.isAllowed(identifier: id), "First attempt must be allowed")
        limiter.recordAttempt(identifier: id, success: false)
        XCTAssertTrue(limiter.isAllowed(identifier: id), "Second attempt must be allowed after one failure")
        limiter.recordAttempt(identifier: id, success: false)
        XCTAssertTrue(limiter.isAllowed(identifier: id), "Third attempt must be allowed after two failures")
    }

    func testBlocksAfterMaxFailures() {
        let limiter = RateLimiter(maxAttempts: 2, windowSeconds: 60, lockoutSeconds: 120)
        let id = "test-blocks-\(UUID().uuidString)"

        limiter.recordAttempt(identifier: id, success: false)
        limiter.recordAttempt(identifier: id, success: false)

        XCTAssertFalse(limiter.isAllowed(identifier: id), "Identifier must be blocked after reaching maxAttempts failures")
    }

    func testResetsOnSuccess() {
        let limiter = RateLimiter(maxAttempts: 2, windowSeconds: 60, lockoutSeconds: 120)
        let id = "test-reset-success-\(UUID().uuidString)"

        limiter.recordAttempt(identifier: id, success: false)
        limiter.recordAttempt(identifier: id, success: true)

        XCTAssertTrue(limiter.isAllowed(identifier: id), "Identifier must be allowed again after a successful attempt")
        XCTAssertEqual(limiter.remainingAttempts(identifier: id), 2,
                       "Remaining attempts must be reset to maxAttempts after success")
    }

    func testResetClearsState() {
        let limiter = RateLimiter(maxAttempts: 2, windowSeconds: 60, lockoutSeconds: 120)
        let id = "test-reset-method-\(UUID().uuidString)"

        limiter.recordAttempt(identifier: id, success: false)
        limiter.recordAttempt(identifier: id, success: false)
        XCTAssertFalse(limiter.isAllowed(identifier: id), "Identifier must be blocked before reset")

        limiter.reset(identifier: id)

        XCTAssertTrue(limiter.isAllowed(identifier: id), "Identifier must be allowed again after reset()")
        XCTAssertNil(limiter.lockoutTimeRemaining(identifier: id),
                     "Lockout time remaining must be nil after reset()")
    }
}
