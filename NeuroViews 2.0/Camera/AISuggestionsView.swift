//
//  AISuggestionsView.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 17: AI Integration Foundation
//

import SwiftUI

@available(iOS 15.0, macOS 12.0, *)
struct AISuggestionsView: View {
    let suggestions: [AISuggestion]
    @State private var isExpanded = false
    
    var body: some View {
        VStack {
            Spacer()
            
            if !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    // Header
                    HStack {
                        Image(systemName: "brain.head.profile")
                            .foregroundColor(.blue)
                        Text("AI Suggestions")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        Spacer()
                        
                        Button(action: { 
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isExpanded.toggle()
                            }
                        }) {
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.black.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    
                    // Suggestions List
                    if isExpanded {
                        LazyVStack(alignment: .leading, spacing: 6) {
                            ForEach(suggestions.prefix(3), id: \.id) { suggestion in
                                SuggestionRowView(suggestion: suggestion)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                    } else {
                        // Show only highest priority suggestion when collapsed
                        if let topSuggestion = suggestions.first {
                            SuggestionRowView(suggestion: topSuggestion)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 12)
                                .background(Color.black.opacity(0.7))
                                .cornerRadius(12)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
        .ignoresSafeArea()
    }
}

@available(iOS 15.0, macOS 12.0, *)
struct SuggestionRowView: View {
    let suggestion: AISuggestion
    
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Icon
            Image(systemName: suggestion.type.icon)
                .foregroundColor(priorityColor)
                .font(.system(size: 16))
                .frame(width: 20, height: 20)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(suggestion.message)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer()
            
            // Confidence indicator
            if suggestion.actionable {
                ConfidenceIndicator(confidence: suggestion.confidence)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var priorityColor: Color {
        switch suggestion.priority {
        case .low:
            return .gray
        case .medium:
            return .blue
        case .high:
            return .orange
        case .critical:
            return .red
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
struct ConfidenceIndicator: View {
    let confidence: Float
    
    var body: some View {
        VStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(barColor(for: index))
                    .frame(width: 3, height: 6)
            }
        }
    }
    
    private func barColor(for index: Int) -> Color {
        let threshold = Float(index + 1) / 3.0
        return confidence >= threshold ? .green : .gray.opacity(0.3)
    }
}

// Simplified for cross-platform compatibility

#Preview {
    if #available(iOS 15.0, macOS 12.0, *) {
        AISuggestionsView(suggestions: [
            AISuggestion(
                type: .composition,
                title: "Rule of Thirds",
                message: "Try positioning your subject along the grid lines",
                confidence: 0.8,
                priority: .medium
            ),
            AISuggestion(
                type: .lighting,
                title: "Better Lighting",
                message: "Scene appears underexposed. Try moving to better lighting",
                confidence: 0.9,
                priority: .high
            )
        ])
        .background(Color.black)
    } else {
        Text("Requires iOS 15.0+")
    }
}