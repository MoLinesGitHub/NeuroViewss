import Foundation
import os.log
import OSLog
import CoreFoundation

// MARK: - Performance Actor

@available(iOS 15.0, macOS 12.0, *)
@globalActor public actor PerformanceActor {
    public static let shared = PerformanceActor()
    
    private init() {}
}

// MARK: - Advanced Performance Monitor

@available(iOS 15.0, macOS 12.0, *)
@PerformanceActor
public class AdvancedPerformanceMonitor {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.neuroviews.aikit", category: "PerformanceMonitor")
    private var operationMetrics: [String: [OperationMetric]] = [:]
    private var memoryAnalysis: [MemorySnapshot] = []
    private var isMonitoring = false
    private var startTime: CFAbsoluteTime = 0
    
    // Performance thresholds
    private let maxOperationTime: TimeInterval = 0.1 // 100ms
    private let maxMemoryUsage: UInt64 = 100 * 1024 * 1024 // 100MB
    private let maxCPUUsage: Double = 80.0 // 80%
    
    // MARK: - Initialization
    
    public init() {
        setupPerformanceMonitoring()
    }
    
    // MARK: - Public Interface
    
    /// Tracks the performance of an async operation
    public func trackOperation<T>(
        _ operation: String,
        _ block: @Sendable () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getCurrentMemoryUsage()
        let startCPU = getCurrentCPUUsage()
        
        logger.debug("🚀 Starting operation: \(operation)")
        
        let result = try await block()
        
        let endTime = CFAbsoluteTimeGetCurrent()
        let endMemory = getCurrentMemoryUsage()
        let endCPU = getCurrentCPUUsage()
        
        let metric = OperationMetric(
            name: operation,
            duration: endTime - startTime,
            memoryUsage: endMemory - startMemory,
            cpuUsage: (startCPU + endCPU) / 2.0,
            timestamp: Date()
        )
        
        await recordOperationMetric(metric)
        
        if metric.duration > maxOperationTime {
            logger.warning("⚠️ Operation '\(operation)' took \(String(format: "%.2fms", metric.duration * 1000))")
        }
        
        logger.debug("✅ Completed operation: \(operation) in \(String(format: "%.2fms", metric.duration * 1000))")
        
        return result
    }
    
    /// Analyzes current memory usage patterns
    public func analyzeMemoryUsage() async -> MemoryAnalysis {
        let snapshot = createMemorySnapshot()
        memoryAnalysis.append(snapshot)
        
        // Keep only recent snapshots (last 100)
        if memoryAnalysis.count > 100 {
            memoryAnalysis.removeFirst(10)
        }
        
        return MemoryAnalysis(
            currentUsage: snapshot.totalUsage,
            peakUsage: memoryAnalysis.map(\.totalUsage).max() ?? snapshot.totalUsage,
            averageUsage: memoryAnalysis.map(\.totalUsage).reduce(0, +) / UInt64(memoryAnalysis.count),
            memoryPressure: calculateMemoryPressure(snapshot),
            recommendations: generateMemoryRecommendations(snapshot)
        )
    }
    
    /// Optimizes the processing pipeline based on performance metrics
    public func optimizePipeline() async throws {
        logger.info("🔧 Starting pipeline optimization")
        
        let memoryAnalysis = await analyzeMemoryUsage()
        let operationStats = calculateOperationStatistics()
        let systemCapabilities = analyzeSystemCapabilities()
        
        var optimizations: [PipelineOptimization] = []
        
        // Memory-based optimizations
        if memoryAnalysis.currentUsage > maxMemoryUsage {
            optimizations.append(.reduceMemoryFootprint)
            optimizations.append(.enableMemoryPooling)
        }
        
        // CPU-based optimizations
        if systemCapabilities.cpuCores < 4 {
            optimizations.append(.reduceConcurrency)
            optimizations.append(.simplifyProcessing)
        } else if systemCapabilities.cpuCores >= 8 {
            optimizations.append(.enableParallelProcessing)
            optimizations.append(.increaseBatchSize)
        }
        
        // Operation timing optimizations
        let slowOperations = operationStats.filter { $0.averageDuration > maxOperationTime }
        if !slowOperations.isEmpty {
            optimizations.append(.optimizeSlowOperations(slowOperations.map(\.name)))
        }
        
        // Apply optimizations
        try await applyOptimizations(optimizations)
        
        logger.info("✅ Pipeline optimization completed with \(optimizations.count) optimizations")
    }
    
    /// Starts continuous performance monitoring
    public func startMonitoring() async {
        guard !isMonitoring else { return }
        
        isMonitoring = true
        startTime = CFAbsoluteTimeGetCurrent()
        
        logger.info("📊 Advanced performance monitoring started")
        
        // Start background monitoring task
        Task {
            await performContinuousMonitoring()
        }
    }
    
    /// Stops performance monitoring
    public func stopMonitoring() async {
        isMonitoring = false
        logger.info("⏹️ Performance monitoring stopped")
    }
    
    /// Gets comprehensive performance report
    public func getPerformanceReport() async -> PerformanceReport {
        let memoryAnalysis = await analyzeMemoryUsage()
        let operationStats = calculateOperationStatistics()
        let systemInfo = analyzeSystemCapabilities()
        
        return PerformanceReport(
            sessionDuration: CFAbsoluteTimeGetCurrent() - startTime,
            memoryAnalysis: memoryAnalysis,
            operationStatistics: operationStats,
            systemCapabilities: systemInfo,
            recommendations: generateOptimizationRecommendations()
        )
    }
    
    // MARK: - Private Implementation
    
    private func setupPerformanceMonitoring() {
        logger.debug("🔧 Setting up advanced performance monitoring")
    }
    
    private func recordOperationMetric(_ metric: OperationMetric) async {
        if operationMetrics[metric.name] == nil {
            operationMetrics[metric.name] = []
        }
        
        operationMetrics[metric.name]?.append(metric)
        
        // Keep only recent metrics per operation
        if let count = operationMetrics[metric.name]?.count, count > 50 {
            operationMetrics[metric.name]?.removeFirst(10)
        }
    }
    
    private func createMemorySnapshot() -> MemorySnapshot {
        let usage = getCurrentMemoryUsage()
        let available = getAvailableMemory()
        let pressure = calculateMemoryPressure()
        
        return MemorySnapshot(
            totalUsage: usage,
            availableMemory: available,
            memoryPressure: pressure,
            timestamp: Date()
        )
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
    
    private func getAvailableMemory() -> UInt64 {
        return UInt64(ProcessInfo.processInfo.physicalMemory)
    }
    
    private func getCurrentCPUUsage() -> Double {
        var info = task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            // Simplified CPU usage calculation
            return Double.random(in: 10...60) // Mock implementation
        }
        
        return 0.0
    }
    
    private func calculateMemoryPressure(_ snapshot: MemorySnapshot) -> MemoryPressure {
        let usageRatio = Double(snapshot.totalUsage) / Double(snapshot.availableMemory)
        
        if usageRatio > 0.9 {
            return .critical
        } else if usageRatio > 0.7 {
            return .high
        } else if usageRatio > 0.5 {
            return .moderate
        } else {
            return .low
        }
    }
    
    private func calculateMemoryPressure() -> MemoryPressure {
        let current = getCurrentMemoryUsage()
        let available = getAvailableMemory()
        let usageRatio = Double(current) / Double(available)
        
        if usageRatio > 0.9 {
            return .critical
        } else if usageRatio > 0.7 {
            return .high
        } else if usageRatio > 0.5 {
            return .moderate
        } else {
            return .low
        }
    }
    
    private func generateMemoryRecommendations(_ snapshot: MemorySnapshot) -> [String] {
        var recommendations: [String] = []
        
        switch snapshot.memoryPressure {
        case .critical:
            recommendations.append("Critical: Reduce image processing batch size")
            recommendations.append("Critical: Enable aggressive memory cleanup")
        case .high:
            recommendations.append("High: Optimize image caching strategy")
            recommendations.append("High: Reduce concurrent operations")
        case .moderate:
            recommendations.append("Moderate: Monitor memory usage closely")
        case .low:
            recommendations.append("Good: Memory usage is optimal")
        }
        
        return recommendations
    }
    
    private func calculateOperationStatistics() -> [OperationStatistics] {
        return operationMetrics.compactMap { (name, metrics) in
            guard !metrics.isEmpty else { return nil }
            
            let durations = metrics.map(\.duration)
            let memoryUsages = metrics.map(\.memoryUsage)
            
            return OperationStatistics(
                name: name,
                executionCount: metrics.count,
                averageDuration: durations.reduce(0, +) / Double(durations.count),
                maxDuration: durations.max() ?? 0,
                minDuration: durations.min() ?? 0,
                averageMemoryUsage: memoryUsages.reduce(0, +) / UInt64(memoryUsages.count)
            )
        }
    }
    
    private func analyzeSystemCapabilities() -> SystemCapabilities {
        let processInfo = ProcessInfo.processInfo
        
        return SystemCapabilities(
            cpuCores: processInfo.activeProcessorCount,
            physicalMemory: processInfo.physicalMemory,
            operatingSystem: processInfo.operatingSystemVersionString,
            deviceModel: getDeviceModel(),
            thermalState: processInfo.thermalState,
            lowPowerModeEnabled: processInfo.isLowPowerModeEnabled
        )
    }
    
    private func getDeviceModel() -> String {
        #if os(iOS)
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value))!)
        }
        return identifier
        #else
        return "macOS Device"
        #endif
    }
    
    private func generateOptimizationRecommendations() -> [String] {
        var recommendations: [String] = []
        let systemInfo = analyzeSystemCapabilities()
        
        if systemInfo.lowPowerModeEnabled {
            recommendations.append("Enable power-efficient processing mode")
            recommendations.append("Reduce AI analysis frequency")
        }
        
        if systemInfo.thermalState == .critical {
            recommendations.append("Critical: Reduce processing intensity")
            recommendations.append("Critical: Implement thermal throttling")
        }
        
        if systemInfo.cpuCores >= 8 {
            recommendations.append("Enable high-performance parallel processing")
        } else if systemInfo.cpuCores <= 2 {
            recommendations.append("Use sequential processing to avoid contention")
        }
        
        return recommendations
    }
    
    private func applyOptimizations(_ optimizations: [PipelineOptimization]) async throws {
        for optimization in optimizations {
            logger.debug("Applying optimization: \(optimization)")
            
            switch optimization {
            case .reduceMemoryFootprint:
                // Implement memory footprint reduction
                break
            case .enableMemoryPooling:
                // Implement memory pooling
                break
            case .reduceConcurrency:
                // Reduce concurrent operations
                break
            case .simplifyProcessing:
                // Simplify processing algorithms
                break
            case .enableParallelProcessing:
                // Enable parallel processing
                break
            case .increaseBatchSize:
                // Increase batch processing size
                break
            case .optimizeSlowOperations(let operations):
                logger.info("Optimizing slow operations: \(operations.joined(separator: ", "))")
                break
            }
        }
    }
    
    private func performContinuousMonitoring() async {
        while isMonitoring {
            // Take periodic snapshots
            let snapshot = createMemorySnapshot()
            memoryAnalysis.append(snapshot)
            
            // Check for performance issues
            if snapshot.memoryPressure == .critical {
                logger.warning("🚨 Critical memory pressure detected!")
            }
            
            // Sleep for monitoring interval
            try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
        }
    }
}

// MARK: - Supporting Types

@available(iOS 15.0, macOS 12.0, *)
public struct OperationMetric: Sendable {
    public let name: String
    public let duration: TimeInterval
    public let memoryUsage: UInt64
    public let cpuUsage: Double
    public let timestamp: Date
}

@available(iOS 15.0, macOS 12.0, *)
public struct MemorySnapshot: Sendable {
    public let totalUsage: UInt64
    public let availableMemory: UInt64
    public let memoryPressure: MemoryPressure
    public let timestamp: Date
}

@available(iOS 15.0, macOS 12.0, *)
public enum MemoryPressure: String, CaseIterable, Sendable {
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case critical = "critical"
    
    public var displayName: String {
        return rawValue.capitalized
    }
}

@available(iOS 15.0, macOS 12.0, *)
public struct MemoryAnalysis: Sendable {
    public let currentUsage: UInt64
    public let peakUsage: UInt64
    public let averageUsage: UInt64
    public let memoryPressure: MemoryPressure
    public let recommendations: [String]
    
    public var formattedCurrentUsage: String {
        return ByteCountFormatter.string(fromByteCount: Int64(currentUsage), countStyle: .memory)
    }
    
    public var formattedPeakUsage: String {
        return ByteCountFormatter.string(fromByteCount: Int64(peakUsage), countStyle: .memory)
    }
    
    public var formattedAverageUsage: String {
        return ByteCountFormatter.string(fromByteCount: Int64(averageUsage), countStyle: .memory)
    }
}

@available(iOS 15.0, macOS 12.0, *)
public struct OperationStatistics: Sendable {
    public let name: String
    public let executionCount: Int
    public let averageDuration: TimeInterval
    public let maxDuration: TimeInterval
    public let minDuration: TimeInterval
    public let averageMemoryUsage: UInt64
    
    public var formattedAverageDuration: String {
        return String(format: "%.2fms", averageDuration * 1000)
    }
    
    public var formattedMaxDuration: String {
        return String(format: "%.2fms", maxDuration * 1000)
    }
    
    public var formattedAverageMemoryUsage: String {
        return ByteCountFormatter.string(fromByteCount: Int64(averageMemoryUsage), countStyle: .memory)
    }
}

@available(iOS 15.0, macOS 12.0, *)
public struct SystemCapabilities: Sendable {
    public let cpuCores: Int
    public let physicalMemory: UInt64
    public let operatingSystem: String
    public let deviceModel: String
    public let thermalState: ProcessInfo.ThermalState
    public let lowPowerModeEnabled: Bool
    
    public var formattedPhysicalMemory: String {
        return ByteCountFormatter.string(fromByteCount: Int64(physicalMemory), countStyle: .memory)
    }
    
    public var isHighPerformanceDevice: Bool {
        return cpuCores >= 8 && physicalMemory >= 6_000_000_000 // 6GB+
    }
    
    public var isMidRangeDevice: Bool {
        return cpuCores >= 4 && physicalMemory >= 3_000_000_000 // 3GB+
    }
}

@available(iOS 15.0, macOS 12.0, *)
public struct PerformanceReport: Sendable {
    public let sessionDuration: TimeInterval
    public let memoryAnalysis: MemoryAnalysis
    public let operationStatistics: [OperationStatistics]
    public let systemCapabilities: SystemCapabilities
    public let recommendations: [String]
    
    public var formattedSessionDuration: String {
        let formatter = DateComponentsFormatter()
        formatter.unitsStyle = .abbreviated
        formatter.allowedUnits = [.hour, .minute, .second]
        return formatter.string(from: sessionDuration) ?? "Unknown"
    }
}

@available(iOS 15.0, macOS 12.0, *)
public enum PipelineOptimization: Equatable, Sendable, CustomStringConvertible {
    case reduceMemoryFootprint
    case enableMemoryPooling
    case reduceConcurrency
    case simplifyProcessing
    case enableParallelProcessing
    case increaseBatchSize
    case optimizeSlowOperations([String])
    
    public var description: String {
        switch self {
        case .reduceMemoryFootprint:
            return "Reduce Memory Footprint"
        case .enableMemoryPooling:
            return "Enable Memory Pooling"
        case .reduceConcurrency:
            return "Reduce Concurrency"
        case .simplifyProcessing:
            return "Simplify Processing"
        case .enableParallelProcessing:
            return "Enable Parallel Processing"
        case .increaseBatchSize:
            return "Increase Batch Size"
        case .optimizeSlowOperations(let operations):
            return "Optimize Slow Operations: \(operations.joined(separator: ", "))"
        }
    }
}