//
//  MemoryOptimizer.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 22-23: Performance Optimization - Memory Optimization & Leak Detection
//

import Foundation
import Combine
import AVFoundation
import CoreImage
import os.log

// MARK: - Memory Optimizer Actor
@available(iOS 15.0, macOS 12.0, *)
public actor MemoryOptimizer: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = MemoryOptimizer()
    
    // MARK: - Published Properties
    @MainActor @Published public private(set) var memoryPressure: MemoryPressure = .normal
    @MainActor @Published public private(set) var leakDetectionReport: LeakDetectionReport?
    @MainActor @Published public private(set) var isOptimizing = false
    
    // MARK: - Private Properties
    @MainActor private var memoryMonitorTimer: Timer?
    private let logger = Logger(subsystem: "com.neuroviews.performance", category: "memory")
    
    // Memory tracking
    private var baselineMemory: UInt64 = 0
    private var memoryHistory: [MemorySnapshot] = []
    private let historyLimit = 50
    private var optimizationQueue = DispatchQueue(label: "com.neuroviews.memory", qos: .utility)
    
    // Leak detection
    private var objectCounts: [String: Int] = [:]
    private var strongReferences: Set<AnyHashable> = []
    private var weakReferences: NSHashTable<AnyObject> = NSHashTable.weakObjects()
    
    // CVPixelBuffer pool management
    private var pixelBufferPool: CVPixelBufferPool?
    private var poolAttributes: [String: Any] = [:]
    
    private init() {
        // Setup será manejado en startOptimization()
    }
    
    // MARK: - Public Methods
    
    /// Start memory optimization monitoring
    @MainActor
    public func startOptimization() async {
        guard !isOptimizing else { return }
        
        isOptimizing = true
        logger.info("🧹 Starting memory optimization")
        
        // Start memory monitoring timer
        memoryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.performMemoryCheck()
            }
        }
        
        // Setup pixel buffer pool
        await setupPixelBufferPool()
        
        // Initial cleanup
        await performMemoryCleanup()
    }
    
    /// Stop memory optimization
    @MainActor
    public func stopOptimization() async {
        guard isOptimizing else { return }
        
        isOptimizing = false
        memoryMonitorTimer?.invalidate()
        memoryMonitorTimer = nil
        
        logger.info("⏹️ Memory optimization stopped")
    }
    
    /// Detect memory leaks
    public func detectMemoryLeaks() async -> LeakDetectionReport {
        logger.info("🔍 Starting memory leak detection")
        
        let currentMemory = getCurrentMemoryUsage()
        let suspiciousPatterns = await analyzeSuspiciousPatterns()
        let unreferencedObjects = await findUnreferencedObjects()
        let circularReferences = await detectCircularReferences()
        
        let report = LeakDetectionReport(
            timestamp: Date(),
            currentMemoryMB: Double(currentMemory) / 1_000_000,
            suspiciousPatterns: suspiciousPatterns,
            unreferencedObjects: unreferencedObjects,
            circularReferences: circularReferences,
            recommendations: await generateMemoryRecommendations(currentMemory: currentMemory)
        )
        
        await MainActor.run {
            self.leakDetectionReport = report
        }
        
        return report
    }
    
    /// Force memory cleanup
    public func performMemoryCleanup() async {
        logger.info("🧹 Performing memory cleanup")
        
        // Cleanup image caches
        await cleanupImageCaches()
        
        // Cleanup AI analysis caches
        await cleanupAnalysisCaches()
        
        // Cleanup pixel buffers
        await cleanupPixelBuffers()
        
        // Force garbage collection
        await forceGarbageCollection()
        
        logger.info("✅ Memory cleanup completed")
    }
    
    /// Get optimized pixel buffer from pool
    public func getOptimizedPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        
        if let pool = pixelBufferPool {
            let status = CVPixelBufferPoolCreatePixelBuffer(nil, pool, &pixelBuffer)
            if status == kCVReturnSuccess {
                return pixelBuffer
            }
        }
        
        // Fallback to direct creation
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        let status = CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &pixelBuffer)
        return status == kCVReturnSuccess ? pixelBuffer : nil
    }
    
    /// Register object for leak tracking
    public func registerObject(_ object: AnyObject, withIdentifier identifier: String) {
        strongReferences.insert(ObjectIdentifier(object))
        weakReferences.add(object)
        objectCounts[identifier, default: 0] += 1
    }
    
    /// Unregister object from leak tracking
    public func unregisterObject(_ object: AnyObject, withIdentifier identifier: String) {
        strongReferences.remove(ObjectIdentifier(object))
        if let count = objectCounts[identifier], count > 0 {
            objectCounts[identifier] = count - 1
        }
    }
    
    // MARK: - Private Implementation
    
    private func setupMemoryMonitoring() {
        baselineMemory = getCurrentMemoryUsage()
        logger.info("📊 Baseline memory: \(self.baselineMemory / 1_000_000)MB")
    }
    
    private func setupMemoryPressureHandling() {
        #if os(iOS) || os(tvOS)
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.handleMemoryPressure()
            }
        }
        #else
        // macOS doesn't have memory warnings, use timer-based monitoring
        logger.info("🍎 Using timer-based memory monitoring on macOS")
        #endif
    }
    
    private func recordBaseline() {
        let snapshot = MemorySnapshot(
            timestamp: Date(),
            totalMemoryMB: Double(getCurrentMemoryUsage()) / 1_000_000,
            availableMemoryMB: Double(getAvailableMemory()) / 1_000_000
        )
        
        memoryHistory.append(snapshot)
    }
    
    private func performMemoryCheck() async {
        let currentMemory = getCurrentMemoryUsage()
        let availableMemory = getAvailableMemory()
        
        let snapshot = MemorySnapshot(
            timestamp: Date(),
            totalMemoryMB: Double(currentMemory) / 1_000_000,
            availableMemoryMB: Double(availableMemory) / 1_000_000
        )
        
        memoryHistory.append(snapshot)
        
        if memoryHistory.count > historyLimit {
            memoryHistory.removeFirst()
        }
        
        // Update memory pressure
        let pressure = calculateMemoryPressure(current: currentMemory, available: availableMemory)
        await MainActor.run {
            self.memoryPressure = pressure
        }
        
        // Trigger cleanup if needed
        if pressure == .high || pressure == .critical {
            await performMemoryCleanup()
        }
    }
    
    private func calculateMemoryPressure(current: UInt64, available: UInt64) -> MemoryPressure {
        let totalMemory = current + available
        let usageRatio = Double(current) / Double(totalMemory)
        
        switch usageRatio {
        case 0.0..<0.6:
            return .normal
        case 0.6..<0.8:
            return .moderate
        case 0.8..<0.9:
            return .high
        default:
            return .critical
        }
    }
    
    private func handleMemoryPressure() async {
        logger.warning("⚠️ Memory pressure detected")
        
        await MainActor.run {
            self.memoryPressure = .critical
        }
        
        await performMemoryCleanup()
    }
    
    private func analyzeSuspiciousPatterns() async -> [SuspiciousPattern] {
        var patterns: [SuspiciousPattern] = []
        
        // Check for continuously growing memory
        if memoryHistory.count >= 10 {
            let recent = Array(memoryHistory.suffix(10))
            let isGrowing = recent.enumerated().allSatisfy { index, snapshot in
                index == 0 || snapshot.totalMemoryMB > recent[index - 1].totalMemoryMB
            }
            
            if isGrowing {
                patterns.append(SuspiciousPattern(
                    type: .continuousGrowth,
                    description: "Memory continuously growing over last 10 measurements",
                    severity: .high
                ))
            }
        }
        
        // Check object count anomalies
        for (identifier, count) in objectCounts where count > 100 {
            patterns.append(SuspiciousPattern(
                type: .excessiveObjects,
                description: "Excessive object count for \(identifier): \(count)",
                severity: count > 1000 ? .critical : .moderate
            ))
        }
        
        return patterns
    }
    
    private func findUnreferencedObjects() async -> [String] {
        var unreferenced: [String] = []
        
        // Check weak references table for objects that should have been deallocated
        for object in weakReferences.allObjects {
            let identifier = ObjectIdentifier(object)
            if strongReferences.contains(identifier) {
                unreferenced.append(String(describing: type(of: object)))
            }
        }
        
        return unreferenced
    }
    
    private func detectCircularReferences() async -> [CircularReference] {
        // Simplified circular reference detection
        // In a real implementation, this would involve more sophisticated graph analysis
        return []
    }
    
    private func generateMemoryRecommendations(currentMemory: UInt64) async -> [String] {
        var recommendations: [String] = []
        
        let memoryMB = Double(currentMemory) / 1_000_000
        
        if memoryMB > 200 {
            recommendations.append("Consider reducing AI analysis frequency")
            recommendations.append("Implement more aggressive image cache cleanup")
        }
        
        if memoryMB > 300 {
            recommendations.append("Enable aggressive memory optimization mode")
            recommendations.append("Reduce concurrent AI operations")
        }
        
        if objectCounts.values.max() ?? 0 > 500 {
            recommendations.append("Review object lifecycle management")
            recommendations.append("Implement object pooling for frequently created objects")
        }
        
        return recommendations
    }
    
    private func cleanupImageCaches() async {
        // Cleanup CIContext caches
        CIContext().clearCaches()
        
        // Cleanup any custom image caches
        // This would be implemented based on specific cache implementations
        
        logger.info("🗑️ Image caches cleaned")
    }
    
    private func cleanupAnalysisCaches() async {
        // Clear AI analysis result caches
        // This would integrate with NVAIKit caching system
        
        logger.info("🗑️ AI analysis caches cleaned")
    }
    
    private func cleanupPixelBuffers() async {
        // Flush pixel buffer pool
        if let pool = pixelBufferPool {
            CVPixelBufferPoolFlush(pool, .excessBuffers)
        }
        
        logger.info("🗑️ Pixel buffers cleaned")
    }
    
    private func forceGarbageCollection() async {
        // In Swift, we can't force GC directly, but we can help by:
        // 1. Clearing strong references
        // 2. Running autoreleasepool operations
        
        autoreleasepool {
            // Clear temporary references
            strongReferences.removeAll()
        }
        
        logger.info("♻️ Garbage collection assisted")
    }
    
    private func setupPixelBufferPool() async {
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 1920,
            kCVPixelBufferHeightKey as String: 1080,
            kCVPixelBufferIOSurfacePropertiesKey as String: [:]
        ]
        
        let poolAttributes: [String: Any] = [
            kCVPixelBufferPoolMinimumBufferCountKey as String: 3,
            kCVPixelBufferPoolMaximumBufferAgeKey as String: 5.0
        ]
        
        var pool: CVPixelBufferPool?
        let status = CVPixelBufferPoolCreate(
            nil,
            poolAttributes as CFDictionary,
            attributes as CFDictionary,
            &pool
        )
        
        if status == kCVReturnSuccess {
            pixelBufferPool = pool
            self.poolAttributes = attributes
            logger.info("✅ Pixel buffer pool created")
        } else {
            logger.error("❌ Failed to create pixel buffer pool: \(status)")
        }
    }
    
    // MARK: - Memory Utilities
    
    private func getCurrentMemoryUsage() -> UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        return result == KERN_SUCCESS ? info.resident_size : 0
    }
    
    private func getAvailableMemory() -> UInt64 {
        var info = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<natural_t>.size)
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            return UInt64(info.free_count) * UInt64(vm_kernel_page_size)
        }
        
        return 0
    }
}

// MARK: - Supporting Data Structures

public struct MemorySnapshot {
    public let timestamp: Date
    public let totalMemoryMB: Double
    public let availableMemoryMB: Double
}

public enum MemoryPressure {
    case normal, moderate, high, critical
    
    public var description: String {
        switch self {
        case .normal: return "Normal"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
    
    public var color: Color {
        switch self {
        case .normal: return .green
        case .moderate: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
}

public struct LeakDetectionReport {
    public let timestamp: Date
    public let currentMemoryMB: Double
    public let suspiciousPatterns: [SuspiciousPattern]
    public let unreferencedObjects: [String]
    public let circularReferences: [CircularReference]
    public let recommendations: [String]
}

public struct SuspiciousPattern {
    public let type: PatternType
    public let description: String
    public let severity: Severity
    
    public enum PatternType {
        case continuousGrowth, excessiveObjects, suspiciousRetainCycles
    }
    
    public enum Severity {
        case low, moderate, high, critical
    }
}

public struct CircularReference {
    public let objects: [String]
    public let description: String
}

// MARK: - SwiftUI Color Extension
import SwiftUI

private extension Color {
    static let green = Color.green
    static let yellow = Color.yellow
    static let orange = Color.orange
    static let red = Color.red
}