//
//  PerformanceMonitor.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 22-23: Performance Optimization - Core Performance Monitoring System
//

import Foundation
import CoreImage
import AVFoundation
import SwiftUI
import Combine

// MARK: - Performance Benchmarks
@MainActor
public struct PerformanceBenchmarks {
    public static let appStartupTime: TimeInterval = 2.0      // App startup target
    public static let cameraStartupTime: TimeInterval = 1.0   // Camera startup target
    public static let memoryUsage: Int = 150_000_000          // 150MB max memory
    public static let cpuUsage: Double = 0.3                  // 30% CPU max
    public static let batteryDrain: Double = 0.15             // 15%/hour battery
    public static let frameProcessingTime: TimeInterval = 0.033 // 33ms for 30fps
    public static let aiAnalysisTime: TimeInterval = 0.05     // 50ms max AI analysis
}

// MARK: - Performance Monitor Actor
@available(iOS 15.0, macOS 12.0, *)
public actor PerformanceMonitor: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = PerformanceMonitor()
    
    // MARK: - Performance Metrics
    @MainActor @Published public var currentMetrics = PerformanceMetrics()
    @MainActor @Published public var isMonitoring = false
    @MainActor @Published public var performanceStatus: PerformanceStatus = .optimal
    
    // MARK: - Private Properties
    private var metricsHistory: [PerformanceSnapshot] = []
    private let historyLimit = 100
    private var monitoringTimer: Timer?
    private let monitoringQueue = DispatchQueue(label: "com.neuroviews.performance", qos: .utility)
    
    // Measurement tracking
    private var appStartTime: CFTimeInterval?
    private var cameraStartTime: CFTimeInterval?
    private var frameProcessingTimes: [CFTimeInterval] = []
    private var aiAnalysisTimes: [CFTimeInterval] = []
    
    // Memory tracking
    private let memoryQueue = DispatchQueue(label: "com.neuroviews.memory", qos: .utility)
    
    private init() {
        setupPerformanceTracking()
    }
    
    // MARK: - Public Interface
    
    /// Start performance monitoring
    @MainActor
    public func startMonitoring() async {
        guard !isMonitoring else { return }
        
        await setupMonitoring()
        isMonitoring = true
        
        // Start periodic monitoring
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.capturePerformanceSnapshot()
            }
        }
        
        print("✅ Performance monitoring started")
    }
    
    /// Stop performance monitoring
    @MainActor
    public func stopMonitoring() async {
        guard isMonitoring else { return }
        
        await stopMonitoringInternal()
        isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        print("⏹️ Performance monitoring stopped")
    }
    
    /// Track app startup time
    public func trackAppStartup() {
        appStartTime = CACurrentMediaTime()
    }
    
    /// Mark app startup completion
    @MainActor
    public func markAppStartupComplete() async {
        guard let startTime = await self.appStartTime else { return }
        
        let startupTime = CACurrentMediaTime() - startTime
        await updateStartupTime(startupTime)
        
        let status = startupTime <= PerformanceBenchmarks.appStartupTime ? "✅" : "⚠️"
        print("\(status) App startup time: \(String(format: "%.2f", startupTime))s (target: \(PerformanceBenchmarks.appStartupTime)s)")
    }
    
    /// Track camera startup time
    public func trackCameraStartup() {
        cameraStartTime = CACurrentMediaTime()
    }
    
    /// Mark camera startup completion
    @MainActor
    public func markCameraStartupComplete() async {
        guard let startTime = await self.cameraStartTime else { return }
        
        let startupTime = CACurrentMediaTime() - startTime
        await updateCameraStartupTime(startupTime)
        
        let status = startupTime <= PerformanceBenchmarks.cameraStartupTime ? "✅" : "⚠️"
        print("\(status) Camera startup time: \(String(format: "%.2f", startupTime))s (target: \(PerformanceBenchmarks.cameraStartupTime)s)")
    }
    
    /// Track frame processing time
    public func trackFrameProcessing<T>(_ operation: () async throws -> T) async rethrows -> T {
        let startTime = CACurrentMediaTime()
        let result = try await operation()
        let processingTime = CACurrentMediaTime() - startTime
        
        await addFrameProcessingTime(processingTime)
        return result
    }
    
    /// Track AI analysis time
    public func trackAIAnalysis<T>(_ operation: () async throws -> T) async rethrows -> T {
        let startTime = CACurrentMediaTime()
        let result = try await operation()
        let analysisTime = CACurrentMediaTime() - startTime
        
        await addAIAnalysisTime(analysisTime)
        return result
    }
    
    /// Get current performance report
    @MainActor
    public func getPerformanceReport() async -> PerformanceReport {
        let metrics = await getCurrentMetrics()
        let recentSnapshots = await getRecentSnapshots(count: 10)
        
        return PerformanceReport(
            currentMetrics: metrics,
            recentSnapshots: recentSnapshots,
            recommendations: await generateRecommendations(metrics: metrics)
        )
    }
    
    /// Check if performance is within acceptable limits
    @MainActor
    public func isPerformanceHealthy() async -> Bool {
        let metrics = await getCurrentMetrics()
        
        return metrics.memoryUsageMB <= Double(PerformanceBenchmarks.memoryUsage) / 1_000_000 &&
               metrics.cpuUsage <= PerformanceBenchmarks.cpuUsage &&
               metrics.averageFrameTime <= PerformanceBenchmarks.frameProcessingTime &&
               metrics.averageAIAnalysisTime <= PerformanceBenchmarks.aiAnalysisTime
    }
    
    // MARK: - Private Implementation
    
    private func setupPerformanceTracking() {
        // Initialize performance tracking
        metricsHistory = []
        frameProcessingTimes = []
        aiAnalysisTimes = []
    }
    
    private func setupMonitoring() async {
        // Setup monitoring infrastructure
        await capturePerformanceSnapshot()
    }
    
    private func stopMonitoringInternal() async {
        // Cleanup monitoring resources
    }
    
    private func capturePerformanceSnapshot() async {
        let snapshot = PerformanceSnapshot(
            timestamp: Date(),
            memoryUsageMB: await getCurrentMemoryUsage(),
            cpuUsage: await getCurrentCPUUsage(),
            frameRate: await getCurrentFrameRate(),
            batteryLevel: await getCurrentBatteryLevel(),
            thermalState: await getCurrentThermalState()
        )
        
        await addSnapshot(snapshot)
        await updateCurrentMetrics(from: snapshot)
        await updatePerformanceStatus()
    }
    
    private func getCurrentMemoryUsage() async -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return Double(info.resident_size) / 1_000_000 // Convert to MB
        }
        return 0
    }
    
    private func getCurrentCPUUsage() async -> Double {
        var info = processor_info_array_t.allocate(capacity: 1)
        var numCores: natural_t = 0
        var numCoresU: mach_msg_type_number_t = 0
        
        defer {
            info.deallocate()
        }
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCores, &info, &numCoresU)
        
        if result == KERN_SUCCESS {
            // Simplified CPU calculation - real implementation would need more sophisticated tracking
            return 0.1 // Placeholder - actual CPU measurement requires more complex implementation
        }
        return 0
    }
    
    private func getCurrentFrameRate() async -> Double {
        let recentFrameTimes = Array(frameProcessingTimes.suffix(30))
        guard !recentFrameTimes.isEmpty else { return 0 }
        
        let averageFrameTime = recentFrameTimes.reduce(0, +) / Double(recentFrameTimes.count)
        return averageFrameTime > 0 ? 1.0 / averageFrameTime : 0
    }
    
    private func getCurrentBatteryLevel() async -> Double {
        #if os(iOS)
        return Double(UIDevice.current.batteryLevel)
        #else
        return 1.0 // macOS doesn't have simple battery level access
        #endif
    }
    
    private func getCurrentThermalState() async -> ProcessInfo.ThermalState {
        return ProcessInfo.processInfo.thermalState
    }
    
    private func addSnapshot(_ snapshot: PerformanceSnapshot) async {
        metricsHistory.append(snapshot)
        
        if metricsHistory.count > historyLimit {
            metricsHistory.removeFirst()
        }
    }
    
    private func updateCurrentMetrics(from snapshot: PerformanceSnapshot) async {
        let recentFrameTimes = Array(frameProcessingTimes.suffix(30))
        let recentAITimes = Array(aiAnalysisTimes.suffix(30))
        
        let metrics = PerformanceMetrics(
            memoryUsageMB: snapshot.memoryUsageMB,
            cpuUsage: snapshot.cpuUsage,
            frameRate: snapshot.frameRate,
            averageFrameTime: recentFrameTimes.isEmpty ? 0 : recentFrameTimes.reduce(0, +) / Double(recentFrameTimes.count),
            averageAIAnalysisTime: recentAITimes.isEmpty ? 0 : recentAITimes.reduce(0, +) / Double(recentAITimes.count),
            batteryLevel: snapshot.batteryLevel,
            thermalState: snapshot.thermalState
        )
        
        await MainActor.run {
            self.currentMetrics = metrics
        }
    }
    
    private func updatePerformanceStatus() async {
        let isHealthy = await isPerformanceHealthy()
        let metrics = await getCurrentMetrics()
        
        let status: PerformanceStatus
        if !isHealthy {
            if metrics.memoryUsageMB > Double(PerformanceBenchmarks.memoryUsage) / 1_000_000 * 1.2 {
                status = .critical
            } else {
                status = .warning
            }
        } else if metrics.thermalState == .critical {
            status = .warning
        } else {
            status = .optimal
        }
        
        await MainActor.run {
            self.performanceStatus = status
        }
    }
    
    private func updateStartupTime(_ time: TimeInterval) async {
        await MainActor.run {
            self.currentMetrics.appStartupTime = time
        }
    }
    
    private func updateCameraStartupTime(_ time: TimeInterval) async {
        await MainActor.run {
            self.currentMetrics.cameraStartupTime = time
        }
    }
    
    private func addFrameProcessingTime(_ time: CFTimeInterval) async {
        frameProcessingTimes.append(time)
        if frameProcessingTimes.count > 60 { // Keep last 60 frames (2 seconds at 30fps)
            frameProcessingTimes.removeFirst()
        }
    }
    
    private func addAIAnalysisTime(_ time: CFTimeInterval) async {
        aiAnalysisTimes.append(time)
        if aiAnalysisTimes.count > 30 { // Keep last 30 analyses
            aiAnalysisTimes.removeFirst()
        }
    }
    
    private func getCurrentMetrics() async -> PerformanceMetrics {
        await MainActor.run {
            return self.currentMetrics
        }
    }
    
    private func getRecentSnapshots(count: Int) async -> [PerformanceSnapshot] {
        return Array(metricsHistory.suffix(count))
    }
    
    private func generateRecommendations(metrics: PerformanceMetrics) async -> [PerformanceRecommendation] {
        var recommendations: [PerformanceRecommendation] = []
        
        // Memory recommendations
        if metrics.memoryUsageMB > Double(PerformanceBenchmarks.memoryUsage) / 1_000_000 {
            recommendations.append(PerformanceRecommendation(
                type: .memory,
                priority: .high,
                message: "Memory usage is above target (\(String(format: "%.1f", metrics.memoryUsageMB))MB). Consider reducing AI analysis frequency or optimizing image processing.",
                action: "Implement memory optimization strategies"
            ))
        }
        
        // CPU recommendations
        if metrics.cpuUsage > PerformanceBenchmarks.cpuUsage {
            recommendations.append(PerformanceRecommendation(
                type: .cpu,
                priority: .medium,
                message: "CPU usage is above target (\(String(format: "%.1f", metrics.cpuUsage * 100))%). Consider optimizing frame processing algorithms.",
                action: "Profile and optimize high-CPU operations"
            ))
        }
        
        // Frame rate recommendations
        if metrics.averageFrameTime > PerformanceBenchmarks.frameProcessingTime {
            recommendations.append(PerformanceRecommendation(
                type: .performance,
                priority: .high,
                message: "Frame processing time is above target (\(String(format: "%.1f", metrics.averageFrameTime * 1000))ms). This may cause dropped frames.",
                action: "Optimize camera pipeline and AI processing"
            ))
        }
        
        // Thermal recommendations
        if metrics.thermalState == .critical {
            recommendations.append(PerformanceRecommendation(
                type: .thermal,
                priority: .critical,
                message: "Device is overheating. Reduce processing intensity immediately.",
                action: "Implement thermal throttling"
            ))
        }
        
        return recommendations
    }
}

// MARK: - Performance Data Structures

public struct PerformanceMetrics {
    public var memoryUsageMB: Double = 0
    public var cpuUsage: Double = 0
    public var frameRate: Double = 0
    public var averageFrameTime: TimeInterval = 0
    public var averageAIAnalysisTime: TimeInterval = 0
    public var batteryLevel: Double = 1.0
    public var thermalState: ProcessInfo.ThermalState = .nominal
    public var appStartupTime: TimeInterval = 0
    public var cameraStartupTime: TimeInterval = 0
    
    public init() {}
    
    public init(memoryUsageMB: Double, cpuUsage: Double, frameRate: Double, averageFrameTime: TimeInterval, averageAIAnalysisTime: TimeInterval, batteryLevel: Double, thermalState: ProcessInfo.ThermalState) {
        self.memoryUsageMB = memoryUsageMB
        self.cpuUsage = cpuUsage
        self.frameRate = frameRate
        self.averageFrameTime = averageFrameTime
        self.averageAIAnalysisTime = averageAIAnalysisTime
        self.batteryLevel = batteryLevel
        self.thermalState = thermalState
    }
}

public struct PerformanceSnapshot {
    public let timestamp: Date
    public let memoryUsageMB: Double
    public let cpuUsage: Double
    public let frameRate: Double
    public let batteryLevel: Double
    public let thermalState: ProcessInfo.ThermalState
    
    public init(timestamp: Date, memoryUsageMB: Double, cpuUsage: Double, frameRate: Double, batteryLevel: Double, thermalState: ProcessInfo.ThermalState) {
        self.timestamp = timestamp
        self.memoryUsageMB = memoryUsageMB
        self.cpuUsage = cpuUsage
        self.frameRate = frameRate
        self.batteryLevel = batteryLevel
        self.thermalState = thermalState
    }
}

public struct PerformanceReport {
    public let currentMetrics: PerformanceMetrics
    public let recentSnapshots: [PerformanceSnapshot]
    public let recommendations: [PerformanceRecommendation]
    public let timestamp: Date = Date()
    
    public init(currentMetrics: PerformanceMetrics, recentSnapshots: [PerformanceSnapshot], recommendations: [PerformanceRecommendation]) {
        self.currentMetrics = currentMetrics
        self.recentSnapshots = recentSnapshots
        self.recommendations = recommendations
    }
}

public struct PerformanceRecommendation {
    public let type: RecommendationType
    public let priority: Priority
    public let message: String
    public let action: String
    
    public enum RecommendationType {
        case memory, cpu, performance, thermal, battery
    }
    
    public enum Priority {
        case low, medium, high, critical
        
        public var color: Color {
            switch self {
            case .low: return .green
            case .medium: return .yellow
            case .high: return .orange
            case .critical: return .red
            }
        }
    }
    
    public init(type: RecommendationType, priority: Priority, message: String, action: String) {
        self.type = type
        self.priority = priority
        self.message = message
        self.action = action
    }
}

public enum PerformanceStatus {
    case optimal, warning, critical
    
    public var color: Color {
        switch self {
        case .optimal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }
    
    public var description: String {
        switch self {
        case .optimal: return "Optimal"
        case .warning: return "Warning"
        case .critical: return "Critical"
        }
    }
}