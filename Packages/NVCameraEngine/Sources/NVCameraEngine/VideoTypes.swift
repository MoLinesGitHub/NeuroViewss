import Foundation
import AVFoundation
import CoreGraphics

// MARK: - Video Preferences

@available(iOS 15.0, macOS 12.0, *)
public struct VideoPreferences: Sendable, Codable {
    public let resolution: VideoResolution
    public let frameRate: FrameRate
    public let codec: VideoCodec
    public let adaptiveQuality: Bool
    public let realTimeFilters: Bool
    
    public init(
        resolution: VideoResolution = .hd1080,
        frameRate: FrameRate = .fps30,
        codec: VideoCodec = .h264,
        adaptiveQuality: Bool = true,
        realTimeFilters: Bool = false
    ) {
        self.resolution = resolution
        self.frameRate = frameRate
        self.codec = codec
        self.adaptiveQuality = adaptiveQuality
        self.realTimeFilters = realTimeFilters
    }
}

// MARK: - Recording Session

@available(iOS 15.0, macOS 12.0, *)
public struct RecordingSession: Identifiable, Sendable, Codable {
    public let id: UUID
    public let preferences: VideoPreferences
    public let startTime: Date
    public let initialQuality: VideoQuality
    
    public init(id: UUID, preferences: VideoPreferences, startTime: Date, initialQuality: VideoQuality) {
        self.id = id
        self.preferences = preferences
        self.startTime = startTime
        self.initialQuality = initialQuality
    }
}

// MARK: - Environment Conditions

@available(iOS 15.0, macOS 12.0, *)
public struct EnvironmentConditions: Sendable, Codable {
    public let batteryLevel: Double // 0.0 to 1.0
    public let thermalState: ThermalState
    public let availableStorage: Int64 // in bytes
    public let networkQuality: NetworkQuality
    public let lightingConditions: LightingConditions
    
    public init(batteryLevel: Double, thermalState: ThermalState, availableStorage: Int64, networkQuality: NetworkQuality, lightingConditions: LightingConditions) {
        self.batteryLevel = batteryLevel
        self.thermalState = thermalState
        self.availableStorage = availableStorage
        self.networkQuality = networkQuality
        self.lightingConditions = lightingConditions
    }
    
    public var overallScore: Double {
        let batteryScore = batteryLevel
        let thermalScore = thermalState.impactScore
        let storageScore = min(1.0, Double(availableStorage) / (5.0 * 1024 * 1024 * 1024)) // 5GB baseline
        let networkScore = networkQuality.impactScore
        let lightingScore = lightingConditions.qualityScore
        
        return (batteryScore + thermalScore + storageScore + networkScore + lightingScore) / 5.0
    }
}

// MARK: - Thermal State

@available(iOS 15.0, macOS 12.0, *)
public enum ThermalState: String, CaseIterable, Sendable, Codable {
    case normal = "normal"
    case fair = "fair"
    case serious = "serious"
    
    public var impactScore: Double {
        switch self {
        case .normal: return 1.0
        case .fair: return 0.7
        case .serious: return 0.4
        }
    }
    
    public var displayName: String {
        switch self {
        case .normal: return "Normal"
        case .fair: return "Warm"
        case .serious: return "Hot"
        }
    }
}

// MARK: - Network Quality

@available(iOS 15.0, macOS 12.0, *)
public enum NetworkQuality: String, CaseIterable, Sendable, Codable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    
    public var impactScore: Double {
        switch self {
        case .excellent: return 1.0
        case .good: return 0.8
        case .fair: return 0.6
        case .poor: return 0.3
        }
    }
    
    public var displayName: String {
        switch self {
        case .excellent: return "Excellent"
        case .good: return "Good"
        case .fair: return "Fair"
        case .poor: return "Poor"
        }
    }
}

// MARK: - Lighting Conditions

@available(iOS 15.0, macOS 12.0, *)
public struct LightingConditions: Sendable, Codable {
    public let brightness: Double // 0.0 to 1.0
    public let stability: Double // 0.0 to 1.0
    
    public init(brightness: Double, stability: Double) {
        self.brightness = brightness
        self.stability = stability
    }
    
    public var qualityScore: Double {
        return (brightness + stability) / 2.0
    }
    
    public var lightingType: String {
        switch brightness {
        case 0.0..<0.3: return "Low Light"
        case 0.3..<0.7: return "Moderate Light"
        default: return "Bright Light"
        }
    }
}

// MARK: - Quality Adaptation Event

@available(iOS 15.0, macOS 12.0, *)
public struct QualityAdaptationEvent: Identifiable, Sendable, Codable {
    public let id = UUID()
    public let timestamp: Date
    public let fromQuality: VideoQuality
    public let toQuality: VideoQuality
    public let reason: AdaptationReason
    
    public init(timestamp: Date, fromQuality: VideoQuality, toQuality: VideoQuality, reason: AdaptationReason) {
        self.timestamp = timestamp
        self.fromQuality = fromQuality
        self.toQuality = toQuality
        self.reason = reason
    }
}

// MARK: - Adaptation Reason

@available(iOS 15.0, macOS 12.0, *)
public enum AdaptationReason: Sendable, Codable {
    case batteryLow(Double)
    case thermalThrottling(ThermalState)
    case storageLimit(Int64)
    case networkDegradation(NetworkQuality)
    case lightingChange(LightingConditions)
    case environmentalConditions(EnvironmentConditions)
    case userRequest
    case systemOptimization
    
    public var displayDescription: String {
        switch self {
        case .batteryLow(let level):
            return "Battery low (\(Int(level * 100))%)"
        case .thermalThrottling(let state):
            return "Thermal throttling (\(state.displayName))"
        case .storageLimit(let bytes):
            let gb = Double(bytes) / (1024 * 1024 * 1024)
            return "Storage limit (\(String(format: "%.1f", gb))GB available)"
        case .networkDegradation(let quality):
            return "Network degradation (\(quality.displayName))"
        case .lightingChange(let conditions):
            return "Lighting change (\(conditions.lightingType))"
        case .environmentalConditions:
            return "Environmental conditions changed"
        case .userRequest:
            return "User request"
        case .systemOptimization:
            return "System optimization"
        }
    }
}

// MARK: - Video Filter

@available(iOS 15.0, macOS 12.0, *)
public enum VideoFilter: Sendable, Codable {
    case exposure(Double)
    case saturation(Double)
    case contrast(Double)
    case blur(Double)
    case sharpen(Double)
    
    public var displayName: String {
        switch self {
        case .exposure: return "Exposure"
        case .saturation: return "Saturation"
        case .contrast: return "Contrast"
        case .blur: return "Blur"
        case .sharpen: return "Sharpen"
        }
    }
}

// MARK: - Recorded Video

@available(iOS 15.0, macOS 12.0, *)
public struct RecordedVideo: Identifiable, Sendable {
    public let id: UUID
    public let url: URL
    public let duration: TimeInterval
    public let resolution: VideoResolution
    public let frameRate: FrameRate
    public let codec: VideoCodec
    public let createdAt: Date
    public let adaptationEvents: [QualityAdaptationEvent]
    
    public init(id: UUID, url: URL, duration: TimeInterval, resolution: VideoResolution, frameRate: FrameRate, codec: VideoCodec, createdAt: Date, adaptationEvents: [QualityAdaptationEvent]) {
        self.id = id
        self.url = url
        self.duration = duration
        self.resolution = resolution
        self.frameRate = frameRate
        self.codec = codec
        self.createdAt = createdAt
        self.adaptationEvents = adaptationEvents
    }
    
    public var fileSize: Int64 {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return attributes[.size] as? Int64 ?? 0
        } catch {
            return 0
        }
    }
    
    public var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }
    
    public var durationFormatted: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Video Recording Errors

@available(iOS 15.0, macOS 12.0, *)
public enum VideoRecordingError: Error, LocalizedError, Sendable {
    case notInitialized
    case alreadyRecording
    case notRecording
    case setupFailed(String)
    case finalizationFailed(String)
    case insufficientStorage
    case thermalThrottling
    case codecNotSupported(String)
    case resolutionNotSupported(String)
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Video recorder not initialized"
        case .alreadyRecording:
            return "Recording is already in progress"
        case .notRecording:
            return "No active recording session"
        case .setupFailed(let reason):
            return "Recording setup failed: \(reason)"
        case .finalizationFailed(let reason):
            return "Recording finalization failed: \(reason)"
        case .insufficientStorage:
            return "Insufficient storage space for recording"
        case .thermalThrottling:
            return "Recording stopped due to thermal throttling"
        case .codecNotSupported(let codecName):
            return "Codec \(codecName) is not supported"
        case .resolutionNotSupported(let resolutionName):
            return "Resolution \(resolutionName) is not supported"
        }
    }
}

// MARK: - File Size Impact

@available(iOS 15.0, macOS 12.0, *)
public enum FileSizeImpact: String, Sendable, Codable {
    case small = "small"
    case medium = "medium"
    case large = "large"
    
    public var displayName: String {
        switch self {
        case .small: return "Small files"
        case .medium: return "Medium files"
        case .large: return "Large files"
        }
    }
    
    public var multiplier: Double {
        switch self {
        case .small: return 0.7
        case .medium: return 1.0
        case .large: return 2.0
        }
    }
}