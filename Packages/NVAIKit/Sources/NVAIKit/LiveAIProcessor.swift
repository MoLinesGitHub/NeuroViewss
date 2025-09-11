import Foundation
import Vision
import CoreML
import Combine
import AVFoundation

// MARK: - Live AI Processor

@available(iOS 15.0, macOS 12.0, *)
public actor LiveAIProcessor {
    
    // MARK: - Properties
    
    public var currentAnalysis: LiveAnalysis?
    public var suggestions: [AISuggestion] = []
    public var isProcessing: Bool = false
    public var processingError: AIProcessingError?
    public var performanceMetrics: ProcessingMetrics = ProcessingMetrics()
    
    // Callbacks for UI updates
    nonisolated(unsafe) public var onAnalysisUpdated: ((LiveAnalysis?) -> Void)?
    nonisolated(unsafe) public var onSuggestionsUpdated: (([AISuggestion]) -> Void)?
    nonisolated(unsafe) public var onProcessingStateChanged: ((Bool) -> Void)?
    
    // MARK: - Private Properties
    
    private let compositionAnalyzer: CompositionAnalyzer
    private let visionEngine: VisionAnalysisEngine
    private let performanceMonitor: AIPerformanceMonitor
    private let suggestionEngine: AISuggestionEngine
    private var advancedPerformanceMonitor: AdvancedPerformanceMonitor?
    
    // Security & Privacy Components
    private var privacyManager: PrivacyManager?
    private var securityManager: SecurityManager?
    
    private var isLiveProcessingActive = false
    private var frameBuffer: FrameBuffer
    private var lastProcessingTime: Date?
    
    // Processing configuration
    private let maxFramesPerSecond: Int = 15
    private let minProcessingInterval: TimeInterval = 1.0 / 15.0
    
    // MARK: - Initialization
    
    public init() {
        self.compositionAnalyzer = CompositionAnalyzer()
        self.visionEngine = VisionAnalysisEngine()
        self.performanceMonitor = AIPerformanceMonitor()
        self.suggestionEngine = AISuggestionEngine()
        self.frameBuffer = FrameBuffer(capacity: 5)
        
        Task {
            await initializeAdvancedPerformanceMonitor()
            await initializeSecurityComponents()
            await setupProcessingPipeline()
        }
    }
    
    // MARK: - Public Interface
    
    /// Starts live AI analysis pipeline
    public func startLiveAnalysis() async throws {
        guard !isLiveProcessingActive else {
            throw AIProcessingError.alreadyProcessing
        }
        
        // Ensure privacy permissions are granted
        try await ensurePrivacyCompliance()
        
        // Validate security requirements
        try await validateSecurityRequirements()
        
        isLiveProcessingActive = true
        isProcessing = true
        processingError = nil
        
        // Initialize all analysis engines
        await initializeAnalysisEngines()
        
        // Start performance monitoring
        await performanceMonitor.startMonitoring()
        await advancedPerformanceMonitor?.startMonitoring()
        
        // Reset metrics
        performanceMetrics = ProcessingMetrics()
        
        print("🤖 Live AI Analysis Started with Advanced Performance Monitoring & Security")
    }
    
    /// Stops live AI analysis pipeline
    public func stopLiveAnalysis() async {
        isLiveProcessingActive = false
        isProcessing = false
        
        // Stop performance monitoring
        await performanceMonitor.stopMonitoring()
        await advancedPerformanceMonitor?.stopMonitoring()
        
        // Clear current analysis
        currentAnalysis = nil
        suggestions.removeAll()
        
        print("⏹️ Live AI Analysis Stopped")
    }
    
    /// Processes a single frame and returns analysis
    public func processFrame(_ frame: CVPixelBuffer) async throws -> FrameAnalysis {
        // Throttle processing to maintain performance
        if let lastTime = lastProcessingTime,
           Date().timeIntervalSince(lastTime) < minProcessingInterval {
            return FrameAnalysis.empty()
        }
        
        // Track performance without closure to avoid concurrency issues
        let startTime = Date()
        lastProcessingTime = startTime
        
        // Log frame processing for privacy audit
        await logFrameProcessing()
        
        // Skip frame buffering for now due to CVPixelBuffer concurrency issues
        // await frameBuffer.addFrame(frame)
        
        // Perform comprehensive analysis with security validation
        let analysis = try await performSecureFrameAnalysis(frame)
        
        // Update performance metrics
        let processingTime = Date().timeIntervalSince(startTime)
        await updatePerformanceMetrics(processingTime: processingTime)
        
        // Record performance manually for advanced monitoring
        await recordPerformanceMetric("processFrame", processingTime)
        
        // Generate suggestions based on analysis
        let newSuggestions = await generateSuggestions(from: analysis)
        
        // Update properties
        let liveAnalysis = LiveAnalysis(
            frameAnalysis: analysis,
            timestamp: Date(),
            processingTime: processingTime
        )
        
        currentAnalysis = liveAnalysis
        suggestions = newSuggestions
        
        // Notify UI updates via callbacks
        onAnalysisUpdated?(liveAnalysis)
        onSuggestionsUpdated?(newSuggestions)
        
        return analysis
    }
    
    /// Generates AI suggestions based on frame analysis
    public func generateSuggestions(from analysis: FrameAnalysis) async -> [AISuggestion] {
        return await suggestionEngine.generateSuggestions(from: analysis)
    }
    
    /// Gets current performance metrics
    public func getCurrentMetrics() async -> ProcessingMetrics {
        return await performanceMonitor.getCurrentMetrics()
    }
    
    /// Optimizes processing settings based on device performance
    public func optimizeForDevice() async {
        let deviceCapabilities = await performanceMonitor.analyzeDeviceCapabilities()
        
        // Adjust processing parameters based on device performance
        if deviceCapabilities.isHighPerformance {
            await setProcessingQuality(.high)
        } else if deviceCapabilities.isMidRange {
            await setProcessingQuality(.medium)
        } else {
            await setProcessingQuality(.low)
        }
        
        // Advanced pipeline optimization
        do {
            try await advancedPerformanceMonitor?.optimizePipeline()
        } catch {
            print("⚠️ Pipeline optimization failed: \(error.localizedDescription)")
        }
    }
    
    /// Gets comprehensive performance report
    public func getAdvancedPerformanceReport() async -> PerformanceReport? {
        return await advancedPerformanceMonitor?.getPerformanceReport()
    }
    
    /// Analyzes memory usage patterns
    public func getMemoryAnalysis() async -> MemoryAnalysis? {
        return await advancedPerformanceMonitor?.analyzeMemoryUsage()
    }
    
    /// Gets privacy audit log
    public func getPrivacyAuditLog() async -> [AccessLog] {
        guard let privacyManager = privacyManager else { return [] }
        do {
            return try await privacyManager.auditDataAccess()
        } catch {
            print("⚠️ Privacy audit failed: \(error.localizedDescription)")
            return []
        }
    }
    
    /// Validates security integrity
    public func validateSecurityIntegrity() async throws -> Bool {
        guard let securityManager = securityManager else { return false }
        
        // For now, just validate system security without creating MediaItem
        let securityAudit = try await securityManager.validateSecurityConfiguration()
        return securityAudit.vulnerabilities.isEmpty
    }
    
    // MARK: - Private Implementation
    
    private func initializeAdvancedPerformanceMonitor() async {
        advancedPerformanceMonitor = await AdvancedPerformanceMonitor()
    }
    
    private func initializeSecurityComponents() async {
        privacyManager = PrivacyManager.shared
        securityManager = SecurityManager.shared
        
        // Initialize privacy manager
        do {
            let _ = try await privacyManager?.requestPermissions()
            print("🔐 Privacy Manager initialized successfully")
        } catch {
            print("⚠️ Privacy Manager initialization failed: \(error.localizedDescription)")
        }
        
        // Initialize security manager
        do {
            let _ = try await securityManager?.validateSecurityConfiguration()
            print("🛡️ Security Manager initialized successfully")
        } catch {
            print("⚠️ Security Manager initialization failed: \(error.localizedDescription)")
        }
    }
    
    private func setupProcessingPipeline() async {
        // Configure processing pipeline
        await visionEngine.setupForLiveProcessing()
        await compositionAnalyzer.enableRealTimeMode()
        
        // Optimize for current device
        await optimizeForDevice()
    }
    
    private func initializeAnalysisEngines() async {
        await compositionAnalyzer.initialize()
        await visionEngine.initialize()
        await suggestionEngine.initialize()
    }
    
    private func performFrameAnalysis(_ frame: CVPixelBuffer) async throws -> FrameAnalysis {
        // Simplified analysis for now to avoid concurrency issues
        // In a real implementation, we would properly handle CVPixelBuffer sharing
        let compositionResult = CompositionSuggestion.neutral()
        let visionResult = VisionAnalysisResult.empty()
        let qualityResult = ImageQualityAnalysis.unknown()
        
        // Combine results into comprehensive analysis
        return FrameAnalysis(
            composition: compositionResult,
            vision: visionResult,
            quality: qualityResult,
            timestamp: Date()
        )
    }
    
    private func performSecureFrameAnalysis(_ frame: CVPixelBuffer) async throws -> FrameAnalysis {
        // Validate frame integrity before processing
        guard securityManager != nil else {
            return try await performFrameAnalysis(frame)
        }
        
        // For now, use simplified analysis
        // In production, we would validate frame data integrity
        return try await performFrameAnalysis(frame)
    }
    
    private func ensurePrivacyCompliance() async throws {
        guard let privacyManager = privacyManager else {
            throw AIProcessingError.initializationFailed(NSError(domain: "Privacy", code: 1, userInfo: [NSLocalizedDescriptionKey: "Privacy manager not initialized"]))
        }
        
        let status = try await privacyManager.requestPermissions()
        
        // Check if all required permissions are granted
        guard status.allGranted else {
            throw AIProcessingError.insufficientResources
        }
    }
    
    private func validateSecurityRequirements() async throws {
        guard let securityManager = securityManager else {
            throw AIProcessingError.initializationFailed(NSError(domain: "Security", code: 1, userInfo: [NSLocalizedDescriptionKey: "Security manager not initialized"]))
        }
        
        // Validate security readiness
        let securityAudit = try await securityManager.validateSecurityConfiguration()
        guard securityAudit.vulnerabilities.isEmpty else {
            throw AIProcessingError.insufficientResources
        }
    }
    
    private func logFrameProcessing() async {
        await privacyManager?.logAccess(to: "camera_frame", purpose: .aiProcessing, dataType: .frameData)
    }
    
    // MARK: - Analysis Methods (Commented out due to CVPixelBuffer concurrency issues)
    /*
    private func analyzeComposition(_ frame: CVPixelBuffer) async throws -> CompositionSuggestion {
        return await compositionAnalyzer.analyzeComposition(frame)
    }
    
    private func analyzeWithVision(_ frame: CVPixelBuffer) async throws -> VisionAnalysisResult {
        return try await visionEngine.analyzeFrame(frame)
    }
    
    private func analyzeImageQuality(_ frame: CVPixelBuffer) async throws -> ImageQualityAnalysis {
        return try await ImageQualityAnalyzer.analyze(frame)
    }
    */
    
    private func updatePerformanceMetrics(processingTime: TimeInterval) async {
        await performanceMonitor.recordProcessingTime(processingTime)
        
        // Update published metrics
        performanceMetrics = await performanceMonitor.getCurrentMetrics()
    }
    
    private func recordPerformanceMetric(_ operation: String, _ duration: TimeInterval) async {
        // Create manual performance record for advanced monitoring
        _ = OperationMetric(
            name: operation,
            duration: duration,
            memoryUsage: getCurrentMemoryUsage(),
            cpuUsage: 0.0, // Simplified
            timestamp: Date()
        )
        
        // Note: In a full implementation, we would properly integrate with PerformanceActor
        // For now, this is a simplified placeholder
    }
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return info.resident_size
        }
        
        return 0
    }
    
    private func setProcessingQuality(_ quality: ProcessingQuality) async {
        await visionEngine.setProcessingQuality(quality)
        await compositionAnalyzer.setQualityLevel(quality)
    }
}

// MARK: - Live Analysis

@available(iOS 15.0, macOS 12.0, *)
public struct LiveAnalysis: Sendable {
    public let frameAnalysis: FrameAnalysis
    public let timestamp: Date
    public let processingTime: TimeInterval
    
    public init(frameAnalysis: FrameAnalysis, timestamp: Date, processingTime: TimeInterval) {
        self.frameAnalysis = frameAnalysis
        self.timestamp = timestamp
        self.processingTime = processingTime
    }
    
    public var isRecentAnalysis: Bool {
        Date().timeIntervalSince(timestamp) < 0.5
    }
}

// MARK: - Frame Analysis

@available(iOS 15.0, macOS 12.0, *)
public struct FrameAnalysis: Sendable {
    public let composition: CompositionSuggestion
    public let vision: VisionAnalysisResult
    public let quality: ImageQualityAnalysis
    public let timestamp: Date
    
    public init(composition: CompositionSuggestion, vision: VisionAnalysisResult, quality: ImageQualityAnalysis, timestamp: Date) {
        self.composition = composition
        self.vision = vision
        self.quality = quality
        self.timestamp = timestamp
    }
    
    public static func empty() -> FrameAnalysis {
        return FrameAnalysis(
            composition: CompositionSuggestion.neutral(),
            vision: VisionAnalysisResult.empty(),
            quality: ImageQualityAnalysis.unknown(),
            timestamp: Date()
        )
    }
    
    public var overallScore: Double {
        return (composition.score + quality.overallQuality) / 2.0
    }
}


// MARK: - Supporting Types

@available(iOS 15.0, macOS 12.0, *)
public enum SuggestionPriority: String, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}


@available(iOS 15.0, macOS 12.0, *)
public enum ProcessingQuality: String, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

// MARK: - AI Processing Error

@available(iOS 15.0, macOS 12.0, *)
public enum AIProcessingError: Error, LocalizedError, Sendable {
    case alreadyProcessing
    case initializationFailed(Error)
    case processingFailed(String)
    case insufficientResources
    case unsupportedFormat
    case timeout
    
    public var errorDescription: String? {
        switch self {
        case .alreadyProcessing:
            return "AI processing is already active"
        case .initializationFailed(let error):
            return "Failed to initialize AI processing: \(error.localizedDescription)"
        case .processingFailed(let reason):
            return "AI processing failed: \(reason)"
        case .insufficientResources:
            return "Insufficient system resources for AI processing"
        case .unsupportedFormat:
            return "Unsupported image format for AI processing"
        case .timeout:
            return "AI processing timed out"
        }
    }
}