//
//  MockAVFoundation.swift
//  NeuroViews 2.0Tests
//
//  Created by Claude Code on 24/01/25.
//  Mock AVFoundation sessions and devices for testing
//

import AVFoundation
import Foundation

// MARK: - Mock AVCaptureSession

/// Mock capture session for testing camera functionality
@MainActor
final class MockCaptureSession {
    var isRunning: Bool = false
    var sessionPreset: AVCaptureSession.Preset = .high
    private(set) var inputs: [MockCaptureDeviceInput] = []
    private(set) var outputs: [Any] = []

    /// Starts the capture session
    func startRunning() {
        isRunning = true
    }

    /// Stops the capture session
    func stopRunning() {
        isRunning = false
    }

    /// Begins configuration transaction
    func beginConfiguration() {
        // Mock implementation
    }

    /// Commits configuration transaction
    func commitConfiguration() {
        // Mock implementation
    }

    /// Adds an input to the session
    func canAddInput(_ input: MockCaptureDeviceInput) -> Bool {
        return true
    }

    func addInput(_ input: MockCaptureDeviceInput) {
        inputs.append(input)
    }

    /// Removes an input from the session
    func removeInput(_ input: MockCaptureDeviceInput) {
        inputs.removeAll { $0 === input }
    }

    /// Adds an output to the session
    func canAddOutput(_ output: Any) -> Bool {
        return true
    }

    func addOutput(_ output: Any) {
        outputs.append(output)
    }

    /// Removes an output from the session
    func removeOutput(_ output: Any) {
        // Mock implementation - simplified
        outputs.removeAll { _ in true }
    }

    /// Checks if preset is supported
    func canSetSessionPreset(_ preset: AVCaptureSession.Preset) -> Bool {
        return true
    }
}

// MARK: - Mock AVCaptureDevice

/// Mock capture device for testing camera hardware
@MainActor
final class MockCaptureDevice {
    let uniqueID: String
    let position: AVCaptureDevice.Position
    let deviceType: AVCaptureDevice.DeviceType
    var isLocked: Bool = false

    // Focus properties
    var isFocusModeSupported: (AVCaptureDevice.FocusMode) -> Bool
    var focusMode: AVCaptureDevice.FocusMode = .continuousAutoFocus
    var focusPointOfInterest: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var isFocusPointOfInterestSupported: Bool = true

    // Exposure properties
    var isExposureModeSupported: (AVCaptureDevice.ExposureMode) -> Bool
    var exposureMode: AVCaptureDevice.ExposureMode = .continuousAutoExposure
    var exposurePointOfInterest: CGPoint = CGPoint(x: 0.5, y: 0.5)
    var isExposurePointOfInterestSupported: Bool = true
    var exposureDuration: CMTime = CMTime(value: 1, timescale: 30)
    var iso: Float = 100.0

    // Zoom properties
    var videoZoomFactor: CGFloat = 1.0
    var minAvailableVideoZoomFactor: CGFloat = 1.0
    var maxAvailableVideoZoomFactor: CGFloat = 10.0

    // Torch properties
    var hasTorch: Bool = true
    var isTorchAvailable: Bool = true
    var torchMode: AVCaptureDevice.TorchMode = .off

    init(
        position: AVCaptureDevice.Position = .back,
        deviceType: AVCaptureDevice.DeviceType = .builtInWideAngleCamera,
        uniqueID: String = UUID().uuidString
    ) {
        self.position = position
        self.deviceType = deviceType
        self.uniqueID = uniqueID

        // Default: all modes supported
        self.isFocusModeSupported = { _ in true }
        self.isExposureModeSupported = { _ in true }
    }

    /// Locks the device for configuration
    func lockForConfiguration() throws {
        isLocked = true
    }

    /// Unlocks the device
    func unlockForConfiguration() {
        isLocked = false
    }

    /// Sets focus mode
    func setFocusMode(_ mode: AVCaptureDevice.FocusMode) {
        focusMode = mode
    }

    /// Sets focus point
    func setFocusPoint(_ point: CGPoint) {
        focusPointOfInterest = point
    }

    /// Sets exposure mode
    func setExposureMode(_ mode: AVCaptureDevice.ExposureMode) {
        exposureMode = mode
    }

    /// Sets exposure point
    func setExposurePoint(_ point: CGPoint) {
        exposurePointOfInterest = point
    }

    /// Sets zoom factor
    func setZoom(_ factor: CGFloat) throws {
        guard factor >= minAvailableVideoZoomFactor && factor <= maxAvailableVideoZoomFactor else {
            throw MockAVError.invalidZoomFactor
        }
        videoZoomFactor = factor
    }

    /// Sets torch mode
    func setTorchMode(_ mode: AVCaptureDevice.TorchMode) throws {
        guard hasTorch && isTorchAvailable else {
            throw MockAVError.torchNotAvailable
        }
        torchMode = mode
    }
}

// MARK: - Mock AVCaptureDeviceInput

/// Mock device input
@MainActor
final class MockCaptureDeviceInput {
    let device: MockCaptureDevice

    init(device: MockCaptureDevice) {
        self.device = device
    }
}

// MARK: - Mock AVCapturePhotoOutput

/// Mock photo output for testing photo capture
@MainActor
final class MockCapturePhotoOutput {
    var isFlashSupported: Bool = true
    var maxPhotoQualityPrioritization: AVCapturePhotoOutput.QualityPrioritization = .quality

    private(set) var capturedPhotos: [MockCapturePhoto] = []

    /// Captures a photo with settings
    func capturePhoto(
        with settings: AVCapturePhotoSettings,
        delegate: MockCapturePhotoDelegate
    ) {
        let photo = MockCapturePhoto(
            settings: settings,
            timestamp: Date()
        )
        capturedPhotos.append(photo)

        // Simulate async callback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            delegate.didFinishCapture(photo: photo)
        }
    }

    /// Returns available photo pixel format types
    func availablePhotoPixelFormatTypes() -> [OSType] {
        return [kCVPixelFormatType_32BGRA]
    }
}

// MARK: - Mock Capture Photo

/// Mock captured photo
struct MockCapturePhoto {
    let settings: AVCapturePhotoSettings
    let timestamp: Date
    var previewPixelBuffer: CVPixelBuffer?
    var fileDataRepresentation: Data?

    /// Returns photo as Data (JPEG)
    func fileData() -> Data? {
        return fileDataRepresentation
    }
}

// MARK: - Mock Photo Capture Delegate

/// Protocol for photo capture delegate
protocol MockCapturePhotoDelegate: AnyObject {
    func didFinishCapture(photo: MockCapturePhoto)
}

// MARK: - Mock AVCaptureVideoDataOutput

/// Mock video data output for testing frame processing
@MainActor
final class MockCaptureVideoDataOutput {
    var videoSettings: [String: Any] = [:]
    var alwaysDiscardsLateVideoFrames: Bool = true

    weak var sampleBufferDelegate: MockCaptureVideoDataOutputDelegate?
    var delegateQueue: DispatchQueue?

    /// Sets sample buffer delegate
    func setSampleBufferDelegate(
        _ delegate: MockCaptureVideoDataOutputDelegate?,
        queue: DispatchQueue?
    ) {
        self.sampleBufferDelegate = delegate
        self.delegateQueue = queue
    }

    /// Simulates receiving a sample buffer
    func simulateFrameCapture(sampleBuffer: CMSampleBuffer) {
        guard let delegate = sampleBufferDelegate,
              let queue = delegateQueue else {
            return
        }

        queue.async {
            delegate.didOutput(sampleBuffer: sampleBuffer)
        }
    }
}

// MARK: - Mock Video Data Output Delegate

/// Protocol for video data output delegate
protocol MockCaptureVideoDataOutputDelegate: AnyObject {
    func didOutput(sampleBuffer: CMSampleBuffer)
}

// MARK: - Mock Authorization

/// Mock authorization status for camera access
enum MockAuthorizationStatus {
    case notDetermined
    case restricted
    case denied
    case authorized
}

/// Mock authorization helper
enum MockAVCaptureAuthorization {
    static var authorizationStatus: MockAuthorizationStatus = .authorized

    /// Requests camera access
    static func requestAccess(completion: @escaping (Bool) -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let granted = authorizationStatus == .authorized
            completion(granted)
        }
    }

    /// Gets authorization status
    static func status() -> MockAuthorizationStatus {
        return authorizationStatus
    }
}

// MARK: - Mock Errors

enum MockAVError: Error, LocalizedError {
    case deviceNotAvailable
    case configurationFailed
    case invalidZoomFactor
    case torchNotAvailable
    case sessionNotRunning

    var errorDescription: String? {
        switch self {
        case .deviceNotAvailable:
            return "Mock device not available"
        case .configurationFailed:
            return "Mock configuration failed"
        case .invalidZoomFactor:
            return "Invalid zoom factor"
        case .torchNotAvailable:
            return "Torch not available"
        case .sessionNotRunning:
            return "Session not running"
        }
    }
}

// MARK: - Mock Device Discovery

/// Mock device discovery
enum MockDeviceDiscovery {

    /// Discovers available devices
    @MainActor
    static func devices(
        for deviceTypes: [AVCaptureDevice.DeviceType],
        mediaType: AVMediaType?,
        position: AVCaptureDevice.Position
    ) -> [MockCaptureDevice] {
        var devices: [MockCaptureDevice] = []

        for deviceType in deviceTypes {
            let device = MockCaptureDevice(
                position: position,
                deviceType: deviceType
            )
            devices.append(device)
        }

        return devices
    }

    /// Gets default device for position
    @MainActor
    static func defaultDevice(for position: AVCaptureDevice.Position) -> MockCaptureDevice? {
        return MockCaptureDevice(
            position: position,
            deviceType: .builtInWideAngleCamera
        )
    }
}

// MARK: - Test Scenarios

extension MockCaptureDevice {

    /// Creates a device with limited capabilities (no flash, limited zoom)
    @MainActor
    static func limitedCapabilities() -> MockCaptureDevice {
        let device = MockCaptureDevice()
        device.hasTorch = false
        device.maxAvailableVideoZoomFactor = 2.0
        device.isFocusModeSupported = { mode in
            mode == .continuousAutoFocus
        }
        return device
    }

    /// Creates a device with full capabilities
    @MainActor
    static func fullCapabilities() -> MockCaptureDevice {
        let device = MockCaptureDevice()
        device.hasTorch = true
        device.maxAvailableVideoZoomFactor = 15.0
        return device
    }

    /// Creates a front-facing device
    @MainActor
    static func frontCamera() -> MockCaptureDevice {
        return MockCaptureDevice(
            position: .front,
            deviceType: .builtInWideAngleCamera
        )
    }

    /// Creates a back-facing device
    @MainActor
    static func backCamera() -> MockCaptureDevice {
        return MockCaptureDevice(
            position: .back,
            deviceType: .builtInWideAngleCamera
        )
    }
}
