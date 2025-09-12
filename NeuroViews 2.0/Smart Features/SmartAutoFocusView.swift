//
//  SmartAutoFocusView.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 20-21: Smart Features Implementation - Auto-Focus UI
//

import SwiftUI
import AVFoundation

@available(iOS 15.0, macOS 12.0, *)
struct SmartAutoFocusView: View {
    @StateObject private var autoFocus = SmartAutoFocus()
    @Binding var captureDevice: AVCaptureDevice?
    @State private var showingFocusModes = false
    
    var body: some View {
        ZStack {
            // Focus point indicators
            focusPointOverlay
            
            // Subject tracking indicators
            subjectTrackingOverlay
            
            // Focus controls
            VStack {
                Spacer()
                
                HStack {
                    Spacer()
                    
                    // Focus control panel
                    focusControlPanel
                }
                .padding(.trailing, 20)
                .padding(.bottom, 200)
            }
            
            // Focus suggestions
            if !autoFocus.focusSuggestions.isEmpty {
                VStack {
                    Spacer()
                    
                    focusSuggestionsView
                        .padding(.horizontal, 20)
                        .padding(.bottom, 140)
                }
            }
        }
        .sheet(isPresented: $showingFocusModes) {
            FocusModePickerView(
                selectedMode: $autoFocus.focusMode,
                onDismiss: { showingFocusModes = false }
            )
        }
    }
    
    // MARK: - View Components
    
    private var focusPointOverlay: some View {
        Canvas { context, size in
            // Draw current focus point
            if let focusPoint = autoFocus.currentFocusPoint {
                let point = CGPoint(
                    x: focusPoint.x * size.width,
                    y: focusPoint.y * size.height
                )
                
                // Focus indicator circle
                let focusRect = CGRect(
                    x: point.x - 25,
                    y: point.y - 25,
                    width: 50,
                    height: 50
                )
                
                context.stroke(
                    Path(ellipseIn: focusRect),
                    with: .color(focusIndicatorColor),
                    lineWidth: 2
                )
                
                // Center crosshair
                context.stroke(
                    Path { path in
                        path.move(to: CGPoint(x: point.x - 10, y: point.y))
                        path.addLine(to: CGPoint(x: point.x + 10, y: point.y))
                        path.move(to: CGPoint(x: point.x, y: point.y - 10))
                        path.addLine(to: CGPoint(x: point.x, y: point.y + 10))
                    },
                    with: .color(focusIndicatorColor),
                    lineWidth: 1
                )
            }
        }
    }
    
    private var subjectTrackingOverlay: some View {
        Canvas { context, size in
            if autoFocus.focusMode == .subjectTracking {
                for subject in autoFocus.trackingSubjects {
                    let rect = CGRect(
                        x: subject.boundingBox.minX * size.width,
                        y: subject.boundingBox.minY * size.height,
                        width: subject.boundingBox.width * size.width,
                        height: subject.boundingBox.height * size.height
                    )
                    
                    // Subject bounding box
                    context.stroke(
                        Path(roundedRect: rect, cornerRadius: 4),
                        with: .color(subjectColor(for: subject)),
                        lineWidth: subject.isPrimary ? 3 : 2
                    )
                    
                    // Subject type indicator
                    let indicator = subjectTypeIcon(subject.type)
                    let iconSize: CGFloat = 16
                    let iconRect = CGRect(
                        x: rect.minX,
                        y: rect.minY - iconSize - 4,
                        width: iconSize,
                        height: iconSize
                    )
                    
                    context.fill(
                        Path(roundedRect: iconRect, cornerRadius: 2),
                        with: .color(.black.opacity(0.7))
                    )
                }
            }
        }
    }
    
    private var focusControlPanel: some View {
        VStack(spacing: 12) {
            // Focus mode selector
            Button(action: { showingFocusModes.toggle() }) {
                VStack(spacing: 4) {
                    Image(systemName: focusModeIcon(autoFocus.focusMode))
                        .font(.title2)
                    
                    Text(autoFocus.focusMode.displayName)
                        .font(.caption)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(8)
                .background(Color.black.opacity(0.6))
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            
            // Focus quality indicator
            focusQualityIndicator
            
            // Subject tracking toggle
            if autoFocus.focusMode != .manual {
                Button(action: { autoFocus.toggleSubjectTracking() }) {
                    Image(systemName: autoFocus.focusMode == .subjectTracking ? "target" : "target.fill")
                        .font(.title2)
                        .foregroundColor(autoFocus.focusMode == .subjectTracking ? .green : .gray)
                        .padding(8)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(8)
                }
            }
            
            // Enable/disable toggle
            Button(action: { autoFocus.isEnabled.toggle() }) {
                Image(systemName: autoFocus.isEnabled ? "viewfinder" : "viewfinder.circle")
                    .font(.title2)
                    .foregroundColor(autoFocus.isEnabled ? .blue : .gray)
                    .padding(8)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
            }
            
            // Manual apply button
            if autoFocus.focusMode == .aiGuided && autoFocus.currentFocusPoint != nil {
                Button("Aplicar") {
                    applyAIFocus()
                }
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
        }
    }
    
    private var focusQualityIndicator: some View {
        VStack(spacing: 4) {
            // Quality bars
            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { index in
                    Rectangle()
                        .fill(focusQualityColor)
                        .frame(width: 4, height: qualityBarHeight(for: index))
                        .opacity(autoFocus.focusConfidence > Float(index) * 0.2 ? 1.0 : 0.3)
                }
            }
            
            Text("Focus")
                .font(.caption2)
                .foregroundColor(.white)
        }
        .padding(6)
        .background(Color.black.opacity(0.6))
        .cornerRadius(6)
    }
    
    private var focusSuggestionsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "viewfinder")
                    .foregroundColor(.blue)
                
                Text("Sugerencia de Enfoque")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: {
                    // Dismiss suggestions
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.gray)
                }
            }
            
            if let suggestion = autoFocus.focusSuggestions.first {
                Text(suggestion.message)
                    .font(.body)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
                
                if suggestion.targetPoint != nil {
                    Button("Aplicar Sugerencia") {
                        applySuggestion(suggestion)
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.8))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.blue.opacity(0.5), lineWidth: 1)
        )
    }
    
    // MARK: - Helper Properties
    
    private var focusIndicatorColor: Color {
        switch autoFocus.focusConfidence {
        case 0.8...1.0: return .green
        case 0.5..<0.8: return .yellow
        default: return .orange
        }
    }
    
    private var focusQualityColor: Color {
        switch autoFocus.getFocusQualityScore() {
        case 0.8...1.0: return .green
        case 0.6..<0.8: return .yellow
        case 0.4..<0.6: return .orange
        default: return .red
        }
    }
    
    // MARK: - Helper Methods
    
    private func focusModeIcon(_ mode: FocusMode) -> String {
        switch mode {
        case .aiGuided: return "viewfinder"
        case .subjectTracking: return "target"
        case .manual: return "hand.point.up"
        case .hyperfocal: return "mountain.2"
        }
    }
    
    private func subjectColor(for subject: DetectedSubject) -> Color {
        switch subject.type {
        case .face: return subject.isPrimary ? .green : .yellow
        case .humanBody: return .blue
        case .object: return .gray
        case .animal: return .orange
        }
    }
    
    private func subjectTypeIcon(_ type: DetectedSubject.SubjectType) -> String {
        switch type {
        case .face: return "person.crop.circle"
        case .humanBody: return "figure.stand"
        case .object: return "cube"
        case .animal: return "pawprint"
        }
    }
    
    private func qualityBarHeight(for index: Int) -> CGFloat {
        return CGFloat(8 + index * 2) // Increasing height
    }
    
    private func applyAIFocus() {
        guard let device = captureDevice else { return }
        
        do {
            try autoFocus.applyAIFocus(to: device)
            
            #if os(iOS)
            let impact = UIImpactFeedbackGenerator(style: .light)
            impact.impactOccurred()
            #endif
            
        } catch {
            print("Error applying AI focus: \(error)")
            
            #if os(iOS)
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.error)
            #endif
        }
    }
    
    private func applySuggestion(_ suggestion: FocusSuggestion) {
        // Apply specific suggestion
        applyAIFocus()
    }
    
    // MARK: - Public Interface
    
    /// Update with new camera frame
    func updateWithFrame(_ pixelBuffer: CVPixelBuffer) {
        autoFocus.analyzeForFocus(pixelBuffer)
    }
}

// MARK: - Focus Mode Picker

struct FocusModePickerView: View {
    @Binding var selectedMode: FocusMode
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(FocusMode.allCases, id: \.self) { mode in
                    Button(action: {
                        selectedMode = mode
                        onDismiss()
                    }) {
                        HStack {
                            Image(systemName: iconFor(mode))
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(mode.displayName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(descriptionFor(mode))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            if mode == selectedMode {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Modo de Enfoque")
            .navigationBarItems(trailing: Button("Cerrar", action: onDismiss))
        }
    }
    
    private func iconFor(_ mode: FocusMode) -> String {
        switch mode {
        case .aiGuided: return "viewfinder"
        case .subjectTracking: return "target"
        case .manual: return "hand.point.up"
        case .hyperfocal: return "mountain.2"
        }
    }
    
    private func descriptionFor(_ mode: FocusMode) -> String {
        switch mode {
        case .aiGuided:
            return "IA analiza la escena y sugiere el mejor punto de enfoque"
        case .subjectTracking:
            return "Sigue automáticamente al sujeto principal detectado"
        case .manual:
            return "Control manual completo del punto de enfoque"
        case .hyperfocal:
            return "Enfoque hiperfocal para fotografía de paisajes"
        }
    }
}

// MARK: - Preview

@available(iOS 15.0, macOS 12.0, *)
struct SmartAutoFocusView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            SmartAutoFocusView(captureDevice: .constant(nil))
        }
        .preferredColorScheme(.dark)
    }
}