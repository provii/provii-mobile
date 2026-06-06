// SPDX-License-Identifier: BUSL-1.1
// Copyright (c) 2024-2026 Maelstrom AI Pty Ltd ATF Maelstrom AI Holding Trust

import SwiftUI
import Combine
import AVFoundation
import Vision

/// QR code scanner view for Provii Wallet. Uses AVFoundation for camera access and the
/// Vision framework for barcode detection. Supports both general and verification-specific
/// scan modes with full VoiceOver feedback, haptic responses, and torch control.
struct QRScannerView: View {
    let mode: SheetDestination.QRScanMode
    let completion: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @StateObject private var scannerViewModel = QRScannerViewModel()
    @State private var torchOn = false

    // Focus restoration for WCAG 2.4.3
    @FocusState private var focusedElement: FocusableElement?
    @State private var savedFocus: FocusableElement?

    enum FocusableElement: Hashable {
        case cancelButton
        case torchButton
        case manualEntryButton
    }

    init(mode: SheetDestination.QRScanMode = .general,
         completion: @escaping (String) -> Void) {
        self.mode = mode
        self.completion = completion
    }

    var body: some View {
        navigationContainer
    }

    @ViewBuilder
    private var navigationContainer: some View {
        NavigationStack {
            scannerContent
        }
    }

    private var scannerContent: some View {
        ZStack {
            // Camera preview
            CameraPreview(
                session: scannerViewModel.captureSession,
                isScanning: scannerViewModel.isScanning,
                scanState: scannerViewModel.scanState
            )
                .accessibilityIgnoresInvertColors(true)
                .ignoresSafeArea()
                .onAppear {
                    scannerViewModel.startScanning()
                }
                .onDisappear {
                    scannerViewModel.stopScanning()
                }
                .accessibilityElement(children: .contain)
                .accessibilityLabel(NSLocalizedString("accessibility.qr_scanner.camera_container.label", comment: "QR code scanner camera"))
                .accessibilityAddTraits(.updatesFrequently)

            // Scanning overlay
            ScannerOverlay(
                isScanning: scannerViewModel.isScanning,
                scanState: scannerViewModel.scanState,
                mode: mode
            )

            // Error overlay
            if let error = scannerViewModel.error {
                ErrorOverlay(error: error) {
                    scannerViewModel.clearError()
                    scannerViewModel.startScanning()
                }
            }
        }
        .navigationTitle(navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(NSLocalizedString("scanner.qr_scanner_view.cancel_button", comment: "Cancel button")) {
                    dismiss()
                }
                .focused($focusedElement, equals: .cancelButton)
                .pronunciationFriendly(NSLocalizedString("accessibility.qr_scanner.cancel_button.label", comment: "Label for cancel button"))
                .pronunciationFriendlyHint(NSLocalizedString("accessibility.qr_scanner.cancel_button.hint", comment: "Hint for cancel button action"))
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    // Torch toggle
                    if scannerViewModel.hasTorch {
                        Button(action: toggleTorch) {
                            Image(systemName: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                                .foregroundColor(torchOn ? .yellow : AccessibleColors.secondaryText)
                        }
                        .focused($focusedElement, equals: .torchButton)
                        .pronunciationFriendly(torchOn ? NSLocalizedString("accessibility.qr_scanner.flashlight_on.label", comment: "Label when flashlight is on") : NSLocalizedString("accessibility.qr_scanner.flashlight_off.label", comment: "Label when flashlight is off"))
                        .pronunciationFriendlyHint(NSLocalizedString("accessibility.qr_scanner.flashlight.hint", comment: "Hint for flashlight toggle"))
                    }

                }
            }
        }
        .onReceive(scannerViewModel.$detectedQRContent) { content in
            if let content = content {
                handleQRDetected(content)
            }
        }
    }

    private var navigationTitle: String {
        switch mode {
        case .verification:
            return NSLocalizedString("scanner.qr_scanner_view.title.verification", comment: "Navigation title for verification QR scan")
        case .general:
            return NSLocalizedString("scanner.qr_scanner_view.title.general", comment: "Navigation title for general QR scan")
        }
    }

    private func toggleTorch() {
        torchOn.toggle()
        scannerViewModel.setTorch(torchOn)

        // WCAG 4.1.2: Announce state change to assistive technologies
        let announcement = torchOn
            ? NSLocalizedString("accessibility.qr_scanner.flashlight_turned_on", comment: "Flashlight turned on")
            : NSLocalizedString("accessibility.qr_scanner.flashlight_turned_off", comment: "Flashlight turned off")
        UIAccessibility.post(notification: .announcement, argument: announcement)
    }

    private func handleQRDetected(_ content: String) {
        // Validate QR content based on mode
        let isValid: Bool
        let errorMessage: String

        switch mode {
        case .verification:
            // Verification QRs should be provii://verify or JSON
            isValid = QRUtils.isValidProviiQR(content)
            errorMessage = NSLocalizedString("scanner.qr_scanner_view.error.invalid_verification", comment: "Invalid verification QR code error message")
        case .general:
            isValid = true
            errorMessage = NSLocalizedString("scanner.qr_scanner_view.error.invalid_qr", comment: "Invalid QR code error message")
        }

        if isValid {
            scannerViewModel.scanState = .success

            // VoiceOver announcement with pronunciation
            let announcement = NSLocalizedString("accessibility.qr.scan_successful", comment: "Scan successful announcement")
            UIAccessibility.post(notification: .announcement, argument: announcement.pronunciationFriendly)

            // Haptic feedback for success
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)

            completion(content)
            dismiss()
        } else {
            // Show error with announcement
            scannerViewModel.showError(errorMessage)
        }
    }
}

// MARK: - Scanner View Model

@MainActor
class QRScannerViewModel: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var error: String?
    @Published var detectedQRContent: String?
    @Published var hasTorch = false
    @Published var scanState: ScanState = .idle

    enum ScanState {
        case idle
        case searching
        case detected
        case processing
        case success
        case failed
    }

    let captureSession = AVCaptureSession()
    private var videoOutput: AVCaptureVideoDataOutput?
    private var scanThrottle = Date()
    private let scanThrottleInterval: TimeInterval = 0.5

    override init() {
        super.init()
        setupCamera()
    }

    func startScanning() {
        guard !captureSession.isRunning else { return }

        Task {
            await MainActor.run {
                isScanning = true
                error = nil
                scanState = .searching

                // VoiceOver announcement with pronunciation
                let searchingMessage = NSLocalizedString("scanner.qr_scanner_viewmodel.voiceover.searching", comment: "VoiceOver announcement when searching for QR code")
                announceToVoiceOver(searchingMessage.pronunciationFriendly)

                // Haptic feedback for scan start
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurredIfEnabled(.success)
            }
        }

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession.startRunning()
        }
    }

    func stopScanning() {
        guard captureSession.isRunning else { return }

        isScanning = false
        captureSession.stopRunning()
    }

    func setTorch(_ on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }

        do {
            try device.lockForConfiguration()
            device.torchMode = on ? .on : .off
            device.unlockForConfiguration()
        } catch {
            SecureLogger.shared.error("QRScanner torch error: \(error.localizedDescription)")
        }
    }

    func clearError() {
        error = nil
    }

    func showError(_ message: String) {
        error = message
        scanState = .failed

        // VoiceOver announcement for error with pronunciation
        let errorAnnouncement = String(format: NSLocalizedString("scanner.qr_scanner_viewmodel.voiceover.error", comment: "VoiceOver announcement for error"), message)
        announceToVoiceOver(errorAnnouncement.pronunciationFriendly)

        // Haptic feedback for error
        let feedback = UINotificationFeedbackGenerator()
        feedback.notificationOccurredIfEnabled(.error)
    }

    /// Announce message to VoiceOver users
    private func announceToVoiceOver(_ message: String) {
        UIAccessibility.post(notification: .announcement, argument: message)
    }

    private func setupCamera() {
        // Check camera permission
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureCaptureSession()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    DispatchQueue.main.async {
                        self?.configureCaptureSession()
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.error = NSLocalizedString("scanner.qr_scanner_viewmodel.error.camera_permission_required", comment: "Camera permission required error")
                    }
                }
            }
        case .denied, .restricted:
            error = NSLocalizedString("scanner.qr_scanner_viewmodel.error.camera_access_denied", comment: "Camera access denied error")
        @unknown default:
            error = NSLocalizedString("scanner.qr_scanner_viewmodel.error.camera_not_available", comment: "Camera not available error")
        }
    }

    private func configureCaptureSession() {
        captureSession.beginConfiguration()

        // Input
        guard let videoDevice = AVCaptureDevice.default(for: .video) else {
            error = NSLocalizedString("scanner.qr_scanner_viewmodel.error.no_camera", comment: "No camera available error")
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            if captureSession.canAddInput(videoInput) {
                captureSession.addInput(videoInput)
            }

            hasTorch = videoDevice.hasTorch
        } catch {
            self.error = String(format: NSLocalizedString("scanner.qr_scanner_viewmodel.error.camera_setup_failed", comment: "Camera setup failed error"), error.localizedDescription)
            return
        }

        // Output
        let output = AVCaptureVideoDataOutput()
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "qr.scanner.queue"))

        if captureSession.canAddOutput(output) {
            captureSession.addOutput(output)
            videoOutput = output
        }

        captureSession.commitConfiguration()
    }
}

// MARK: - Video Capture Delegate

extension QRScannerViewModel: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        // Throttle scanning
        guard Date().timeIntervalSince(scanThrottle) > scanThrottleInterval else { return }

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let request = VNDetectBarcodesRequest { [weak self] request, error in
            guard let self = self else { return }

            if let error = error {
                SecureLogger.shared.error("QRScanner detection error: \(error.localizedDescription)")
                return
            }

            guard let observations = request.results as? [VNBarcodeObservation],
                  let firstBarcode = observations.first,
                  let payload = firstBarcode.payloadStringValue else { return }

            // Validate QR size
            guard payload.count <= 10_000 else {
                #if DEBUG
                SecureLogger.shared.warning("QR code too large: \(payload.count) bytes", redact: false)
                #endif
                // MASVS CODE-1: Use [weak self] to prevent retain cycles in escaping closures
                DispatchQueue.main.async { [weak self] in
                    self?.showError(NSLocalizedString("scanner.qr_scanner_viewmodel.error.qr_too_large", comment: "QR code too large error"))
                }
                return
            }

            // MASVS CODE-1: Use [weak self] to prevent retain cycles in escaping closures
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.scanThrottle = Date()
                self.scanState = .detected

                // VoiceOver announcement with pronunciation
                let detectedMessage = NSLocalizedString("scanner.qr_scanner_viewmodel.voiceover.qr_detected", comment: "VoiceOver announcement when QR code is detected")
                self.announceToVoiceOver(detectedMessage.pronunciationFriendly)

                // Haptic feedback for successful detection
                let feedback = UINotificationFeedbackGenerator()
                feedback.notificationOccurredIfEnabled(.success)

                self.detectedQRContent = payload
            }
        }

        request.symbologies = [.qr]

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])
        } catch {
            SecureLogger.shared.error("QRScanner failed to perform detection: \(error.localizedDescription)")
        }
    }
}

// MARK: - Camera Preview

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    var isScanning: Bool = false
    var scanState: QRScannerViewModel.ScanState = .idle

    func makeUIView(context: Context) -> UIView {
        let view = UIView()

        // Configure accessibility for the camera preview UIView
        view.isAccessibilityElement = true
        view.accessibilityLabel = NSLocalizedString("accessibility.qr_scanner.camera_preview.label", comment: "Camera preview for scanning QR codes")
        view.accessibilityTraits = .image
        view.accessibilityValue = NSLocalizedString("accessibility.qr_scanner.camera_preview.idle", comment: "Camera idle")

        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        previewLayer.connection?.videoOrientation = .portrait

        view.layer.addSublayer(previewLayer)

        DispatchQueue.main.async {
            previewLayer.frame = view.bounds
        }

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }

        // Update accessibility value based on scanning state
        let accessibilityValue: String
        switch scanState {
        case .idle:
            accessibilityValue = NSLocalizedString("accessibility.qr_scanner.camera_preview.idle", comment: "Camera idle")
        case .searching:
            accessibilityValue = NSLocalizedString("accessibility.qr_scanner.camera_preview.scanning", comment: "Scanning for QR code")
        case .detected:
            accessibilityValue = NSLocalizedString("accessibility.qr_scanner.camera_preview.detected", comment: "QR code detected")
        case .processing:
            accessibilityValue = NSLocalizedString("accessibility.qr_scanner.camera_preview.processing", comment: "Processing QR code")
        case .success:
            accessibilityValue = NSLocalizedString("accessibility.qr_scanner.camera_preview.success", comment: "Scan successful")
        case .failed:
            accessibilityValue = NSLocalizedString("accessibility.qr_scanner.camera_preview.failed", comment: "Scan failed")
        }

        uiView.accessibilityValue = accessibilityValue
    }
}

// MARK: - Scanner Overlay

struct ScannerOverlay: View {
    let isScanning: Bool
    let scanState: QRScannerViewModel.ScanState
    let mode: SheetDestination.QRScanMode

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Semi-transparent background
                Color.black.opacity(0.5)
                    .ignoresSafeArea()
                    .accessibilityHidden(true)

                // Scanning frame
                RoundedRectangle(cornerRadius: 20)
                    .stroke(frameColor, lineWidth: 2)
                    .frame(width: 280, height: 280)
                    .overlay(
                        // Corner markers
                        ScannerCorners(color: frameColor)
                    )
                    .position(x: geometry.size.width / 2,
                             y: geometry.size.height / 2)
                    .pronunciationFriendly(NSLocalizedString("accessibility.qr_scanner.scan_area.label", comment: "Label for QR code scan area"))
                    .pronunciationFriendlyHint(NSLocalizedString("accessibility.qr_scanner.scan_area.hint", comment: "Hint for positioning QR code"))

                // Instructions
                VStack {
                    Spacer()

                    if isScanning {
                        HStack {
                            Image(systemName: stateIcon)
                                .foregroundColor(stateIconColor)
                            Text(stateText)
                        }
                        .padding()
                        .background(Color.black.opacity(0.7))
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        .padding(.bottom, 100)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(stateText)
                    }
                }
            }
        }
    }

    private var frameColor: Color {
        switch scanState {
        case .detected, .success:
            return .green
        case .failed:
            return .red
        default:
            return .white
        }
    }

    private var stateIcon: String {
        switch scanState {
        case .searching:
            return "qrcode.viewfinder"
        case .detected:
            return "checkmark.circle.fill"
        case .processing:
            return "hourglass"
        case .success:
            return "checkmark.circle.fill"
        case .failed:
            return "xmark.circle.fill"
        case .idle:
            return "qrcode.viewfinder"
        }
    }

    private var stateIconColor: Color {
        switch scanState {
        case .detected, .success:
            return .green
        case .failed:
            return .red
        default:
            return .white
        }
    }

    private var stateText: String {
        switch scanState {
        case .searching:
            return instructionText
        case .detected:
            return NSLocalizedString("scanner.scanner_overlay.state.qr_detected", comment: "QR code detected state")
        case .processing:
            return NSLocalizedString("scanner.scanner_overlay.state.processing", comment: "Processing state")
        case .success:
            return NSLocalizedString("scanner.scanner_overlay.state.scan_successful", comment: "Scan successful state")
        case .failed:
            return NSLocalizedString("scanner.scanner_overlay.state.scan_failed", comment: "Scan failed state")
        case .idle:
            return instructionText
        }
    }

    private var instructionText: String {
        switch mode {
        case .verification:
            return NSLocalizedString("scanner.scanner_overlay.instruction.verification", comment: "Instruction for scanning age verification QR")
        case .general:
            return NSLocalizedString("scanner.scanner_overlay.instruction.general", comment: "General instruction for positioning QR code")
        }
    }
}

struct ScannerCorners: View {
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            let cornerLength: CGFloat = 30
            let lineWidth: CGFloat = 3

            // Top-left
            Path { path in
                path.move(to: CGPoint(x: 0, y: cornerLength))
                path.addLine(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: cornerLength, y: 0))
            }
            .stroke(color, lineWidth: lineWidth)

            // Top-right
            Path { path in
                path.move(to: CGPoint(x: geometry.size.width - cornerLength, y: 0))
                path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
                path.addLine(to: CGPoint(x: geometry.size.width, y: cornerLength))
            }
            .stroke(color, lineWidth: lineWidth)

            // Bottom-left
            Path { path in
                path.move(to: CGPoint(x: 0, y: geometry.size.height - cornerLength))
                path.addLine(to: CGPoint(x: 0, y: geometry.size.height))
                path.addLine(to: CGPoint(x: cornerLength, y: geometry.size.height))
            }
            .stroke(color, lineWidth: lineWidth)

            // Bottom-right
            Path { path in
                path.move(to: CGPoint(x: geometry.size.width - cornerLength, y: geometry.size.height))
                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height - cornerLength))
            }
            .stroke(color, lineWidth: lineWidth)
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Error Overlay

struct ErrorOverlay: View {
    let error: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(AccessibleTypography.title3)
                .foregroundColor(.yellow)
                .accessibilityHidden(true)

            Text(error)
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .accessibilityLabel(error)

            Button(NSLocalizedString("scanner.error_overlay.try_again_button", comment: "Try again button"), action: onRetry)
                .buttonStyle(.borderedProminent)
                .accessibilityLabel(NSLocalizedString("accessibility.qr_scanner.try_again_button.label", comment: "Label for try again button"))
                .accessibilityHint(NSLocalizedString("accessibility.qr_scanner.try_again_button.hint", comment: "Hint for restarting scan"))
        }
        .padding(32)
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
        .accessibilityElement(children: .contain)
    }
}
