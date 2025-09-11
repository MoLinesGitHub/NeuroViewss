import Foundation
import AVFoundation

// MARK: - Photo Types

public struct PhotoSettings: Sendable, Codable {
    public let enableHDR: Bool
    public let flashMode: FlashMode
    public let enableRAW: Bool
    public let quality: PhotoQuality
    
    public init(
        enableHDR: Bool = false,
        flashMode: FlashMode = .auto,
        enableRAW: Bool = false,
        quality: PhotoQuality = .high
    ) {
        self.enableHDR = enableHDR
        self.flashMode = flashMode
        self.enableRAW = enableRAW
        self.quality = quality
    }
}

public enum PhotoQuality: String, Codable, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case maximum = "maximum"
}

public struct RawPhoto: Sendable, Codable {
    public let id: UUID
    public let data: Data
    public let metadataJSON: String // Simplified metadata as JSON string
    public let timestamp: Date
    public let format: String
    
    public init(data: Data, metadataJSON: String = "{}", format: String) {
        self.id = UUID()
        self.data = data
        self.metadataJSON = metadataJSON
        self.timestamp = Date()
        self.format = format
    }
    
    // Convenience init for metadata dictionary
    public init(data: Data, metadata: [String: Any], format: String) {
        self.id = UUID()
        self.data = data
        self.metadataJSON = Self.encodeMetadata(metadata)
        self.timestamp = Date()
        self.format = format
    }
    
    private static func encodeMetadata(_ metadata: [String: Any]) -> String {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: metadata),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }
}

// MARK: - Video Types

public struct VideoSettings: Sendable, Codable {
    public let resolution: VideoResolution
    public let frameRate: FrameRate
    public let codec: VideoCodec
    public let quality: VideoQuality
    public let enableStabilization: Bool
    
    public init(
        resolution: VideoResolution = .hd1080,
        frameRate: FrameRate = .fps30,
        codec: VideoCodec = .h264,
        quality: VideoQuality = .high,
        enableStabilization: Bool = true
    ) {
        self.resolution = resolution
        self.frameRate = frameRate
        self.codec = codec
        self.quality = quality
        self.enableStabilization = enableStabilization
    }
}

public enum VideoResolution: String, Codable, CaseIterable, Sendable {
    case hd720 = "1280x720"
    case hd1080 = "1920x1080"
    case uhd4k = "3840x2160"
    case cinema4k = "4096x2160"
    
    public var cgSize: CGSize {
        switch self {
        case .hd720: return CGSize(width: 1280, height: 720)
        case .hd1080: return CGSize(width: 1920, height: 1080)
        case .uhd4k: return CGSize(width: 3840, height: 2160)
        case .cinema4k: return CGSize(width: 4096, height: 2160)
        }
    }
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

public struct RecordingStream: Sendable, Codable {
    public let id: UUID
    public let startTime: Date
    public let settings: VideoSettings
    public let outputURL: URL
    
    public init(settings: VideoSettings, outputURL: URL) {
        self.id = UUID()
        self.startTime = Date()
        self.settings = settings
        self.outputURL = outputURL
    }
}

// MARK: - Camera Errors

public enum CameraError: Error, LocalizedError, Sendable {
    case deviceNotAvailable
    case cannotAddInput
    case cannotAddOutput
    case photoOutputNotAvailable
    case videoOutputNotAvailable
    case sessionRuntimeError
    case authorizationDenied
    case configurationFailed(String)
    case captureFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .deviceNotAvailable:
            return "Camera device not available"
        case .cannotAddInput:
            return "Cannot add camera input to session"
        case .cannotAddOutput:
            return "Cannot add output to session"
        case .photoOutputNotAvailable:
            return "Photo output not available"
        case .videoOutputNotAvailable:
            return "Video output not available"
        case .sessionRuntimeError:
            return "Camera session runtime error"
        case .authorizationDenied:
            return "Camera access denied"
        case .configurationFailed(let message):
            return "Configuration failed: \(message)"
        case .captureFailed(let message):
            return "Capture failed: \(message)"
        }
    }
}

// MARK: - Capture Delegates

@available(iOS 15.0, macOS 12.0, *)
internal final class PhotoCaptureDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    private let completion: (Result<RawPhoto, Error>) -> Void
    
    init(completion: @escaping (Result<RawPhoto, Error>) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error = error {
            completion(.failure(error))
            return
        }
        
        guard let imageData = photo.fileDataRepresentation() else {
            completion(.failure(CameraError.captureFailed("No image data")))
            return
        }
        
        let rawPhoto = RawPhoto(
            data: imageData,
            metadataJSON: "{}",  // Simplified for macOS compatibility
            format: "jpeg"
        )
        
        completion(.success(rawPhoto))
    }
}

@available(iOS 15.0, macOS 12.0, *)
internal final class VideoRecordingDelegate: NSObject, AVCaptureFileOutputRecordingDelegate {
    private let completion: (Result<RecordingStream, Error>) -> Void
    
    init(completion: @escaping (Result<RecordingStream, Error>) -> Void) {
        self.completion = completion
        super.init()
    }
    
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        let defaultSettings = VideoSettings()
        let stream = RecordingStream(settings: defaultSettings, outputURL: fileURL)
        completion(.success(stream))
    }
    
    func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        if let error = error {
            completion(.failure(error))
        }
    }
}