//
//  SmartCompositionGuidesView.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 20-21: Smart Features Implementation - Composition Guides UI
//

import SwiftUI

@available(iOS 15.0, macOS 12.0, *)
struct SmartCompositionGuidesView: View {
    @StateObject private var compositionGuides = SmartCompositionGuides()
    @State private var showingGuidePicker = false
    
    var body: some View {
        ZStack {
            // Overlay guides on camera preview
            CompositionGuideOverlay(guides: compositionGuides.currentGuides)
            
            // Suggestions overlay
            if !compositionGuides.suggestions.isEmpty {
                VStack {
                    Spacer()
                    
                    CompositionSuggestionsOverlay(
                        suggestions: compositionGuides.suggestions,
                        confidence: compositionGuides.confidence
                    )
                    .padding(.bottom, 120)
                }
            }
            
            // Controls
            VStack {
                HStack {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        // Guide type selector
                        Button(action: { showingGuidePicker.toggle() }) {
                            VStack(spacing: 4) {
                                Image(systemName: guideTypeIcon(compositionGuides.activeGuideType))
                                    .font(.title2)
                                
                                Text(compositionGuides.activeGuideType.displayName)
                                    .font(.caption)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                            .padding(8)
                            .background(Color.black.opacity(0.6))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        
                        // Enable/disable toggle
                        Button(action: { compositionGuides.isEnabled.toggle() }) {
                            Image(systemName: compositionGuides.isEnabled ? "grid" : "grid.circle")
                                .font(.title2)
                                .foregroundColor(compositionGuides.isEnabled ? .yellow : .gray)
                                .padding(8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(8)
                        }
                        
                        // Confidence indicator
                        if compositionGuides.confidence > 0 {
                            confidenceIndicator
                        }
                    }
                }
                .padding(.trailing, 20)
                .padding(.top, 60)
                
                Spacer()
            }
        }
        .sheet(isPresented: $showingGuidePicker) {
            GuideTypePickerView(
                selectedGuide: $compositionGuides.activeGuideType,
                onDismiss: { showingGuidePicker = false }
            )
        }
    }
    
    // MARK: - View Components
    
    private var confidenceIndicator: some View {
        VStack(spacing: 4) {
            ProgressView(value: compositionGuides.confidence)
                .progressViewStyle(LinearProgressViewStyle(tint: confidenceColor))
                .frame(width: 40, height: 4)
            
            Text("\(Int(compositionGuides.confidence * 100))%")
                .font(.caption2)
                .foregroundColor(.white)
        }
        .padding(6)
        .background(Color.black.opacity(0.6))
        .cornerRadius(6)
    }
    
    private var confidenceColor: Color {
        switch compositionGuides.confidence {
        case 0.8...1.0: return .green
        case 0.5..<0.8: return .yellow
        default: return .orange
        }
    }
    
    // MARK: - Helper Methods
    
    private func guideTypeIcon(_ type: GuideType) -> String {
        switch type {
        case .ruleOfThirds: return "grid"
        case .goldenRatio: return "fiberchannel"
        case .leadingLines: return "line.diagonal"
        case .symmetry: return "arrow.up.and.down.and.arrow.left.and.right"
        case .centeredComposition: return "plus.circle"
        case .dynamicSymmetry: return "diamond"
        case .horizon: return "horizon"
        }
    }
    
    // MARK: - Public Interface
    
    /// Update with new camera frame
    func updateWithFrame(_ pixelBuffer: CVPixelBuffer) {
        compositionGuides.analyzeComposition(pixelBuffer)
    }
}

// MARK: - Composition Guide Overlay

struct CompositionGuideOverlay: View {
    let guides: [CompositionGuide]
    
    var body: some View {
        Canvas { context, size in
            for guide in guides where guide.isActive {
                context.stroke(
                    Path { path in
                        for line in guide.lines {
                            let startPoint = CGPoint(
                                x: line.start.x * size.width,
                                y: line.start.y * size.height
                            )
                            let endPoint = CGPoint(
                                x: line.end.x * size.width,
                                y: line.end.y * size.height
                            )
                            
                            path.move(to: startPoint)
                            path.addLine(to: endPoint)
                        }
                    },
                    with: .color(guideColor(for: guide.type).opacity(guideOpacity(for: guide.confidence))),
                    lineWidth: guideLineWidth(for: guide.type)
                )
                
                // Add intersection points for rule of thirds
                if guide.type == .ruleOfThirds {
                    drawThirdsIntersectionPoints(context: context, size: size)
                }
                
                // Add center point for centered composition
                if guide.type == .centeredComposition {
                    drawCenterPoint(context: context, size: size)
                }
            }
        }
    }
    
    private func drawThirdsIntersectionPoints(context: GraphicsContext, size: CGSize) {
        let thirdsPoints = [
            CGPoint(x: size.width / 3, y: size.height / 3),
            CGPoint(x: size.width * 2 / 3, y: size.height / 3),
            CGPoint(x: size.width / 3, y: size.height * 2 / 3),
            CGPoint(x: size.width * 2 / 3, y: size.height * 2 / 3)
        ]
        
        for point in thirdsPoints {
            context.fill(
                Path(ellipseIn: CGRect(
                    x: point.x - 3,
                    y: point.y - 3,
                    width: 6,
                    height: 6
                )),
                with: .color(.yellow.opacity(0.8))
            )
        }
    }
    
    private func drawCenterPoint(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        
        // Draw center cross
        context.stroke(
            Path { path in
                path.move(to: CGPoint(x: center.x - 10, y: center.y))
                path.addLine(to: CGPoint(x: center.x + 10, y: center.y))
                path.move(to: CGPoint(x: center.x, y: center.y - 10))
                path.addLine(to: CGPoint(x: center.x, y: center.y + 10))
            },
            with: .color(.white.opacity(0.8)),
            lineWidth: 2
        )
    }
    
    private func guideColor(for type: GuideType) -> Color {
        switch type {
        case .ruleOfThirds: return .yellow
        case .goldenRatio: return .orange
        case .leadingLines: return .blue
        case .symmetry: return .green
        case .centeredComposition: return .white
        case .dynamicSymmetry: return .purple
        case .horizon: return .red
        }
    }
    
    private func guideOpacity(for confidence: Float) -> Double {
        Double(max(0.3, min(0.8, confidence)))
    }
    
    private func guideLineWidth(for type: GuideType) -> CGFloat {
        switch type {
        case .ruleOfThirds, .goldenRatio: return 1.0
        case .leadingLines: return 2.0
        case .symmetry: return 1.5
        case .centeredComposition: return 2.0
        case .dynamicSymmetry: return 1.0
        case .horizon: return 2.0
        }
    }
}

// MARK: - Composition Suggestions Overlay

struct CompositionSuggestionsOverlay: View {
    let suggestions: [CompositionSuggestion]
    let confidence: Float
    @State private var currentSuggestionIndex = 0
    @State private var showSuggestions = true
    
    var body: some View {
        if showSuggestions && !suggestions.isEmpty {
            VStack(spacing: 8) {
                HStack {
                    Button(action: { showSuggestions = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                            .foregroundColor(.yellow)
                        
                        Text("Sugerencia de Composición")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    
                    Text(suggestions[currentSuggestionIndex].message)
                        .font(.body)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.leading)
                    
                    // Suggestion navigation
                    if suggestions.count > 1 {
                        HStack {
                            Button("Anterior") {
                                currentSuggestionIndex = max(0, currentSuggestionIndex - 1)
                            }
                            .disabled(currentSuggestionIndex == 0)
                            
                            Spacer()
                            
                            Text("\(currentSuggestionIndex + 1) de \(suggestions.count)")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Button("Siguiente") {
                                currentSuggestionIndex = min(suggestions.count - 1, currentSuggestionIndex + 1)
                            }
                            .disabled(currentSuggestionIndex == suggestions.count - 1)
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
                .padding(16)
                .background(Color.black.opacity(0.8))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Guide Type Picker

struct GuideTypePickerView: View {
    @Binding var selectedGuide: GuideType
    let onDismiss: () -> Void
    
    var body: some View {
        NavigationView {
            List {
                ForEach(GuideType.allCases, id: \.self) { guideType in
                    Button(action: {
                        selectedGuide = guideType
                        onDismiss()
                    }) {
                        HStack {
                            Image(systemName: iconFor(guideType))
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(guideType.displayName)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                
                                Text(descriptionFor(guideType))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            
                            Spacer()
                            
                            if guideType == selectedGuide {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Guías de Composición")
            .navigationBarItems(trailing: Button("Cerrar", action: onDismiss))
        }
    }
    
    private func iconFor(_ guide: GuideType) -> String {
        switch guide {
        case .ruleOfThirds: return "grid"
        case .goldenRatio: return "fiberchannel"
        case .leadingLines: return "line.diagonal"
        case .symmetry: return "arrow.up.and.down.and.arrow.left.and.right"
        case .centeredComposition: return "plus.circle"
        case .dynamicSymmetry: return "diamond"
        case .horizon: return "horizon"
        }
    }
    
    private func descriptionFor(_ guide: GuideType) -> String {
        switch guide {
        case .ruleOfThirds:
            return "Divide la imagen en tercios para colocar elementos clave"
        case .goldenRatio:
            return "Usa la proporción áurea para composiciones más naturales"
        case .leadingLines:
            return "Detecta líneas que guían la mirada hacia el sujeto"
        case .symmetry:
            return "Ayuda a crear composiciones simétricas equilibradas"
        case .centeredComposition:
            return "Centra el sujeto para un impacto visual fuerte"
        case .dynamicSymmetry:
            return "Usa diagonales dinámicas para composiciones energéticas"
        case .horizon:
            return "Nivela el horizonte automáticamente"
        }
    }
}

// MARK: - Preview

@available(iOS 15.0, macOS 12.0, *)
struct SmartCompositionGuidesView_Previews: PreviewProvider {
    static var previews: some View {
        ZStack {
            Color.black
            SmartCompositionGuidesView()
        }
        .preferredColorScheme(.dark)
    }
}