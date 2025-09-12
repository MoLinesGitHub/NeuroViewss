//
//  CameraManager.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 16: Core Camera Implementation
//

import AVFoundation
import SwiftUI
import Photos
import Combine

#if os(iOS)
import UIKit
#endif

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
        videoDeviceDiscoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTrueDepthCamera],
            mediaType: .video,
            position: .unspecified
        )
        
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
                DispatchQueue.main.async {
                    self.cameraPosition = videoDevice.position
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
            
            photoOutput.isHighResolutionCaptureEnabled = true
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
            
            // Don't drop frames for real-time analysis
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
        } else {
            print("⚠️ Could not add video data output to the session")
        }
    }
    
    // MARK: - Device Selection
    nonisolated private func defaultVideoDevice(for position: AVCaptureDevice.Position = .back) -> AVCaptureDevice? {
        // Prefer dual camera if available
        if let dualCameraDevice = videoDeviceDiscoverySession?.devices.first(where: { 
            $0.deviceType == .builtInDualCamera && $0.position == position 
        }) {
            return dualCameraDevice
        }
        
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
            
            if !photoSettings.__availablePreviewPhotoPixelFormatTypes.isEmpty {
                photoSettings.previewPhotoFormat = [
                    kCVPixelBufferPixelFormatTypeKey as String: photoSettings.__availablePreviewPhotoPixelFormatTypes.first!,
                    kCVPixelBufferWidthKey as String: 160,
                    kCVPixelBufferHeightKey as String: 160
                ]
            }
            
            photoSettings.isHighResolutionPhotoEnabled = true
            if #available(iOS 13.0, *) {
                photoSettings.photoQualityPrioritization = .quality
            }
            
            // Capture the photo
            self.photoOutput.capturePhoto(with: photoSettings, delegate: self)
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
        // Check if AI analysis is enabled on main actor
        Task { @MainActor in
            guard self.isAIAnalysisEnabled else { return }
            
            // Process the frame
            self.processFrameForAI(sampleBuffer)
        }
    }
    
    @MainActor
    private func processFrameForAI(_ sampleBuffer: CMSampleBuffer) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }
        
        // Analyze frame with AI
        aiKit.analyzeFrame(pixelBuffer) { [weak self] result in
            Task { @MainActor in
                self?.currentAnalysis = result
                self?.aiSuggestions = result.suggestions
            }
        }
    }
}