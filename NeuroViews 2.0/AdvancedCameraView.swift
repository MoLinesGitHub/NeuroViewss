//
//  AdvancedCameraView.swift  
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//

import SwiftUI

@available(iOS 15.0, macOS 12.0, *)
struct AdvancedCameraView: View {
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Image(systemName: "camera.metering.center.weighted.average")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)
                
                VStack(spacing: 12) {
                    Text("Advanced Camera Interface")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("AI-Powered Camera with Gesture Recognition")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
                    FeatureRow(icon: "brain.head.profile", title: "AI Guidance", description: "Real-time shooting suggestions")
                    FeatureRow(icon: "hand.tap.fill", title: "Advanced Gestures", description: "Tap, pinch, rotate controls")
                    FeatureRow(icon: "camera.filters", title: "Smart Processing", description: "Automatic enhancement")
                    FeatureRow(icon: "grid", title: "Composition Grid", description: "Rule of thirds & golden ratio")
                }
                
                Button("Start Camera Session") {
                    print("🎥 Advanced Camera - Full integration pending NVAIKit linkage")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Text("Week 13: Advanced UI/UX ✅")
                    .font(.caption)
                    .foregroundColor(.green)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .navigationTitle("NeuroViews Camera")
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
    }
}

#Preview {
    if #available(iOS 15.0, macOS 12.0, *) {
        AdvancedCameraView()
    } else {
        Text("Requires iOS 15.0+")
    }
}