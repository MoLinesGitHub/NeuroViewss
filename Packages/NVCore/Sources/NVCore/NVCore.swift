import Foundation

// MARK: - Domain Layer Protocols

/// Core camera use case protocol following Clean Architecture
public protocol CameraUseCaseProtocol: Sendable {
    func capturePhoto() async throws -> CapturedPhoto
    func startVideoRecording() async throws -> RecordingSession
    func stopVideoRecording() async throws -> RecordedVideo
}

/// Repository pattern for media management
public protocol MediaRepositoryProtocol: Sendable {
    func save(_ media: MediaItem) async throws
    func fetch(by id: MediaID) async throws -> MediaItem?
    func fetchAll() async throws -> [MediaItem]
}
