import Foundation
import AVFoundation

// MARK: - Camera Actor

@globalActor
public actor CameraActor {
    public static let shared = CameraActor()
    
    private init() {}
}

// MARK: - Camera State Management

public enum CameraState: Sendable {
    case idle
    case configuring
    case ready
    case capturing
    case recording
    case error(Error)
}

// MARK: - Camera Capabilities

public struct CameraCapabilities: Sendable, Codable {
    public let supportedFormats: [String]
    public let maxResolution: CGSize
    public let supportedFrameRates: [Double]
    public let hasFlash: Bool
    public let hasOpticalZoom: Bool
    public let maxZoomFactor: Float
    public let supportedFocusModes: [String]
    public let supportedExposureModes: [String]
    
    public init(
        supportedFormats: [String],
        maxResolution: CGSize,
        supportedFrameRates: [Double],
        hasFlash: Bool,
        hasOpticalZoom: Bool,
        maxZoomFactor: Float,
        supportedFocusModes: [String],
        supportedExposureModes: [String]
    ) {
        self.supportedFormats = supportedFormats
        self.maxResolution = maxResolution
        self.supportedFrameRates = supportedFrameRates
        self.hasFlash = hasFlash
        self.hasOpticalZoom = hasOpticalZoom
        self.maxZoomFactor = maxZoomFactor
        self.supportedFocusModes = supportedFocusModes
        self.supportedExposureModes = supportedExposureModes
    }
}

// MARK: - Camera Configuration

public struct CameraConfiguration: Sendable, Codable {
    public let position: CameraPosition
    public let quality: CameraQuality
    public let flashMode: FlashMode
    public let focusMode: FocusMode
    public let exposureMode: ExposureMode
    
    public init(
        position: CameraPosition = .back,
        quality: CameraQuality = .high,
        flashMode: FlashMode = .auto,
        focusMode: FocusMode = .continuousAutoFocus,
        exposureMode: ExposureMode = .continuousAutoExposure
    ) {
        self.position = position
        self.quality = quality
        self.flashMode = flashMode
        self.focusMode = focusMode
        self.exposureMode = exposureMode
    }
}

public enum CameraPosition: String, Codable, CaseIterable, Sendable {
    case front = "front"
    case back = "back"
    case external = "external"
}

public enum CameraQuality: String, Codable, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium" 
    case high = "high"
    case ultra = "ultra"
}

public enum FlashMode: String, Codable, CaseIterable, Sendable {
    case off = "off"
    case on = "on"
    case auto = "auto"
}

public enum FocusMode: String, Codable, CaseIterable, Sendable {
    case locked = "locked"
    case autoFocus = "autoFocus"
    case continuousAutoFocus = "continuousAutoFocus"
}

public enum ExposureMode: String, Codable, CaseIterable, Sendable {
    case locked = "locked"
    case autoExposure = "autoExposure" 
    case continuousAutoExposure = "continuousAutoExposure"
    case custom = "custom"
}
