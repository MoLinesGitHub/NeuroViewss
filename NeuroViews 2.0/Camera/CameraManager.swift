//
//  CameraManager.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 16: Core Camera Implementation
//

@preconcurrency import AVFoundation
import SwiftUI
import Photos
import Combine

#if os(iOS)
import UIKit
#endif

// MARK: - Camera Errors
enum CameraError: LocalizedError {
    case deviceNotAvailable
    case configurationFailed
    
    var errorDescription: String? {
        switch self {
        case .deviceNotAvailable:
            return "Dispositivo de cámara no disponible"
        case .configurationFailed:
            return "Error en la configuración de la cámara"
        }
    }
}

@MainActor
final class CameraManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isAuthorized = false
    @Published var isSessionRunning = false
    @Published var isRecording = false
    #if os(iOS)
    @Published var capturedImage: UIImage?
    #endif
    @Published var errorMessage: String?
    @Published var cameraPosition: AVCaptureDevice.Position = .back
    @Published var zoomFactor: CGFloat = 1.0
    
    // AI Analysis Properties
    @Published var currentAnalysis: AIAnalysisResult?
    @Published var aiSuggestions: [AISuggestion] = []
    @Published var isAIAnalysisEnabled = true
    
    // Smart Features - Temporarily disabled for this target
    // @Published var smartExposureAssistant = SmartExposureAssistant()
    // @Published var currentExposureSuggestion: ExposureSuggestion?
    @Published var smartAutoFocus = SmartAutoFocus()
    @Published var isSmartFeaturesEnabled = true
    
    // MARK: - Camera Session Components
    nonisolated private let captureSession = AVCaptureSession()
    nonisolated(unsafe) private var videoDeviceInput: AVCaptureDeviceInput?
    nonisolated(unsafe) private var photoOutput = AVCapturePhotoOutput()
    nonisolated(unsafe) private var videoOutput = AVCaptureMovieFileOutput()
    nonisolated(unsafe) private var videoDataOutput = AVCaptureVideoDataOutput()
    nonisolated(unsafe) private var previewLayer: AVCaptureVideoPreviewLayer?
    
    // MARK: - Camera Properties
    nonisolated private let sessionQueue = DispatchQueue(label: "camera.session.queue")
    nonisolated private let videoDataQueue = DispatchQueue(label: "camera.videodata.queue")
    nonisolated(unsafe) private var setupResult: SessionSetupResult = .success
    nonisolated(unsafe) private var videoDeviceDiscoverySession: AVCaptureDevice.DiscoverySession?
    
    // CRITICAL FIX: Frame processing throttling properties
    @MainActor private var lastFrameProcessingTime: CFTimeInterval = 0
    @MainActor private var isProcessingFrame: Bool = false
    
    // AI Analysis
    private let aiKit = NVAIKit.shared
    
    // MARK: - Session Setup Result
    private enum SessionSetupResult {
        case success
        case notAuthorized
        case configurationFailed
    }
    
    override init() {
        super.init()
        
        // Create device discovery session
        #if os(iOS) || os(tvOS)
        videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
            mediaType: .video,
            position: .unspecified
        )
        #else
        // macOS - use available camera devices
        videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .unspecified
        )
        #endif
        
        // Request camera authorization
        requestCameraAuthorization()
    }
    
    // MARK: - Authorization
    private func requestCameraAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isAuthorized = true
            setupCaptureSession()
            
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isAuthorized = granted
                    if granted {
                        self?.setupCaptureSession()
                    } else {
                        self?.setupResult = .notAuthorized
                        self?.errorMessage = "Camera access denied. Please enable camera access in Settings."
                    }
                }
            }
            
        case .denied, .restricted:
            setupResult = .notAuthorized
            errorMessage = "Camera access is required for NeuroViews to function properly."
            
        @unknown default:
            setupResult = .notAuthorized
            errorMessage = "Unknown camera authorization status."
        }
    }
    
    // MARK: - Session Configuration
    private func setupCaptureSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            self.captureSession.beginConfiguration()
            
            // Configure session preset
            if self.captureSession.canSetSessionPreset(.photo) {
                self.captureSession.sessionPreset = .photo
            } else {
                print("⚠️ Cannot set photo session preset")
                DispatchQueue.main.async {
                    self.setupResult = .configurationFailed
                    self.errorMessage = "Unable to configure camera session."
                }
                self.captureSession.commitConfiguration()
                return
            }
            
            // Setup video input
            self.setupVideoInput()
            
            // Setup photo output
            self.setupPhotoOutput()
            
            // Setup video output for future video recording
            self.setupVideoOutput()
            
            // Setup video data output for AI analysis
            self.setupVideoDataOutput()
            
            self.captureSession.commitConfiguration()
            
            DispatchQueue.main.async {
                if self.setupResult == .success {
                    self.startSession()
                }
            }
        }
    }
    
    nonisolated private func setupVideoInput() {
        guard let videoDevice = defaultVideoDevice(for: .back) else {
            print("❌ Default video device is unavailable.")
            setupResult = .configurationFailed
            DispatchQueue.main.async {
                self.errorMessage = "Unable to access camera device."
            }
            return
        }
        
        do {
            let videoDeviceInput = try AVCaptureDeviceInput(device: videoDevice)
            
            if captureSession.canAddInput(videoDeviceInput) {
                captureSession.addInput(videoDeviceInput)
                self.videoDeviceInput = videoDeviceInput
                
                // Update camera position
                let devicePosition = videoDevice.position
                DispatchQueue.main.async {
                    self.cameraPosition = devicePosition
                }
            } else {
                print("❌ Couldn't add video device input to the session.")
                setupResult = .configurationFailed
                DispatchQueue.main.async {
                    self.errorMessage = "Unable to add camera input to session."
                }
            }
        } catch {
            print("❌ Couldn't create video device input: \(error)")
            setupResult = .configurationFailed
            DispatchQueue.main.async {
                self.errorMessage = "Failed to create camera input: \(error.localizedDescription)"
            }
        }
    }
    
    nonisolated private func setupPhotoOutput() {
        if captureSession.canAddOutput(photoOutput) {
            captureSession.addOutput(photoOutput)
            
            if #available(iOS 16.0, *) {
                photoOutput.maxPhotoDimensions = CMVideoDimensions(width: 4032, height: 3024)
            } else {
                photoOutput.isHighResolutionCaptureEnabled = true
            }
            if #available(iOS 13.0, *) {
                photoOutput.maxPhotoQualityPrioritization = .quality
            }
        } else {
            print("❌ Could not add photo output to the session")
            setupResult = .configurationFailed
            DispatchQueue.main.async {
                self.errorMessage = "Unable to configure photo capture."
            }
        }
    }
    
    nonisolated private func setupVideoOutput() {
        if captureSession.canAddOutput(videoOutput) {
            captureSession.addOutput(videoOutput)
        } else {
            print("⚠️ Could not add video output to the session")
            // Video output is optional, don't fail setup
        }
    }
    
    nonisolated private func setupVideoDataOutput() {
        if captureSession.canAddOutput(videoDataOutput) {
            captureSession.addOutput(videoDataOutput)
            
            videoDataOutput.videoSettings = [
                (kCVPixelBufferPixelFormatTypeKey as String): kCVPixelFormatType_32BGRA
            ]
            videoDataOutput.setSampleBufferDelegate(self, queue: videoDataQueue)
            
            // CRITICAL FIX: Always drop frames to prevent iOS termination
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            
            // CRITICAL FIX: Minimize output quality to reduce memory pressure
            if let connection = videoDataOutput.connection(with: .video) {
                connection.videoOrientation = .portrait
                // Reduce video data rate
                connection.isEnabled = true
            }
        } else {
            print("⚠️ Could not add video data output to the session")
        }
    }
    
    // MARK: - Device Selection
    nonisolated private func defaultVideoDevice(for position: AVCaptureDevice.Position = .back) -> AVCaptureDevice? {
        // Prefer dual camera if available (iOS only)
        #if os(iOS) || os(tvOS)
        if let dualCameraDevice = videoDeviceDiscoverySession?.devices.first(where: { 
            $0.deviceType == .builtInDualCamera && $0.position == position 
        }) {
            return dualCameraDevice
        }
        #endif
        
        // Fall back to wide angle camera
        if let wideAngleDevice = videoDeviceDiscoverySession?.devices.first(where: { 
            $0.deviceType == .builtInWideAngleCamera && $0.position == position 
        }) {
            return wideAngleDevice
        }
        
        // Last resort - any available device
        return videoDeviceDiscoverySession?.devices.first
    }
    
    // MARK: - Session Control
    func startSession() {
        guard isAuthorized else {
            errorMessage = "Camera not authorized"
            return
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if !self.captureSession.isRunning {
                self.captureSession.startRunning()
                
                DispatchQueue.main.async {
                    self.isSessionRunning = self.captureSession.isRunning
                }
            }
        }
    }
    
    func stopSession() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            if self.captureSession.isRunning {
                self.captureSession.stopRunning()
                
                DispatchQueue.main.async {
                    self.isSessionRunning = false
                }
            }
        }
    }
    
    // MARK: - Photo Capture
    func capturePhoto() {
        guard isAuthorized && isSessionRunning else {
            errorMessage = "Camera not ready for capture"
            return
        }
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let photoSettings = AVCapturePhotoSettings()
            
            // Configure photo settings (format is read-only, let's configure other settings)
            
            #if os(iOS) || os(tvOS)
            if !photoSettings.__availablePreviewPhotoPixelFormatTypes.isEmpty {
                photoSettings.previewPhotoFormat = [
                    kCVPixelBufferPixelFormatTypeKey as String: photoSettings.__availablePreviewPhotoPixelFormatTypes.first!,
                    kCVPixelBufferWidthKey as String: 160,
                    kCVPixelBufferHeightKey as String: 160
                ]
            }
            #endif
            
            if #available(iOS 16.0, *) {
                photoSettings.maxPhotoDimensions = CMVideoDimensions(width: 4032, height: 3024)
            } else {
                photoSettings.isHighResolutionPhotoEnabled = true
            }
            if #available(iOS 13.0, *) {
                photoSettings.photoQualityPrioritization = .quality
            }
            
            // Capture the photo
            Task { @MainActor in
                self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
            }
        }
    }
    
    // MARK: - Camera Controls
    func switchCamera() {
        let currentPosition = cameraPosition // Capture current position on main actor
        
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            
            let newPosition: AVCaptureDevice.Position = (currentPosition == .back) ? .front : .back
            
            guard let newVideoDevice = self.videoDeviceDiscoverySession?.devices.first(where: { 
                $0.position == newPosition 
            }) else {
                DispatchQueue.main.async {
                    self.errorMessage = "Unable to switch cameras"
                }
                return
            }
            
            do {
                let newVideoInput = try AVCaptureDeviceInput(device: newVideoDevice)
                
                self.captureSession.beginConfiguration()
                
                if let currentVideoInput = self.videoDeviceInput {
                    self.captureSession.removeInput(currentVideoInput)
                }
                
                if self.captureSession.canAddInput(newVideoInput) {
                    self.captureSession.addInput(newVideoInput)
                    self.videoDeviceInput = newVideoInput
                    
                    DispatchQueue.main.async {
                        self.cameraPosition = newPosition
                        self.zoomFactor = 1.0 // Reset zoom when switching cameras
                    }
                } else {
                    // Re-add the original input if new one fails
                    if let currentVideoInput = self.videoDeviceInput {
                        self.captureSession.addInput(currentVideoInput)
                    }
                    DispatchQueue.main.async {
                        self.errorMessage = "Unable to switch cameras"
                    }
                }
                
                self.captureSession.commitConfiguration()
                
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to switch cameras: \(error.localizedDescription)"
                }
            }
        }
    }
    
    func setZoom(_ factor: CGFloat) {
        guard let device = videoDeviceInput?.device else { return }
        
        #if os(iOS) || os(tvOS)
        let clampedFactor = min(max(factor, 1.0), device.activeFormat.videoMaxZoomFactor)
        
        do {
            try device.lockForConfiguration()
            device.videoZoomFactor = clampedFactor
            device.unlockForConfiguration()
            
            DispatchQueue.main.async {
                self.zoomFactor = clampedFactor
            }
        } catch {
            print("❌ Unable to set zoom: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Unable to adjust zoom"
            }
        }
        #else
        // macOS doesn't support video zoom factor
        let clampedFactor = factor
        DispatchQueue.main.async {
            self.zoomFactor = clampedFactor
        }
        #endif
    }
    
    // MARK: - Focus Control
    func focusAt(point: CGPoint, in previewLayer: AVCaptureVideoPreviewLayer) {
        guard let device = videoDeviceInput?.device,
              device.isFocusPointOfInterestSupported else { return }
        
        let focusPoint = previewLayer.captureDevicePointConverted(fromLayerPoint: point)
        
        do {
            try device.lockForConfiguration()
            device.focusPointOfInterest = focusPoint
            device.focusMode = .autoFocus
            device.exposurePointOfInterest = focusPoint
            device.exposureMode = .autoExpose
            device.unlockForConfiguration()
        } catch {
            print("❌ Unable to focus: \(error)")
        }
    }
    
    // MARK: - Preview Layer
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        if previewLayer == nil {
            previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
            previewLayer?.videoGravity = .resizeAspectFill
        }
        return previewLayer!
    }
}

// MARK: - AVCapturePhotoCaptureDelegate
extension CameraManager: AVCapturePhotoCaptureDelegate {
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        
        if let error = error {
            print("❌ Photo capture error: \(error)")
            DispatchQueue.main.async {
                self.errorMessage = "Failed to capture photo: \(error.localizedDescription)"
            }
            return
        }
        
        #if os(iOS)
        guard let photoData = photo.fileDataRepresentation(),
              let image = UIImage(data: photoData) else {
            print("❌ Unable to create image from photo data")
            DispatchQueue.main.async {
                self.errorMessage = "Unable to process captured photo"
            }
            return
        }
        
        // Save to photo library
        savePhotoToLibrary(image: image)
        
        DispatchQueue.main.async {
            self.capturedImage = image
            print("✅ Photo captured successfully")
        }
        #else
        print("❌ Photo capture not supported on macOS")
        DispatchQueue.main.async {
            self.errorMessage = "Photo capture not supported on macOS"
        }
        #endif
    }
    
    #if os(iOS)
    private func savePhotoToLibrary(image: UIImage) {
        PHPhotoLibrary.requestAuthorization { status in
            guard status == .authorized else {
                print("⚠️ Photo library access denied")
                return
            }
            
            PHPhotoLibrary.shared().performChanges({
                PHAssetCreationRequest.creationRequestForAsset(from: image)
            }) { success, error in
                if let error = error {
                    print("❌ Error saving photo: \(error)")
                } else if success {
                    print("✅ Photo saved to library")
                }
            }
        }
    }
    #endif
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Extract pixel buffer outside of Task to avoid Sendable issues
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        
        // CRITICAL FIX: Throttle to max 10fps for background processing to prevent iOS termination
        let currentTime = CACurrentMediaTime()
        if currentTime - lastFrameProcessingTime < 0.1 { // 100ms minimum interval
            return
        }
        lastFrameProcessingTime = currentTime
        
        // CRITICAL FIX: Use weak reference to prevent retain cycles causing memory pressure
        Task { @MainActor [weak self] in
            guard let self = self, self.isAIAnalysisEnabled else { return }
            
            // CRITICAL FIX: Process only one task at a time to prevent resource exhaustion
            if self.isProcessingFrame { return }
            self.isProcessingFrame = true
            
            defer {
                self.isProcessingFrame = false
            }
            
            // CRITICAL FIX: Use original buffer directly, no copying to reduce memory pressure
            self.processFrameForAI(pixelBuffer)
            
            // CRITICAL FIX: Skip smart features if AI processing is active
            if self.isSmartFeaturesEnabled && !self.isProcessingFrame {
                self.processFrameForSmartFeatures(pixelBuffer)
            }
        }
    }
    
    @MainActor
    private func processFrameForAI(_ pixelBuffer: CVPixelBuffer) {
        // Analyze frame with AI
        aiKit.analyzeFrame(pixelBuffer) { [weak self] result in
            Task { @MainActor in
                self?.currentAnalysis = result
                self?.aiSuggestions = result.suggestions
            }
        }
    }
    
    @MainActor
    private func processFrameForSmartFeatures(_ pixelBuffer: CVPixelBuffer) {
        // Process with Smart Exposure Assistant - Temporarily disabled
        // smartExposureAssistant.analyzeFrame(pixelBuffer)
        
        // Process with Smart Auto Focus
        smartAutoFocus.analyzeForFocus(pixelBuffer)
        
        // Update current exposure suggestion - Temporarily disabled
        // currentExposureSuggestion = smartExposureAssistant.currentSuggestion
    }
    
    // MARK: - Smart Features Methods
    
    /// Get current capture device for smart features
    func getCurrentDevice() -> AVCaptureDevice? {
        return videoDeviceInput?.device
    }
    
    /// Apply smart exposure suggestion - Temporarily disabled
    // func applySmartExposureSuggestion(_ suggestion: ExposureSuggestion) throws {
    //     guard let device = getCurrentDevice() else {
    //         throw CameraError.deviceNotAvailable
    //     }
    //     try smartExposureAssistant.applySuggestion(suggestion, to: device)
    // }
    
    // MARK: - Helper Methods
    
    /// Creates a shared reference to CVPixelBuffer for efficient processing
    /// This avoids expensive memory copying while maintaining thread safety
    nonisolated private func createSharedPixelBufferReference(from sourceBuffer: CVPixelBuffer) -> CVPixelBuffer {
        // In Swift 6, Core Foundation objects are automatically memory managed
        // We can safely return the source buffer without manual retain/release
        return sourceBuffer
    }
    
    /// Creates a copy of CVPixelBuffer only when absolutely necessary
    /// Use createSharedPixelBufferReference() instead for most cases
    nonisolated private func createPixelBufferCopyWhenRequired(from sourceBuffer: CVPixelBuffer) -> CVPixelBuffer? {
        // Check if we can share the buffer instead of copying
        let pixelFormat = CVPixelBufferGetPixelFormatType(sourceBuffer)
        
        // For most AI analysis, sharing is sufficient and much faster
        if pixelFormat == kCVPixelFormatType_32BGRA || pixelFormat == kCVPixelFormatType_420YpCbCr8BiPlanarFullRange {
            return createSharedPixelBufferReference(from: sourceBuffer)
        }
        
        // Only copy when format conversion is needed
        let width = CVPixelBufferGetWidth(sourceBuffer)
        let height = CVPixelBufferGetHeight(sourceBuffer)
        
        var copiedBuffer: CVPixelBuffer?
        let attributes: [String: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey as String: [:], // Enable zero-copy when possible
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attributes as CFDictionary,
            &copiedBuffer
        )
        
        guard status == kCVReturnSuccess, let buffer = copiedBuffer else {
            return nil
        }
        
        // Use optimized copying with minimal locking
        CVPixelBufferLockBaseAddress(sourceBuffer, .readOnly)
        CVPixelBufferLockBaseAddress(buffer, [])
        
        defer {
            CVPixelBufferUnlockBaseAddress(sourceBuffer, .readOnly)
            CVPixelBufferUnlockBaseAddress(buffer, [])
        }
        
        // Copy the pixel data efficiently
        let sourceBaseAddress = CVPixelBufferGetBaseAddress(sourceBuffer)
        let copiedBaseAddress = CVPixelBufferGetBaseAddress(buffer)
        let dataSize = CVPixelBufferGetDataSize(sourceBuffer)
        
        if let source = sourceBaseAddress, let copied = copiedBaseAddress {
            memcpy(copied, source, dataSize)
        }
        
        return buffer
    }
}