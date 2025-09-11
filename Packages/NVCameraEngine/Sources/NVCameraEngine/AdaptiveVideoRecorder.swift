import Foundation
import AVFoundation
import CoreImage
import Vision

// MARK: - Adaptive Video Recording System

@available(iOS 15.0, macOS 12.0, *)
@CameraActor
public class AdaptiveVideoRecorder: ObservableObject, Sendable {
    
    // MARK: - Properties
    private var isInitialized = false
    private var currentSession: RecordingSession?
    private var assetWriter: AVAssetWriter?
    private var videoWriterInput: AVAssetWriterInput?
    private var audioWriterInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    
    // Environment monitoring
    private var environmentMonitor: EnvironmentMonitor?
    private var qualityAdapter: VideoQualityAdapter?
    private var filterProcessor: RealTimeFilterProcessor?
    
    @Published public var isRecording: Bool = false
    @Published public var currentQuality: VideoQuality = .high
    @Published public var recordingDuration: TimeInterval = 0.0
    @Published public var adaptationEvents: [QualityAdaptationEvent] = []
    
    // MARK: - Initialization
    
    public init() {
        Task {
            await initialize()
        }
    }
    
    private func initialize() async {
        environmentMonitor = EnvironmentMonitor()
        qualityAdapter = VideoQualityAdapter()
        filterProcessor = RealTimeFilterProcessor()
        isInitialized = true
    }
    
    // MARK: - Recording Control
    
    /// Starts adaptive video recording with intelligent quality management
    public func startRecording(with preferences: VideoPreferences) async throws -> RecordingSession {
        guard isInitialized else {
            throw VideoRecordingError.notInitialized
        }
        
        guard !isRecording else {
            throw VideoRecordingError.alreadyRecording
        }
        
        // Create recording session
        let sessionId = UUID()
        let session = RecordingSession(
            id: sessionId,
            preferences: preferences,
            startTime: Date(),
            initialQuality: mapPreferencesToQuality(preferences)
        )
        
        // Setup recording infrastructure
        try await setupRecording(with: preferences, sessionId: sessionId)
        
        // Start environment monitoring
        await environmentMonitor?.startMonitoring()
        
        // Begin recording
        currentSession = session
        isRecording = true
        recordingDuration = 0.0
        
        // Start quality adaptation monitoring
        Task {
            await monitorAndAdaptQuality()
        }
        
        return session
    }
    
    /// Stops the current recording session
    public func stopRecording() async throws -> RecordedVideo {
        guard isRecording, let session = currentSession else {
            throw VideoRecordingError.notRecording
        }
        
        isRecording = false
        await environmentMonitor?.stopMonitoring()
        
        // Finalize recording
        let videoURL = try await finalizeRecording()
        
        let recordedVideo = RecordedVideo(
            id: UUID(),
            url: videoURL,
            duration: recordingDuration,
            resolution: session.preferences.resolution,
            frameRate: session.preferences.frameRate,
            codec: session.preferences.codec,
            createdAt: Date(),
            adaptationEvents: adaptationEvents
        )
        
        // Cleanup
        currentSession = nil
        adaptationEvents.removeAll()
        
        return recordedVideo
    }
    
    /// Adapts video quality based on current environment conditions
    public func adaptQuality(basedOn conditions: EnvironmentConditions) async {
        guard isRecording, let session = currentSession else { return }
        
        let recommendedQuality = await qualityAdapter?.determineOptimalQuality(
            conditions: conditions,
            preferences: session.preferences
        ) ?? currentQuality
        
        if recommendedQuality != currentQuality {
            await transitionToQuality(recommendedQuality, reason: .environmentalConditions(conditions))
        }
    }
    
    /// Applies real-time filters to the video stream
    public func applyRealTimeFilters(_ filterChain: [VideoFilter]) async {
        guard isRecording else { return }
        
        await filterProcessor?.updateFilterChain(filterChain)
    }
    
    // MARK: - Private Implementation
    
    private func setupRecording(with preferences: VideoPreferences, sessionId: UUID) async throws {
        // Create temporary URL for recording
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording_\(sessionId.uuidString).mov")
        
        // Setup AVAssetWriter
        assetWriter = try AVAssetWriter(outputURL: tempURL, fileType: .mov)
        
        // Configure video input
        let videoSettings = createVideoSettings(from: preferences)
        videoWriterInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoWriterInput?.expectsMediaDataInRealTime = true
        
        // Setup pixel buffer adaptor
        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
            kCVPixelBufferWidthKey as String: Int(preferences.resolution.cgSize.width),
            kCVPixelBufferHeightKey as String: Int(preferences.resolution.cgSize.height)
        ]
        
        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoWriterInput!,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )
        
        // Configure audio input
        let audioSettings = createAudioSettings()
        audioWriterInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioWriterInput?.expectsMediaDataInRealTime = true
        
        // Add inputs to writer
        if let videoInput = videoWriterInput, assetWriter?.canAdd(videoInput) == true {
            assetWriter?.add(videoInput)
        }
        
        if let audioInput = audioWriterInput, assetWriter?.canAdd(audioInput) == true {
            assetWriter?.add(audioInput)
        }
        
        // Start writing
        guard assetWriter?.startWriting() == true else {
            throw VideoRecordingError.setupFailed("Failed to start asset writer")
        }
        
        assetWriter?.startSession(atSourceTime: CMTime.zero)
    }
    
    private func createVideoSettings(from preferences: VideoPreferences) -> [String: Any] {
        let resolution = preferences.resolution
        let codec = preferences.codec
        
        let avCodec: AVVideoCodecType
        switch codec {
        case .h264: avCodec = .h264
        case .h265, .hevc: avCodec = .hevc
        case .av1: avCodec = .h264 // Fallback to h264 if av1 not available
        }
        
        return [
            AVVideoCodecKey: avCodec,
            AVVideoWidthKey: Int(resolution.cgSize.width),
            AVVideoHeightKey: Int(resolution.cgSize.height),
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: calculateBitRate(for: resolution, frameRate: preferences.frameRate),
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                AVVideoExpectedSourceFrameRateKey: preferences.frameRate.rawValue
            ]
        ]
    }
    
    private func createAudioSettings() -> [String: Any] {
        return [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 2,
            AVEncoderBitRateKey: 128000
        ]
    }
    
    private func calculateBitRate(for resolution: VideoResolution, frameRate: FrameRate) -> Int {
        let pixelCount = Int(resolution.cgSize.width * resolution.cgSize.height)
        let baseRate = pixelCount * frameRate.rawValue / 100
        
        switch resolution {
        case .hd720: return max(baseRate, 3_000_000)
        case .hd1080: return max(baseRate, 6_000_000)
        case .uhd4k: return max(baseRate, 25_000_000)
        case .cinema4k: return max(baseRate, 30_000_000)
        }
    }
    
    private func mapPreferencesToQuality(_ preferences: VideoPreferences) -> VideoQuality {
        switch preferences.resolution {
        case .hd720: return .medium
        case .hd1080: return .high
        case .uhd4k: return .maximum
        case .cinema4k: return .maximum
        }
    }
    
    private func monitorAndAdaptQuality() async {
        while isRecording {
            if let conditions = await environmentMonitor?.getCurrentConditions() {
                await adaptQuality(basedOn: conditions)
            }
            
            // Check every 2 seconds
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }
    }
    
    private func transitionToQuality(_ newQuality: VideoQuality, reason: AdaptationReason) async {
        let event = QualityAdaptationEvent(
            timestamp: Date(),
            fromQuality: currentQuality,
            toQuality: newQuality,
            reason: reason
        )
        
        adaptationEvents.append(event)
        currentQuality = newQuality
        
        // Apply quality changes to current recording
        await applyQualityChanges(newQuality)
    }
    
    private func applyQualityChanges(_ quality: VideoQuality) async {
        // In a real implementation, this would adjust encoder settings
        // For now, we'll simulate the quality change
    }
    
    private func finalizeRecording() async throws -> URL {
        guard let writer = assetWriter else {
            throw VideoRecordingError.finalizationFailed("No asset writer available")
        }
        
        // Mark inputs as finished
        videoWriterInput?.markAsFinished()
        audioWriterInput?.markAsFinished()
        
        // Wait for writing to complete
        await writer.finishWriting()
        
        if writer.status == .failed {
            throw VideoRecordingError.finalizationFailed(writer.error?.localizedDescription ?? "Unknown error")
        }
        
        return writer.outputURL
    }
}

// MARK: - Environment Monitor

@available(iOS 15.0, macOS 12.0, *)
private actor EnvironmentMonitor {
    private var isMonitoring = false
    private var currentConditions: EnvironmentConditions?
    
    func startMonitoring() async {
        isMonitoring = true
        Task {
            await monitorConditions()
        }
    }
    
    func stopMonitoring() async {
        isMonitoring = false
    }
    
    func getCurrentConditions() async -> EnvironmentConditions? {
        return currentConditions
    }
    
    private func monitorConditions() async {
        while isMonitoring {
            currentConditions = EnvironmentConditions(
                batteryLevel: await getBatteryLevel(),
                thermalState: await getThermalState(),
                availableStorage: await getAvailableStorage(),
                networkQuality: await getNetworkQuality(),
                lightingConditions: await getLightingConditions()
            )
            
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
    }
    
    private func getBatteryLevel() async -> Double {
        // Simulate battery monitoring
        return Double.random(in: 0.2...1.0)
    }
    
    private func getThermalState() async -> ThermalState {
        return [.normal, .fair, .serious].randomElement() ?? .normal
    }
    
    private func getAvailableStorage() async -> Int64 {
        // Return available storage in bytes
        return Int64.random(in: 1_000_000_000...10_000_000_000)
    }
    
    private func getNetworkQuality() async -> NetworkQuality {
        return [.excellent, .good, .fair, .poor].randomElement() ?? .good
    }
    
    private func getLightingConditions() async -> LightingConditions {
        return LightingConditions(
            brightness: Double.random(in: 0.1...1.0),
            stability: Double.random(in: 0.5...1.0)
        )
    }
}

// MARK: - Video Quality Adapter

@available(iOS 15.0, macOS 12.0, *)
private actor VideoQualityAdapter {
    
    func determineOptimalQuality(conditions: EnvironmentConditions, preferences: VideoPreferences) async -> VideoQuality {
        var qualityScore: Double = 1.0
        
        // Battery impact
        if conditions.batteryLevel < 0.3 {
            qualityScore *= 0.7
        } else if conditions.batteryLevel < 0.6 {
            qualityScore *= 0.9
        }
        
        // Thermal impact
        switch conditions.thermalState {
        case .serious:
            qualityScore *= 0.6
        case .fair:
            qualityScore *= 0.8
        case .normal:
            break
        }
        
        // Storage impact
        let storageGB = conditions.availableStorage / (1024 * 1024 * 1024)
        if storageGB < 2 {
            qualityScore *= 0.5
        } else if storageGB < 5 {
            qualityScore *= 0.8
        }
        
        // Lighting conditions impact
        if conditions.lightingConditions.brightness < 0.3 {
            qualityScore *= 0.9 // Lower quality in low light to reduce noise
        }
        
        // Map quality score to VideoQuality
        if qualityScore >= 0.9 {
            return .maximum
        } else if qualityScore >= 0.7 {
            return .high
        } else if qualityScore >= 0.5 {
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - Real-Time Filter Processor

@available(iOS 15.0, macOS 12.0, *)
private actor RealTimeFilterProcessor {
    private var currentFilterChain: [VideoFilter] = []
    private var ciContext: CIContext?
    
    init() {
        ciContext = CIContext()
    }
    
    func updateFilterChain(_ filters: [VideoFilter]) async {
        currentFilterChain = filters
    }
    
    func processFrame(_ pixelBuffer: CVPixelBuffer) async -> CVPixelBuffer {
        guard !currentFilterChain.isEmpty else { return pixelBuffer }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        var processedImage = ciImage
        
        // Apply filters in sequence
        for filter in currentFilterChain {
            processedImage = await applyFilter(filter, to: processedImage)
        }
        
        // Convert back to pixel buffer
        var outputPixelBuffer: CVPixelBuffer?
        CVPixelBufferCreate(
            kCFAllocatorDefault,
            CVPixelBufferGetWidth(pixelBuffer),
            CVPixelBufferGetHeight(pixelBuffer),
            CVPixelBufferGetPixelFormatType(pixelBuffer),
            nil,
            &outputPixelBuffer
        )
        
        if let outputBuffer = outputPixelBuffer {
            ciContext?.render(processedImage, to: outputBuffer)
            return outputBuffer
        }
        
        return pixelBuffer
    }
    
    private func applyFilter(_ filter: VideoFilter, to image: CIImage) async -> CIImage {
        switch filter {
        case .exposure(let value):
            return image.applyingFilter("CIExposureAdjust", parameters: ["inputEV": value])
        case .saturation(let value):
            return image.applyingFilter("CIColorControls", parameters: ["inputSaturation": value])
        case .contrast(let value):
            return image.applyingFilter("CIColorControls", parameters: ["inputContrast": value])
        case .blur(let radius):
            return image.applyingFilter("CIGaussianBlur", parameters: ["inputRadius": radius])
        case .sharpen(let intensity):
            return image.applyingFilter("CISharpenLuminance", parameters: ["inputSharpness": intensity])
        }
    }
}