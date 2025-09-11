import SwiftUI
import Foundation
import Combine

// MARK: - View Models

@available(iOS 15.0, macOS 12.0, *)
public class CameraPreviewViewModel: ObservableObject {
    @Published public var currentAnalysis: AIAnalysisData?
    @Published public var isAnalyzing: Bool = false
    
    public init() {
        // Mock data for demonstration
        self.currentAnalysis = AIAnalysisData(
            confidence: 87.5,
            sceneType: "Portrait",
            suggestions: [
                SuggestionData(
                    id: UUID(),
                    title: "Focus on subject",
                    icon: "viewfinder"
                ),
                SuggestionData(
                    id: UUID(),
                    title: "Increase exposure",
                    icon: "sun.max"
                )
            ]
        )
    }
    
    public func startAnalysis() {
        isAnalyzing = true
        // This would trigger AI analysis in a real implementation
    }
    
    public func stopAnalysis() {
        isAnalyzing = false
        currentAnalysis = nil
    }
}

// MARK: - Data Models

public struct AIAnalysisData: Identifiable, Sendable {
    public let id: UUID
    public let confidence: Double
    public let sceneType: String
    public let suggestions: [SuggestionData]
    
    public init(confidence: Double, sceneType: String, suggestions: [SuggestionData]) {
        self.id = UUID()
        self.confidence = confidence
        self.sceneType = sceneType
        self.suggestions = suggestions
    }
}

public struct SuggestionData: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let icon: String
    
    public init(id: UUID = UUID(), title: String, icon: String) {
        self.id = id
        self.title = title
        self.icon = icon
    }
}

// MARK: - Environment Values

@available(iOS 15.0, macOS 12.0, *)
public struct CameraSessionKey: EnvironmentKey {
    public static let defaultValue: (any AnyCameraSession)? = nil
}

@available(iOS 15.0, macOS 12.0, *)
extension EnvironmentValues {
    public var cameraSession: (any AnyCameraSession)? {
        get { self[CameraSessionKey.self] }
        set { self[CameraSessionKey.self] = newValue }
    }
}

// MARK: - Protocol for Camera Session

@available(iOS 15.0, macOS 12.0, *)
public protocol AnyCameraSession: ObservableObject, Sendable {
    var isRunning: Bool { get }
    
    func startSession() async
    func stopSession() async
}