//
//  PerformanceTypes.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 22-23: Performance Optimization - Centralized Type Definitions for Swift 6
//

import Foundation
import SwiftUI
import Combine
import os.log

// MARK: - Core Performance Types

/// System performance status
public enum SystemPerformanceStatus: String, CaseIterable, Sendable {
    case idle = "idle"
    case optimizing = "optimizing"
    case optimal = "optimal"
    case degraded = "degraded"
    case critical = "critical"
}

/// System load levels
public enum SystemLoadLevel: String, CaseIterable, Sendable {
    case minimal = "minimal"
    case low = "low"
    case normal = "normal"
    case high = "high"
    case critical = "critical"
    
    public var description: String {
        switch self {
        case .minimal: return "Mínima"
        case .low: return "Baja"
        case .normal: return "Normal"
        case .high: return "Alta"
        case .critical: return "Crítica"
        }
    }
}

/// Task priority levels for scheduling
public enum TaskPriorityLevel: Int, CaseIterable, Sendable, Comparable {
    case background = 0
    case low = 1
    case normal = 2
    case high = 3
    case critical = 4
    
    public static func < (lhs: TaskPriorityLevel, rhs: TaskPriorityLevel) -> Bool {
        return lhs.rawValue < rhs.rawValue
    }
    
    public var description: String {
        switch self {
        case .background: return "Background"
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }
}

/// System thermal states
public enum SystemThermalState: Int, CaseIterable, Sendable {
    case nominal = 0
    case fair = 1
    case serious = 2
    case critical = 3
    
    public var description: String {
        switch self {
        case .nominal: return "Normal"
        case .fair: return "Aceptable"
        case .serious: return "Serio"
        case .critical: return "Crítico"
        }
    }
}

/// Workload prediction levels
public enum WorkloadLevel: Int, CaseIterable, Sendable {
    case idle = 0
    case minimal = 1
    case low = 2
    case medium = 3
    case high = 4
    case extreme = 5
    
    public var description: String {
        switch self {
        case .idle: return "Inactivo"
        case .minimal: return "Mínima"
        case .low: return "Baja"
        case .medium: return "Media"
        case .high: return "Alta"
        case .extreme: return "Extrema"
        }
    }
}

/// Cache levels for intelligent caching
public enum CacheLevel: Int, CaseIterable, Sendable {
    case l1 = 1
    case l2 = 2
    case l3 = 3
    case l4 = 4
    case l5 = 5
    case l6 = 6
    
    public var description: String {
        return "L\(rawValue)"
    }
}

/// Performance analysis types for AI processing
public enum PerformanceAIAnalysisType: String, CaseIterable, Sendable {
    case exposure = "exposure"
    case focus = "focus"
    case objectDetection = "objectDetection"
    case sceneClassification = "sceneClassification"
    case colorAnalysis = "colorAnalysis"
    case faceDetection = "faceDetection"
    case motionAnalysis = "motionAnalysis"
    
    public var description: String {
        switch self {
        case .exposure: return "Análisis de Exposición"
        case .focus: return "Análisis de Enfoque"
        case .objectDetection: return "Detección de Objetos"
        case .sceneClassification: return "Clasificación de Escena"
        case .colorAnalysis: return "Análisis de Color"
        case .faceDetection: return "Detección Facial"
        case .motionAnalysis: return "Análisis de Movimiento"
        }
    }
}

// MARK: - Performance Metrics

/// Comprehensive performance metrics
public struct SystemPerformanceMetrics: Sendable {
    public let timestamp: Date
    public let cpuUsage: Double
    public let memoryUsage: Double
    public let thermalState: SystemThermalState
    public let batteryLevel: Double
    public let systemLoad: SystemLoadLevel
    public let activeThreads: Int
    public let queueDepth: Int
    public let cacheHitRate: Double
    public let throughput: Double
    public let averageLatency: TimeInterval
    public let frameRate: Double
    
    public init(
        timestamp: Date = Date(),
        cpuUsage: Double = 0.0,
        memoryUsage: Double = 0.0,
        thermalState: SystemThermalState = .nominal,
        batteryLevel: Double = 1.0,
        systemLoad: SystemLoadLevel = .normal,
        activeThreads: Int = 1,
        queueDepth: Int = 0,
        cacheHitRate: Double = 0.0,
        throughput: Double = 0.0,
        averageLatency: TimeInterval = 0.0,
        frameRate: Double = 30.0
    ) {
        self.timestamp = timestamp
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.thermalState = thermalState
        self.batteryLevel = batteryLevel
        self.systemLoad = systemLoad
        self.activeThreads = activeThreads
        self.queueDepth = queueDepth
        self.cacheHitRate = cacheHitRate
        self.throughput = throughput
        self.averageLatency = averageLatency
        self.frameRate = frameRate
    }
}

/// Concurrency-specific metrics
public struct ConcurrencyMetrics: Sendable {
    public let activeThreads: Int
    public let queueDepth: Int
    public let threadEfficiency: Double
    public let lockContention: Double
    public let executionRate: Double
    
    public init(
        activeThreads: Int = 0,
        queueDepth: Int = 0,
        threadEfficiency: Double = 1.0,
        lockContention: Double = 0.0,
        executionRate: Double = 0.0
    ) {
        self.activeThreads = activeThreads
        self.queueDepth = queueDepth
        self.threadEfficiency = threadEfficiency
        self.lockContention = lockContention
        self.executionRate = executionRate
    }
}

/// Cache performance metrics
public struct CacheMetrics: Sendable {
    public let level: CacheLevel
    public let hitRate: Double
    public let size: Int
    public let memoryUsage: Double
    public let evictionRate: Double
    
    public init(
        level: CacheLevel,
        hitRate: Double = 0.0,
        size: Int = 0,
        memoryUsage: Double = 0.0,
        evictionRate: Double = 0.0
    ) {
        self.level = level
        self.hitRate = hitRate
        self.size = size
        self.memoryUsage = memoryUsage
        self.evictionRate = evictionRate
    }
}

/// Workload analysis results
public struct WorkloadAnalysisResult: Sendable {
    public let timestamp: Date
    public let currentLevel: WorkloadLevel
    public let predictedLevel: WorkloadLevel
    public let confidence: Double
    public let trendDirection: WorkloadTrend
    public let factors: [WorkloadFactor]
    
    public init(
        timestamp: Date = Date(),
        currentLevel: WorkloadLevel = .medium,
        predictedLevel: WorkloadLevel = .medium,
        confidence: Double = 0.5,
        trendDirection: WorkloadTrend = .stable,
        factors: [WorkloadFactor] = []
    ) {
        self.timestamp = timestamp
        self.currentLevel = currentLevel
        self.predictedLevel = predictedLevel
        self.confidence = confidence
        self.trendDirection = trendDirection
        self.factors = factors
    }
}

/// Workload trend analysis
public enum WorkloadTrend: String, CaseIterable, Sendable {
    case decreasing = "decreasing"
    case stable = "stable"
    case increasing = "increasing"
    case volatile = "volatile"
    
    public var description: String {
        switch self {
        case .decreasing: return "Decreciente"
        case .stable: return "Estable"
        case .increasing: return "Creciente"
        case .volatile: return "Volátil"
        }
    }
}

/// Factors affecting workload
public struct WorkloadFactor: Sendable {
    public let name: String
    public let impact: Double
    public let description: String
    public let category: FactorCategory
    
    public init(name: String, impact: Double, description: String, category: FactorCategory) {
        self.name = name
        self.impact = impact
        self.description = description
        self.category = category
    }
}

/// Factor categories
public enum FactorCategory: String, CaseIterable, Sendable {
    case system = "system"
    case user = "user"
    case application = "application"
    case external = "external"
}

// MARK: - AI Analysis Results

/// Performance AI analysis result structure
public struct PerformanceAIAnalysisResult: Sendable {
    public let type: PerformanceAIAnalysisType
    public let confidence: Double
    public let processingTime: TimeInterval
    public let data: [String: Double]
    public let recommendations: [String]
    
    public init(
        type: PerformanceAIAnalysisType,
        confidence: Double = 0.0,
        processingTime: TimeInterval = 0.0,
        data: [String: Double] = [:],
        recommendations: [String] = []
    ) {
        self.type = type
        self.confidence = confidence
        self.processingTime = processingTime
        self.data = data
        self.recommendations = recommendations
    }
}

/// Batch performance AI analysis results
public struct BatchPerformanceAIAnalysisResult: Sendable {
    public let results: [PerformanceAIAnalysisResult]
    public let totalProcessingTime: TimeInterval
    public let averageConfidence: Double
    public let timestamp: Date
    
    public init(
        results: [PerformanceAIAnalysisResult],
        totalProcessingTime: TimeInterval = 0.0,
        timestamp: Date = Date()
    ) {
        self.results = results
        self.totalProcessingTime = totalProcessingTime
        self.timestamp = timestamp
        self.averageConfidence = results.isEmpty ? 0.0 : 
            results.map(\.confidence).reduce(0, +) / Double(results.count)
    }
}

// MARK: - Task Management

/// Schedulable task protocol
public protocol SchedulableTask: Sendable {
    var id: UUID { get }
    var priority: TaskPriorityLevel { get }
    var estimatedDuration: TimeInterval { get }
    var dependencies: [UUID] { get }
    var deadline: Date? { get }
    
    func execute() async throws -> Any
}

/// Task execution result
public struct TaskExecutionResult: Sendable {
    public let taskId: UUID
    public let success: Bool
    public let result: String? // Simplified to avoid Any
    public let executionTime: TimeInterval
    public let error: String?
    
    public init(
        taskId: UUID,
        success: Bool,
        result: String? = nil,
        executionTime: TimeInterval,
        error: String? = nil
    ) {
        self.taskId = taskId
        self.success = success
        self.result = result
        self.executionTime = executionTime
        self.error = error
    }
}

/// Batch task execution results
public struct BatchTaskExecutionResult: Sendable {
    public let results: [TaskExecutionResult]
    public let totalTime: TimeInterval
    public let successRate: Double
    public let timestamp: Date
    
    public init(results: [TaskExecutionResult], timestamp: Date = Date()) {
        self.results = results
        self.totalTime = results.map(\.executionTime).reduce(0, +)
        self.successRate = results.isEmpty ? 0.0 : 
            Double(results.filter(\.success).count) / Double(results.count)
        self.timestamp = timestamp
    }
}

// MARK: - Error Types

/// Performance optimization errors
public enum PerformanceOptimizationError: Error, Sendable {
    case systemOverload
    case resourceUnavailable
    case taskExecutionFailed(String)
    case concurrencyLimitExceeded
    case cacheCorruption
    case thermalThrottling
    case batteryOptimizationRequired
    case aiProcessingTimeout
    
    public var localizedDescription: String {
        switch self {
        case .systemOverload:
            return "Sistema sobrecargado - reduciendo carga de trabajo"
        case .resourceUnavailable:
            return "Recurso no disponible temporalmente"
        case .taskExecutionFailed(let details):
            return "Error en ejecución de tarea: \(details)"
        case .concurrencyLimitExceeded:
            return "Límite de concurrencia excedido"
        case .cacheCorruption:
            return "Corrupción detectada en cache"
        case .thermalThrottling:
            return "Limitación térmica activada"
        case .batteryOptimizationRequired:
            return "Optimización de batería requerida"
        case .aiProcessingTimeout:
            return "Timeout en procesamiento de IA"
        }
    }
}

// MARK: - Configuration

/// Performance optimization configuration
public struct PerformanceConfiguration: Sendable {
    public let maxConcurrentTasks: Int
    public let cacheMaxSize: Int
    public let aiProcessingTimeout: TimeInterval
    public let thermalThrottlingEnabled: Bool
    public let batteryOptimizationEnabled: Bool
    public let adaptiveSchedulingEnabled: Bool
    
    public init(
        maxConcurrentTasks: Int = 4,
        cacheMaxSize: Int = 100,
        aiProcessingTimeout: TimeInterval = 30.0,
        thermalThrottlingEnabled: Bool = true,
        batteryOptimizationEnabled: Bool = true,
        adaptiveSchedulingEnabled: Bool = true
    ) {
        self.maxConcurrentTasks = maxConcurrentTasks
        self.cacheMaxSize = cacheMaxSize
        self.aiProcessingTimeout = aiProcessingTimeout
        self.thermalThrottlingEnabled = thermalThrottlingEnabled
        self.batteryOptimizationEnabled = batteryOptimizationEnabled
        self.adaptiveSchedulingEnabled = adaptiveSchedulingEnabled
    }
    
    public static let `default` = PerformanceConfiguration()
}

// MARK: - Utility Extensions

extension TimeInterval {
    public var milliseconds: Double {
        return self * 1000.0
    }
    
    public var formattedString: String {
        if self < 1.0 {
            return String(format: "%.1fms", milliseconds)
        } else {
            return String(format: "%.2fs", self)
        }
    }
}

extension Double {
    public var percentageString: String {
        return String(format: "%.1f%%", self * 100)
    }
    
    public var formattedBytes: String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = self
        var unitIndex = 0
        
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        
        return String(format: "%.1f %@", value, units[unitIndex])
    }
}

// MARK: - Constants

public struct PerformanceConstants {
    public static let defaultFrameRate: Double = 30.0
    public static let maxFrameRate: Double = 120.0
    public static let defaultCacheSize: Int = 100
    public static let maxCacheSize: Int = 1000
    public static let defaultThreadCount: Int = ProcessInfo.processInfo.activeProcessorCount
    public static let maxThreadCount: Int = ProcessInfo.processInfo.activeProcessorCount * 2
    public static let thermalThrottleThreshold: Double = 0.8
    public static let batteryOptimizationThreshold: Double = 0.2
    public static let memoryPressureThreshold: Double = 0.8
    
    private init() {} // Prevent instantiation
}