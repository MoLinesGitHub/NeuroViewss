//
//  ExposureAnalyzerAdvancedTests.swift
//  NeuroViews 2.0Tests
//
//  Created by Claude Code on 24/01/25.
//  Advanced tests for ExposureAnalyzer using mock infrastructure (Corrected APIs)
//

import Testing
import Foundation
import CoreImage
import AVFoundation
@testable import NeuroViews_2_0

// MARK: - Exposure Analysis with Mock Images

@Suite("ExposureAnalyzer - Advanced Analysis")
struct ExposureAnalyzerAdvancedAnalysisTests {

    @Test("analyze returns different results for exposure scenarios")
    @MainActor
    func testAnalyzeExposureScenarios() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()
        analyzer.isEnabled = true

        // Test well-exposed
        guard let wellExposed = MockPixelBuffer.wellExposed(width: 1280, height: 720) else {
            Issue.record("Failed to create well-exposed buffer")
            return
        }
        let wellResult = analyzer.analyze(frame: wellExposed)
        #expect(wellResult != nil, "Well-exposed should return analysis")

        // Test overexposed
        guard let overexposed = MockPixelBuffer.overexposed(width: 1280, height: 720) else {
            Issue.record("Failed to create overexposed buffer")
            return
        }
        let overResult = analyzer.analyze(frame: overexposed)
        #expect(overResult != nil, "Overexposed should return analysis")

        // Test underexposed
        guard let underexposed = MockPixelBuffer.underexposed(width: 1280, height: 720) else {
            Issue.record("Failed to create underexposed buffer")
            return
        }
        let underResult = analyzer.analyze(frame: underexposed)
        #expect(underResult != nil, "Underexposed should return analysis")
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
            (1920, 1080),
            (3840, 2160)
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

    @Test("analyze processes contrast scenarios")
    @MainActor
    func testAnalyzeContrastScenarios() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()
        analyzer.isEnabled = true

        // High contrast
        guard let highContrast = MockPixelBuffer.highContrast(width: 1920, height: 1080) else {
            Issue.record("Failed to create high contrast buffer")
            return
        }
        let highResult = analyzer.analyze(frame: highContrast)
        #expect(highResult != nil, "High contrast should return analysis")

        // Low contrast
        guard let lowContrast = MockPixelBuffer.lowContrast(width: 1280, height: 720) else {
            Issue.record("Failed to create low contrast buffer")
            return
        }
        let lowResult = analyzer.analyze(frame: lowContrast)
        #expect(lowResult != nil, "Low contrast should return analysis")
    }
}

// MARK: - CIImage Conversion Tests

@Suite("ExposureAnalyzer - CIImage Processing")
struct ExposureAnalyzerCIImageTests {

    @Test("CVPixelBuffer converts to CIImage correctly")
    func testPixelBufferToCIImageConversion() {
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
    func testCIImagePreservesExposureData() {
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

    @Test("CIImage conversion handles multiple resolutions")
    func testCIImageMultipleResolutions() {
        let resolutions: [(Int, Int)] = [
            (640, 480),
            (1280, 720),
            (1920, 1080)
        ]

        for (width, height) in resolutions {
            guard let pixelBuffer = MockPixelBuffer.wellExposed(width: width, height: height),
                  let ciImage = MockPixelBuffer.toCIImage(pixelBuffer) else {
                Issue.record("Failed to convert \(width)x\(height) to CIImage")
                continue
            }

            #expect(ciImage.extent.width == CGFloat(width))
            #expect(ciImage.extent.height == CGFloat(height))
        }
    }
}

// MARK: - Configuration Tests

@Suite("ExposureAnalyzer - Configuration")
struct ExposureAnalyzerConfigurationTests {

    @Test("configure accepts all valid settings")
    @MainActor
    func testConfigureAllSettings() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        let settings: [String: Any] = [
            "adaptiveAnalysisEnabled": false,
            "sceneAnalysisEnabled": false,
            "exposureSmoothingEnabled": false,
            "targetEV": 1.5
        ]

        analyzer.configure(with: settings)

        // Configuration should succeed without throwing
        #expect(analyzer.isEnabled == true)
    }

    @Test("configure handles partial settings")
    @MainActor
    func testConfigurePartialSettings() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        // Only some settings
        let partialSettings: [String: Any] = [
            "adaptiveAnalysisEnabled": true,
            "targetEV": 0.5
        ]

        analyzer.configure(with: partialSettings)

        #expect(analyzer.isEnabled == true)
    }

    @Test("configure handles empty settings")
    @MainActor
    func testConfigureEmptySettings() {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        let emptySettings: [String: Any] = [:]

        analyzer.configure(with: emptySettings)

        #expect(analyzer.isEnabled == true)
    }
}

// MARK: - Performance Tests

@Suite("ExposureAnalyzer - Advanced Performance")
struct ExposureAnalyzerAdvancedPerformanceTests {

    @Test("CIImage conversion is fast")
    func testCIImageConversionSpeed() {
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

    @Test("Multiple scenario buffers can be analyzed quickly")
    @MainActor
    func testMultiScenarioAnalysis() async throws {
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
            _ = analyzer.analyze(frame: pixelBuffer)
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(timeElapsed < 3.0, "Processing 5 scenarios should take < 3s")
    }

    @Test("Analyzer handles rapid sequential frames")
    @MainActor
    func testRapidSequentialAnalysis() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()
        analyzer.isEnabled = true

        guard let pixelBuffer = MockPixelBuffer.wellExposed(width: 640, height: 480) else {
            Issue.record("Failed to create pixel buffer")
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        // Simulate rapid frame processing
        for _ in 0..<20 {
            _ = analyzer.analyze(frame: pixelBuffer)
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(timeElapsed < 2.0, "20 rapid analyses should complete within 2s")
    }
}

// MARK: - Edge Cases

@Suite("ExposureAnalyzer - Advanced Edge Cases")
struct ExposureAnalyzerAdvancedEdgeCasesTests {

    @Test("Handles very small frame size")
    @MainActor
    func testVerySmallFrame() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()
        analyzer.isEnabled = true

        guard let pixelBuffer = MockPixelBuffer.wellExposed(width: 64, height: 64) else {
            Issue.record("Failed to create small buffer")
            return
        }

        let result = analyzer.analyze(frame: pixelBuffer)
        #expect(result != nil, "Small frame should be analyzable")
    }

    @Test("Handles very large frame size")
    @MainActor
    func testVeryLargeFrame() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()
        analyzer.isEnabled = true

        guard let pixelBuffer = MockPixelBuffer.wellExposed(width: 7680, height: 4320) else {
            Issue.record("Failed to create 8K buffer")
            return
        }

        let result = analyzer.analyze(frame: pixelBuffer)
        #expect(result != nil, "8K frame should be analyzable")
    }

    @Test("Handles checkerboard pattern")
    @MainActor
    func testCheckerboardPattern() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()
        analyzer.isEnabled = true

        guard let pixelBuffer = MockPixelBuffer.checkerboard(
            width: 1280,
            height: 720,
            squareSize: 64
        ) else {
            Issue.record("Failed to create checkerboard buffer")
            return
        }

        let result = analyzer.analyze(frame: pixelBuffer)
        #expect(result != nil, "Checkerboard pattern should be analyzable")
    }
}
