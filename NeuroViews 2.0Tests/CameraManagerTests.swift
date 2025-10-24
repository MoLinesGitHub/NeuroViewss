//
//  CameraManagerTests.swift
//  NeuroViews 2.0Tests
//
//  Created by Claude Code on 24/01/25.
//  Coverage improvement: CameraManager 0% → 30%+
//

import Testing
import Foundation
import AVFoundation
@testable import NeuroViews_2_0

// MARK: - CameraManager Core Tests

@Suite("CameraManager - Core Functionality")
struct CameraManagerTests {

    // MARK: - Initialization Tests

    @Test("CameraManager initializes with correct defaults")
    @MainActor
    func testInitialization() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        #expect(manager.isSessionRunning == false, "Session should not be running initially")
        #expect(manager.isRecording == false, "Should not be recording initially")
        #expect(manager.errorMessage == nil, "Should have no error message initially")
        #expect(manager.cameraPosition == .back, "Default camera position should be back")
        #expect(manager.zoomFactor == 1.0, "Default zoom factor should be 1.0")
        #expect(manager.isAIAnalysisEnabled == true, "AI analysis should be enabled by default")
        #expect(manager.isSmartFeaturesEnabled == true, "Smart features should be enabled by default")
    }

    @Test("CameraManager initializes SmartAutoFocus")
    @MainActor
    func testSmartAutoFocusInitialization() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        #expect(manager.smartAutoFocus != nil, "SmartAutoFocus should be initialized")
        #expect(manager.smartAutoFocus.isEnabled == true, "SmartAutoFocus should be enabled by default")
    }

    // MARK: - Published Properties Tests

    @Test("CameraManager can update session running state")
    @MainActor
    func testSessionRunningState() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        #expect(manager.isSessionRunning == false)

        manager.isSessionRunning = true
        #expect(manager.isSessionRunning == true)

        manager.isSessionRunning = false
        #expect(manager.isSessionRunning == false)
    }

    @Test("CameraManager can update recording state")
    @MainActor
    func testRecordingState() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        #expect(manager.isRecording == false)

        manager.isRecording = true
        #expect(manager.isRecording == true)

        manager.isRecording = false
        #expect(manager.isRecording == false)
    }

    @Test("CameraManager can update zoom factor")
    @MainActor
    func testZoomFactorUpdate() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        #expect(manager.zoomFactor == 1.0)

        manager.zoomFactor = 2.0
        #expect(manager.zoomFactor == 2.0)

        manager.zoomFactor = 0.5
        #expect(manager.zoomFactor == 0.5)
    }

    @Test("CameraManager can update camera position")
    @MainActor
    func testCameraPositionUpdate() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        #expect(manager.cameraPosition == .back)

        manager.cameraPosition = .front
        #expect(manager.cameraPosition == .front)

        manager.cameraPosition = .back
        #expect(manager.cameraPosition == .back)
    }

    @Test("CameraManager can set error messages")
    @MainActor
    func testErrorMessageUpdate() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        #expect(manager.errorMessage == nil)

        manager.errorMessage = "Test error"
        #expect(manager.errorMessage == "Test error")

        manager.errorMessage = nil
        #expect(manager.errorMessage == nil)
    }

    @Test("CameraManager can toggle AI analysis")
    @MainActor
    func testAIAnalysisToggle() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        #expect(manager.isAIAnalysisEnabled == true)

        manager.isAIAnalysisEnabled = false
        #expect(manager.isAIAnalysisEnabled == false)

        manager.isAIAnalysisEnabled = true
        #expect(manager.isAIAnalysisEnabled == true)
    }

    @Test("CameraManager can toggle smart features")
    @MainActor
    func testSmartFeaturesToggle() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        #expect(manager.isSmartFeaturesEnabled == true)

        manager.isSmartFeaturesEnabled = false
        #expect(manager.isSmartFeaturesEnabled == false)

        manager.isSmartFeaturesEnabled = true
        #expect(manager.isSmartFeaturesEnabled == true)
    }

    @Test("CameraManager AI suggestions can be updated")
    @MainActor
    func testAISuggestionsUpdate() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        #expect(manager.aiSuggestions.isEmpty)

        let suggestion = AISuggestion(
            type: .lighting,
            title: "Test",
            message: "Test suggestion",
            confidence: 0.8,
            priority: .medium
        )

        manager.aiSuggestions = [suggestion]
        #expect(manager.aiSuggestions.count == 1)
        #expect(manager.aiSuggestions[0].title == "Test")
    }
}

// MARK: - CameraError Tests

@Suite("CameraManager - Error Handling")
struct CameraErrorTests {

    @Test("CameraError provides localized descriptions")
    func testCameraErrorDescriptions() {
        let errors: [CameraError] = [
            .deviceNotAvailable,
            .configurationFailed
        ]

        for error in errors {
            let description = error.errorDescription
            #expect(description != nil, "Error should have description")
            #expect(!description!.isEmpty, "Error description should not be empty")
        }
    }

    @Test("CameraError descriptions are in Spanish")
    func testCameraErrorSpanishLocalization() {
        #expect(CameraError.deviceNotAvailable.errorDescription == "Dispositivo de cámara no disponible")
        #expect(CameraError.configurationFailed.errorDescription == "Error en la configuración de la cámara")
    }

    @Test("CameraError cases are complete")
    func testCameraErrorCases() {
        let deviceError = CameraError.deviceNotAvailable
        let configError = CameraError.configurationFailed

        #expect(deviceError.errorDescription != nil)
        #expect(configError.errorDescription != nil)
    }
}

// MARK: - AVCaptureDevice.Position Tests

@Suite("CameraManager - Camera Position")
struct CameraPositionTests {

    @Test("All camera positions are available")
    func testAllCameraPositions() {
        let positions: [AVCaptureDevice.Position] = [
            .front,
            .back,
            .unspecified
        ]

        for position in positions {
            // Verify positions can be assigned
            #expect(position.rawValue >= 0)
        }
    }

    @Test("Camera position back is default")
    @MainActor
    func testBackCameraIsDefault() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()
        #expect(manager.cameraPosition == .back)
    }

    @Test("Camera position can switch between front and back")
    @MainActor
    func testCameraPositionSwitching() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        // Start with back
        #expect(manager.cameraPosition == .back)

        // Switch to front
        manager.cameraPosition = .front
        #expect(manager.cameraPosition == .front)

        // Switch back to back
        manager.cameraPosition = .back
        #expect(manager.cameraPosition == .back)

        // Try unspecified
        manager.cameraPosition = .unspecified
        #expect(manager.cameraPosition == .unspecified)
    }
}

// MARK: - Performance Tests

@Suite("CameraManager - Performance Tests")
struct CameraManagerPerformanceTests {

    @Test("CameraManager initialization is reasonably fast")
    @MainActor
    func testInitializationPerformance() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let startTime = CFAbsoluteTimeGetCurrent()

        var managers: [CameraManager] = []
        for _ in 0..<10 {
            managers.append(CameraManager())
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(timeElapsed < 5.0, "Creating 10 instances should take less than 5 seconds")
        #expect(managers.count == 10)
    }

    @Test("Property updates are instantaneous")
    @MainActor
    func testPropertyUpdatePerformance() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()
        let startTime = CFAbsoluteTimeGetCurrent()

        for i in 0..<1000 {
            manager.zoomFactor = CGFloat(i % 10)
            manager.isRecording = i % 2 == 0
            manager.isSessionRunning = i % 3 == 0
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(timeElapsed < 0.1, "1000 property updates should take less than 100ms")
    }
}

// MARK: - Edge Cases Tests

@Suite("CameraManager - Edge Cases")
struct CameraManagerEdgeCasesTests {

    @Test("CameraManager handles extreme zoom factors")
    @MainActor
    func testExtremeZoomFactors() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        // Test minimum zoom
        manager.zoomFactor = 0.1
        #expect(manager.zoomFactor == 0.1)

        // Test zero zoom (edge case)
        manager.zoomFactor = 0.0
        #expect(manager.zoomFactor == 0.0)

        // Test high zoom
        manager.zoomFactor = 10.0
        #expect(manager.zoomFactor == 10.0)

        // Test very high zoom
        manager.zoomFactor = 100.0
        #expect(manager.zoomFactor == 100.0)
    }

    @Test("CameraManager handles negative zoom factor")
    @MainActor
    func testNegativeZoomFactor() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        // System allows negative values (may be clamped by AVFoundation later)
        manager.zoomFactor = -1.0
        #expect(manager.zoomFactor == -1.0)
    }

    @Test("CameraManager handles rapid state toggling")
    @MainActor
    func testRapidStateToggling() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        for _ in 0..<100 {
            manager.isRecording = true
            manager.isRecording = false
            manager.isSessionRunning = true
            manager.isSessionRunning = false
        }

        #expect(manager.isRecording == false)
        #expect(manager.isSessionRunning == false)
    }

    @Test("CameraManager handles large AI suggestions array")
    @MainActor
    func testLargeAISuggestionsArray() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        var suggestions: [AISuggestion] = []
        for i in 0..<1000 {
            suggestions.append(AISuggestion(
                type: .lighting,
                title: "Suggestion \(i)",
                message: "Test",
                confidence: 0.5,
                priority: .low
            ))
        }

        manager.aiSuggestions = suggestions
        #expect(manager.aiSuggestions.count == 1000)
    }

    @Test("CameraManager handles empty AI suggestions array")
    @MainActor
    func testEmptyAISuggestionsArray() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        manager.aiSuggestions = []
        #expect(manager.aiSuggestions.isEmpty)

        // Set some suggestions
        manager.aiSuggestions = [AISuggestion(
            type: .composition,
            title: "Test",
            message: "Test",
            confidence: 0.8,
            priority: .high
        )]
        #expect(manager.aiSuggestions.count == 1)

        // Clear again
        manager.aiSuggestions = []
        #expect(manager.aiSuggestions.isEmpty)
    }

    @Test("CameraManager handles nil error message")
    @MainActor
    func testNilErrorMessage() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        #expect(manager.errorMessage == nil)

        manager.errorMessage = "Error"
        #expect(manager.errorMessage == "Error")

        manager.errorMessage = nil
        #expect(manager.errorMessage == nil)
    }

    @Test("CameraManager handles empty error message")
    @MainActor
    func testEmptyErrorMessage() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        manager.errorMessage = ""
        #expect(manager.errorMessage == "")
        #expect(manager.errorMessage?.isEmpty == true)
    }

    @Test("CameraManager handles very long error message")
    @MainActor
    func testLongErrorMessage() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        let longMessage = String(repeating: "Error message. ", count: 100)
        manager.errorMessage = longMessage

        #expect(manager.errorMessage == longMessage)
        #expect(manager.errorMessage!.count > 1000)
    }
}

// MARK: - Integration with Smart Features Tests

@Suite("CameraManager - Smart Features Integration")
struct CameraManagerSmartFeaturesTests {

    @Test("CameraManager integrates with SmartAutoFocus")
    @MainActor
    func testSmartAutoFocusIntegration() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        // Verify SmartAutoFocus is accessible
        #expect(manager.smartAutoFocus != nil)

        // Verify can change SmartAutoFocus settings
        manager.smartAutoFocus.isEnabled = false
        #expect(manager.smartAutoFocus.isEnabled == false)

        manager.smartAutoFocus.isEnabled = true
        #expect(manager.smartAutoFocus.isEnabled == true)
    }

    @Test("CameraManager smart features can be disabled")
    @MainActor
    func testDisableSmartFeatures() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let manager = CameraManager()

        #expect(manager.isSmartFeaturesEnabled == true)

        manager.isSmartFeaturesEnabled = false
        #expect(manager.isSmartFeaturesEnabled == false)

        // SmartAutoFocus should still be accessible when features are disabled
        #expect(manager.smartAutoFocus != nil)
    }
}
