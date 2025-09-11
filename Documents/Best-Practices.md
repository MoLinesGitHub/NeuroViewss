# NeuroViews 2.0 - Mejores Prácticas Swift 6.2

## Tabla de Contenidos

1. [Principios Fundamentales](#principios-fundamentales)
2. [Concurrency & Actors](#concurrency--actors)
3. [Architecture Patterns](#architecture-patterns)
4. [Memory Management](#memory-management)
5. [Error Handling](#error-handling)
6. [Testing Strategies](#testing-strategies)
7. [Performance Optimization](#performance-optimization)
8. [Code Quality](#code-quality)
9. [Security Best Practices](#security-best-practices)
10. [Platform-Specific Guidelines](#platform-specific-guidelines)

---

## Principios Fundamentales

### 1. Swift 6.2 Core Principles

#### Type Safety First
```swift
// ❌ EVITAR: Weak typing y forzado opcional
func processVideo(quality: String, format: String) {
    let data = fetchData()!  // Dangerous force unwrap
}

// ✅ PREFERIR: Strong typing y safe unwrapping
enum VideoQuality: Sendable, CaseIterable {
    case sd, hd, fullHD, fourK, eightK
    
    var resolution: CGSize {
        switch self {
        case .sd: CGSize(width: 640, height: 480)
        case .hd: CGSize(width: 1280, height: 720)
        case .fullHD: CGSize(width: 1920, height: 1080)
        case .fourK: CGSize(width: 3840, height: 2160)
        case .eightK: CGSize(width: 7680, height: 4320)
        }
    }
}

func processVideo(quality: VideoQuality, format: VideoFormat) async throws {
    guard let data = try await fetchData() else { return }
    // Safe processing
}
```

#### Sendable Conformance
```swift
// ✅ Marcar tipos como Sendable cuando sea appropriate
struct CameraConfiguration: Sendable {
    let resolution: VideoQuality
    let frameRate: Int
    let codecType: VideoFormat
}

// ✅ Use @unchecked Sendable judiciously
final class LegacyDataManager: @unchecked Sendable {
    private let queue = DispatchQueue(label: "data-manager", attributes: .concurrent)
    private var _data: [String: Any] = [:]
    
    private var data: [String: Any] {
        get { queue.sync { _data } }
        set { queue.async(flags: .barrier) { self._data = newValue } }
    }
}
```

#### Protocol-Oriented Programming
```swift
// ✅ Define protocols with Sendable constraints
protocol CameraSessionProtocol: Sendable {
    func startSession() async throws
    func stopSession() async throws
    func configure(with settings: CameraConfiguration) async throws
}

// ✅ Use protocol extensions for default implementations
extension CameraSessionProtocol {
    func restart() async throws {
        try await stopSession()
        try await startSession()
    }
}
```

---

## Concurrency & Actors

### 1. Actor-Based Architecture

#### MainActor for UI Components
```swift
// ✅ Todos los ViewModels deben ser @MainActor
@MainActor
final class CameraViewModel: ObservableObject {
    @Published var isRecording = false
    @Published var currentCamera: CameraDevice?
    @Published var errorMessage: String?
    
    private let sessionActor: CameraSessionActor
    private let deviceActor: CameraDeviceActor
    
    init(sessionActor: CameraSessionActor, deviceActor: CameraDeviceActor) {
        self.sessionActor = sessionActor
        self.deviceActor = deviceActor
    }
    
    func startRecording() async {
        do {
            try await sessionActor.startRecording()
            isRecording = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
```

#### Domain Actors for Business Logic
```swift
// ✅ Use actors para proteger estado compartido
actor CameraSessionActor {
    private var session: AVCaptureSession?
    private var outputs: [AVCaptureOutput] = []
    private var currentState: SessionState = .inactive
    
    enum SessionState {
        case inactive, configuring, active, recording
    }
    
    func startSession() async throws {
        guard currentState != .active else { return }
        
        currentState = .configuring
        
        let newSession = AVCaptureSession()
        // Configure session...
        
        session = newSession
        currentState = .active
        
        await MainActor.run {
            newSession.startRunning()
        }
    }
    
    func addOutput<T: AVCaptureOutput>(_ outputType: T.Type) async throws -> T {
        guard let session = session else {
            throw CameraError.sessionNotConfigured
        }
        
        let output = T()
        guard session.canAddOutput(output) else {
            throw CameraError.outputNotSupported
        }
        
        session.addOutput(output)
        outputs.append(output)
        return output
    }
}
```

#### TaskGroup for Parallel Operations
```swift
// ✅ Use TaskGroup para operaciones paralelas
actor CameraSystemInitializer {
    func initializeSystem() async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Initialize camera devices
            group.addTask {
                try await self.initializeCameraDevices()
            }
            
            // Initialize audio system
            group.addTask {
                try await self.initializeAudioSystem()
            }
            
            // Initialize storage system
            group.addTask {
                try await self.initializeStorageSystem()
            }
            
            // Wait for all to complete
            try await group.waitForAll()
        }
    }
    
    private func initializeCameraDevices() async throws {
        // Heavy initialization work
    }
}
```

### 2. Structured Concurrency Patterns

#### Cancellation Support
```swift
// ✅ Always check for cancellation en long-running tasks
actor VideoProcessor {
    func processVideo(_ videoURL: URL) async throws -> URL {
        let frames = try await extractFrames(from: videoURL)
        
        for frame in frames {
            // Check for cancellation regularly
            try Task.checkCancellation()
            
            await processFrame(frame)
        }
        
        return try await assembleVideo(from: frames)
    }
    
    private func processFrame(_ frame: VideoFrame) async {
        // Frame processing with periodic cancellation checks
        for i in 0..<1000 {
            if i % 100 == 0 {
                try? Task.checkCancellation()
            }
            // Process...
        }
    }
}
```

#### AsyncSequence for Streaming Data
```swift
// ✅ Use AsyncSequence para data streaming
struct CameraFrameStream: AsyncSequence {
    typealias Element = CVPixelBuffer
    
    private let sessionActor: CameraSessionActor
    
    func makeAsyncIterator() -> AsyncIterator {
        AsyncIterator(sessionActor: sessionActor)
    }
    
    struct AsyncIterator: AsyncIteratorProtocol {
        private let sessionActor: CameraSessionActor
        
        init(sessionActor: CameraSessionActor) {
            self.sessionActor = sessionActor
        }
        
        func next() async throws -> CVPixelBuffer? {
            try await sessionActor.nextFrame()
        }
    }
}

// Usage:
for try await frame in CameraFrameStream(sessionActor: sessionActor) {
    await processFrame(frame)
}
```

---

## Architecture Patterns

### 1. Clean Architecture Implementation

#### Dependency Injection Container
```swift
// ✅ Protocol-based DI container
protocol DIContainer {
    func resolve<T>(_ type: T.Type) -> T
    func register<T>(_ type: T.Type, factory: @escaping () -> T)
}

final class AppDIContainer: DIContainer {
    private var factories: [String: () -> Any] = [:]
    
    func register<T>(_ type: T.Type, factory: @escaping () -> T) {
        let key = String(describing: type)
        factories[key] = factory
    }
    
    func resolve<T>(_ type: T.Type) -> T {
        let key = String(describing: type)
        guard let factory = factories[key] else {
            fatalError("Type \(type) not registered")
        }
        return factory() as! T
    }
}

// Registration:
let container = AppDIContainer()
container.register(CameraRepositoryProtocol.self) {
    CameraRepository()
}
container.register(CameraUseCaseProtocol.self) {
    CameraUseCase(repository: container.resolve(CameraRepositoryProtocol.self))
}
```

#### Repository Pattern
```swift
// ✅ Repository pattern para data access
protocol CameraConfigurationRepositoryProtocol: Sendable {
    func save(_ configuration: CameraConfiguration) async throws
    func load() async throws -> CameraConfiguration?
    func loadAll() async throws -> [CameraConfiguration]
    func delete(_ id: UUID) async throws
}

actor CameraConfigurationRepository: CameraConfigurationRepositoryProtocol {
    private let storage: StorageActorProtocol
    private let cacheActor: CacheActorProtocol
    
    init(storage: StorageActorProtocol, cache: CacheActorProtocol) {
        self.storage = storage
        self.cacheActor = cache
    }
    
    func save(_ configuration: CameraConfiguration) async throws {
        // Save to storage
        try await storage.save(configuration)
        
        // Update cache
        await cacheActor.update(configuration)
        
        // Notify observers
        await NotificationCenter.default.post(
            name: .cameraConfigurationChanged,
            object: configuration
        )
    }
    
    func load() async throws -> CameraConfiguration? {
        // Try cache first
        if let cached = await cacheActor.get(CameraConfiguration.self) {
            return cached
        }
        
        // Fallback to storage
        let configuration = try await storage.load(CameraConfiguration.self)
        
        // Update cache
        if let config = configuration {
            await cacheActor.set(config)
        }
        
        return configuration
    }
}
```

#### Use Case Pattern
```swift
// ✅ Use cases para business logic
protocol CameraRecordingUseCaseProtocol: Sendable {
    func startRecording(with configuration: RecordingConfiguration) async throws -> RecordingSession
    func stopRecording(_ session: RecordingSession) async throws -> RecordingResult
    func pauseRecording(_ session: RecordingSession) async throws
    func resumeRecording(_ session: RecordingSession) async throws
}

struct CameraRecordingUseCase: CameraRecordingUseCaseProtocol {
    private let sessionActor: CameraSessionActor
    private let storageRepository: RecordingStorageRepositoryProtocol
    private let analyticsService: AnalyticsServiceProtocol
    
    func startRecording(with configuration: RecordingConfiguration) async throws -> RecordingSession {
        // Validate configuration
        try await validateConfiguration(configuration)
        
        // Start recording
        let session = try await sessionActor.startRecording(configuration)
        
        // Save session info
        try await storageRepository.saveSession(session)
        
        // Track analytics
        await analyticsService.trackEvent(.recordingStarted, parameters: [
            "quality": configuration.quality.rawValue,
            "format": configuration.format.rawValue
        ])
        
        return session
    }
    
    private func validateConfiguration(_ config: RecordingConfiguration) async throws {
        guard await hasPermissions() else {
            throw CameraError.permissionDenied
        }
        
        guard await hasStorageSpace(for: config) else {
            throw CameraError.insufficientStorage
        }
    }
}
```

### 2. MVVM + Coordinator Pattern

#### Coordinator Implementation
```swift
// ✅ Type-safe navigation con coordinators
protocol CoordinatorProtocol: AnyObject {
    var navigationController: UINavigationController { get }
    func start()
}

@MainActor
final class CameraCoordinator: CoordinatorProtocol {
    let navigationController: UINavigationController
    private let dependencyContainer: DIContainer
    private var childCoordinators: [CoordinatorProtocol] = []
    
    init(navigationController: UINavigationController, 
         dependencyContainer: DIContainer) {
        self.navigationController = navigationController
        self.dependencyContainer = dependencyContainer
    }
    
    func start() {
        showCameraView()
    }
    
    private func showCameraView() {
        let viewModel = dependencyContainer.resolve(CameraViewModelProtocol.self)
        viewModel.coordinator = self
        
        let cameraView = CameraView(viewModel: viewModel)
        let hostingController = UIHostingController(rootView: cameraView)
        
        navigationController.pushViewController(hostingController, animated: true)
    }
    
    func showSettings() {
        let settingsCoordinator = SettingsCoordinator(
            navigationController: navigationController,
            dependencyContainer: dependencyContainer
        )
        childCoordinators.append(settingsCoordinator)
        settingsCoordinator.start()
    }
}
```

---

## Memory Management

### 1. Avoiding Memory Leaks

#### Weak References in Closures
```swift
// ❌ EVITAR: Strong reference cycles
class VideoProcessor {
    private var completion: (() -> Void)?
    
    func processVideo() {
        networking.download { [strong self] in  // ❌ Strong capture
            self.completion?()
        }
    }
}

// ✅ PREFERIR: Weak/unowned references
class VideoProcessor {
    private var completion: (() -> Void)?
    
    func processVideo() async {
        do {
            _ = try await networking.download()
            completion?()
        } catch {
            // Handle error
        }
    }
}

// For legacy callback-based APIs:
func processVideoLegacy() {
    networking.download { [weak self] result in
        guard let self = self else { return }
        self.completion?()
    }
}
```

#### Actor Lifecycle Management
```swift
// ✅ Proper actor cleanup
actor CameraSessionActor {
    private var session: AVCaptureSession?
    private var isShuttingDown = false
    
    func shutdown() async {
        isShuttingDown = true
        
        // Stop all operations
        session?.stopRunning()
        
        // Remove all inputs/outputs
        session?.inputs.forEach { session?.removeInput($0) }
        session?.outputs.forEach { session?.removeOutput($0) }
        
        session = nil
        
        print("CameraSessionActor shutdown complete")
    }
    
    deinit {
        print("CameraSessionActor deallocated")
    }
}
```

### 2. Efficient Resource Usage

#### Lazy Initialization
```swift
// ✅ Lazy initialization para recursos costosos
@MainActor
final class CameraViewModel: ObservableObject {
    private lazy var previewLayer: AVCaptureVideoPreviewLayer = {
        let layer = AVCaptureVideoPreviewLayer()
        layer.videoGravity = .resizeAspectFill
        return layer
    }()
    
    private lazy var imageProcessor: ImageProcessor = {
        ImageProcessor(configuration: .default)
    }()
    
    // Only create when actually needed
    func getPreviewLayer() -> AVCaptureVideoPreviewLayer {
        previewLayer
    }
}
```

#### Resource Pooling
```swift
// ✅ Object pooling para objetos costosos
actor ImageProcessorPool {
    private var available: [ImageProcessor] = []
    private var inUse: Set<ObjectIdentifier> = []
    private let maxPoolSize = 5
    
    func acquire() async -> ImageProcessor {
        if let processor = available.popLast() {
            inUse.insert(ObjectIdentifier(processor))
            return processor
        }
        
        let processor = ImageProcessor()
        inUse.insert(ObjectIdentifier(processor))
        return processor
    }
    
    func release(_ processor: ImageProcessor) async {
        let id = ObjectIdentifier(processor)
        inUse.remove(id)
        
        if available.count < maxPoolSize {
            processor.reset()
            available.append(processor)
        }
    }
}
```

---

## Error Handling

### 1. Typed Throws (Swift 6)

#### Custom Error Types
```swift
// ✅ Specific error types for different domains
enum CameraError: Error, Sendable, LocalizedError {
    case permissionDenied
    case deviceUnavailable
    case sessionConfigurationFailed
    case captureFailure(underlying: Error)
    case storageSpaceInsufficient
    case networkConnectionLost
    case invalidConfiguration(reason: String)
    
    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return NSLocalizedString("camera_permission_denied", comment: "Camera permission denied")
        case .deviceUnavailable:
            return NSLocalizedString("camera_device_unavailable", comment: "Camera device unavailable")
        case .sessionConfigurationFailed:
            return NSLocalizedString("camera_session_failed", comment: "Camera session configuration failed")
        case .captureFailure(let underlying):
            return NSLocalizedString("camera_capture_failed", comment: "Camera capture failed: \(underlying.localizedDescription)")
        case .storageSpaceInsufficient:
            return NSLocalizedString("storage_insufficient", comment: "Insufficient storage space")
        case .networkConnectionLost:
            return NSLocalizedString("network_connection_lost", comment: "Network connection lost")
        case .invalidConfiguration(let reason):
            return NSLocalizedString("invalid_configuration", comment: "Invalid configuration: \(reason)")
        }
    }
}

// ✅ Functions with typed throws
func startCameraSession() async throws(CameraError) {
    guard await hasPermission() else {
        throw .permissionDenied
    }
    
    do {
        try await configureSession()
    } catch let configError {
        throw .sessionConfigurationFailed
    }
}
```

#### Error Recovery Strategies
```swift
// ✅ Robust error recovery
actor ResilientCameraSession {
    private var session: AVCaptureSession?
    private var retryCount = 0
    private let maxRetries = 3
    
    func startSession() async throws {
        retryCount = 0
        try await startSessionWithRetry()
    }
    
    private func startSessionWithRetry() async throws {
        do {
            try await actuallyStartSession()
            retryCount = 0 // Reset on success
        } catch CameraError.deviceUnavailable where retryCount < maxRetries {
            retryCount += 1
            
            // Exponential backoff
            try await Task.sleep(nanoseconds: UInt64(pow(2.0, Double(retryCount)) * 1_000_000_000))
            
            try await startSessionWithRetry()
        } catch {
            // Propagate non-recoverable errors
            throw error
        }
    }
}
```

### 2. Result Type Usage

#### Comprehensive Result Handling
```swift
// ✅ Result type para operaciones que pueden fallar
enum NetworkResult<T> {
    case success(T)
    case failure(NetworkError)
    
    func map<U>(_ transform: (T) -> U) -> NetworkResult<U> {
        switch self {
        case .success(let value):
            return .success(transform(value))
        case .failure(let error):
            return .failure(error)
        }
    }
    
    func flatMap<U>(_ transform: (T) -> NetworkResult<U>) -> NetworkResult<U> {
        switch self {
        case .success(let value):
            return transform(value)
        case .failure(let error):
            return .failure(error)
        }
    }
}

// Usage:
func fetchCameraConfiguration() async -> NetworkResult<CameraConfiguration> {
    do {
        let config = try await networkService.fetchConfiguration()
        return .success(config)
    } catch let error as NetworkError {
        return .failure(error)
    } catch {
        return .failure(.unknown(error))
    }
}
```

---

## Testing Strategies

### 1. Actor Testing

#### Testing Actors
```swift
// ✅ Testing actors correctly
@Test
func testCameraSessionStartup() async throws {
    let sessionActor = CameraSessionActor()
    
    // Test that session starts correctly
    try await sessionActor.startSession()
    
    let isRunning = await sessionActor.isSessionRunning
    #expect(isRunning == true)
}

// ✅ Mock actors for testing
actor MockCameraSessionActor: CameraSessionProtocol {
    private(set) var startSessionCallCount = 0
    private(set) var stopSessionCallCount = 0
    var shouldFailStart = false
    
    func startSession() async throws {
        startSessionCallCount += 1
        if shouldFailStart {
            throw CameraError.deviceUnavailable
        }
    }
    
    func stopSession() async throws {
        stopSessionCallCount += 1
    }
}
```

#### MainActor Testing
```swift
// ✅ Testing MainActor components
@MainActor
@Test 
func testCameraViewModelRecording() async throws {
    let mockSessionActor = MockCameraSessionActor()
    let viewModel = CameraViewModel(sessionActor: mockSessionActor)
    
    // Test recording start
    await viewModel.startRecording()
    
    #expect(viewModel.isRecording == true)
    #expect(await mockSessionActor.startSessionCallCount == 1)
}
```

### 2. Integration Testing

#### End-to-End Testing
```swift
// ✅ Integration tests con real dependencies
final class CameraIntegrationTests {
    
    @Test
    func testFullRecordingWorkflow() async throws {
        let container = TestDIContainer()
        container.registerTestDependencies()
        
        let coordinator = CameraCoordinator(
            navigationController: UINavigationController(),
            dependencyContainer: container
        )
        
        // Test complete workflow
        await coordinator.start()
        
        let viewModel = container.resolve(CameraViewModelProtocol.self)
        
        // Start recording
        await viewModel.startRecording()
        #expect(viewModel.isRecording == true)
        
        // Wait a moment
        try await Task.sleep(nanoseconds: 1_000_000_000)
        
        // Stop recording
        await viewModel.stopRecording()
        #expect(viewModel.isRecording == false)
        
        // Verify file was created
        #expect(viewModel.lastRecordingURL != nil)
    }
}
```

---

## Performance Optimization

### 1. Compiler Optimizations

#### Compilation Flags
```swift
// ✅ Use appropriate optimization levels
// In Package.swift:
.target(
    name: "NeuroViews",
    swiftSettings: [
        .unsafeFlags(["-O"]), // Release optimization
        .unsafeFlags(["-whole-module-optimization"]), // Better optimization
        .define("RELEASE", .when(configuration: .release))
    ]
)
```

#### Performance-Critical Code
```swift
// ✅ Optimize hot paths
@inline(__always)
func fastPixelOperation(_ pixel: UInt32) -> UInt32 {
    // Critical path - always inline
    return pixel & 0xFF00FF00
}

@_optimize(speed)
func processVideoFrame(_ buffer: CVPixelBuffer) {
    // Speed-optimized function
    let width = CVPixelBufferGetWidth(buffer)
    let height = CVPixelBufferGetHeight(buffer)
    
    // Process pixels...
}
```

### 2. Memory Optimization

#### Efficient Data Structures
```swift
// ✅ Use appropriate data structures
struct FrameBuffer {
    // Use ContiguousArray for better performance
    private var pixels: ContiguousArray<UInt8>
    
    init(width: Int, height: Int) {
        pixels = ContiguousArray<UInt8>(repeating: 0, count: width * height * 4)
    }
    
    // Subscript for efficient access
    subscript(x: Int, y: Int) -> (r: UInt8, g: UInt8, b: UInt8, a: UInt8) {
        get {
            let index = (y * width + x) * 4
            return (pixels[index], pixels[index + 1], pixels[index + 2], pixels[index + 3])
        }
        set {
            let index = (y * width + x) * 4
            pixels[index] = newValue.r
            pixels[index + 1] = newValue.g
            pixels[index + 2] = newValue.b
            pixels[index + 3] = newValue.a
        }
    }
}
```

### 3. Async Performance

#### Efficient Task Management
```swift
// ✅ Batch operations efficiently
actor FrameProcessor {
    private let processingQueue: TaskQueue = TaskQueue(maxConcurrency: 4)
    
    func processFrames(_ frames: [VideoFrame]) async throws -> [ProcessedFrame] {
        return try await withThrowingTaskGroup(of: ProcessedFrame.self) { group in
            for frame in frames {
                group.addTask {
                    try await self.processFrame(frame)
                }
            }
            
            var results: [ProcessedFrame] = []
            for try await result in group {
                results.append(result)
            }
            return results
        }
    }
}
```

---

## Code Quality

### 1. Documentation Standards

#### Code Documentation
```swift
// ✅ Comprehensive documentation
/// Manages camera session lifecycle and configuration
/// 
/// The `CameraSessionActor` is responsible for:
/// - Managing AVCaptureSession lifecycle
/// - Handling input/output configuration
/// - Coordinating with hardware devices
/// - Providing thread-safe access to session state
///
/// ## Usage
/// ```swift
/// let sessionActor = CameraSessionActor()
/// try await sessionActor.startSession()
/// ```
///
/// - Important: Always call `stopSession()` before deallocation
/// - Note: All methods are isolated to the actor's context
/// - Warning: Session configuration changes require stopping first
actor CameraSessionActor {
    
    /// Current session state
    /// - Returns: The current session state
    private(set) var state: SessionState = .inactive
    
    /// Starts the camera session with current configuration
    /// 
    /// This method performs the following operations:
    /// 1. Validates current configuration
    /// 2. Configures inputs and outputs
    /// 3. Starts the session running
    ///
    /// - Throws: `CameraError.sessionConfigurationFailed` if configuration fails
    /// - Throws: `CameraError.permissionDenied` if camera access denied
    func startSession() async throws {
        // Implementation...
    }
}
```

### 2. Code Organization

#### File Structure
```swift
// ✅ Proper file organization
import Foundation
import AVFoundation
import Combine

// MARK: - Types

/// Configuration for camera session
struct CameraConfiguration: Sendable {
    let preset: AVCaptureSession.Preset
    let videoCodec: AVVideoCodecType
    let audioEnabled: Bool
}

// MARK: - Protocols

protocol CameraSessionProtocol: Sendable {
    func startSession() async throws
    func stopSession() async throws
}

// MARK: - Implementation

actor CameraSessionActor: CameraSessionProtocol {
    
    // MARK: - Properties
    
    private var session: AVCaptureSession?
    private var configuration: CameraConfiguration?
    
    // MARK: - Lifecycle
    
    init() {
        // Initialization
    }
    
    // MARK: - Protocol Conformance
    
    func startSession() async throws {
        // Implementation
    }
    
    func stopSession() async throws {
        // Implementation
    }
    
    // MARK: - Private Methods
    
    private func configureInputs() throws {
        // Implementation
    }
}
```

### 3. Naming Conventions

#### Swift 6.2 Naming
```swift
// ✅ Clear, descriptive names
protocol CameraDeviceDiscoveryServiceProtocol: Sendable {
    func discoverAvailableDevices() async throws -> [CameraDevice]
    func selectDefaultDevice() async throws -> CameraDevice?
}

// ✅ Consistent naming patterns
enum CameraError: Error {
    case deviceDiscoveryFailed(underlying: Error)
    case deviceConfigurationFailed(deviceID: String)
    case sessionStartupFailed(reason: SessionStartupFailureReason)
}

// ✅ Contextual naming
actor CameraSessionActor {
    func startSession() async throws // Not startCameraSession - context is clear
    func stopSession() async throws  // Consistent with start
    func addVideoInput(_ device: AVCaptureDevice) async throws
    func addAudioInput(_ device: AVCaptureDevice) async throws
}
```

---

## Security Best Practices

### 1. Data Protection

#### Sensitive Data Handling
```swift
// ✅ Secure data handling
actor SecureStorageActor {
    private let keychain = KeychainWrapper.standard
    
    func storeAPIKey(_ key: String) async throws {
        guard !key.isEmpty else {
            throw SecurityError.invalidAPIKey
        }
        
        let data = key.data(using: .utf8)!
        let success = keychain.set(data, forKey: "api_key")
        
        guard success else {
            throw SecurityError.keychainStorageFailed
        }
    }
    
    func retrieveAPIKey() async throws -> String {
        guard let data = keychain.data(forKey: "api_key"),
              let key = String(data: data, encoding: .utf8) else {
            throw SecurityError.apiKeyNotFound
        }
        
        return key
    }
}
```

#### Permission Management
```swift
// ✅ Comprehensive permission handling
actor PermissionManager {
    
    func requestCameraPermission() async throws -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .video)
        case .denied, .restricted:
            throw PermissionError.cameraAccessDenied
        @unknown default:
            throw PermissionError.unknownAuthorizationStatus
        }
    }
    
    func requestMicrophonePermission() async throws -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        
        switch status {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        case .denied, .restricted:
            throw PermissionError.microphoneAccessDenied
        @unknown default:
            throw PermissionError.unknownAuthorizationStatus
        }
    }
}
```

### 2. Network Security

#### Secure Networking
```swift
// ✅ Secure network communications
actor NetworkSecurityManager {
    private let session: URLSession
    
    init() {
        let configuration = URLSessionConfiguration.default
        configuration.tlsMinimumSupportedProtocolVersion = .TLSv12
        configuration.tlsMaximumSupportedProtocolVersion = .TLSv13
        
        // Certificate pinning
        self.session = URLSession(
            configuration: configuration,
            delegate: CertificatePinningDelegate(),
            delegateQueue: nil
        )
    }
    
    func secureRequest(to url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Add authentication header
        if let token = try? await retrieveAuthToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.invalidResponse
        }
        
        return data
    }
}
```

---

## Platform-Specific Guidelines

### 1. iOS Specific

#### iOS Performance Optimization
```swift
// ✅ iOS memory warnings handling
@MainActor
final class iOSCameraViewModel: ObservableObject {
    
    init() {
        setupMemoryWarningObserver()
    }
    
    private func setupMemoryWarningObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task {
                await self?.handleMemoryWarning()
            }
        }
    }
    
    private func handleMemoryWarning() async {
        // Clear caches
        await imageCache.clearCache()
        
        // Reduce quality if needed
        if isRecording {
            await sessionActor.reduceQuality()
        }
    }
}
```

### 2. macOS Specific

#### macOS Window Management
```swift
// ✅ macOS window coordination
@MainActor
final class macOSWindowCoordinator: NSWindowController {
    
    override func windowDidLoad() {
        super.windowDidLoad()
        
        window?.titleVisibility = .hidden
        window?.styleMask.insert(.fullSizeContentView)
        window?.isMovableByWindowBackground = true
        
        setupToolbar()
    }
    
    private func setupToolbar() {
        let toolbar = NSToolbar(identifier: "CameraToolbar")
        toolbar.delegate = self
        toolbar.allowsUserCustomization = true
        window?.toolbar = toolbar
    }
}
```

### 3. watchOS Specific

#### watchOS Connectivity
```swift
// ✅ watchOS WCSession management
@MainActor
final class WatchConnectivityManager: NSObject, ObservableObject, WCSessionDelegate {
    
    private let session = WCSession.default
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    func sendCameraCommand(_ command: CameraCommand) {
        guard session.isReachable else { return }
        
        let message = ["command": command.rawValue]
        session.sendMessage(message, replyHandler: nil) { error in
            print("Failed to send camera command: \(error)")
        }
    }
    
    // MARK: - WCSessionDelegate
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        // Handle activation
    }
}
```

### 4. visionOS Specific

#### visionOS Spatial Computing
```swift
// ✅ visionOS immersive content
import RealityKit
import ARKit

@MainActor
final class visionOSImmersiveViewModel: ObservableObject {
    
    @Published var immersiveSpaceState: ImmersionStyle = .mixed
    
    func setupImmersiveContent() async {
        let entity = ModelEntity()
        
        // Setup AR camera preview in 3D space
        let previewEntity = Entity()
        previewEntity.components[VideoMaterial.self] = VideoMaterial()
        
        // Position in user's field of view
        previewEntity.transform.translation = simd_float3(0, 0, -2)
    }
}
```

---

## Conclusión

Estas mejores prácticas para Swift 6.2 en NeuroViews 2.0 aseguran:

1. **Type Safety**: Uso exhaustivo del sistema de tipos de Swift
2. **Concurrency Safety**: Actors y structured concurrency para thread safety
3. **Memory Efficiency**: Gestión inteligente de recursos y memoria
4. **Error Handling**: Manejo robusto y tipado de errores
5. **Testing**: Estrategias comprehensivas de testing
6. **Performance**: Optimizaciones específicas para video processing
7. **Security**: Protección de datos y comunicaciones seguras
8. **Platform Integration**: Aprovechamiento de características únicas de cada plataforma

Siguiendo estas guidelines, NeuroViews 2.0 será una aplicación robusta, performante y mantenible que aprovecha todas las características modernas de Swift 6.2 y las plataformas Apple.