//
//  SmartAutoFocus.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 20-21: Smart Features Implementation - Auto-Focus Enhancement
//

import Foundation
import AVFoundation
import Vision
import CoreImage
import SwiftUI
import Combine

// MARK: - Smart Auto-Focus Assistant
@available(iOS 15.0, macOS 12.0, *)
@MainActor
public final class SmartAutoFocus: ObservableObject {
    
    // MARK: - Published Properties
    @Published public var focusMode: FocusMode = .aiGuided
    @Published public var currentFocusPoint: CGPoint?
    @Published public var focusConfidence: Float = 0.0
    @Published public var isAnalyzing = false
    @Published public var isEnabled = true
    @Published public var focusSuggestions: [FocusSuggestion] = []
    @Published public var trackingSubjects: [DetectedSubject] = []
    
    // MARK: - Private Properties
    private let visionQueue = DispatchQueue(label: "com.neuroviews.autofocus.vision", qos: .userInitiated)
    private var lastAnalysisTime: CFTimeInterval = 0
    private let minimumAnalysisInterval: CFTimeInterval = 0.2 // 5fps analysis for focus
    private var focusHistory: [FocusAnalysis] = []
    private let historyLimit = 10
    
    // Vision requests
    nonisolated(unsafe) private lazy var faceDetectionRequest = VNDetectFaceRectanglesRequest()
    nonisolated(unsafe) private lazy var objectDetectionRequest = VNDetectRectanglesRequest()
    nonisolated(unsafe) private lazy var bodyDetectionRequest = VNDetectHumanBodyPoseRequest()
    
    // Focus analyzer
    private var focusAnalyzer: FocusAnalyzer?
    
    // MARK: - Initialization
    public init() {
        setupVisionRequests()
        setupFocusAnalyzer()
    }
    
    private func setupVisionRequests() {
        // Configure face detection with landmarks
        faceDetectionRequest.revision = VNDetectFaceRectanglesRequestRevision3
        
        // Configure object detection
        objectDetectionRequest.minimumAspectRatio = 0.2
        objectDetectionRequest.maximumAspectRatio = 3.0
        objectDetectionRequest.minimumSize = 0.05
        objectDetectionRequest.minimumConfidence = 0.7
        
        // Body pose detection for full subject tracking
        if #available(iOS 14.0, *) {
            bodyDetectionRequest.revision = VNDetectHumanBodyPoseRequestRevision1
        }
    }
    
    private func setupFocusAnalyzer() {
        focusAnalyzer = FocusAnalyzer()
        focusAnalyzer?.configure(with: [
            "sharpnessThreshold": 0.7,
            "contrastWeight": 0.3,
            "edgeWeight": 0.4,
            "varianceWeight": 0.3
        ])
    }
    
    // MARK: - Public Methods
    
    /// Analyze frame and provide AI-guided focus suggestions
    nonisolated public func analyzeForFocus(_ pixelBuffer: CVPixelBuffer) {
        Task { @MainActor in
            guard self.isEnabled else { return }
            
            let currentTime = CACurrentMediaTime()
            guard currentTime - self.lastAnalysisTime >= self.minimumAnalysisInterval else { return }
            
            self.isAnalyzing = true
            
            Task.detached { [weak self] in
                guard let self = self else { return }
                
                let focusAnalysis = await self.performFocusAnalysis(pixelBuffer)
                let subjects = await self.detectSubjects(pixelBuffer)
                let suggestions = self.generateFocusSuggestions(analysis: focusAnalysis, subjects: subjects)
                let optimalFocusPoint = self.calculateOptimalFocusPoint(subjects: subjects, analysis: focusAnalysis)
                
                Task { @MainActor in
                    self.updateFocusResults(
                        analysis: focusAnalysis,
                        subjects: subjects,
                        suggestions: suggestions,
                        optimalPoint: optimalFocusPoint
                    )
                    
                    self.lastAnalysisTime = currentTime
                    self.isAnalyzing = false
                }
            }
        }
    }
    
    /// Apply AI-guided focus to camera device
    public func applyAIFocus(to device: AVCaptureDevice) throws {
        guard let optimalPoint = currentFocusPoint,
              device.isFocusPointOfInterestSupported,
              device.isFocusModeSupported(.autoFocus) else {
            throw FocusError.focusNotSupported
        }
        
        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        
        switch focusMode {
        case .aiGuided:
            device.focusPointOfInterest = optimalPoint
            device.focusMode = .autoFocus
            device.exposurePointOfInterest = optimalPoint
            device.exposureMode = .autoExpose
            
        case .subjectTracking:
            if let primarySubject = trackingSubjects.first(where: { $0.isPrimary }) {
                let subjectCenter = primarySubject.boundingBox.center
                device.focusPointOfInterest = subjectCenter
                device.focusMode = .continuousAutoFocus
                device.exposurePointOfInterest = subjectCenter
                device.exposureMode = .continuousAutoExposure
            }
            
        case .manual:
            // Manual focus controlled by user
            break
            
        case .hyperfocal:
            // Set to hyperfocal distance for landscape photography
            if device.isLockingFocusWithCustomLensPositionSupported {
                device.setFocusModeLocked(lensPosition: 0.0) { _ in }
            }
        }
    }
    
    /// Set focus mode
    public func setFocusMode(_ mode: FocusMode) {
        focusMode = mode
        regenerateSuggestions()
    }
    
    /// Enable/disable subject tracking
    public func toggleSubjectTracking() {
        if focusMode == .subjectTracking {
            focusMode = .aiGuided
        } else {
            focusMode = .subjectTracking
        }
    }
    
    // MARK: - Private Analysis Methods
    
    nonisolated private func performFocusAnalysis(_ pixelBuffer: CVPixelBuffer) async -> FocusAnalysis {
        guard let analyzer = await self.focusAnalyzer else {
            return FocusAnalysis.empty
        }
        
        guard let analysisResult = analyzer.analyze(frame: pixelBuffer) else {
            return FocusAnalysis.empty
        }
        
        let sharpness = analysisResult.data["sharpness"] as? Float ?? 0.0
        let contrast = analysisResult.data["contrast"] as? Float ?? 0.0
        let edgeStrength = analysisResult.data["edgeStrength"] as? Float ?? 0.0
        let focusScore = analysisResult.data["focusScore"] as? Float ?? 0.0
        
        return FocusAnalysis(
            sharpness: sharpness,
            contrast: contrast,
            edgeStrength: edgeStrength,
            focusScore: focusScore,
            confidence: min(1.0, (sharpness + contrast + edgeStrength) / 3.0),
            timestamp: Date()
        )
    }
    
    nonisolated private func detectSubjects(_ pixelBuffer: CVPixelBuffer) async -> [DetectedSubject] {
        let imageRequestHandler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        var subjects: [DetectedSubject] = []
        
        do {
            // Detect faces
            try imageRequestHandler.perform([faceDetectionRequest])
            if let faces = faceDetectionRequest.results {
                for face in faces {
                    subjects.append(DetectedSubject(
                        type: .face,
                        boundingBox: face.boundingBox,
                        confidence: face.confidence,
                        isPrimary: subjects.isEmpty, // First face is primary
                        trackingID: UUID()
                    ))
                }
            }
            
            // Detect human bodies
            if #available(iOS 14.0, *) {
                try imageRequestHandler.perform([bodyDetectionRequest])
                if let bodies = bodyDetectionRequest.results {
                    for body in bodies {
                        // Convert body pose to bounding box
                        if let points = try? body.recognizedPoints(.all) {
                            let boundingBox = calculateBoundingBox(from: points)
                            subjects.append(DetectedSubject(
                                type: .humanBody,
                                boundingBox: boundingBox,
                                confidence: body.confidence,
                                isPrimary: subjects.filter({ $0.type == .humanBody }).isEmpty,
                                trackingID: UUID()
                            ))
                        }
                    }
                }
            }
            
            // Detect other objects/rectangles
            try imageRequestHandler.perform([objectDetectionRequest])
            if let objects = objectDetectionRequest.results {
                for object in objects {
                    subjects.append(DetectedSubject(
                        type: .object,
                        boundingBox: object.boundingBox,
                        confidence: object.confidence,
                        isPrimary: false,
                        trackingID: UUID()
                    ))
                }
            }
            
        } catch {
            print("Subject detection error: \(error)")
        }
        
        return subjects.sorted { $0.confidence > $1.confidence }
    }
    
    nonisolated private func calculateBoundingBox(from points: [VNHumanBodyPoseObservation.JointName: VNRecognizedPoint]) -> CGRect {
        guard !points.isEmpty else { return .zero }
        
        let validPoints = points.values.filter { $0.confidence > 0.5 }
        guard !validPoints.isEmpty else { return .zero }
        
        let xValues = validPoints.map { $0.location.x }
        let yValues = validPoints.map { $0.location.y }
        
        let minX = xValues.min() ?? 0
        let maxX = xValues.max() ?? 0
        let minY = yValues.min() ?? 0
        let maxY = yValues.max() ?? 0
        
        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }
    
    nonisolated private func generateFocusSuggestions(analysis: FocusAnalysis, subjects: [DetectedSubject]) -> [FocusSuggestion] {
        var suggestions: [FocusSuggestion] = []
        
        // Low focus quality suggestion
        if analysis.focusScore < 0.6 {
            suggestions.append(FocusSuggestion(
                type: .focusAdjustment,
                message: "Ajustar enfoque para mejorar la nitidez",
                confidence: 1.0 - analysis.focusScore,
                targetPoint: calculateOptimalFocusPoint(subjects: subjects, analysis: analysis)
            ))
        }
        
        // Subject-based suggestions
        if let primarySubject = subjects.first(where: { $0.isPrimary }) {
            if primarySubject.confidence > 0.8 {
                suggestions.append(FocusSuggestion(
                    type: .subjectFocus,
                    message: "Enfocar en el sujeto principal detectado",
                    confidence: primarySubject.confidence,
                    targetPoint: primarySubject.boundingBox.center
                ))
            }
        }
        
        // Multiple subjects suggestion
        if subjects.filter({ $0.type == .face }).count > 1 {
            suggestions.append(FocusSuggestion(
                type: .multipleSubjects,
                message: "Múltiples rostros detectados - seleccionar sujeto principal",
                confidence: 0.8,
                targetPoint: nil
            ))
        }
        
        // Background focus suggestion
        if subjects.isEmpty && analysis.contrast > 0.7 {
            suggestions.append(FocusSuggestion(
                type: .backgroundFocus,
                message: "Considerar enfoque de fondo para paisajes",
                confidence: analysis.contrast,
                targetPoint: CGPoint(x: 0.5, y: 0.5)
            ))
        }
        
        return suggestions
    }
    
    nonisolated private func calculateOptimalFocusPoint(subjects: [DetectedSubject], analysis: FocusAnalysis) -> CGPoint {
        // Priority 1: Primary subject (faces)
        if let primaryFace = subjects.first(where: { $0.type == .face && $0.isPrimary }) {
            return primaryFace.boundingBox.center
        }
        
        // Priority 2: Any face
        if let anyFace = subjects.first(where: { $0.type == .face }) {
            return anyFace.boundingBox.center
        }
        
        // Priority 3: Human body
        if let humanBody = subjects.first(where: { $0.type == .humanBody }) {
            return humanBody.boundingBox.center
        }
        
        // Priority 4: Highest confidence object
        if let primaryObject = subjects.first {
            return primaryObject.boundingBox.center
        }
        
        // Default: Center with slight bias to rule of thirds
        return CGPoint(x: 0.5, y: 0.4) // Slightly above center following rule of thirds
    }
    
    @MainActor
    private func updateFocusResults(analysis: FocusAnalysis, subjects: [DetectedSubject], suggestions: [FocusSuggestion], optimalPoint: CGPoint) {
        // Update focus history
        focusHistory.append(analysis)
        if focusHistory.count > historyLimit {
            focusHistory.removeFirst()
        }
        
        // Update published properties
        trackingSubjects = subjects
        focusSuggestions = suggestions
        currentFocusPoint = optimalPoint
        focusConfidence = analysis.confidence
    }
    
    private func regenerateSuggestions() {
        // Regenerate suggestions based on current focus mode
        // This could be enhanced to provide mode-specific suggestions
    }
    
    // MARK: - Focus Quality Analysis
    
    public func getFocusQualityScore() -> Float {
        guard let latestAnalysis = focusHistory.last else { return 0.0 }
        return latestAnalysis.focusScore
    }
    
    public func getFocusTrend() -> FocusTrend {
        guard focusHistory.count >= 3 else { return .stable }
        
        let recent = Array(focusHistory.suffix(3))
        let trend = recent.last!.focusScore - recent.first!.focusScore
        
        if trend > 0.1 {
            return .improving
        } else if trend < -0.1 {
            return .declining
        } else {
            return .stable
        }
    }
}

// MARK: - Supporting Types

public enum FocusMode: String, CaseIterable {
    case aiGuided = "aiGuided"
    case subjectTracking = "subjectTracking"
    case manual = "manual"
    case hyperfocal = "hyperfocal"
    
    public var displayName: String {
        switch self {
        case .aiGuided: return "IA Guiada"
        case .subjectTracking: return "Seguimiento de Sujeto"
        case .manual: return "Manual"
        case .hyperfocal: return "Hiperfocal"
        }
    }
}

public struct FocusSuggestion {
    public let type: SuggestionType
    public let message: String
    public let confidence: Float
    public let targetPoint: CGPoint?
    
    public enum SuggestionType {
        case focusAdjustment
        case subjectFocus
        case multipleSubjects
        case backgroundFocus
        case depthOfField
    }
}

public struct DetectedSubject {
    public let type: SubjectType
    public let boundingBox: CGRect
    public let confidence: Float
    public let isPrimary: Bool
    public let trackingID: UUID
    
    public enum SubjectType {
        case face
        case humanBody
        case object
        case animal
    }
}

public struct FocusAnalysis {
    public let sharpness: Float
    public let contrast: Float
    public let edgeStrength: Float
    public let focusScore: Float
    public let confidence: Float
    public let timestamp: Date
    
    static let empty = FocusAnalysis(
        sharpness: 0.0,
        contrast: 0.0,
        edgeStrength: 0.0,
        focusScore: 0.0,
        confidence: 0.0,
        timestamp: Date()
    )
}

public enum FocusTrend {
    case improving
    case stable
    case declining
}

public enum FocusError: LocalizedError {
    case focusNotSupported
    case deviceNotAvailable
    case configurationFailed
    
    public var errorDescription: String? {
        switch self {
        case .focusNotSupported:
            return "El enfoque automático no está disponible"
        case .deviceNotAvailable:
            return "Dispositivo de cámara no disponible"
        case .configurationFailed:
            return "Error en la configuración del enfoque"
        }
    }
}

// MARK: - Extensions

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: midX, y: midY)
    }
}