import SwiftUI
import AVFoundation

// MARK: - AI Guidance Overlay

@available(iOS 15.0, macOS 12.0, *)
public struct AIGuidanceOverlay: View {
    
    let suggestions: [AISuggestion]
    let frameSize: CGSize
    
    @State private var animationPhase: AnimationPhase = .hidden
    @State private var pulseAnimation = false
    @State private var gridOpacity: Double = 0.3
    
    public init(suggestions: [AISuggestion], frameSize: CGSize) {
        self.suggestions = suggestions
        self.frameSize = frameSize
    }
    
    public var body: some View {
        ZStack {
            // Composition Grid
            CompositionGridOverlay(
                opacity: gridOpacity,
                frameSize: frameSize
            )
            
            // Focus Point Indicator
            if let focusPoint = getCurrentFocusPoint() {
                FocusIndicator(position: focusPoint)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulseAnimation)
            }
            
            // AI Suggestion Overlays
            ForEach(Array(suggestions.enumerated()), id: \.offset) { index, suggestion in
                SuggestionOverlay(
                    suggestion: suggestion,
                    index: index,
                    frameSize: frameSize
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.5).combined(with: .opacity),
                    removal: .scale(scale: 1.2).combined(with: .opacity)
                ))
            }
            
            // Level Indicator for Camera Tilt
            if shouldShowLevelIndicator() {
                LevelIndicator()
                    .position(x: frameSize.width / 2, y: 60)
            }
            
            // Exposure Adjustment Indicator
            if let exposureAdjustment = getExposureAdjustment() {
                ExposureIndicator(adjustment: exposureAdjustment)
                    .position(x: 60, y: frameSize.height / 2)
            }
        }
        .onAppear {
            startAnimations()
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.7), value: suggestions.count)
    }
    
    // MARK: - Helper Views
    
    private func startAnimations() {
        withAnimation(.easeIn(duration: 0.3)) {
            animationPhase = .visible
        }
        
        pulseAnimation = true
    }
    
    private func getCurrentFocusPoint() -> CGPoint? {
        // Check if there's a focus suggestion
        for suggestion in suggestions {
            if case .focusOn(let point) = suggestion {
                return CGPoint(
                    x: point.x * frameSize.width,
                    y: point.y * frameSize.height
                )
            }
        }
        return nil
    }
    
    private func shouldShowLevelIndicator() -> Bool {
        return suggestions.contains { suggestion in
            if case .changeAngle = suggestion { return true }
            return false
        }
    }
    
    private func getExposureAdjustment() -> Float? {
        for suggestion in suggestions {
            if case .adjustExposure(let value) = suggestion {
                return value
            }
        }
        return nil
    }
}

// MARK: - Composition Grid Overlay

@available(iOS 15.0, macOS 12.0, *)
private struct CompositionGridOverlay: View {
    
    let opacity: Double
    let frameSize: CGSize
    
    private let gridLineWidth: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Rule of thirds lines - Vertical
            VStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(opacity))
                    .frame(height: gridLineWidth)
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(opacity))
                    .frame(height: gridLineWidth)
                Spacer()
            }
            
            // Rule of thirds lines - Horizontal
            HStack(spacing: 0) {
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(opacity))
                    .frame(width: gridLineWidth)
                Spacer()
                Rectangle()
                    .fill(Color.white.opacity(opacity))
                    .frame(width: gridLineWidth)
                Spacer()
            }
            
            // Golden ratio spiral (optional enhancement)
            if opacity > 0.5 {
                GoldenRatioSpiral()
                    .stroke(Color.yellow.opacity(opacity * 0.5), lineWidth: 2)
            }
        }
    }
}

// MARK: - Golden Ratio Spiral

@available(iOS 15.0, macOS 12.0, *)
private struct GoldenRatioSpiral: Shape {
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        let goldenRatio: CGFloat = 1.618
        let centerX = rect.width / 2
        let centerY = rect.height / 2
        let maxRadius = min(rect.width, rect.height) / 4
        
        // Create spiral approximation using arcs
        var radius: CGFloat = 10
        var angle: Double = 0
        let angleIncrement: Double = 0.2
        
        path.move(to: CGPoint(x: centerX, y: centerY))
        
        while radius < maxRadius {
            let x = centerX + radius * cos(angle)
            let y = centerY + radius * sin(angle)
            path.addLine(to: CGPoint(x: x, y: y))
            
            angle += angleIncrement
            radius *= 1 + angleIncrement / goldenRatio
        }
        
        return path
    }
}

// MARK: - Focus Indicator

@available(iOS 15.0, macOS 12.0, *)
private struct FocusIndicator: View {
    
    let position: CGPoint
    @State private var animationScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.yellow, lineWidth: 2)
                .frame(width: 80, height: 80)
                .scaleEffect(animationScale)
                .animation(.easeOut(duration: 0.6), value: animationScale)
            
            Circle()
                .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                .frame(width: 60, height: 60)
        }
        .position(position)
        .onAppear {
            animationScale = 1.2
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                animationScale = 1.0
            }
        }
    }
}

// MARK: - Suggestion Overlay

@available(iOS 15.0, macOS 12.0, *)
private struct SuggestionOverlay: View {
    
    let suggestion: AISuggestion
    let index: Int
    let frameSize: CGSize
    
    @State private var isVisible = false
    
    var body: some View {
        VStack(spacing: 4) {
            suggestionIcon
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(suggestionColor.opacity(0.8))
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 4, x: 0, y: 2)
            
            Text(suggestionText)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
        }
        .position(suggestionPosition)
        .opacity(isVisible ? 1.0 : 0.0)
        .scaleEffect(isVisible ? 1.0 : 0.5)
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8).delay(Double(index) * 0.1)) {
                isVisible = true
            }
        }
    }
    
    private var suggestionIcon: Image {
        switch suggestion {
        case .adjustExposure:
            return Image(systemName: "sun.max.fill")
        case .changeAngle:
            return Image(systemName: "rotate.3d")
        case .waitForBetterLighting:
            return Image(systemName: "lightbulb.fill")
        case .captureNow:
            return Image(systemName: "camera.fill")
        case .addFilter:
            return Image(systemName: "camera.filters")
        case .focusOn:
            return Image(systemName: "scope")
        }
    }
    
    private var suggestionColor: Color {
        switch suggestion {
        case .adjustExposure:
            return .orange
        case .changeAngle:
            return .blue
        case .waitForBetterLighting:
            return .yellow
        case .captureNow:
            return .green
        case .addFilter:
            return .purple
        case .focusOn:
            return .cyan
        }
    }
    
    private var suggestionText: String {
        switch suggestion {
        case .adjustExposure(let value):
            return value > 0 ? "Brighter" : "Darker"
        case .changeAngle(let degrees):
            return "Tilt \(Int(degrees))°"
        case .waitForBetterLighting:
            return "Wait for Light"
        case .captureNow(let reason):
            return reason.isEmpty ? "Perfect!" : reason
        case .addFilter(let filter):
            return filter.rawValue.capitalized
        case .focusOn:
            return "Focus Here"
        }
    }
    
    private var suggestionPosition: CGPoint {
        switch suggestion {
        case .adjustExposure:
            return CGPoint(x: 60, y: frameSize.height / 2)
        case .changeAngle:
            return CGPoint(x: frameSize.width / 2, y: 60)
        case .waitForBetterLighting:
            return CGPoint(x: frameSize.width - 60, y: 100)
        case .captureNow:
            return CGPoint(x: frameSize.width / 2, y: frameSize.height - 150)
        case .addFilter:
            return CGPoint(x: frameSize.width - 60, y: frameSize.height / 2)
        case .focusOn(let point):
            return CGPoint(x: point.x * frameSize.width, y: point.y * frameSize.height - 50)
        }
    }
}

// MARK: - Level Indicator

@available(iOS 15.0, macOS 12.0, *)
private struct LevelIndicator: View {
    
    @State private var tiltAngle: Double = 0
    
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<5, id: \.self) { index in
                Rectangle()
                    .fill(Color.white.opacity(getLevelOpacity(for: index)))
                    .frame(width: 3, height: 20)
            }
        }
        .background(Color.black.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(8)
        .onAppear {
            // In real implementation, get tilt from device motion
            tiltAngle = Double.random(in: -2...2)
        }
    }
    
    private func getLevelOpacity(for index: Int) -> Double {
        let centerIndex = 2
        let distance = abs(index - centerIndex)
        let tiltOffset = Int(tiltAngle.rounded())
        let adjustedCenter = centerIndex + tiltOffset
        
        return index == adjustedCenter ? 1.0 : 0.3
    }
}

// MARK: - Exposure Indicator

@available(iOS 15.0, macOS 12.0, *)
private struct ExposureIndicator: View {
    
    let adjustment: Float
    @State private var animatedValue: Float = 0
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "sun.max.fill")
                .font(.caption)
                .foregroundColor(.white)
            
            VStack(spacing: 2) {
                ForEach(-2..<3, id: \.self) { level in
                    Rectangle()
                        .fill(getBarColor(for: level))
                        .frame(width: 20, height: 4)
                        .opacity(getBarOpacity(for: level))
                }
            }
            
            Image(systemName: "sun.min.fill")
                .font(.caption)
                .foregroundColor(.white)
        }
        .padding(8)
        .background(Color.black.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5)) {
                animatedValue = adjustment
            }
        }
    }
    
    private func getBarColor(for level: Int) -> Color {
        let normalizedLevel = Float(level)
        
        if abs(normalizedLevel - animatedValue) < 0.5 {
            return .yellow
        } else if normalizedLevel > animatedValue {
            return .orange
        } else {
            return .blue
        }
    }
    
    private func getBarOpacity(for level: Int) -> Double {
        let normalizedLevel = Float(level)
        let distance = abs(normalizedLevel - animatedValue)
        
        if distance < 0.5 {
            return 1.0
        } else if distance < 1.0 {
            return 0.6
        } else {
            return 0.3
        }
    }
}

// MARK: - Animation Phases

@available(iOS 15.0, macOS 12.0, *)
private enum AnimationPhase {
    case hidden
    case visible
    case highlighted
}