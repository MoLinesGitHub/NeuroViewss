//
//  ContextualRecommendationEngine.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 18-19: AI Foundation - Contextual Recommendation System
//

import Foundation
import CoreImage
import CoreLocation
import AVFoundation

@available(iOS 15.0, macOS 12.0, *)
public final class ContextualRecommendationEngine: AIAnalyzer {
    public let analysisType: AIAnalysisType = .composition // Primary type
    public var isEnabled: Bool = true
    
    private let compositionAnalyzer = CompositionAnalyzer()
    private let lightingAnalyzer = LightingAnalyzer()
    private let subjectDetector = AdvancedSubjectDetector()
    private let exposureAnalyzer = ExposureAnalyzer()
    private let stabilityAnalyzer = StabilityAnalyzer()
    private let focusAnalyzer = FocusAnalyzer()
    
    private var currentContext = PhotographyContext()
    private let sessionHistory = SessionHistory()
    
    public struct PhotographyContext {
        var sceneType: SceneType = .unknown
        var lightingConditions: LightingConditions = .unknown
        var subjectType: SubjectType = .unknown
        var photographyMode: PhotographyMode = .auto
        var userSkillLevel: SkillLevel = .intermediate
        var environmentContext: EnvironmentContext = EnvironmentContext()
        var userPreferences: UserPreferences = UserPreferences()
        
        public enum SceneType: String, CaseIterable {
            case portrait = "portrait"
            case landscape = "landscape"
            case macro = "macro"
            case street = "street"
            case sport = "sport"
            case lowLight = "low_light"
            case highContrast = "high_contrast"
            case unknown = "unknown"
            
            public var displayName: String {
                switch self {
                case .portrait: return "Portrait"
                case .landscape: return "Landscape"
                case .macro: return "Macro"
                case .street: return "Street Photography"
                case .sport: return "Sports/Action"
                case .lowLight: return "Low Light"
                case .highContrast: return "High Contrast"
                case .unknown: return "General"
                }
            }
        }
        
        public enum LightingConditions: String, CaseIterable {
            case golden = "golden_hour"
            case blue = "blue_hour"
            case harsh = "harsh_midday"
            case soft = "soft_overcast"
            case artificial = "artificial_indoor"
            case mixed = "mixed_lighting"
            case lowLight = "low_light"
            case unknown = "unknown"
        }
        
        public enum SubjectType: String, CaseIterable {
            case person = "person"
            case group = "group"
            case animal = "animal"
            case object = "object"
            case architecture = "architecture"
            case nature = "nature"
            case text = "text"
            case unknown = "unknown"
        }
        
        public enum PhotographyMode: String, CaseIterable {
            case auto = "auto"
            case portrait = "portrait"
            case landscape = "landscape"
            case macro = "macro"
            case night = "night"
            case sport = "sport"
            case manual = "manual"
        }
        
        public enum SkillLevel: String, CaseIterable {
            case beginner = "beginner"
            case intermediate = "intermediate"
            case advanced = "advanced"
            case professional = "professional"
        }
        
        public struct EnvironmentContext {
            var timeOfDay: TimeOfDay = .unknown
            var weather: Weather = .unknown
            var location: LocationType = .unknown
            var cameraStability: CameraStability = .unknown
            
            public enum TimeOfDay: String, CaseIterable {
                case dawn = "dawn"
                case morning = "morning"
                case midday = "midday"
                case afternoon = "afternoon"
                case golden = "golden_hour"
                case blue = "blue_hour"
                case night = "night"
                case unknown = "unknown"
            }
            
            public enum Weather: String, CaseIterable {
                case sunny = "sunny"
                case overcast = "overcast"
                case cloudy = "cloudy"
                case rainy = "rainy"
                case snowy = "snowy"
                case foggy = "foggy"
                case unknown = "unknown"
            }
            
            public enum LocationType: String, CaseIterable {
                case indoor = "indoor"
                case outdoor = "outdoor"
                case urban = "urban"
                case nature = "nature"
                case studio = "studio"
                case unknown = "unknown"
            }
            
            public enum CameraStability: String, CaseIterable {
                case handheld = "handheld"
                case tripod = "tripod"
                case stabilized = "stabilized"
                case unstable = "unstable"
                case unknown = "unknown"
            }
        }
        
        public struct UserPreferences {
            var preferredStyle: PhotographyStyle = .natural
            var prioritizeSharpness: Bool = true
            var prioritizeComposition: Bool = true
            var enableAdvancedSuggestions: Bool = true
            var suggestionFrequency: SuggestionFrequency = .moderate
            
            public enum PhotographyStyle: String, CaseIterable {
                case natural = "natural"
                case artistic = "artistic"
                case documentary = "documentary"
                case commercial = "commercial"
                case experimental = "experimental"
            }
            
            public enum SuggestionFrequency: String, CaseIterable {
                case minimal = "minimal"
                case moderate = "moderate"
                case frequent = "frequent"
                case realtime = "realtime"
            }
        }
    }
    
    private class SessionHistory {
        private var captureHistory: [CaptureData] = []
        private let maxHistorySize = 50
        
        struct CaptureData {
            let timestamp: Date
            let context: PhotographyContext
            let analysisResults: [AIAnalysisType: Float] // confidence scores
            let userActions: [UserAction]
        }
        
        enum UserAction {
            case acceptedSuggestion(type: SuggestionType)
            case dismissedSuggestion(type: SuggestionType)
            case manualAdjustment(setting: String, value: Any)
            case capturedPhoto
            case changedMode(from: PhotographyContext.PhotographyMode, to: PhotographyContext.PhotographyMode)
        }
        
        func addCapture(_ data: CaptureData) {
            captureHistory.append(data)
            if captureHistory.count > maxHistorySize {
                captureHistory.removeFirst()
            }
        }
        
        func getUserPreferencesFromHistory() -> PhotographyContext.UserPreferences {
            // Analyze user behavior patterns
            var preferences = PhotographyContext.UserPreferences()
            
            let recentCaptures = Array(captureHistory.suffix(10))
            
            // Analyze accepted vs dismissed suggestions
            var acceptedSuggestions: [SuggestionType] = []
            var dismissedSuggestions: [SuggestionType] = []
            
            for capture in recentCaptures {
                for action in capture.userActions {
                    switch action {
                    case .acceptedSuggestion(let type):
                        acceptedSuggestions.append(type)
                    case .dismissedSuggestion(let type):
                        dismissedSuggestions.append(type)
                    default:
                        break
                    }
                }
            }
            
            // Adjust suggestion frequency based on acceptance rate
            let totalSuggestions = acceptedSuggestions.count + dismissedSuggestions.count
            if totalSuggestions > 0 {
                let acceptanceRate = Float(acceptedSuggestions.count) / Float(totalSuggestions)
                
                if acceptanceRate > 0.8 {
                    preferences.suggestionFrequency = .frequent
                } else if acceptanceRate < 0.3 {
                    preferences.suggestionFrequency = .minimal
                } else {
                    preferences.suggestionFrequency = .moderate
                }
            }
            
            return preferences
        }
        
        func getSuccessfulPatterns() -> [ContextPattern] {
            var patterns: [ContextPattern] = []
            
            // Analyze successful combinations
            let successfulCaptures = captureHistory.filter { capture in
                capture.userActions.contains { action in
                    if case .capturedPhoto = action { return true }
                    return false
                }
            }
            
            for capture in successfulCaptures {
                patterns.append(ContextPattern(
                    context: capture.context,
                    analysisResults: capture.analysisResults,
                    successScore: calculateSuccessScore(capture)
                ))
            }
            
            return patterns
        }
        
        private func calculateSuccessScore(_ capture: CaptureData) -> Float {
            // Calculate success based on analysis results and user actions
            let avgConfidence = capture.analysisResults.values.reduce(0, +) / Float(capture.analysisResults.count)
            
            let hasCapture = capture.userActions.contains { action in
                if case .capturedPhoto = action { return true }
                return false
            }
            
            return hasCapture ? avgConfidence : avgConfidence * 0.5
        }
    }
    
    struct ContextPattern {
        let context: PhotographyContext
        let analysisResults: [AIAnalysisType: Float]
        let successScore: Float
    }
    
    public struct ContextualRecommendationResult {
        let primaryRecommendations: [ContextualRecommendation]
        let secondaryRecommendations: [ContextualRecommendation]
        let contextualInsights: [ContextualInsight]
        let sceneAnalysis: SceneAnalysis
        let confidenceScore: Float
    }
    
    public struct ContextualRecommendation {
        let id: UUID
        let type: RecommendationType
        let priority: SuggestionPriority
        let title: String
        let message: String
        var detailedExplanation: String
        let actionable: Bool
        let estimatedImpact: ImpactLevel
        let relevanceScore: Float
        let contextFactors: [String]
        
        public enum RecommendationType: String, CaseIterable {
            case composition = "composition"
            case lighting = "lighting"
            case focus = "focus"
            case exposure = "exposure"
            case timing = "timing"
            case technique = "technique"
            case creative = "creative"
            case technical = "technical"
        }
        
        public enum ImpactLevel: String, CaseIterable {
            case minimal = "minimal"
            case moderate = "moderate"
            case significant = "significant"
            case dramatic = "dramatic"
        }
    }
    
    public struct ContextualInsight {
        let category: InsightCategory
        let title: String
        let description: String
        let confidence: Float
        
        public enum InsightCategory: String, CaseIterable {
            case sceneRecognition = "scene_recognition"
            case lightingAnalysis = "lighting_analysis"
            case compositionTips = "composition_tips"
            case technicalAdvice = "technical_advice"
            case creativeOpportunities = "creative_opportunities"
        }
    }
    
    public struct SceneAnalysis {
        let detectedScene: PhotographyContext.SceneType
        let confidence: Float
        let contextFactors: [String: Float]
        let suggestedMode: PhotographyContext.PhotographyMode
        let optimalSettings: [String: Any]
    }
    
    public init() {}
    
    public func configure(with settings: [String: Any]) {
        if let skillLevel = settings["userSkillLevel"] as? String,
           let skill = PhotographyContext.SkillLevel(rawValue: skillLevel) {
            currentContext.userSkillLevel = skill
        }
        
        if let mode = settings["photographyMode"] as? String,
           let photoMode = PhotographyContext.PhotographyMode(rawValue: mode) {
            currentContext.photographyMode = photoMode
        }
        
        // Configure sub-analyzers
        compositionAnalyzer.configure(with: settings)
        lightingAnalyzer.configure(with: settings)
        subjectDetector.configure(with: settings)
        exposureAnalyzer.configure(with: settings)
        stabilityAnalyzer.configure(with: settings)
        focusAnalyzer.configure(with: settings)
    }
    
    public func analyze(frame: CVPixelBuffer) -> AIAnalysis? {
        guard isEnabled else { return nil }
        
        let ciImage = CIImage(cvPixelBuffer: frame)
        let result = performContextualAnalysis(image: ciImage)
        
        let suggestions = generateContextualSuggestions(from: result)
        
        let analysisData: [String: Any] = [
            "scene_type": result.sceneAnalysis.detectedScene.rawValue,
            "scene_confidence": result.sceneAnalysis.confidence,
            "suggested_mode": result.sceneAnalysis.suggestedMode.rawValue,
            "primary_recommendations": result.primaryRecommendations.map { rec in
                [
                    "type": rec.type.rawValue,
                    "title": rec.title,
                    "message": rec.message,
                    "priority": rec.priority.rawValue,
                    "impact": rec.estimatedImpact.rawValue,
                    "relevance": rec.relevanceScore
                ]
            },
            "contextual_insights": result.contextualInsights.map { insight in
                [
                    "category": insight.category.rawValue,
                    "title": insight.title,
                    "description": insight.description,
                    "confidence": insight.confidence
                ]
            },
            "context_factors": result.sceneAnalysis.contextFactors
        ]
        
        return AIAnalysis(
            type: .composition,
            confidence: result.confidenceScore,
            data: analysisData,
            suggestions: suggestions
        )
    }
    
    private func performContextualAnalysis(image: CIImage) -> ContextualRecommendationResult {
        // Get individual analyzer results
        guard let pixelBuffer = pixelBufferFromImage(image) else {
            return ContextualRecommendationResult(
                primaryRecommendations: [],
                secondaryRecommendations: [],
                contextualInsights: [],
                sceneAnalysis: SceneAnalysis(
                    detectedScene: .unknown,
                    confidence: 0.0,
                    contextFactors: [:],
                    suggestedMode: .auto,
                    optimalSettings: [:]
                ),
                confidenceScore: 0.0
            )
        }
        
        let compositionResult = compositionAnalyzer.analyze(frame: pixelBuffer)
        let lightingResult = lightingAnalyzer.analyze(frame: pixelBuffer)
        let subjectResult = subjectDetector.analyze(frame: pixelBuffer)
        let exposureResult = exposureAnalyzer.analyze(frame: pixelBuffer)
        let stabilityResult = stabilityAnalyzer.analyze(frame: pixelBuffer)
        let focusResult = focusAnalyzer.analyze(frame: pixelBuffer)
        
        // Update current context based on analysis
        updateContextFromAnalysis([
            compositionResult, lightingResult, subjectResult,
            exposureResult, stabilityResult, focusResult
        ].compactMap { $0 })
        
        // Perform scene analysis
        let sceneAnalysis = performSceneAnalysis(
            composition: compositionResult,
            lighting: lightingResult,
            subject: subjectResult,
            exposure: exposureResult,
            stability: stabilityResult,
            focus: focusResult
        )
        
        // Generate contextual recommendations
        let recommendations = generateContextualRecommendations(
            sceneAnalysis: sceneAnalysis,
            analysisResults: [
                compositionResult, lightingResult, subjectResult,
                exposureResult, stabilityResult, focusResult
            ].compactMap { $0 }
        )
        
        // Generate contextual insights
        let insights = generateContextualInsights(sceneAnalysis: sceneAnalysis)
        
        // Prioritize recommendations
        let (primary, secondary) = prioritizeRecommendations(recommendations)
        
        // Calculate overall confidence
        let confidence = calculateOverallConfidence([
            compositionResult, lightingResult, subjectResult,
            exposureResult, stabilityResult, focusResult
        ].compactMap { $0 })
        
        return ContextualRecommendationResult(
            primaryRecommendations: primary,
            secondaryRecommendations: secondary,
            contextualInsights: insights,
            sceneAnalysis: sceneAnalysis,
            confidenceScore: confidence
        )
    }
    
    private func pixelBufferFromImage(_ image: CIImage) -> CVPixelBuffer? {
        let context = CIContext()
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(image.extent.width),
            Int(image.extent.height),
            kCVPixelFormatType_32ARGB,
            attributes,
            &pixelBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }
        
        context.render(image, to: buffer)
        return buffer
    }
    
    private func updateContextFromAnalysis(_ results: [AIAnalysis]) {
        // Update lighting conditions
        if let lightingResult = results.first(where: { $0.type == .lighting }) {
            updateLightingContext(from: lightingResult)
        }
        
        // Update subject type
        if let subjectResult = results.first(where: { $0.type == .subject }) {
            updateSubjectContext(from: subjectResult)
        }
        
        // Update stability context
        if let stabilityResult = results.first(where: { $0.type == .stability }) {
            updateStabilityContext(from: stabilityResult)
        }
        
        // Update user preferences from history
        currentContext.userPreferences = sessionHistory.getUserPreferencesFromHistory()
    }
    
    private func updateLightingContext(from result: AIAnalysis) {
        // Extract lighting information from analysis data
        if let lightingData = result.data["lighting_type"] as? String {
            switch lightingData {
            case "golden_hour":
                currentContext.lightingConditions = .golden
                currentContext.environmentContext.timeOfDay = .golden
            case "harsh":
                currentContext.lightingConditions = .harsh
                currentContext.environmentContext.timeOfDay = .midday
            case "low_light":
                currentContext.lightingConditions = .lowLight
                currentContext.environmentContext.timeOfDay = .night
            default:
                break
            }
        }
    }
    
    private func updateSubjectContext(from result: AIAnalysis) {
        if let detectedSubjects = result.data["detected_subjects"] as? [[String: Any]],
           let firstSubject = detectedSubjects.first,
           let subjectType = firstSubject["type"] as? String {
            
            switch subjectType {
            case "face":
                currentContext.subjectType = .person
                currentContext.sceneType = .portrait
            case "human_body":
                currentContext.subjectType = .person
            case "animal":
                currentContext.subjectType = .animal
            default:
                currentContext.subjectType = .object
            }
        }
    }
    
    private func updateStabilityContext(from result: AIAnalysis) {
        if let stabilityScore = result.data["overall_stability"] as? Float {
            if stabilityScore > 0.8 {
                currentContext.environmentContext.cameraStability = .stabilized
            } else if stabilityScore > 0.5 {
                currentContext.environmentContext.cameraStability = .handheld
            } else {
                currentContext.environmentContext.cameraStability = .unstable
            }
        }
    }
    
    private func performSceneAnalysis(
        composition: AIAnalysis?,
        lighting: AIAnalysis?,
        subject: AIAnalysis?,
        exposure: AIAnalysis?,
        stability: AIAnalysis?,
        focus: AIAnalysis?
    ) -> SceneAnalysis {
        
        var contextFactors: [String: Float] = [:]
        var sceneScores: [PhotographyContext.SceneType: Float] = [:]
        
        // Analyze subject-based scene detection
        if let subjectData = subject?.data["detected_subjects"] as? [[String: Any]] {
            for subjectInfo in subjectData {
                if let type = subjectInfo["type"] as? String,
                   let confidence = subjectInfo["confidence"] as? Float {
                    
                    switch type {
                    case "face":
                        sceneScores[.portrait] = (sceneScores[.portrait] ?? 0) + confidence * 0.8
                        contextFactors["has_face"] = confidence
                    case "human_body":
                        sceneScores[.portrait] = (sceneScores[.portrait] ?? 0) + confidence * 0.6
                        sceneScores[.street] = (sceneScores[.street] ?? 0) + confidence * 0.4
                    case "animal":
                        sceneScores[.portrait] = (sceneScores[.portrait] ?? 0) + confidence * 0.3
                        contextFactors["has_animal"] = confidence
                    default:
                        sceneScores[.street] = (sceneScores[.street] ?? 0) + confidence * 0.2
                    }
                }
            }
        }
        
        // Analyze lighting-based scene detection
        if let lightingData = lighting?.data {
            if let evValue = lightingData["ev_value"] as? Float {
                contextFactors["exposure_value"] = evValue
                
                if evValue < -2 {
                    sceneScores[.lowLight] = (sceneScores[.lowLight] ?? 0) + 0.7
                } else if evValue > 2 {
                    sceneScores[.highContrast] = (sceneScores[.highContrast] ?? 0) + 0.6
                }
            }
            
            if let lightingType = lightingData["lighting_type"] as? String {
                switch lightingType {
                case "golden_hour":
                    sceneScores[.landscape] = (sceneScores[.landscape] ?? 0) + 0.6
                    contextFactors["golden_hour"] = 1.0
                case "harsh":
                    sceneScores[.street] = (sceneScores[.street] ?? 0) + 0.4
                case "low_light":
                    sceneScores[.lowLight] = (sceneScores[.lowLight] ?? 0) + 0.8
                default:
                    break
                }
            }
        }
        
        // Analyze composition-based scene detection
        if let compositionData = composition?.data {
            if let ruleOfThirdsScore = compositionData["rule_of_thirds_compliance"] as? Float {
                contextFactors["composition_score"] = ruleOfThirdsScore
                
                if ruleOfThirdsScore > 0.7 {
                    sceneScores[.landscape] = (sceneScores[.landscape] ?? 0) + 0.3
                }
            }
        }
        
        // Determine dominant scene type
        let detectedScene = sceneScores.max { $0.value < $1.value }?.key ?? .unknown
        let confidence = sceneScores[detectedScene] ?? 0.0
        
        // Suggest optimal mode based on scene
        let suggestedMode = getSuggestedMode(for: detectedScene)
        
        // Generate optimal settings
        let optimalSettings = generateOptimalSettings(for: detectedScene, context: currentContext)
        
        return SceneAnalysis(
            detectedScene: detectedScene,
            confidence: confidence,
            contextFactors: contextFactors,
            suggestedMode: suggestedMode,
            optimalSettings: optimalSettings
        )
    }
    
    private func getSuggestedMode(for scene: PhotographyContext.SceneType) -> PhotographyContext.PhotographyMode {
        switch scene {
        case .portrait:
            return .portrait
        case .landscape:
            return .landscape
        case .macro:
            return .macro
        case .sport:
            return .sport
        case .lowLight:
            return .night
        default:
            return .auto
        }
    }
    
    private func generateOptimalSettings(for scene: PhotographyContext.SceneType, context: PhotographyContext) -> [String: Any] {
        var settings: [String: Any] = [:]
        
        switch scene {
        case .portrait:
            settings["aperture"] = "f/2.8"
            settings["focus_mode"] = "single_point"
            settings["metering_mode"] = "spot"
            settings["iso"] = "auto_low"
            
        case .landscape:
            settings["aperture"] = "f/8"
            settings["focus_mode"] = "hyperfocal"
            settings["metering_mode"] = "matrix"
            settings["iso"] = "100"
            
        case .lowLight:
            settings["aperture"] = "f/1.8"
            settings["focus_mode"] = "continuous"
            settings["metering_mode"] = "matrix"
            settings["iso"] = "auto_high"
            settings["stabilization"] = "enabled"
            
        case .sport:
            settings["shutter_speed"] = "1/500"
            settings["focus_mode"] = "continuous_tracking"
            settings["metering_mode"] = "matrix"
            settings["iso"] = "auto_high"
            
        default:
            settings["mode"] = "auto"
        }
        
        return settings
    }
    
    private func generateContextualRecommendations(
        sceneAnalysis: SceneAnalysis,
        analysisResults: [AIAnalysis]
    ) -> [ContextualRecommendation] {
        
        var recommendations: [ContextualRecommendation] = []
        
        // Scene-specific recommendations
        recommendations.append(contentsOf: generateSceneSpecificRecommendations(sceneAnalysis))
        
        // Multi-analyzer recommendations
        recommendations.append(contentsOf: generateCrossAnalyzerRecommendations(analysisResults))
        
        // User skill level adjusted recommendations
        recommendations = adjustRecommendationsForSkillLevel(recommendations)
        
        // Context-aware recommendations
        recommendations.append(contentsOf: generateContextAwareRecommendations(sceneAnalysis))
        
        return recommendations
    }
    
    private func generateSceneSpecificRecommendations(_ sceneAnalysis: SceneAnalysis) -> [ContextualRecommendation] {
        var recommendations: [ContextualRecommendation] = []
        
        switch sceneAnalysis.detectedScene {
        case .portrait:
            recommendations.append(ContextualRecommendation(
                id: UUID(),
                type: .composition,
                priority: .high,
                title: "Portrait Composition",
                message: "Focus on the subject's eyes for engaging portraits",
                detailedExplanation: "In portrait photography, the eyes are the window to the soul. Ensure sharp focus on the eyes and consider the rule of thirds for positioning.",
                actionable: true,
                estimatedImpact: .significant,
                relevanceScore: 0.9,
                contextFactors: ["portrait_detected", "face_present"]
            ))
            
            if sceneAnalysis.confidence > 0.7 {
                recommendations.append(ContextualRecommendation(
                    id: UUID(),
                    type: .lighting,
                    priority: .medium,
                    title: "Portrait Lighting",
                    message: "Consider soft, directional lighting for flattering portraits",
                    detailedExplanation: "Harsh direct light can create unflattering shadows. Look for soft, diffused light sources or position your subject near a window.",
                    actionable: true,
                    estimatedImpact: .moderate,
                    relevanceScore: 0.8,
                    contextFactors: ["portrait_scene", "lighting_quality"]
                ))
            }
            
        case .landscape:
            recommendations.append(ContextualRecommendation(
                id: UUID(),
                type: .composition,
                priority: .high,
                title: "Landscape Composition",
                message: "Use foreground, middle ground, and background for depth",
                detailedExplanation: "Great landscape photos have layers that draw the viewer's eye through the scene. Look for interesting foreground elements to add depth.",
                actionable: true,
                estimatedImpact: .significant,
                relevanceScore: 0.85,
                contextFactors: ["landscape_detected", "depth_opportunity"]
            ))
            
        case .lowLight:
            recommendations.append(ContextualRecommendation(
                id: UUID(),
                type: .technical,
                priority: .high,
                title: "Low Light Technique",
                message: "Stabilize your camera and consider longer exposure",
                detailedExplanation: "In low light conditions, camera shake is your biggest enemy. Use a tripod, brace against a wall, or use your camera's stabilization features.",
                actionable: true,
                estimatedImpact: .dramatic,
                relevanceScore: 0.95,
                contextFactors: ["low_light_detected", "stability_needed"]
            ))
            
        default:
            break
        }
        
        return recommendations
    }
    
    private func generateCrossAnalyzerRecommendations(_ results: [AIAnalysis]) -> [ContextualRecommendation] {
        var recommendations: [ContextualRecommendation] = []
        
        // Look for patterns across analyzers
        let focusResult = results.first { $0.type == .focus }
        let exposureResult = results.first { $0.type == .exposure }
        let stabilityResult = results.first { $0.type == .stability }
        
        // Focus + Exposure correlation
        if let focus = focusResult, let exposure = exposureResult {
            let focusScore = focus.confidence
            let exposureScore = exposure.confidence
            
            if focusScore < 0.5 && exposureScore < 0.5 {
                recommendations.append(ContextualRecommendation(
                    id: UUID(),
                    type: .technical,
                    priority: .high,
                    title: "Focus & Exposure Issues",
                    message: "Both focus and exposure need attention - try auto mode",
                    detailedExplanation: "When both focus and exposure are problematic, it often indicates challenging shooting conditions. Consider using auto mode or improving lighting.",
                    actionable: true,
                    estimatedImpact: .significant,
                    relevanceScore: 0.9,
                    contextFactors: ["multiple_issues", "technical_difficulty"]
                ))
            }
        }
        
        // Stability + Focus correlation
        if let stability = stabilityResult, let focus = focusResult {
            if let stabilityScore = stability.data["overall_stability"] as? Float,
               stabilityScore < 0.4 && focus.confidence < 0.6 {
                
                recommendations.append(ContextualRecommendation(
                    id: UUID(),
                    type: .technique,
                    priority: .high,
                    title: "Camera Shake Affecting Focus",
                    message: "Stabilize your camera for sharper images",
                    detailedExplanation: "Camera shake is causing both stability and focus issues. Try bracing your arms, using proper grip, or finding a stable surface to lean against.",
                    actionable: true,
                    estimatedImpact: .significant,
                    relevanceScore: 0.85,
                    contextFactors: ["stability_focus_correlation", "technique_improvement"]
                ))
            }
        }
        
        return recommendations
    }
    
    private func adjustRecommendationsForSkillLevel(_ recommendations: [ContextualRecommendation]) -> [ContextualRecommendation] {
        return recommendations.map { recommendation in
            var adjusted = recommendation
            
            switch currentContext.userSkillLevel {
            case .beginner:
                // Simplify language and focus on basic concepts
                adjusted.detailedExplanation = simplifyExplanation(adjusted.detailedExplanation)
                
            case .professional:
                // Add technical details and advanced suggestions
                adjusted.detailedExplanation = enhanceExplanationWithTechnicalDetails(adjusted.detailedExplanation)
                
            default:
                break
            }
            
            return adjusted
        }
    }
    
    private func simplifyExplanation(_ explanation: String) -> String {
        // Simplify technical language for beginners
        return explanation
            .replacingOccurrences(of: "hyperfocal", with: "focusing for maximum sharpness")
            .replacingOccurrences(of: "aperture", with: "lens opening")
            .replacingOccurrences(of: "depth of field", with: "background blur")
    }
    
    private func enhanceExplanationWithTechnicalDetails(_ explanation: String) -> String {
        // Add technical details for professionals
        return explanation + " Consider the technical triangle (ISO, aperture, shutter speed) relationships and their impact on image quality."
    }
    
    private func generateContextAwareRecommendations(_ sceneAnalysis: SceneAnalysis) -> [ContextualRecommendation] {
        var recommendations: [ContextualRecommendation] = []
        
        // Time-based recommendations
        if let timeOfDay = getCurrentTimeOfDay() {
            switch timeOfDay {
            case .golden:
                recommendations.append(ContextualRecommendation(
                    id: UUID(),
                    type: .creative,
                    priority: .medium,
                    title: "Golden Hour Opportunity",
                    message: "Perfect lighting for warm, dramatic photos",
                    detailedExplanation: "Golden hour provides soft, warm light that's flattering for portraits and landscapes. The low angle creates long shadows and adds dimension.",
                    actionable: true,
                    estimatedImpact: .significant,
                    relevanceScore: 0.9,
                    contextFactors: ["golden_hour", "optimal_lighting"]
                ))
                
            case .blue:
                recommendations.append(ContextualRecommendation(
                    id: UUID(),
                    type: .creative,
                    priority: .medium,
                    title: "Blue Hour Magic",
                    message: "Great time for cityscapes and architectural photography",
                    detailedExplanation: "Blue hour provides even, diffused light with deep blue skies. Perfect for balancing artificial lights with ambient light.",
                    actionable: true,
                    estimatedImpact: .moderate,
                    relevanceScore: 0.8,
                    contextFactors: ["blue_hour", "architectural_opportunity"]
                ))
                
            default:
                break
            }
        }
        
        return recommendations
    }
    
    private func getCurrentTimeOfDay() -> PhotographyContext.EnvironmentContext.TimeOfDay? {
        let hour = Calendar.current.component(.hour, from: Date())
        
        switch hour {
        case 5...7:
            return .dawn
        case 8...11:
            return .morning
        case 12...15:
            return .midday
        case 16...17:
            return .afternoon
        case 18...19:
            return .golden
        case 20...21:
            return .blue
        case 22...4:
            return .night
        default:
            return nil
        }
    }
    
    private func generateContextualInsights(sceneAnalysis: SceneAnalysis) -> [ContextualInsight] {
        var insights: [ContextualInsight] = []
        
        // Scene recognition insights
        if sceneAnalysis.confidence > 0.7 {
            insights.append(ContextualInsight(
                category: .sceneRecognition,
                title: "Scene Detected: \(sceneAnalysis.detectedScene.displayName)",
                description: "The AI has identified this as a \(sceneAnalysis.detectedScene.displayName.lowercased()) scene with \(Int(sceneAnalysis.confidence * 100))% confidence.",
                confidence: sceneAnalysis.confidence
            ))
        }
        
        // Context factor insights
        for (factor, value) in sceneAnalysis.contextFactors {
            if value > 0.7 {
                switch factor {
                case "has_face":
                    insights.append(ContextualInsight(
                        category: .compositionTips,
                        title: "Face Detected",
                        description: "A face has been detected in the frame. Consider portrait-specific composition techniques.",
                        confidence: value
                    ))
                    
                case "golden_hour":
                    insights.append(ContextualInsight(
                        category: .lightingAnalysis,
                        title: "Golden Hour Lighting",
                        description: "You're shooting during golden hour - perfect for warm, dramatic lighting effects.",
                        confidence: value
                    ))
                    
                default:
                    break
                }
            }
        }
        
        return insights
    }
    
    private func prioritizeRecommendations(_ recommendations: [ContextualRecommendation]) -> ([ContextualRecommendation], [ContextualRecommendation]) {
        let sorted = recommendations.sorted { lhs, rhs in
            if lhs.priority != rhs.priority {
                return lhs.priority.rawValue > rhs.priority.rawValue
            }
            return lhs.relevanceScore > rhs.relevanceScore
        }
        
        let maxPrimary = currentContext.userPreferences.suggestionFrequency == .minimal ? 2 : 4
        let primary = Array(sorted.prefix(maxPrimary))
        let secondary = Array(sorted.dropFirst(maxPrimary))
        
        return (primary, secondary)
    }
    
    private func calculateOverallConfidence(_ results: [AIAnalysis]) -> Float {
        guard !results.isEmpty else { return 0.0 }
        
        let totalConfidence = results.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Float(results.count)
    }
    
    private func generateContextualSuggestions(from result: ContextualRecommendationResult) -> [AISuggestion] {
        var suggestions: [AISuggestion] = []
        
        // Convert contextual recommendations to AI suggestions
        for recommendation in result.primaryRecommendations {
            let suggestionType: SuggestionType
            
            switch recommendation.type {
            case .composition, .creative:
                suggestionType = .composition
            case .lighting:
                suggestionType = .lighting
            case .focus:
                suggestionType = .focus
            case .exposure:
                suggestionType = .lighting
            case .timing:
                suggestionType = .timing
            case .technique, .technical:
                suggestionType = .settings
            }
            
            suggestions.append(AISuggestion(
                type: suggestionType,
                title: recommendation.title,
                message: recommendation.message,
                confidence: recommendation.relevanceScore,
                priority: recommendation.priority
            ))
        }
        
        return suggestions
    }
}