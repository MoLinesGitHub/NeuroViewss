import Testing
import Foundation
@testable import NVAIKit

// MARK: - Main Test Suite Entry Point

@Suite("NVAIKit Test Suite")
struct NVAIKitMainTests {
    
    @Test("NVAIKit module loads correctly")
    func testModuleLoading() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }
        
        // Basic smoke test to ensure the module loads
        let _ = LiveAIProcessor()
        
        // Test passed if we can create the processor
        #expect(true)
    }
    
    @Test("All core types are available")
    func testCoreTypesAvailability() throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }
        
        // Test that all main types can be instantiated
        let analysis = FrameAnalysis.empty()
        let suggestion = CompositionSuggestion.neutral()
        let error = AIProcessingError.insufficientResources
        
        #expect(analysis.overallScore >= 0)
        #expect(suggestion.score > 0)
        #expect(error.localizedDescription.contains("resources"))
    }
    
    @Test("Processing quality enum is complete")
    func testProcessingQualityEnum() throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }
        
        let allQualities = ProcessingQuality.allCases
        
        #expect(allQualities.count == 3)
        #expect(allQualities.contains(.low))
        #expect(allQualities.contains(.medium))
        #expect(allQualities.contains(.high))
        
        for quality in allQualities {
            #expect(!quality.displayName.isEmpty)
        }
    }
    
    @Test("AI suggestion types are complete")
    func testAISuggestionTypes() throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }
        
        let adjustExposure = AISuggestion.adjustExposure(value: 0.5)
        let changeAngle = AISuggestion.changeAngle(degrees: 15.0)
        let waitForLighting = AISuggestion.waitForBetterLighting
        let captureNow = AISuggestion.captureNow(reason: "Perfect timing")
        let addFilter = AISuggestion.addFilter(.vivid)
        let focusOn = AISuggestion.focusOn(point: CGPoint(x: 0.5, y: 0.5))
        
        let allSuggestions = [adjustExposure, changeAngle, waitForLighting, captureNow, addFilter, focusOn]
        
        #expect(allSuggestions.count == 6)
        
        // Test Equatable conformance
        #expect(adjustExposure == AISuggestion.adjustExposure(value: 0.5))
        #expect(captureNow == AISuggestion.captureNow(reason: "Perfect timing"))
    }
    
    @Test("Error types provide meaningful descriptions")
    func testErrorDescriptions() throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }
        
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
            #expect(description.count > 10, "Error description should be meaningful")
        }
    }
}
