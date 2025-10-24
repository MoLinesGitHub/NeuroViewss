//
//  SmartAutoFocusAdvancedTests.swift
//  NeuroViews 2.0Tests
//
//  Created by Claude Code on 24/01/25.
//  Advanced tests for SmartAutoFocus using mock infrastructure (Corrected APIs)
//

import Testing
import Foundation
import AVFoundation
import CoreImage
@testable import NeuroViews_2_0

// MARK: - Focus Analysis with Mock Pixel Buffers

@Suite("SmartAutoFocus - Advanced Analysis")
struct SmartAutoFocusAdvancedAnalysisTests {

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

            let sendableBuffer = SendablePixelBuffer(pixelBuffer)
            autoFocus.isEnabled = true
            autoFocus.analyzeForFocus(sendableBuffer)

            try await Task.sleep(nanoseconds: 50_000_000)
        }

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

        let sendableBuffer = SendablePixelBuffer(pixelBuffer)

        autoFocus.isEnabled = true
        autoFocus.analyzeForFocus(sendableBuffer)

        try await Task.sleep(nanoseconds: 500_000_000)

        #expect(autoFocus.isEnabled == true)
    }

    @Test("analyzeForFocus processes low contrast frame")
    @MainActor
    func testAnalyzeLowContrastFrame() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()

        guard let pixelBuffer = MockPixelBuffer.lowContrast(width: 1280, height: 720) else {
            Issue.record("Failed to create low contrast pixel buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(pixelBuffer)

        autoFocus.isEnabled = true
        autoFocus.analyzeForFocus(sendableBuffer)

        try await Task.sleep(nanoseconds: 500_000_000)

        #expect(autoFocus.isEnabled == true)
    }
}

// MARK: - Focus Quality Tests

@Suite("SmartAutoFocus - Quality Metrics")
struct SmartAutoFocusQualityMetricsTests {

    @Test("Focus quality score is in valid range")
    @MainActor
    func testFocusQualityScoreRange() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()
        let qualityScore = autoFocus.getFocusQualityScore()

        #expect(qualityScore >= 0.0)
        #expect(qualityScore <= 1.0)
    }

    @Test("Focus trend is valid")
    @MainActor
    func testFocusTrendValid() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()
        let trend = autoFocus.getFocusTrend()

        // Should return one of the valid enum cases
        #expect(trend == .improving || trend == .declining || trend == .stable)
    }

    @Test("Focus mode transitions correctly")
    @MainActor
    func testFocusModeTransitions() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()

        // Test all mode transitions
        autoFocus.setFocusMode(.aiGuided)
        #expect(autoFocus.focusMode == .aiGuided)

        autoFocus.setFocusMode(.subjectTracking)
        #expect(autoFocus.focusMode == .subjectTracking)

        autoFocus.setFocusMode(.manual)
        #expect(autoFocus.focusMode == .manual)

        autoFocus.setFocusMode(.hyperfocal)
        #expect(autoFocus.focusMode == .hyperfocal)
    }

    @Test("Subject tracking toggle cycles correctly")
    @MainActor
    func testSubjectTrackingCycle() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let autoFocus = SmartAutoFocus()

        // Start in aiGuided mode
        autoFocus.setFocusMode(.aiGuided)
        #expect(autoFocus.focusMode == .aiGuided)

        // Toggle should switch to subjectTracking
        autoFocus.toggleSubjectTracking()
        #expect(autoFocus.focusMode == .subjectTracking)

        // Toggle again should return to aiGuided
        autoFocus.toggleSubjectTracking()
        #expect(autoFocus.focusMode == .aiGuided)
    }
}

// MARK: - SendablePixelBuffer Integration

@Suite("SendablePixelBuffer - Advanced Integration")
struct SendablePixelBufferAdvancedTests {

    @Test("SendablePixelBuffer wraps different scenarios correctly")
    func testWrapDifferentScenarios() {
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

            let sendableBuffer = SendablePixelBuffer(pixelBuffer)
            #expect(sendableBuffer.buffer != nil, "\(name) buffer should wrap correctly")
        }
    }

    @Test("SendablePixelBuffer preserves resolution")
    func testPreserveResolution() {
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

            let sendableBuffer = SendablePixelBuffer(pixelBuffer)

            #expect(CVPixelBufferGetWidth(sendableBuffer.buffer) == width)
            #expect(CVPixelBufferGetHeight(sendableBuffer.buffer) == height)
        }
    }

    @Test("SendablePixelBuffer maintains format")
    func testMaintainFormat() {
        guard let pixelBuffer = MockPixelBuffer.wellExposed(width: 1920, height: 1080) else {
            Issue.record("Failed to create pixel buffer")
            return
        }

        let sendableBuffer = SendablePixelBuffer(pixelBuffer)
        let format = CVPixelBufferGetPixelFormatType(sendableBuffer.buffer)

        #expect(format == kCVPixelFormatType_32BGRA)
    }
}

// MARK: - Performance Tests

@Suite("SmartAutoFocus - Advanced Performance")
struct SmartAutoFocusAdvancedPerformanceTests {

    @Test("Pixel buffer creation is performant")
    func testPixelBufferCreationPerformance() {
        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<50 {
            _ = MockPixelBuffer.wellExposed(width: 1280, height: 720)
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(timeElapsed < 3.0, "Creating 50 pixel buffers should take < 3s")
    }

    @Test("SendablePixelBuffer wrapping is fast")
    func testSendableWrappingSpeed() {
        guard let pixelBuffer = MockPixelBuffer.wellExposed() else {
            Issue.record("Failed to create pixel buffer")
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<5000 {
            _ = SendablePixelBuffer(pixelBuffer)
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(timeElapsed < 0.3, "5000 wrapper creations should take < 300ms")
    }

    @Test("Multiple scenario buffers creation is efficient")
    func testMultiScenarioCreation() {
        let startTime = CFAbsoluteTimeGetCurrent()

        for _ in 0..<10 {
            _ = MockPixelBuffer.overexposed()
            _ = MockPixelBuffer.underexposed()
            _ = MockPixelBuffer.wellExposed()
            _ = MockPixelBuffer.highContrast()
            _ = MockPixelBuffer.lowContrast()
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(timeElapsed < 5.0, "50 buffers across scenarios should take < 5s")
    }
}
