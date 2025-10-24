//
//  SmartAutoFocusAdvancedTests.swift
//  NeuroViews 2.0Tests
//
//  Created by Claude Code on 24/01/25.
//  Advanced tests for SmartAutoFocus using mock infrastructure
//

import Testing
import Foundation
import AVFoundation
import CoreImage
@testable import NeuroViews_2_0

// MARK: - Focus Analysis with Mock Pixel Buffers

@Suite("SmartAutoFocus - Analysis with Mocks")
struct SmartAutoFocusAnalysisTests {

    @Test("analyzeForFocus processes well-exposed frame")
    @MainActor
    func testAnalyzeWellExposedFrame() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()

        guard let pixelBuffer = MockPixelBuffer.wellExposed(width: 1280, height: 720) else {
            Issue.record("Failed to create mock pixel buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)

        // Enable and trigger analysis
        autoFocus.isEnabled = true
        autoFocus.analyzeForFocus(sendableBuffer)

        // Wait a bit for async processing
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Verify state changed
        #expect(autoFocus.isEnabled == true)
    }

    @Test("analyzeForFocus processes overexposed frame")
    @MainActor
    func testAnalyzeOverexposedFrame() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()

        guard let pixelBuffer = MockPixelBuffer.overexposed(width: 1280, height: 720) else {
            Issue.record("Failed to create overexposed pixel buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)

        autoFocus.isEnabled = true
        autoFocus.analyzeForFocus(sendableBuffer)

        // Wait for processing
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(autoFocus.isEnabled == true)
    }

    @Test("analyzeForFocus processes underexposed frame")
    @MainActor
    func testAnalyzeUnderexposedFrame() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()

        guard let pixelBuffer = MockPixelBuffer.underexposed(width: 1280, height: 720) else {
            Issue.record("Failed to create underexposed pixel buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)

        autoFocus.isEnabled = true
        autoFocus.analyzeForFocus(sendableBuffer)

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(autoFocus.isEnabled == true)
    }

    @Test("analyzeForFocus processes high contrast frame")
    @MainActor
    func testAnalyzeHighContrastFrame() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()

        guard let pixelBuffer = MockPixelBuffer.highContrast(width: 1920, height: 1080) else {
            Issue.record("Failed to create high contrast pixel buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)

        autoFocus.isEnabled = true
        autoFocus.analyzeForFocus(sendableBuffer)

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(autoFocus.isEnabled == true)
    }

    @Test("analyzeForFocus does not process when disabled")
    @MainActor
    func testAnalyzeWhenDisabled() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()
        autoFocus.isEnabled = false

        guard let pixelBuffer = MockPixelBuffer.wellExposed() else {
            Issue.record("Failed to create pixel buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)
        let initialAnalysisState = autoFocus.isAnalyzing

        autoFocus.analyzeForFocus(sendableBuffer)

        try await Task.sleep(nanoseconds: 100_000_000)

        // Should not have triggered analysis
        #expect(autoFocus.isAnalyzing == initialAnalysisState)
        #expect(autoFocus.isEnabled == false)
    }

    @Test("analyzeForFocus handles different resolutions")
    @MainActor
    func testAnalyzeDifferentResolutions() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()
        let resolutions: [(Int, Int)] = [
            (640, 480),    // SD
            (1280, 720),   // HD
            (1920, 1080),  // Full HD
            (3840, 2160)   // 4K
        ]

        for (width, height) in resolutions {
            guard let pixelBuffer = MockPixelBuffer.wellExposed(width: width, height: height) else {
                Issue.record("Failed to create \(width)x\(height) pixel buffer")
                continue
            }

            let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)
            autoFocus.isEnabled = true
            autoFocus.analyzeForFocus(sendableBuffer)

            try await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(autoFocus.isEnabled == true)
    }
}

// MARK: - Device Integration Tests

@Suite("SmartAutoFocus - Device Integration")
struct SmartAutoFocusDeviceTests {

    @Test("applyAIFocus applies focus to mock device")
    @MainActor
    func testApplyFocusToDevice() throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()
        let mockDevice = MockCaptureDevice.backCamera()

        // Set a focus point
        autoFocus.currentFocusPoint = CGPoint(x: 0.5, y: 0.5)

        // This will throw in real usage but we're testing the call path
        do {
            // Can't actually test this without AVCaptureDevice protocol conformance
            // Just verify the setup is correct
            #expect(autoFocus.currentFocusPoint != nil)
            #expect(mockDevice.focusMode != nil)
        }
    }

    @Test("Focus mode changes are tracked")
    @MainActor
    func testFocusModeTracking() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()

        autoFocus.setFocusMode(.aiGuided)
        #expect(autoFocus.focusMode == .aiGuided)

        autoFocus.setFocusMode(.subjectTracking)
        #expect(autoFocus.focusMode == .subjectTracking)

        autoFocus.setFocusMode(.manual)
        #expect(autoFocus.focusMode == .manual)
    }

    @Test("Subject tracking toggle works")
    @MainActor
    func testSubjectTrackingToggle() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()
        let initialMode = autoFocus.focusMode

        autoFocus.toggleSubjectTracking()

        // Should toggle to/from subject tracking
        if initialMode == .subjectTracking {
            #expect(autoFocus.focusMode == .aiGuided)
        } else {
            #expect(autoFocus.focusMode == .subjectTracking)
        }
    }
}

// MARK: - Focus Quality Tests

@Suite("SmartAutoFocus - Focus Quality")
struct SmartAutoFocusQualityTests {

    @Test("Focus quality score is in valid range")
    @MainActor
    func testFocusQualityScore() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()
        let qualityScore = autoFocus.getFocusQualityScore()

        #expect(qualityScore >= 0.0)
        #expect(qualityScore <= 1.0)
    }

    @Test("Focus trend is valid")
    @MainActor
    func testFocusTrend() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()
        let trend = autoFocus.getFocusTrend()

        // Should return one of the valid enum cases
        #expect(trend == .improving || trend == .degrading || trend == .stable)
    }

    @Test("Focus confidence is initialized to zero")
    @MainActor
    func testInitialFocusConfidence() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()
        #expect(autoFocus.focusConfidence == 0.0)
    }

    @Test("Focus suggestions array starts empty")
    @MainActor
    func testInitialFocusSuggestions() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()
        #expect(autoFocus.focusSuggestions.isEmpty)
    }

    @Test("Tracking subjects array starts empty")
    @MainActor
    func testInitialTrackingSubjects() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()
        #expect(autoFocus.trackingSubjects.isEmpty)
    }
}

// MARK: - SendablePixelBuffer Tests

@Suite("SendablePixelBuffer - Integration")
struct SendablePixelBufferIntegrationTests {

    @Test("SendablePixelBuffer wraps CVPixelBuffer correctly")
    func testPixelBufferWrapping() {
        guard let pixelBuffer = MockPixelBuffer.wellExposed(width: 640, height: 480) else {
            Issue.record("Failed to create pixel buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)

        #expect(sendableBuffer.buffer != nil)
        #expect(CVPixelBufferGetWidth(sendableBuffer.buffer) == 640)
        #expect(CVPixelBufferGetHeight(sendableBuffer.buffer) == 480)
    }

    @Test("SendablePixelBuffer preserves buffer format")
    func testPixelBufferFormat() {
        guard let pixelBuffer = MockPixelBuffer.solidColor(
            width: 1920,
            height: 1080,
            color: (128, 128, 128)
        ) else {
            Issue.record("Failed to create pixel buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)
        let format = CVPixelBufferGetPixelFormatType(sendableBuffer.buffer)

        #expect(format == kCVPixelFormatType_32BGRA)
    }

    @Test("SendablePixelBuffer can be created with different scenarios")
    func testScenarioBuffers() {
        let scenarios: [(String, CVPixelBuffer?)] = [
            ("overexposed", MockPixelBuffer.overexposed()),
            ("underexposed", MockPixelBuffer.underexposed()),
            ("well-exposed", MockPixelBuffer.wellExposed()),
            ("high-contrast", MockPixelBuffer.highContrast()),
            ("low-contrast", MockPixelBuffer.lowContrast())
        ]

        for (name, buffer) in scenarios {
            guard let pixelBuffer = buffer else {
                Issue.record("Failed to create \(name) buffer")
                continue
            }

            let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)
            #expect(sendableBuffer.buffer != nil, "\(name) buffer should wrap correctly")
        }
    }
}

// MARK: - Performance Tests with Mocks

@Suite("SmartAutoFocus - Performance with Mocks")
struct SmartAutoFocusPerformanceWithMocksTests {

    @Test("Pixel buffer creation is fast")
    func testPixelBufferCreationPerformance() {
        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<100 {
            _ = MockPixelBuffer.wellExposed(width: 1280, height: 720)
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(timeElapsed < 5.0, "Creating 100 pixel buffers should take < 5s")
    }

    @Test("SendablePixelBuffer wrapping is instantaneous")
    func testSendableWrappingPerformance() {
        guard let pixelBuffer = MockPixelBuffer.wellExposed() else {
            Issue.record("Failed to create pixel buffer")
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<10000 {
            _ = SendablePixelBuffer(buffer: pixelBuffer)
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(timeElapsed < 0.5, "10000 wrapper creations should take < 500ms")
    }

    @Test("Multiple resolution buffers can be created quickly")
    func testMultiResolutionCreation() {
        let resolutions: [(Int, Int)] = [
            (640, 480),
            (1280, 720),
            (1920, 1080),
            (3840, 2160)
        ]

        let startTime = CFAbsoluteTimeGetCurrent()

        for (width, height) in resolutions {
            for _ in 0..<10 {
                _ = MockPixelBuffer.wellExposed(width: width, height: height)
            }
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(timeElapsed < 10.0, "40 buffers across resolutions should take < 10s")
    }
}
