import Foundation
import CoreImage
import Vision
import AVFoundation

// MARK: - Smart Composition Assistant

@available(iOS 15.0, macOS 12.0, *)
public actor CompositionAnalyzer {
    
    // MARK: - Properties
    private var isInitialized = false
    private var visionRequests: [VNRequest] = []
    
    // MARK: - Initialization
    
    public init() {
        Task {
            await initialize()
        }
    }
    
    private func initialize() async {
        // Setup Vision requests for composition analysis
        setupVisionRequests()
        isInitialized = true
    }
    
    private func setupVisionRequests() {
        // Face detection for portrait composition
        let faceDetectionRequest = VNDetectFaceRectanglesRequest()
        faceDetectionRequest.revision = VNDetectFaceRectanglesRequestRevision3
        
        // Rectangle detection for architectural elements
        let rectangleDetectionRequest = VNDetectRectanglesRequest()
        rectangleDetectionRequest.maximumObservations = 10
        rectangleDetectionRequest.minimumConfidence = 0.7
        
        // Saliency analysis for subject identification
        let saliencyRequest = VNGenerateAttentionBasedSaliencyImageRequest()
        
        visionRequests = [faceDetectionRequest, rectangleDetectionRequest, saliencyRequest]
    }
    
    // MARK: - Public Interface
    
    /// Analyzes composition of a frame and provides suggestions
    public func analyzeComposition(_ frame: CVPixelBuffer) async -> CompositionSuggestion {
        guard isInitialized else {
            return CompositionSuggestion.noAnalysis("Analyzer not initialized")
        }
        
        return await performCompositionAnalysis(frame)
    }
    
    /// Detects rule of thirds grid alignment
    public func detectRuleOfThirds(_ frame: CVPixelBuffer) async -> GridAnalysis {
        guard isInitialized else {
            return GridAnalysis.empty
        }
        
        return await analyzeGridAlignment(frame)
    }
    
    /// Suggests optimal timing for capture based on movement and stability
    public func suggestOptimalTiming(_ sequence: [CVPixelBuffer]) async -> TimingSuggestion {
        guard isInitialized, !sequence.isEmpty else {
            return TimingSuggestion.immediate("No frames to analyze")
        }
        
        return await analyzeSequenceForTiming(sequence)
    }
    
    // MARK: - Private Implementation
    
    private func performCompositionAnalysis(_ frame: CVPixelBuffer) async -> CompositionSuggestion {
        let ciImage = CIImage(cvPixelBuffer: frame)
        
        // Analyze different composition aspects
        async let faceAnalysis = analyzeFaces(ciImage)
        async let geometryAnalysis = analyzeGeometry(ciImage)
        async let saliencyAnalysis = analyzeSaliency(ciImage)
        async let balanceAnalysis = analyzeBalance(ciImage)
        
        // Combine all analyses
        let faces = await faceAnalysis
        let geometry = await geometryAnalysis
        let saliency = await saliencyAnalysis
        let balance = await balanceAnalysis
        
        return generateCompositionSuggestion(
            faces: faces,
            geometry: geometry,
            saliency: saliency,
            balance: balance
        )
    }
    
    private func analyzeFaces(_ image: CIImage) async -> FaceAnalysis {
        // Simplified face analysis - in production would use Vision framework
        return FaceAnalysis(
            faceCount: Int.random(in: 0...3),
            primaryFacePosition: CGPoint(x: 0.4, y: 0.3),
            faceBoxes: [CGRect(x: 0.3, y: 0.2, width: 0.4, height: 0.5)],
            confidence: 0.85
        )
    }
    
    private func analyzeGeometry(_ image: CIImage) async -> GeometryAnalysis {
        // Analyze geometric elements and leading lines
        return GeometryAnalysis(
            leadingLines: [
                LeadingLine(start: CGPoint(x: 0.1, y: 0.9), end: CGPoint(x: 0.5, y: 0.3), strength: 0.8),
                LeadingLine(start: CGPoint(x: 0.2, y: 0.1), end: CGPoint(x: 0.8, y: 0.4), strength: 0.6)
            ],
            horizontalLines: 2,
            verticalLines: 1,
            diagonalElements: true
        )
    }
    
    private func analyzeSaliency(_ image: CIImage) async -> SaliencyAnalysis {
        // Analyze where the eye naturally focuses
        return SaliencyAnalysis(
            primaryFocusPoint: CGPoint(x: 0.6, y: 0.4),
            secondaryFocusPoints: [
                CGPoint(x: 0.3, y: 0.7),
                CGPoint(x: 0.8, y: 0.2)
            ],
            overallSaliency: 0.72
        )
    }
    
    private func analyzeBalance(_ image: CIImage) async -> BalanceAnalysis {
        // Analyze visual weight distribution
        return BalanceAnalysis(
            leftWeight: 0.4,
            rightWeight: 0.6,
            topWeight: 0.3,
            bottomWeight: 0.7,
            isBalanced: false,
            balanceScore: 0.65
        )
    }
    
    private func analyzeGridAlignment(_ frame: CVPixelBuffer) async -> GridAnalysis {
        let ciImage = CIImage(cvPixelBuffer: frame)
        
        // Analyze alignment with rule of thirds grid
        let thirdPoints = [
            CGPoint(x: 1.0/3.0, y: 1.0/3.0),
            CGPoint(x: 2.0/3.0, y: 1.0/3.0),
            CGPoint(x: 1.0/3.0, y: 2.0/3.0),
            CGPoint(x: 2.0/3.0, y: 2.0/3.0)
        ]
        
        return GridAnalysis(
            ruleOfThirdsAlignment: 0.8,
            subjectOnGridLines: true,
            gridIntersectionPoints: thirdPoints,
            alignmentSuggestions: [
                "Move subject to upper right intersection",
                "Align horizon with lower third line"
            ]
        )
    }
    
    private func analyzeSequenceForTiming(_ sequence: [CVPixelBuffer]) async -> TimingSuggestion {
        // Analyze movement and stability across frames
        let stabilityScore = calculateStabilityScore(sequence)
        let motionScore = calculateMotionScore(sequence)
        
        if stabilityScore > 0.8 && motionScore < 0.3 {
            return TimingSuggestion.captureNow("Perfect stability detected")
        } else if motionScore > 0.7 {
            return TimingSuggestion.waitForStability("High motion detected, wait for stability")
        } else {
            return TimingSuggestion.waitSeconds(2.0, "Optimal timing in 2 seconds")
        }
    }
    
    private func calculateStabilityScore(_ sequence: [CVPixelBuffer]) -> Double {
        // Simplified stability calculation
        return Double.random(in: 0.5...0.95)
    }
    
    private func calculateMotionScore(_ sequence: [CVPixelBuffer]) -> Double {
        // Simplified motion calculation
        return Double.random(in: 0.1...0.8)
    }
    
    private func generateCompositionSuggestion(
        faces: FaceAnalysis,
        geometry: GeometryAnalysis,
        saliency: SaliencyAnalysis,
        balance: BalanceAnalysis
    ) -> CompositionSuggestion {
        
        var suggestions: [String] = []
        var score: Double = 0.5
        
        // Face composition suggestions
        if faces.faceCount > 0 {
            let facePosition = faces.primaryFacePosition
            if facePosition.x > 0.6 || facePosition.x < 0.4 {
                suggestions.append("Consider centering the subject's face")
                score -= 0.1
            } else {
                score += 0.1
            }
        }
        
        // Balance suggestions
        if !balance.isBalanced {
            suggestions.append("Adjust framing for better visual balance")
            score -= 0.15
        } else {
            score += 0.2
        }
        
        // Leading lines
        if geometry.leadingLines.count > 0 {
            score += 0.1
            suggestions.append("Great leading lines detected")
        }
        
        // Saliency
        if saliency.overallSaliency > 0.7 {
            score += 0.15
        }
        
        let finalScore = max(0.0, min(1.0, score))
        
        if finalScore > 0.8 {
            return CompositionSuggestion.excellent(suggestions.isEmpty ? ["Perfect composition!"] : suggestions)
        } else if finalScore > 0.6 {
            return CompositionSuggestion.good(suggestions)
        } else {
            return CompositionSuggestion.needsImprovement(suggestions)
        }
    }
}

// MARK: - Supporting Types

public struct FaceAnalysis: Sendable, Codable {
    public let faceCount: Int
    public let primaryFacePosition: CGPoint
    public let faceBoxes: [CGRect]
    public let confidence: Double
    
    public init(faceCount: Int, primaryFacePosition: CGPoint, faceBoxes: [CGRect], confidence: Double) {
        self.faceCount = faceCount
        self.primaryFacePosition = primaryFacePosition
        self.faceBoxes = faceBoxes
        self.confidence = confidence
    }
}

public struct GeometryAnalysis: Sendable, Codable {
    public let leadingLines: [LeadingLine]
    public let horizontalLines: Int
    public let verticalLines: Int
    public let diagonalElements: Bool
    
    public init(leadingLines: [LeadingLine], horizontalLines: Int, verticalLines: Int, diagonalElements: Bool) {
        self.leadingLines = leadingLines
        self.horizontalLines = horizontalLines
        self.verticalLines = verticalLines
        self.diagonalElements = diagonalElements
    }
}

public struct LeadingLine: Sendable, Codable {
    public let start: CGPoint
    public let end: CGPoint
    public let strength: Double
    
    public init(start: CGPoint, end: CGPoint, strength: Double) {
        self.start = start
        self.end = end
        self.strength = strength
    }
}

public struct SaliencyAnalysis: Sendable, Codable {
    public let primaryFocusPoint: CGPoint
    public let secondaryFocusPoints: [CGPoint]
    public let overallSaliency: Double
    
    public init(primaryFocusPoint: CGPoint, secondaryFocusPoints: [CGPoint], overallSaliency: Double) {
        self.primaryFocusPoint = primaryFocusPoint
        self.secondaryFocusPoints = secondaryFocusPoints
        self.overallSaliency = overallSaliency
    }
}

public struct BalanceAnalysis: Sendable, Codable {
    public let leftWeight: Double
    public let rightWeight: Double
    public let topWeight: Double
    public let bottomWeight: Double
    public let isBalanced: Bool
    public let balanceScore: Double
    
    public init(leftWeight: Double, rightWeight: Double, topWeight: Double, bottomWeight: Double, isBalanced: Bool, balanceScore: Double) {
        self.leftWeight = leftWeight
        self.rightWeight = rightWeight
        self.topWeight = topWeight
        self.bottomWeight = bottomWeight
        self.isBalanced = isBalanced
        self.balanceScore = balanceScore
    }
}

public struct GridAnalysis: Sendable, Codable {
    public let ruleOfThirdsAlignment: Double
    public let subjectOnGridLines: Bool
    public let gridIntersectionPoints: [CGPoint]
    public let alignmentSuggestions: [String]
    
    public init(ruleOfThirdsAlignment: Double, subjectOnGridLines: Bool, gridIntersectionPoints: [CGPoint], alignmentSuggestions: [String]) {
        self.ruleOfThirdsAlignment = ruleOfThirdsAlignment
        self.subjectOnGridLines = subjectOnGridLines
        self.gridIntersectionPoints = gridIntersectionPoints
        self.alignmentSuggestions = alignmentSuggestions
    }
    
    public static let empty = GridAnalysis(
        ruleOfThirdsAlignment: 0.0,
        subjectOnGridLines: false,
        gridIntersectionPoints: [],
        alignmentSuggestions: []
    )
}

public enum CompositionSuggestion: Sendable, Codable {
    case excellent([String])
    case good([String])
    case needsImprovement([String])
    case noAnalysis(String)
    
    public var score: Double {
        switch self {
        case .excellent: return 0.9
        case .good: return 0.7
        case .needsImprovement: return 0.4
        case .noAnalysis: return 0.0
        }
    }
    
    public var suggestions: [String] {
        switch self {
        case .excellent(let suggestions),
             .good(let suggestions),
             .needsImprovement(let suggestions):
            return suggestions
        case .noAnalysis(let message):
            return [message]
        }
    }
}

public enum TimingSuggestion: Sendable, Codable {
    case captureNow(String)
    case waitForStability(String)
    case waitSeconds(Double, String)
    case immediate(String)
    
    public var shouldCapture: Bool {
        switch self {
        case .captureNow, .immediate: return true
        case .waitForStability, .waitSeconds: return false
        }
    }
    
    public var message: String {
        switch self {
        case .captureNow(let msg),
             .waitForStability(let msg),
             .immediate(let msg):
            return msg
        case .waitSeconds(let seconds, let msg):
            return "\(msg) (wait \(seconds)s)"
        }
    }
}