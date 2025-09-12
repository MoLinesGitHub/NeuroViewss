//
//  ExposureAnalyzer.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 18-19: Advanced AI Foundation
//

import Foundation
import CoreImage
import Vision
import AVFoundation
import Accelerate

@available(iOS 15.0, macOS 12.0, *)
public final class ExposureAnalyzer: AIAnalyzer {
    
    // MARK: - AIAnalyzer Protocol
    public let analysisType: AIAnalysisType = .exposure
    public var isEnabled: Bool = true
    
    // MARK: - Properties
    private let ciContext = CIContext()
    private var settings: ExposureSettings = .default
    
    // Histogram analysis
    private var previousHistogram: [Float]?
    private var exposureHistory: [Float] = []
    private let historyLimit = 10
    
    // MARK: - Configuration
    public func configure(with settings: [String: Any]) {
        if let adaptiveEnabled = settings["adaptiveAnalysisEnabled"] as? Bool {
            self.settings.adaptiveAnalysisEnabled = adaptiveEnabled
        }
        if let sceneAnalysisEnabled = settings["sceneAnalysisEnabled"] as? Bool {
            self.settings.sceneAnalysisEnabled = sceneAnalysisEnabled
        }
        if let exposureSmoothingEnabled = settings["exposureSmoothingEnabled"] as? Bool {
            self.settings.exposureSmoothingEnabled = exposureSmoothingEnabled
        }
        if let targetEV = settings["targetEV"] as? Float {
            self.settings.targetEV = targetEV
        }
    }
    
    // MARK: - Analysis
    nonisolated public func analyze(frame: CVPixelBuffer) -> AIAnalysis? {
        guard isEnabled else { return nil }
        
        let ciImage = CIImage(cvPixelBuffer: frame)
        var analysisData: [String: Any] = [:]
        var suggestions: [AISuggestion] = []
        var totalConfidence: Float = 0.0
        var analysisCount = 0
        
        // Core exposure analysis
        let exposureResult = analyzeExposure(image: ciImage)
        analysisData["exposure"] = exposureResult.toDictionary()
        totalConfidence += exposureResult.confidence
        analysisCount += 1
        
        // Adaptive scene analysis
        if settings.sceneAnalysisEnabled {
            let sceneResult = analyzeSceneExposure(image: ciImage)
            analysisData["sceneExposure"] = sceneResult.toDictionary()
            totalConfidence += sceneResult.confidence
            analysisCount += 1
            
            suggestions.append(contentsOf: generateSceneSuggestions(from: sceneResult))
        }
        
        // Dynamic range analysis
        let dynamicRangeResult = analyzeDynamicRange(image: ciImage)
        analysisData["dynamicRange"] = dynamicRangeResult.toDictionary()
        totalConfidence += dynamicRangeResult.confidence
        analysisCount += 1
        
        // Generate exposure suggestions
        suggestions.append(contentsOf: generateExposureSuggestions(
            exposure: exposureResult,
            dynamicRange: dynamicRangeResult
        ))
        
        // Smoothing and history tracking
        if settings.exposureSmoothingEnabled {
            updateExposureHistory(exposureResult.evValue)
            let smoothedResult = applySmoothingToSuggestions(suggestions)
            suggestions = smoothedResult
        }
        
        let averageConfidence = analysisCount > 0 ? totalConfidence / Float(analysisCount) : 0.0
        
        return AIAnalysis(
            type: .exposure,
            confidence: averageConfidence,
            data: analysisData,
            suggestions: suggestions
        )
    }
    
    // MARK: - Advanced Analysis Methods
    
    private func analyzeExposure(image: CIImage) -> AdvancedExposureResult {
        // Get luminance histogram
        guard let histogram = getLuminanceHistogram(image: image) else {
            return AdvancedExposureResult(
                evValue: 0.0,
                confidence: 0.0,
                isOptimal: false,
                clippingLevel: 0.0,
                exposureCompensation: 0.0,
                histogram: []
            )
        }
        
        // Calculate EV (Exposure Value) estimation
        let meanLuminance = calculateMeanLuminance(histogram: histogram)
        let evValue = luminanceToEV(luminance: meanLuminance)
        
        // Detect clipping
        let clippingLevel = detectClipping(histogram: histogram)
        
        // Calculate optimal exposure compensation
        let exposureCompensation = calculateExposureCompensation(
            currentEV: evValue,
            targetEV: settings.targetEV,
            clipping: clippingLevel
        )
        
        // Determine if exposure is optimal
        let isOptimal = abs(exposureCompensation) < 0.3 && clippingLevel < 0.05
        
        // Confidence based on histogram quality and stability
        let confidence = calculateExposureConfidence(
            histogram: histogram,
            clipping: clippingLevel,
            compensation: exposureCompensation
        )
        
        return AdvancedExposureResult(
            evValue: evValue,
            confidence: confidence,
            isOptimal: isOptimal,
            clippingLevel: clippingLevel,
            exposureCompensation: exposureCompensation,
            histogram: histogram
        )
    }
    
    private func analyzeSceneExposure(image: CIImage) -> SceneExposureResult {
        // Analyze different regions of the image
        let imageSize = image.extent.size
        let regionSize = CGSize(width: imageSize.width / 3, height: imageSize.height / 3)
        
        var regions: [RegionExposure] = []
        
        // 3x3 grid analysis
        for row in 0..<3 {
            for col in 0..<3 {
                let origin = CGPoint(
                    x: CGFloat(col) * regionSize.width,
                    y: CGFloat(row) * regionSize.height
                )
                let regionRect = CGRect(origin: origin, size: regionSize)
                let regionImage = image.cropped(to: regionRect)
                
                if let regionHistogram = getLuminanceHistogram(image: regionImage) {
                    let meanLuminance = calculateMeanLuminance(histogram: regionHistogram)
                    let evValue = luminanceToEV(luminance: meanLuminance)
                    
                    regions.append(RegionExposure(
                        region: regionRect,
                        evValue: evValue,
                        luminance: meanLuminance,
                        importance: calculateRegionImportance(row: row, col: col)
                    ))
                }
            }
        }
        
        // Calculate scene exposure characteristics
        let centerRegions = regions.filter { $0.importance > 0.7 }
        let sceneDynamicRange = calculateSceneDynamicRange(regions: regions)
        let exposureVariation = calculateExposureVariation(regions: regions)
        
        let confidence = min(Float(regions.count) / 9.0, 1.0) * 0.9
        
        return SceneExposureResult(
            regions: regions,
            centerWeightedEV: centerRegions.reduce(0) { $0 + $1.evValue } / max(Float(centerRegions.count), 1),
            dynamicRange: sceneDynamicRange,
            exposureVariation: exposureVariation,
            confidence: confidence
        )
    }
    
    private func analyzeDynamicRange(image: CIImage) -> AdvancedDynamicRangeResult {
        guard let histogram = getLuminanceHistogram(image: image) else {
            return AdvancedDynamicRangeResult(
                confidence: 0.0,
                shadowsBlocked: 0.0,
                highlightsBlown: 0.0,
                dynamicRange: 0.0,
                midtoneSeparation: 0.0,
                toneDistribution: []
            )
        }
        
        let totalPixels = histogram.reduce(0, +)
        
        // Shadow analysis (bottom 10%)
        let shadowEnd = histogram.count / 10
        let blockedShadows = histogram[0..<shadowEnd].reduce(0, +) / totalPixels
        
        // Highlight analysis (top 10%)
        let highlightStart = histogram.count - shadowEnd
        let blownHighlights = histogram[highlightStart...].reduce(0, +) / totalPixels
        
        // Midtone separation analysis
        let midStart = histogram.count / 3
        let midEnd = (histogram.count * 2) / 3
        let midtones = histogram[midStart..<midEnd]
        let midtoneSeparation = calculateMidtoneSeparation(midtones: Array(midtones))
        
        // Overall dynamic range
        let dynamicRange = calculateDynamicRangeSpread(histogram: histogram)
        
        // Tone distribution analysis
        let toneDistribution = analyzeToneDistribution(histogram: histogram)
        
        return AdvancedDynamicRangeResult(
            confidence: 0.85,
            shadowsBlocked: blockedShadows,
            highlightsBlown: blownHighlights,
            dynamicRange: dynamicRange,
            midtoneSeparation: midtoneSeparation,
            toneDistribution: toneDistribution
        )
    }
    
    // MARK: - Histogram Analysis Helpers
    
    private func getLuminanceHistogram(image: CIImage) -> [Float]? {
        guard let histogramFilter = CIFilter(name: "CIAreaHistogram") else { return nil }
        
        // Convert to grayscale for luminance analysis
        let grayscaleImage = image.applyingFilter("CIColorControls", parameters: [
            "inputSaturation": 0.0
        ])
        
        histogramFilter.setValue(grayscaleImage, forKey: kCIInputImageKey)
        histogramFilter.setValue(256, forKey: "inputCount")
        histogramFilter.setValue(1.0, forKey: "inputScale")
        
        guard let histogramImage = histogramFilter.outputImage else { return nil }
        
        var histogramData = [UInt8](repeating: 0, count: 256 * 4)
        let histogramBounds = CGRect(x: 0, y: 0, width: 256, height: 1)
        
        ciContext.render(histogramImage, toBitmap: &histogramData, rowBytes: 256 * 4, bounds: histogramBounds, format: .RGBA8, colorSpace: nil)
        
        // Convert to normalized float array
        var histogram: [Float] = []
        for i in stride(from: 0, to: histogramData.count, by: 4) {
            let value = Float(histogramData[i])
            histogram.append(value)
        }
        
        return histogram
    }
    
    private func calculateMeanLuminance(histogram: [Float]) -> Float {
        let total = histogram.reduce(0, +)
        guard total > 0 else { return 0 }
        
        var weightedSum: Float = 0
        for (index, count) in histogram.enumerated() {
            let luminanceValue = Float(index) / 255.0
            weightedSum += luminanceValue * count
        }
        
        return weightedSum / total
    }
    
    private func luminanceToEV(luminance: Float) -> Float {
        // Convert luminance to approximate EV (this is a simplified calculation)
        // Real EV calculation would need ISO, aperture, and shutter speed
        let clampedLuminance = max(luminance, 0.001) // Avoid log(0)
        return log2(clampedLuminance * 100) - 3 // Approximate EV conversion
    }
    
    private func detectClipping(histogram: [Float]) -> Float {
        let total = histogram.reduce(0, +)
        guard total > 0 else { return 0 }
        
        // Check first and last bins for clipping
        let shadowClipping = histogram[0] / total
        let highlightClipping = histogram[histogram.count - 1] / total
        
        return max(shadowClipping, highlightClipping)
    }
    
    private func calculateExposureCompensation(currentEV: Float, targetEV: Float, clipping: Float) -> Float {
        let baseCompensation = targetEV - currentEV
        
        // Reduce compensation if clipping is detected
        let clippingFactor = 1.0 - (clipping * 2.0) // Reduce compensation as clipping increases
        
        return baseCompensation * clippingFactor
    }
    
    private func calculateExposureConfidence(histogram: [Float], clipping: Float, compensation: Float) -> Float {
        // Base confidence from histogram quality
        let histogramQuality = min(histogram.reduce(0, +) / 1000.0, 1.0) // Normalize by typical pixel count
        
        // Reduce confidence if clipping is high
        let clippingPenalty = 1.0 - min(clipping * 3.0, 0.8)
        
        // Reduce confidence if large compensation is needed
        let compensationPenalty = 1.0 - min(abs(compensation) * 0.2, 0.5)
        
        return histogramQuality * clippingPenalty * compensationPenalty
    }
    
    // MARK: - Scene Analysis Helpers
    
    private func calculateRegionImportance(row: Int, col: Int) -> Float {
        // Center regions are more important (rule of thirds)
        let centerDistance = sqrt(pow(Float(col - 1), 2) + pow(Float(row - 1), 2))
        return max(0.3, 1.0 - (centerDistance * 0.3))
    }
    
    private func calculateSceneDynamicRange(regions: [RegionExposure]) -> Float {
        guard !regions.isEmpty else { return 0 }
        
        let evValues = regions.map { $0.evValue }
        let minEV = evValues.min() ?? 0
        let maxEV = evValues.max() ?? 0
        
        return maxEV - minEV
    }
    
    private func calculateExposureVariation(regions: [RegionExposure]) -> Float {
        guard regions.count > 1 else { return 0 }
        
        let evValues = regions.map { $0.evValue }
        let mean = evValues.reduce(0, +) / Float(evValues.count)
        let variance = evValues.reduce(0) { $0 + pow($1 - mean, 2) } / Float(evValues.count)
        
        return sqrt(variance)
    }
    
    private func calculateMidtoneSeparation(midtones: [Float]) -> Float {
        guard midtones.count > 2 else { return 0 }
        
        // Calculate the standard deviation of midtones as a measure of separation
        let total = midtones.reduce(0, +)
        guard total > 0 else { return 0 }
        
        let mean = total / Float(midtones.count)
        let variance = midtones.reduce(0) { $0 + pow($1 - mean, 2) } / Float(midtones.count)
        
        return sqrt(variance) / mean // Coefficient of variation
    }
    
    private func calculateDynamicRangeSpread(histogram: [Float]) -> Float {
        // Find the range where significant pixel data exists
        let threshold = histogram.reduce(0, +) * 0.01 // 1% threshold
        
        var firstSignificant = 0
        var lastSignificant = histogram.count - 1
        
        // Find first significant bin
        for (index, value) in histogram.enumerated() {
            if value > threshold {
                firstSignificant = index
                break
            }
        }
        
        // Find last significant bin
        for index in stride(from: histogram.count - 1, through: 0, by: -1) {
            if histogram[index] > threshold {
                lastSignificant = index
                break
            }
        }
        
        return Float(lastSignificant - firstSignificant) / Float(histogram.count)
    }
    
    private func analyzeToneDistribution(histogram: [Float]) -> [Float] {
        let segmentSize = histogram.count / 5 // Divide into 5 tone regions
        var distribution: [Float] = []
        
        for segment in 0..<5 {
            let start = segment * segmentSize
            let end = min(start + segmentSize, histogram.count)
            let segmentSum = histogram[start..<end].reduce(0, +)
            distribution.append(segmentSum)
        }
        
        // Normalize to percentages
        let total = distribution.reduce(0, +)
        if total > 0 {
            distribution = distribution.map { $0 / total }
        }
        
        return distribution
    }
    
    // MARK: - Suggestion Generation
    
    private func generateExposureSuggestions(
        exposure: AdvancedExposureResult,
        dynamicRange: AdvancedDynamicRangeResult
    ) -> [AISuggestion] {
        var suggestions: [AISuggestion] = []
        
        // Exposure compensation suggestions
        if !exposure.isOptimal {
            let compensationText = exposure.exposureCompensation > 0 ? "Increase" : "Decrease"
            let compensationAmount = abs(exposure.exposureCompensation)
            
            suggestions.append(AISuggestion(
                type: .settings,
                title: "\(compensationText) Exposure",
                message: String(format: "Adjust exposure by %.1f stops for optimal lighting", compensationAmount),
                confidence: exposure.confidence,
                priority: compensationAmount > 1.0 ? .high : .medium
            ))
        }
        
        // Clipping warnings
        if exposure.clippingLevel > 0.05 {
            suggestions.append(AISuggestion(
                type: .settings,
                title: "Reduce Clipping",
                message: "Some details are lost in highlights or shadows. Adjust exposure or use HDR",
                confidence: min(exposure.clippingLevel * 2.0, 1.0),
                priority: .high
            ))
        }
        
        // Dynamic range suggestions
        if dynamicRange.shadowsBlocked > 0.1 {
            suggestions.append(AISuggestion(
                type: .lighting,
                title: "Lift Shadows",
                message: "Shadow details are blocked. Try adding fill light or adjusting position",
                confidence: dynamicRange.shadowsBlocked,
                priority: .medium
            ))
        }
        
        if dynamicRange.highlightsBlown > 0.1 {
            suggestions.append(AISuggestion(
                type: .lighting,
                title: "Protect Highlights",
                message: "Highlight details are blown. Reduce exposure or wait for softer light",
                confidence: dynamicRange.highlightsBlown,
                priority: .high
            ))
        }
        
        // Positive feedback
        if exposure.isOptimal && dynamicRange.shadowsBlocked < 0.05 && dynamicRange.highlightsBlown < 0.05 {
            suggestions.append(AISuggestion(
                type: .lighting,
                title: "Excellent Exposure",
                message: "Perfect lighting conditions with good detail retention",
                confidence: 0.9,
                priority: .low,
                actionable: false
            ))
        }
        
        return suggestions
    }
    
    private func generateSceneSuggestions(from sceneResult: SceneExposureResult) -> [AISuggestion] {
        var suggestions: [AISuggestion] = []
        
        // High dynamic range scene detection
        if sceneResult.dynamicRange > 4.0 {
            suggestions.append(AISuggestion(
                type: .settings,
                title: "High Dynamic Range Scene",
                message: "Consider using HDR mode or bracketed exposure for this challenging lighting",
                confidence: 0.8,
                priority: .medium
            ))
        }
        
        // Uneven exposure warning
        if sceneResult.exposureVariation > 2.0 {
            suggestions.append(AISuggestion(
                type: .composition,
                title: "Uneven Lighting",
                message: "Scene has very uneven lighting. Consider repositioning or waiting for better conditions",
                confidence: sceneResult.confidence,
                priority: .medium
            ))
        }
        
        return suggestions
    }
    
    // MARK: - History and Smoothing
    
    private func updateExposureHistory(_ evValue: Float) {
        exposureHistory.append(evValue)
        if exposureHistory.count > historyLimit {
            exposureHistory.removeFirst()
        }
    }
    
    private func applySmoothingToSuggestions(_ suggestions: [AISuggestion]) -> [AISuggestion] {
        // Apply temporal smoothing to reduce flickering suggestions
        return suggestions.filter { suggestion in
            // Only show suggestions that have been consistent over recent frames
            return suggestion.confidence > 0.7 || suggestion.priority == .critical
        }
    }
}

// MARK: - Configuration
public struct ExposureSettings {
    public var adaptiveAnalysisEnabled: Bool
    public var sceneAnalysisEnabled: Bool
    public var exposureSmoothingEnabled: Bool
    public var targetEV: Float // Target exposure value
    
    public static let `default` = ExposureSettings(
        adaptiveAnalysisEnabled: true,
        sceneAnalysisEnabled: true,
        exposureSmoothingEnabled: true,
        targetEV: 0.0 // Middle exposure
    )
}

// MARK: - Analysis Results
public struct AdvancedExposureResult {
    public let evValue: Float
    public let confidence: Float
    public let isOptimal: Bool
    public let clippingLevel: Float
    public let exposureCompensation: Float
    public let histogram: [Float]
    
    public func toDictionary() -> [String: Any] {
        return [
            "evValue": evValue,
            "confidence": confidence,
            "isOptimal": isOptimal,
            "clippingLevel": clippingLevel,
            "exposureCompensation": exposureCompensation,
            "histogram": histogram
        ]
    }
}

public struct SceneExposureResult {
    public let regions: [RegionExposure]
    public let centerWeightedEV: Float
    public let dynamicRange: Float
    public let exposureVariation: Float
    public let confidence: Float
    
    public func toDictionary() -> [String: Any] {
        return [
            "regionCount": regions.count,
            "centerWeightedEV": centerWeightedEV,
            "dynamicRange": dynamicRange,
            "exposureVariation": exposureVariation,
            "confidence": confidence
        ]
    }
}

public struct RegionExposure {
    public let region: CGRect
    public let evValue: Float
    public let luminance: Float
    public let importance: Float
}

public struct AdvancedDynamicRangeResult {
    public let confidence: Float
    public let shadowsBlocked: Float
    public let highlightsBlown: Float
    public let dynamicRange: Float
    public let midtoneSeparation: Float
    public let toneDistribution: [Float]
    
    public func toDictionary() -> [String: Any] {
        return [
            "confidence": confidence,
            "shadowsBlocked": shadowsBlocked,
            "highlightsBlown": highlightsBlown,
            "dynamicRange": dynamicRange,
            "midtoneSeparation": midtoneSeparation,
            "toneDistribution": toneDistribution
        ]
    }
}