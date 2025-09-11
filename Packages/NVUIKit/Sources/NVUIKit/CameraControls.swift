import SwiftUI
import Foundation

// MARK: - Camera Control Components

@available(iOS 15.0, macOS 12.0, *)
public struct CameraControlsView: View {
    @Binding public var captureMode: CaptureMode
    @Binding public var flashMode: FlashMode
    @Binding public var isRecording: Bool
    
    public let onCapture: () -> Void
    public let onStartRecording: () -> Void
    public let onStopRecording: () -> Void
    
    public init(
        captureMode: Binding<CaptureMode>,
        flashMode: Binding<FlashMode>,
        isRecording: Binding<Bool>,
        onCapture: @escaping () -> Void,
        onStartRecording: @escaping () -> Void,
        onStopRecording: @escaping () -> Void
    ) {
        self._captureMode = captureMode
        self._flashMode = flashMode
        self._isRecording = isRecording
        self.onCapture = onCapture
        self.onStartRecording = onStartRecording
        self.onStopRecording = onStopRecording
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Top controls
            HStack {
                FlashButton(flashMode: $flashMode)
                
                Spacer()
                
                CaptureModeSelector(captureMode: $captureMode)
            }
            .padding(.horizontal, 20)
            
            Spacer()
            
            // Bottom controls
            HStack(spacing: 40) {
                GalleryButton()
                
                CaptureButton(
                    captureMode: captureMode,
                    isRecording: isRecording,
                    onCapture: onCapture,
                    onStartRecording: onStartRecording,
                    onStopRecording: onStopRecording
                )
                
                CameraSwitchButton()
            }
            .padding(.bottom, 40)
        }
    }
}

// MARK: - Flash Button

@available(iOS 15.0, macOS 12.0, *)
public struct FlashButton: View {
    @Binding public var flashMode: FlashMode
    
    public init(flashMode: Binding<FlashMode>) {
        self._flashMode = flashMode
    }
    
    public var body: some View {
        Button {
            cycleThroughFlashModes()
        } label: {
            Image(systemName: flashMode.iconName)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
        }
    }
    
    private func cycleThroughFlashModes() {
        switch flashMode {
        case .off:
            flashMode = .on
        case .on:
            flashMode = .auto
        case .auto:
            flashMode = .off
        }
    }
}

// MARK: - Capture Mode Selector

@available(iOS 15.0, macOS 12.0, *)
public struct CaptureModeSelector: View {
    @Binding public var captureMode: CaptureMode
    
    public init(captureMode: Binding<CaptureMode>) {
        self._captureMode = captureMode
    }
    
    public var body: some View {
        HStack(spacing: 16) {
            ForEach(CaptureMode.allCases, id: \.self) { mode in
                Button {
                    captureMode = mode
                } label: {
                    Text(mode.displayName)
                        .font(.caption)
                        .foregroundColor(captureMode == mode ? .yellow : .white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 16)
                                .fill(captureMode == mode ? .white.opacity(0.2) : .clear)
                        )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
        )
    }
}

// MARK: - Capture Button

@available(iOS 15.0, macOS 12.0, *)
public struct CaptureButton: View {
    public let captureMode: CaptureMode
    public let isRecording: Bool
    public let onCapture: () -> Void
    public let onStartRecording: () -> Void
    public let onStopRecording: () -> Void
    
    public init(
        captureMode: CaptureMode,
        isRecording: Bool,
        onCapture: @escaping () -> Void,
        onStartRecording: @escaping () -> Void,
        onStopRecording: @escaping () -> Void
    ) {
        self.captureMode = captureMode
        self.isRecording = isRecording
        self.onCapture = onCapture
        self.onStartRecording = onStartRecording
        self.onStopRecording = onStopRecording
    }
    
    public var body: some View {
        Button {
            handleCaptureAction()
        } label: {
            ZStack {
                Circle()
                    .fill(.white)
                    .frame(width: 80, height: 80)
                
                if captureMode == .video {
                    if isRecording {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.red)
                            .frame(width: 30, height: 30)
                    } else {
                        Circle()
                            .fill(.red)
                            .frame(width: 70, height: 70)
                    }
                } else {
                    Circle()
                        .fill(.white)
                        .frame(width: 70, height: 70)
                        .overlay(
                            Circle()
                                .stroke(.gray, lineWidth: 2)
                                .frame(width: 66, height: 66)
                        )
                }
            }
        }
        .scaleEffect(isRecording ? 0.9 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isRecording)
    }
    
    private func handleCaptureAction() {
        switch captureMode {
        case .photo:
            onCapture()
        case .video:
            if isRecording {
                onStopRecording()
            } else {
                onStartRecording()
            }
        }
    }
}

// MARK: - Gallery Button

@available(iOS 15.0, macOS 12.0, *)
public struct GalleryButton: View {
    public init() {}
    
    public var body: some View {
        Button {
            // Open gallery action
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(.ultraThinMaterial)
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "photo")
                        .font(.title3)
                        .foregroundColor(.white)
                )
        }
    }
}

// MARK: - Camera Switch Button

@available(iOS 15.0, macOS 12.0, *)
public struct CameraSwitchButton: View {
    public init() {}
    
    public var body: some View {
        Button {
            // Switch camera action
        } label: {
            Image(systemName: "camera.rotate")
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(.ultraThinMaterial)
                )
        }
    }
}

// MARK: - Supporting Types

public enum CaptureMode: String, CaseIterable, Sendable {
    case photo = "photo"
    case video = "video"
    
    public var displayName: String {
        switch self {
        case .photo: return "FOTO"
        case .video: return "VIDEO"
        }
    }
}

public enum FlashMode: String, CaseIterable, Sendable {
    case off = "off"
    case on = "on" 
    case auto = "auto"
    
    public var iconName: String {
        switch self {
        case .off: return "bolt.slash"
        case .on: return "bolt"
        case .auto: return "bolt.badge.a"
        }
    }
}