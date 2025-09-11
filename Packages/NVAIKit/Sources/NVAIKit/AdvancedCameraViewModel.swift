import Foundation
@preconcurrency import AVFoundation
import SwiftUI
import Combine
import Photos
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Advanced Camera View Model

@available(iOS 15.0, macOS 12.0, *)
@MainActor
public class AdvancedCameraViewModel: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public var isSessionRunning = false
    @Published public var isRecording = false
    @Published public var currentZoom: CGFloat = 1.0
    @Published public var isFlashOn = false
    @Published public var currentCameraPosition: AVCaptureDevice.Position = .back
    @Published public var cameraMode: CameraMode = .photo
    @Published public var captureQuality: CaptureQuality = .high
    @Published public var errorMessage: String?
    @Published public var lastCapturedMedia: CapturedMedia?
    @Published public var availableDevices: [CameraDevice] = []
    @Published public var currentExposure: Float = 0.0
    @Published public var currentISO: Float = 100.0
    @Published public var focusMode: AVCaptureDevice.FocusMode = .autoFocus
    
    // MARK: - Internal Properties
    
    @MainActor
    public var previewLayer: AVCaptureVideoPreviewLayer? {
        // Sync access for compatibility with SwiftUI
        return mockPreviewLayer
    }
    
    @MainActor
    private var mockPreviewLayer: AVCaptureVideoPreviewLayer? = nil
    
    private let captureSession = AdvancedCaptureSession()
    @MainActor
    private var previewLayerCache: AVCaptureVideoPreviewLayer?
    private let aiProcessor: LiveAIProcessor
    private var cancellables = Set<AnyCancellable>()
    
    // Camera capabilities
    private var minZoom: CGFloat = 1.0
    private var maxZoom: CGFloat = 5.0
    private var supportedFlashModes: [AVCaptureDevice.FlashMode] = []
    private var supportedFocusModes: [AVCaptureDevice.FocusMode] = []
    
    // MARK: - Initialization
    
    public init(aiProcessor: LiveAIProcessor? = nil) {
        self.aiProcessor = aiProcessor ?? LiveAIProcessor()
        
        setupBindings()
        setupNotifications()
    }
    
    deinit {
        // Note: In real implementation, would need proper cleanup without Task in deinit
        print("🧹 AdvancedCameraViewModel deinit - cleanup needed")
    }
    
    // MARK: - Public Methods
    
    public func setup() async {
        do {
            try await captureSession.configure()
            
            // Cache preview layer
            mockPreviewLayer = AVCaptureVideoPreviewLayer() // Use local instance for compatibility
            await updateCameraCapabilities()
            await discoverAvailableDevices()
            
            isSessionRunning = true
            await startAIProcessing()
            
        } catch {
            await handleError("Failed to setup camera: \(error.localizedDescription)")
        }
    }
    
    public func cleanup() async {
        isSessionRunning = false
        await captureSession.stopRunning()
        await aiProcessor.stopLiveAnalysis()
    }
    
    // MARK: - Camera Controls
    
    public func capturePhoto() async throws {
        guard isSessionRunning else { return }
        
        let startTime = CACurrentMediaTime()
        let currentQuality = captureQuality
        let currentFlashMode = isFlashOn ? AVCaptureDevice.FlashMode.on : .off
        
        do {
            let photoData = try await captureSession.capturePhoto(
                quality: currentQuality,
                flashMode: currentFlashMode
            )
            
            let processingTime = CACurrentMediaTime() - startTime
            
            // Process with AI (create local copy to avoid data race)
            let pixelBufferCopy = photoData.pixelBuffer
            let aiAnalysis = try await aiProcessor.processFrame(pixelBufferCopy)
            
            // Save to photo library
            let savedMedia = try await saveToPhotoLibrary(photoData, analysis: aiAnalysis)
            
            lastCapturedMedia = CapturedMedia(
                type: .photo,
                url: savedMedia.url,
                thumbnail: savedMedia.thumbnail,
                aiAnalysis: aiAnalysis,
                captureDate: Date(),
                processingTime: processingTime
            )
            
            print("📸 Photo captured in \(String(format: "%.2fms", processingTime * 1000))")
            
        } catch {
            throw CameraError.captureFailed("Photo capture failed: \(error.localizedDescription)")
        }
    }
    
    public func startVideoRecording() async throws {
        guard isSessionRunning && !isRecording else { return }
        
        let currentQuality = captureQuality
        
        do {
            try await captureSession.startVideoRecording(quality: currentQuality)
            isRecording = true
            
            print("🎥 Video recording started")
            
        } catch {
            throw CameraError.recordingFailed("Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    public func stopVideoRecording() async throws {
        guard isRecording else { return }
        
        do {
            let videoData = try await captureSession.stopVideoRecording()
            isRecording = false
            
            // Save to photo library
            let savedMedia = try await saveVideoToPhotoLibrary(videoData)
            
            lastCapturedMedia = CapturedMedia(
                type: .video,
                url: savedMedia.url,
                thumbnail: savedMedia.thumbnail,
                aiAnalysis: nil,
                captureDate: Date(),
                processingTime: 0
            )
            
            print("🎥 Video recording stopped and saved")
            
        } catch {
            isRecording = false
            throw CameraError.recordingFailed("Failed to stop recording: \(error.localizedDescription)")
        }
    }
    
    public func setZoom(_ zoom: CGFloat) async {
        let clampedZoom = max(minZoom, min(maxZoom, zoom))
        currentZoom = clampedZoom
        
        await captureSession.setZoom(clampedZoom)
    }
    
    public func setFocus(at point: CGPoint) async {
        await captureSession.setFocus(at: point, mode: focusMode)
        print("🎯 Focus set at: \(point)")
    }
    
    public func setExposure(at point: CGPoint, value: Float? = nil) async {
        if let value = value {
            currentExposure = value
            await captureSession.setExposure(value: value)
        } else {
            await captureSession.setExposure(at: point)
        }
    }
    
    public func switchCamera(to position: AVCaptureDevice.Position) async {
        guard currentCameraPosition != position else { return }
        
        do {
            try await captureSession.switchCamera(to: position)
            currentCameraPosition = position
            await updateCameraCapabilities()
            
            print("🔄 Switched to \(position == .back ? "back" : "front") camera")
            
        } catch {
            await handleError("Failed to switch camera: \(error.localizedDescription)")
        }
    }
    
    public func toggleFlash() async {
        guard supportedFlashModes.contains(isFlashOn ? .off : .on) else { return }
        
        isFlashOn.toggle()
        await captureSession.setFlashMode(isFlashOn ? .on : .off)
        
        print("⚡ Flash \(isFlashOn ? "on" : "off")")
    }
    
    public func setCameraMode(_ mode: CameraMode) async {
        guard cameraMode != mode else { return }
        
        let modeToSet = mode
        cameraMode = mode
        await captureSession.setCameraMode(modeToSet)
        
        print("📷 Camera mode: \(mode.displayName)")
    }
    
    public func setCaptureQuality(_ quality: CaptureQuality) async {
        let qualityToSet = quality
        captureQuality = quality
        await captureSession.setCaptureQuality(qualityToSet)
        
        print("⚙️ Capture quality: \(quality.displayName)")
    }
    
    // MARK: - Private Methods
    
    private func setupBindings() {
        // Observe AI processor state
        // Note: In real implementation, would properly observe AI processor updates
    }
    
    private func setupNotifications() {
        NotificationCenter.default.publisher(for: AVCaptureSession.runtimeErrorNotification)
            .sink { [weak self] notification in
                Task { @MainActor in
                    if let error = notification.userInfo?[AVCaptureSessionErrorKey] as? AVError {
                        await self?.handleError("Camera runtime error: \(error.localizedDescription)")
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    private func startAIProcessing() async {
        do {
            try await aiProcessor.startLiveAnalysis()
            print("🤖 AI processing started")
        } catch {
            print("⚠️ Failed to start AI processing: \(error.localizedDescription)")
        }
    }
    
    private func processAIAnalysis(_ analysis: LiveAnalysis) async {
        // Process AI suggestions and update UI accordingly
        // This would be connected to the AI guidance overlay
    }
    
    private func updateCameraCapabilities() async {
        guard let device = captureSession.currentDevice else { return }
        
        #if os(iOS)
        minZoom = device.minAvailableVideoZoomFactor
        maxZoom = device.maxAvailableVideoZoomFactor
        #else
        minZoom = 1.0
        maxZoom = 5.0
        #endif
        
        supportedFlashModes = device.supportedFlashModes
        supportedFocusModes = device.supportedFocusModes
        
        // Update current values within supported ranges
        currentZoom = max(minZoom, min(maxZoom, currentZoom))
        
        print("📋 Camera capabilities updated - Zoom: \(minZoom)-\(maxZoom)x")
    }
    
    private func discoverAvailableDevices() async {
        #if os(iOS)
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera,
            .builtInUltraWideCamera,
            .builtInTelephotoCamera,
            .builtInTripleCamera,
            .builtInDualCamera,
            .builtInDualWideCamera,
            .builtInTrueDepthCamera
        ]
        #else
        let deviceTypes: [AVCaptureDevice.DeviceType] = [
            .builtInWideAngleCamera
        ]
        #endif
        
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: deviceTypes,
            mediaType: .video,
            position: .unspecified
        )
        
        availableDevices = discoverySession.devices.map { device in
            CameraDevice(
                id: device.uniqueID,
                name: device.localizedName,
                position: device.position,
                deviceType: device.deviceType,
                isDefault: false // Simplified for compatibility
            )
        }
        
        print("📱 Found \(availableDevices.count) camera devices")
    }
    
    private func saveToPhotoLibrary(_ photoData: PhotoData, analysis: FrameAnalysis) async throws -> SavedMedia {
        // Implementation would save to photo library with metadata
        // For now, return mock data
        #if canImport(UIKit)
        let mockThumbnail = UIImage(systemName: "photo") ?? UIImage()
        #else
        let mockThumbnail = NSImage(systemSymbolName: "photo", accessibilityDescription: nil) ?? NSImage()
        #endif
        
        return SavedMedia(
            url: URL(fileURLWithPath: "/tmp/photo.jpg"),
            thumbnail: mockThumbnail
        )
    }
    
    private func saveVideoToPhotoLibrary(_ videoData: VideoData) async throws -> SavedMedia {
        // Implementation would save video to photo library
        // For now, return mock data
        #if canImport(UIKit)
        let mockThumbnail = UIImage(systemName: "video") ?? UIImage()
        #else
        let mockThumbnail = NSImage(systemSymbolName: "video", accessibilityDescription: nil) ?? NSImage()
        #endif
        
        return SavedMedia(
            url: URL(fileURLWithPath: "/tmp/video.mov"),
            thumbnail: mockThumbnail
        )
    }
    
    private func handleError(_ message: String) async {
        errorMessage = message
        print("❌ Camera Error: \(message)")
        
        // Auto-clear error after 3 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            if self.errorMessage == message {
                self.errorMessage = nil
            }
        }
    }
}

// MARK: - AI Assistant View Model

@available(iOS 15.0, macOS 12.0, *)
@MainActor
public class AIAssistantViewModel: ObservableObject {
    
    @Published public var currentSuggestions: [AISuggestion] = []
    @Published public var showingPanel = false
    @Published public var assistantMode: AssistantMode = .smart
    @Published public var confidence: Double = 0.0
    
    private var aiProcessor: LiveAIProcessor?
    private var cancellables = Set<AnyCancellable>()
    
    public init() {}
    
    public func connect(to cameraModel: AdvancedCameraViewModel) async {
        // Connect to AI processor for real-time suggestions
        // This would stream suggestions from the LiveAIProcessor
        
        // Mock suggestions for demo
        currentSuggestions = [
            .adjustExposure(value: 0.2),
            .changeAngle(degrees: 5.0),
            .captureNow(reason: "Perfect light!")
        ]
        
        confidence = 0.85
    }
    
    public func togglePanel() {
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
            showingPanel.toggle()
        }
    }
    
    public func setAssistantMode(_ mode: AssistantMode) {
        assistantMode = mode
    }
}

// MARK: - AI Assistant Panel

@available(iOS 15.0, macOS 12.0, *)
public struct AIAssistantPanel: View {
    
    @ObservedObject var viewModel: AIAssistantViewModel
    
    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title2)
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Assistant")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("Confidence: \(Int(viewModel.confidence * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Done") {
                    viewModel.togglePanel()
                }
                .font(.subheadline)
                .foregroundColor(.blue)
            }
            
            // Suggestions List
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(Array(viewModel.currentSuggestions.enumerated()), id: \.offset) { index, suggestion in
                        SuggestionCard(suggestion: suggestion)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            // Mode Selector
            Picker("Assistant Mode", selection: $viewModel.assistantMode) {
                ForEach(AssistantMode.allCases, id: \.self) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding(20)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 20)
    }
}

// MARK: - Suggestion Card

@available(iOS 15.0, macOS 12.0, *)
private struct SuggestionCard: View {
    
    let suggestion: AISuggestion
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundColor(.white)
                .frame(width: 40, height: 40)
                .background(suggestionColor)
                .clipShape(Circle())
            
            Text(suggestionText)
                .font(.caption)
                .fontWeight(.medium)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
        }
        .frame(width: 80)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    private var iconName: String {
        switch suggestion {
        case .adjustExposure: return "sun.max"
        case .changeAngle: return "rotate.3d"
        case .waitForBetterLighting: return "lightbulb"
        case .captureNow: return "camera"
        case .addFilter: return "camera.filters"
        case .focusOn: return "scope"
        }
    }
    
    private var suggestionColor: Color {
        switch suggestion {
        case .adjustExposure: return .orange
        case .changeAngle: return .blue
        case .waitForBetterLighting: return .yellow
        case .captureNow: return .green
        case .addFilter: return .purple
        case .focusOn: return .cyan
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
            return filter.rawValue
        case .focusOn:
            return "Focus Here"
        }
    }
}

// MARK: - Supporting Types

@available(iOS 15.0, macOS 12.0, *)
public enum CameraMode: String, CaseIterable, Sendable {
    case photo = "photo"
    case video = "video"
    case portrait = "portrait"
    case night = "night"
    case panorama = "panorama"
    case slowMotion = "slow_motion"
    case timelapase = "timelapse"
    
    public var displayName: String {
        switch self {
        case .photo: return "Photo"
        case .video: return "Video"
        case .portrait: return "Portrait"
        case .night: return "Night"
        case .panorama: return "Panorama"
        case .slowMotion: return "Slow-Mo"
        case .timelapase: return "Time-lapse"
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
public enum CaptureQuality: String, CaseIterable, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case ultra = "ultra"
    
    public var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .ultra: return "Ultra"
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
public enum AssistantMode: String, CaseIterable {
    case off = "off"
    case basic = "basic"
    case smart = "smart"
    case expert = "expert"
    
    public var displayName: String {
        switch self {
        case .off: return "Off"
        case .basic: return "Basic"
        case .smart: return "Smart"
        case .expert: return "Expert"
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
public struct CameraDevice: Identifiable {
    public let id: String
    public let name: String
    public let position: AVCaptureDevice.Position
    public let deviceType: AVCaptureDevice.DeviceType
    public let isDefault: Bool
}

@available(iOS 15.0, macOS 12.0, *)
public struct CapturedMedia {
    public let type: CameraMediaType
    public let url: URL
    #if canImport(UIKit)
    public let thumbnail: UIImage
    #else
    public let thumbnail: NSImage
    #endif
    public let aiAnalysis: FrameAnalysis?
    public let captureDate: Date
    public let processingTime: TimeInterval
}

@available(iOS 15.0, macOS 12.0, *)
public enum CameraMediaType {
    case photo
    case video
}

@available(iOS 15.0, macOS 12.0, *)
private struct SavedMedia {
    let url: URL
    #if canImport(UIKit)
    let thumbnail: UIImage
    #else
    let thumbnail: NSImage
    #endif
}

@available(iOS 15.0, macOS 12.0, *)
private struct PhotoData: @unchecked Sendable {
    let pixelBuffer: CVPixelBuffer
    let metadata: [String: Any]
}

@available(iOS 15.0, macOS 12.0, *)
private struct VideoData: @unchecked Sendable {
    let url: URL
    let duration: TimeInterval
}

@available(iOS 15.0, macOS 12.0, *)
public enum CameraError: Error, LocalizedError {
    case setupFailed(String)
    case captureFailed(String)
    case recordingFailed(String)
    case deviceUnavailable
    case permissionDenied
    
    public var errorDescription: String? {
        switch self {
        case .setupFailed(let message): return "Setup failed: \(message)"
        case .captureFailed(let message): return "Capture failed: \(message)"
        case .recordingFailed(let message): return "Recording failed: \(message)"
        case .deviceUnavailable: return "Camera device unavailable"
        case .permissionDenied: return "Camera permission denied"
        }
    }
}

// MARK: - Advanced Capture Session (Mock Implementation)

@available(iOS 15.0, macOS 12.0, *)
private class AdvancedCaptureSession: @unchecked Sendable {
    
    private var previewLayer: AVCaptureVideoPreviewLayer?
    var currentDevice: AVCaptureDevice?
    
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer? {
        return previewLayer
    }
    
    func configure() async throws {
        // Mock implementation - in real app would configure AVCaptureSession
        previewLayer = AVCaptureVideoPreviewLayer()
        
        // Simulate configuration delay
        try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
    
    func stopRunning() async {
        // Mock stop
    }
    
    func capturePhoto(quality: CaptureQuality, flashMode: AVCaptureDevice.FlashMode) async throws -> PhotoData {
        // Mock photo capture
        try await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
        
        // Create mock pixel buffer
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                     kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        let status = CVPixelBufferCreate(kCFAllocatorDefault, 1920, 1080, kCVPixelFormatType_32ARGB, attrs, &pixelBuffer)
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            throw CameraError.captureFailed("Failed to create pixel buffer")
        }
        
        return PhotoData(pixelBuffer: buffer, metadata: [:])
    }
    
    func startVideoRecording(quality: CaptureQuality) async throws {
        // Mock video recording start
    }
    
    func stopVideoRecording() async throws -> VideoData {
        // Mock video recording stop
        return VideoData(url: URL(fileURLWithPath: "/tmp/video.mov"), duration: 10.0)
    }
    
    func setZoom(_ zoom: CGFloat) async {
        // Mock zoom control
    }
    
    func setFocus(at point: CGPoint, mode: AVCaptureDevice.FocusMode) async {
        // Mock focus control
    }
    
    func setExposure(at point: CGPoint) async {
        // Mock exposure control
    }
    
    func setExposure(value: Float) async {
        // Mock manual exposure control
    }
    
    func switchCamera(to position: AVCaptureDevice.Position) async throws {
        // Mock camera switch
    }
    
    func setFlashMode(_ mode: AVCaptureDevice.FlashMode) async {
        // Mock flash control
    }
    
    func setCameraMode(_ mode: CameraMode) async {
        // Mock camera mode switch
    }
    
    func setCaptureQuality(_ quality: CaptureQuality) async {
        // Mock quality adjustment
    }
}

// MARK: - Extensions

@available(iOS 15.0, macOS 12.0, *)
extension AVCaptureDevice {
    var supportedFlashModes: [AVCaptureDevice.FlashMode] {
        var modes: [AVCaptureDevice.FlashMode] = [.off]
        if hasFlash {
            modes.append(.on)
            modes.append(.auto)
        }
        return modes
    }
    
    var supportedFocusModes: [AVCaptureDevice.FocusMode] {
        var modes: [AVCaptureDevice.FocusMode] = []
        
        if isFocusModeSupported(.locked) { modes.append(.locked) }
        if isFocusModeSupported(.autoFocus) { modes.append(.autoFocus) }
        if isFocusModeSupported(.continuousAutoFocus) { modes.append(.continuousAutoFocus) }
        
        return modes
    }
}

@available(iOS 15.0, macOS 12.0, *)
extension LiveAIProcessor {
    var analysisUpdates: AsyncStream<LiveAnalysis> {
        AsyncStream { continuation in
            // Mock stream - in real implementation would emit real analysis updates
            Task {
                while !Task.isCancelled {
                    try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                    let mockAnalysis = LiveAnalysis(
                        frameAnalysis: FrameAnalysis.empty(),
                        timestamp: Date(),
                        processingTime: 0.05
                    )
                    continuation.yield(mockAnalysis)
                }
            }
        }
    }
}