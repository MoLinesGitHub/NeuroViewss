import Foundation

// MARK: - Repository Actor Implementation

/// In-memory media repository implementation using Swift Actor
public actor InMemoryMediaRepository: MediaRepositoryProtocol {
    private var mediaItems: [MediaID: MediaItem] = [:]
    
    public init() {}
    
    public func save(_ media: MediaItem) async throws {
        mediaItems[media.id] = media
    }
    
    public func fetch(by id: MediaID) async throws -> MediaItem? {
        return mediaItems[id]
    }
    
    public func fetchAll() async throws -> [MediaItem] {
        return Array(mediaItems.values)
    }
    
    public func delete(by id: MediaID) async throws {
        mediaItems.removeValue(forKey: id)
    }
    
    public func clear() async throws {
        mediaItems.removeAll()
    }
}

// MARK: - Repository Factory

/// Factory for creating repository instances
public final class RepositoryFactory: Sendable {
    public static let shared = RepositoryFactory()
    
    private init() {}
    
    public func makeMediaRepository() -> MediaRepositoryProtocol {
        return InMemoryMediaRepository()
    }
}

// MARK: - Core Data Models (Future Implementation)

/// Protocol for persistent storage adapters
public protocol StorageAdapter: Sendable {
    func save<T: Codable>(_ item: T, with key: String) async throws
    func load<T: Codable>(_ type: T.Type, with key: String) async throws -> T?
    func delete(with key: String) async throws
    func loadAll<T: Codable>(_ type: T.Type) async throws -> [T]
}

/// File system storage adapter implementation
public final class FileSystemStorageAdapter: StorageAdapter, @unchecked Sendable {
    private let documentsDirectory: URL
    
    public init() throws {
        let fileManager = FileManager.default
        self.documentsDirectory = try fileManager.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        ).appendingPathComponent("NeuroViews2", isDirectory: true)
        
        try fileManager.createDirectory(
            at: documentsDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }
    
    public func save<T: Codable>(_ item: T, with key: String) async throws {
        let data = try JSONEncoder().encode(item)
        let url = documentsDirectory.appendingPathComponent("\(key).json")
        try data.write(to: url)
    }
    
    public func load<T: Codable>(_ type: T.Type, with key: String) async throws -> T? {
        let fileManager = FileManager.default
        let url = documentsDirectory.appendingPathComponent("\(key).json")
        
        guard fileManager.fileExists(atPath: url.path) else {
            return nil
        }
        
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(type, from: data)
    }
    
    public func delete(with key: String) async throws {
        let fileManager = FileManager.default
        let url = documentsDirectory.appendingPathComponent("\(key).json")
        if fileManager.fileExists(atPath: url.path) {
            try fileManager.removeItem(at: url)
        }
    }
    
    public func loadAll<T: Codable>(_ type: T.Type) async throws -> [T] {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
        var items: [T] = []
        
        for url in contents where url.pathExtension == "json" {
            do {
                let data = try Data(contentsOf: url)
                let item = try JSONDecoder().decode(type, from: data)
                items.append(item)
            } catch {
                // Log error but continue with other files
                continue
            }
        }
        
        return items
    }
}