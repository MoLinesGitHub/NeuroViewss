//
//  SmartExposureView.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 20-21: Smart Features Implementation - Smart Exposure UI
//

import SwiftUI
import AVFoundation

@available(iOS 15.0, macOS 12.0, *)
struct SmartExposureView: View {
    @StateObject private var exposureAssistant = SmartExposureAssistant()
    @Binding var captureDevice: AVCaptureDevice?
    @State private var showingManualControls = false
    @State private var showingSettings = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerView
            
            if exposureAssistant.isAnalyzing {
                analyzingView
            } else if let suggestion = exposureAssistant.currentSuggestion {
                suggestionView(suggestion)
            } else {
                placeholderView
            }
            
            if showingManualControls {
                manualControlsView
            }
            
            controlsView
        }
        .padding(16)
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
        .foregroundColor(.white)
    }
    
    // MARK: - View Components
    
    private var headerView: some View {
        HStack {
            Image(systemName: "camera.aperture")
                .foregroundColor(.yellow)
            
            Text("Smart Exposure")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            HStack(spacing: 8) {
                // Mode Picker
                Picker("Modo", selection: $exposureAssistant.suggestionMode) {
                    ForEach(SuggestionMode.allCases, id: \.self) { mode in
                        Text(mode.displayName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)
                
                // Settings Button
                Button(action: { showingSettings.toggle() }) {
                    Image(systemName: "gear")
                        .foregroundColor(.gray)
                }
                
                // Toggle Button
                Button(action: { exposureAssistant.isEnabled.toggle() }) {
                    Image(systemName: exposureAssistant.isEnabled ? "eye" : "eye.slash")
                        .foregroundColor(exposureAssistant.isEnabled ? .green : .red)
                }
            }
        }
    }
    
    private var analyzingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
                .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
            
            Text("Analizando exposición...")
                .font(.body)
                .foregroundColor(.gray)
        }
        .frame(height: 40)
    }
    
    private func suggestionView(_ suggestion: ExposureSuggestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                priorityIndicator(suggestion.priority)
                
                Text(suggestionTypeText(suggestion.type))
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                confidenceIndicator(suggestion.confidence)
            }
            
            Text(suggestion.reason)
                .font(.caption)
                .foregroundColor(.gray)
                .lineLimit(2)
            
            HStack(spacing: 12) {
                if case .manual = suggestion.type {
                    applyButton(suggestion)
                    
                    Button("Ajustes Manuales") {
                        showingManualControls.toggle()
                    }
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                } else {
                    applyButton(suggestion)
                }
            }
        }
        .padding(12)
        .background(impactColor(suggestion.impact).opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(impactColor(suggestion.impact), lineWidth: 1)
        )
    }
    
    private var placeholderView: some View {
        Text("Esperando análisis de exposición...")
            .font(.body)
            .foregroundColor(.gray)
            .frame(height: 40)
    }
    
    private var manualControlsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Controles Manuales")
                .font(.subheadline)
                .fontWeight(.semibold)
            
            if let recommendation = exposureAssistant.getManualExposureRecommendation() {
                VStack(alignment: .leading, spacing: 6) {
                    manualControlRow(
                        title: "ISO",
                        value: "\(Int(recommendation.iso))",
                        icon: "camera.aperture"
                    )
                    
                    manualControlRow(
                        title: "Velocidad",
                        value: formatShutterSpeed(recommendation.shutterSpeed),
                        icon: "timer"
                    )
                    
                    manualControlRow(
                        title: "Apertura",
                        value: "f/\(String(format: "%.1f", recommendation.aperture))",
                        icon: "circle"
                    )
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
    
    private var controlsView: some View {
        HStack {
            // Exposure History
            if !exposureAssistant.exposureHistory.isEmpty {
                Button("Historial") {
                    // Show exposure history
                }
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Reset Button
            Button("Limpiar") {
                // Reset suggestions
            }
            .font(.caption)
            .foregroundColor(.red)
        }
    }
    
    // MARK: - Helper Views
    
    private func priorityIndicator(_ priority: SuggestionPriority) -> some View {
        Circle()
            .fill(priorityColor(priority))
            .frame(width: 8, height: 8)
    }
    
    private func confidenceIndicator(_ confidence: Float) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<5, id: \.self) { index in
                Rectangle()
                    .fill(confidence > Float(index) * 0.2 ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 4, height: 8)
            }
        }
    }
    
    private func applyButton(_ suggestion: ExposureSuggestion) -> some View {
        Button("Aplicar") {
            applySuggestion(suggestion)
        }
        .font(.caption)
        .fontWeight(.semibold)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.green)
        .foregroundColor(.white)
        .cornerRadius(8)
        .disabled(captureDevice == nil)
    }
    
    private func manualControlRow(title: String, value: String, icon: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.gray)
                .frame(width: 16)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            Spacer()
            
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Helper Methods
    
    private func suggestionTypeText(_ type: ExposureSuggestionType) -> String {
        switch type {
        case .automatic:
            return "Modo Automático"
        case .manual:
            return "Configuración Manual"
        case .exposureCompensation(let ev):
            return "Compensación: \(ev > 0 ? "+" : "")\(String(format: "%.1f", ev)) EV"
        }
    }
    
    private func priorityColor(_ priority: SuggestionPriority) -> Color {
        switch priority {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    private func impactColor(_ impact: ExposureSuggestion.ImpactLevel) -> Color {
        switch impact {
        case .none: return .gray
        case .minor: return .blue
        case .moderate: return .yellow
        case .significant: return .orange
        case .dramatic: return .red
        }
    }
    
    private func formatShutterSpeed(_ time: CMTime) -> String {
        let seconds = CMTimeGetSeconds(time)
        if seconds >= 1.0 {
            return "\(String(format: "%.1f", seconds))s"
        } else {
            return "1/\(Int(1.0/seconds))"
        }
    }
    
    private func applySuggestion(_ suggestion: ExposureSuggestion) {
        guard let device = captureDevice else { return }
        
        do {
            try exposureAssistant.applySuggestion(suggestion, to: device)
            
            // Show success feedback
            #if os(iOS)
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            #endif
            
        } catch {
            print("Error applying exposure suggestion: \(error)")
            
            // Show error feedback
            #if os(iOS)
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.error)
            #endif
        }
    }
}

// MARK: - Public Interface

@available(iOS 15.0, macOS 12.0, *)
extension SmartExposureView {
    /// Update exposure analysis with new frame
    func updateWithFrame(_ pixelBuffer: CVPixelBuffer) {
        exposureAssistant.analyzeFrame(pixelBuffer)
    }
    
    /// Enable or disable smart exposure analysis
    func setEnabled(_ enabled: Bool) {
        exposureAssistant.isEnabled = enabled
    }
    
    /// Change suggestion mode
    func setSuggestionMode(_ mode: SuggestionMode) {
        exposureAssistant.suggestionMode = mode
    }
}

// MARK: - Preview

@available(iOS 15.0, macOS 12.0, *)
struct SmartExposureView_Previews: PreviewProvider {
    static var previews: some View {
        SmartExposureView(captureDevice: .constant(nil))
            .preferredColorScheme(.dark)
            .previewLayout(.sizeThatFits)
            .padding()
    }
}