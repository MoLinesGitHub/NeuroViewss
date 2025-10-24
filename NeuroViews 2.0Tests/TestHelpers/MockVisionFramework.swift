//
//  MockVisionFramework.swift
//  NeuroViews 2.0Tests
//
//  Created by Claude Code on 24/01/25.
//  Mock Vision framework responses for testing
//

import Vision
import CoreImage
import Foundation

/// Mock Vision framework responses
enum MockVision {

    // MARK: - Face Detection Mocks

    /// Creates a mock face observation
    /// - Parameters:
    ///   - boundingBox: Normalized bounding box (0-1)
    ///   - confidence: Detection confidence (0-1)
    /// - Returns: Mock VNFaceObservation-like data
    static func faceObservation(
        boundingBox: CGRect = CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4),
        confidence: Float = 0.95
    ) -> MockFaceObservation {
        return MockFaceObservation(
            boundingBox: boundingBox,
            confidence: confidence
        )
    }

    /// Creates multiple mock face observations
    static func multipleFaces(count: Int = 2) -> [MockFaceObservation] {
        var faces: [MockFaceObservation] = []

        for i in 0..<count {
            let x = 0.1 + (Double(i) * 0.3)
            let y = 0.2
            let boundingBox = CGRect(x: x, y: y, width: 0.2, height: 0.3)
            faces.append(faceObservation(boundingBox: boundingBox, confidence: 0.9))
        }

        return faces
    }

    /// No faces detected scenario
    static func noFaces() -> [MockFaceObservation] {
        return []
    }

    // MARK: - Object Detection Mocks

    /// Creates a mock detected object observation
    static func objectObservation(
        identifier: String = "person",
        boundingBox: CGRect = CGRect(x: 0.2, y: 0.3, width: 0.6, height: 0.5),
        confidence: Float = 0.85
    ) -> MockObjectObservation {
        return MockObjectObservation(
            identifier: identifier,
            boundingBox: boundingBox,
            confidence: confidence
        )
    }

    /// Creates multiple mock object observations
    static func multipleObjects(identifiers: [String] = ["person", "dog", "car"]) -> [MockObjectObservation] {
        var objects: [MockObjectObservation] = []

        for (index, identifier) in identifiers.enumerated() {
            let x = 0.1 + (Double(index) * 0.25)
            let y = 0.2
            let boundingBox = CGRect(x: x, y: y, width: 0.2, height: 0.4)
            objects.append(objectObservation(
                identifier: identifier,
                boundingBox: boundingBox,
                confidence: 0.8
            ))
        }

        return objects
    }

    // MARK: - Saliency Detection Mocks

    /// Creates a mock saliency observation
    static func saliencyObservation(
        salientRegions: [CGRect] = [
            CGRect(x: 0.3, y: 0.3, width: 0.4, height: 0.4)
        ]
    ) -> MockSaliencyObservation {
        return MockSaliencyObservation(salientRegions: salientRegions)
    }

    /// Creates center-focused saliency (single region in center)
    static func centerSaliency() -> MockSaliencyObservation {
        return saliencyObservation(
            salientRegions: [CGRect(x: 0.25, y: 0.25, width: 0.5, height: 0.5)]
        )
    }

    /// Creates edge-focused saliency (multiple regions at edges)
    static func edgeSaliency() -> MockSaliencyObservation {
        return saliencyObservation(
            salientRegions: [
                CGRect(x: 0.05, y: 0.05, width: 0.2, height: 0.2),
                CGRect(x: 0.75, y: 0.05, width: 0.2, height: 0.2),
                CGRect(x: 0.05, y: 0.75, width: 0.2, height: 0.2),
                CGRect(x: 0.75, y: 0.75, width: 0.2, height: 0.2)
            ]
        )
    }
}

// MARK: - Mock Observation Structures

/// Mock face observation matching VNFaceObservation interface
struct MockFaceObservation {
    let boundingBox: CGRect
    let confidence: Float

    /// Converts to normalized CGRect for testing
    var normalizedBoundingBox: CGRect {
        return boundingBox
    }
}

/// Mock object observation matching VNRecognizedObjectObservation interface
struct MockObjectObservation {
    let identifier: String
    let boundingBox: CGRect
    let confidence: Float

    var normalizedBoundingBox: CGRect {
        return boundingBox
    }
}

/// Mock saliency observation matching VNSaliencyImageObservation interface
struct MockSaliencyObservation {
    let salientRegions: [CGRect]

    /// Returns the most salient region
    var primaryRegion: CGRect? {
        return salientRegions.first
    }

    /// Returns all salient regions as normalized CGRects
    var allRegions: [CGRect] {
        return salientRegions
    }
}

// MARK: - Request Mock Helpers

/// Mock Vision request completion handlers
enum MockVisionRequest {

    /// Simulates a face detection request completion
    static func completeFaceDetection(
        observations: [MockFaceObservation],
        error: Error? = nil
    ) -> (results: [MockFaceObservation]?, error: Error?) {
        if let error = error {
            return (nil, error)
        }
        return (observations, nil)
    }

    /// Simulates an object detection request completion
    static func completeObjectDetection(
        observations: [MockObjectObservation],
        error: Error? = nil
    ) -> (results: [MockObjectObservation]?, error: Error?) {
        if let error = error {
            return (nil, error)
        }
        return (observations, nil)
    }

    /// Simulates a saliency detection request completion
    static func completeSaliencyDetection(
        observation: MockSaliencyObservation,
        error: Error? = nil
    ) -> (result: MockSaliencyObservation?, error: Error?) {
        if let error = error {
            return (nil, error)
        }
        return (observation, nil)
    }
}

// MARK: - Common Test Scenarios

extension MockVision {

    /// Test scenario: Portrait with single centered face
    static func portraitScenario() -> [MockFaceObservation] {
        return [faceObservation(
            boundingBox: CGRect(x: 0.25, y: 0.2, width: 0.5, height: 0.6),
            confidence: 0.98
        )]
    }

    /// Test scenario: Group photo with multiple faces
    static func groupPhotoScenario() -> [MockFaceObservation] {
        return multipleFaces(count: 4)
    }

    /// Test scenario: Low confidence detection
    static func lowConfidenceScenario() -> [MockFaceObservation] {
        return [faceObservation(
            boundingBox: CGRect(x: 0.4, y: 0.4, width: 0.2, height: 0.2),
            confidence: 0.3
        )]
    }

    /// Test scenario: Subject at edge of frame
    static func edgeSubjectScenario() -> [MockFaceObservation] {
        return [faceObservation(
            boundingBox: CGRect(x: 0.85, y: 0.1, width: 0.1, height: 0.15),
            confidence: 0.85
        )]
    }

    /// Test scenario: Very small subject (far away)
    static func distantSubjectScenario() -> [MockFaceObservation] {
        return [faceObservation(
            boundingBox: CGRect(x: 0.45, y: 0.45, width: 0.05, height: 0.05),
            confidence: 0.75
        )]
    }
}

// MARK: - CGRect Helpers for Testing

extension CGRect {

    /// Returns the center point of the rectangle
    var center: CGPoint {
        return CGPoint(
            x: origin.x + (size.width / 2),
            y: origin.y + (size.height / 2)
        )
    }

    /// Returns the area of the rectangle
    var area: CGFloat {
        return size.width * size.height
    }

    /// Checks if this rect is in the center third of the frame
    var isInCenter: Bool {
        let centerX = origin.x + (size.width / 2)
        let centerY = origin.y + (size.height / 2)
        return centerX > 0.33 && centerX < 0.66 && centerY > 0.33 && centerY < 0.66
    }

    /// Checks if this rect is near an edge (within 20% of frame boundary)
    var isNearEdge: Bool {
        return origin.x < 0.2 || origin.y < 0.2 ||
               (origin.x + size.width) > 0.8 || (origin.y + size.height) > 0.8
    }
}
