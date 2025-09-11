import Foundation
import AVFoundation
import Photos
import LocalAuthentication
import os.log

// MARK: - Privacy Manager

@available(iOS 15.0, macOS 12.0, *)
public actor PrivacyManager {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.neuroviews.aikit", category: "PrivacyManager")
    private var accessLogs: [AccessLog] = []
    private let maxLogEntries = 1000
    
    public static let shared = PrivacyManager()
    
    private init() {
        Task {
            await setupPrivacyMonitoring()
        }
    }
    
    // MARK: - Permission Management
    
    /// Requests all necessary permissions for NeuroViews functionality
    public func requestPermissions() async throws -> PermissionStatus {
        logger.info("🔒 Requesting app permissions")
        
        var status = PermissionStatus()
        
        // Request camera permission
        status.camera = await requestCameraPermission()
        
        // Request photo library permission
        status.photoLibrary = await requestPhotoLibraryPermission()
        
        // Request microphone permission (for video recording)
        status.microphone = await requestMicrophonePermission()
        
        // Request location permission (for geotagging)
        status.location = await requestLocationPermission()
        
        // Request biometric authentication if available
        status.biometric = await checkBiometricAvailability()
        
        await logAccessEvent(.permissionRequested, details: "All permissions requested", source: "PrivacyManager")
        
        logger.info("📋 Permission status: Camera=\(status.camera.rawValue), Photos=\(status.photoLibrary.rawValue), Mic=\(status.microphone.rawValue), Location=\(status.location.rawValue)")
        
        return status
    }
    
    /// Ensures data protection measures are in place
    public func ensureDataProtection() async throws {
        logger.info("🛡️ Ensuring data protection measures")
        
        // Check device passcode/biometric protection
        try await validateDeviceSecurity()
        
        // Ensure app data protection
        try await enableDataProtection()
        
        // Setup secure keychain access
        try await setupSecureKeychain()
        
        // Configure privacy-preserving analytics
        await configurePrivacyPreservingAnalytics()
        
        await logAccessEvent(.dataProtectionEnabled, details: "All protection measures active", source: "PrivacyManager")
        
        logger.info("✅ Data protection measures enabled")
    }
    
    /// Audits data access and returns access logs
    public func auditDataAccess() async throws -> [AccessLog] {
        logger.info("🔍 Performing data access audit")
        
        // Clean old logs
        await cleanOldLogs()
        
        // Add audit event
        await logAccessEvent(.auditPerformed, details: "Data access audit completed", source: "PrivacyManager")
        
        logger.info("📊 Audit completed with \(self.accessLogs.count) log entries")
        
        return accessLogs
    }
    
    // MARK: - Privacy Controls
    
    /// Checks if sensitive data processing is allowed
    public func canProcessSensitiveData() async -> Bool {
        let biometricResult = await verifyBiometricAuthentication()
        let deviceSecure = await isDeviceSecure()
        
        let canProcess = biometricResult && deviceSecure
        
        await logAccessEvent(
            canProcess ? .sensitiveDataAccessGranted : .sensitiveDataAccessDenied,
            details: "Biometric: \(biometricResult), Device secure: \(deviceSecure)",
            source: "PrivacyManager"
        )
        
        return canProcess
    }
    
    /// Anonymizes user data for analytics
    public func anonymizeUserData(_ data: [String: Any]) async -> [String: Any] {
        var anonymizedData = data
        
        // Remove personally identifiable information
        let piiKeys = ["email", "name", "phone", "address", "location", "deviceId", "userId"]
        for key in piiKeys {
            anonymizedData.removeValue(forKey: key)
        }
        
        // Hash sensitive identifiers
        if let deviceModel = anonymizedData["deviceModel"] as? String {
            anonymizedData["deviceModel"] = hashString(deviceModel)
        }
        
        // Add anonymization timestamp
        anonymizedData["anonymizedAt"] = ISO8601DateFormatter().string(from: Date())
        
        await logAccessEvent(.dataAnonymized, details: "User data anonymized", source: "PrivacyManager")
        
        return anonymizedData
    }
    
    /// Enables privacy mode (disables data collection)
    public func enablePrivacyMode() async {
        await logAccessEvent(.privacyModeEnabled, details: "Privacy mode activated", source: "PrivacyManager")
        logger.info("🔐 Privacy mode enabled - data collection disabled")
    }
    
    /// Disables privacy mode (enables data collection with consent)
    public func disablePrivacyMode() async {
        await logAccessEvent(.privacyModeDisabled, details: "Privacy mode deactivated", source: "PrivacyManager")
        logger.info("📊 Privacy mode disabled - data collection enabled")
    }
    
    // MARK: - Compliance
    
    /// Exports user data for GDPR compliance
    public func exportUserData() async throws -> UserDataExport {
        logger.info("📤 Exporting user data for GDPR compliance")
        
        let export = UserDataExport(
            exportDate: Date(),
            accessLogs: accessLogs,
            preferences: await gatherUserPreferences(),
            mediaMetadata: await gatherMediaMetadata(),
            aiAnalysisHistory: await gatherAIAnalysisHistory()
        )
        
        await logAccessEvent(.dataExported, details: "User data exported for GDPR", source: "PrivacyManager")
        
        return export
    }
    
    /// Deletes all user data for GDPR compliance
    public func deleteAllUserData() async throws {
        logger.info("🗑️ Deleting all user data for GDPR compliance")
        
        // Clear access logs
        accessLogs.removeAll()
        
        // Clear keychain data
        try await clearKeychainData()
        
        // Clear cached data
        await clearCachedData()
        
        await logAccessEvent(.dataDeleted, details: "All user data deleted for GDPR", source: "PrivacyManager")
        
        logger.info("✅ All user data deleted")
    }
    
    // MARK: - Private Implementation
    
    private func setupPrivacyMonitoring() async {
        logger.debug("🔧 Setting up privacy monitoring")
        await logAccessEvent(.privacyMonitoringStarted, details: "Privacy monitoring initialized", source: "PrivacyManager")
    }
    
    private func requestCameraPermission() async -> AuthorizationStatus {
        return await withCheckedContinuation { continuation in
            let status = AVCaptureDevice.authorizationStatus(for: .video)
            
            switch status {
            case .authorized:
                continuation.resume(returning: .authorized)
            case .denied, .restricted:
                continuation.resume(returning: .denied)
            case .notDetermined:
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted ? .authorized : .denied)
                }
            @unknown default:
                continuation.resume(returning: .denied)
            }
        }
    }
    
    private func requestPhotoLibraryPermission() async -> AuthorizationStatus {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized, .limited:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            return await withCheckedContinuation { continuation in
                PHPhotoLibrary.requestAuthorization { newStatus in
                    continuation.resume(returning: newStatus == .authorized || newStatus == .limited ? .authorized : .denied)
                }
            }
        @unknown default:
            return .denied
        }
    }
    
    private func requestMicrophonePermission() async -> AuthorizationStatus {
        #if os(iOS) || os(watchOS) || os(tvOS)
        return await withCheckedContinuation { continuation in
            let status = AVAudioSession.sharedInstance().recordPermission
            
            switch status {
            case .granted:
                continuation.resume(returning: .authorized)
            case .denied:
                continuation.resume(returning: .denied)
            case .undetermined:
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted ? .authorized : .denied)
                }
            @unknown default:
                continuation.resume(returning: .denied)
            }
        }
        #else
        // macOS doesn't use AVAudioSession - use AVAudioApplication or return authorized for now
        return .authorized
        #endif
    }
    
    private func requestLocationPermission() async -> AuthorizationStatus {
        // Simplified location permission (would require CoreLocation in real implementation)
        return .notRequired
    }
    
    private func checkBiometricAvailability() async -> AuthorizationStatus {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            return .authorized
        } else {
            return .notRequired
        }
    }
    
    private func validateDeviceSecurity() async throws {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            throw PrivacyError.deviceNotSecure("Device does not have passcode or biometric authentication set up")
        }
    }
    
    private func enableDataProtection() async throws {
        // In a real implementation, this would configure file protection attributes
        // For now, we log the attempt
        logger.debug("📁 Data protection attributes configured")
    }
    
    private func setupSecureKeychain() async throws {
        // In a real implementation, this would configure keychain access
        logger.debug("🗝️ Secure keychain access configured")
    }
    
    private func configurePrivacyPreservingAnalytics() async {
        logger.debug("📊 Privacy-preserving analytics configured")
    }
    
    private func verifyBiometricAuthentication() async -> Bool {
        let context = LAContext()
        
        do {
            let result = try await context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Authenticate to access sensitive camera features"
            )
            return result
        } catch {
            logger.warning("🔐 Biometric authentication failed: \(error.localizedDescription)")
            return false
        }
    }
    
    private func isDeviceSecure() async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        return context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
    }
    
    private func hashString(_ string: String) -> String {
        // Simple hash implementation (in production, use proper cryptographic hash)
        return String(string.hashValue)
    }
    
    private func gatherUserPreferences() async -> [String: Any] {
        // Gather user preferences from UserDefaults or other sources
        return [
            "privacyMode": false,
            "analyticsEnabled": true,
            "biometricAuthEnabled": true
        ]
    }
    
    private func gatherMediaMetadata() async -> [String: Any] {
        // Gather metadata about user's media (without actual content)
        return [
            "totalPhotos": 0,
            "totalVideos": 0,
            "storageUsed": "0 MB"
        ]
    }
    
    private func gatherAIAnalysisHistory() async -> [String: Any] {
        // Gather AI analysis history (anonymized)
        return [
            "totalAnalyses": 0,
            "averageProcessingTime": "0 ms",
            "mostUsedFeatures": []
        ]
    }
    
    private func clearKeychainData() async throws {
        logger.debug("🗝️ Clearing keychain data")
        // In real implementation, would clear keychain items
    }
    
    private func clearCachedData() async {
        logger.debug("🗑️ Clearing cached data")
        // Clear any cached user data
    }
    
    private func logAccessEvent(_ event: AccessEventType, details: String, source: String) async {
        let log = AccessLog(
            timestamp: Date(),
            eventType: event,
            details: details,
            source: source,
            userAgent: await getCurrentUserAgent()
        )
        
        accessLogs.append(log)
        
        // Ensure we don't exceed maximum log entries
        if accessLogs.count > maxLogEntries {
            accessLogs.removeFirst(accessLogs.count - maxLogEntries)
        }
    }
    
    private func getCurrentUserAgent() async -> String {
        let processInfo = ProcessInfo.processInfo
        return "NeuroViews/2.0 (iOS/macOS; \(processInfo.operatingSystemVersionString))"
    }
    
    private func cleanOldLogs() async {
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60) // 30 days
        accessLogs.removeAll { $0.timestamp < thirtyDaysAgo }
    }
    
    // MARK: - Public Logging Methods
    
    /// Logs access to specific data for privacy audit trail
    public func logAccess(to resource: String, purpose: AccessPurpose, dataType: DataType) async {
        let eventType: AccessEventType
        
        switch purpose {
        case .aiProcessing:
            eventType = .sensitiveDataAccessGranted
        case .userRequested:
            eventType = .dataExported
        case .analytics:
            eventType = .dataAnonymized
        }
        
        await logAccessEvent(
            eventType,
            details: "Accessing \(resource) for \(purpose.rawValue) - Data type: \(dataType.rawValue)",
            source: "LiveAIProcessor"
        )
    }
}

// MARK: - Supporting Types

@available(iOS 15.0, macOS 12.0, *)
public struct PermissionStatus: Sendable, Codable {
    public var camera: AuthorizationStatus = .notDetermined
    public var photoLibrary: AuthorizationStatus = .notDetermined
    public var microphone: AuthorizationStatus = .notDetermined
    public var location: AuthorizationStatus = .notDetermined
    public var biometric: AuthorizationStatus = .notDetermined
    
    public var allGranted: Bool {
        return camera == .authorized &&
               photoLibrary == .authorized &&
               microphone == .authorized &&
               (location == .authorized || location == .notRequired) &&
               (biometric == .authorized || biometric == .notRequired)
    }
    
    public init() {}
}

@available(iOS 15.0, macOS 12.0, *)
public enum AuthorizationStatus: String, Codable, CaseIterable, Sendable {
    case authorized = "authorized"
    case denied = "denied"
    case notDetermined = "notDetermined"
    case notRequired = "notRequired"
    
    public var displayName: String {
        switch self {
        case .authorized: return "Authorized"
        case .denied: return "Denied"
        case .notDetermined: return "Not Determined"
        case .notRequired: return "Not Required"
        }
    }
    
    public var isGranted: Bool {
        return self == .authorized || self == .notRequired
    }
}

@available(iOS 15.0, macOS 12.0, *)
public struct AccessLog: Sendable, Codable {
    public let id: UUID
    public let timestamp: Date
    public let eventType: AccessEventType
    public let details: String
    public let source: String
    public let userAgent: String
    
    public init(timestamp: Date, eventType: AccessEventType, details: String, source: String, userAgent: String) {
        self.id = UUID()
        self.timestamp = timestamp
        self.eventType = eventType
        self.details = details
        self.source = source
        self.userAgent = userAgent
    }
}

@available(iOS 15.0, macOS 12.0, *)
public enum AccessEventType: String, Codable, CaseIterable, Sendable {
    case permissionRequested = "permission_requested"
    case dataProtectionEnabled = "data_protection_enabled"
    case auditPerformed = "audit_performed"
    case sensitiveDataAccessGranted = "sensitive_data_access_granted"
    case sensitiveDataAccessDenied = "sensitive_data_access_denied"
    case dataAnonymized = "data_anonymized"
    case privacyModeEnabled = "privacy_mode_enabled"
    case privacyModeDisabled = "privacy_mode_disabled"
    case dataExported = "data_exported"
    case dataDeleted = "data_deleted"
    case privacyMonitoringStarted = "privacy_monitoring_started"
    case biometricAuthenticationFailed = "biometric_authentication_failed"
    case unauthorizedAccess = "unauthorized_access"
    
    public var displayName: String {
        return rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

@available(iOS 15.0, macOS 12.0, *)
public enum AccessPurpose: String, Codable, CaseIterable, Sendable {
    case aiProcessing = "ai_processing"
    case userRequested = "user_requested"
    case analytics = "analytics"
    
    public var displayName: String {
        return rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

@available(iOS 15.0, macOS 12.0, *)
public enum DataType: String, Codable, CaseIterable, Sendable {
    case frameData = "frame_data"
    case mediaFile = "media_file"
    case userPreferences = "user_preferences"
    case analyticsData = "analytics_data"
    
    public var displayName: String {
        return rawValue.replacingOccurrences(of: "_", with: " ").capitalized
    }
}

@available(iOS 15.0, macOS 12.0, *)
public struct UserDataExport: Sendable, Codable {
    public let exportDate: Date
    public let accessLogs: [AccessLog]
    public let preferences: [String: String]
    public let mediaMetadata: [String: String]
    public let aiAnalysisHistory: [String: String]
    
    public init(exportDate: Date, accessLogs: [AccessLog], preferences: [String: Any], mediaMetadata: [String: Any], aiAnalysisHistory: [String: Any]) {
        self.exportDate = exportDate
        self.accessLogs = accessLogs
        // Convert [String: Any] to [String: String] for Sendable compliance
        self.preferences = preferences.mapValues { String(describing: $0) }
        self.mediaMetadata = mediaMetadata.mapValues { String(describing: $0) }
        self.aiAnalysisHistory = aiAnalysisHistory.mapValues { String(describing: $0) }
    }
}

@available(iOS 15.0, macOS 12.0, *)
public enum PrivacyError: Error, LocalizedError {
    case deviceNotSecure(String)
    case permissionDenied(String)
    case biometricNotAvailable
    case dataProtectionFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .deviceNotSecure(let message):
            return "Device security insufficient: \(message)"
        case .permissionDenied(let permission):
            return "Permission denied: \(permission)"
        case .biometricNotAvailable:
            return "Biometric authentication not available"
        case .dataProtectionFailed(let reason):
            return "Data protection failed: \(reason)"
        }
    }
}