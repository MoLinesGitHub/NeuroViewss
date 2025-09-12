//
//  FocusAnalyzer.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 18-19: AI Foundation - Intelligent Auto Focus Analysis
//

import Foundation
import CoreImage
import Vision
import AVFoundation
import Accelerate

@available(iOS 15.0, macOS 12.0, *)
public final class FocusAnalyzer: AIAnalyzer {
    public let analysisType: AIAnalysisType = .focus
    public var isEnabled: Bool = true
    
    public struct FocusSettings {
        var sharpnessThreshold: Float = 0.3
        var contrastThreshold: Float = 0.2
        var edgeThreshold: Float = 0.4
        var focusRegionSize: CGFloat = 0.1 // 10% of image size
        var multiPointAnalysis: Bool = true
        var depthEstimationEnabled: Bool = true
        var trackingEnabled: Bool = true
        
        public init() {}
    }
    
    private var settings = FocusSettings()
    private var previousFocusRegions: [FocusRegion] = []
    private let focusHistory = FocusHistory(maxSamples: 30) // 1 second at 30fps
    
    public struct FocusRegion {
        let id: UUID
        let boundingBox: CGRect
        let sharpnessScore: Float
        let contrastScore: Float
        let edgeScore: Float
        let overallScore: Float
        let confidence: Float
        let depth: Float? // Estimated depth
        let timestamp: Date
        
        public enum FocusQuality: String, CaseIterable {
            case excellent = "excellent"
            case good = "good"
            case fair = "fair"
            case poor = "poor"
            
            public var threshold: Float {
                switch self {
                case .excellent: return 0.8
                case .good: return 0.6
                case .fair: return 0.4
                case .poor: return 0.0
                }
            }
        }
        
        public var quality: FocusQuality {
            if overallScore >= 0.8 { return .excellent }
            else if overallScore >= 0.6 { return .good }
            else if overallScore >= 0.4 { return .fair }
            else { return .poor }
        }
    }
    
    private class FocusHistory {
        private var samples: [FocusSample] = []
        private let maxSamples: Int
        
        struct FocusSample {
            let timestamp: Date
            let overallSharpness: Float
            let bestFocusPoint: CGPoint
            let confidence: Float
        }
        
        init(maxSamples: Int) {
            self.maxSamples = maxSamples
        }
        
        func addSample(_ sample: FocusSample) {
            samples.append(sample)
            if samples.count > maxSamples {
                samples.removeFirst()
            }
        }
        
        func getRecentTrend() -> FocusTrend {
            guard samples.count >= 3 else { return .stable }
            
            let recentSamples = Array(samples.suffix(5))
            let sharpnessValues = recentSamples.map { $0.overallSharpness }
            
            let trend = calculateTrend(sharpnessValues)
            return trend
        }
        
        func getStabilityScore() -> Float {
            guard samples.count >= 5 else { return 0.5 }
            
            let recentSamples = Array(samples.suffix(10))
            let sharpnessValues = recentSamples.map { $0.overallSharpness }
            
            let mean = sharpnessValues.reduce(0, +) / Float(sharpnessValues.count)
            let variance = sharpnessValues.map { pow($0 - mean, 2) }.reduce(0, +) / Float(sharpnessValues.count)
            let standardDeviation = sqrt(variance)
            
            // Lower standard deviation = higher stability
            return max(0.0, 1.0 - standardDeviation)
        }
        
        private func calculateTrend(_ values: [Float]) -> FocusTrend {
            guard values.count >= 3 else { return .stable }
            
            let firstHalf = Array(values.prefix(values.count / 2))
            let secondHalf = Array(values.suffix(values.count / 2))
            
            let firstAvg = firstHalf.reduce(0, +) / Float(firstHalf.count)
            let secondAvg = secondHalf.reduce(0, +) / Float(secondHalf.count)
            
            let difference = secondAvg - firstAvg
            
            if difference > 0.1 { return .improving }
            else if difference < -0.1 { return .degrading }
            else { return .stable }
        }
    }
    
    public enum FocusTrend: String, CaseIterable {
        case improving = "improving"
        case stable = "stable"
        case degrading = "degrading"
        
        public var displayName: String {
            switch self {
            case .improving: return "Improving"
            case .stable: return "Stable"
            case .degrading: return "Degrading"
            }
        }
    }
    
    public struct FocusAnalysisResult {
        let focusRegions: [FocusRegion]
        let bestFocusRegion: FocusRegion?
        let overallSharpness: Float
        let suggestedFocusPoint: CGPoint
        let focusStability: Float
        let focusTrend: FocusTrend
        let recommendations: [FocusRecommendation]
        let confidence: Float
    }
    
    public struct FocusRecommendation {
        let type: RecommendationType
        let message: String
        let priority: SuggestionPriority
        let actionPoint: CGPoint?
        
        public enum RecommendationType: String, CaseIterable {
            case refocus = "refocus"
            case moveCloser = "move_closer"
            case improveStability = "improve_stability"
            case changeFocusMode = "change_focus_mode"
            case adjustExposure = "adjust_exposure"
            case waitForStability = "wait_for_stability"
        }
    }
    
    public init() {}
    
    public func configure(with settings: [String: Any]) {
        if let sharpnessThreshold = settings["sharpnessThreshold"] as? Float {
            self.settings.sharpnessThreshold = sharpnessThreshold
        }
        if let contrastThreshold = settings["contrastThreshold"] as? Float {
            self.settings.contrastThreshold = contrastThreshold
        }
        if let edgeThreshold = settings["edgeThreshold"] as? Float {
            self.settings.edgeThreshold = edgeThreshold
        }
        if let focusRegionSize = settings["focusRegionSize"] as? CGFloat {
            self.settings.focusRegionSize = focusRegionSize
        }
        if let multiPointAnalysis = settings["multiPointAnalysis"] as? Bool {
            self.settings.multiPointAnalysis = multiPointAnalysis
        }
        if let depthEstimation = settings["depthEstimationEnabled"] as? Bool {
            self.settings.depthEstimationEnabled = depthEstimation
        }
        if let tracking = settings["trackingEnabled"] as? Bool {
            self.settings.trackingEnabled = tracking
        }
    }
    
    public func analyze(frame: CVPixelBuffer) -> AIAnalysis? {
        guard isEnabled else { return nil }
        
        let ciImage = CIImage(cvPixelBuffer: frame)
        let focusResult = performFocusAnalysis(image: ciImage)
        
        // Add to history
        let sample = FocusHistory.FocusSample(
            timestamp: Date(),
            overallSharpness: focusResult.overallSharpness,
            bestFocusPoint: focusResult.suggestedFocusPoint,
            confidence: focusResult.confidence
        )
        focusHistory.addSample(sample)
        
        let suggestions = generateFocusSuggestions(from: focusResult)
        
        let analysisData: [String: Any] = [
            "overall_sharpness": focusResult.overallSharpness,
            "best_focus_point": [
                "x": focusResult.suggestedFocusPoint.x,
                "y": focusResult.suggestedFocusPoint.y
            ],
            "focus_stability": focusResult.focusStability,
            "focus_trend": focusResult.focusTrend.rawValue,
            "focus_regions": focusResult.focusRegions.map { region in
                [
                    "bounding_box": [
                        "x": region.boundingBox.origin.x,
                        "y": region.boundingBox.origin.y,
                        "width": region.boundingBox.width,
                        "height": region.boundingBox.height
                    ],
                    "sharpness_score": region.sharpnessScore,
                    "contrast_score": region.contrastScore,
                    "edge_score": region.edgeScore,
                    "overall_score": region.overallScore,
                    "quality": region.quality.rawValue
                ]
            },
            "recommendations": focusResult.recommendations.map { rec in
                [
                    "type": rec.type.rawValue,
                    "message": rec.message,
                    "priority": rec.priority.rawValue
                ]
            }
        ]
        
        return AIAnalysis(
            type: .focus,
            confidence: focusResult.confidence,
            data: analysisData,
            suggestions: suggestions
        )
    }
    
    private func performFocusAnalysis(image: CIImage) -> FocusAnalysisResult {
        let imageSize = image.extent.size
        
        // Generate focus regions to analyze
        let focusRegions = generateFocusRegions(imageSize: imageSize)
        
        // Analyze each region
        var analyzedRegions: [FocusRegion] = []
        
        for region in focusRegions {
            let croppedImage = cropImage(image, to: region)
            let analysis = analyzeFocusRegion(image: croppedImage, region: region)
            analyzedRegions.append(analysis)
        }
        
        // Find best focus region
        let bestFocusRegion = analyzedRegions.max { $0.overallScore < $1.overallScore }
        
        // Calculate overall sharpness
        let overallSharpness = calculateOverallSharpness(regions: analyzedRegions)
        
        // Determine suggested focus point
        let suggestedFocusPoint = determineSuggestedFocusPoint(regions: analyzedRegions, imageSize: imageSize)
        
        // Calculate focus stability from history
        let focusStability = focusHistory.getStabilityScore()
        
        // Get focus trend
        let focusTrend = focusHistory.getRecentTrend()
        
        // Generate recommendations
        let recommendations = generateFocusRecommendations(
            regions: analyzedRegions,
            bestRegion: bestFocusRegion,
            stability: focusStability,
            trend: focusTrend
        )
        
        // Calculate overall confidence
        let confidence = calculateOverallConfidence(regions: analyzedRegions, stability: focusStability)
        
        return FocusAnalysisResult(
            focusRegions: analyzedRegions,
            bestFocusRegion: bestFocusRegion,
            overallSharpness: overallSharpness,
            suggestedFocusPoint: suggestedFocusPoint,
            focusStability: focusStability,
            focusTrend: focusTrend,
            recommendations: recommendations,
            confidence: confidence
        )
    }
    
    private func generateFocusRegions(imageSize: CGSize) -> [CGRect] {
        var regions: [CGRect] = []
        
        if settings.multiPointAnalysis {
            // Generate multiple focus regions across the image
            let regionSize = CGSize(
                width: imageSize.width * settings.focusRegionSize,
                height: imageSize.height * settings.focusRegionSize
            )
            
            // Center region
            regions.append(CGRect(
                x: imageSize.width * 0.5 - regionSize.width * 0.5,
                y: imageSize.height * 0.5 - regionSize.height * 0.5,
                width: regionSize.width,
                height: regionSize.height
            ))
            
            // Rule of thirds points
            let thirdPoints: [(CGFloat, CGFloat)] = [
                (1.0/3.0, 1.0/3.0), (2.0/3.0, 1.0/3.0),
                (1.0/3.0, 2.0/3.0), (2.0/3.0, 2.0/3.0)
            ]
            
            for (x, y) in thirdPoints {
                regions.append(CGRect(
                    x: imageSize.width * x - regionSize.width * 0.5,
                    y: imageSize.height * y - regionSize.height * 0.5,
                    width: regionSize.width,
                    height: regionSize.height
                ))
            }
        } else {
            // Single center region
            let regionSize = CGSize(
                width: imageSize.width * settings.focusRegionSize,
                height: imageSize.height * settings.focusRegionSize
            )
            
            regions.append(CGRect(
                x: imageSize.width * 0.5 - regionSize.width * 0.5,
                y: imageSize.height * 0.5 - regionSize.height * 0.5,
                width: regionSize.width,
                height: regionSize.height
            ))
        }
        
        return regions
    }
    
    private func cropImage(_ image: CIImage, to region: CGRect) -> CIImage {
        let clampedRegion = region.intersection(image.extent)
        return image.cropped(to: clampedRegion)
    }
    
    private func analyzeFocusRegion(image: CIImage, region: CGRect) -> FocusRegion {
        let sharpnessScore = calculateSharpnessScore(image: image)
        let contrastScore = calculateContrastScore(image: image)
        let edgeScore = calculateEdgeScore(image: image)
        
        // Calculate overall score with weighted average
        let overallScore = (sharpnessScore * 0.5) + (contrastScore * 0.3) + (edgeScore * 0.2)
        
        // Calculate confidence based on consistency of metrics
        let confidence = calculateRegionConfidence(
            sharpness: sharpnessScore,
            contrast: contrastScore,
            edge: edgeScore
        )
        
        // Estimate depth (simplified)
        let depth = settings.depthEstimationEnabled ? estimateDepth(image: image) : nil
        
        return FocusRegion(
            id: UUID(),
            boundingBox: region,
            sharpnessScore: sharpnessScore,
            contrastScore: contrastScore,
            edgeScore: edgeScore,
            overallScore: overallScore,
            confidence: confidence,
            depth: depth,
            timestamp: Date()
        )
    }
    
    private func calculateSharpnessScore(image: CIImage) -> Float {
        // Use Laplacian variance for sharpness detection
        let laplacianFilter = CIFilter(name: "CIConvolution3X3")!
        laplacianFilter.setValue(image, forKey: kCIInputImageKey)
        
        // Laplacian kernel for edge detection
        let laplacianKernel = CIVector(values: [
            0, -1, 0,
            -1, 4, -1,
            0, -1, 0
        ], count: 9)
        laplacianFilter.setValue(laplacianKernel, forKey: "inputWeights")
        
        guard let outputImage = laplacianFilter.outputImage else { return 0.0 }
        
        // Calculate variance of the filtered image
        let variance = calculateImageVariance(image: outputImage)
        
        // Normalize to 0-1 range
        return min(variance / 1000.0, 1.0)
    }
    
    private func calculateContrastScore(image: CIImage) -> Float {
        // Calculate RMS contrast
        let context = CIContext()
        guard let cgImage = context.createCGImage(image, from: image.extent) else { return 0.0 }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context2 = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return 0.0 }
        
        context2.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Calculate luminance values
        var luminances: [Float] = []
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            let r = Float(pixelData[i]) / 255.0
            let g = Float(pixelData[i + 1]) / 255.0
            let b = Float(pixelData[i + 2]) / 255.0
            let luminance = 0.299 * r + 0.587 * g + 0.114 * b
            luminances.append(luminance)
        }
        
        // Calculate RMS contrast
        let mean = luminances.reduce(0, +) / Float(luminances.count)
        let variance = luminances.map { pow($0 - mean, 2) }.reduce(0, +) / Float(luminances.count)
        let rmsContrast = sqrt(variance)
        
        return min(rmsContrast * 4.0, 1.0) // Normalize and amplify
    }
    
    private func calculateEdgeScore(image: CIImage) -> Float {
        // Use Sobel edge detection
        let sobelFilter = CIFilter(name: "CIConvolution3X3")!
        sobelFilter.setValue(image, forKey: kCIInputImageKey)
        
        // Sobel X kernel
        let sobelX = CIVector(values: [
            -1, 0, 1,
            -2, 0, 2,
            -1, 0, 1
        ], count: 9)
        sobelFilter.setValue(sobelX, forKey: "inputWeights")
        
        guard let sobelXImage = sobelFilter.outputImage else { return 0.0 }
        
        // Sobel Y kernel
        let sobelY = CIVector(values: [
            -1, -2, -1,
            0, 0, 0,
            1, 2, 1
        ], count: 9)
        sobelFilter.setValue(sobelY, forKey: "inputWeights")
        
        guard let sobelYImage = sobelFilter.outputImage else { return 0.0 }
        
        // Combine gradients
        let edgeStrength = sqrt(calculateImageVariance(image: sobelXImage) + calculateImageVariance(image: sobelYImage))
        
        return min(edgeStrength / 500.0, 1.0)
    }
    
    private func calculateImageVariance(image: CIImage) -> Float {
        let context = CIContext()
        guard let cgImage = context.createCGImage(image, from: image.extent) else { return 0.0 }
        
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        
        var pixelData = [UInt8](repeating: 0, count: height * bytesPerRow)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context2 = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        ) else { return 0.0 }
        
        context2.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // Calculate grayscale values and variance
        var grayValues: [Float] = []
        for i in stride(from: 0, to: pixelData.count, by: 4) {
            let r = Float(pixelData[i]) / 255.0
            let g = Float(pixelData[i + 1]) / 255.0
            let b = Float(pixelData[i + 2]) / 255.0
            let gray = 0.299 * r + 0.587 * g + 0.114 * b
            grayValues.append(gray)
        }
        
        let mean = grayValues.reduce(0, +) / Float(grayValues.count)
        let variance = grayValues.map { pow($0 - mean, 2) }.reduce(0, +) / Float(grayValues.count)
        
        return variance
    }
    
    private func calculateRegionConfidence(sharpness: Float, contrast: Float, edge: Float) -> Float {
        // Higher confidence when all metrics are consistent
        let mean = (sharpness + contrast + edge) / 3.0
        let variance = (pow(sharpness - mean, 2) + pow(contrast - mean, 2) + pow(edge - mean, 2)) / 3.0
        let consistency = 1.0 - sqrt(variance)
        
        // Combine with overall quality
        let quality = mean
        
        return (consistency * 0.4) + (quality * 0.6)
    }
    
    private func estimateDepth(image: CIImage) -> Float {
        // Simplified depth estimation based on focus metrics
        // In a real implementation, this would use stereo vision or ML models
        let sharpness = calculateSharpnessScore(image: image)
        
        // Assume sharper = closer (simplified)
        return 1.0 - sharpness
    }
    
    private func calculateOverallSharpness(regions: [FocusRegion]) -> Float {
        guard !regions.isEmpty else { return 0.0 }
        
        let totalSharpness = regions.reduce(0.0) { $0 + $1.sharpnessScore }
        return totalSharpness / Float(regions.count)
    }
    
    private func determineSuggestedFocusPoint(regions: [FocusRegion], imageSize: CGSize) -> CGPoint {
        guard let bestRegion = regions.max(by: { $0.overallScore < $1.overallScore }) else {
            return CGPoint(x: 0.5, y: 0.5)
        }
        
        // Convert region center to normalized coordinates
        let centerX = (bestRegion.boundingBox.midX) / imageSize.width
        let centerY = (bestRegion.boundingBox.midY) / imageSize.height
        
        return CGPoint(x: centerX, y: centerY)
    }
    
    private func generateFocusRecommendations(
        regions: [FocusRegion],
        bestRegion: FocusRegion?,
        stability: Float,
        trend: FocusTrend
    ) -> [FocusRecommendation] {
        
        var recommendations: [FocusRecommendation] = []
        
        // Overall sharpness recommendation
        if let bestRegion = bestRegion {
            if bestRegion.overallScore < 0.4 {
                recommendations.append(FocusRecommendation(
                    type: .refocus,
                    message: "Tap to refocus on the subject",
                    priority: .high,
                    actionPoint: CGPoint(
                        x: bestRegion.boundingBox.midX,
                        y: bestRegion.boundingBox.midY
                    )
                ))
            }
            
            if bestRegion.overallScore < 0.6 && bestRegion.sharpnessScore < 0.3 {
                recommendations.append(FocusRecommendation(
                    type: .moveCloser,
                    message: "Move closer to the subject for better detail",
                    priority: .medium,
                    actionPoint: nil
                ))
            }
        }
        
        // Stability recommendations
        if stability < 0.4 {
            recommendations.append(FocusRecommendation(
                type: .improveStability,
                message: "Hold the camera steadier for sharper images",
                priority: .high,
                actionPoint: nil
            ))
        }
        
        // Trend-based recommendations
        switch trend {
        case .degrading:
            recommendations.append(FocusRecommendation(
                type: .waitForStability,
                message: "Wait for autofocus to stabilize",
                priority: .medium,
                actionPoint: nil
            ))
        case .improving:
            // No recommendation needed, focus is improving
            break
        case .stable:
            if stability > 0.7 {
                // Good stability, could suggest focus mode changes
                recommendations.append(FocusRecommendation(
                    type: .changeFocusMode,
                    message: "Consider locking focus for this composition",
                    priority: .low,
                    actionPoint: nil
                ))
            }
        }
        
        // Contrast-based recommendations
        if let bestRegion = bestRegion, bestRegion.contrastScore < 0.3 {
            recommendations.append(FocusRecommendation(
                type: .adjustExposure,
                message: "Adjust exposure to improve contrast",
                priority: .medium,
                actionPoint: nil
            ))
        }
        
        return recommendations
    }
    
    private func calculateOverallConfidence(regions: [FocusRegion], stability: Float) -> Float {
        guard !regions.isEmpty else { return 0.0 }
        
        let avgConfidence = regions.reduce(0.0) { $0 + $1.confidence } / Float(regions.count)
        
        // Combine region confidence with stability
        return (avgConfidence * 0.7) + (stability * 0.3)
    }
    
    private func generateFocusSuggestions(from result: FocusAnalysisResult) -> [AISuggestion] {
        var suggestions: [AISuggestion] = []
        
        // Convert focus recommendations to AI suggestions
        for recommendation in result.recommendations {
            let suggestionType: SuggestionType
            
            switch recommendation.type {
            case .refocus, .moveCloser:
                suggestionType = .focus
            case .improveStability:
                suggestionType = .stability
            case .changeFocusMode, .adjustExposure:
                suggestionType = .settings
            case .waitForStability:
                suggestionType = .timing
            }
            
            suggestions.append(AISuggestion(
                type: suggestionType,
                title: "Focus " + recommendation.type.rawValue.capitalized,
                message: recommendation.message,
                confidence: result.confidence,
                priority: recommendation.priority
            ))
        }
        
        // Overall focus quality suggestion
        if result.overallSharpness < 0.4 {
            suggestions.append(AISuggestion(
                type: .focus,
                title: "Image Sharpness",
                message: "Image appears soft - tap to refocus or check camera stability",
                confidence: 0.9,
                priority: .high
            ))
        } else if result.overallSharpness > 0.8 {
            suggestions.append(AISuggestion(
                type: .focus,
                title: "Excellent Focus",
                message: "Sharp focus achieved - perfect time to capture",
                confidence: result.confidence,
                priority: .low
            ))
        }
        
        return suggestions
    }
}