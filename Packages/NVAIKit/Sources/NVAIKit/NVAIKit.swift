import Foundation
import Vision
import CoreML
import CoreImage

// MARK: - AI Analysis Engine Protocol

public protocol AIAnalysisEngine: Sendable {
    func analyzeScene(_ image: CIImage) async throws -> SceneAnalysis
    func detectObjects(_ image: CIImage) async throws -> [DetectedObject]
    func enhanceImage(_ image: CIImage) async throws -> EnhancedImage
}

// MARK: - AI Data Types

public struct SceneAnalysis: Sendable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let confidence: Float
    public let sceneType: SceneType
    public let lightingConditions: LightingConditions
    public let suggestions: [AISuggestion]
    
    public init(
        sceneType: SceneType,
        lightingConditions: LightingConditions,
        suggestions: [AISuggestion] = [],
        confidence: Float = 0.0
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.confidence = confidence
        self.sceneType = sceneType
        self.lightingConditions = lightingConditions
        self.suggestions = suggestions
    }
}

public enum SceneType: String, Codable, CaseIterable, Sendable {
    case portrait = "portrait"
    case landscape = "landscape"
    case macro = "macro"
    case night = "night"
    case sport = "sport"
    case street = "street"
    case architecture = "architecture"
    case nature = "nature"
    case unknown = "unknown"
}

public enum LightingConditions: String, Codable, CaseIterable, Sendable {
    case bright = "bright"
    case natural = "natural"
    case dim = "dim"
    case backlit = "backlit"
    case artificial = "artificial"
    case mixed = "mixed"
}
