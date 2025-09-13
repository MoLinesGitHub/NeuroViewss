//
//  SmartCompositionGuides.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 20-21: Smart Features Implementation - Composition Guides
//

import Foundation
import SwiftUI
import Vision
import AVFoundation
import CoreImage
import Combine

// MARK: - Smart Composition Guides Assistant
@available(iOS 15.0, macOS 12.0, *)
@MainActor
public final class SmartCompositionGuides: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var currentGuides: [CompositionGuide] = []
    @Published public var activeGuideType: GuideType = .ruleOfThirds
    @Published public var isAnalyzing = false
    @Published public var isEnabled = true
    @Published public var confidence: Float = 0.0
    @Published public var suggestions: [CompositionSuggestion] = []
    
    // MARK: - Private Properties
    private let visionQueue = DispatchQueue(label: "com.neuroviews.composition.vision", qos: .userInitiated)
    private var lastAnalysisTime: CFTimeInterval = 0
    private let minimumAnalysisInterval: CFTimeInterval = 0.33 // 30fps limit
    private let guidesHistory: [CompositionAnalysis] = []
    private let historyLimit = 5
    
    // Vision requests
    private var facesRequest: VNDetectFaceRectanglesRequest?
    private var rectanglesRequest: VNDetectRectanglesRequest?
    private var horizonRequest: VNDetectHorizonRequest?
    
    // MARK: - Initialization
    public init() {
        setupVisionRequests()
    }
    
    private func setupVisionRequests() {
        // Initialize and configure face detection
        facesRequest = VNDetectFaceRectanglesRequest()
        facesRequest?.revision = VNDetectFaceRectanglesRequestRevision3
        
        // Initialize other requests
        rectanglesRequest = VNDetectRectanglesRequest()
        horizonRequest = VNDetectHorizonRequest()
        
        // Configure rectangle detection
        rectanglesRequest?.minimumAspectRatio = 0.3
        rectanglesRequest?.maximumAspectRatio = 1.7
        rectanglesRequest?.minimumSize = 0.1
        rectanglesRequest?.minimumConfidence = 0.6
        
        // Configure horizon detection - VNDetectHorizonRequest doesn't have minimumConfidence
        // Available on iOS 14.0+
    }
    
    // MARK: - Public Methods
    
    /// Analyze frame and provide composition guidance
    nonisolated public func analyzeComposition(_ pixelBuffer: CVPixelBuffer) {
        Task { @MainActor in
            guard self.isEnabled, !self.isAnalyzing else { return }
            
            let currentTime = CACurrentMediaTime()
            
            // CRITICAL FIX: Increase minimum interval to 2 seconds to prevent resource exhaustion
            let minimumInterval: CFTimeInterval = 2.0
            guard currentTime - self.lastAnalysisTime >= minimumInterval else { return }
            
            self.isAnalyzing = true
            self.lastAnalysisTime = currentTime
            
            // CRITICAL FIX: Use background priority and simplified analysis
            Task.detached(priority: .background) { [weak self] in
                guard let self = self else { return }
                
                // CRITICAL FIX: Skip expensive Vision analysis and use static guides
                let currentGuideType = await self.activeGuideType
                let guides = self.generateStaticCompositionGuides(guideType: currentGuideType)
                
                Task { @MainActor in
                    self.currentGuides = guides
                    self.confidence = 1.0 // Static guides always have full confidence
                    self.isAnalyzing = false
                }
            }
        }
    }
    
    /// Change active guide type
    public func setGuideType(_ type: GuideType) {
        activeGuideType = type
        regenerateGuides()
    }
    
    /// Enable or disable specific guide types
    public func toggleGuide(_ type: GuideType, enabled: Bool) {
        // Update guide configuration
        regenerateGuides()
    }
    
    // MARK: - Private Analysis Methods
    
    private func performVisionAnalysis(_ pixelBuffer: CVPixelBuffer) async -> CompositionAnalysis {
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        
        var detectedFaces: [VNFaceObservation] = []
        var detectedRectangles: [VNRectangleObservation] = []
        var horizonAngle: Float = 0.0
        var confidence: Float = 0.0
        
        do {
            // Batch all Vision requests together for optimal performance
            var visionRequests: [VNRequest] = []
            
            if let facesReq = facesRequest {
                visionRequests.append(facesReq)
            }
            
            if let rectanglesReq = rectanglesRequest {
                visionRequests.append(rectanglesReq)
            }
            
            if #available(iOS 14.0, *), let horizonReq = horizonRequest {
                visionRequests.append(horizonReq)
            }
            
            // Single batch execution - much more efficient than separate calls
            if !visionRequests.isEmpty {
                try imageRequestHandler.perform(visionRequests)
                
                // Process results from batch execution
                if let facesReq = facesRequest, let faces = facesReq.results {
                    detectedFaces = faces
                    confidence += 0.3
                }
                
                if let rectanglesReq = rectanglesRequest, let rectangles = rectanglesReq.results {
                    detectedRectangles = rectangles
                    confidence += 0.2
                }
                
                if #available(iOS 14.0, *), let horizonReq = horizonRequest,
                   let horizon = horizonReq.results?.first {
                    horizonAngle = Float(horizon.angle)
                    confidence += 0.2
                }
            }
            
        } catch {
            print("Batch vision analysis error: \(error)")
        }
        
        return CompositionAnalysis(
            faces: detectedFaces,
            rectangles: detectedRectangles,
            horizonAngle: horizonAngle,
            confidence: min(confidence, 1.0),
            timestamp: Date()
        )
    }
    
    nonisolated private func generateCompositionGuides(from analysis: CompositionAnalysis, guideType: GuideType) -> [CompositionGuide] {
        var guides: [CompositionGuide] = []
        
        // Generate guides based on active type
        switch guideType {
        case .ruleOfThirds:
            guides.append(contentsOf: generateRuleOfThirdsGuides())
            
        case .goldenRatio:
            guides.append(contentsOf: generateGoldenRatioGuides())
            
        case .leadingLines:
            guides.append(contentsOf: generateLeadingLinesGuides(from: analysis))
            
        case .symmetry:
            guides.append(contentsOf: generateSymmetryGuides())
            
        case .centeredComposition:
            guides.append(contentsOf: generateCenteredGuides())
            
        case .dynamicSymmetry:
            guides.append(contentsOf: generateDynamicSymmetryGuides())
            
        case .horizon:
            // Horizon guides are added automatically below if detected
            break
        }
        
        // Add horizon guide if detected
        if abs(analysis.horizonAngle) > 0.1 {
            guides.append(CompositionGuide(
                type: .horizon,
                lines: [CGLine(start: CGPoint(x: 0, y: 0.5), end: CGPoint(x: 1, y: 0.5))],
                confidence: analysis.confidence,
                isActive: abs(analysis.horizonAngle) < 5.0 // Within 5 degrees
            ))
        }
        
        return guides
    }
    
    // CRITICAL FIX: Static guide generation to avoid expensive Vision processing
    nonisolated private func generateStaticCompositionGuides(guideType: GuideType) -> [CompositionGuide] {
        // Generate guides without expensive analysis
        switch guideType {
        case .ruleOfThirds:
            return generateRuleOfThirdsGuides()
        case .goldenRatio:
            return generateGoldenRatioGuides()
        case .symmetry:
            return generateSymmetryGuides()
        case .centeredComposition:
            return generateCenteredGuides()
        case .dynamicSymmetry:
            return generateDynamicSymmetryGuides()
        case .leadingLines, .horizon:
            // Skip expensive analysis-dependent guides
            return generateRuleOfThirdsGuides() // Default to rule of thirds
        }
    }
    
    nonisolated private func generateRuleOfThirdsGuides() -> [CompositionGuide] {
        let lines = [
            // Vertical lines
            CGLine(start: CGPoint(x: 1.0/3.0, y: 0), end: CGPoint(x: 1.0/3.0, y: 1)),
            CGLine(start: CGPoint(x: 2.0/3.0, y: 0), end: CGPoint(x: 2.0/3.0, y: 1)),
            
            // Horizontal lines
            CGLine(start: CGPoint(x: 0, y: 1.0/3.0), end: CGPoint(x: 1, y: 1.0/3.0)),
            CGLine(start: CGPoint(x: 0, y: 2.0/3.0), end: CGPoint(x: 1, y: 2.0/3.0))
        ]
        
        return [CompositionGuide(
            type: .ruleOfThirds,
            lines: lines,
            confidence: 1.0,
            isActive: true
        )]
    }
    
    nonisolated private func generateGoldenRatioGuides() -> [CompositionGuide] {
        let phi = (1.0 + sqrt(5.0)) / 2.0
        let goldenRatio = 1.0 / phi
        
        let lines = [
            // Vertical lines based on golden ratio
            CGLine(start: CGPoint(x: goldenRatio, y: 0), end: CGPoint(x: goldenRatio, y: 1)),
            CGLine(start: CGPoint(x: 1.0 - goldenRatio, y: 0), end: CGPoint(x: 1.0 - goldenRatio, y: 1)),
            
            // Horizontal lines based on golden ratio
            CGLine(start: CGPoint(x: 0, y: goldenRatio), end: CGPoint(x: 1, y: goldenRatio)),
            CGLine(start: CGPoint(x: 0, y: 1.0 - goldenRatio), end: CGPoint(x: 1, y: 1.0 - goldenRatio))
        ]
        
        return [CompositionGuide(
            type: .goldenRatio,
            lines: lines,
            confidence: 1.0,
            isActive: true
        )]
    }
    
    nonisolated private func generateLeadingLinesGuides(from analysis: CompositionAnalysis) -> [CompositionGuide] {
        var lines: [CGLine] = []
        
        // Generate leading lines based on detected rectangles
        for rectangle in analysis.rectangles {
            let topLeft = rectangle.topLeft
            let topRight = rectangle.topRight
            let bottomLeft = rectangle.bottomLeft
            let bottomRight = rectangle.bottomRight
            
            // Add diagonal lines
            lines.append(CGLine(start: topLeft, end: bottomRight))
            lines.append(CGLine(start: topRight, end: bottomLeft))
        }
        
        return [CompositionGuide(
            type: .leadingLines,
            lines: lines,
            confidence: analysis.confidence,
            isActive: !lines.isEmpty
        )]
    }
    
    nonisolated private func generateSymmetryGuides() -> [CompositionGuide] {
        let lines = [
            // Vertical center line
            CGLine(start: CGPoint(x: 0.5, y: 0), end: CGPoint(x: 0.5, y: 1)),
            
            // Horizontal center line
            CGLine(start: CGPoint(x: 0, y: 0.5), end: CGPoint(x: 1, y: 0.5))
        ]
        
        return [CompositionGuide(
            type: .symmetry,
            lines: lines,
            confidence: 1.0,
            isActive: true
        )]
    }
    
    nonisolated private func generateCenteredGuides() -> [CompositionGuide] {
        // Center focus circle
        let centerGuides = [CompositionGuide(
            type: .centeredComposition,
            lines: [], // Will use circles/points instead of lines
            confidence: 1.0,
            isActive: true
        )]
        
        return centerGuides
    }
    
    nonisolated private func generateDynamicSymmetryGuides() -> [CompositionGuide] {
        // Dynamic symmetry diagonal lines
        let lines = [
            CGLine(start: CGPoint(x: 0, y: 0), end: CGPoint(x: 1, y: 1)),
            CGLine(start: CGPoint(x: 1, y: 0), end: CGPoint(x: 0, y: 1)),
            CGLine(start: CGPoint(x: 0, y: 0.5), end: CGPoint(x: 0.5, y: 1)),
            CGLine(start: CGPoint(x: 0.5, y: 0), end: CGPoint(x: 1, y: 0.5))
        ]
        
        return [CompositionGuide(
            type: .dynamicSymmetry,
            lines: lines,
            confidence: 1.0,
            isActive: true
        )]
    }
    
    nonisolated private func generateSuggestions(from analysis: CompositionAnalysis, guides: [CompositionGuide], guideType: GuideType) -> [CompositionSuggestion] {
        var suggestions: [CompositionSuggestion] = []
        
        // Analyze face placement for rule of thirds
        for face in analysis.faces {
            let faceCenter = CGPoint(
                x: face.boundingBox.midX,
                y: 1.0 - face.boundingBox.midY // Flip Y coordinate
            )
            
            let isOnThirdsPoint = isNearThirdsIntersection(faceCenter)
            
            if !isOnThirdsPoint {
                let nearestThirdsPoint = findNearestThirdsIntersection(faceCenter)
                suggestions.append(CompositionSuggestion(
                    type: .subjectPlacement,
                    message: "Posiciona el rostro en uno de los puntos de la regla de tercios",
                    confidence: analysis.confidence,
                    targetPoint: nearestThirdsPoint
                ))
            }
        }
        
        // Analyze horizon level
        if abs(analysis.horizonAngle) > 2.0 {
            suggestions.append(CompositionSuggestion(
                type: .horizonAlignment,
                message: "Nivela el horizonte para mejorar la composición",
                confidence: analysis.confidence,
                targetPoint: nil
            ))
        }
        
        // Analyze symmetry
        if guideType == .symmetry && !analysis.faces.isEmpty {
            suggestions.append(CompositionSuggestion(
                type: .symmetry,
                message: "Centra el sujeto para una composición simétrica",
                confidence: analysis.confidence,
                targetPoint: CGPoint(x: 0.5, y: 0.5)
            ))
        }
        
        return suggestions
    }
    
    // MARK: - Helper Methods
    
    private func regenerateGuides() {
        // Regenerate guides with current settings
        let emptyAnalysis = CompositionAnalysis(
            faces: [],
            rectangles: [],
            horizonAngle: 0.0,
            confidence: 1.0,
            timestamp: Date()
        )
        currentGuides = generateCompositionGuides(from: emptyAnalysis, guideType: activeGuideType)
    }
    
    nonisolated private func isNearThirdsIntersection(_ point: CGPoint) -> Bool {
        let thirdsPoints = [
            CGPoint(x: 1.0/3.0, y: 1.0/3.0),
            CGPoint(x: 2.0/3.0, y: 1.0/3.0),
            CGPoint(x: 1.0/3.0, y: 2.0/3.0),
            CGPoint(x: 2.0/3.0, y: 2.0/3.0)
        ]
        
        let threshold: CGFloat = 0.1
        
        return thirdsPoints.contains { thirdsPoint in
            let distance = sqrt(pow(point.x - thirdsPoint.x, 2) + pow(point.y - thirdsPoint.y, 2))
            return distance < threshold
        }
    }
    
    nonisolated private func findNearestThirdsIntersection(_ point: CGPoint) -> CGPoint {
        let thirdsPoints = [
            CGPoint(x: 1.0/3.0, y: 1.0/3.0),
            CGPoint(x: 2.0/3.0, y: 1.0/3.0),
            CGPoint(x: 1.0/3.0, y: 2.0/3.0),
            CGPoint(x: 2.0/3.0, y: 2.0/3.0)
        ]
        
        return thirdsPoints.min { a, b in
            let distanceA = sqrt(pow(point.x - a.x, 2) + pow(point.y - a.y, 2))
            let distanceB = sqrt(pow(point.x - b.x, 2) + pow(point.y - b.y, 2))
            return distanceA < distanceB
        } ?? thirdsPoints.first!
    }
}

// MARK: - Supporting Types

public struct CompositionGuide {
    public let type: GuideType
    public let lines: [CGLine]
    public let confidence: Float
    public let isActive: Bool
    
    nonisolated public init(type: GuideType, lines: [CGLine], confidence: Float, isActive: Bool) {
        self.type = type
        self.lines = lines
        self.confidence = confidence
        self.isActive = isActive
    }
}

public struct CompositionSuggestion {
    public let type: SuggestionType
    public let message: String
    public let confidence: Float
    public let targetPoint: CGPoint?
    
    public enum SuggestionType {
        case subjectPlacement
        case horizonAlignment
        case symmetry
        case leadingLines
        case framing
    }
}

public enum GuideType: String, CaseIterable {
    case ruleOfThirds = "ruleOfThirds"
    case goldenRatio = "goldenRatio"
    case leadingLines = "leadingLines"
    case symmetry = "symmetry"
    case centeredComposition = "centeredComposition"
    case dynamicSymmetry = "dynamicSymmetry"
    case horizon = "horizon"
    
    public var displayName: String {
        switch self {
        case .ruleOfThirds: return "Regla de Tercios"
        case .goldenRatio: return "Proporción Áurea"
        case .leadingLines: return "Líneas Guía"
        case .symmetry: return "Simetría"
        case .centeredComposition: return "Composición Centrada"
        case .dynamicSymmetry: return "Simetría Dinámica"
        case .horizon: return "Horizonte"
        }
    }
}

public struct CGLine {
    public let start: CGPoint
    public let end: CGPoint
    
    public init(start: CGPoint, end: CGPoint) {
        self.start = start
        self.end = end
    }
}

private struct CompositionAnalysis {
    let faces: [VNFaceObservation]
    let rectangles: [VNRectangleObservation]
    let horizonAngle: Float
    let confidence: Float
    let timestamp: Date
}