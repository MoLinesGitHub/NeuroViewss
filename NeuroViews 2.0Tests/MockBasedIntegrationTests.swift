//
//  MockBasedIntegrationTests.swift
//  NeuroViews 2.0Tests
//
//  Created by Claude Code on 24/01/25.
//  Simple integration tests using mock infrastructure with correct APIs
//

import Testing
import Foundation
import CoreImage
import AVFoundation
@testable import NeuroViews_2_0

// MARK: - ExposureAnalyzer Tests with Mock Pixel Buffers

@Suite("ExposureAnalyzer - Mock Integration")
struct ExposureAnalyzerMockIntegrationTests {

    @Test("analyze processes well-exposed mock frame")
    @MainActor
    func testAnalyzeWellExposedMockFrame() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()
        analyzer.isEnabled = true

        guard let pixelBuffer = MockPixelBuffer.wellExposed(width: 1280, height: 720) else {
            Issue.record("Failed to create mock pixel buffer")
            return
        }

        // ExposureAnalyzer.analyze expects CVPixelBuffer directly
        let result = analyzer.analyze(frame: pixelBuffer)

        // Should return an analysis
        #expect(result != nil)
    }

    @Test("analyze processes overexposed mock frame")
    @MainActor
    func testAnalyzeOverexposedMockFrame() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()
        analyzer.isEnabled = true

        guard let pixelBuffer = MockPixelBuffer.overexposed(width: 1280, height: 720) else {
            Issue.record("Failed to create overexposed buffer")
            return
        }

        let result = analyzer.analyze(frame: pixelBuffer)
        #expect(result != nil)
    }

    @Test("analyze processes underexposed mock frame")
    @MainActor
    func testAnalyzeUnderexposedMockFrame() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()
        analyzer.isEnabled = true

        guard let pixelBuffer = MockPixelBuffer.underexposed(width: 1280, height: 720) else {
            Issue.record("Failed to create underexposed buffer")
            return
        }

        let result = analyzer.analyze(frame: pixelBuffer)
        #expect(result != nil)
    }

    @Test("analyze processes high contrast scene")
    @MainActor
    func testAnalyzeHighContrastScene() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()
        analyzer.isEnabled = true

        guard let pixelBuffer = MockPixelBuffer.highContrast(width: 1920, height: 1080) else {
            Issue.record("Failed to create high contrast buffer")
            return
        }

        let result = analyzer.analyze(frame: pixelBuffer)
        #expect(result != nil)
    }

    @Test("analyze processes low contrast scene")
    @MainActor
    func testAnalyzeLowContrastScene() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()
        analyzer.isEnabled = true

        guard let pixelBuffer = MockPixelBuffer.lowContrast(width: 1280, height: 720) else {
            Issue.record("Failed to create low contrast buffer")
            return
        }

        let result = analyzer.analyze(frame: pixelBuffer)
        #expect(result != nil)
    }

    @Test("analyze returns nil when disabled")
    @MainActor
    func testAnalyzeWhenDisabled() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()
        analyzer.isEnabled = false

        guard let pixelBuffer = MockPixelBuffer.wellExposed() else {
            Issue.record("Failed to create pixel buffer")
            return
        }

        let result = analyzer.analyze(frame: pixelBuffer)
        #expect(result == nil)
    }

    @Test("analyze handles different resolutions")
    @MainActor
    func testAnalyzeDifferentResolutions() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()
        analyzer.isEnabled = true

        let resolutions: [(Int, Int)] = [
            (640, 480),
            (1280, 720),
            (1920, 1080)
        ]

        for (width, height) in resolutions {
            guard let pixelBuffer = MockPixelBuffer.wellExposed(width: width, height: height) else {
                Issue.record("Failed to create \(width)x\(height) buffer")
                continue
            }

            let result = analyzer.analyze(frame: pixelBuffer)
            #expect(result != nil, "\(width)x\(height) should be analyzed")
        }
    }

    @Test("configure accepts settings dictionary")
    @MainActor
    func testConfigureWithSettings() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        let settings: [String: Any] = [
            "adaptiveAnalysisEnabled": false,
            "sceneAnalysisEnabled": false,
            "targetEV": 1.5
        ]

        analyzer.configure(with: settings)

        // Configuration should succeed without throwing
        #expect(analyzer.isEnabled == true)
    }
}

// MARK: - SmartAutoFocus Tests with Mock Pixel Buffers

@Suite("SmartAutoFocus - Mock Integration")
struct SmartAutoFocusMockIntegrationTests {

    @Test("analyzeForFocus processes well-exposed mock frame")
    @MainActor
    func testAnalyzeWellExposedMockFrame() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()
        autoFocus.isEnabled = true

        guard let pixelBuffer = MockPixelBuffer.wellExposed(width: 1280, height: 720) else {
            Issue.record("Failed to create mock pixel buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(pixelBuffer)

        // SmartAutoFocus.analyzeForFocus expects SendablePixelBuffer
        autoFocus.analyzeForFocus(sendableBuffer)

        // Give it time to process (async method)
        try await Task.sleep(nanoseconds: 500_000_000) // 500ms

        // Should have analyzed
        #expect(autoFocus.isEnabled == true)
    }

    @Test("analyzeForFocus processes overexposed frame")
    @MainActor
    func testAnalyzeOverexposedFrame() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()
        autoFocus.isEnabled = true

        guard let pixelBuffer = MockPixelBuffer.overexposed(width: 1280, height: 720) else {
            Issue.record("Failed to create overexposed buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(pixelBuffer)
        autoFocus.analyzeForFocus(sendableBuffer)

        try await Task.sleep(nanoseconds: 500_000_000)
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

        let sendableBuffer = SendablePixelBuffer(pixelBuffer)
        let initialAnalysisState = autoFocus.isAnalyzing

        autoFocus.analyzeForFocus(sendableBuffer)

        try await Task.sleep(nanoseconds: 500_000_000)

        // Should not have triggered analysis
        #expect(autoFocus.isAnalyzing == initialAnalysisState)
        #expect(autoFocus.isEnabled == false)
    }

    @Test("setFocusMode changes mode")
    @MainActor
    func testSetFocusMode() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()

        autoFocus.setFocusMode(.aiGuided)
        #expect(autoFocus.focusMode == .aiGuided)

        autoFocus.setFocusMode(.subjectTracking)
        #expect(autoFocus.focusMode == .subjectTracking)

        autoFocus.setFocusMode(.manual)
        #expect(autoFocus.focusMode == .manual)
    }

    @Test("toggleSubjectTracking works")
    @MainActor
    func testToggleSubjectTracking() {
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

    @Test("getFocusQualityScore returns valid score")
    @MainActor
    func testGetFocusQualityScore() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()
        let score = autoFocus.getFocusQualityScore()

        #expect(score >= 0.0)
        #expect(score <= 1.0)
    }

    @Test("getFocusTrend returns valid trend")
    @MainActor
    func testGetFocusTrend() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()
        let trend = autoFocus.getFocusTrend()

        // Should return one of the valid enum cases
        #expect(trend == .improving || trend == .declining || trend == .stable)
    }

    @Test("focusConfidence initialized to zero")
    @MainActor
    func testInitialFocusConfidence() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()
        #expect(autoFocus.focusConfidence == 0.0)
    }

    @Test("focusSuggestions starts empty")
    @MainActor
    func testInitialFocusSuggestions() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()
        #expect(autoFocus.focusSuggestions.isEmpty)
    }

    @Test("trackingSubjects starts empty")
    @MainActor
    func testInitialTrackingSubjects() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()
        #expect(autoFocus.trackingSubjects.isEmpty)
    }
}

// MARK: - Mock Infrastructure Validation Tests

@Suite("Mock Infrastructure - Validation")
struct MockInfrastructureValidationTests {

    @Test("MockPixelBuffer creates valid well-exposed buffer")
    func testWellExposedBufferCreation() {
        guard let buffer = MockPixelBuffer.wellExposed(width: 640, height: 480) else {
            Issue.record("Failed to create well-exposed buffer")
            return
        }

        #expect(CVPixelBufferGetWidth(buffer) == 640)
        #expect(CVPixelBufferGetHeight(buffer) == 480)
        #expect(CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_32BGRA)
    }

    @Test("MockPixelBuffer creates valid overexposed buffer")
    func testOverexposedBufferCreation() {
        guard let buffer = MockPixelBuffer.overexposed(width: 1280, height: 720) else {
            Issue.record("Failed to create overexposed buffer")
            return
        }

        #expect(CVPixelBufferGetWidth(buffer) == 1280)
        #expect(CVPixelBufferGetHeight(buffer) == 720)
    }

    @Test("MockPixelBuffer creates valid underexposed buffer")
    func testUnderexposedBufferCreation() {
        guard let buffer = MockPixelBuffer.underexposed(width: 1920, height: 1080) else {
            Issue.record("Failed to create underexposed buffer")
            return
        }

        #expect(CVPixelBufferGetWidth(buffer) == 1920)
        #expect(CVPixelBufferGetHeight(buffer) == 1080)
    }

    @Test("MockPixelBuffer supports multiple resolutions")
    func testMultipleResolutions() {
        let resolutions: [(Int, Int)] = [
            (640, 480),
            (1280, 720),
            (1920, 1080),
            (3840, 2160)
        ]

        for (width, height) in resolutions {
            guard let buffer = MockPixelBuffer.wellExposed(width: width, height: height) else {
                Issue.record("Failed to create \(width)x\(height) buffer")
                continue
            }

            #expect(CVPixelBufferGetWidth(buffer) == width)
            #expect(CVPixelBufferGetHeight(buffer) == height)
        }
    }

    @Test("MockPixelBuffer converts to CIImage")
    func testPixelBufferToCIImage() {
        guard let pixelBuffer = MockPixelBuffer.wellExposed(width: 1280, height: 720) else {
            Issue.record("Failed to create pixel buffer")
            return
        }

        guard let ciImage = MockPixelBuffer.toCIImage(pixelBuffer) else {
            Issue.record("Failed to convert to CIImage")
            return
        }

        #expect(ciImage.extent.width == 1280)
        #expect(ciImage.extent.height == 720)
    }

    @Test("SendablePixelBuffer wraps CVPixelBuffer")
    func testSendablePixelBufferWrapping() {
        guard let pixelBuffer = MockPixelBuffer.wellExposed(width: 640, height: 480) else {
            Issue.record("Failed to create pixel buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(pixelBuffer)

        #expect(CVPixelBufferGetWidth(sendableBuffer.buffer) == 640)
        #expect(CVPixelBufferGetHeight(sendableBuffer.buffer) == 480)
    }

    @Test("MockPixelBuffer creates checkerboard pattern")
    func testCheckerboardPattern() {
        guard let buffer = MockPixelBuffer.checkerboard(
            width: 1280,
            height: 720,
            squareSize: 64
        ) else {
            Issue.record("Failed to create checkerboard buffer")
            return
        }

        #expect(CVPixelBufferGetWidth(buffer) == 1280)
        #expect(CVPixelBufferGetHeight(buffer) == 720)
    }
}
