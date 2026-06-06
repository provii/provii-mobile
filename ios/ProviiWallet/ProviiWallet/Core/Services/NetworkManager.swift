// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

/// Network connectivity monitor and HTTP client for the wallet app.
///
/// Uses `NWPathMonitor` to track connectivity state (WiFi, cellular, ethernet)
/// and publishes changes via Combine. Provides GET and POST helpers with
/// structured error handling. Does NOT implement certificate pinning per
/// project rules.

import Foundation
import Network
import Combine
import SystemConfiguration
@MainActor
class NetworkManager: ObservableObject {
    static let shared = NetworkManager()

    // MARK: - Published Properties

    @Published private(set) var isConnected = false
    @Published private(set) var connectionType: ConnectionType = .none
    @Published private(set) var isExpensive = false
    @Published private(set) var isConstrained = false

    // MARK: - Private Properties

    private var monitor: NWPathMonitor?
    private let queue = DispatchQueue(label: "app.provii.wallet.networkmonitor")
    private var config: NetworkConfiguration?
    private var isMonitoring = false
    private var _session: URLSession?
    private var session: URLSession {
        if let existing = _session { return existing }
        let s = URLSession(configuration: buildConfiguration())
        _session = s
        return s
    }

    // MARK: - Types

    enum ConnectionType: String {
        case wifi = "WiFi"
        case cellular = "Cellular"
        case ethernet = "Ethernet"
        case other = "Other"
        case none = "None"
    }

    // MARK: - Initialization

    private init() {
        startMonitoring()
    }

    deinit {
        monitor?.cancel()
    }

    // MARK: - Configuration

    func configure(with config: NetworkConfiguration) {
        self.config = config
        // Invalidate stored session so it picks up the new configuration on next use.
        _session = nil
    }

    // MARK: - Network Monitoring

    func startMonitoring() {
        guard !isMonitoring else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.updateNetworkStatus(path)
            }
        }
        monitor.start(queue: queue)
        self.monitor = monitor
        isMonitoring = true
    }

    func stopMonitoring() {
        guard isMonitoring else { return }
        monitor?.cancel()
        monitor = nil
        isMonitoring = false
    }

    private func updateNetworkStatus(_ path: NWPath) {
        isConnected = path.status == .satisfied
        isExpensive = path.isExpensive
        isConstrained = path.isConstrained

        // Determine connection type
        if path.usesInterfaceType(.wifi) {
            connectionType = .wifi
        } else if path.usesInterfaceType(.cellular) {
            connectionType = .cellular
        } else if path.usesInterfaceType(.wiredEthernet) {
            connectionType = .ethernet
        } else if path.status == .satisfied {
            connectionType = .other
        } else {
            connectionType = .none
        }

        #if DEBUG
        SecureLogger.shared.debug("NetworkManager Status: \(isConnected ? "Connected" : "Disconnected"), Type: \(connectionType.rawValue)", redact: false)
        #endif
    }

    // MARK: - Public Methods

    /**
     * Check if network is currently available
     */
    func isNetworkAvailable() -> Bool {
        return isConnected
    }

    /**
     * Get current connection type as string
     */
    func getConnectionType() -> String {
        return connectionType.rawValue
    }

    /**
     * Check if current connection is expensive (e.g., cellular data)
     */
    func isConnectionExpensive() -> Bool {
        return isExpensive
    }

    /**
     * Check if current connection is constrained (e.g., low data mode)
     */
    func isConnectionConstrained() -> Bool {
        return isConstrained
    }

    /**
     * Perform a simple reachability check to a specific host
     */
    func checkReachability(to host: String = "www.google.com") -> Bool {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout.size(ofValue: zeroAddress))
        zeroAddress.sin_family = sa_family_t(AF_INET)

        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) { zeroSockAddress in
                SCNetworkReachabilityCreateWithAddress(nil, zeroSockAddress)
            }
        }) else {
            return false
        }

        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return false
        }

        let isReachable = flags.contains(.reachable)
        let needsConnection = flags.contains(.connectionRequired)

        return (isReachable && !needsConnection)
    }

    /**
     * Wait for network connection with timeout
     */
    func waitForConnection(timeout: TimeInterval = 10) async -> Bool {
        if isConnected { return true }

        let startTime = Date()

        while Date().timeIntervalSince(startTime) < timeout {
            if isConnected { return true }
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        return isConnected
    }

    // MARK: - API Request Helpers

    private func buildConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = config?.timeout ?? 30
        configuration.timeoutIntervalForResource = config?.timeout ?? 30
        configuration.waitsForConnectivity = true
        configuration.allowsCellularAccess = true
        configuration.allowsExpensiveNetworkAccess = true
        configuration.allowsConstrainedNetworkAccess = true
        return configuration
    }

    /**
     * Perform GET request with error handling
     */
    func get(from url: URL) async throws -> (Data, URLResponse) {
        guard isConnected else {
            throw NetworkError.noConnection
        }

        do {
            let (data, response) = try await session.data(from: url)
            try validateHTTPResponse(response)
            return (data, response)
        } catch let error as NetworkError {
            throw error
        } catch {
            throw mapTransportError(error)
        }
    }

    /**
     * Perform POST request with JSON body
     */
    func post(to url: URL, body: Data, headers: [String: String] = [:]) async throws -> (Data, URLResponse) {
        guard isConnected else {
            throw NetworkError.noConnection
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Add custom headers
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (data, response) = try await session.data(for: request)
            try validateHTTPResponse(response)
            return (data, response)
        } catch let error as NetworkError {
            throw error
        } catch {
            throw mapTransportError(error)
        }
    }

    // MARK: - Response Validation

    private func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        switch httpResponse.statusCode {
        case 200...299:
            return
        case 401:
            throw NetworkError.unauthorized
        case 403:
            throw NetworkError.forbidden
        case 404:
            throw NetworkError.notFound
        case 500...599:
            throw NetworkError.serverError(code: httpResponse.statusCode)
        default:
            throw NetworkError.httpError(code: httpResponse.statusCode)
        }
    }

    private func mapTransportError(_ error: Error) -> NetworkError {
        if (error as NSError).code == NSURLErrorTimedOut {
            return NetworkError.timeout
        }
        return NetworkError.requestFailed(error)
    }
}

// MARK: - Network Error Types

enum NetworkError: LocalizedError {
    case noConnection
    case timeout
    case unauthorized
    case forbidden
    case notFound
    case serverError(code: Int)
    case httpError(code: Int)
    case requestFailed(Error)
    case invalidResponse
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .noConnection:
            return NSLocalizedString("error.network.no_connection", comment: "No internet connection available error")
        case .timeout:
            return NSLocalizedString("error.network.request_timeout", comment: "Request timed out error")
        case .unauthorized:
            return NSLocalizedString("error.network.unauthorized", comment: "Authentication required error")
        case .forbidden:
            return NSLocalizedString("error.network.forbidden", comment: "Access forbidden error")
        case .notFound:
            return NSLocalizedString("error.network.not_found", comment: "Resource not found error")
        case .serverError(let code):
            return String(format: NSLocalizedString("error.network.server_error_code", comment: "Server error with code"), code)
        case .httpError(let code):
            return String(format: NSLocalizedString("error.network.http_error_code", comment: "HTTP error with code"), code)
        case .requestFailed(let error):
            return String(format: NSLocalizedString("error.network.request_failed", comment: "Request failed error"), error.localizedDescription)
        case .invalidResponse:
            return NSLocalizedString("error.network.invalid_response", comment: "Invalid server response error")
        case .decodingFailed:
            return NSLocalizedString("error.network.decoding_failed", comment: "Failed to decode response error")
        }
    }

    var isRetryable: Bool {
        switch self {
        case .noConnection, .timeout, .serverError:
            return true
        default:
            return false
        }
    }
}

// MARK: - Network Quality

extension NetworkManager {
    /**
     * Estimate network quality based on connection type and constraints
     */
    enum NetworkQuality {
        case excellent  // WiFi/Ethernet, unconstrained
        case good       // Cellular, unconstrained
        case fair       // WiFi/Cellular, constrained
        case poor       // Limited connectivity
        case offline    // No connection
    }

    func getNetworkQuality() -> NetworkQuality {
        guard isConnected else { return .offline }

        if isConstrained {
            return .fair
        }

        switch connectionType {
        case .wifi, .ethernet:
            return .excellent
        case .cellular:
            return isExpensive ? .fair : .good
        case .other:
            return .poor
        case .none:
            return .offline
        }
    }

    /**
     * Check if network is suitable for large downloads
     */
    func isSuitableForLargeDownload() -> Bool {
        let quality = getNetworkQuality()
        return quality == .excellent || (quality == .good && !isExpensive)
    }
}

// MARK: - Combine Publishers

extension NetworkManager {
    /**
     * Publisher for network status changes
     */
    var networkStatusPublisher: AnyPublisher<Bool, Never> {
        $isConnected
            .removeDuplicates()
            .eraseToAnyPublisher()
    }

    /**
     * Publisher for connection type changes
     */
    var connectionTypePublisher: AnyPublisher<ConnectionType, Never> {
        $connectionType
            .removeDuplicates()
            .eraseToAnyPublisher()
    }
}
