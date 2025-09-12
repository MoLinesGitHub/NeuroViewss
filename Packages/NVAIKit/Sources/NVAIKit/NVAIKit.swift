import Foundation
import Vision
import CoreML
import CoreImage
import Combine
import AVFoundation
import os.log

// MARK: - AI Analysis Engine Protocol

public protocol AIAnalysisEngine: Sendable {
    func analyzeScene(_ image: CIImage) async throws -> SceneAnalysis
    func detectObjects(_ image: CIImage) async throws -> [DetectedObject]
    func enhanceImage(_ image: CIImage) async throws -> EnhancedImage
}

// MARK: - AI Data Types

public struct SceneAnalysis: Sendable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let confidence: Float
    public let sceneType: SceneType
    public let lightingConditions: LightingConditions
    public let suggestions: [AISuggestion]
    
    public init(
        sceneType: SceneType,
        lightingConditions: LightingConditions,
        suggestions: [AISuggestion] = [],
        confidence: Float = 0.0
    ) {
        self.id = UUID()
        self.timestamp = Date()
        self.confidence = confidence
        self.sceneType = sceneType
        self.lightingConditions = lightingConditions
        self.suggestions = suggestions
    }
}

public enum SceneType: String, Codable, CaseIterable, Sendable {
    case portrait = "portrait"
    case landscape = "landscape"
    case macro = "macro"
    case night = "night"
    case sport = "sport"
    case street = "street"
    case architecture = "architecture"
    case nature = "nature"
    case unknown = "unknown"
}

public enum LightingConditions: String, Codable, CaseIterable, Sendable {
    case bright = "bright"
    case natural = "natural"
    case dim = "dim"
    case backlit = "backlit"
    case artificial = "artificial"
    case mixed = "mixed"
}




// MARK: - Enhanced AI Analysis
public struct AIAnalysis: Sendable {
    public let id: UUID
    public let timestamp: Date
    public let type: AnalysisType
    public let data: [String: Any]
    public let confidence: Float
    public let processingTime: TimeInterval
    
    public init(type: AnalysisType, data: [String: Any], confidence: Float = 0.0, processingTime: TimeInterval = 0.0) {
        self.id = UUID()
        self.timestamp = Date()
        self.type = type
        self.data = data
        self.confidence = confidence
        self.processingTime = processingTime
    }
}

public enum AnalysisType: String, Codable, CaseIterable, Sendable {
    case exposure = "exposure"
    case stability = "stability"
    case focus = "focus"
    case composition = "composition"
    case scene = "scene"
    case performance = "performance"
}

// MARK: - Memory-Optimized NVAIKit
@available(iOS 15.0, macOS 12.0, *)
public final class NVAIKit: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = NVAIKit()
    
    // MARK: - Published Properties
    @Published public private(set) var isPerformanceOptimized = false
    @Published public private(set) var currentMemoryPressure: MemoryPressure = .normal
    @Published public private(set) var analysisQuality: AnalysisQuality = .high
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.neuroviews.ai", category: "core")
    private let memoryOptimizer = MemoryOptimizer.shared
    private let lazyLoader = LazyAILoader.shared
    private let performanceMonitor = PerformanceMonitor.shared
    
    // Analysis throttling
    private var analysisQueue = DispatchQueue(label: "com.neuroviews.ai.analysis", qos: .userInitiated)
    private var lastAnalysisTime: CFTimeInterval = 0
    private var minimumAnalysisInterval: CFTimeInterval = 0.033 // 30 FPS
    
    // Memory management
    private var analysisCache: [String: AIAnalysis] = [:]
    private let cacheLimit = 50
    
    private init() {
        setupPerformanceOptimization()
        setupMemoryManagement()
    }
    
    // MARK: - Public API
    
    /// Start performance optimization
    public func startPerformanceOptimization() async {
        logger.info("🚀 Starting NVAIKit performance optimization")
        
        await memoryOptimizer.startOptimization()
        await performanceMonitor.startMonitoring()
        
        // Preload essential components
        await lazyLoader.preloadFrequentComponents()
        
        isPerformanceOptimized = true
        logger.info("✅ NVAIKit performance optimization active")
    }
    
    /// Stop performance optimization
    public func stopPerformanceOptimization() async {
        logger.info("⏹️ Stopping NVAIKit performance optimization")
        
        await memoryOptimizer.stopOptimization()
        await performanceMonitor.stopMonitoring()
        
        isPerformanceOptimized = false
        logger.info("✅ NVAIKit performance optimization stopped")
    }
    
    /// Analyze frame with memory optimization
    public func analyzeFrame(_ pixelBuffer: CVPixelBuffer, analysisType: AnalysisType) async throws -> AIAnalysis? {
        // Throttling check
        let currentTime = CACurrentMediaTime()
        guard currentTime - lastAnalysisTime >= minimumAnalysisInterval else {
            return getCachedAnalysis(for: analysisType)
        }
        
        // Memory pressure check
        if currentMemoryPressure == .critical {
            await adjustQualityForMemoryPressure()
        }
        
        // Track performance
        return await performanceMonitor.trackFrameProcessing {
            return try await self.performFrameAnalysis(pixelBuffer, analysisType: analysisType)
        }
    }
    
    /// Get AI component with lazy loading
    public func getAIComponent<T>(_ component: AIComponent, type: T.Type) async throws -> T {
        return try await lazyLoader.loadComponent(component, type: type)
    }
    
    /// Force memory cleanup
    public func performMemoryCleanup() async {
        await memoryOptimizer.performMemoryCleanup()
        await lazyLoader.unloadUnusedComponents()
        clearAnalysisCache()
    }
    
    /// Get performance report
    public func getPerformanceReport() async -> NVAIKitPerformanceReport {
        let performanceReport = await performanceMonitor.getPerformanceReport()
        let memoryReport = await memoryOptimizer.detectMemoryLeaks()
        let loadingStats = await lazyLoader.getLoadingStatistics()
        
        return NVAIKitPerformanceReport(
            performance: performanceReport,
            memory: memoryReport,
            loading: loadingStats,
            analysisQuality: analysisQuality
        )
    }
    
    // MARK: - Private Implementation
    
    private func setupPerformanceOptimization() {
        // Subscribe to memory pressure changes
        Task { @MainActor in
            for await memoryPressure in memoryOptimizer.$memoryPressure.values {
                self.currentMemoryPressure = memoryPressure
                await self.adaptToMemoryPressure(memoryPressure)
            }
        }
    }
    
    private func setupMemoryManagement() {
        // Setup automatic cleanup timer
        Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.performPeriodicCleanup()
            }
        }
    }
    
    private func performFrameAnalysis(_ pixelBuffer: CVPixelBuffer, analysisType: AnalysisType) async throws -> AIAnalysis {
        let startTime = CACurrentMediaTime()
        
        // Create optimized pixel buffer if needed
        let optimizedBuffer = await getOptimizedPixelBuffer(from: pixelBuffer)
        
        var analysisData: [String: Any] = [:]
        var confidence: Float = 0.0
        
        switch analysisType {
        case .exposure:
            let analyzer = try await lazyLoader.loadComponent(.exposureAnalyzer, type: ExposureAnalyzer.self)
            if let analysis = analyzer.analyze(frame: optimizedBuffer) {
                analysisData = analysis.data
                confidence = analysis.confidence
            }
            
        case .stability:
            let analyzer = try await lazyLoader.loadComponent(.stabilityAnalyzer, type: StabilityAnalyzer.self)
            if let analysis = analyzer.analyzeStability(pixelBuffer: optimizedBuffer) {
                analysisData = ["stabilityScore": analysis.stabilityScore, "motionVector": analysis.motionVector]
                confidence = analysis.confidence
            }
            
        case .focus:
            let analyzer = try await lazyLoader.loadComponent(.focusAnalyzer, type: FocusAnalyzer.self)
            if let analysis = analyzer.analyzeFocus(pixelBuffer: optimizedBuffer) {
                analysisData = ["sharpnessScore": analysis.sharpnessScore, "focusPoints": analysis.focusPoints]
                confidence = analysis.confidence
            }
            
        case .composition:
            let guides = try await lazyLoader.loadComponent(.smartCompositionGuides, type: SmartCompositionGuides.self)
            // Analysis would be implemented here
            
        case .scene:
            let detector = try await lazyLoader.loadComponent(.subjectDetector, type: AdvancedSubjectDetector.self)
            let detectedSubjects = await detector.detectSubjects(in: optimizedBuffer)
            analysisData = ["subjects": detectedSubjects.map { [$0.type.rawValue: $0.boundingBox] }]
            confidence = detectedSubjects.isEmpty ? 0.0 : detectedSubjects.map { $0.confidence }.reduce(0, +) / Float(detectedSubjects.count)
            
        case .performance:
            // Performance analysis would be implemented here
            break
        }
        
        let processingTime = CACurrentMediaTime() - startTime
        lastAnalysisTime = CACurrentMediaTime()
        
        let analysis = AIAnalysis(
            type: analysisType,
            data: analysisData,
            confidence: confidence,
            processingTime: processingTime
        )
        
        // Cache the analysis
        cacheAnalysis(analysis, for: analysisType)
        
        return analysis
    }
    
    private func getOptimizedPixelBuffer(from original: CVPixelBuffer) async -> CVPixelBuffer {
        // Use optimized pixel buffer from memory optimizer if available
        let width = CVPixelBufferGetWidth(original)
        let height = CVPixelBufferGetHeight(original)
        
        if analysisQuality == .low {
            // Use smaller resolution for low quality
            return await memoryOptimizer.getOptimizedPixelBuffer(width: width / 2, height: height / 2) ?? original
        }
        
        return original
    }
    
    private func adaptToMemoryPressure(_ pressure: MemoryPressure) async {
        switch pressure {
        case .normal:
            analysisQuality = .high
            minimumAnalysisInterval = 0.033 // 30 FPS
            
        case .moderate:
            analysisQuality = .medium
            minimumAnalysisInterval = 0.05 // 20 FPS
            
        case .high:
            analysisQuality = .low
            minimumAnalysisInterval = 0.1 // 10 FPS
            
        case .critical:
            analysisQuality = .minimal
            minimumAnalysisInterval = 0.2 // 5 FPS
            await performMemoryCleanup()
        }
        
        logger.info("📊 Adapted to memory pressure: \(pressure.description), quality: \(analysisQuality)")
    }
    
    private func adjustQualityForMemoryPressure() async {
        if analysisQuality != .minimal {
            analysisQuality = AnalysisQuality(rawValue: max(0, analysisQuality.rawValue - 1)) ?? .minimal
        }
    }
    
    private func performPeriodicCleanup() async {
        // Cleanup analysis cache
        if analysisCache.count > cacheLimit {
            clearAnalysisCache()
        }
        
        // Trigger component cleanup
        await lazyLoader.unloadUnusedComponents()
    }
    
    private func cacheAnalysis(_ analysis: AIAnalysis, for type: AnalysisType) {
        analysisCache[type.rawValue] = analysis
        
        if analysisCache.count > cacheLimit {
            // Remove oldest entries
            let sortedKeys = analysisCache.keys.sorted { key1, key2 in
                analysisCache[key1]?.timestamp ?? Date.distantPast < analysisCache[key2]?.timestamp ?? Date.distantPast
            }
            
            for key in sortedKeys.prefix(sortedKeys.count - cacheLimit + 10) {
                analysisCache.removeValue(forKey: key)
            }
        }
    }
    
    private func getCachedAnalysis(for type: AnalysisType) -> AIAnalysis? {
        return analysisCache[type.rawValue]
    }
    
    private func clearAnalysisCache() {
        analysisCache.removeAll()
        logger.info("🗑️ Analysis cache cleared")
    }
}

// MARK: - Analysis Quality
public enum AnalysisQuality: Int, CaseIterable {
    case minimal = 0
    case low = 1
    case medium = 2
    case high = 3
    
    public var description: String {
        switch self {
        case .minimal: return "Minimal"
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

// MARK: - Performance Report
public struct NVAIKitPerformanceReport {
    public let performance: PerformanceReport
    public let memory: LeakDetectionReport
    public let loading: LoadingStatistics
    public let analysisQuality: AnalysisQuality
}
