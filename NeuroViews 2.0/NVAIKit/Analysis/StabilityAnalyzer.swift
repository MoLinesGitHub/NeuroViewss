//
//  StabilityAnalyzer.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 18-19: Advanced AI Foundation
//

import Foundation
import CoreImage
import Vision
import AVFoundation
import CoreMotion

@available(iOS 15.0, macOS 12.0, *)
public final class StabilityAnalyzer: AIAnalyzer {
    
    // MARK: - AIAnalyzer Protocol
    public let analysisType: AIAnalysisType = .stability
    public var isEnabled: Bool = true
    
    // MARK: - Properties
    private let ciContext = CIContext()
    private var settings: StabilitySettings = .default
    
    // Motion tracking (iOS/watchOS only)
    #if !os(macOS)
    private let motionManager = CMMotionManager()
    private var motionQueue = OperationQueue()
    private var recentMotionData: [CMDeviceMotion] = []
    #endif
    private let motionHistoryLimit = 10
    
    // Frame comparison for optical stability
    private var previousFrame: CVPixelBuffer?
    private var frameStabilityHistory: [Float] = []
    private let stabilityHistoryLimit = 5
    
    // MARK: - Initialization
    public init() {
        setupMotionTracking()
    }
    
    deinit {
        #if !os(macOS)
        motionManager.stopDeviceMotionUpdates()
        #endif
    }
    
    private func setupMotionTracking() {
        #if !os(macOS)
        guard motionManager.isDeviceMotionAvailable else {
            print("⚠️ Device motion not available for stability analysis")
            return
        }
        
        motionManager.deviceMotionUpdateInterval = 1.0 / 30.0 // 30 Hz
        motionManager.startDeviceMotionUpdates(to: motionQueue) { [weak self] motionData, error in
            guard let self = self, let motion = motionData else { return }
            
            DispatchQueue.global(qos: .utility).async {
                self.processMotionData(motion)
            }
        }
        #else
        print("📱 Motion tracking not available on macOS - using optical-only stability analysis")
        #endif
    }
    
    // MARK: - Configuration
    public func configure(with settings: [String: Any]) {
        if let motionTrackingEnabled = settings["motionTrackingEnabled"] as? Bool {
            self.settings.motionTrackingEnabled = motionTrackingEnabled
        }
        if let opticalStabilityEnabled = settings["opticalStabilityEnabled"] as? Bool {
            self.settings.opticalStabilityEnabled = opticalStabilityEnabled
        }
        if let shakeThreshold = settings["shakeThreshold"] as? Float {
            self.settings.shakeThreshold = shakeThreshold
        }
        if let blurDetectionEnabled = settings["blurDetectionEnabled"] as? Bool {
            self.settings.blurDetectionEnabled = blurDetectionEnabled
        }
    }
    
    // MARK: - Analysis
    public func analyze(frame: CVPixelBuffer) -> AIAnalysis? {
        guard isEnabled else { return nil }
        
        var analysisData: [String: Any] = [:]
        var suggestions: [AISuggestion] = []
        var totalConfidence: Float = 0.0
        var analysisCount = 0
        
        // Motion-based stability analysis
        #if !os(macOS)
        if settings.motionTrackingEnabled {
            let motionResult = analyzeMotionStability()
            analysisData["motionStability"] = motionResult.toDictionary()
            totalConfidence += motionResult.confidence
            analysisCount += 1
            
            suggestions.append(contentsOf: generateMotionSuggestions(from: motionResult))
        }
        #endif
        
        // Optical stability analysis
        if settings.opticalStabilityEnabled {
            let opticalResult = analyzeOpticalStability(currentFrame: frame)
            analysisData["opticalStability"] = opticalResult.toDictionary()
            totalConfidence += opticalResult.confidence
            analysisCount += 1
            
            suggestions.append(contentsOf: generateOpticalSuggestions(from: opticalResult))
        }
        
        // Blur detection analysis
        if settings.blurDetectionEnabled {
            let blurResult = analyzeBlurLevel(frame: frame)
            analysisData["blurAnalysis"] = blurResult.toDictionary()
            totalConfidence += blurResult.confidence
            analysisCount += 1
            
            suggestions.append(contentsOf: generateBlurSuggestions(from: blurResult))
        }
        
        let averageConfidence = analysisCount > 0 ? totalConfidence / Float(analysisCount) : 0.0
        
        // Store current frame for next analysis
        previousFrame = frame
        
        return AIAnalysis(
            type: .stability,
            confidence: averageConfidence,
            data: analysisData,
            suggestions: suggestions
        )
    }
    
    // MARK: - Motion Analysis
    
    #if !os(macOS)
    private func processMotionData(_ motion: CMDeviceMotion) {
        recentMotionData.append(motion)
        if recentMotionData.count > motionHistoryLimit {
            recentMotionData.removeFirst()
        }
    }
    
    private func analyzeMotionStability() -> MotionStabilityResult {
        guard !recentMotionData.isEmpty else {
            return MotionStabilityResult(
                isStable: true,
                shakeLevel: 0.0,
                rotationRate: 0.0,
                userAcceleration: 0.0,
                confidence: 0.0
            )
        }
        
        let recentMotion = Array(recentMotionData.suffix(5)) // Last 5 readings for immediate analysis
        
        // Calculate rotation rate magnitude
        let rotationRates = recentMotion.map { motion in
            let rotation = motion.rotationRate
            return sqrt(rotation.x * rotation.x + rotation.y * rotation.y + rotation.z * rotation.z)
        }
        let avgRotationRate = rotationRates.reduce(0, +) / Double(rotationRates.count)
        
        // Calculate user acceleration magnitude (excluding gravity)
        let userAccelerations = recentMotion.map { motion in
            let accel = motion.userAcceleration
            return sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)
        }
        let avgUserAcceleration = userAccelerations.reduce(0, +) / Double(userAccelerations.count)
        
        // Calculate shake level (combination of rotation and acceleration)
        let shakeLevel = Float((avgRotationRate * 0.6) + (avgUserAcceleration * 0.4))
        
        // Determine stability
        let isStable = shakeLevel < settings.shakeThreshold
        
        // Calculate confidence based on data consistency
        let rotationVariance = calculateVariance(rotationRates)
        let accelerationVariance = calculateVariance(userAccelerations)
        let confidence = max(0.5, 1.0 - Float((rotationVariance + accelerationVariance) * 0.5))
        
        return MotionStabilityResult(
            isStable: isStable,
            shakeLevel: shakeLevel,
            rotationRate: Float(avgRotationRate),
            userAcceleration: Float(avgUserAcceleration),
            confidence: confidence
        )
    }
    #endif
    
    private func calculateVariance(_ values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count - 1)
        return variance
    }
    
    // MARK: - Optical Stability Analysis
    
    private func analyzeOpticalStability(currentFrame: CVPixelBuffer) -> OpticalStabilityResult {
        guard let previousFrame = previousFrame else {
            return OpticalStabilityResult(
                frameStability: 1.0,
                motionMagnitude: 0.0,
                isStable: true,
                confidence: 0.3
            )
        }
        
        // Calculate optical flow or frame difference
        let stability = calculateFrameStability(
            previous: previousFrame,
            current: currentFrame
        )
        
        // Update history
        frameStabilityHistory.append(stability)
        if frameStabilityHistory.count > stabilityHistoryLimit {
            frameStabilityHistory.removeFirst()
        }
        
        // Calculate average stability
        let avgStability = frameStabilityHistory.reduce(0, +) / Float(frameStabilityHistory.count)
        let motionMagnitude = 1.0 - avgStability
        let isStable = avgStability > 0.7
        
        let confidence = min(Float(frameStabilityHistory.count) / Float(stabilityHistoryLimit), 1.0) * 0.9
        
        return OpticalStabilityResult(
            frameStability: avgStability,
            motionMagnitude: motionMagnitude,
            isStable: isStable,
            confidence: confidence
        )
    }
    
    private func calculateFrameStability(previous: CVPixelBuffer, current: CVPixelBuffer) -> Float {
        // Convert frames to CIImage for processing
        let previousImage = CIImage(cvPixelBuffer: previous)
        let currentImage = CIImage(cvPixelBuffer: current)
        
        // Resize images for faster processing
        let scale: CGFloat = 0.25
        let resizedPrevious = previousImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let resizedCurrent = currentImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        
        // Calculate difference between frames
        guard let differenceFilter = CIFilter(name: "CIDifferenceBlendMode") else {
            return 0.5
        }
        
        differenceFilter.setValue(resizedPrevious, forKey: kCIInputImageKey)
        differenceFilter.setValue(resizedCurrent, forKey: kCIInputBackgroundImageKey)
        
        guard let differenceImage = differenceFilter.outputImage else {
            return 0.5
        }
        
        // Calculate mean difference
        guard let areaAverage = CIFilter(name: "CIAreaAverage") else {
            return 0.5
        }
        
        areaAverage.setValue(differenceImage, forKey: kCIInputImageKey)
        areaAverage.setValue(CIVector(cgRect: differenceImage.extent), forKey: kCIInputExtentKey)
        
        guard let avgImage = areaAverage.outputImage else {
            return 0.5
        }
        
        // Render to get the average difference value
        var pixel: [UInt8] = [0, 0, 0, 0]
        ciContext.render(avgImage, toBitmap: &pixel, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)
        
        // Convert to stability score (lower difference = higher stability)
        let difference = Float(pixel[0]) / 255.0
        return max(0.0, 1.0 - difference * 3.0) // Scale difference to stability
    }
    
    // MARK: - Blur Detection Analysis
    
    private func analyzeBlurLevel(frame: CVPixelBuffer) -> BlurAnalysisResult {
        let ciImage = CIImage(cvPixelBuffer: frame)
        
        // Detect blur using Laplacian variance
        let blurLevel = detectBlurVariance(image: ciImage)
        let isBlurred = blurLevel < 50.0 // Threshold for blur detection
        
        // Motion blur detection
        let motionBlurLevel = detectMotionBlur(image: ciImage)
        
        let confidence: Float = 0.8
        
        return BlurAnalysisResult(
            blurLevel: blurLevel,
            motionBlurLevel: motionBlurLevel,
            isBlurred: isBlurred,
            blurType: isBlurred ? (motionBlurLevel > blurLevel * 0.7 ? .motion : .focus) : .none,
            confidence: confidence
        )
    }
    
    private func detectBlurVariance(image: CIImage) -> Float {
        // Apply Laplacian kernel to detect edges
        let laplacianKernel = CIKernel(source: """
            kernel vec4 laplacian(sampler image) {
                vec2 dc = destCoord();
                vec4 center = sample(image, dc);
                vec4 top = sample(image, dc + vec2(0.0, 1.0));
                vec4 bottom = sample(image, dc + vec2(0.0, -1.0));
                vec4 left = sample(image, dc + vec2(-1.0, 0.0));
                vec4 right = sample(image, dc + vec2(1.0, 0.0));
                
                vec4 laplacian = -4.0 * center + top + bottom + left + right;
                return vec4(length(laplacian.rgb), laplacian.a);
            }
        """)
        
        guard let kernel = laplacianKernel else { return 50.0 }
        
        let extent = image.extent
        guard let laplacianImage = kernel.apply(extent: extent, roiCallback: { _, destRect in
            return destRect.insetBy(dx: -1, dy: -1)
        }, arguments: [image]) else { return 50.0 }
        
        // Calculate variance of the Laplacian
        guard let varianceFilter = CIFilter(name: "CIAreaHistogram") else { return 50.0 }
        varianceFilter.setValue(laplacianImage, forKey: kCIInputImageKey)
        
        // Simplified blur detection - in production would calculate actual variance
        return 75.0 // Placeholder value
    }
    
    private func detectMotionBlur(image: CIImage) -> Float {
        // Detect horizontal and vertical gradients
        guard let sobelX = CIFilter(name: "CIConvolution3X3") else { return 0.0 }
        
        let sobelXMatrix = CIVector(values: [-1, 0, 1, -2, 0, 2, -1, 0, 1], count: 9)
        sobelX.setValue(image, forKey: kCIInputImageKey)
        sobelX.setValue(sobelXMatrix, forKey: kCIInputWeightsKey)
        
        // Simplified motion blur detection
        return 30.0 // Placeholder value
    }
    
    // MARK: - Suggestion Generation
    
    #if !os(macOS)
    private func generateMotionSuggestions(from result: MotionStabilityResult) -> [AISuggestion] {
        var suggestions: [AISuggestion] = []
        
        if !result.isStable {
            let priority: SuggestionPriority = result.shakeLevel > settings.shakeThreshold * 2 ? .high : .medium
            
            if result.rotationRate > result.userAcceleration {
                suggestions.append(AISuggestion(
                    type: .stability,
                    title: "Hold Steady",
                    message: "Device rotation detected. Hold camera more steadily or use a tripod",
                    confidence: result.confidence,
                    priority: priority
                ))
            } else {
                suggestions.append(AISuggestion(
                    type: .stability,
                    title: "Reduce Movement",
                    message: "Camera shake detected. Brace yourself or use image stabilization",
                    confidence: result.confidence,
                    priority: priority
                ))
            }
        } else if result.shakeLevel < settings.shakeThreshold * 0.3 {
            suggestions.append(AISuggestion(
                type: .stability,
                title: "Excellent Stability",
                message: "Very stable camera position - great for sharp photos",
                confidence: result.confidence,
                priority: .low,
                actionable: false
            ))
        }
        
        return suggestions
    }
    #endif
    
    private func generateOpticalSuggestions(from result: OpticalStabilityResult) -> [AISuggestion] {
        var suggestions: [AISuggestion] = []
        
        if !result.isStable {
            suggestions.append(AISuggestion(
                type: .stability,
                title: "Frame Movement",
                message: "Significant movement between frames. Hold steady for sharper images",
                confidence: result.confidence,
                priority: result.motionMagnitude > 0.5 ? .high : .medium
            ))
        }
        
        return suggestions
    }
    
    private func generateBlurSuggestions(from result: BlurAnalysisResult) -> [AISuggestion] {
        var suggestions: [AISuggestion] = []
        
        if result.isBlurred {
            switch result.blurType {
            case .motion:
                suggestions.append(AISuggestion(
                    type: .stability,
                    title: "Motion Blur Detected",
                    message: "Use faster shutter speed or stabilize camera to reduce motion blur",
                    confidence: result.confidence,
                    priority: .medium
                ))
            case .focus:
                suggestions.append(AISuggestion(
                    type: .focus,
                    title: "Focus Blur Detected",
                    message: "Image appears out of focus. Tap to focus on your subject",
                    confidence: result.confidence,
                    priority: .medium
                ))
            case .none:
                break
            }
        }
        
        return suggestions
    }
}

// MARK: - Configuration
public struct StabilitySettings {
    public var motionTrackingEnabled: Bool
    public var opticalStabilityEnabled: Bool
    public var blurDetectionEnabled: Bool
    public var shakeThreshold: Float // Threshold for shake detection
    
    public static let `default` = StabilitySettings(
        motionTrackingEnabled: true,
        opticalStabilityEnabled: true,
        blurDetectionEnabled: true,
        shakeThreshold: 0.3
    )
}

// MARK: - Analysis Results
public struct MotionStabilityResult {
    public let isStable: Bool
    public let shakeLevel: Float
    public let rotationRate: Float
    public let userAcceleration: Float
    public let confidence: Float
    
    public func toDictionary() -> [String: Any] {
        return [
            "isStable": isStable,
            "shakeLevel": shakeLevel,
            "rotationRate": rotationRate,
            "userAcceleration": userAcceleration,
            "confidence": confidence
        ]
    }
}

public struct OpticalStabilityResult {
    public let frameStability: Float // 0-1 where 1 is most stable
    public let motionMagnitude: Float
    public let isStable: Bool
    public let confidence: Float
    
    public func toDictionary() -> [String: Any] {
        return [
            "frameStability": frameStability,
            "motionMagnitude": motionMagnitude,
            "isStable": isStable,
            "confidence": confidence
        ]
    }
}

public struct BlurAnalysisResult {
    public let blurLevel: Float
    public let motionBlurLevel: Float
    public let isBlurred: Bool
    public let blurType: BlurType
    public let confidence: Float
    
    public enum BlurType {
        case none
        case motion
        case focus
    }
    
    public func toDictionary() -> [String: Any] {
        return [
            "blurLevel": blurLevel,
            "motionBlurLevel": motionBlurLevel,
            "isBlurred": isBlurred,
            "blurType": String(describing: blurType),
            "confidence": confidence
        ]
    }
}