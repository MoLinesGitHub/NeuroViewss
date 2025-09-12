import Foundation

// MARK: - AI Enhanced Types

public struct DetectedObject: Sendable, Codable {
    public let id: UUID
    public let boundingBox: CGRect
    public let confidence: Float
    public let label: String
    public let objectType: ObjectType
    
    public init(boundingBox: CGRect, confidence: Float, label: String, objectType: ObjectType) {
        self.id = UUID()
        self.boundingBox = boundingBox
        self.confidence = confidence
        self.label = label
        self.objectType = objectType
    }
}

public enum ObjectType: String, Codable, CaseIterable, Sendable {
    case person = "person"
    case face = "face"
    case animal = "animal"
    case vehicle = "vehicle"
    case building = "building"
    case plant = "plant"
    case food = "food"
    case object = "object"
    case text = "text"
}

public struct EnhancedImage: Sendable, Codable {
    public let id: UUID
    public let originalImageData: Data
    public let enhancedImageData: Data
    public let enhancements: [Enhancement]
    public let processingTime: TimeInterval
    
    public init(originalImageData: Data, enhancedImageData: Data, enhancements: [Enhancement], processingTime: TimeInterval) {
        self.id = UUID()
        self.originalImageData = originalImageData
        self.enhancedImageData = enhancedImageData
        self.enhancements = enhancements
        self.processingTime = processingTime
    }
}

public struct Enhancement: Sendable, Codable {
    public let type: EnhancementType
    public let intensity: Float
    public let description: String
    
    public init(type: EnhancementType, intensity: Float, description: String) {
        self.type = type
        self.intensity = intensity
        self.description = description
    }
}

public enum EnhancementType: String, Codable, CaseIterable, Sendable {
    case brightness = "brightness"
    case contrast = "contrast"
    case saturation = "saturation"
    case sharpness = "sharpness"
    case noiseReduction = "noise_reduction"
    case colorBalance = "color_balance"
    case hdr = "hdr"
    case bokeh = "bokeh"
}

// MARK: - AI Suggestions

public enum AISuggestion: Sendable, Codable, Equatable {
    case adjustExposure(value: Float)
    case changeAngle(degrees: Float)
    case waitForBetterLighting
    case captureNow(reason: String)
    case addFilter(FilterType)
    case focusOn(point: CGPoint)
    
    // Codable conformance
    private enum CodingKeys: String, CodingKey {
        case type, value, degrees, reason, filterType, pointX, pointY
    }
    
    private enum SuggestionType: String, Codable {
        case adjustExposure, changeAngle, waitForBetterLighting, captureNow, addFilter, focusOn
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(SuggestionType.self, forKey: .type)
        
        switch type {
        case .adjustExposure:
            let value = try container.decode(Float.self, forKey: .value)
            self = .adjustExposure(value: value)
        case .changeAngle:
            let degrees = try container.decode(Float.self, forKey: .degrees)
            self = .changeAngle(degrees: degrees)
        case .waitForBetterLighting:
            self = .waitForBetterLighting
        case .captureNow:
            let reason = try container.decode(String.self, forKey: .reason)
            self = .captureNow(reason: reason)
        case .addFilter:
            let filterType = try container.decode(FilterType.self, forKey: .filterType)
            self = .addFilter(filterType)
        case .focusOn:
            let x = try container.decode(CGFloat.self, forKey: .pointX)
            let y = try container.decode(CGFloat.self, forKey: .pointY)
            self = .focusOn(point: CGPoint(x: x, y: y))
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        switch self {
        case .adjustExposure(let value):
            try container.encode(SuggestionType.adjustExposure, forKey: .type)
            try container.encode(value, forKey: .value)
        case .changeAngle(let degrees):
            try container.encode(SuggestionType.changeAngle, forKey: .type)
            try container.encode(degrees, forKey: .degrees)
        case .waitForBetterLighting:
            try container.encode(SuggestionType.waitForBetterLighting, forKey: .type)
        case .captureNow(let reason):
            try container.encode(SuggestionType.captureNow, forKey: .type)
            try container.encode(reason, forKey: .reason)
        case .addFilter(let filterType):
            try container.encode(SuggestionType.addFilter, forKey: .type)
            try container.encode(filterType, forKey: .filterType)
        case .focusOn(let point):
            try container.encode(SuggestionType.focusOn, forKey: .type)
            try container.encode(point.x, forKey: .pointX)
            try container.encode(point.y, forKey: .pointY)
        }
    }
}

public enum FilterType: String, Codable, CaseIterable, Sendable {
    case none = "none"
    case vivid = "vivid"
    case dramatic = "dramatic"
    case mono = "mono"
    case silvertone = "silvertone"
    case noir = "noir"
    case vintage = "vintage"
    case warm = "warm"
    case cool = "cool"
}

public enum SuggestionPriority: String, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}