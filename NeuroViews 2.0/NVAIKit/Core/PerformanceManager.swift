//
//  PerformanceManager.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 18-19: AI Foundation - Real-time Analysis Performance Optimization
//

import Foundation
import CoreImage
import AVFoundation
import os.log

// MARK: - Analysis Priority
public enum AnalysisPriority: Int, CaseIterable {
    case low = 0
    case normal = 1
    case high = 2
}

@available(iOS 15.0, macOS 12.0, *)
public final class PerformanceManager {
    
    public static let shared = PerformanceManager()
    
    private let logger = Logger(subsystem: "com.neuroviews.nvaikit", category: "Performance")
    private let performanceQueue = DispatchQueue(label: "com.neuroviews.performance", qos: .utility)
    
    // Performance monitoring
    private var frameProcessingTimes: [TimeInterval] = []
    private var lastFrameTime: CFTimeInterval = 0
    private var droppedFrameCount: Int = 0
    private var totalFrameCount: Int = 0
    private var isPerformanceMonitoringEnabled = true
    
    // Adaptive quality settings
    private var currentQualityLevel: QualityLevel = .high
    private var targetFrameRate: Double = 30.0
    private var maxProcessingTime: TimeInterval = 0.033 // 33ms for 30fps
    
    // Resource management
    private let maxConcurrentAnalysis = 2
    private var activeAnalysisCount = 0
    private let activeAnalysisQueue = DispatchQueue(label: "com.neuroviews.analysis.counter")
    
    // Frame management
    private let frameBuffer = FrameBuffer(capacity: 5)
    private var lastProcessedFrameTime: CFTimeInterval = 0
    private let minFrameInterval: TimeInterval = 1.0 / 30.0 // 30fps max
    
    public enum QualityLevel: String, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case ultra = "ultra"
        
        public var analysisResolution: CGSize {
            switch self {
            case .low: return CGSize(width: 320, height: 240)
            case .medium: return CGSize(width: 640, height: 480)
            case .high: return CGSize(width: 1280, height: 720)
            case .ultra: return CGSize(width: 1920, height: 1080)
            }
        }
        
        public var maxAnalyzers: Int {
            switch self {
            case .low: return 2
            case .medium: return 3
            case .high: return 4
            case .ultra: return 6
            }
        }
        
        public var analysisInterval: TimeInterval {
            switch self {
            case .low: return 1.0 / 10.0 // 10fps analysis
            case .medium: return 1.0 / 15.0 // 15fps analysis
            case .high: return 1.0 / 20.0 // 20fps analysis
            case .ultra: return 1.0 / 30.0 // 30fps analysis
            }
        }
    }
    
    public struct PerformanceMetrics {
        public let averageProcessingTime: TimeInterval
        public let frameRate: Double
        public let droppedFramePercentage: Double
        public let memoryUsage: UInt64
        public let currentQualityLevel: QualityLevel
        public let isThrottling: Bool
        public let activeConcurrentTasks: Int
    }
    
    public struct PerformanceSettings {
        var enableAdaptiveQuality: Bool = true
        var targetFrameRate: Double = 30.0
        var maxProcessingTime: TimeInterval = 0.033
        var enableFrameSkipping: Bool = true
        var enableResourceThrottling: Bool = true
        var maxMemoryUsage: UInt64 = 200 * 1024 * 1024 // 200MB
        var enablePerformanceLogging: Bool = true
        
        public init() {}
    }
    
    private var settings = PerformanceSettings()
    
    private class FrameBuffer {
        private var buffer: [FrameData] = []
        private let capacity: Int
        private let queue = DispatchQueue(label: "com.neuroviews.framebuffer", qos: .utility)
        
        struct FrameData {
            let pixelBuffer: CVPixelBuffer
            let timestamp: CFTimeInterval
            let priority: AnalysisPriority
        }
        
        enum AnalysisPriority: Int, CaseIterable {
            case low = 0
            case normal = 1
            case high = 2
        }
        
        init(capacity: Int) {
            self.capacity = capacity
        }
        
        func addFrame(_ pixelBuffer: CVPixelBuffer, timestamp: CFTimeInterval, priority: AnalysisPriority = .normal) {
            queue.async {
                let frameData = FrameData(pixelBuffer: pixelBuffer, timestamp: timestamp, priority: priority)
                
                // Add frame and maintain capacity
                self.buffer.append(frameData)
                
                if self.buffer.count > self.capacity {
                    // Remove oldest frame with lowest priority
                    if let lowestPriorityIndex = self.buffer.enumerated().min(by: { lhs, rhs in
                        if lhs.element.priority.rawValue == rhs.element.priority.rawValue {
                            return lhs.element.timestamp < rhs.element.timestamp
                        }
                        return lhs.element.priority.rawValue < rhs.element.priority.rawValue
                    })?.offset {
                        self.buffer.remove(at: lowestPriorityIndex)
                    }
                }
            }
        }
        
        func getNextFrame(completion: @escaping (FrameData?) -> Void) {
            queue.async {
                // Get highest priority, most recent frame
                let sortedFrames = self.buffer.sorted { lhs, rhs in
                    if lhs.priority.rawValue == rhs.priority.rawValue {
                        return lhs.timestamp > rhs.timestamp
                    }
                    return lhs.priority.rawValue > rhs.priority.rawValue
                }
                
                if let nextFrame = sortedFrames.first,
                   let index = self.buffer.firstIndex(where: { $0.timestamp == nextFrame.timestamp }) {
                    self.buffer.remove(at: index)
                    completion(nextFrame)
                } else {
                    completion(nil)
                }
            }
        }
        
        func getCurrentBufferSize(completion: @escaping (Int) -> Void) {
            queue.async {
                completion(self.buffer.count)
            }
        }
        
        func clearBuffer() {
            queue.async {
                self.buffer.removeAll()
            }
        }
    }
    
    private init() {
        startPerformanceMonitoring()
    }
    
    // MARK: - Configuration
    
    public func configure(with settings: PerformanceSettings) {
        self.settings = settings
        targetFrameRate = settings.targetFrameRate
        maxProcessingTime = settings.maxProcessingTime
        isPerformanceMonitoringEnabled = settings.enablePerformanceLogging
        
        logger.info("Performance manager configured - Target FPS: \(settings.targetFrameRate), Max processing time: \(settings.maxProcessingTime * 1000)ms")
    }
    
    public func setQualityLevel(_ level: QualityLevel) {
        currentQualityLevel = level
        logger.info("Quality level set to: \(level.rawValue)")
    }
    
    // MARK: - Frame Processing Management
    
    public func shouldProcessFrame(timestamp: CFTimeInterval) -> Bool {
        let currentTime = CACurrentMediaTime()
        
        // Check if enough time has passed since last processed frame
        let timeSinceLastFrame = currentTime - lastProcessedFrameTime
        if timeSinceLastFrame < currentQualityLevel.analysisInterval {
            return false
        }
        
        // Check if we have too many concurrent analyses
        if activeAnalysisCount >= maxConcurrentAnalysis {
            return false
        }
        
        // Check if we're throttling due to performance
        if settings.enableResourceThrottling && isCurrentlyThrottling() {
            return false
        }
        
        return true
    }
    
    public func beginFrameProcessing() {
        activeAnalysisQueue.async {
            self.activeAnalysisCount += 1
        }
        lastProcessedFrameTime = CACurrentMediaTime()
    }
    
    public func endFrameProcessing(processingTime: TimeInterval) {
        activeAnalysisQueue.async {
            self.activeAnalysisCount = max(0, self.activeAnalysisCount - 1)
        }
        
        recordFrameProcessingTime(processingTime)
        updateAdaptiveQuality(processingTime: processingTime)
    }
    
    // MARK: - Adaptive Quality Management
    
    private func updateAdaptiveQuality(processingTime: TimeInterval) {
        guard settings.enableAdaptiveQuality else { return }
        
        performanceQueue.async {
            // Calculate recent average processing time
            let recentTimes = Array(self.frameProcessingTimes.suffix(30)) // Last 30 frames
            let averageTime = recentTimes.reduce(0, +) / Double(recentTimes.count)
            
            // Adjust quality based on performance
            if averageTime > self.maxProcessingTime * 1.2 {
                // Performance is poor, decrease quality
                self.decreaseQuality()
            } else if averageTime < self.maxProcessingTime * 0.6 && self.activeAnalysisCount < self.maxConcurrentAnalysis / 2 {
                // Performance is good and we have resources, increase quality
                self.increaseQuality()
            }
        }
    }
    
    private func decreaseQuality() {
        let newLevel: QualityLevel
        switch currentQualityLevel {
        case .ultra:
            newLevel = .high
        case .high:
            newLevel = .medium
        case .medium:
            newLevel = .low
        case .low:
            return // Already at lowest quality
        }
        
        currentQualityLevel = newLevel
        logger.info("Quality decreased to: \(newLevel.rawValue)")
    }
    
    private func increaseQuality() {
        let newLevel: QualityLevel
        switch currentQualityLevel {
        case .low:
            newLevel = .medium
        case .medium:
            newLevel = .high
        case .high:
            newLevel = .ultra
        case .ultra:
            return // Already at highest quality
        }
        
        currentQualityLevel = newLevel
        logger.info("Quality increased to: \(newLevel.rawValue)")
    }
    
    // MARK: - Resource Monitoring
    
    public func getMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        } else {
            return 0
        }
    }
    
    private func isCurrentlyThrottling() -> Bool {
        // Check memory usage
        let currentMemory = getMemoryUsage()
        if currentMemory > settings.maxMemoryUsage {
            logger.warning("Memory usage too high: \(currentMemory / (1024 * 1024))MB")
            return true
        }
        
        // Check recent performance
        let recentTimes = Array(frameProcessingTimes.suffix(10))
        if !recentTimes.isEmpty {
            let averageTime = recentTimes.reduce(0, +) / Double(recentTimes.count)
            if averageTime > maxProcessingTime * 1.5 {
                logger.warning("Processing time too high: \(averageTime * 1000)ms")
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Performance Metrics
    
    private func recordFrameProcessingTime(_ time: TimeInterval) {
        performanceQueue.async {
            self.frameProcessingTimes.append(time)
            
            // Keep only recent measurements
            if self.frameProcessingTimes.count > 100 {
                self.frameProcessingTimes.removeFirst()
            }
            
            self.totalFrameCount += 1
            
            // Log performance if enabled
            if self.settings.enablePerformanceLogging && self.totalFrameCount % 30 == 0 {
                let avgTime = self.frameProcessingTimes.suffix(30).reduce(0, +) / 30.0
                self.logger.info("Avg processing time (last 30 frames): \(avgTime * 1000)ms")
            }
        }
    }
    
    public func getPerformanceMetrics(completion: @escaping (PerformanceMetrics) -> Void) {
        performanceQueue.async {
            let averageProcessingTime = self.frameProcessingTimes.isEmpty ? 0 : 
                self.frameProcessingTimes.reduce(0, +) / Double(self.frameProcessingTimes.count)
            
            let frameRate = averageProcessingTime > 0 ? 1.0 / averageProcessingTime : 0.0
            
            let droppedFramePercentage = self.totalFrameCount > 0 ? 
                Double(self.droppedFrameCount) / Double(self.totalFrameCount) * 100 : 0.0
            
            let metrics = PerformanceMetrics(
                averageProcessingTime: averageProcessingTime,
                frameRate: min(frameRate, self.targetFrameRate),
                droppedFramePercentage: droppedFramePercentage,
                memoryUsage: self.getMemoryUsage(),
                currentQualityLevel: self.currentQualityLevel,
                isThrottling: self.isCurrentlyThrottling(),
                activeConcurrentTasks: self.activeAnalysisCount
            )
            
            DispatchQueue.main.async {
                completion(metrics)
            }
        }
    }
    
    // MARK: - Frame Buffer Management
    
    public func addFrameToBuffer(_ pixelBuffer: CVPixelBuffer, timestamp: CFTimeInterval, priority: AnalysisPriority = .normal) {
        let bufferPriority = FrameBuffer.AnalysisPriority(rawValue: priority.rawValue) ?? .normal
        frameBuffer.addFrame(pixelBuffer, timestamp: timestamp, priority: bufferPriority)
    }
    
    public func processNextFrameFromBuffer(completion: @escaping (CVPixelBuffer?) -> Void) {
        frameBuffer.getNextFrame { frameData in
            completion(frameData?.pixelBuffer)
        }
    }
    
    // MARK: - Image Optimization
    
    public func optimizeImageForAnalysis(_ image: CIImage) -> CIImage {
        let targetSize = currentQualityLevel.analysisResolution
        let imageSize = image.extent.size
        
        // Only resize if image is larger than target
        if imageSize.width > targetSize.width || imageSize.height > targetSize.height {
            let scaleX = targetSize.width / imageSize.width
            let scaleY = targetSize.height / imageSize.height
            let scale = min(scaleX, scaleY)
            
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            return image.transformed(by: transform)
        }
        
        return image
    }
    
    public func optimizePixelBufferForAnalysis(_ pixelBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        let targetSize = currentQualityLevel.analysisResolution
        let bufferWidth = CVPixelBufferGetWidth(pixelBuffer)
        let bufferHeight = CVPixelBufferGetHeight(pixelBuffer)
        
        // Only resize if buffer is larger than target
        if CGFloat(bufferWidth) <= targetSize.width && CGFloat(bufferHeight) <= targetSize.height {
            return pixelBuffer
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let optimizedImage = optimizeImageForAnalysis(ciImage)
        
        return createPixelBufferFromImage(optimizedImage)
    }
    
    private func createPixelBufferFromImage(_ image: CIImage) -> CVPixelBuffer? {
        let context = CIContext()
        let size = image.extent.size
        
        let attributes = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue
        ] as CFDictionary
        
        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
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
    
    // MARK: - Performance Monitoring
    
    private func startPerformanceMonitoring() {
        guard isPerformanceMonitoringEnabled else { return }
        
        Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            self.getPerformanceMetrics { metrics in
                if metrics.droppedFramePercentage > 10 {
                    self.logger.warning("High dropped frame rate: \(metrics.droppedFramePercentage)%")
                }
                
                if metrics.memoryUsage > self.settings.maxMemoryUsage * 80 / 100 {
                    self.logger.warning("Memory usage approaching limit: \(metrics.memoryUsage / (1024 * 1024))MB")
                }
            }
        }
    }
    
    // MARK: - Utility Methods
    
    public func resetPerformanceMetrics() {
        performanceQueue.async {
            self.frameProcessingTimes.removeAll()
            self.droppedFrameCount = 0
            self.totalFrameCount = 0
            self.lastFrameTime = 0
            self.lastProcessedFrameTime = 0
        }
        
        frameBuffer.clearBuffer()
        
        logger.info("Performance metrics reset")
    }
    
    public func recordDroppedFrame() {
        performanceQueue.async {
            self.droppedFrameCount += 1
        }
    }
    
    public func getCurrentQualityLevel() -> QualityLevel {
        return currentQualityLevel
    }
    
    public func getMaxAnalyzersForCurrentQuality() -> Int {
        return currentQualityLevel.maxAnalyzers
    }
    
    public func getAnalysisIntervalForCurrentQuality() -> TimeInterval {
        return currentQualityLevel.analysisInterval
    }
}