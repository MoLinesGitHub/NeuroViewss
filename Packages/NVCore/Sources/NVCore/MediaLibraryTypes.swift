import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit
public typealias PlatformColor = UIColor
#elseif canImport(AppKit)
import AppKit
public typealias PlatformColor = NSColor
#endif

// MARK: - Smart Collection

@available(iOS 15.0, macOS 12.0, *)
public struct SmartCollection: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let criteria: SearchCriteria
    public let autoUpdate: Bool
    public let mediaItems: [MediaItem]
    public let createdAt: Date
    public let lastUpdated: Date
    
    public init(id: UUID, name: String, criteria: SearchCriteria, autoUpdate: Bool, mediaItems: [MediaItem], createdAt: Date, lastUpdated: Date) {
        self.id = id
        self.name = name
        self.criteria = criteria
        self.autoUpdate = autoUpdate
        self.mediaItems = mediaItems
        self.createdAt = createdAt
        self.lastUpdated = lastUpdated
    }
    
    public var itemCount: Int {
        return mediaItems.count
    }
    
    public var photoCount: Int {
        return mediaItems.count // Simplified
    }
    
    public var videoCount: Int {
        return mediaItems.count // Simplified 
    }
    
    public var totalSize: Int64 {
        return Int64(mediaItems.count * 1024 * 1024) // Simplified
    }
    
    public var sizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
}

// MARK: - Search Criteria

@available(iOS 15.0, macOS 12.0, *)
public struct SearchCriteria: Sendable {
    public let name: String
    public let mediaType: String?
    public let dateRange: DateRange?
    public let tags: [String]
    public let location: LocationCriteria?
    public let contentFeatures: [ContentFeature]
    public let autoUpdate: Bool
    
    public init(name: String, mediaType: String? = nil, dateRange: DateRange? = nil, tags: [String] = [], location: LocationCriteria? = nil, contentFeatures: [ContentFeature] = [], autoUpdate: Bool = true) {
        self.name = name
        self.mediaType = mediaType
        self.dateRange = dateRange
        self.tags = tags
        self.location = location
        self.contentFeatures = contentFeatures
        self.autoUpdate = autoUpdate
    }
}

// MARK: - Date Range

@available(iOS 15.0, macOS 12.0, *)
public enum DateRange: Sendable, Codable {
    case lastHour
    case lastDay
    case lastWeek
    case lastMonth
    case lastYear
    case custom(from: Date, to: Date)
    case before(Date)
    case after(Date)
    
    public func contains(_ date: Date) -> Bool {
        let now = Date()
        let calendar = Calendar.current
        
        switch self {
        case .lastHour:
            return date >= calendar.date(byAdding: .hour, value: -1, to: now) ?? now
        case .lastDay:
            return date >= calendar.date(byAdding: .day, value: -1, to: now) ?? now
        case .lastWeek:
            return date >= calendar.date(byAdding: .weekOfYear, value: -1, to: now) ?? now
        case .lastMonth:
            return date >= calendar.date(byAdding: .month, value: -1, to: now) ?? now
        case .lastYear:
            return date >= calendar.date(byAdding: .year, value: -1, to: now) ?? now
        case .custom(let from, let to):
            return date >= from && date <= to
        case .before(let beforeDate):
            return date < beforeDate
        case .after(let afterDate):
            return date > afterDate
        }
    }
    
    public var displayName: String {
        switch self {
        case .lastHour: return "Last Hour"
        case .lastDay: return "Last Day"
        case .lastWeek: return "Last Week"
        case .lastMonth: return "Last Month"
        case .lastYear: return "Last Year"
        case .custom(let from, let to):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "\(formatter.string(from: from)) - \(formatter.string(from: to))"
        case .before(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "Before \(formatter.string(from: date))"
        case .after(let date):
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return "After \(formatter.string(from: date))"
        }
    }
}

// MARK: - Location Criteria

@available(iOS 15.0, macOS 12.0, *)
public struct LocationCriteria: Sendable, Codable {
    public let centerLatitude: Double
    public let centerLongitude: Double
    public let radiusMeters: Double
    public let placeName: String?
    
    public init(centerLatitude: Double, centerLongitude: Double, radiusMeters: Double, placeName: String? = nil) {
        self.centerLatitude = centerLatitude
        self.centerLongitude = centerLongitude
        self.radiusMeters = radiusMeters
        self.placeName = placeName
    }
    
    public var displayName: String {
        if let name = placeName {
            return name
        } else {
            return "Location (\(String(format: "%.4f", centerLatitude)), \(String(format: "%.4f", centerLongitude)))"
        }
    }
}

// MARK: - Content Feature

@available(iOS 15.0, macOS 12.0, *)
public enum ContentFeature: String, CaseIterable, Sendable, Codable {
    case faces = "faces"
    case text = "text"
    case objects = "objects"
    case landmarks = "landmarks"
    case animals = "animals"
    case vehicles = "vehicles"
    case nature = "nature"
    case architecture = "architecture"
    case food = "food"
    case documents = "documents"
    case screenshots = "screenshots"
    case selfies = "selfies"
    case groups = "groups"
    case lowLight = "lowLight"
    case panorama = "panorama"
    case slowMotion = "slowMotion"
    case timelapse = "timelapse"
    
    public var displayName: String {
        switch self {
        case .faces: return "People"
        case .text: return "Text"
        case .objects: return "Objects"
        case .landmarks: return "Landmarks"
        case .animals: return "Animals"
        case .vehicles: return "Vehicles"
        case .nature: return "Nature"
        case .architecture: return "Architecture"
        case .food: return "Food"
        case .documents: return "Documents"
        case .screenshots: return "Screenshots"
        case .selfies: return "Selfies"
        case .groups: return "Groups"
        case .lowLight: return "Low Light"
        case .panorama: return "Panorama"
        case .slowMotion: return "Slow Motion"
        case .timelapse: return "Timelapse"
        }
    }
}

// MARK: - Search Types

@available(iOS 15.0, macOS 12.0, *)
public enum SearchType: String, CaseIterable, Sendable, Codable {
    case text = "text"
    case visual = "visual"
    case metadata = "metadata"
    case semantic = "semantic"
    
    public var displayName: String {
        switch self {
        case .text: return "Text Content"
        case .visual: return "Visual Content"
        case .metadata: return "Metadata"
        case .semantic: return "Semantic Analysis"
        }
    }
}

// MARK: - Search Suggestion

@available(iOS 15.0, macOS 12.0, *)
public struct SearchSuggestion: Identifiable, Sendable {
    public let id = UUID()
    public let text: String
    public let type: SuggestionType
    public let confidence: Double
    
    public init(text: String, type: SuggestionType, confidence: Double) {
        self.text = text
        self.type = type
        self.confidence = confidence
    }
}

// MARK: - Suggestion Type

@available(iOS 15.0, macOS 12.0, *)
public enum SuggestionType: String, CaseIterable, Sendable {
    case tag = "tag"
    case semantic = "semantic"
    case temporal = "temporal"
    case location = "location"
    case person = "person"
    case object = "object"
    
    public var iconName: String {
        switch self {
        case .tag: return "tag"
        case .semantic: return "brain"
        case .temporal: return "clock"
        case .location: return "location"
        case .person: return "person"
        case .object: return "cube"
        }
    }
}

// MARK: - Media Analysis

@available(iOS 15.0, macOS 12.0, *)
public struct MediaAnalysis: Sendable {
    public let mediaId: MediaID
    public let contentFeatures: [ContentFeature]
    public let visualFeatures: VisualFeatures
    public let textContent: [String]
    public let objectsDetected: [DetectedObject]
    public let sceneClassification: SceneClassification
    public let colorAnalysis: ColorAnalysis
    public let faceAnalysis: FaceAnalysis
    
    public init(mediaId: MediaID, contentFeatures: [ContentFeature], visualFeatures: VisualFeatures, textContent: [String], objectsDetected: [DetectedObject], sceneClassification: SceneClassification, colorAnalysis: ColorAnalysis, faceAnalysis: FaceAnalysis) {
        self.mediaId = mediaId
        self.contentFeatures = contentFeatures
        self.visualFeatures = visualFeatures
        self.textContent = textContent
        self.objectsDetected = objectsDetected
        self.sceneClassification = sceneClassification
        self.colorAnalysis = colorAnalysis
        self.faceAnalysis = faceAnalysis
    }
}

// MARK: - Visual Features

@available(iOS 15.0, macOS 12.0, *)
public struct VisualFeatures: Sendable {
    public let dominantColors: [PlatformColor]
    public let brightness: Double // 0.0 to 1.0
    public let contrast: Double // 0.0 to 1.0
    public let sharpness: Double // 0.0 to 1.0
    public let complexity: Double // 0.0 to 1.0
    
    public init(dominantColors: [PlatformColor], brightness: Double, contrast: Double, sharpness: Double, complexity: Double) {
        self.dominantColors = dominantColors
        self.brightness = brightness
        self.contrast = contrast
        self.sharpness = sharpness
        self.complexity = complexity
    }
}

// MARK: - Detected Object

@available(iOS 15.0, macOS 12.0, *)
public struct DetectedObject: Identifiable, Sendable {
    public let id = UUID()
    public let label: String
    public let confidence: Double
    public let boundingBox: CGRect
    public let category: ObjectCategory
    
    public init(label: String, confidence: Double, boundingBox: CGRect, category: ObjectCategory) {
        self.label = label
        self.confidence = confidence
        self.boundingBox = boundingBox
        self.category = category
    }
}

// MARK: - Object Category

@available(iOS 15.0, macOS 12.0, *)
public enum ObjectCategory: String, CaseIterable, Sendable {
    case person = "person"
    case animal = "animal"
    case vehicle = "vehicle"
    case object = "object"
    case food = "food"
    case nature = "nature"
    case architecture = "architecture"
    case text = "text"
    case unknown = "unknown"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - Scene Classification

@available(iOS 15.0, macOS 12.0, *)
public struct SceneClassification: Sendable {
    public let primaryScene: String
    public let confidence: Double
    public let alternativeScenes: [String]
    
    public init(primaryScene: String, confidence: Double, alternativeScenes: [String]) {
        self.primaryScene = primaryScene
        self.confidence = confidence
        self.alternativeScenes = alternativeScenes
    }
}

// MARK: - Color Analysis

@available(iOS 15.0, macOS 12.0, *)
public struct ColorAnalysis: Sendable {
    public let dominantColors: [String]
    public let colorHarmony: ColorHarmony
    public let temperature: ColorTemperature
    
    public init(dominantColors: [String], colorHarmony: ColorHarmony, temperature: ColorTemperature) {
        self.dominantColors = dominantColors
        self.colorHarmony = colorHarmony
        self.temperature = temperature
    }
}

// MARK: - Color Harmony

@available(iOS 15.0, macOS 12.0, *)
public enum ColorHarmony: String, CaseIterable, Sendable {
    case monochromatic = "monochromatic"
    case analogous = "analogous"
    case complementary = "complementary"
    case triadic = "triadic"
    case tetradic = "tetradic"
    case mixed = "mixed"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - Color Temperature

@available(iOS 15.0, macOS 12.0, *)
public enum ColorTemperature: String, CaseIterable, Sendable {
    case warm = "warm"
    case neutral = "neutral"
    case cool = "cool"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - Face Analysis

@available(iOS 15.0, macOS 12.0, *)
public struct FaceAnalysis: Sendable {
    public let faceCount: Int
    public let ages: [AgeRange]
    public let emotions: [EmotionAnalysis]
    public let landmarks: [FaceLandmarks]
    
    public init(faceCount: Int, ages: [AgeRange], emotions: [EmotionAnalysis], landmarks: [FaceLandmarks]) {
        self.faceCount = faceCount
        self.ages = ages
        self.emotions = emotions
        self.landmarks = landmarks
    }
}

// MARK: - Age Range

@available(iOS 15.0, macOS 12.0, *)
public enum AgeRange: String, CaseIterable, Sendable {
    case child = "child"
    case teenager = "teenager"
    case adult = "adult"
    case elderly = "elderly"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - Emotion Analysis

@available(iOS 15.0, macOS 12.0, *)
public struct EmotionAnalysis: Sendable {
    public let emotion: Emotion
    public let confidence: Double
    
    public init(emotion: Emotion, confidence: Double) {
        self.emotion = emotion
        self.confidence = confidence
    }
}

// MARK: - Emotion

@available(iOS 15.0, macOS 12.0, *)
public enum Emotion: String, CaseIterable, Sendable {
    case happy = "happy"
    case sad = "sad"
    case angry = "angry"
    case surprised = "surprised"
    case neutral = "neutral"
    case fear = "fear"
    case disgust = "disgust"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - Face Landmarks

@available(iOS 15.0, macOS 12.0, *)
public struct FaceLandmarks: Sendable {
    public let eyePositions: [CGPoint]
    public let nosePosition: CGPoint
    public let mouthPosition: CGPoint
    public let faceContour: [CGPoint]
    
    public init(eyePositions: [CGPoint], nosePosition: CGPoint, mouthPosition: CGPoint, faceContour: [CGPoint]) {
        self.eyePositions = eyePositions
        self.nosePosition = nosePosition
        self.mouthPosition = mouthPosition
        self.faceContour = faceContour
    }
}

// MARK: - Searchable Content

@available(iOS 15.0, macOS 12.0, *)
public struct SearchableContent: Sendable {
    public let mediaId: MediaID
    public let textContent: String
    public let tags: [String]
    public let features: [ContentFeature]
    public let embeddings: [Double] // Vector embeddings for similarity search
    
    public init(mediaId: MediaID, textContent: String, tags: [String], features: [ContentFeature], embeddings: [Double]) {
        self.mediaId = mediaId
        self.textContent = textContent
        self.tags = tags
        self.features = features
        self.embeddings = embeddings
    }
}

// MARK: - Media Library Error

@available(iOS 15.0, macOS 12.0, *)
public enum MediaLibraryError: Error, LocalizedError, Sendable {
    case invalidItem
    case analysisFailure(String)
    case searchFailure(String)
    case collectionNotFound
    case insufficientData
    case processingTimeout
    
    public var errorDescription: String? {
        switch self {
        case .invalidItem:
            return "Invalid media item"
        case .analysisFailure(let reason):
            return "Media analysis failed: \(reason)"
        case .searchFailure(let reason):
            return "Search failed: \(reason)"
        case .collectionNotFound:
            return "Smart collection not found"
        case .insufficientData:
            return "Insufficient data for operation"
        case .processingTimeout:
            return "Processing operation timed out"
        }
    }
}