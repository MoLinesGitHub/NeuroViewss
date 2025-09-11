import Foundation
import CloudKit
import CoreGraphics
import Combine

// MARK: - Cloud Media Item

@available(iOS 15.0, macOS 12.0, *)
public struct CloudMediaItem: Identifiable, Sendable {
    public let id = UUID()
    public let cloudId: String
    public let localId: MediaID?
    public let recordName: String
    public let createdAt: Date
    public let modifiedAt: Date
    public let size: Int64
    public let duration: TimeInterval?
    public let resolution: CGSize?
    public let syncStatus: MediaSyncState
    
    public init(cloudId: String, localId: MediaID?, recordName: String, createdAt: Date, modifiedAt: Date, size: Int64, duration: TimeInterval?, resolution: CGSize?, syncStatus: MediaSyncState) {
        self.cloudId = cloudId
        self.localId = localId
        self.recordName = recordName
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.size = size
        self.duration = duration
        self.resolution = resolution
        self.syncStatus = syncStatus
    }
    
    public static func from(_ mediaItem: MediaItem) -> CloudMediaItem {
        return CloudMediaItem(
            cloudId: UUID().uuidString,
            localId: MediaID(value: UUID()), // Simplified
            recordName: UUID().uuidString,
            createdAt: mediaItem.createdAt,
            modifiedAt: Date(),
            size: mediaItem.metadata.size,
            duration: mediaItem.metadata.duration,
            resolution: mediaItem.metadata.resolution.map { CGSize(width: $0.width, height: $0.height) },
            syncStatus: .local
        )
    }
    
    public static func from(_ record: CKRecord) -> CloudMediaItem {
        return CloudMediaItem(
            cloudId: record.recordID.recordName,
            localId: nil,
            recordName: record.recordID.recordName,
            createdAt: record.creationDate ?? Date(),
            modifiedAt: record.modificationDate ?? Date(),
            size: record["metadataSize"] as? Int64 ?? 0,
            duration: record["duration"] as? TimeInterval,
            resolution: {
                if let width = record["width"] as? Double,
                   let height = record["height"] as? Double {
                    return CGSize(width: width, height: height)
                }
                return nil
            }(),
            syncStatus: .synced
        )
    }
}

// MARK: - Sync Status

@available(iOS 15.0, macOS 12.0, *)
public enum SyncStatus: Sendable {
    case idle
    case started
    case syncing(item: CloudMediaItem)
    case downloading(item: CloudMediaItem)
    case downloaded(item: CloudMediaItem)
    case uploading(item: CloudMediaItem)
    case uploaded(item: CloudMediaItem)
    case paused
    case resumed
    case completed
    case failed(Error)
    case offline
    
    public var isActive: Bool {
        switch self {
        case .syncing, .downloading, .uploading:
            return true
        default:
            return false
        }
    }
    
    public var displayMessage: String {
        switch self {
        case .idle:
            return "Ready to sync"
        case .started:
            return "Starting sync..."
        case .syncing(let item):
            return "Syncing \(item.recordName)"
        case .downloading(let item):
            return "Downloading \(item.recordName)"
        case .downloaded(let item):
            return "Downloaded \(item.recordName)"
        case .uploading(let item):
            return "Uploading \(item.recordName)"
        case .uploaded(let item):
            return "Uploaded \(item.recordName)"
        case .paused:
            return "Sync paused"
        case .resumed:
            return "Sync resumed"
        case .completed:
            return "Sync completed"
        case .failed(let error):
            return "Sync failed: \(error.localizedDescription)"
        case .offline:
            return "Offline - sync queued"
        }
    }
}

// MARK: - Sync Progress

@available(iOS 15.0, macOS 12.0, *)
public struct SyncProgress: Sendable {
    public let operation: SyncOperation
    public let itemsCompleted: Int
    public let totalItems: Int
    public let currentItem: CloudMediaItem?
    public let bytesTransferred: Int64
    public let totalBytes: Int64
    
    public init(operation: SyncOperation, itemsCompleted: Int, totalItems: Int, currentItem: CloudMediaItem? = nil, bytesTransferred: Int64 = 0, totalBytes: Int64 = 0) {
        self.operation = operation
        self.itemsCompleted = itemsCompleted
        self.totalItems = totalItems
        self.currentItem = currentItem
        self.bytesTransferred = bytesTransferred
        self.totalBytes = totalBytes
    }
    
    public var percentage: Double {
        guard totalItems > 0 else { return 0.0 }
        return Double(itemsCompleted) / Double(totalItems)
    }
    
    public var isComplete: Bool {
        return itemsCompleted >= totalItems
    }
}

// MARK: - Sync Operation

@available(iOS 15.0, macOS 12.0, *)
public enum SyncOperation: String, CaseIterable, Sendable {
    case upload = "upload"
    case download = "download" 
    case delete = "delete"
    case sync = "sync"
    
    public var displayName: String {
        switch self {
        case .upload: return "Uploading"
        case .download: return "Downloading"
        case .delete: return "Deleting"
        case .sync: return "Syncing"
        }
    }
}

// MARK: - Media Sync Status

@available(iOS 15.0, macOS 12.0, *)
public struct MediaSyncStatus: Identifiable, Sendable {
    public let id = UUID()
    public let itemId: MediaID
    public let cloudId: String?
    public let lastSyncDate: Date?
    public let syncState: MediaSyncState
    public let hasConflicts: Bool
    public let conflictReason: String?
    
    public init(itemId: MediaID, cloudId: String?, lastSyncDate: Date?, syncState: MediaSyncState, hasConflicts: Bool, conflictReason: String? = nil) {
        self.itemId = itemId
        self.cloudId = cloudId
        self.lastSyncDate = lastSyncDate
        self.syncState = syncState
        self.hasConflicts = hasConflicts
        self.conflictReason = conflictReason
    }
    
    public var needsSync: Bool {
        switch syncState {
        case .local, .modified, .conflict:
            return true
        case .synced, .syncing, .failed:
            return false
        }
    }
}

// MARK: - Media Sync State

@available(iOS 15.0, macOS 12.0, *)
public enum MediaSyncState: String, CaseIterable, Sendable {
    case local = "local"           // Only exists locally
    case synced = "synced"         // Synchronized with cloud
    case syncing = "syncing"       // Currently syncing
    case modified = "modified"     // Local changes need sync
    case conflict = "conflict"     // Conflict needs resolution
    case failed = "failed"        // Sync failed
    
    public var displayName: String {
        switch self {
        case .local: return "Local Only"
        case .synced: return "Synced"
        case .syncing: return "Syncing..."
        case .modified: return "Modified"
        case .conflict: return "Conflict"
        case .failed: return "Sync Failed"
        }
    }
    
    public var iconName: String {
        switch self {
        case .local: return "iphone"
        case .synced: return "icloud.and.arrow.up"
        case .syncing: return "arrow.clockwise.icloud"
        case .modified: return "pencil.circle"
        case .conflict: return "exclamationmark.triangle"
        case .failed: return "xmark.icloud"
        }
    }
}

// MARK: - Sync Conflict

@available(iOS 15.0, macOS 12.0, *)
public struct SyncConflict: Identifiable, Sendable {
    public let id = UUID()
    public let mediaId: MediaID
    public let conflictType: ConflictType
    public let localItem: MediaItem?
    public let remoteItem: CloudMediaItem?
    public let conflictDate: Date
    public let description: String
    
    public init(mediaId: MediaID, conflictType: ConflictType, localItem: MediaItem?, remoteItem: CloudMediaItem?, conflictDate: Date, description: String) {
        self.mediaId = mediaId
        self.conflictType = conflictType
        self.localItem = localItem
        self.remoteItem = remoteItem
        self.conflictDate = conflictDate
        self.description = description
    }
}

// MARK: - Conflict Type

@available(iOS 15.0, macOS 12.0, *)
public enum ConflictType: String, CaseIterable, Sendable {
    case modifiedBoth = "modifiedBoth"      // Both local and remote modified
    case deletedLocal = "deletedLocal"      // Deleted locally, modified remotely
    case deletedRemote = "deletedRemote"    // Modified locally, deleted remotely
    case duplicate = "duplicate"            // Same item exists in both
    case metadata = "metadata"              // Metadata conflicts
    
    public var displayName: String {
        switch self {
        case .modifiedBoth: return "Modified on Both Devices"
        case .deletedLocal: return "Deleted Locally, Modified Remotely"
        case .deletedRemote: return "Modified Locally, Deleted Remotely"
        case .duplicate: return "Duplicate Items"
        case .metadata: return "Metadata Conflict"
        }
    }
    
    public var severity: ConflictSeverity {
        switch self {
        case .modifiedBoth, .duplicate: return .medium
        case .deletedLocal, .deletedRemote: return .high
        case .metadata: return .low
        }
    }
}

// MARK: - Conflict Severity

@available(iOS 15.0, macOS 12.0, *)
public enum ConflictSeverity: String, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    public var displayName: String {
        return rawValue.capitalized
    }
    
    public var color: String {
        switch self {
        case .low: return "yellow"
        case .medium: return "orange"
        case .high: return "red"
        }
    }
}

// MARK: - Resolution

@available(iOS 15.0, macOS 12.0, *)
public struct Resolution: Identifiable, Sendable {
    public let id = UUID()
    public let conflictId: UUID
    public let strategy: ResolutionStrategy
    public let localItem: MediaItem?
    public let remoteItem: CloudMediaItem?
    public let mergedItem: MediaItem?
    public let timestamp: Date
    
    public init(conflictId: UUID, strategy: ResolutionStrategy, localItem: MediaItem? = nil, remoteItem: CloudMediaItem? = nil, mergedItem: MediaItem? = nil) {
        self.conflictId = conflictId
        self.strategy = strategy
        self.localItem = localItem
        self.remoteItem = remoteItem
        self.mergedItem = mergedItem
        self.timestamp = Date()
    }
}

// MARK: - Resolution Strategy

@available(iOS 15.0, macOS 12.0, *)
public enum ResolutionStrategy: String, CaseIterable, Sendable {
    case useLocal = "useLocal"         // Keep local version
    case useRemote = "useRemote"       // Use remote version  
    case merge = "merge"               // Merge both versions
    case duplicate = "duplicate"       // Keep both as separate items
    case askUser = "askUser"          // Prompt user for decision
    
    public var displayName: String {
        switch self {
        case .useLocal: return "Use Local Version"
        case .useRemote: return "Use Cloud Version"
        case .merge: return "Merge Versions"
        case .duplicate: return "Keep Both"
        case .askUser: return "Ask Me Later"
        }
    }
    
    public var description: String {
        switch self {
        case .useLocal: return "Overwrite cloud version with local changes"
        case .useRemote: return "Replace local version with cloud version"
        case .merge: return "Combine changes from both versions"
        case .duplicate: return "Save both versions as separate items"
        case .askUser: return "I'll decide later"
        }
    }
}

// MARK: - Sync Metadata

@available(iOS 15.0, macOS 12.0, *)
public struct SyncMetadata: Sendable {
    public let localId: MediaID
    public let cloudId: String?
    public let lastSyncDate: Date?
    public let syncState: MediaSyncState
    public let hasConflicts: Bool
    public let etag: String?
    public let changeToken: String?
    
    public init(localId: MediaID, cloudId: String?, lastSyncDate: Date?, syncState: MediaSyncState, hasConflicts: Bool, etag: String? = nil, changeToken: String? = nil) {
        self.localId = localId
        self.cloudId = cloudId
        self.lastSyncDate = lastSyncDate
        self.syncState = syncState
        self.hasConflicts = hasConflicts
        self.etag = etag
        self.changeToken = changeToken
    }
}

// MARK: - Queue Operation

@available(iOS 15.0, macOS 12.0, *)
public enum QueueOperation: Sendable {
    case upload(MediaItem)
    case download(CloudMediaItem)
    case delete(MediaID)
    
    public var operationType: SyncOperation {
        switch self {
        case .upload: return .upload
        case .download: return .download
        case .delete: return .delete
        }
    }
    
    public var priority: OperationPriority {
        switch self {
        case .delete: return .high
        case .upload: return .medium
        case .download: return .low
        }
    }
}

// MARK: - Operation Priority

@available(iOS 15.0, macOS 12.0, *)
public enum OperationPriority: Int, CaseIterable, Sendable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
    
    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium" 
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

// MARK: - CloudSync Errors

@available(iOS 15.0, macOS 12.0, *)
public enum CloudSyncError: Error, LocalizedError, Sendable {
    case notInitialized
    case offline
    case syncInProgress
    case invalidAsset
    case accountNotFound
    case quotaExceeded
    case networkTimeout
    case conflictResolutionFailed
    case cloudKitError(CKError)
    case unknownError(String)
    
    public var errorDescription: String? {
        switch self {
        case .notInitialized:
            return "Cloud sync not initialized"
        case .offline:
            return "Device is offline"
        case .syncInProgress:
            return "Sync already in progress"
        case .invalidAsset:
            return "Invalid media asset"
        case .accountNotFound:
            return "iCloud account not found"
        case .quotaExceeded:
            return "iCloud storage quota exceeded"
        case .networkTimeout:
            return "Network request timed out"
        case .conflictResolutionFailed:
            return "Failed to resolve sync conflict"
        case .cloudKitError(let ckError):
            return "CloudKit error: \(ckError.localizedDescription)"
        case .unknownError(let message):
            return "Unknown error: \(message)"
        }
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .offline:
            return "Check your internet connection and try again"
        case .accountNotFound:
            return "Sign in to iCloud in Settings"
        case .quotaExceeded:
            return "Free up iCloud storage or upgrade your plan"
        case .networkTimeout:
            return "Check your network connection and retry"
        default:
            return nil
        }
    }
}

// MARK: - Conflict Resolver

@available(iOS 15.0, macOS 12.0, *)
public actor ConflictResolver {
    
    private var isInitialized = false
    private var resolutionStrategies: [ConflictType: ResolutionStrategy] = [:]
    
    public init() {}
    
    public func initialize() async {
        // Set default resolution strategies
        resolutionStrategies = [
            .modifiedBoth: .askUser,
            .deletedLocal: .useRemote,
            .deletedRemote: .useLocal,
            .duplicate: .merge,
            .metadata: .useLocal
        ]
        
        isInitialized = true
    }
    
    public func resolveConflicts(_ conflicts: [SyncConflict]) async -> [Resolution] {
        guard isInitialized else { return [] }
        
        var resolutions: [Resolution] = []
        
        for conflict in conflicts {
            let strategy = resolutionStrategies[conflict.conflictType] ?? .askUser
            
            let resolution = Resolution(
                conflictId: conflict.id,
                strategy: strategy,
                localItem: conflict.localItem,
                remoteItem: conflict.remoteItem
            )
            
            resolutions.append(resolution)
        }
        
        return resolutions
    }
    
    public func setResolutionStrategy(for conflictType: ConflictType, strategy: ResolutionStrategy) async {
        resolutionStrategies[conflictType] = strategy
    }
}

// MARK: - Sync Queue

@available(iOS 15.0, macOS 12.0, *)
public actor SyncQueue {
    
    private var pendingOperations: [QueueOperation] = []
    private var completedOperations: [QueueOperation] = []
    private var failedOperations: [(QueueOperation, Error)] = []
    
    public func enqueue(_ operation: QueueOperation) async {
        pendingOperations.append(operation)
        sortByPriority()
    }
    
    public func getPendingUploads() async -> [QueueOperation] {
        return pendingOperations.filter { 
            if case .upload = $0 { return true }
            return false
        }
    }
    
    public func getAllPending() async -> [QueueOperation] {
        return pendingOperations
    }
    
    public func markCompleted(_ operation: QueueOperation) async {
        if let index = pendingOperations.firstIndex(where: { areEqual($0, operation) }) {
            pendingOperations.remove(at: index)
            completedOperations.append(operation)
        }
    }
    
    public func markFailed(_ operation: QueueOperation, error: Error) async {
        if let index = pendingOperations.firstIndex(where: { areEqual($0, operation) }) {
            pendingOperations.remove(at: index)
            failedOperations.append((operation, error))
        }
    }
    
    private func sortByPriority() {
        pendingOperations.sort { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    private func areEqual(_ op1: QueueOperation, _ op2: QueueOperation) -> Bool {
        switch (op1, op2) {
        case (.upload(let item1), .upload(let item2)):
            return item1.createdAt == item2.createdAt // Simplified comparison
        case (.download(let item1), .download(let item2)):
            return item1.cloudId == item2.cloudId
        case (.delete(let id1), .delete(let id2)):
            return id1.value == id2.value
        default:
            return false
        }
    }
}