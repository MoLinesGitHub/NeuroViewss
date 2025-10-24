//
//  TestFixtures.swift
//  NeuroViews 2.0Tests
//
//  Created by Claude Code on 24/01/25.
//  Common test fixtures and helpers
//

import Foundation
import CoreGraphics
import AVFoundation

/// Common test fixtures and data
enum TestFixtures {

    // MARK: - Common Test Points

    /// Standard test points for focus/exposure testing
    enum TestPoints {
        static let center = CGPoint(x: 0.5, y: 0.5)
        static let topLeft = CGPoint(x: 0.1, y: 0.1)
        static let topRight = CGPoint(x: 0.9, y: 0.1)
        static let bottomLeft = CGPoint(x: 0.1, y: 0.9)
        static let bottomRight = CGPoint(x: 0.9, y: 0.9)

        static let ruleOfThirds: [CGPoint] = [
            CGPoint(x: 0.33, y: 0.33),
            CGPoint(x: 0.66, y: 0.33),
            CGPoint(x: 0.33, y: 0.66),
            CGPoint(x: 0.66, y: 0.66)
        ]

        static let golden: [CGPoint] = [
            CGPoint(x: 0.382, y: 0.382),
            CGPoint(x: 0.618, y: 0.382),
            CGPoint(x: 0.382, y: 0.618),
            CGPoint(x: 0.618, y: 0.618)
        ]
    }

    // MARK: - Common Test Rectangles

    /// Standard test rectangles for bounding box testing
    enum TestRects {
        static let centerSquare = CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)
        static let topHalf = CGRect(x: 0.0, y: 0.0, width: 1.0, height: 0.5)
        static let bottomHalf = CGRect(x: 0.0, y: 0.5, width: 1.0, height: 0.5)
        static let leftHalf = CGRect(x: 0.0, y: 0.0, width: 0.5, height: 1.0)
        static let rightHalf = CGRect(x: 0.5, y: 0.0, width: 0.5, height: 1.0)

        static let smallCentered = CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2)
        static let largeCentered = CGRect(x: 0.1, y: 0.1, width: 0.8, height: 0.8)

        /// Generates a random rect within bounds
        static func random(minSize: CGFloat = 0.1, maxSize: CGFloat = 0.4) -> CGRect {
            let width = CGFloat.random(in: minSize...maxSize)
            let height = CGFloat.random(in: minSize...maxSize)
            let x = CGFloat.random(in: 0...(1.0 - width))
            let y = CGFloat.random(in: 0...(1.0 - height))
            return CGRect(x: x, y: y, width: width, height: height)
        }
    }

    // MARK: - Common Test Colors

    /// Standard test colors (RGB 0-255)
    enum TestColors {
        static let white = (r: UInt8(255), g: UInt8(255), b: UInt8(255))
        static let black = (r: UInt8(0), g: UInt8(0), b: UInt8(0))
        static let gray = (r: UInt8(128), g: UInt8(128), b: UInt8(128))
        static let red = (r: UInt8(255), g: UInt8(0), b: UInt8(0))
        static let green = (r: UInt8(0), g: UInt8(255), b: UInt8(0))
        static let blue = (r: UInt8(0), g: UInt8(0), b: UInt8(255))
    }

    // MARK: - Common Test Settings

    /// Standard camera settings for testing
    enum CameraSettings {
        static let defaultISO: Float = 100.0
        static let lowISO: Float = 50.0
        static let highISO: Float = 800.0

        static let defaultExposureDuration = CMTime(value: 1, timescale: 30)
        static let fastExposureDuration = CMTime(value: 1, timescale: 120)
        static let slowExposureDuration = CMTime(value: 1, timescale: 15)

        static let defaultZoom: CGFloat = 1.0
        static let maxZoom: CGFloat = 10.0
        static let minZoom: CGFloat = 1.0
    }

    // MARK: - Test Data Generators

    /// Generates random test data
    enum RandomData {
        /// Generates random confidence value (0.0-1.0)
        static func confidence() -> Float {
            return Float.random(in: 0.0...1.0)
        }

        /// Generates random high confidence (0.7-1.0)
        static func highConfidence() -> Float {
            return Float.random(in: 0.7...1.0)
        }

        /// Generates random low confidence (0.0-0.5)
        static func lowConfidence() -> Float {
            return Float.random(in: 0.0...0.5)
        }

        /// Generates random point within normalized coordinates
        static func point() -> CGPoint {
            return CGPoint(
                x: CGFloat.random(in: 0.0...1.0),
                y: CGFloat.random(in: 0.0...1.0)
            )
        }

        /// Generates random EV value (-3 to +3)
        static func evValue() -> Float {
            return Float.random(in: -3.0...3.0)
        }

        /// Generates random brightness value (0-1)
        static func brightness() -> Float {
            return Float.random(in: 0.0...1.0)
        }
    }
}

// MARK: - Test Assertion Helpers

/// Helpers for common test assertions
enum TestAssertions {

    /// Checks if a point is within normalized bounds [0,1]
    static func isNormalizedPoint(_ point: CGPoint) -> Bool {
        return point.x >= 0 && point.x <= 1 && point.y >= 0 && point.y <= 1
    }

    /// Checks if a rect is within normalized bounds [0,1]
    static func isNormalizedRect(_ rect: CGRect) -> Bool {
        return rect.origin.x >= 0 && rect.origin.y >= 0 &&
               (rect.origin.x + rect.size.width) <= 1 &&
               (rect.origin.y + rect.size.height) <= 1
    }

    /// Checks if a value is within expected range
    static func isInRange<T: Comparable>(_ value: T, min: T, max: T) -> Bool {
        return value >= min && value <= max
    }

    /// Checks if confidence is valid (0-1)
    static func isValidConfidence(_ confidence: Float) -> Bool {
        return isInRange(confidence, min: 0.0, max: 1.0)
    }

    /// Checks if two CGFloats are approximately equal (for floating point comparison)
    static func approximatelyEqual(
        _ a: CGFloat,
        _ b: CGFloat,
        tolerance: CGFloat = 0.001
    ) -> Bool {
        return abs(a - b) < tolerance
    }

    /// Checks if two Floats are approximately equal
    static func approximatelyEqual(
        _ a: Float,
        _ b: Float,
        tolerance: Float = 0.001
    ) -> Bool {
        return abs(a - b) < tolerance
    }

    /// Checks if two CGPoints are approximately equal
    static func approximatelyEqual(
        _ a: CGPoint,
        _ b: CGPoint,
        tolerance: CGFloat = 0.001
    ) -> Bool {
        return approximatelyEqual(a.x, b.x, tolerance: tolerance) &&
               approximatelyEqual(a.y, b.y, tolerance: tolerance)
    }

    /// Checks if two CGRects are approximately equal
    static func approximatelyEqual(
        _ a: CGRect,
        _ b: CGRect,
        tolerance: CGFloat = 0.001
    ) -> Bool {
        return approximatelyEqual(a.origin, b.origin, tolerance: tolerance) &&
               approximatelyEqual(a.size.width, b.size.width, tolerance: tolerance) &&
               approximatelyEqual(a.size.height, b.size.height, tolerance: tolerance)
    }
}

// MARK: - Performance Test Helpers

/// Helpers for performance testing
enum PerformanceHelpers {

    /// Measures execution time of a block
    static func measure(block: () -> Void) -> TimeInterval {
        let start = CFAbsoluteTimeGetCurrent()
        block()
        let end = CFAbsoluteTimeGetCurrent()
        return end - start
    }

    /// Measures average execution time over multiple iterations
    static func measureAverage(iterations: Int, block: () -> Void) -> TimeInterval {
        var totalTime: TimeInterval = 0

        for _ in 0..<iterations {
            totalTime += measure(block: block)
        }

        return totalTime / Double(iterations)
    }

    /// Runs a block multiple times and returns all execution times
    static func profile(iterations: Int, block: () -> Void) -> [TimeInterval] {
        var times: [TimeInterval] = []

        for _ in 0..<iterations {
            times.append(measure(block: block))
        }

        return times
    }

    /// Returns statistics for a set of measurements
    static func statistics(for times: [TimeInterval]) -> (min: TimeInterval, max: TimeInterval, average: TimeInterval, median: TimeInterval) {
        let sorted = times.sorted()
        let min = sorted.first ?? 0
        let max = sorted.last ?? 0
        let average = times.reduce(0, +) / Double(times.count)
        let median = sorted[sorted.count / 2]

        return (min, max, average, median)
    }
}

// MARK: - Mock Data Builders

/// Builders for complex mock data
enum MockDataBuilders {

    /// Builds a complete mock camera state
    struct CameraState {
        var isRunning: Bool = false
        var isRecording: Bool = false
        var zoomFactor: CGFloat = 1.0
        var iso: Float = 100.0
        var exposureDuration: CMTime = CMTime(value: 1, timescale: 30)
        var focusMode: AVCaptureDevice.FocusMode = .continuousAutoFocus
        var exposureMode: AVCaptureDevice.ExposureMode = .continuousAutoExposure

        static var `default`: CameraState {
            return CameraState()
        }

        static var recording: CameraState {
            return CameraState(isRunning: true, isRecording: true)
        }

        static var manualExposure: CameraState {
            return CameraState(
                isRunning: true,
                iso: 200,
                exposureDuration: CMTime(value: 1, timescale: 60),
                exposureMode: .custom
            )
        }
    }

    /// Builds a complete analysis scenario
    struct AnalysisScenario {
        var pixelBuffer: CVPixelBuffer?
        var faces: [MockFaceObservation] = []
        var objects: [MockObjectObservation] = []
        var saliency: MockSaliencyObservation?

        static var portraitWithFace: AnalysisScenario {
            let buffer = MockPixelBuffer.wellExposed()
            let faces = MockVision.portraitScenario()
            let saliency = MockVision.centerSaliency()

            return AnalysisScenario(
                pixelBuffer: buffer,
                faces: faces,
                saliency: saliency
            )
        }

        static var overexposedScene: AnalysisScenario {
            let buffer = MockPixelBuffer.overexposed()

            return AnalysisScenario(
                pixelBuffer: buffer,
                faces: [],
                saliency: MockVision.centerSaliency()
            )
        }

        static var multiSubjectScene: AnalysisScenario {
            let buffer = MockPixelBuffer.wellExposed()
            let faces = MockVision.multipleFaces(count: 3)
            let objects = MockVision.multipleObjects()

            return AnalysisScenario(
                pixelBuffer: buffer,
                faces: faces,
                objects: objects
            )
        }
    }
}
