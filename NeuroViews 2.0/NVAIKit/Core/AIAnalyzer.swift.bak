//
//  AIAnalyzer.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 17: AI Integration Foundation
//

import Foundation
import CoreImage
import AVFoundation

// MARK: - AI Analyzer Protocol
@available(iOS 15.0, macOS 12.0, *)
public protocol AIAnalyzer: AnyObject {
    
    /// The type of analysis this analyzer performs
    var analysisType: AIAnalysisType { get }
    
    /// Whether this analyzer is currently enabled
    var isEnabled: Bool { get set }
    
    /// Analyze a single frame and return results
    func analyze(frame: CVPixelBuffer) -> AIAnalysis?
    
    /// Configure analyzer with settings
    func configure(with settings: [String: Any])
}

// MARK: - Analysis Types
public enum AIAnalysisType: String, CaseIterable {
    case composition = "composition"
    case lighting = "lighting"
    case subject = "subject"
    case focus = "focus"
    case exposure = "exposure"
    case stability = "stability"
    
    public var displayName: String {
        switch self {
        case .composition:
            return "Composition"
        case .lighting:
            return "Lighting"
        case .subject:
            return "Subject Detection"
        case .focus:
            return "Focus Analysis"
        case .exposure:
            return "Exposure"
        case .stability:
            return "Camera Stability"
        }
    }
}

// MARK: - Analysis Result
public struct AIAnalysis {
    public let type: AIAnalysisType
    public let confidence: Float
    public let timestamp: Date
    public let data: [String: Any]
    public let suggestions: [AISuggestion]
    
    public init(
        type: AIAnalysisType,
        confidence: Float,
        timestamp: Date = Date(),
        data: [String: Any] = [:],
        suggestions: [AISuggestion] = []
    ) {
        self.type = type
        self.confidence = confidence
        self.timestamp = timestamp
        self.data = data
        self.suggestions = suggestions
    }
}

// MARK: - Combined Analysis Result
public struct AIAnalysisResult {
    public let timestamp: Date
    public let frameAnalyses: [AIAnalysis]
    public let overallConfidence: Float
    public let suggestions: [AISuggestion]
    
    public init(
        timestamp: Date,
        frameAnalyses: [AIAnalysis],
        overallConfidence: Float,
        suggestions: [AISuggestion]
    ) {
        self.timestamp = timestamp
        self.frameAnalyses = frameAnalyses
        self.overallConfidence = overallConfidence
        self.suggestions = suggestions
    }
}

// MARK: - AI Suggestion
public struct AISuggestion {
    public let id: UUID
    public let type: SuggestionType
    public let title: String
    public let message: String
    public let confidence: Float
    public let priority: SuggestionPriority
    public let actionable: Bool
    
    public init(
        type: SuggestionType,
        title: String,
        message: String,
        confidence: Float,
        priority: SuggestionPriority,
        actionable: Bool = true
    ) {
        self.id = UUID()
        self.type = type
        self.title = title
        self.message = message
        self.confidence = confidence
        self.priority = priority
        self.actionable = actionable
    }
}

// MARK: - Suggestion Types
public enum SuggestionType: String, CaseIterable {
    case composition = "composition"
    case lighting = "lighting"
    case focus = "focus"
    case stability = "stability"
    case timing = "timing"
    case settings = "settings"
    
    public var icon: String {
        switch self {
        case .composition:
            return "grid"
        case .lighting:
            return "sun.max"
        case .focus:
            return "scope"
        case .stability:
            return "gyroscope"
        case .timing:
            return "timer"
        case .settings:
            return "slider.horizontal.3"
        }
    }
}

// MARK: - Suggestion Priority
public enum SuggestionPriority: Int, CaseIterable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4
    
    public var displayName: String {
        switch self {
        case .low:
            return "Low"
        case .medium:
            return "Medium"
        case .high:
            return "High"
        case .critical:
            return "Critical"
        }
    }
    
    public var color: String {
        switch self {
        case .low:
            return "gray"
        case .medium:
            return "blue"
        case .high:
            return "orange"
        case .critical:
            return "red"
        }
    }
}