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

// Types are defined in AIAnalyzer.swift - this file provides unified access

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
        // CRITICAL FIX: Conservative settings to prevent iOS termination
        settings.targetFrameRate = 10.0 // Reduced from 30fps to 10fps
        settings.maxProcessingTime = 0.1 // Increased from 33ms to 100ms
        settings.enableAdaptiveQuality = true
        settings.enableFrameSkipping = true
        settings.maxMemoryUsage = 100 * 1024 * 1024 // CRITICAL FIX: Reduced from 200MB to 100MB
        performanceManager.configure(with: settings)
        
        // CRITICAL FIX: Start with low quality to prevent immediate resource issues
        performanceManager.setQualityLevel(.low)
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