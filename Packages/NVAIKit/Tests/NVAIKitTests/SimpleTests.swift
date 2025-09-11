import Testing
import Foundation
@testable import NVAIKit

// MARK: - Simplified Test Suite (Compatible with all versions)

@Suite("Simple NVAIKit Tests")
struct SimpleTests {
    
    @Test("Basic type instantiation")
    func testBasicTypeInstantiation() throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { 
            print("Skipping test - requires iOS 15.0+ or macOS 12.0+")
            return 
        }
        
        // Test basic type creation
        let analysis = FrameAnalysis.empty()
        let liveAnalysis = LiveAnalysis(
            frameAnalysis: analysis,
            timestamp: Date(),
            processingTime: 0.1
        )
        
        #expect(analysis.overallScore >= 0)
        #expect(liveAnalysis.processingTime == 0.1)
        #expect(liveAnalysis.isRecentAnalysis == true)
    }
    
    @Test("Composition suggestions work")
    func testCompositionSuggestions() throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { 
            print("Skipping test - requires iOS 15.0+ or macOS 12.0+")
            return 
        }
        
        let excellent = CompositionSuggestion.excellent(["Great!"])
        let good = CompositionSuggestion.good(["Good"])
        let needsWork = CompositionSuggestion.needsImprovement(["Needs work"])
        let none = CompositionSuggestion.noAnalysis("No analysis")
        
        #expect(excellent.score == 0.9)
        #expect(good.score == 0.7)
        #expect(needsWork.score == 0.4)
        #expect(none.score == 0.0)
        
        #expect(excellent.suggestions.count == 1)
        #expect(good.suggestions.count == 1)
    }
    
    @Test("Vision analysis results")
    func testVisionAnalysisResults() throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { 
            print("Skipping test - requires iOS 15.0+ or macOS 12.0+")
            return 
        }
        
        let emptyResult = VisionAnalysisResult.empty()
        
        #expect(emptyResult.faces.isEmpty)
        #expect(emptyResult.detectedText.isEmpty)
        #expect(emptyResult.objects.isEmpty)
        #expect(emptyResult.confidence == 0.0)
        
        // Test with some data
        let face = VisionFaceResult(
            boundingBox: CGRect(x: 0, y: 0, width: 100, height: 100),
            confidence: 0.9
        )
        
        let text = VisionTextResult(
            text: "Hello",
            boundingBox: CGRect(x: 0, y: 0, width: 50, height: 20),
            confidence: 0.8
        )
        
        let object = VisionObjectResult(
            label: "person",
            boundingBox: CGRect(x: 0, y: 0, width: 200, height: 300),
            confidence: 0.85
        )
        
        let result = VisionAnalysisResult(
            faces: [face],
            detectedText: [text],
            objects: [object],
            confidence: 0.8
        )
        
        #expect(result.faces.count == 1)
        #expect(result.detectedText.count == 1)
        #expect(result.objects.count == 1)
        #expect(result.confidence == 0.8)
        #expect(result.faces.first?.confidence == 0.9)
        #expect(result.detectedText.first?.text == "Hello")
        #expect(result.objects.first?.label == "person")
    }
    
    @Test("Image quality analysis")
    func testImageQualityAnalysis() throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { 
            print("Skipping test - requires iOS 15.0+ or macOS 12.0+")
            return 
        }
        
        let unknownQuality = ImageQualityAnalysis.unknown()
        
        #expect(unknownQuality.brightness == 0.5)
        #expect(unknownQuality.contrast == 0.5)
        #expect(unknownQuality.sharpness == 0.5)
        #expect(unknownQuality.noise == 0.5)
        #expect(unknownQuality.exposure == 0.5)
        #expect(unknownQuality.stability == 0.5)
        #expect(unknownQuality.lighting == .good)
        #expect(unknownQuality.overallQuality == 0.5)
        
        // Test custom quality
        let customQuality = ImageQualityAnalysis(
            brightness: 0.8,
            contrast: 0.7,
            sharpness: 0.9,
            noise: 0.2,
            exposure: 0.6,
            stability: 0.8,
            lighting: .excellent,
            overallQuality: 0.8
        )
        
        #expect(customQuality.brightness == 0.8)
        #expect(customQuality.contrast == 0.7)
        #expect(customQuality.lighting == .excellent)
        #expect(customQuality.overallQuality == 0.8)
    }
    
    @Test("AI suggestions encoding and decoding")
    func testAISuggestionsCodable() throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { 
            print("Skipping test - requires iOS 15.0+ or macOS 12.0+")
            return 
        }
        
        let suggestions: [AISuggestion] = [
            .adjustExposure(value: 0.5),
            .changeAngle(degrees: 15.0),
            .waitForBetterLighting,
            .captureNow(reason: "Perfect moment"),
            .addFilter(.vivid),
            .focusOn(point: CGPoint(x: 0.5, y: 0.3))
        ]
        
        // Test that all suggestions can be created
        #expect(suggestions.count == 6)
        
        // Test encoding/decoding
        for suggestion in suggestions {
            do {
                let encoded = try JSONEncoder().encode(suggestion)
                let decoded = try JSONDecoder().decode(AISuggestion.self, from: encoded)
                
                #expect(suggestion == decoded, "Suggestion encoding/decoding failed for \(suggestion)")
            } catch {
                Issue.record("Failed to encode/decode suggestion \(suggestion): \(error)")
            }
        }
    }
    
    @Test("Processing quality and filter types")
    func testProcessingQualityAndFilters() throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { 
            print("Skipping test - requires iOS 15.0+ or macOS 12.0+")
            return 
        }
        
        // Test ProcessingQuality
        let qualities = ProcessingQuality.allCases
        #expect(qualities.count == 3)
        #expect(qualities.contains(.low))
        #expect(qualities.contains(.medium))
        #expect(qualities.contains(.high))
        
        for quality in qualities {
            #expect(!quality.displayName.isEmpty)
            #expect(quality.displayName.capitalized == quality.displayName)
        }
        
        // Test FilterType
        let filters = FilterType.allCases
        #expect(filters.count == 9)
        #expect(filters.contains(.none))
        #expect(filters.contains(.vivid))
        #expect(filters.contains(.dramatic))
        
        for filter in filters {
            #expect(!filter.rawValue.isEmpty)
        }
    }
    
    @Test("Error types and descriptions")
    func testErrorTypes() throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { 
            print("Skipping test - requires iOS 15.0+ or macOS 12.0+")
            return 
        }
        
        let errors: [AIProcessingError] = [
            .alreadyProcessing,
            .initializationFailed(NSError(domain: "test", code: 1)),
            .processingFailed("test failure"),
            .insufficientResources,
            .unsupportedFormat,
            .timeout
        ]
        
        for error in errors {
            let description = error.localizedDescription
            #expect(!description.isEmpty, "Error should have a description")
            #expect(description.count > 5, "Error description should be meaningful")
        }
        
        // Test specific error cases
        #expect(AIProcessingError.alreadyProcessing.localizedDescription.contains("already"))
        #expect(AIProcessingError.insufficientResources.localizedDescription.contains("resources"))
        #expect(AIProcessingError.timeout.localizedDescription.contains("timed out"))
    }
    
    @Test("Performance metrics formatting")
    func testPerformanceMetricsFormatting() throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { 
            print("Skipping test - requires iOS 15.0+ or macOS 12.0+")
            return 
        }
        
        let metrics = ProcessingMetrics(
            averageProcessingTime: 0.05, // 50ms
            currentFPS: 15.5,
            totalFramesProcessed: 100,
            memoryUsage: 50.0 // 50MB
        )
        
        #expect(metrics.formattedFPS == "15.5")
        #expect(metrics.formattedProcessingTime == "50.00ms")
        #expect(metrics.formattedMemoryUsage == "50.0MB")
        
        // Test zero values
        let zeroMetrics = ProcessingMetrics()
        #expect(zeroMetrics.formattedFPS == "0.0")
        #expect(zeroMetrics.formattedProcessingTime == "0.00ms")
        #expect(zeroMetrics.formattedMemoryUsage == "0.0MB")
    }
    
    @Test("Memory analysis formatting")
    func testMemoryAnalysisFormatting() throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { 
            print("Skipping test - requires iOS 15.0+ or macOS 12.0+")
            return 
        }
        
        let analysis = MemoryAnalysis(
            currentUsage: 100 * 1024 * 1024, // 100MB
            peakUsage: 150 * 1024 * 1024,    // 150MB
            averageUsage: 120 * 1024 * 1024, // 120MB
            memoryPressure: .moderate,
            recommendations: ["Optimize caching", "Reduce batch size"]
        )
        
        #expect(analysis.formattedCurrentUsage.contains("MB"))
        #expect(analysis.formattedPeakUsage.contains("MB"))
        #expect(analysis.formattedAverageUsage.contains("MB"))
        #expect(analysis.recommendations.count == 2)
        #expect(analysis.memoryPressure == .moderate)
    }
    
    @Test("System capabilities structure")
    func testSystemCapabilities() throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { 
            print("Skipping test - requires iOS 15.0+ or macOS 12.0+")
            return 
        }
        
        let capabilities = SystemCapabilities(
            cpuCores: 8,
            physicalMemory: 8 * 1024 * 1024 * 1024, // 8GB
            operatingSystem: "iOS 17.0",
            deviceModel: "iPhone15,2",
            thermalState: .nominal,
            lowPowerModeEnabled: false
        )
        
        #expect(capabilities.cpuCores == 8)
        #expect(capabilities.formattedPhysicalMemory.contains("GB"))
        #expect(capabilities.isHighPerformanceDevice == true)
        #expect(capabilities.isMidRangeDevice == true)
        #expect(!capabilities.operatingSystem.isEmpty)
        #expect(!capabilities.deviceModel.isEmpty)
    }
}