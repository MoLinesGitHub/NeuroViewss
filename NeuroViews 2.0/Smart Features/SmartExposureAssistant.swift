//
//  SmartExposureAssistant.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 20-21: Smart Features Implementation - Smart Exposure System
//

import Foundation
import CoreImage
import AVFoundation
import SwiftUI
import Combine

// MARK: - Smart Exposure Assistant
@available(iOS 15.0, macOS 12.0, *)
@MainActor
public final class SmartExposureAssistant: ObservableObject {
    
    // MARK: - Published Properties
    @Published public private(set) var currentSuggestion: ExposureSuggestion?
    @Published public private(set) var exposureHistory: [ExposureReading] = []
    @Published public private(set) var isAnalyzing = false
    @Published public var isEnabled = true
    @Published public var suggestionMode: SuggestionMode = .balanced
    
    // MARK: - Private Properties
    private let exposureAnalyzer = ExposureAnalyzer()
    private let analysisQueue = DispatchQueue(label: "com.neuroviews.exposure.analysis", qos: .userInitiated)
    private var lastAnalysisTime: CFTimeInterval = 0
    private let minimumAnalysisInterval: CFTimeInterval = 0.5 // 500ms between analyses
    private let historyLimit = 20
    
    // MARK: - Dependencies
    private let nvaiKit = NVAIKit.shared
    
    // MARK: - Initialization
    public init() {
        setupAnalyzer()
    }
    
    private func setupAnalyzer() {
        let settings: [String: Any] = [
            "targetEV": 0.0,
            "analysisResolution": CGSize(width: 1920, height: 1080),
            "histogramBins": 256,
            "enableSceneDetection": true
        ]
        exposureAnalyzer.configure(with: settings)
    }
    
    // MARK: - Public Methods
    
    /// Analyze frame and provide smart exposure suggestions
    nonisolated public func analyzeFrame(_ pixelBuffer: CVPixelBuffer) {
        Task { @MainActor in
            guard self.isEnabled else { return }
            
            let currentTime = CACurrentMediaTime()
            guard currentTime - self.lastAnalysisTime >= self.minimumAnalysisInterval else { return }
            
            self.isAnalyzing = true
            
            Task.detached { [weak self] in
                guard let self = self else { return }
                
                // Perform exposure analysis
                guard let analysis = self.exposureAnalyzer.analyze(frame: pixelBuffer) else {
                    Task { @MainActor in
                        self.isAnalyzing = false
                    }
                    return
                }
                
                let reading = ExposureReading(
                    timestamp: Date(),
                    evValue: self.extractEVValue(from: analysis),
                    brightness: self.extractBrightness(from: analysis),
                    contrast: self.extractContrast(from: analysis),
                    clipping: self.extractClipping(from: analysis)
                )
                
                Task { @MainActor in
                    self.processExposureReading(reading)
                    self.lastAnalysisTime = currentTime
                    self.isAnalyzing = false
                }
            }
        }
    }
    
    /// Get manual exposure recommendation for current conditions
    public func getManualExposureRecommendation() -> ManualExposureRecommendation? {
        guard let currentReading = exposureHistory.last else { return nil }
        
        let recommendation = calculateManualExposureSettings(from: currentReading)
        return recommendation
    }
    
    /// Apply suggested exposure settings to camera
    public func applySuggestion(_ suggestion: ExposureSuggestion, to device: AVCaptureDevice) throws {
        try device.lockForConfiguration()
        
        defer { device.unlockForConfiguration() }
        
        switch suggestion.type {
        case .automatic:
            device.exposureMode = .continuousAutoExposure
            
        case .manual(let settings):
            #if os(iOS) || os(tvOS)
            if device.isExposureModeSupported(.custom) {
                device.exposureMode = .custom
                device.setExposureModeCustom(duration: settings.shutterSpeed,
                                           iso: settings.iso) { _ in }
            }
            #else
            // macOS doesn't support custom exposure settings
            print("Manual exposure not supported on macOS")
            #endif
            
        case .exposureCompensation(let compensation):
            if device.isExposureModeSupported(.continuousAutoExposure) {
                device.exposureMode = .continuousAutoExposure
                #if os(iOS) || os(tvOS)
                device.setExposureTargetBias(compensation) { _ in }
                #else
                print("Exposure compensation not supported on macOS")
                #endif
            }
        }
    }
    
    // MARK: - Private Analysis Methods
    
    private func processExposureReading(_ reading: ExposureReading) {
        // Add to history
        exposureHistory.append(reading)
        
        // Maintain history limit
        if exposureHistory.count > historyLimit {
            exposureHistory.removeFirst()
        }
        
        // Generate suggestion based on current reading and history
        currentSuggestion = generateExposureSuggestion(from: reading)
    }
    
    private func generateExposureSuggestion(from reading: ExposureReading) -> ExposureSuggestion {
        let analysisContext = createAnalysisContext(from: reading)
        
        switch suggestionMode {
        case .balanced:
            return generateBalancedSuggestion(reading: reading, context: analysisContext)
        case .creative:
            return generateCreativeSuggestion(reading: reading, context: analysisContext)
        case .technical:
            return generateTechnicalSuggestion(reading: reading, context: analysisContext)
        }
    }
    
    private func generateBalancedSuggestion(reading: ExposureReading, context: AnalysisContext) -> ExposureSuggestion {
        // Check for common exposure issues
        if reading.clipping.highlights > 0.1 {
            // Overexposure detected
            return ExposureSuggestion(
                type: .exposureCompensation(-1.0),
                confidence: 0.8,
                reason: "Reducir exposición para evitar sobreexposición en altas luces",
                impact: .significant,
                priority: .high
            )
        }
        
        if reading.brightness < 0.2 && reading.clipping.shadows < 0.05 {
            // Underexposure with room to recover shadows
            return ExposureSuggestion(
                type: .exposureCompensation(0.7),
                confidence: 0.75,
                reason: "Aumentar exposición para mejorar detalle en sombras",
                impact: .moderate,
                priority: .medium
            )
        }
        
        if abs(reading.evValue) < 0.5 && reading.contrast > 0.6 {
            // Well exposed but could benefit from fine-tuning
            return ExposureSuggestion(
                type: .automatic,
                confidence: 0.6,
                reason: "Exposición adecuada - usar modo automático",
                impact: .minor,
                priority: .low
            )
        }
        
        // Default to current settings
        return ExposureSuggestion(
            type: .automatic,
            confidence: 0.5,
            reason: "Exposición actual es aceptable",
            impact: .none,
            priority: .low
        )
    }
    
    private func generateCreativeSuggestion(reading: ExposureReading, context: AnalysisContext) -> ExposureSuggestion {
        // Creative mode focuses on mood and artistic expression
        
        if context.sceneType == .lowLight {
            let manualSettings = ManualExposureSettings(
                shutterSpeed: CMTime(seconds: 1.0/30.0, preferredTimescale: 600),
                iso: 1600,
                aperture: 2.8
            )
            
            return ExposureSuggestion(
                type: .manual(manualSettings),
                confidence: 0.85,
                reason: "Configuración manual para capturar atmósfera de poca luz",
                impact: .dramatic,
                priority: .high
            )
        }
        
        if context.hasBacklight {
            return ExposureSuggestion(
                type: .exposureCompensation(-0.7),
                confidence: 0.8,
                reason: "Subexposición creativa para siluetas dramáticas",
                impact: .significant,
                priority: .medium
            )
        }
        
        return generateBalancedSuggestion(reading: reading, context: context)
    }
    
    private func generateTechnicalSuggestion(reading: ExposureReading, context: AnalysisContext) -> ExposureSuggestion {
        // Technical mode provides precise manual control recommendations
        
        let optimalSettings = calculateOptimalManualSettings(reading: reading, context: context)
        
        return ExposureSuggestion(
            type: .manual(optimalSettings),
            confidence: 0.9,
            reason: "Configuración manual técnica para máxima calidad",
            impact: .significant,
            priority: .high
        )
    }
    
    private func calculateOptimalManualSettings(reading: ExposureReading, context: AnalysisContext) -> ManualExposureSettings {
        // Calculate optimal manual settings based on scene analysis
        
        let baseISO: Float = context.sceneType == .lowLight ? 800 : 200
        let baseShutterSpeed = CMTime(seconds: 1.0/120.0, preferredTimescale: 600)
        
        // Adjust based on exposure reading
        let targetEV = reading.evValue + (reading.brightness < 0.4 ? 1.0 : 0.0)
        let adjustedISO = min(3200, max(100, baseISO * pow(2, Float(targetEV))))
        
        return ManualExposureSettings(
            shutterSpeed: baseShutterSpeed,
            iso: adjustedISO,
            aperture: 2.8
        )
    }
    
    private func calculateManualExposureSettings(from reading: ExposureReading) -> ManualExposureRecommendation {
        // Simplified manual exposure calculation
        let recommendedISO = calculateRecommendedISO(brightness: reading.brightness)
        let recommendedShutterSpeed = calculateRecommendedShutterSpeed(evValue: reading.evValue)
        
        return ManualExposureRecommendation(
            iso: recommendedISO,
            shutterSpeed: recommendedShutterSpeed,
            aperture: 2.8, // Fixed for now
            confidence: 0.75
        )
    }
    
    private func calculateRecommendedISO(brightness: Float) -> Float {
        switch brightness {
        case 0.0..<0.2: return 1600 // Very dark
        case 0.2..<0.4: return 800  // Dark
        case 0.4..<0.6: return 400  // Medium
        case 0.6..<0.8: return 200  // Bright
        default: return 100         // Very bright
        }
    }
    
    private func calculateRecommendedShutterSpeed(evValue: Float) -> CMTime {
        // Base shutter speed calculation
        let baseSpeed = 1.0/120.0 // 1/120s
        let adjustment = pow(2.0, Double(-evValue))
        let adjustedSpeed = baseSpeed * adjustment
        
        // Clamp to reasonable values
        let clampedSpeed = max(1.0/4000.0, min(1.0/30.0, adjustedSpeed))
        
        return CMTime(seconds: clampedSpeed, preferredTimescale: 600)
    }
    
    // MARK: - Helper Methods
    
    nonisolated private func extractEVValue(from analysis: AIAnalysis) -> Float {
        return analysis.data["evValue"] as? Float ?? 0.0
    }
    
    nonisolated private func extractBrightness(from analysis: AIAnalysis) -> Float {
        return analysis.data["brightness"] as? Float ?? 0.5
    }
    
    nonisolated private func extractContrast(from analysis: AIAnalysis) -> Float {
        return analysis.data["contrast"] as? Float ?? 0.5
    }
    
    nonisolated private func extractClipping(from analysis: AIAnalysis) -> ClippingInfo {
        let highlightClipping = analysis.data["highlightClipping"] as? Float ?? 0.0
        let shadowClipping = analysis.data["shadowClipping"] as? Float ?? 0.0
        
        return ClippingInfo(highlights: highlightClipping, shadows: shadowClipping)
    }
    
    private func createAnalysisContext(from reading: ExposureReading) -> AnalysisContext {
        // Determine scene type based on exposure characteristics
        let sceneType: SceneType
        if reading.brightness < 0.3 {
            sceneType = .lowLight
        } else if reading.brightness > 0.8 {
            sceneType = .brightLight
        } else {
            sceneType = .normal
        }
        
        let hasBacklight = reading.contrast > 0.7 && reading.clipping.highlights > 0.05
        
        return AnalysisContext(
            sceneType: sceneType,
            hasBacklight: hasBacklight,
            timeOfDay: determineTimeOfDay()
        )
    }
    
    private func determineTimeOfDay() -> TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6..<10: return .morning
        case 10..<16: return .midday
        case 16..<19: return .afternoon
        case 19..<22: return .evening
        default: return .night
        }
    }
}

// MARK: - Supporting Types

public struct ExposureSuggestion {
    public let type: ExposureSuggestionType
    public let confidence: Float
    public let reason: String
    public let impact: ImpactLevel
    public let priority: SuggestionPriority
    
    public enum ImpactLevel {
        case none, minor, moderate, significant, dramatic
    }
}

public enum ExposureSuggestionType {
    case automatic
    case manual(ManualExposureSettings)
    case exposureCompensation(Float) // EV adjustment
}

public struct ManualExposureSettings {
    public let shutterSpeed: CMTime
    public let iso: Float
    public let aperture: Float
}

public struct ExposureReading {
    public let timestamp: Date
    public let evValue: Float
    public let brightness: Float
    public let contrast: Float
    public let clipping: ClippingInfo
}

public struct ClippingInfo {
    public let highlights: Float // 0.0 = no clipping, 1.0 = full clipping
    public let shadows: Float
}

public struct ManualExposureRecommendation {
    public let iso: Float
    public let shutterSpeed: CMTime
    public let aperture: Float
    public let confidence: Float
}

public enum SuggestionMode: String, CaseIterable {
    case balanced = "balanced"
    case creative = "creative"
    case technical = "technical"
    
    public var displayName: String {
        switch self {
        case .balanced: return "Balanceado"
        case .creative: return "Creativo"
        case .technical: return "Técnico"
        }
    }
}


private struct AnalysisContext {
    let sceneType: SceneType
    let hasBacklight: Bool
    let timeOfDay: TimeOfDay
}

private enum SceneType {
    case lowLight, normal, brightLight
}

private enum TimeOfDay {
    case morning, midday, afternoon, evening, night
}

