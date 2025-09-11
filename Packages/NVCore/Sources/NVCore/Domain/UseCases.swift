import Foundation

// MARK: - Use Cases Implementation

/// Camera use case implementation following Clean Architecture principles
public final class CameraUseCase: CameraUseCaseProtocol {
    private let mediaRepository: MediaRepositoryProtocol
    
    public init(mediaRepository: MediaRepositoryProtocol) {
        self.mediaRepository = mediaRepository
    }
    
    public func capturePhoto() async throws -> CapturedPhoto {
        // This will be implemented by the camera engine
        // For now, creating a placeholder
        let placeholderData = Data("placeholder_photo".utf8)
        let photo = CapturedPhoto(imageData: placeholderData, format: .jpeg)
        
        try await mediaRepository.save(photo)
        return photo
    }
    
    public func startVideoRecording() async throws -> RecordingSession {
        let settings = VideoSettings(
            resolution: .hd1080,
            frameRate: .fps30,
            codec: .h264,
            quality: .high
        )
        
        return RecordingSession(settings: settings)
    }
    
    public func stopVideoRecording() async throws -> RecordedVideo {
        // This will be implemented by the camera engine
        // For now, creating a placeholder
        let placeholderURL = URL(fileURLWithPath: "/tmp/placeholder.mp4")
        let video = RecordedVideo(
            videoURL: placeholderURL,
            duration: 10.0,
            format: .mp4
        )
        
        try await mediaRepository.save(video)
        return video
    }
}

/// Media management use case
public final class MediaManagementUseCase: Sendable {
    private let repository: MediaRepositoryProtocol
    
    public init(repository: MediaRepositoryProtocol) {
        self.repository = repository
    }
    
    public func getAllMedia() async throws -> [MediaItem] {
        return try await repository.fetchAll()
    }
    
    public func getMedia(by id: MediaID) async throws -> MediaItem? {
        return try await repository.fetch(by: id)
    }
    
    public func deleteMedia(by id: MediaID) async throws {
        // This will be extended with actual deletion logic
        // For now, this is a placeholder
    }
}

/// Search and filtering use case
public final class MediaSearchUseCase: Sendable {
    private let repository: MediaRepositoryProtocol
    
    public init(repository: MediaRepositoryProtocol) {
        self.repository = repository
    }
    
    public func searchByDateRange(from startDate: Date, to endDate: Date) async throws -> [MediaItem] {
        let allMedia = try await repository.fetchAll()
        return allMedia.filter { media in
            media.createdAt >= startDate && media.createdAt <= endDate
        }
    }
    
    public func searchByFormat<T: MediaItem>(_ type: T.Type) async throws -> [T] {
        let allMedia = try await repository.fetchAll()
        return allMedia.compactMap { $0 as? T }
    }
}