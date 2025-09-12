//
//  BatteryOptimizer.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 22-23: Performance Optimization - Battery Optimization & Intelligent Throttling
//

import Foundation
import Combine
import AVFoundation
import CoreImage
import os.log
#if os(iOS)
import UIKit
#endif

// MARK: - Battery Optimizer Actor
@available(iOS 15.0, macOS 12.0, *)
public actor BatteryOptimizer: ObservableObject {
    
    // MARK: - Singleton
    public static let shared = BatteryOptimizer()
    
    // MARK: - Published Properties
    @MainActor @Published public private(set) var batteryLevel: Double = 1.0
    @MainActor @Published public private(set) var batteryState: BatteryState = .unknown
    @MainActor @Published public private(set) var powerMode: PowerMode = .balanced
    @MainActor @Published public private(set) var thermalState: ThermalState = .nominal
    @MainActor @Published public private(set) var isOptimizing = false
    
    // MARK: - Private Properties
    private let logger = Logger(subsystem: "com.neuroviews.performance", category: "battery")
    
    // Battery monitoring
    private var batteryMonitorTimer: Timer?
    private var batteryHistory: [BatteryReading] = []
    private let historyLimit = 60 // Last 60 readings
    
    // Thermal monitoring
    private var thermalMonitorTimer: Timer?
    private var thermalHistory: [ThermalReading] = []
    
    // Performance throttling
    private var currentThrottleLevel: ThrottleLevel = .none
    private var adaptiveQualitySettings: AdaptiveQualitySettings = .default
    
    // Power usage tracking
    private var powerConsumptionRate: Double = 0.0 // %/hour
    private var baselineConsumption: Double = 0.0
    private var aiAnalysisConsumption: Double = 0.0
    
    private init() {
        setupBatteryMonitoring()
        setupThermalMonitoring()
    }
    
    // MARK: - Public Methods
    
    /// Start battery optimization
    @MainActor
    public func startOptimization() async {
        guard !isOptimizing else { return }
        
        isOptimizing = true
        logger.info("🔋 Starting battery optimization")
        
        await updateBatteryStatus()
        await updateThermalStatus()
        await calculatePowerMode()
        
        // Start monitoring timers
        batteryMonitorTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.monitorBattery()
            }
        }
        
        thermalMonitorTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { [weak self] in
                await self?.monitorThermalState()
            }
        }
        
        // Setup power notifications
        await setupPowerNotifications()
        
        logger.info("✅ Battery optimization started")
    }
    
    /// Stop battery optimization
    @MainActor
    public func stopOptimization() async {
        guard isOptimizing else { return }
        
        isOptimizing = false
        batteryMonitorTimer?.invalidate()
        thermalMonitorTimer?.invalidate()
        batteryMonitorTimer = nil
        thermalMonitorTimer = nil
        
        logger.info("⏹️ Battery optimization stopped")
    }
    
    /// Get intelligent throttling recommendations
    public func getThrottlingRecommendations() async -> ThrottlingRecommendations {
        let currentLevel = await getCurrentBatteryLevel()
        let thermalState = await getCurrentThermalState()
        let powerMode = await getPowerMode()
        
        var recommendations = ThrottlingRecommendations(
            suggestedFrameRate: 30.0,
            suggestedAnalysisInterval: 0.033,
            suggestedQuality: .high,
            reason: "Condiciones normales"
        )
        
        // Battery-based recommendations
        if currentLevel < 0.2 { // Below 20%
            recommendations.suggestedFrameRate = 15.0
            recommendations.suggestedAnalysisInterval = 0.1
            recommendations.suggestedQuality = .low
            recommendations.reason = "Batería baja - modo conservación"
        } else if currentLevel < 0.5 { // Below 50%
            recommendations.suggestedFrameRate = 24.0
            recommendations.suggestedAnalysisInterval = 0.05
            recommendations.suggestedQuality = .medium
            recommendations.reason = "Batería media - optimización moderada"
        }
        
        // Thermal-based adjustments
        if thermalState == .serious || thermalState == .critical {
            recommendations.suggestedFrameRate = min(recommendations.suggestedFrameRate, 15.0)
            recommendations.suggestedAnalysisInterval = max(recommendations.suggestedAnalysisInterval, 0.1)
            recommendations.suggestedQuality = .minimal
            recommendations.reason = "Estado térmico crítico - reducir carga"
        }
        
        // Power mode adjustments
        switch powerMode {
        case .lowPower:
            recommendations.suggestedFrameRate = 10.0
            recommendations.suggestedAnalysisInterval = 0.2
            recommendations.suggestedQuality = .minimal
            recommendations.reason = "Modo ahorro de energía"
        case .balanced:
            // Keep current recommendations
            break
        case .performance:
            if currentLevel > 0.8 { // Only if battery is high
                recommendations.suggestedFrameRate = 60.0
                recommendations.suggestedAnalysisInterval = 0.016
                recommendations.suggestedQuality = .high
                recommendations.reason = "Modo rendimiento - batería alta"
            }
        }
        
        return recommendations
    }
    
    /// Apply intelligent throttling
    public func applyIntelligentThrottling() async -> AppliedThrottleSettings {
        let recommendations = await getThrottlingRecommendations()
        
        let appliedSettings = AppliedThrottleSettings(
            frameRate: recommendations.suggestedFrameRate,
            analysisInterval: recommendations.suggestedAnalysisInterval,
            qualityLevel: recommendations.suggestedQuality,
            throttleLevel: await calculateThrottleLevel(from: recommendations),
            energySavings: await estimateEnergySavings(from: recommendations)
        )
        
        await updateThrottleLevel(appliedSettings.throttleLevel)
        
        logger.info("⚡ Applied throttling: \(appliedSettings.throttleLevel) - estimated savings: \(String(format: "%.1f", appliedSettings.energySavings))%")
        
        return appliedSettings
    }
    
    /// Estimate remaining battery time with current usage
    public func estimateRemainingBatteryTime() async -> BatteryTimeEstimate {
        let currentLevel = await getCurrentBatteryLevel()
        let consumptionRate = await getCurrentConsumptionRate()
        
        if consumptionRate <= 0 {
            return BatteryTimeEstimate(
                hours: Double.infinity,
                minutes: Double.infinity,
                confidence: 0.0,
                based_on: "Sin datos suficientes"
            )
        }
        
        let remainingPercent = currentLevel * 100
        let hoursRemaining = remainingPercent / consumptionRate
        let minutesRemaining = hoursRemaining * 60
        
        let confidence = calculateEstimateConfidence()
        
        return BatteryTimeEstimate(
            hours: hoursRemaining,
            minutes: minutesRemaining,
            confidence: confidence,
            based_on: "Uso actual de \(String(format: "%.1f", consumptionRate))%/h"
        )
    }
    
    /// Get battery optimization report
    public func getBatteryOptimizationReport() async -> BatteryOptimizationReport {
        let currentReading = await getCurrentBatteryReading()
        let consumptionAnalysis = await analyzePowerConsumption()
        let thermalAnalysis = await analyzeThermalPerformance()
        let recommendations = await getOptimizationRecommendations()
        
        return BatteryOptimizationReport(
            timestamp: Date(),
            batteryLevel: currentReading.level,
            batteryState: currentReading.state,
            thermalState: thermalState,
            powerMode: powerMode,
            consumptionRate: consumptionAnalysis.currentRate,
            estimatedTimeRemaining: await estimateRemainingBatteryTime(),
            thermalAnalysis: thermalAnalysis,
            recommendations: recommendations
        )
    }
    
    // MARK: - Private Implementation
    
    private func setupBatteryMonitoring() {
        #if os(iOS)
        UIDevice.current.isBatteryMonitoringEnabled = true
        #endif
    }
    
    private func setupThermalMonitoring() {
        // Thermal monitoring is automatic via ProcessInfo
    }
    
    private func setupPowerNotifications() async {
        #if os(iOS)
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.handleBatteryStateChange()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: UIDevice.batteryLevelDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.handleBatteryLevelChange()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSProcessInfoThermalStateDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { [weak self] in
                await self?.handleThermalStateChange()
            }
        }
        #endif
    }
    
    private func monitorBattery() async {
        await updateBatteryStatus()
        await recordBatteryReading()
        await calculateConsumptionRate()
        await adjustPowerModeIfNeeded()
    }
    
    private func monitorThermalState() async {
        await updateThermalStatus()
        await recordThermalReading()
        await adjustForThermalState()
    }
    
    private func updateBatteryStatus() async {
        #if os(iOS)
        let level = Double(UIDevice.current.batteryLevel)
        let state = mapBatteryState(UIDevice.current.batteryState)
        
        await MainActor.run {
            self.batteryLevel = level >= 0 ? level : 1.0 // -1.0 means unknown
            self.batteryState = state
        }
        #else
        // macOS - simplified battery monitoring
        await MainActor.run {
            self.batteryLevel = 1.0 // Assume plugged in
            self.batteryState = .charging
        }
        #endif
    }
    
    private func updateThermalStatus() async {
        let thermalState = mapThermalState(ProcessInfo.processInfo.thermalState)
        
        await MainActor.run {
            self.thermalState = thermalState
        }
    }
    
    private func calculatePowerMode() async {
        let level = await getCurrentBatteryLevel()
        let state = await getCurrentBatteryState()
        
        let mode: PowerMode
        if state == .charging || level > 0.8 {
            mode = .balanced
        } else if level < 0.3 {
            mode = .lowPower
        } else {
            mode = .balanced
        }
        
        await MainActor.run {
            self.powerMode = mode
        }
    }
    
    private func recordBatteryReading() async {
        let reading = BatteryReading(
            timestamp: Date(),
            level: await getCurrentBatteryLevel(),
            state: await getCurrentBatteryState()
        )
        
        batteryHistory.append(reading)
        
        if batteryHistory.count > historyLimit {
            batteryHistory.removeFirst()
        }
    }
    
    private func recordThermalReading() async {
        let reading = ThermalReading(
            timestamp: Date(),
            state: thermalState
        )
        
        thermalHistory.append(reading)
        
        if thermalHistory.count > historyLimit {
            thermalHistory.removeFirst()
        }
    }
    
    private func calculateConsumptionRate() async {
        guard batteryHistory.count >= 2 else { return }
        
        let recent = Array(batteryHistory.suffix(10))
        guard recent.count >= 2 else { return }
        
        let timeInterval = recent.last!.timestamp.timeIntervalSince(recent.first!.timestamp)
        let levelChange = recent.first!.level - recent.last!.level
        
        if timeInterval > 0 && levelChange > 0 {
            // Convert to %/hour
            powerConsumptionRate = (levelChange * 100) / (timeInterval / 3600)
        }
    }
    
    private func adjustPowerModeIfNeeded() async {
        let level = await getCurrentBatteryLevel()
        let currentMode = await getPowerMode()
        
        let newMode: PowerMode
        if level < 0.1 { // Below 10% - emergency
            newMode = .lowPower
        } else if level < 0.3 && currentMode != .lowPower {
            newMode = .lowPower
        } else if level > 0.7 && currentMode == .lowPower {
            newMode = .balanced
        } else {
            newMode = currentMode
        }
        
        if newMode != currentMode {
            await MainActor.run {
                self.powerMode = newMode
            }
            logger.info("🔋 Power mode changed to: \(newMode)")
        }
    }
    
    private func adjustForThermalState() async {
        let thermal = thermalState
        
        switch thermal {
        case .critical:
            await updateThrottleLevel(.aggressive)
            logger.warning("🌡️ Critical thermal state - aggressive throttling")
            
        case .serious:
            await updateThrottleLevel(.moderate)
            logger.warning("🌡️ Serious thermal state - moderate throttling")
            
        case .fair:
            await updateThrottleLevel(.light)
            
        case .nominal:
            if currentThrottleLevel != .none {
                await updateThrottleLevel(.none)
                logger.info("🌡️ Thermal state normal - removing throttling")
            }
        }
    }
    
    private func calculateThrottleLevel(from recommendations: ThrottlingRecommendations) async -> ThrottleLevel {
        if recommendations.suggestedQuality == .minimal {
            return .aggressive
        } else if recommendations.suggestedFrameRate < 20 {
            return .moderate
        } else if recommendations.suggestedFrameRate < 30 {
            return .light
        } else {
            return .none
        }
    }
    
    private func estimateEnergySavings(from recommendations: ThrottlingRecommendations) async -> Double {
        // Simplified energy savings estimation
        let baselineFrameRate = 30.0
        let baselineQuality = QualityLevel.high
        
        var savings = 0.0
        
        // Frame rate savings
        if recommendations.suggestedFrameRate < baselineFrameRate {
            savings += (baselineFrameRate - recommendations.suggestedFrameRate) / baselineFrameRate * 30.0
        }
        
        // Quality savings
        if recommendations.suggestedQuality.rawValue < baselineQuality.rawValue {
            savings += Double(baselineQuality.rawValue - recommendations.suggestedQuality.rawValue) * 10.0
        }
        
        return min(savings, 50.0) // Cap at 50% savings
    }
    
    private func updateThrottleLevel(_ level: ThrottleLevel) async {
        currentThrottleLevel = level
    }
    
    private func calculateEstimateConfidence() -> Double {
        // Confidence based on amount of historical data
        if batteryHistory.count < 5 {
            return 0.3
        } else if batteryHistory.count < 20 {
            return 0.7
        } else {
            return 0.9
        }
    }
    
    private func analyzePowerConsumption() async -> PowerConsumptionAnalysis {
        let currentRate = powerConsumptionRate
        let baseline = baselineConsumption
        let aiConsumption = aiAnalysisConsumption
        
        return PowerConsumptionAnalysis(
            currentRate: currentRate,
            baselineRate: baseline,
            aiAnalysisRate: aiConsumption,
            efficiency: baseline > 0 ? currentRate / baseline : 1.0
        )
    }
    
    private func analyzeThermalPerformance() async -> ThermalAnalysis {
        let recentThermal = Array(thermalHistory.suffix(10))
        
        let averageState = recentThermal.isEmpty ? .nominal : 
            recentThermal.map { $0.state.rawValue }.reduce(0, +) / recentThermal.count
        
        return ThermalAnalysis(
            currentState: thermalState,
            averageRecentState: ThermalState(rawValue: averageState) ?? .nominal,
            timeInCritical: calculateTimeInState(.critical),
            recommendations: generateThermalRecommendations()
        )
    }
    
    private func calculateTimeInState(_ targetState: ThermalState) -> TimeInterval {
        let fiveMinutesAgo = Date().addingTimeInterval(-300)
        let recentReadings = thermalHistory.filter { $0.timestamp >= fiveMinutesAgo }
        let criticalReadings = recentReadings.filter { $0.state == targetState }
        
        return TimeInterval(criticalReadings.count) * 10.0 // 10 seconds per reading
    }
    
    private func generateThermalRecommendations() -> [String] {
        var recommendations: [String] = []
        
        switch thermalState {
        case .critical:
            recommendations.append("Reducir inmediatamente la calidad de análisis AI")
            recommendations.append("Limitar frame rate a 10 FPS")
            recommendations.append("Pausar análisis no esenciales")
            
        case .serious:
            recommendations.append("Reducir calidad de análisis a modo bajo")
            recommendations.append("Limitar frame rate a 15 FPS")
            
        case .fair:
            recommendations.append("Considerar reducir calidad de análisis")
            
        case .nominal:
            break
        }
        
        return recommendations
    }
    
    private func getOptimizationRecommendations() async -> [String] {
        var recommendations: [String] = []
        
        let level = await getCurrentBatteryLevel()
        let consumptionRate = powerConsumptionRate
        
        if level < 0.2 {
            recommendations.append("Activar modo ahorro de energía inmediatamente")
            recommendations.append("Reducir análisis AI al mínimo esencial")
        }
        
        if consumptionRate > 20.0 { // More than 20%/hour
            recommendations.append("Consumo alto detectado - optimizar configuraciones")
            recommendations.append("Considerar reducir frecuencia de análisis")
        }
        
        if thermalState == .serious || thermalState == .critical {
            recommendations.append("Estado térmico elevado - reducir carga del procesador")
        }
        
        return recommendations
    }
    
    // MARK: - Helper Methods
    
    private func getCurrentBatteryLevel() async -> Double {
        await MainActor.run { self.batteryLevel }
    }
    
    private func getCurrentBatteryState() async -> BatteryState {
        await MainActor.run { self.batteryState }
    }
    
    private func getCurrentThermalState() async -> ThermalState {
        await MainActor.run { self.thermalState }
    }
    
    private func getPowerMode() async -> PowerMode {
        await MainActor.run { self.powerMode }
    }
    
    private func getCurrentConsumptionRate() async -> Double {
        return powerConsumptionRate
    }
    
    private func getCurrentBatteryReading() async -> BatteryReading {
        return BatteryReading(
            timestamp: Date(),
            level: await getCurrentBatteryLevel(),
            state: await getCurrentBatteryState()
        )
    }
    
    private func handleBatteryStateChange() async {
        await updateBatteryStatus()
        await calculatePowerMode()
    }
    
    private func handleBatteryLevelChange() async {
        await updateBatteryStatus()
        await adjustPowerModeIfNeeded()
    }
    
    private func handleThermalStateChange() async {
        await updateThermalStatus()
        await adjustForThermalState()
    }
    
    #if os(iOS)
    private func mapBatteryState(_ uiState: UIDevice.BatteryState) -> BatteryState {
        switch uiState {
        case .unknown: return .unknown
        case .unplugged: return .unplugged
        case .charging: return .charging
        case .full: return .full
        @unknown default: return .unknown
        }
    }
    #endif
    
    private func mapThermalState(_ processState: ProcessInfo.ThermalState) -> ThermalState {
        switch processState {
        case .nominal: return .nominal
        case .fair: return .fair
        case .serious: return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
    }
}

// MARK: - Supporting Data Structures

public enum BatteryState {
    case unknown, unplugged, charging, full
}

public enum PowerMode {
    case lowPower, balanced, performance
    
    public var description: String {
        switch self {
        case .lowPower: return "Ahorro de Energía"
        case .balanced: return "Balanceado"
        case .performance: return "Rendimiento"
        }
    }
}

public enum ThermalState: Int {
    case nominal = 0, fair = 1, serious = 2, critical = 3
    
    public var description: String {
        switch self {
        case .nominal: return "Normal"
        case .fair: return "Tibio"
        case .serious: return "Caliente"
        case .critical: return "Crítico"
        }
    }
}

public enum ThrottleLevel {
    case none, light, moderate, aggressive
    
    public var description: String {
        switch self {
        case .none: return "Sin Limitación"
        case .light: return "Limitación Ligera"
        case .moderate: return "Limitación Moderada"
        case .aggressive: return "Limitación Agresiva"
        }
    }
}

public enum QualityLevel: Int, CaseIterable {
    case minimal = 0, low = 1, medium = 2, high = 3
    
    public var description: String {
        switch self {
        case .minimal: return "Mínima"
        case .low: return "Baja"
        case .medium: return "Media"
        case .high: return "Alta"
        }
    }
}

public struct BatteryReading {
    public let timestamp: Date
    public let level: Double
    public let state: BatteryState
}

public struct ThermalReading {
    public let timestamp: Date
    public let state: ThermalState
}

public struct ThrottlingRecommendations {
    public var suggestedFrameRate: Double
    public var suggestedAnalysisInterval: TimeInterval
    public var suggestedQuality: QualityLevel
    public var reason: String
}

public struct AppliedThrottleSettings {
    public let frameRate: Double
    public let analysisInterval: TimeInterval
    public let qualityLevel: QualityLevel
    public let throttleLevel: ThrottleLevel
    public let energySavings: Double
}

public struct BatteryTimeEstimate {
    public let hours: Double
    public let minutes: Double
    public let confidence: Double
    public let based_on: String
}

public struct AdaptiveQualitySettings {
    public let frameRate: Double
    public let analysisInterval: TimeInterval
    public let qualityLevel: QualityLevel
    
    public static let `default` = AdaptiveQualitySettings(
        frameRate: 30.0,
        analysisInterval: 0.033,
        qualityLevel: .high
    )
}

public struct PowerConsumptionAnalysis {
    public let currentRate: Double
    public let baselineRate: Double
    public let aiAnalysisRate: Double
    public let efficiency: Double
}

public struct ThermalAnalysis {
    public let currentState: ThermalState
    public let averageRecentState: ThermalState
    public let timeInCritical: TimeInterval
    public let recommendations: [String]
}

public struct BatteryOptimizationReport {
    public let timestamp: Date
    public let batteryLevel: Double
    public let batteryState: BatteryState
    public let thermalState: ThermalState
    public let powerMode: PowerMode
    public let consumptionRate: Double
    public let estimatedTimeRemaining: BatteryTimeEstimate
    public let thermalAnalysis: ThermalAnalysis
    public let recommendations: [String]
}