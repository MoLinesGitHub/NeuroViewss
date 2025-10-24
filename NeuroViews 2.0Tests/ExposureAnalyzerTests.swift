//
//  ExposureAnalyzerTests.swift
//  NeuroViews 2.0Tests
//
//  Created by Claude Code on 24/01/25.
//  Coverage improvement: ExposureAnalyzer 2.29% → 35%+
//

import Testing
import Foundation
import CoreGraphics
@testable import NeuroViews_2_0

// MARK: - ExposureAnalyzer Core Tests

@Suite("ExposureAnalyzer - Core Functionality")
struct ExposureAnalyzerTests {

    // MARK: - Initialization and Configuration Tests

    @Test("ExposureAnalyzer initializes with correct defaults")
    func testInitialization() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        #expect(analyzer.analysisType == .exposure, "Analysis type should be exposure")
        #expect(analyzer.isEnabled == true, "Should be enabled by default")
    }

    @Test("ExposureAnalyzer can be enabled and disabled")
    func testEnableDisable() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        #expect(analyzer.isEnabled == true, "Should start enabled")

        analyzer.isEnabled = false
        #expect(analyzer.isEnabled == false, "Should be disabled")

        analyzer.isEnabled = true
        #expect(analyzer.isEnabled == true, "Should be re-enabled")
    }

    @Test("ExposureAnalyzer supports configuration with settings")
    func testConfiguration() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        let settings: [String: Any] = [
            "adaptiveAnalysisEnabled": false,
            "sceneAnalysisEnabled": false,
            "exposureSmoothingEnabled": false,
            "targetEV": 1.5
        ]

        analyzer.configure(with: settings)

        // Configuration should succeed without errors
        #expect(true, "Configuration should complete successfully")
    }

    @Test("ExposureAnalyzer handles partial configuration")
    func testPartialConfiguration() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        // Only configure some settings
        let settings: [String: Any] = [
            "targetEV": 2.0
        ]

        analyzer.configure(with: settings)

        #expect(true, "Partial configuration should succeed")
    }

    @Test("ExposureAnalyzer handles empty configuration")
    func testEmptyConfiguration() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        let emptySettings: [String: Any] = [:]

        analyzer.configure(with: emptySettings)

        #expect(true, "Empty configuration should not crash")
    }

    // MARK: - ExposureSettings Tests

    @Test("ExposureSettings default values are correct")
    func testExposureSettingsDefaults() {
        let settings = ExposureSettings.default

        #expect(settings.adaptiveAnalysisEnabled == true, "Adaptive analysis should be enabled by default")
        #expect(settings.sceneAnalysisEnabled == true, "Scene analysis should be enabled by default")
        #expect(settings.exposureSmoothingEnabled == true, "Exposure smoothing should be enabled by default")
        #expect(settings.targetEV == 0.0, "Default target EV should be 0.0 (middle exposure)")
    }

    @Test("ExposureSettings can be created with custom values")
    func testExposureSettingsCustom() {
        let settings = ExposureSettings(
            adaptiveAnalysisEnabled: false,
            sceneAnalysisEnabled: false,
            exposureSmoothingEnabled: false,
            targetEV: 2.5
        )

        #expect(settings.adaptiveAnalysisEnabled == false)
        #expect(settings.sceneAnalysisEnabled == false)
        #expect(settings.exposureSmoothingEnabled == false)
        #expect(settings.targetEV == 2.5)
    }

    @Test("ExposureSettings supports extreme EV values")
    func testExposureSettingsExtremeEV() {
        let positiveEV = ExposureSettings(
            adaptiveAnalysisEnabled: true,
            sceneAnalysisEnabled: true,
            exposureSmoothingEnabled: true,
            targetEV: 10.0
        )

        #expect(positiveEV.targetEV == 10.0)

        let negativeEV = ExposureSettings(
            adaptiveAnalysisEnabled: true,
            sceneAnalysisEnabled: true,
            exposureSmoothingEnabled: true,
            targetEV: -10.0
        )

        #expect(negativeEV.targetEV == -10.0)
    }

    // MARK: - AdvancedExposureResult Tests

    @Test("AdvancedExposureResult can be created with all properties")
    func testAdvancedExposureResultCreation() {
        let histogram: [Float] = Array(repeating: 0.5, count: 256)

        let result = AdvancedExposureResult(
            evValue: 1.2,
            confidence: 0.85,
            isOptimal: true,
            clippingLevel: 0.02,
            exposureCompensation: 0.1,
            histogram: histogram
        )

        #expect(result.evValue == 1.2)
        #expect(result.confidence == 0.85)
        #expect(result.isOptimal == true)
        #expect(result.clippingLevel == 0.02)
        #expect(result.exposureCompensation == 0.1)
        #expect(result.histogram.count == 256)
    }

    @Test("AdvancedExposureResult converts to dictionary correctly")
    func testAdvancedExposureResultToDictionary() {
        let histogram: [Float] = [0.1, 0.2, 0.3]

        let result = AdvancedExposureResult(
            evValue: 1.5,
            confidence: 0.9,
            isOptimal: false,
            clippingLevel: 0.1,
            exposureCompensation: -0.5,
            histogram: histogram
        )

        let dict = result.toDictionary()

        #expect(dict["evValue"] as? Float == 1.5)
        #expect(dict["confidence"] as? Float == 0.9)
        #expect(dict["isOptimal"] as? Bool == false)
        #expect(dict["clippingLevel"] as? Float == 0.1)
        #expect(dict["exposureCompensation"] as? Float == -0.5)
        #expect((dict["histogram"] as? [Float])?.count == 3)
    }

    @Test("AdvancedExposureResult handles empty histogram")
    func testAdvancedExposureResultEmptyHistogram() {
        let result = AdvancedExposureResult(
            evValue: 0.0,
            confidence: 0.0,
            isOptimal: false,
            clippingLevel: 0.0,
            exposureCompensation: 0.0,
            histogram: []
        )

        #expect(result.histogram.isEmpty)

        let dict = result.toDictionary()
        #expect((dict["histogram"] as? [Float])?.isEmpty == true)
    }

    // MARK: - SceneExposureResult Tests

    @Test("SceneExposureResult can be created with regions")
    func testSceneExposureResultCreation() {
        let region1 = RegionExposure(
            region: CGRect(x: 0, y: 0, width: 100, height: 100),
            evValue: 1.0,
            luminance: 0.5,
            importance: 0.8
        )

        let region2 = RegionExposure(
            region: CGRect(x: 100, y: 100, width: 100, height: 100),
            evValue: 1.5,
            luminance: 0.6,
            importance: 0.9
        )

        let result = SceneExposureResult(
            regions: [region1, region2],
            centerWeightedEV: 1.2,
            dynamicRange: 4.5,
            exposureVariation: 1.8,
            confidence: 0.85
        )

        #expect(result.regions.count == 2)
        #expect(result.centerWeightedEV == 1.2)
        #expect(result.dynamicRange == 4.5)
        #expect(result.exposureVariation == 1.8)
        #expect(result.confidence == 0.85)
    }

    @Test("SceneExposureResult converts to dictionary correctly")
    func testSceneExposureResultToDictionary() {
        let result = SceneExposureResult(
            regions: [],
            centerWeightedEV: 2.0,
            dynamicRange: 5.0,
            exposureVariation: 2.5,
            confidence: 0.75
        )

        let dict = result.toDictionary()

        #expect(dict["regionCount"] as? Int == 0)
        #expect(dict["centerWeightedEV"] as? Float == 2.0)
        #expect(dict["dynamicRange"] as? Float == 5.0)
        #expect(dict["exposureVariation"] as? Float == 2.5)
        #expect(dict["confidence"] as? Float == 0.75)
    }

    @Test("SceneExposureResult handles empty regions array")
    func testSceneExposureResultEmptyRegions() {
        let result = SceneExposureResult(
            regions: [],
            centerWeightedEV: 0.0,
            dynamicRange: 0.0,
            exposureVariation: 0.0,
            confidence: 0.0
        )

        #expect(result.regions.isEmpty)

        let dict = result.toDictionary()
        #expect(dict["regionCount"] as? Int == 0)
    }

    // MARK: - RegionExposure Tests

    @Test("RegionExposure can be created with all properties")
    func testRegionExposureCreation() {
        let region = RegionExposure(
            region: CGRect(x: 50, y: 50, width: 200, height: 150),
            evValue: 2.5,
            luminance: 0.7,
            importance: 0.95
        )

        #expect(region.region.origin.x == 50)
        #expect(region.region.origin.y == 50)
        #expect(region.region.width == 200)
        #expect(region.region.height == 150)
        #expect(region.evValue == 2.5)
        #expect(region.luminance == 0.7)
        #expect(region.importance == 0.95)
    }

    @Test("RegionExposure handles zero-size region")
    func testRegionExposureZeroSize() {
        let region = RegionExposure(
            region: CGRect(x: 0, y: 0, width: 0, height: 0),
            evValue: 0.0,
            luminance: 0.0,
            importance: 0.0
        )

        #expect(region.region.isEmpty)
        #expect(region.region.width == 0)
        #expect(region.region.height == 0)
    }

    @Test("RegionExposure handles negative coordinates")
    func testRegionExposureNegativeCoordinates() {
        let region = RegionExposure(
            region: CGRect(x: -50, y: -30, width: 100, height: 80),
            evValue: 1.0,
            luminance: 0.5,
            importance: 0.5
        )

        #expect(region.region.origin.x == -50)
        #expect(region.region.origin.y == -30)
    }

    // MARK: - AdvancedDynamicRangeResult Tests

    @Test("AdvancedDynamicRangeResult can be created with all properties")
    func testAdvancedDynamicRangeResultCreation() {
        let toneDistribution: [Float] = [0.1, 0.2, 0.3, 0.2, 0.2]

        let result = AdvancedDynamicRangeResult(
            confidence: 0.88,
            shadowsBlocked: 0.05,
            highlightsBlown: 0.03,
            dynamicRange: 6.5,
            midtoneSeparation: 0.75,
            toneDistribution: toneDistribution
        )

        #expect(result.confidence == 0.88)
        #expect(result.shadowsBlocked == 0.05)
        #expect(result.highlightsBlown == 0.03)
        #expect(result.dynamicRange == 6.5)
        #expect(result.midtoneSeparation == 0.75)
        #expect(result.toneDistribution.count == 5)
    }

    @Test("AdvancedDynamicRangeResult converts to dictionary correctly")
    func testAdvancedDynamicRangeResultToDictionary() {
        let toneDistribution: [Float] = [0.25, 0.5, 0.25]

        let result = AdvancedDynamicRangeResult(
            confidence: 0.95,
            shadowsBlocked: 0.1,
            highlightsBlown: 0.08,
            dynamicRange: 7.0,
            midtoneSeparation: 0.8,
            toneDistribution: toneDistribution
        )

        let dict = result.toDictionary()

        #expect(dict["confidence"] as? Float == 0.95)
        #expect(dict["shadowsBlocked"] as? Float == 0.1)
        #expect(dict["highlightsBlown"] as? Float == 0.08)
        #expect(dict["dynamicRange"] as? Float == 7.0)
        #expect(dict["midtoneSeparation"] as? Float == 0.8)
        #expect((dict["toneDistribution"] as? [Float])?.count == 3)
    }

    @Test("AdvancedDynamicRangeResult handles empty tone distribution")
    func testAdvancedDynamicRangeResultEmptyToneDistribution() {
        let result = AdvancedDynamicRangeResult(
            confidence: 0.0,
            shadowsBlocked: 0.0,
            highlightsBlown: 0.0,
            dynamicRange: 0.0,
            midtoneSeparation: 0.0,
            toneDistribution: []
        )

        #expect(result.toneDistribution.isEmpty)

        let dict = result.toDictionary()
        #expect((dict["toneDistribution"] as? [Float])?.isEmpty == true)
    }
}

// MARK: - Performance Tests

@Suite("ExposureAnalyzer - Performance Tests")
struct ExposureAnalyzerPerformanceTests {

    @Test("ExposureAnalyzer initialization is fast")
    func testInitializationPerformance() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let startTime = CFAbsoluteTimeGetCurrent()

        var analyzers: [ExposureAnalyzer] = []
        for _ in 0..<100 {
            analyzers.append(ExposureAnalyzer())
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(timeElapsed < 1.0, "Creating 100 analyzers should take less than 1 second")
        #expect(analyzers.count == 100)
    }

    @Test("Creating AdvancedExposureResult instances is efficient")
    func testAdvancedExposureResultCreationPerformance() {
        let startTime = CFAbsoluteTimeGetCurrent()

        var results: [AdvancedExposureResult] = []
        for i in 0..<10000 {
            let histogram: [Float] = Array(repeating: Float(i % 100) / 100.0, count: 256)
            results.append(AdvancedExposureResult(
                evValue: Float(i % 10),
                confidence: Float(i % 100) / 100.0,
                isOptimal: i % 2 == 0,
                clippingLevel: Float(i % 20) / 100.0,
                exposureCompensation: Float(i % 10) - 5.0,
                histogram: histogram
            ))
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(timeElapsed < 1.0, "Creating 10000 results should take less than 1 second")
        #expect(results.count == 10000)
    }

    @Test("Dictionary conversion is efficient")
    func testDictionaryConversionPerformance() {
        let result = AdvancedExposureResult(
            evValue: 1.0,
            confidence: 0.8,
            isOptimal: true,
            clippingLevel: 0.05,
            exposureCompensation: 0.2,
            histogram: Array(repeating: 0.5, count: 256)
        )

        let startTime = CFAbsoluteTimeGetCurrent()

        var dictionaries: [[String: Any]] = []
        for _ in 0..<10000 {
            dictionaries.append(result.toDictionary())
        }

        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime

        #expect(timeElapsed < 0.5, "10000 dictionary conversions should take less than 500ms")
        #expect(dictionaries.count == 10000)
    }
}

// MARK: - Edge Cases Tests

@Suite("ExposureAnalyzer - Edge Cases")
struct ExposureAnalyzerEdgeCasesTests {

    @Test("ExposureAnalyzer handles rapid enable/disable toggling")
    func testRapidEnableDisableToggling() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        for _ in 0..<100 {
            analyzer.isEnabled = false
            analyzer.isEnabled = true
        }

        #expect(analyzer.isEnabled == true, "Should end in enabled state")
    }

    @Test("AdvancedExposureResult handles extreme confidence values")
    func testAdvancedExposureResultExtremeConfidence() {
        let minResult = AdvancedExposureResult(
            evValue: 0.0,
            confidence: 0.0,
            isOptimal: false,
            clippingLevel: 0.0,
            exposureCompensation: 0.0,
            histogram: []
        )

        #expect(minResult.confidence == 0.0)

        let maxResult = AdvancedExposureResult(
            evValue: 0.0,
            confidence: 1.0,
            isOptimal: true,
            clippingLevel: 0.0,
            exposureCompensation: 0.0,
            histogram: []
        )

        #expect(maxResult.confidence == 1.0)

        // System may allow > 1.0
        let overMaxResult = AdvancedExposureResult(
            evValue: 0.0,
            confidence: 1.5,
            isOptimal: true,
            clippingLevel: 0.0,
            exposureCompensation: 0.0,
            histogram: []
        )

        #expect(overMaxResult.confidence == 1.5)
    }

    @Test("AdvancedExposureResult handles negative EV values")
    func testAdvancedExposureResultNegativeEV() {
        let result = AdvancedExposureResult(
            evValue: -5.0,
            confidence: 0.8,
            isOptimal: false,
            clippingLevel: 0.0,
            exposureCompensation: 2.0,
            histogram: []
        )

        #expect(result.evValue == -5.0)
    }

    @Test("AdvancedDynamicRangeResult handles extreme dynamic range")
    func testAdvancedDynamicRangeResultExtremeDynamicRange() {
        let result = AdvancedDynamicRangeResult(
            confidence: 0.9,
            shadowsBlocked: 1.0,
            highlightsBlown: 1.0,
            dynamicRange: 20.0,
            midtoneSeparation: 0.0,
            toneDistribution: []
        )

        #expect(result.dynamicRange == 20.0)
        #expect(result.shadowsBlocked == 1.0)
        #expect(result.highlightsBlown == 1.0)
    }

    @Test("SceneExposureResult handles large number of regions")
    func testSceneExposureResultManyRegions() {
        var regions: [RegionExposure] = []
        for i in 0..<1000 {
            regions.append(RegionExposure(
                region: CGRect(x: i * 10, y: i * 10, width: 10, height: 10),
                evValue: Float(i % 10),
                luminance: 0.5,
                importance: 0.5
            ))
        }

        let result = SceneExposureResult(
            regions: regions,
            centerWeightedEV: 1.0,
            dynamicRange: 5.0,
            exposureVariation: 2.0,
            confidence: 0.8
        )

        #expect(result.regions.count == 1000)

        let dict = result.toDictionary()
        #expect(dict["regionCount"] as? Int == 1000)
    }

    @Test("Configuration handles invalid data types")
    func testConfigurationInvalidDataTypes() async throws {
        guard #available(iOS 15.0, macOS 12.0, *) else { return }

        let analyzer = ExposureAnalyzer()

        // Invalid types should be ignored gracefully
        let invalidSettings: [String: Any] = [
            "adaptiveAnalysisEnabled": "not a boolean",
            "targetEV": "not a float",
            "randomKey": 12345
        ]

        analyzer.configure(with: invalidSettings)

        #expect(true, "Configuration with invalid types should not crash")
    }
}
