import Foundation

// MARK: - Domain Entities

/// Unique identifier for media items
public struct MediaID: Hashable, Codable, Sendable {
    public let value: UUID
    
    public init() {
        self.value = UUID()
    }
    
    public init(value: UUID) {
        self.value = value
    }
}

/// Base protocol for all media items
public protocol MediaItem: Sendable {
    var id: MediaID { get }
    var createdAt: Date { get }
    var metadata: MediaMetadata { get }
}

/// Captured photo entity
public struct CapturedPhoto: MediaItem, Codable {
    public let id: MediaID
    public let createdAt: Date
    public let metadata: MediaMetadata
    public let imageData: Data
    public let format: PhotoFormat
    
    public init(imageData: Data, format: PhotoFormat) {
        self.id = MediaID()
        self.createdAt = Date()
        self.metadata = MediaMetadata()
        self.imageData = imageData
        self.format = format
    }
}

/// Video recording session
public struct RecordingSession: Sendable, Codable {
    public let id: UUID
    public let startedAt: Date
    public let settings: VideoSettings
    
    public init(settings: VideoSettings) {
        self.id = UUID()
        self.startedAt = Date()
        self.settings = settings
    }
}

/// Recorded video entity
public struct RecordedVideo: MediaItem, Codable {
    public let id: MediaID
    public let createdAt: Date
    public let metadata: MediaMetadata
    public let videoURL: URL
    public let duration: TimeInterval
    public let format: VideoFormat
    
    public init(videoURL: URL, duration: TimeInterval, format: VideoFormat) {
        self.id = MediaID()
        self.createdAt = Date()
        self.metadata = MediaMetadata()
        self.videoURL = videoURL
        self.duration = duration
        self.format = format
    }
}

/// Media metadata container
public struct MediaMetadata: Codable, Sendable {
    public let location: Location?
    public let cameraSettings: CameraSettings?
    public let fileSize: Int64
    
    public init(location: Location? = nil, cameraSettings: CameraSettings? = nil, fileSize: Int64 = 0) {
        self.location = location
        self.cameraSettings = cameraSettings
        self.fileSize = fileSize
    }
}

/// Location information
public struct Location: Codable, Sendable {
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double?
    
    public init(latitude: Double, longitude: Double, altitude: Double? = nil) {
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
    }
}

/// Camera settings at capture time
public struct CameraSettings: Codable, Sendable {
    public let iso: Int
    public let exposureDuration: TimeInterval
    public let aperture: Float
    public let focalLength: Float
    
    public init(iso: Int, exposureDuration: TimeInterval, aperture: Float, focalLength: Float) {
        self.iso = iso
        self.exposureDuration = exposureDuration
        self.aperture = aperture
        self.focalLength = focalLength
    }
}

// MARK: - Format Types

public enum PhotoFormat: String, Codable, CaseIterable, Sendable {
    case jpeg = "jpeg"
    case heif = "heif"
    case raw = "raw"
    case png = "png"
}

public enum VideoFormat: String, Codable, CaseIterable, Sendable {
    case mp4 = "mp4"
    case mov = "mov"
    case hevc = "hevc"
    case h264 = "h264"
}

// MARK: - Settings Types

public struct VideoSettings: Codable, Sendable {
    public let resolution: VideoResolution
    public let frameRate: FrameRate
    public let codec: VideoCodec
    public let quality: VideoQuality
    
    public init(resolution: VideoResolution, frameRate: FrameRate, codec: VideoCodec, quality: VideoQuality) {
        self.resolution = resolution
        self.frameRate = frameRate
        self.codec = codec
        self.quality = quality
    }
}

public enum VideoResolution: String, Codable, CaseIterable, Sendable {
    case hd720 = "1280x720"
    case hd1080 = "1920x1080"
    case uhd4k = "3840x2160"
    case cinema4k = "4096x2160"
}

public enum FrameRate: Int, Codable, CaseIterable, Sendable {
    case fps24 = 24
    case fps30 = 30
    case fps60 = 60
    case fps120 = 120
}

public enum VideoCodec: String, Codable, CaseIterable, Sendable {
    case h264 = "h264"
    case h265 = "h265"
    case hevc = "hevc"
    case av1 = "av1"
}

public enum VideoQuality: String, Codable, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case maximum = "maximum"
}