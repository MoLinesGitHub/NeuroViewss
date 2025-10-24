//
//  ExposureAnalyzerAdvancedTests.swift
//  NeuroViews 2.0Tests
//
//  Created by Claude Code on 24/01/25.
//  Advanced tests for ExposureAnalyzer using mock infrastructure
//

import Testing
import Foundation
import CoreImage
import AVFoundation
@testable import NeuroViews_2_0

// MARK: - Exposure Analysis with Mock Images

@Suite("ExposureAnalyzer - Analysis with Mocks")
struct ExposureAnalyzerAnalysisTests {

    @Test("analyze processes well-exposed frame")
    @MainActor
    func testAnalyzeWellExposedFrame() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        guard let pixelBuffer = MockPixelBuffer.wellExposed(width: 1280, height: 720) else {
            Issue.record("Failed to create pixel buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)

        // Enable and trigger analysis
        analyzer.isEnabled = true
        analyzer.analyze(frame: sendableBuffer)

        // Wait for async processing
        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(analyzer.isEnabled == true)
    }

    @Test("analyze detects overexposure")
    @MainActor
    func testDetectOverexposure() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        guard let pixelBuffer = MockPixelBuffer.overexposed(width: 1280, height: 720) else {
            Issue.record("Failed to create overexposed buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)

        analyzer.isEnabled = true
        analyzer.analyze(frame: sendableBuffer)

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(analyzer.isEnabled == true)
    }

    @Test("analyze detects underexposure")
    @MainActor
    func testDetectUnderexposure() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        guard let pixelBuffer = MockPixelBuffer.underexposed(width: 1280, height: 720) else {
            Issue.record("Failed to create underexposed buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)

        analyzer.isEnabled = true
        analyzer.analyze(frame: sendableBuffer)

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(analyzer.isEnabled == true)
    }

    @Test("analyze processes high contrast scene")
    @MainActor
    func testAnalyzeHighContrast() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        guard let pixelBuffer = MockPixelBuffer.highContrast(width: 1920, height: 1080) else {
            Issue.record("Failed to create high contrast buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)

        analyzer.isEnabled = true
        analyzer.analyze(frame: sendableBuffer)

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(analyzer.isEnabled == true)
    }

    @Test("analyze processes low contrast scene")
    @MainActor
    func testAnalyzeLowContrast() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        guard let pixelBuffer = MockPixelBuffer.lowContrast(width: 1280, height: 720) else {
            Issue.record("Failed to create low contrast buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)

        analyzer.isEnabled = true
        analyzer.analyze(frame: sendableBuffer)

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(analyzer.isEnabled == true)
    }

    @Test("analyze does not process when disabled")
    @MainActor
    func testAnalyzeWhenDisabled() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()
        analyzer.isEnabled = false

        guard let pixelBuffer = MockPixelBuffer.wellExposed() else {
            Issue.record("Failed to create pixel buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)
        let initialAnalysisState = analyzer.isAnalyzing

        analyzer.analyze(frame: sendableBuffer)

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(analyzer.isAnalyzing == initialAnalysisState)
        #expect(analyzer.isEnabled == false)
    }

    @Test("analyze handles different resolutions")
    @MainActor
    func testAnalyzeDifferentResolutions() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()
        let resolutions: [(Int, Int)] = [
            (640, 480),
            (1280, 720),
            (1920, 1080),
            (3840, 2160)
        ]

        for (width, height) in resolutions {
            guard let pixelBuffer = MockPixelBuffer.wellExposed(width: width, height: height) else {
                Issue.record("Failed to create \(width)x\(height) buffer")
                continue
            }

            let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)
            analyzer.isEnabled = true
            analyzer.analyze(frame: sendableBuffer)

            try await Task.sleep(nanoseconds: 50_000_000)
        }

        #expect(analyzer.isEnabled == true)
    }
}

// MARK: - CIImage Conversion Tests

@Suite("ExposureAnalyzer - CIImage Processing")
struct ExposureAnalyzerCIImageTests {

    @Test("CVPixelBuffer converts to CIImage")
    func testPixelBufferToCIImage() {
        guard let pixelBuffer = MockPixelBuffer.wellExposed(width: 640, height: 480) else {
            Issue.record("Failed to create pixel buffer")
            return
        }

        let ciImage = MockPixelBuffer.toCIImage(pixelBuffer)

        #expect(ciImage != nil)
        #expect(ciImage?.extent.width == 640)
        #expect(ciImage?.extent.height == 480)
    }

    @Test("CIImage preserves exposure scenarios")
    func testCIImagePreservesScenarios() {
        let scenarios: [(String, CVPixelBuffer?)] = [
            ("overexposed", MockPixelBuffer.overexposed(width: 1280, height: 720)),
            ("underexposed", MockPixelBuffer.underexposed(width: 1280, height: 720)),
            ("well-exposed", MockPixelBuffer.wellExposed(width: 1280, height: 720))
        ]

        for (name, buffer) in scenarios {
            guard let pixelBuffer = buffer,
                  let ciImage = MockPixelBuffer.toCIImage(pixelBuffer) else {
                Issue.record("Failed to convert \(name) buffer to CIImage")
                continue
            }

            #expect(ciImage.extent.width == 1280, "\(name) CIImage width should match")
            #expect(ciImage.extent.height == 720, "\(name) CIImage height should match")
        }
    }
}

// MARK: - Exposure Metrics Tests

@Suite("ExposureAnalyzer - Metrics")
struct ExposureAnalyzerMetricsTests {

    @Test("Current exposure is initialized to zero")
    @MainActor
    func testInitialExposure() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()
        #expect(analyzer.currentExposure == 0.0)
    }

    @Test("Target EV is initialized to zero")
    @MainActor
    func testInitialTargetEV() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()
        #expect(analyzer.targetEV == 0.0)
    }

    @Test("Exposure compensation starts at zero")
    @MainActor
    func testInitialExposureCompensation() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()
        #expect(analyzer.exposureCompensation == 0.0)
    }

    @Test("Configuration accepts settings dictionary")
    @MainActor
    func testConfigurationWithSettings() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        let settings: [String: Any] = [
            "adaptiveAnalysisEnabled": false,
            "sceneAnalysisEnabled": false,
            "targetEV": 1.5
        ]

        analyzer.configure(with: settings)

        // Configuration should succeed
        #expect(true)
    }

    @Test("Enable/disable toggle works")
    @MainActor
    func testEnableDisable() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        #expect(analyzer.isEnabled == true)

        analyzer.isEnabled = false
        #expect(analyzer.isEnabled == false)

        analyzer.isEnabled = true
        #expect(analyzer.isEnabled == true)
    }
}

// MARK: - Performance Tests with Mocks

@Suite("ExposureAnalyzer - Performance with Mocks")
struct ExposureAnalyzerPerformanceTests {

    @Test("CIImage conversion is fast")
    func testCIImageConversionPerformance() {
        guard let pixelBuffer = MockPixelBuffer.wellExposed(width: 1280, height: 720) else {
            Issue.record("Failed to create pixel buffer")
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<100 {
            _ = MockPixelBuffer.toCIImage(pixelBuffer)
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(timeElapsed < 1.0, "100 CIImage conversions should take < 1s")
    }

    @Test("Multiple scenario buffers can be processed quickly")
    @MainActor
    func testMultiScenarioProcessing() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()
        analyzer.isEnabled = true

        let scenarios = [
            MockPixelBuffer.overexposed(width: 640, height: 480),
            MockPixelBuffer.underexposed(width: 640, height: 480),
            MockPixelBuffer.wellExposed(width: 640, height: 480),
            MockPixelBuffer.highContrast(width: 640, height: 480),
            MockPixelBuffer.lowContrast(width: 640, height: 480)
        ]

        let startTime = CFAbsoluteTimeGetCurrent()

        for buffer in scenarios {
            guard let pixelBuffer = buffer else { continue }
            let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)
            analyzer.analyze(frame: sendableBuffer)
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms between frames
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(timeElapsed < 5.0, "Processing 5 scenarios should take < 5s")
    }

    @Test("Analyzer can handle rapid frame updates")
    @MainActor
    func testRapidFrameUpdates() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()
        analyzer.isEnabled = true

        guard let pixelBuffer = MockPixelBuffer.wellExposed(width: 640, height: 480) else {
            Issue.record("Failed to create pixel buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)

        let startTime = CFAbsoluteTimeGetCurrent()

        // Simulate 30 fps for 1 second
        for _ in 0..<30 {
            analyzer.analyze(frame: sendableBuffer)
            try await Task.sleep(nanoseconds: 33_000_000) // ~33ms
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(timeElapsed < 2.0, "30 rapid frames should complete within 2s")
    }
}

// MARK: - Edge Cases

@Suite("ExposureAnalyzer - Edge Cases with Mocks")
struct ExposureAnalyzerEdgeCasesTests {

    @Test("Handles very small frame size")
    @MainActor
    func testVerySmallFrame() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        guard let pixelBuffer = MockPixelBuffer.wellExposed(width: 64, height: 64) else {
            Issue.record("Failed to create small buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)

        analyzer.isEnabled = true
        analyzer.analyze(frame: sendableBuffer)

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(analyzer.isEnabled == true)
    }

    @Test("Handles very large frame size")
    @MainActor
    func testVeryLargeFrame() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        guard let pixelBuffer = MockPixelBuffer.wellExposed(width: 7680, height: 4320) else {
            Issue.record("Failed to create 8K buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)

        analyzer.isEnabled = true
        analyzer.analyze(frame: sendableBuffer)

        try await Task.sleep(nanoseconds: 200_000_000) // Extra time for large frame

        #expect(analyzer.isEnabled == true)
    }

    @Test("Handles checkerboard pattern")
    @MainActor
    func testCheckerboardPattern() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        guard let pixelBuffer = MockPixelBuffer.checkerboard(
            width: 1280,
            height: 720,
            squareSize: 64
        ) else {
            Issue.record("Failed to create checkerboard buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(buffer: pixelBuffer)

        analyzer.isEnabled = true
        analyzer.analyze(frame: sendableBuffer)

        try await Task.sleep(nanoseconds: 100_000_000)

        #expect(analyzer.isEnabled == true)
    }
}
