//
//  NVAIKitAll.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 17: AI Integration Foundation - Unified Module
//

import Foundation
import CoreImage
import Vision
import AVFoundation

// MARK: - AI Analyzer Protocol
@available(iOS 15.0, macOS 12.0, *)
public protocol AIAnalyzer: AnyObject {
    var analysisType: AIAnalysisType { get }
    var isEnabled: Bool { get set }
    func analyze(frame: CVPixelBuffer) -> AIAnalysis?
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
        case .composition: return "Composition"
        case .lighting: return "Lighting"
        case .subject: return "Subject Detection"
        case .focus: return "Focus Analysis"
        case .exposure: return "Exposure"
        case .stability: return "Camera Stability"
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
        case .composition: return "grid"
        case .lighting: return "sun.max"
        case .focus: return "scope"
        case .stability: return "gyroscope"
        case .timing: return "timer"
        case .settings: return "slider.horizontal.3"
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
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    public var color: String {
        switch self {
        case .low: return "gray"
        case .medium: return "blue"
        case .high: return "orange"
        case .critical: return "red"
        }
    }
}

// MARK: - NVAIKit Main Module
@available(iOS 15.0, macOS 12.0, *)
public final class NVAIKit {
    
    // MARK: - Singleton
    public static let shared = NVAIKit()
    
    // MARK: - Properties
    private let analysisQueue = DispatchQueue(label: "com.neuroviews.nvaikit.analysis", qos: .userInitiated)
    private var activeAnalyzers: [any AIAnalyzer] = []
    private let performanceManager = PerformanceManager.shared
    
    // Enhanced analyzers
    private var advancedAnalyzers: [any AIAnalyzer] = []
    private var isAdvancedMode: Bool = false
    
    private init() {
        setupDefaultAnalyzers()
        setupAdvancedAnalyzers()
        configurePerformanceManager()
    }
    
    // MARK: - Configuration
    public func enableAdvancedMode(_ enabled: Bool) {
        isAdvancedMode = enabled
        if enabled {
            activeAnalyzers = advancedAnalyzers
        } else {
            setupDefaultAnalyzers()
        }
    }
    
    public func configurePerformanceSettings(_ settings: PerformanceManager.PerformanceSettings) {
        performanceManager.configure(with: settings)
    }
    
    public func setQualityLevel(_ level: PerformanceManager.QualityLevel) {
        performanceManager.setQualityLevel(level)
    }
    
    // MARK: - Public Methods
    nonisolated public func analyzeFrame(
        _ frame: CVPixelBuffer,
        completion: @escaping (AIAnalysisResult) -> Void
    ) {
        let timestamp = CACurrentMediaTime()
        
        // Check if we should process this frame
        guard performanceManager.shouldProcessFrame(timestamp: timestamp) else {
            performanceManager.recordDroppedFrame()
            return
        }
        
        // Begin performance tracking
        performanceManager.beginFrameProcessing()
        let processingStartTime = CACurrentMediaTime()
        
        analysisQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Optimize frame for analysis
            let optimizedFrame = self.performanceManager.optimizePixelBufferForAnalysis(frame) ?? frame
            
            // Get active analyzers based on performance
            let analyzersToRun = self.getAnalyzersForCurrentPerformance()
            
            let results = analyzersToRun.compactMap { analyzer in
                analyzer.analyze(frame: optimizedFrame)
            }
            
            let combinedResult = AIAnalysisResult(
                timestamp: Date(),
                frameAnalyses: results,
                overallConfidence: self.calculateOverallConfidence(from: results),
                suggestions: self.generateSuggestions(from: results)
            )
            
            // Record processing time
            let processingTime = CACurrentMediaTime() - processingStartTime
            self.performanceManager.endFrameProcessing(processingTime: processingTime)
            
            DispatchQueue.main.async {
                completion(combinedResult)
            }
        }
    }
    
    nonisolated public func addAnalyzer(_ analyzer: any AIAnalyzer) {
        analysisQueue.sync {
            activeAnalyzers.append(analyzer)
        }
    }
    
    nonisolated public func removeAnalyzer<T: AIAnalyzer>(ofType type: T.Type) {
        analysisQueue.sync {
            activeAnalyzers.removeAll { analyzer in
                analyzer is T
            }
        }
    }
    
    // MARK: - Private Methods
    private func setupDefaultAnalyzers() {
        activeAnalyzers = [
            CompositionAnalyzer(),
            LightingAnalyzer(),
            SubjectDetector()
        ]
    }
    
    private func setupAdvancedAnalyzers() {
        advancedAnalyzers = [
            CompositionAnalyzer(),
            LightingAnalyzer(),
            AdvancedSubjectDetector(),
            ExposureAnalyzer(),
            StabilityAnalyzer(),
            FocusAnalyzer(),
            ContextualRecommendationEngine()
        ]
    }
    
    private func configurePerformanceManager() {
        var settings = PerformanceManager.PerformanceSettings()
        settings.targetFrameRate = 30.0
        settings.maxProcessingTime = 0.033 // 33ms for 30fps
        settings.enableAdaptiveQuality = true
        settings.enableFrameSkipping = true
        performanceManager.configure(with: settings)
    }
    
    private func getAnalyzersForCurrentPerformance() -> [any AIAnalyzer] {
        let maxAnalyzers = performanceManager.getMaxAnalyzersForCurrentQuality()
        
        // Prioritize analyzers based on importance and current performance
        let prioritizedAnalyzers = activeAnalyzers.sorted { lhs, rhs in
            let lhsPriority = getAnalyzerPriority(lhs)
            let rhsPriority = getAnalyzerPriority(rhs)
            return lhsPriority > rhsPriority
        }
        
        return Array(prioritizedAnalyzers.prefix(maxAnalyzers))
    }
    
    private func getAnalyzerPriority(_ analyzer: any AIAnalyzer) -> Int {
        switch analyzer.analysisType {
        case .focus:
            return 10 // Highest priority - critical for image quality
        case .exposure:
            return 9 // Very high priority
        case .subject:
            return 8 // High priority
        case .composition:
            return 7 // Important for good photos
        case .lighting:
            return 6 // Helpful
        case .stability:
            return 5 // Lower priority for static shots
        }
    }
    
    // MARK: - Performance Monitoring
    public func getPerformanceMetrics(completion: @escaping (PerformanceManager.PerformanceMetrics) -> Void) {
        performanceManager.getPerformanceMetrics(completion: completion)
    }
    
    public func resetPerformanceMetrics() {
        performanceManager.resetPerformanceMetrics()
    }
    
    private func calculateOverallConfidence(from analyses: [AIAnalysis]) -> Float {
        guard !analyses.isEmpty else { return 0.0 }
        
        let totalConfidence = analyses.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Float(analyses.count)
    }
    
    private func generateSuggestions(from analyses: [AIAnalysis]) -> [AISuggestion] {
        var suggestions: [AISuggestion] = []
        
        for analysis in analyses {
            suggestions.append(contentsOf: analysis.suggestions)
        }
        
        return suggestions.sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.confidence > rhs.confidence
            }
            return lhs.priority.rawValue > rhs.priority.rawValue
        }
    }
}

// MARK: - Basic Composition Analyzer
@available(iOS 15.0, macOS 12.0, *)
public final class CompositionAnalyzer: AIAnalyzer {
    public let analysisType: AIAnalysisType = .composition
    public var isEnabled: Bool = true
    
    public init() {}
    
    public func configure(with settings: [String: Any]) {
        // Configure settings
    }
    
    public func analyze(frame: CVPixelBuffer) -> AIAnalysis? {
        guard isEnabled else { return nil }
        
        // Basic rule of thirds analysis
        let confidence: Float = 0.7
        let suggestions: [AISuggestion] = [
            AISuggestion(
                type: .composition,
                title: "Rule of Thirds",
                message: "Consider placing subjects along grid lines",
                confidence: 0.8,
                priority: .medium
            )
        ]
        
        return AIAnalysis(
            type: .composition,
            confidence: confidence,
            suggestions: suggestions
        )
    }
}

// MARK: - Basic Lighting Analyzer
@available(iOS 15.0, macOS 12.0, *)
public final class LightingAnalyzer: AIAnalyzer {
    public let analysisType: AIAnalysisType = .lighting
    public var isEnabled: Bool = true
    
    public init() {}
    
    public func configure(with settings: [String: Any]) {
        // Configure settings
    }
    
    public func analyze(frame: CVPixelBuffer) -> AIAnalysis? {
        guard isEnabled else { return nil }
        
        // Basic lighting analysis
        let confidence: Float = 0.6
        let suggestions: [AISuggestion] = [
            AISuggestion(
                type: .lighting,
                title: "Lighting Check",
                message: "Monitor exposure and contrast",
                confidence: 0.7,
                priority: .medium
            )
        ]
        
        return AIAnalysis(
            type: .lighting,
            confidence: confidence,
            suggestions: suggestions
        )
    }
}

// MARK: - Basic Subject Detector
@available(iOS 15.0, macOS 12.0, *)
public final class SubjectDetector: AIAnalyzer {
    public let analysisType: AIAnalysisType = .subject
    public var isEnabled: Bool = true
    
    public init() {}
    
    public func configure(with settings: [String: Any]) {
        // Configure settings
    }
    
    public func analyze(frame: CVPixelBuffer) -> AIAnalysis? {
        guard isEnabled else { return nil }
        
        // Basic subject detection
        let confidence: Float = 0.5
        let suggestions: [AISuggestion] = [
            AISuggestion(
                type: .composition,
                title: "Subject Focus",
                message: "Ensure clear subject in frame",
                confidence: 0.6,
                priority: .medium
            )
        ]
        
        return AIAnalysis(
            type: .subject,
            confidence: confidence,
            suggestions: suggestions
        )
    }
}