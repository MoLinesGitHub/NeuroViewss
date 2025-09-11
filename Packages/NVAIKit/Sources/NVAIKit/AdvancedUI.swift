import SwiftUI
import AVFoundation
import Combine

// MARK: - Advanced Camera Interface

@available(iOS 15.0, macOS 12.0, *)
public struct AdvancedCameraInterface: View {
    
    // MARK: - Properties
    
    @StateObject private var cameraModel: AdvancedCameraViewModel
    @StateObject private var aiAssistant: AIAssistantViewModel
    @State private var selectedGesture: CameraGesture?
    @State private var isRecording = false
    @State private var showingAIGuidance = true
    @State private var cameraPosition: AVCaptureDevice.Position = .back
    
    // MARK: - Initialization
    
    public init() {
        self._cameraModel = StateObject(wrappedValue: AdvancedCameraViewModel())
        self._aiAssistant = StateObject(wrappedValue: AIAssistantViewModel())
    }
    
    // MARK: - Body
    
    public var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .center) {
                // Main Camera Preview
                CameraPreviewLayer(cameraModel: cameraModel)
                    .ignoresSafeArea()
                    .overlay(alignment: .center) {
                        if showingAIGuidance {
                            AIGuidanceOverlay(
                                suggestions: aiAssistant.currentSuggestions,
                                frameSize: geometry.size
                            )
                            .allowsHitTesting(false)
                        }
                    }
                    #if canImport(UIKit)
                    .gesture(
                        AdvancedCameraGestures(
                            selectedGesture: $selectedGesture,
                            onCapture: {
                                await capturePhoto()
                            },
                            onZoom: { scale in
                                await cameraModel.setZoom(scale)
                            },
                            onFocus: { point in
                                await cameraModel.setFocus(at: point)
                            }
                        )
                    )
                    #endif
                
                // Advanced Control Interface
                VStack {
                    // Top Controls
                    HStack {
                        Button("AI", systemImage: showingAIGuidance ? "brain.fill" : "brain") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showingAIGuidance.toggle()
                            }
                        }
                        .tint(showingAIGuidance ? .blue : .white)
                        
                        Spacer()
                        
                        Button("Switch", systemImage: "camera.rotate") {
                            switchCamera()
                        }
                        .tint(.white)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Bottom Controls
                    HStack(spacing: 50) {
                        // Gallery Button
                        Button("Gallery", systemImage: "photo.stack") {
                            // Open gallery
                        }
                        .tint(.white)
                        
                        // Capture Button
                        CaptureButton(
                            isRecording: $isRecording,
                            onPhoto: {
                                await capturePhoto()
                            },
                            onVideoStart: {
                                await startVideoRecording()
                            },
                            onVideoStop: {
                                await stopVideoRecording()
                            }
                        )
                        
                        // Mode Button
                        Button("Mode", systemImage: "dial.low") {
                            // Change camera mode
                        }
                        .tint(.white)
                    }
                    .padding(.bottom, 50)
                }
                
                // AI Assistant Floating Panel
                if aiAssistant.showingPanel {
                    VStack {
                        Spacer()
                        
                        AIAssistantPanel(viewModel: aiAssistant)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: aiAssistant.showingPanel)
                        
                        Spacer().frame(height: 150)
                    }
                }
            }
        }
        .onAppear {
            Task {
                await setupCamera()
            }
        }
        .onDisappear {
            Task {
                await cameraModel.cleanup()
            }
        }
    }
    
    // MARK: - Private Methods
    
    @MainActor
    private func capturePhoto() async {
        do {
            try await cameraModel.capturePhoto()
            
            #if canImport(UIKit)
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            #endif
            
        } catch {
            print("📸 Capture failed: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func startVideoRecording() async {
        do {
            try await cameraModel.startVideoRecording()
            isRecording = true
        } catch {
            print("🎥 Recording start failed: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func stopVideoRecording() async {
        do {
            try await cameraModel.stopVideoRecording()
            isRecording = false
        } catch {
            print("🎥 Recording stop failed: \(error.localizedDescription)")
        }
    }
    
    @MainActor
    private func switchCamera() {
        cameraPosition = (cameraPosition == .back) ? .front : .back
        
        Task {
            await cameraModel.switchCamera(to: cameraPosition)
        }
    }
    
    @MainActor
    private func setupCamera() async {
        await cameraModel.setup()
        await aiAssistant.connect(to: cameraModel)
    }
}

// MARK: - Camera Preview Layer

@available(iOS 15.0, macOS 12.0, *)
public struct CameraPreviewLayer: View {
    
    @ObservedObject var cameraModel: AdvancedCameraViewModel
    
    public var body: some View {
        GeometryReader { geometry in
            #if canImport(UIKit)
            if let previewLayer = cameraModel.previewLayer {
                CameraPreviewRepresentable(
                    previewLayer: previewLayer,
                    frame: geometry.frame(in: .local)
                )
            } else {
                Rectangle()
                    .fill(Color.black)
                    .overlay {
                        VStack(spacing: 20) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                            
                            Text("Initializing Camera...")
                                .font(.headline)
                                .foregroundColor(.gray)
                        }
                    }
            }
            #else
            // macOS placeholder
            Rectangle()
                .fill(Color.black)
                .overlay {
                    VStack(spacing: 20) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("Camera not available on macOS")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                }
            #endif
        }
        .clipped()
    }
}

// MARK: - Camera Preview UIViewRepresentable

#if canImport(UIKit)
@available(iOS 15.0, macOS 12.0, *)
private struct CameraPreviewRepresentable: UIViewRepresentable {
    
    let previewLayer: AVCaptureVideoPreviewLayer
    let frame: CGRect
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: frame)
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer.frame = uiView.bounds
        CATransaction.commit()
    }
}
#endif

// MARK: - Advanced Capture Button

@available(iOS 15.0, macOS 12.0, *)
public struct CaptureButton: View {
    
    @Binding var isRecording: Bool
    let onPhoto: () async -> Void
    let onVideoStart: () async -> Void
    let onVideoStop: () async -> Void
    
    @State private var isPressed = false
    @State private var recordingScale: CGFloat = 1.0
    
    public var body: some View {
        Button {
            Task {
                if isRecording {
                    await onVideoStop()
                } else {
                    await onPhoto()
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.white)
                    .frame(width: 70, height: 70)
                    .scaleEffect(isPressed ? 0.9 : 1.0)
                    .animation(.easeInOut(duration: 0.1), value: isPressed)
                
                if isRecording {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.red)
                        .frame(width: 25, height: 25)
                        .scaleEffect(recordingScale)
                } else {
                    Circle()
                        .fill(Color.black)
                        .frame(width: 60, height: 60)
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    isPressed = true
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
        .simultaneousGesture(
            LongPressGesture(minimumDuration: 0.5)
                .onEnded { _ in
                    if !isRecording {
                        Task {
                            await onVideoStart()
                        }
                    }
                }
        )
        .onReceive(Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()) { _ in
            if isRecording {
                withAnimation(.easeInOut(duration: 0.5)) {
                    recordingScale = recordingScale == 1.0 ? 0.8 : 1.0
                }
            }
        }
    }
}

// MARK: - Supporting Types

@available(iOS 15.0, macOS 12.0, *)
public enum CameraGesture: String, CaseIterable {
    case tap = "tap"
    case doubleTap = "doubleTap"
    case pinch = "pinch"
    case pan = "pan"
    case longPress = "longPress"
    
    public var displayName: String {
        switch self {
        case .tap: return "Tap to Focus"
        case .doubleTap: return "Double Tap to Zoom"
        case .pinch: return "Pinch to Zoom"
        case .pan: return "Pan to Adjust"
        case .longPress: return "Hold to Record"
        }
    }
}