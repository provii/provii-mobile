// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import XCTest
@testable import ProviiWallet

final class HexExtensionTests: XCTestCase {

    // MARK: - String.hexToData

    func testHexToDataSimple() {
        let data = "0102ff".hexToData()
        XCTAssertEqual(data, Data([0x01, 0x02, 0xFF]))
    }

    func testHexToDataEmpty() {
        let data = "".hexToData()
        XCTAssertEqual(data, Data())
    }

    func testHexToDataOddLengthReturnsNil() {
        let data = "abc".hexToData()
        XCTAssertNil(data, "Odd-length hex string must return nil")
    }

    func testHexToDataInvalidCharsReturnsNil() {
        let data = "xyz0".hexToData()
        XCTAssertNil(data, "Non-hex characters must return nil")
    }

    func testHexToDataWithSpaces() {
        let data = "01 02 03".hexToData()
        XCTAssertEqual(data, Data([0x01, 0x02, 0x03]), "Spaces must be stripped before parsing")
    }

    // MARK: - Data.hexString

    func testDataHexString() {
        let hex = Data([0x00, 0xAB, 0xFF]).hexString()
        XCTAssertEqual(hex, "00abff")
    }

    func testDataHexStringEmpty() {
        let hex = Data().hexString()
        XCTAssertEqual(hex, "")
    }

    func testHexRoundTrip() {
        let original = Data([0xDE, 0xAD, 0xBE, 0xEF])
        let hex = original.hexString()
        let decoded = hex.hexToData()
        XCTAssertEqual(decoded, original, "Hex round-trip must preserve bytes")
    }
}
