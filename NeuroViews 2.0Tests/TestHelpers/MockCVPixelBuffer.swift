//
//  MockCVPixelBuffer.swift
//  NeuroViews 2.0Tests
//
//  Created by Claude Code on 24/01/25.
//  Mock CVPixelBuffer generators for testing camera analysis methods
//

import CoreVideo
import CoreImage
import AVFoundation
import Foundation

/// Mock pixel buffer generator for testing
enum MockPixelBuffer {

    // MARK: - Basic Generators

    /// Creates a solid color pixel buffer
    /// - Parameters:
    ///   - width: Width in pixels
    ///   - height: Height in pixels
    ///   - color: RGB color (values 0-255)
    /// - Returns: CVPixelBuffer or nil if creation fails
    static func solidColor(
        width: Int = 1920,
        height: Int = 1080,
        color: (r: UInt8, g: UInt8, b: UInt8) = (128, 128, 128)
    ) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?

        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            return nil
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let bufferHeight = CVPixelBufferGetHeight(buffer)

        for row in 0..<bufferHeight {
            let rowBase = baseAddress.advanced(by: row * bytesPerRow)
            for col in 0..<width {
                let pixelPtr = rowBase.advanced(by: col * 4).assumingMemoryBound(to: UInt8.self)
                pixelPtr[0] = color.b  // Blue
                pixelPtr[1] = color.g  // Green
                pixelPtr[2] = color.r  // Red
                pixelPtr[3] = 255      // Alpha
            }
        }

        return buffer
    }

    /// Creates a gradient pixel buffer (top to bottom)
    /// - Parameters:
    ///   - width: Width in pixels
    ///   - height: Height in pixels
    ///   - topColor: RGB color at top
    ///   - bottomColor: RGB color at bottom
    /// - Returns: CVPixelBuffer or nil if creation fails
    static func gradient(
        width: Int = 1920,
        height: Int = 1080,
        topColor: (r: UInt8, g: UInt8, b: UInt8) = (255, 255, 255),
        bottomColor: (r: UInt8, g: UInt8, b: UInt8) = (0, 0, 0)
    ) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?

        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            return nil
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let bufferHeight = CVPixelBufferGetHeight(buffer)

        for row in 0..<bufferHeight {
            let rowBase = baseAddress.advanced(by: row * bytesPerRow)
            let ratio = Float(row) / Float(max(bufferHeight - 1, 1))

            let r = UInt8(Float(topColor.r) * (1 - ratio) + Float(bottomColor.r) * ratio)
            let g = UInt8(Float(topColor.g) * (1 - ratio) + Float(bottomColor.g) * ratio)
            let b = UInt8(Float(topColor.b) * (1 - ratio) + Float(bottomColor.b) * ratio)

            for col in 0..<width {
                let pixelPtr = rowBase.advanced(by: col * 4).assumingMemoryBound(to: UInt8.self)
                pixelPtr[0] = b
                pixelPtr[1] = g
                pixelPtr[2] = r
                pixelPtr[3] = 255
            }
        }

        return buffer
    }

    // MARK: - Test Scenario Generators

    /// Creates a bright overexposed pixel buffer (all pixels near white)
    static func overexposed(width: Int = 1920, height: Int = 1080) -> CVPixelBuffer? {
        return solidColor(width: width, height: height, color: (240, 240, 240))
    }

    /// Creates a dark underexposed pixel buffer (all pixels near black)
    static func underexposed(width: Int = 1920, height: Int = 1080) -> CVPixelBuffer? {
        return solidColor(width: width, height: height, color: (15, 15, 15))
    }

    /// Creates a well-exposed pixel buffer (mid-tone gray)
    static func wellExposed(width: Int = 1920, height: Int = 1080) -> CVPixelBuffer? {
        return solidColor(width: width, height: height, color: (128, 128, 128))
    }

    /// Creates a high contrast pixel buffer (gradient from black to white)
    static func highContrast(width: Int = 1920, height: Int = 1080) -> CVPixelBuffer? {
        return gradient(
            width: width,
            height: height,
            topColor: (255, 255, 255),
            bottomColor: (0, 0, 0)
        )
    }

    /// Creates a low contrast pixel buffer (gradient from mid-gray to slightly darker gray)
    static func lowContrast(width: Int = 1920, height: Int = 1080) -> CVPixelBuffer? {
        return gradient(
            width: width,
            height: height,
            topColor: (140, 140, 140),
            bottomColor: (115, 115, 115)
        )
    }

    // MARK: - Pattern Generators

    /// Creates a checkerboard pattern
    /// - Parameters:
    ///   - width: Width in pixels
    ///   - height: Height in pixels
    ///   - squareSize: Size of each checkerboard square
    ///   - color1: First color
    ///   - color2: Second color
    /// - Returns: CVPixelBuffer or nil if creation fails
    static func checkerboard(
        width: Int = 1920,
        height: Int = 1080,
        squareSize: Int = 64,
        color1: (r: UInt8, g: UInt8, b: UInt8) = (255, 255, 255),
        color2: (r: UInt8, g: UInt8, b: UInt8) = (0, 0, 0)
    ) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?

        let attrs = [
            kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue!,
            kCVPixelBufferMetalCompatibilityKey: kCFBooleanTrue!
        ] as CFDictionary

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32BGRA,
            attrs,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(buffer) else {
            return nil
        }

        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let bufferHeight = CVPixelBufferGetHeight(buffer)

        for row in 0..<bufferHeight {
            let rowBase = baseAddress.advanced(by: row * bytesPerRow)
            let rowSquare = (row / squareSize) % 2

            for col in 0..<width {
                let colSquare = (col / squareSize) % 2
                let useColor1 = (rowSquare + colSquare) % 2 == 0
                let color = useColor1 ? color1 : color2

                let pixelPtr = rowBase.advanced(by: col * 4).assumingMemoryBound(to: UInt8.self)
                pixelPtr[0] = color.b
                pixelPtr[1] = color.g
                pixelPtr[2] = color.r
                pixelPtr[3] = 255
            }
        }

        return buffer
    }

    // MARK: - CMSampleBuffer Generator

    /// Creates a CMSampleBuffer from a CVPixelBuffer
    /// - Parameter pixelBuffer: Source pixel buffer
    /// - Returns: CMSampleBuffer or nil if creation fails
    static func createSampleBuffer(from pixelBuffer: CVPixelBuffer) -> CMSampleBuffer? {
        var sampleBuffer: CMSampleBuffer?
        var formatDescription: CMFormatDescription?

        let status = CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescriptionOut: &formatDescription
        )

        guard status == noErr, let formatDesc = formatDescription else {
            return nil
        }

        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: 30),
            presentationTimeStamp: CMTime(value: 0, timescale: 30),
            decodeTimeStamp: CMTime.invalid
        )

        let sampleBufferStatus = CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: pixelBuffer,
            formatDescription: formatDesc,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )

        guard sampleBufferStatus == noErr else {
            return nil
        }

        return sampleBuffer
    }

    // MARK: - CIImage Converter

    /// Converts CVPixelBuffer to CIImage
    /// - Parameter pixelBuffer: Source pixel buffer
    /// - Returns: CIImage or nil if conversion fails
    static func toCIImage(_ pixelBuffer: CVPixelBuffer) -> CIImage? {
        return CIImage(cvPixelBuffer: pixelBuffer)
    }
}

// MARK: - Convenience Extensions

extension MockPixelBuffer {

    /// Standard test resolutions
    enum Resolution {
        case sd      // 640x480
        case hd      // 1280x720
        case fullHD  // 1920x1080
        case uhd     // 3840x2160

        var size: (width: Int, height: Int) {
            switch self {
            case .sd:     return (640, 480)
            case .hd:     return (1280, 720)
            case .fullHD: return (1920, 1080)
            case .uhd:    return (3840, 2160)
            }
        }
    }

    /// Creates a pixel buffer with standard resolution
    static func withResolution(
        _ resolution: Resolution,
        scenario: TestScenario = .wellExposed
    ) -> CVPixelBuffer? {
        let size = resolution.size

        switch scenario {
        case .overexposed:
            return overexposed(width: size.width, height: size.height)
        case .underexposed:
            return underexposed(width: size.width, height: size.height)
        case .wellExposed:
            return wellExposed(width: size.width, height: size.height)
        case .highContrast:
            return highContrast(width: size.width, height: size.height)
        case .lowContrast:
            return lowContrast(width: size.width, height: size.height)
        }
    }

    enum TestScenario {
        case overexposed
        case underexposed
        case wellExposed
        case highContrast
        case lowContrast
    }
}
