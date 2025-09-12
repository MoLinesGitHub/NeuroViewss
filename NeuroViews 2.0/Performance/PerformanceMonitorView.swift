//
//  PerformanceMonitorView.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 22-23: Performance Optimization - Performance Monitor UI
//

import SwiftUI
import Combine

@available(iOS 15.0, macOS 12.0, *)
struct PerformanceMonitorView: View {
    @StateObject private var performanceMonitor = PerformanceMonitor.shared
    @StateObject private var memoryOptimizer = MemoryOptimizer.shared
    @StateObject private var batteryOptimizer = BatteryOptimizer.shared
    private let nvaiKit = NVAIKit.shared
    
    @State private var showingDetailedReport = false
    @State private var showingMemoryDetails = false
    @State private var showingBatteryDetails = false
    @State private var isRunningTests = false
    @State private var testResults: TestRunnerResults?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            headerView
            
            if performanceMonitor.isMonitoring {
                metricsOverview
                
                HStack(spacing: 16) {
                    memorySection
                    batterySection
                }
                
                controlsSection
                
                if let results = testResults {
                    testResultsSection(results)
                }
            } else {
                inactiveView
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.9))
        .cornerRadius(16)
        .foregroundColor(.white)
        .sheet(isPresented: $showingDetailedReport) {
            DetailedPerformanceReportView()
        }
        .sheet(isPresented: $showingMemoryDetails) {
            MemoryDetailsView()
        }
        .sheet(isPresented: $showingBatteryDetails) {
            BatteryDetailsView()
        }
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        HStack {
            Image(systemName: "speedometer")
                .foregroundColor(.blue)
                .font(.title2)
            
            Text("Monitor de Performance")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            HStack(spacing: 8) {
                statusIndicator
                
                Button(action: { showingDetailedReport = true }) {
                    Image(systemName: "doc.text")
                        .foregroundColor(.gray)
                }
            }
        }
    }
    
    private var statusIndicator: some View {
        Circle()
            .fill(performanceMonitor.performanceStatus.color)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(performanceMonitor.performanceStatus.color.opacity(0.3), lineWidth: 3)
                    .scaleEffect(performanceMonitor.isMonitoring ? 1.5 : 1.0)
                    .opacity(performanceMonitor.isMonitoring ? 0.0 : 1.0)
                    .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: false), value: performanceMonitor.isMonitoring)
            )
    }
    
    private var metricsOverview: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                MetricCard(
                    title: "Memoria",
                    value: "\(String(format: "%.1f", performanceMonitor.currentMetrics.memoryUsageMB))MB",
                    color: memoryColor,
                    icon: "memorychip"
                )
                
                MetricCard(
                    title: "CPU",
                    value: "\(String(format: "%.1f", performanceMonitor.currentMetrics.cpuUsage * 100))%",
                    color: cpuColor,
                    icon: "cpu"
                )
            }
            
            HStack(spacing: 16) {
                MetricCard(
                    title: "Frame Rate",
                    value: "\(String(format: "%.1f", performanceMonitor.currentMetrics.frameRate))fps",
                    color: frameRateColor,
                    icon: "camera"
                )
                
                MetricCard(
                    title: "AI Análisis",
                    value: "\(String(format: "%.0f", performanceMonitor.currentMetrics.averageAIAnalysisTime * 1000))ms",
                    color: aiAnalysisColor,
                    icon: "brain.head.profile"
                )
            }
        }
    }
    
    private var memorySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Memoria")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("Detalles") {
                    showingMemoryDetails = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Presión:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(memoryOptimizer.memoryPressure.description)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(memoryOptimizer.memoryPressure.color)
                }
                
                if memoryOptimizer.isOptimizing {
                    HStack {
                        Text("Optimizando")
                            .font(.caption)
                            .foregroundColor(.green)
                        
                        Spacer()
                        
                        ProgressView()
                            .scaleEffect(0.6)
                    }
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private var batterySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Batería")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button("Detalles") {
                    showingBatteryDetails = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Nivel:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text("\(String(format: "%.0f", batteryOptimizer.batteryLevel * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(batteryColor)
                }
                
                HStack {
                    Text("Modo:")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Spacer()
                    
                    Text(batteryOptimizer.powerMode.description)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    private var controlsSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                if performanceMonitor.isMonitoring {
                    Button("Detener Monitoreo") {
                        Task {
                            await performanceMonitor.stopMonitoring()
                            await memoryOptimizer.stopOptimization()
                            await batteryOptimizer.stopOptimization()
                            await UnifiedPerformanceSystem.shared.stopOptimization()
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                } else {
                    Button("Iniciar Monitoreo") {
                        Task {
                            await performanceMonitor.startMonitoring()
                            await memoryOptimizer.startOptimization()
                            await batteryOptimizer.startOptimization()
                            // await nvaiKit.startPerformanceOptimization()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                
                Button("Limpiar Memoria") {
                    Task {
                        // await nvaiKit.performMemoryCleanup()
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
            
            HStack(spacing: 12) {
                Button(isRunningTests ? "Ejecutando Tests..." : "Ejecutar Tests") {
                    runPerformanceTests()
                }
                .disabled(isRunningTests)
                .buttonStyle(SecondaryButtonStyle())
                
                Button("Optimizar Batería") {
                    Task {
                        _ = await batteryOptimizer.applyIntelligentThrottling()
                    }
                }
                .buttonStyle(SecondaryButtonStyle())
            }
        }
    }
    
    private var inactiveView: some View {
        VStack(spacing: 16) {
            Image(systemName: "speedometer")
                .font(.largeTitle)
                .foregroundColor(.gray)
            
            Text("Monitor de Performance Inactivo")
                .font(.headline)
                .foregroundColor(.gray)
            
            Text("Inicia el monitoreo para ver métricas en tiempo real")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            Button("Iniciar Monitoreo") {
                Task {
                    await performanceMonitor.startMonitoring()
                    await memoryOptimizer.startOptimization()
                    await batteryOptimizer.startOptimization()
                    // await nvaiKit.startPerformanceOptimization()
                }
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding(32)
    }
    
    private func testResultsSection(_ results: TestRunnerResults) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Resultados de Tests")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Image(systemName: results.overallStatus == .passed ? "checkmark.circle" : "xmark.circle")
                    .foregroundColor(results.overallStatus == .passed ? .green : .red)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                ForEach(results.testResults, id: \.name) { result in
                    HStack {
                        Text(result.name)
                            .font(.caption)
                            .foregroundColor(.gray)
                        
                        Spacer()
                        
                        HStack(spacing: 4) {
                            Text("\(String(format: "%.1f", result.duration))s")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Image(systemName: result.passed ? "checkmark" : "xmark")
                                .font(.caption)
                                .foregroundColor(result.passed ? .green : .red)
                        }
                    }
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
    }
    
    // MARK: - Helper Methods
    
    private var memoryColor: Color {
        let usage = performanceMonitor.currentMetrics.memoryUsageMB
        let limit = Double(PerformanceBenchmarks.memoryUsage) / 1_000_000
        
        if usage > limit * 0.9 {
            return .red
        } else if usage > limit * 0.7 {
            return .orange
        } else {
            return .green
        }
    }
    
    private var cpuColor: Color {
        let usage = performanceMonitor.currentMetrics.cpuUsage
        
        if usage > 0.8 {
            return .red
        } else if usage > 0.5 {
            return .orange
        } else {
            return .green
        }
    }
    
    private var frameRateColor: Color {
        let rate = performanceMonitor.currentMetrics.frameRate
        
        if rate < 15 {
            return .red
        } else if rate < 24 {
            return .orange
        } else {
            return .green
        }
    }
    
    private var aiAnalysisColor: Color {
        let time = performanceMonitor.currentMetrics.averageAIAnalysisTime
        let benchmark = PerformanceBenchmarks.aiAnalysisTime
        
        if time > benchmark * 1.5 {
            return .red
        } else if time > benchmark {
            return .orange
        } else {
            return .green
        }
    }
    
    private var batteryColor: Color {
        let level = batteryOptimizer.batteryLevel
        
        if level < 0.2 {
            return .red
        } else if level < 0.5 {
            return .orange
        } else {
            return .green
        }
    }
    
    private func runPerformanceTests() {
        isRunningTests = true
        
        Task {
            let runner = PerformanceTestRunner.shared
            let results = await runner.runPerformanceTests()
            
            await MainActor.run {
                self.testResults = results
                self.isRunningTests = false
            }
        }
    }
}

// MARK: - Supporting Views

struct MetricCard: View {
    let title: String
    let value: String
    let color: Color
    let icon: String
    
    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.caption)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
            }
            
            HStack {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(color)
                
                Spacer()
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.gray.opacity(0.2))
            .foregroundColor(.white)
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

// MARK: - Placeholder Detail Views

@available(iOS 15.0, macOS 12.0, *)
struct DetailedPerformanceReportView: View {
    var body: some View {
        Text("Reporte Detallado de Performance")
            .navigationTitle("Reporte Detallado")
    }
}

@available(iOS 15.0, macOS 12.0, *)
struct MemoryDetailsView: View {
    var body: some View {
        Text("Detalles de Memoria")
            .navigationTitle("Memoria")
    }
}

@available(iOS 15.0, macOS 12.0, *)
struct BatteryDetailsView: View {
    var body: some View {
        Text("Detalles de Batería")
            .navigationTitle("Batería")
    }
}

// MARK: - Preview

@available(iOS 15.0, macOS 12.0, *)
struct PerformanceMonitorView_Previews: PreviewProvider {
    static var previews: some View {
        PerformanceMonitorView()
            .preferredColorScheme(.dark)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}
