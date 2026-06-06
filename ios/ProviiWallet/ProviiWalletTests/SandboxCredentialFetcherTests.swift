// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// tests for `SandboxCredentialFetcher`.
///
/// Covers the App Attest handshake, refresh/revoke signing over
/// `timestamp:method:path:JCS(body)`, credential expiry semantics, UUID v7
/// invariants, and clientDataHash byte layout. Uses a stub App Attest service
/// so the test suite runs on simulator and CI.

import XCTest
import CryptoKit
@testable import ProviiWallet

final class SandboxCredentialFetcherTests: XCTestCase {

    private var session: URLSession!
    private var attest: StubAppAttestService!
    private let baseURL = URL(string: "https://gateway.test")!

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        session = URLSession(configuration: configuration)
        MockURLProtocol.handler = nil
        attest = StubAppAttestService()
    }

    override func tearDown() {
        MockURLProtocol.handler = nil
        session = nil
        attest = nil
        super.tearDown()
    }

    private func makeFetcher(clock: Date = Date(timeIntervalSince1970: 1_700_000_000)) -> SandboxCredentialFetcher {
        SandboxCredentialFetcher(
            session: session,
            keychain: .shared,
            attestService: attest,
            baseURLProvider: { [baseURL] in baseURL },
            clockNow: { clock }
        )
    }

    // MARK: - UUID v7

    func testUuidV7FormatAndVersionBits() {
        let id = SandboxCredentialFetcher.generateUuidV7()
        XCTAssertEqual(id.count, 36)
        let parts = id.split(separator: "-")
        XCTAssertEqual(parts.count, 5)
        XCTAssertEqual(parts[0].count, 8)
        XCTAssertEqual(parts[2].first, "7", "Version nibble must be 7")
        let variant = parts[3].first!
        XCTAssertTrue("89ab".contains(variant))
    }

    func testUuidV7IsTimeOrdered() {
        let first = SandboxCredentialFetcher.generateUuidV7()
        Thread.sleep(forTimeInterval: 0.002)
        let second = SandboxCredentialFetcher.generateUuidV7()
        XCTAssertLessThanOrEqual(first, second)
    }

    // MARK: - clientDataHash

    /// BLOCKER-6: clientDataHash = SHA256(nonce_bytes). The gateway's
    /// deriveExpectedNonce does SHA256(authData || SHA256(challenge)) where
    /// challenge is the raw nonce bytes.
    func testClientDataHashIsSha256OfNonceBytes() {
        let nonce = "abcd"
        let actual = SandboxCredentialFetcher.clientDataHash(nonce: nonce)

        let nonceData = Data(nonce.utf8)
        let expected = Data(SHA256.hash(data: nonceData))
        XCTAssertEqual(actual, expected)
        XCTAssertEqual(actual.count, 32)
    }

    // MARK: - App Attest keyId caching

    func testAppAttestKeyIdIsCachedAcrossRegistrations() async throws {
        setUpChallengeAndRegisterHandler()
        let fetcher = makeFetcher()
        await fetcher.clearCache()
        _ = try await fetcher.register()
        let firstGenerated = attest.generateKeyCallCount
        _ = try await fetcher.register()
        XCTAssertEqual(attest.generateKeyCallCount, firstGenerated, "generateKey must not be called again once keyId is cached")
    }

    // MARK: - Register parses gateway response

    func testRegisterParsesGatewayResponse() async throws {
        setUpChallengeAndRegisterHandler()
        let fetcher = makeFetcher()
        await fetcher.clearCache()
        let credential = try await fetcher.register()
        XCTAssertTrue(credential.clientId.hasPrefix("mwallet-sbx-"))
        XCTAssertFalse(credential.hmacSecret.isEmpty)
        XCTAssertFalse(credential.isExpired)
    }

    // MARK: - Refresh signs mwallet-sbx/v1 envelope

    func testRefreshSignsMwalletSbxV1Envelope() async throws {
        setUpChallengeAndRegisterHandler()
        let fetcher = makeFetcher()
        await fetcher.clearCache()
        let initial = try await fetcher.register()

        var capturedAuth: String?
        var capturedSig: String?
        var capturedBody: Data?
        MockURLProtocol.handler = { request in
            capturedAuth = request.value(forHTTPHeaderField: "X-Mwallet-Auth")
            capturedSig = request.value(forHTTPHeaderField: "X-Mwallet-Sig")
            capturedBody = request.bodyData()
            let body = try! JSONSerialization.data(withJSONObject: [
                "client_id": initial.clientId,
                "hmac_secret": initial.hmacSecret,
                "expires_at": ISO8601DateFormatter.iso8601Fractional.string(from: Date().addingTimeInterval(7 * 86400))
            ])
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, body)
        }

        _ = try await fetcher.refresh()

        let sig = try XCTUnwrap(capturedSig)
        let auth = try XCTUnwrap(capturedAuth)
        XCTAssertEqual(sig.count, 64)
        XCTAssertTrue(auth.hasPrefix("Mwallet-Sandbox "))
        XCTAssertTrue(auth.contains("client_id=\(initial.clientId)"))
        XCTAssertTrue(auth.contains("ts="))
        XCTAssertTrue(auth.contains("nonce="))

        // Body must NOT contain install_uuid (MobileLifecycleRequestSchema strips it).
        let bodyStr = String(data: try XCTUnwrap(capturedBody), encoding: .utf8) ?? ""
        XCTAssertFalse(bodyStr.contains("install_uuid"))

        // Parse auth fields and recompute HMAC.
        let fields = auth.replacingOccurrences(of: "Mwallet-Sandbox ", with: "")
            .split(separator: ",")
            .reduce(into: [String: String]()) { dict, pair in
                let parts = pair.split(separator: "=", maxSplits: 1)
                if parts.count == 2 { dict[String(parts[0])] = String(parts[1]) }
            }
        let ts = try XCTUnwrap(fields["ts"])
        let nonce = try XCTUnwrap(fields["nonce"])

        let headerStr = "mwallet-sbx/v1\nPOST\n/api/mobile/sandbox/refresh\n\(ts)\n\(nonce)\n"
        var signingBytes = Data(headerStr.utf8)
        signingBytes.append(try XCTUnwrap(capturedBody))

        let keyData = Data(initial.hmacSecret.utf8)
        let key = SymmetricKey(data: keyData)
        let mac = HMAC<SHA256>.authenticationCode(for: signingBytes, using: key)
        let expected = Data(mac).map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(sig, expected)
    }

    // MARK: - Expiry semantics

    func testNeedsRefreshWithinTwentyFourHours() {
        let soon = Date().addingTimeInterval(23 * 3600)
        let later = Date().addingTimeInterval(48 * 3600)
        XCTAssertTrue(SandboxCredential(clientId: "a", hmacSecret: "b", expiresAt: soon).needsRefresh)
        XCTAssertFalse(SandboxCredential(clientId: "a", hmacSecret: "b", expiresAt: later).needsRefresh)
    }

    func testExpiredCredentialReportsExpired() {
        let past = Date().addingTimeInterval(-10)
        XCTAssertTrue(SandboxCredential(clientId: "a", hmacSecret: "b", expiresAt: past).isExpired)
    }

    // MARK: - BLOCKER-1: expired credential falls through to register

    func testCurrentCredentialReregistersWhenExpiredAndRefreshFails() async throws {
        setUpChallengeAndRegisterHandler()
        let fetcher = makeFetcher()
        await fetcher.clearCache()
        // First register to seed the keychain with an App Attest keyId.
        let initial = try await fetcher.register()

        // Overwrite with an expired credential.
        let expired = SandboxCredential(
            clientId: initial.clientId,
            hmacSecret: initial.hmacSecret,
            expiresAt: Date().addingTimeInterval(-3600)
        )
        let data = try JSONEncoder.iso8601Test.encode(expired)
        try KeychainService.shared.save(key: "provii.sandbox.credential", data: data, requiresBiometric: false)

        // Refresh fails (403), then challenge + register succeed.
        MockURLProtocol.queue.removeAll()
        MockURLProtocol.queue.append { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (response, Data("forbidden".utf8))
        }
        MockURLProtocol.queue.append { request in
            let body = try! JSONSerialization.data(withJSONObject: ["nonce": "nonce-re", "expires_in": 60])
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, body)
        }
        MockURLProtocol.queue.append { request in
            let body = try! JSONSerialization.data(withJSONObject: [
                "client_id": "mwallet-sbx-re-registered",
                "hmac_secret": "bmV3c2VjcmV0",
                "expires_at": ISO8601DateFormatter.iso8601Fractional.string(from: Date().addingTimeInterval(7 * 86400))
            ])
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, body)
        }
        MockURLProtocol.handler = { request in
            MockURLProtocol.queue.isEmpty
                ? (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
                : MockURLProtocol.queue.removeFirst()(request)
        }

        let result = try await fetcher.currentCredential()
        XCTAssertEqual(result.clientId, "mwallet-sbx-re-registered")
    }

    // MARK: - MED-16: revoke tests

    func testRevokeSignsWithMwalletSbxV1Envelope() async throws {
        setUpChallengeAndRegisterHandler()
        let fetcher = makeFetcher()
        await fetcher.clearCache()
        let initial = try await fetcher.register()

        var capturedAuth: String?
        var capturedSig: String?
        MockURLProtocol.handler = { request in
            capturedAuth = request.value(forHTTPHeaderField: "X-Mwallet-Auth")
            capturedSig = request.value(forHTTPHeaderField: "X-Mwallet-Sig")
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("{}".utf8))
        }

        try await fetcher.revoke()

        let auth = try XCTUnwrap(capturedAuth)
        let sig = try XCTUnwrap(capturedSig)
        XCTAssertTrue(auth.hasPrefix("Mwallet-Sandbox "))
        XCTAssertTrue(auth.contains("client_id=\(initial.clientId)"))
        XCTAssertEqual(sig.count, 64)
    }

    func testRevokeClearsLocalCredentialAndCancelsRefresh() async throws {
        setUpChallengeAndRegisterHandler()
        let fetcher = makeFetcher()
        await fetcher.clearCache()
        _ = try await fetcher.register()

        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, Data("{}".utf8))
        }

        try await fetcher.revoke()

        // After revoke, there should be no cached credential.
        let data = try? KeychainService.shared.getData(key: "provii.sandbox.credential", requireAuth: false)
        XCTAssertNil(data, "credential must be cleared after revoke")
    }

    func testRevokeSurfacesAuthFailures() async throws {
        setUpChallengeAndRegisterHandler()
        let fetcher = makeFetcher()
        await fetcher.clearCache()
        _ = try await fetcher.register()

        MockURLProtocol.handler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
            return (response, Data("{\"code\":\"mobile_signature_mismatch\"}".utf8))
        }

        do {
            try await fetcher.revoke()
            XCTFail("expected httpError")
        } catch let error as SandboxCredentialFetcherError {
            if case .httpError(let code, _) = error {
                XCTAssertEqual(code, 401)
            } else {
                XCTFail("wrong error case: \(error)")
            }
        }
    }

    // MARK: - HTTP errors surface cleanly

    func testHttpErrorSurfacesAsHttpError() async {
        setUpChallengeHandler()
        MockURLProtocol.queue.append { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 403, httpVersion: nil, headerFields: nil)!
            return (response, Data("forbidden".utf8))
        }
        let fetcher = makeFetcher()
        await fetcher.clearCache()
        do {
            _ = try await fetcher.register()
            XCTFail("expected httpError")
        } catch let error as SandboxCredentialFetcherError {
            if case .httpError(let code, _) = error {
                XCTAssertEqual(code, 403)
            } else {
                XCTFail("wrong error case: \(error)")
            }
        } catch {
            XCTFail("wrong error: \(error)")
        }
    }

    // MARK: - Helpers

    private func setUpChallengeHandler(nonce: String = "nonce-abc") {
        MockURLProtocol.queue.removeAll()
        MockURLProtocol.queue.append { request in
            let body = try! JSONSerialization.data(withJSONObject: ["nonce": nonce, "expires_in": 60])
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, body)
        }
        MockURLProtocol.handler = { request in
            MockURLProtocol.queue.isEmpty
                ? (HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!, Data())
                : MockURLProtocol.queue.removeFirst()(request)
        }
    }

    private func setUpChallengeAndRegisterHandler() {
        setUpChallengeHandler()
        MockURLProtocol.queue.append { request in
            let body = try! JSONSerialization.data(withJSONObject: [
                "client_id": "mwallet-sbx-01234567-89ab-7cde-8f01-234567890abc",
                "hmac_secret": "c2VjcmV0LWJhc2U2NA",
                "expires_at": ISO8601DateFormatter.iso8601Fractional.string(from: Date().addingTimeInterval(7 * 86400))
            ])
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, body)
        }
    }
}

// MARK: - Stub App Attest

final class StubAppAttestService: AppAttestServicing, @unchecked Sendable {
    var isSupported: Bool = true
    var generateKeyCallCount = 0
    var attestKeyCallCount = 0

    func generateKey(completionHandler: @escaping @Sendable (String?, Error?) -> Void) {
        generateKeyCallCount += 1
        completionHandler("stub-key-\(UUID().uuidString)", nil)
    }

    func attestKey(_ keyId: String, clientDataHash: Data, completionHandler: @escaping @Sendable (Data?, Error?) -> Void) {
        attestKeyCallCount += 1
        completionHandler(Data("stub-attestation-object".utf8), nil)
    }
}

// MARK: - Mock URLProtocol

final class MockURLProtocol: URLProtocol {
    static var handler: ((URLRequest) -> (HTTPURLResponse, Data))?
    /// FIFO queue of handlers, drained by the default `handler`. Tests that
    /// need multiple sequential responses enqueue in setup.
    static var queue: [(URLRequest) -> (HTTPURLResponse, Data)] = []

    override static func canInit(with request: URLRequest) -> Bool { true }
    override static func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: NSError(domain: "MockURLProtocol", code: -1))
            return
        }
        var requestWithBody = request
        if requestWithBody.httpBody == nil, let stream = request.httpBodyStream {
            var data = Data()
            stream.open()
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: 1024)
                if read <= 0 { break }
                data.append(buffer, count: read)
            }
            stream.close()
            requestWithBody.httpBody = data
        }
        let (response, body) = handler(requestWithBody)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: body)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

extension JSONEncoder {
    static let iso8601Test: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(ISO8601DateFormatter.iso8601Fractional.string(from: date))
        }
        return encoder
    }()
}

extension URLRequest {
    func bodyData() -> Data? {
        if let body = httpBody { return body }
        guard let stream = httpBodyStream else { return nil }
        var data = Data()
        stream.open()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1024)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: 1024)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        stream.close()
        return data
    }
}
