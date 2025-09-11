import SwiftUI
import Foundation

// MARK: - Advanced Camera Preview

@available(iOS 15.0, macOS 12.0, *)
public struct AdvancedCameraPreview: View {
    @Environment(\.cameraSession) private var cameraSession
    @StateObject private var viewModel: CameraPreviewViewModel
    
    public init(viewModel: CameraPreviewViewModel = CameraPreviewViewModel()) {
        self._viewModel = StateObject(wrappedValue: viewModel)
    }
    
    public var body: some View {
        ZStack {
            // Camera preview layer would go here
            Rectangle()
                .fill(Color.black)
                .overlay(alignment: .center) {
                    Text("Camera Preview")
                        .foregroundColor(.white)
                        .font(.caption)
                }
                .overlay(alignment: .topTrailing) {
                    AIAnalysisOverlay(analysis: viewModel.currentAnalysis)
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - AI Analysis Overlay

@available(iOS 15.0, macOS 12.0, *)
public struct AIAnalysisOverlay: View {
    let analysis: AIAnalysisData?
    
    public init(analysis: AIAnalysisData?) {
        self.analysis = analysis
    }
    
    public var body: some View {
        VStack(alignment: .trailing, spacing: 8) {
            if let analysis = analysis {
                ForEach(analysis.suggestions, id: \.id) { suggestion in
                    SuggestionCard(suggestion: suggestion)
                }
                
                AnalysisInfo(analysis: analysis)
            }
        }
        .padding()
    }
}

// MARK: - Suggestion Card

@available(iOS 15.0, macOS 12.0, *)
public struct SuggestionCard: View {
    let suggestion: SuggestionData
    
    public init(suggestion: SuggestionData) {
        self.suggestion = suggestion
    }
    
    public var body: some View {
        HStack(spacing: 8) {
            Image(systemName: suggestion.icon)
                .foregroundColor(.white)
                .font(.caption)
            
            Text(suggestion.title)
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Analysis Info

@available(iOS 15.0, macOS 12.0, *)
public struct AnalysisInfo: View {
    let analysis: AIAnalysisData
    
    public init(analysis: AIAnalysisData) {
        self.analysis = analysis
    }
    
    public var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(.white)
                    .font(.caption2)
                
                Text("AI: \(analysis.confidence, specifier: "%.0f")%")
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            
            Text(analysis.sceneType)
                .font(.caption2)
                .foregroundColor(.white.opacity(0.8))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
        )
    }
}
