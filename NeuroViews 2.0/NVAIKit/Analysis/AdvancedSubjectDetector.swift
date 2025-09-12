//
//  AdvancedSubjectDetector.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 18-19: AI Foundation - Advanced Subject Detection with Vision Framework
//

import Foundation
import CoreImage
import Vision
import AVFoundation
import CoreML

@available(iOS 15.0, macOS 12.0, *)
public final class AdvancedSubjectDetector: AIAnalyzer {
    public let analysisType: AIAnalysisType = .subject
    public var isEnabled: Bool = true
    
    private let requestHandler = VNSequenceRequestHandler()
    private var lastDetectedSubjects: [DetectedSubject] = []
    private var trackingRequests: [VNTrackObjectRequest] = []
    
    public struct AdvancedSubjectSettings {
        var faceDetectionEnabled: Bool = true
        var bodyDetectionEnabled: Bool = true
        var objectDetectionEnabled: Bool = true
        var animalDetectionEnabled: Bool = true
        var confidenceThreshold: Float = 0.5
        var maxTrackedObjects: Int = 10
        var trackingEnabled: Bool = true
        
        public init() {}
    }
    
    private var settings = AdvancedSubjectSettings()
    
    public struct DetectedSubject {
        let id: UUID
        let type: SubjectType
        let boundingBox: CGRect
        let confidence: Float
        let landmarks: [String: CGPoint]
        let attributes: [String: Any]
        let trackingID: UUID?
        
        public enum SubjectType: String, CaseIterable {
            case face = "face"
            case humanBody = "human_body"
            case animal = "animal"
            case object = "object"
            case text = "text"
            
            public var displayName: String {
                switch self {
                case .face: return "Face"
                case .humanBody: return "Person"
                case .animal: return "Animal"
                case .object: return "Object"
                case .text: return "Text"
                }
            }
        }
    }
    
    public struct AdvancedSubjectResult {
        let detectedSubjects: [DetectedSubject]
        let dominantSubject: DetectedSubject?
        let compositionAnalysis: CompositionAnalysis
        let focusRecommendation: FocusRecommendation
        let confidence: Float
        
        public struct CompositionAnalysis {
            let ruleOfThirdsCompliance: Float
            let subjectCentering: Float
            let backgroundClutter: Float
            let depthOfField: Float
            let leadingLines: Bool
        }
        
        public struct FocusRecommendation {
            let suggestedFocusPoint: CGPoint
            let reason: String
            let priority: SuggestionPriority
        }
    }
    
    public init() {}
    
    public func configure(with settings: [String: Any]) {
        if let faceDetection = settings["faceDetectionEnabled"] as? Bool {
            self.settings.faceDetectionEnabled = faceDetection
        }
        if let bodyDetection = settings["bodyDetectionEnabled"] as? Bool {
            self.settings.bodyDetectionEnabled = bodyDetection
        }
        if let objectDetection = settings["objectDetectionEnabled"] as? Bool {
            self.settings.objectDetectionEnabled = objectDetection
        }
        if let animalDetection = settings["animalDetectionEnabled"] as? Bool {
            self.settings.animalDetectionEnabled = animalDetection
        }
        if let threshold = settings["confidenceThreshold"] as? Float {
            self.settings.confidenceThreshold = threshold
        }
        if let maxTracked = settings["maxTrackedObjects"] as? Int {
            self.settings.maxTrackedObjects = maxTracked
        }
        if let tracking = settings["trackingEnabled"] as? Bool {
            self.settings.trackingEnabled = tracking
        }
    }
    
    public func analyze(frame: CVPixelBuffer) -> AIAnalysis? {
        guard isEnabled else { return nil }
        
        let ciImage = CIImage(cvPixelBuffer: frame)
        let subjectResult = performAdvancedSubjectDetection(image: ciImage)
        
        let suggestions = generateSubjectSuggestions(from: subjectResult)
        let confidence = subjectResult.confidence
        
        let analysisData: [String: Any] = [
            "detected_subjects": subjectResult.detectedSubjects.map { subject in
                [
                    "type": subject.type.rawValue,
                    "confidence": subject.confidence,
                    "bounding_box": [
                        "x": subject.boundingBox.origin.x,
                        "y": subject.boundingBox.origin.y,
                        "width": subject.boundingBox.width,
                        "height": subject.boundingBox.height
                    ]
                ]
            },
            "dominant_subject": subjectResult.dominantSubject?.type.rawValue ?? "",
            "composition_score": subjectResult.compositionAnalysis.ruleOfThirdsCompliance,
            "focus_point": [
                "x": subjectResult.focusRecommendation.suggestedFocusPoint.x,
                "y": subjectResult.focusRecommendation.suggestedFocusPoint.y
            ]
        ]
        
        return AIAnalysis(
            type: .subject,
            confidence: confidence,
            data: analysisData,
            suggestions: suggestions
        )
    }
    
    private func performAdvancedSubjectDetection(image: CIImage) -> AdvancedSubjectResult {
        var detectedSubjects: [DetectedSubject] = []
        
        // Create Vision requests
        var requests: [VNRequest] = []
        
        if settings.faceDetectionEnabled {
            requests.append(contentsOf: createFaceDetectionRequests())
        }
        
        if settings.bodyDetectionEnabled {
            requests.append(contentsOf: createBodyDetectionRequests())
        }
        
        if settings.objectDetectionEnabled {
            requests.append(contentsOf: createObjectDetectionRequests())
        }
        
        if settings.animalDetectionEnabled {
            requests.append(contentsOf: createAnimalDetectionRequests())
        }
        
        // Perform detection
        let imageRequestHandler = VNImageRequestHandler(ciImage: image, options: [:])
        
        do {
            try imageRequestHandler.perform(requests)
            
            // Process results
            for request in requests {
                detectedSubjects.append(contentsOf: processVisionResults(from: request))
            }
            
        } catch {
            print("❌ Vision analysis failed: \(error)")
        }
        
        // Update tracking if enabled
        if settings.trackingEnabled {
            updateObjectTracking(detectedSubjects: detectedSubjects, image: image)
        }
        
        // Find dominant subject
        let dominantSubject = findDominantSubject(from: detectedSubjects)
        
        // Analyze composition
        let compositionAnalysis = analyzeComposition(subjects: detectedSubjects, imageSize: image.extent.size)
        
        // Generate focus recommendation
        let focusRecommendation = generateFocusRecommendation(
            subjects: detectedSubjects,
            composition: compositionAnalysis
        )
        
        // Calculate overall confidence
        let confidence = calculateOverallConfidence(subjects: detectedSubjects)
        
        return AdvancedSubjectResult(
            detectedSubjects: detectedSubjects,
            dominantSubject: dominantSubject,
            compositionAnalysis: compositionAnalysis,
            focusRecommendation: focusRecommendation,
            confidence: confidence
        )
    }
    
    // MARK: - Vision Request Creation
    
    private func createFaceDetectionRequests() -> [VNRequest] {
        let faceDetectionRequest = VNDetectFaceRectanglesRequest()
        faceDetectionRequest.revision = VNDetectFaceRectanglesRequestRevision3
        
        let faceLandmarksRequest = VNDetectFaceLandmarksRequest()
        faceLandmarksRequest.revision = VNDetectFaceLandmarksRequestRevision3
        
        return [faceDetectionRequest, faceLandmarksRequest]
    }
    
    private func createBodyDetectionRequests() -> [VNRequest] {
        let humanBodyRequest = VNDetectHumanRectanglesRequest()
        
        let bodyPoseRequest = VNDetectHumanBodyPoseRequest()
        bodyPoseRequest.revision = VNDetectHumanBodyPoseRequestRevision1
        
        return [humanBodyRequest, bodyPoseRequest]
    }
    
    private func createObjectDetectionRequests() -> [VNRequest] {
        // Generic object detection using VNRecognizeObjectsRequest
        let objectRecognitionRequest = VNRecognizeObjectsRequest()
        objectRecognitionRequest.maximumObservations = settings.maxTrackedObjects
        
        // Text detection
        let textDetectionRequest = VNDetectTextRectanglesRequest()
        textDetectionRequest.reportCharacterBoxes = true
        
        return [objectRecognitionRequest, textDetectionRequest]
    }
    
    private func createAnimalDetectionRequests() -> [VNRequest] {
        let animalDetectionRequest = VNRecognizeAnimalsRequest()
        animalDetectionRequest.revision = VNRecognizeAnimalsRequestRevision1
        
        return [animalDetectionRequest]
    }
    
    // MARK: - Result Processing
    
    private func processVisionResults(from request: VNRequest) -> [DetectedSubject] {
        var subjects: [DetectedSubject] = []
        
        switch request {
        case let faceRequest as VNDetectFaceRectanglesRequest:
            subjects.append(contentsOf: processFaceResults(faceRequest.results))
            
        case let landmarksRequest as VNDetectFaceLandmarksRequest:
            subjects.append(contentsOf: processFaceLandmarksResults(landmarksRequest.results))
            
        case let bodyRequest as VNDetectHumanRectanglesRequest:
            subjects.append(contentsOf: processHumanBodyResults(bodyRequest.results))
            
        case let poseRequest as VNDetectHumanBodyPoseRequest:
            subjects.append(contentsOf: processBodyPoseResults(poseRequest.results))
            
        case let objectRequest as VNRecognizeObjectsRequest:
            subjects.append(contentsOf: processObjectResults(objectRequest.results))
            
        case let textRequest as VNDetectTextRectanglesRequest:
            subjects.append(contentsOf: processTextResults(textRequest.results))
            
        case let animalRequest as VNRecognizeAnimalsRequest:
            subjects.append(contentsOf: processAnimalResults(animalRequest.results))
            
        default:
            break
        }
        
        return subjects.filter { $0.confidence >= settings.confidenceThreshold }
    }
    
    private func processFaceResults(_ results: [VNFaceObservation]?) -> [DetectedSubject] {
        guard let results = results else { return [] }
        
        return results.map { observation in
            DetectedSubject(
                id: UUID(),
                type: .face,
                boundingBox: observation.boundingBox,
                confidence: observation.confidence,
                landmarks: extractFaceLandmarks(observation),
                attributes: [
                    "yaw": observation.yaw?.doubleValue ?? 0.0,
                    "pitch": observation.pitch?.doubleValue ?? 0.0,
                    "roll": observation.roll?.doubleValue ?? 0.0
                ],
                trackingID: nil
            )
        }
    }
    
    private func processFaceLandmarksResults(_ results: [VNFaceObservation]?) -> [DetectedSubject] {
        guard let results = results else { return [] }
        
        return results.compactMap { observation in
            guard let landmarks = observation.landmarks else { return nil }
            
            let landmarkPoints = extractDetailedFaceLandmarks(landmarks)
            
            return DetectedSubject(
                id: UUID(),
                type: .face,
                boundingBox: observation.boundingBox,
                confidence: observation.confidence,
                landmarks: landmarkPoints,
                attributes: [
                    "has_landmarks": true,
                    "landmark_count": landmarkPoints.count
                ],
                trackingID: nil
            )
        }
    }
    
    private func processHumanBodyResults(_ results: [VNHumanObservation]?) -> [DetectedSubject] {
        guard let results = results else { return [] }
        
        return results.map { observation in
            DetectedSubject(
                id: UUID(),
                type: .humanBody,
                boundingBox: observation.boundingBox,
                confidence: observation.confidence,
                landmarks: [:],
                attributes: [:],
                trackingID: nil
            )
        }
    }
    
    private func processBodyPoseResults(_ results: [VNHumanBodyPoseObservation]?) -> [DetectedSubject] {
        guard let results = results else { return [] }
        
        return results.compactMap { observation in
            let jointsLandmarks = extractBodyJoints(observation)
            
            return DetectedSubject(
                id: UUID(),
                type: .humanBody,
                boundingBox: observation.boundingBox,
                confidence: observation.confidence,
                landmarks: jointsLandmarks,
                attributes: [
                    "has_pose": true,
                    "joint_count": jointsLandmarks.count
                ],
                trackingID: nil
            )
        }
    }
    
    private func processObjectResults(_ results: [VNRecognizedObjectObservation]?) -> [DetectedSubject] {
        guard let results = results else { return [] }
        
        return results.map { observation in
            let topLabel = observation.labels.first
            
            return DetectedSubject(
                id: UUID(),
                type: .object,
                boundingBox: observation.boundingBox,
                confidence: topLabel?.confidence ?? observation.confidence,
                landmarks: [:],
                attributes: [
                    "label": topLabel?.identifier ?? "unknown",
                    "labels": observation.labels.map { ["identifier": $0.identifier, "confidence": $0.confidence] }
                ],
                trackingID: nil
            )
        }
    }
    
    private func processTextResults(_ results: [VNTextObservation]?) -> [DetectedSubject] {
        guard let results = results else { return [] }
        
        return results.map { observation in
            DetectedSubject(
                id: UUID(),
                type: .text,
                boundingBox: observation.boundingBox,
                confidence: observation.confidence,
                landmarks: [:],
                attributes: [
                    "character_boxes": observation.characterBoxes?.count ?? 0
                ],
                trackingID: nil
            )
        }
    }
    
    private func processAnimalResults(_ results: [VNRecognizedObjectObservation]?) -> [DetectedSubject] {
        guard let results = results else { return [] }
        
        return results.map { observation in
            let topLabel = observation.labels.first
            
            return DetectedSubject(
                id: UUID(),
                type: .animal,
                boundingBox: observation.boundingBox,
                confidence: topLabel?.confidence ?? observation.confidence,
                landmarks: [:],
                attributes: [
                    "animal_type": topLabel?.identifier ?? "unknown",
                    "labels": observation.labels.map { ["identifier": $0.identifier, "confidence": $0.confidence] }
                ],
                trackingID: nil
            )
        }
    }
    
    // MARK: - Landmark Extraction
    
    private func extractFaceLandmarks(_ observation: VNFaceObservation) -> [String: CGPoint] {
        var landmarks: [String: CGPoint] = [:]
        
        if let leftEye = observation.landmarks?.leftEye {
            landmarks["left_eye"] = leftEye.normalizedPoints.first ?? .zero
        }
        
        if let rightEye = observation.landmarks?.rightEye {
            landmarks["right_eye"] = rightEye.normalizedPoints.first ?? .zero
        }
        
        if let nose = observation.landmarks?.nose {
            landmarks["nose"] = nose.normalizedPoints.first ?? .zero
        }
        
        if let mouth = observation.landmarks?.outerLips {
            landmarks["mouth"] = mouth.normalizedPoints.first ?? .zero
        }
        
        return landmarks
    }
    
    private func extractDetailedFaceLandmarks(_ landmarks: VNFaceLandmarks2D) -> [String: CGPoint] {
        var landmarkPoints: [String: CGPoint] = [:]
        
        // Eyes
        if let leftEye = landmarks.leftEye {
            for (index, point) in leftEye.normalizedPoints.enumerated() {
                landmarkPoints["left_eye_\(index)"] = point
            }
        }
        
        if let rightEye = landmarks.rightEye {
            for (index, point) in rightEye.normalizedPoints.enumerated() {
                landmarkPoints["right_eye_\(index)"] = point
            }
        }
        
        // Eyebrows
        if let leftEyebrow = landmarks.leftEyebrow {
            for (index, point) in leftEyebrow.normalizedPoints.enumerated() {
                landmarkPoints["left_eyebrow_\(index)"] = point
            }
        }
        
        if let rightEyebrow = landmarks.rightEyebrow {
            for (index, point) in rightEyebrow.normalizedPoints.enumerated() {
                landmarkPoints["right_eyebrow_\(index)"] = point
            }
        }
        
        // Nose
        if let nose = landmarks.nose {
            for (index, point) in nose.normalizedPoints.enumerated() {
                landmarkPoints["nose_\(index)"] = point
            }
        }
        
        // Mouth
        if let outerLips = landmarks.outerLips {
            for (index, point) in outerLips.normalizedPoints.enumerated() {
                landmarkPoints["outer_lips_\(index)"] = point
            }
        }
        
        if let innerLips = landmarks.innerLips {
            for (index, point) in innerLips.normalizedPoints.enumerated() {
                landmarkPoints["inner_lips_\(index)"] = point
            }
        }
        
        // Face contour
        if let faceContour = landmarks.faceContour {
            for (index, point) in faceContour.normalizedPoints.enumerated() {
                landmarkPoints["face_contour_\(index)"] = point
            }
        }
        
        return landmarkPoints
    }
    
    private func extractBodyJoints(_ observation: VNHumanBodyPoseObservation) -> [String: CGPoint] {
        var joints: [String: CGPoint] = [:]
        
        let jointNames: [VNHumanBodyPoseObservation.JointName] = [
            .head, .neck,
            .leftShoulder, .rightShoulder,
            .leftElbow, .rightElbow,
            .leftWrist, .rightWrist,
            .hip, .leftHip, .rightHip,
            .leftKnee, .rightKnee,
            .leftAnkle, .rightAnkle
        ]
        
        for jointName in jointNames {
            do {
                let joint = try observation.recognizedPoint(jointName)
                if joint.confidence > settings.confidenceThreshold {
                    joints[jointName.rawValue] = joint.location
                }
            } catch {
                continue
            }
        }
        
        return joints
    }
    
    // MARK: - Analysis Methods
    
    private func findDominantSubject(from subjects: [DetectedSubject]) -> DetectedSubject? {
        return subjects.max { lhs, rhs in
            let lhsScore = calculateSubjectImportanceScore(lhs)
            let rhsScore = calculateSubjectImportanceScore(rhs)
            return lhsScore < rhsScore
        }
    }
    
    private func calculateSubjectImportanceScore(_ subject: DetectedSubject) -> Float {
        var score = subject.confidence
        
        // Boost score based on subject type
        switch subject.type {
        case .face:
            score *= 2.0 // Faces are most important
        case .humanBody:
            score *= 1.8
        case .animal:
            score *= 1.5
        case .object:
            score *= 1.0
        case .text:
            score *= 0.8
        }
        
        // Boost score based on size
        let area = subject.boundingBox.width * subject.boundingBox.height
        score *= Float(area * 2.0) // Larger subjects are more important
        
        // Boost score based on center positioning
        let centerX = subject.boundingBox.midX
        let centerY = subject.boundingBox.midY
        let distanceFromCenter = sqrt(pow(centerX - 0.5, 2) + pow(centerY - 0.5, 2))
        score *= Float(1.0 - distanceFromCenter * 0.5)
        
        return score
    }
    
    private func analyzeComposition(subjects: [DetectedSubject], imageSize: CGSize) -> AdvancedSubjectResult.CompositionAnalysis {
        let ruleOfThirdsCompliance = calculateRuleOfThirdsCompliance(subjects: subjects)
        let subjectCentering = calculateSubjectCentering(subjects: subjects)
        let backgroundClutter = calculateBackgroundClutter(subjects: subjects)
        let depthOfField = calculateDepthOfFieldScore(subjects: subjects)
        let leadingLines = detectLeadingLines(subjects: subjects)
        
        return AdvancedSubjectResult.CompositionAnalysis(
            ruleOfThirdsCompliance: ruleOfThirdsCompliance,
            subjectCentering: subjectCentering,
            backgroundClutter: backgroundClutter,
            depthOfField: depthOfField,
            leadingLines: leadingLines
        )
    }
    
    private func calculateRuleOfThirdsCompliance(subjects: [DetectedSubject]) -> Float {
        guard !subjects.isEmpty else { return 0.0 }
        
        let thirdLines: [CGFloat] = [1.0/3.0, 2.0/3.0]
        var totalCompliance: Float = 0.0
        
        for subject in subjects {
            let centerX = subject.boundingBox.midX
            let centerY = subject.boundingBox.midY
            
            let xCompliance = thirdLines.map { line in
                1.0 - abs(centerX - line)
            }.max() ?? 0.0
            
            let yCompliance = thirdLines.map { line in
                1.0 - abs(centerY - line)
            }.max() ?? 0.0
            
            totalCompliance += Float(max(xCompliance, yCompliance))
        }
        
        return totalCompliance / Float(subjects.count)
    }
    
    private func calculateSubjectCentering(subjects: [DetectedSubject]) -> Float {
        guard !subjects.isEmpty else { return 0.0 }
        
        var totalCentering: Float = 0.0
        
        for subject in subjects {
            let centerX = subject.boundingBox.midX
            let centerY = subject.boundingBox.midY
            let distanceFromCenter = sqrt(pow(centerX - 0.5, 2) + pow(centerY - 0.5, 2))
            totalCentering += Float(1.0 - distanceFromCenter)
        }
        
        return totalCentering / Float(subjects.count)
    }
    
    private func calculateBackgroundClutter(subjects: [DetectedSubject]) -> Float {
        // More objects = more clutter
        let objectCount = subjects.count
        if objectCount <= 1 {
            return 0.0 // No clutter
        } else if objectCount <= 3 {
            return 0.3 // Low clutter
        } else if objectCount <= 6 {
            return 0.6 // Medium clutter
        } else {
            return 1.0 // High clutter
        }
    }
    
    private func calculateDepthOfFieldScore(subjects: [DetectedSubject]) -> Float {
        // Simplified depth of field calculation
        // In a real implementation, this would analyze blur gradients
        return 0.7 // Placeholder
    }
    
    private func detectLeadingLines(subjects: [DetectedSubject]) -> Bool {
        // Simplified leading lines detection
        // In a real implementation, this would use edge detection
        return subjects.count >= 2 // Placeholder
    }
    
    private func generateFocusRecommendation(
        subjects: [DetectedSubject],
        composition: AdvancedSubjectResult.CompositionAnalysis
    ) -> AdvancedSubjectResult.FocusRecommendation {
        
        if let dominantSubject = subjects.max(by: { calculateSubjectImportanceScore($0) < calculateSubjectImportanceScore($1) }) {
            let focusPoint = CGPoint(
                x: dominantSubject.boundingBox.midX,
                y: dominantSubject.boundingBox.midY
            )
            
            let reason: String
            let priority: SuggestionPriority
            
            switch dominantSubject.type {
            case .face:
                reason = "Focus on the face for sharp portrait"
                priority = .high
            case .humanBody:
                reason = "Focus on the person for clear subject"
                priority = .medium
            case .animal:
                reason = "Focus on the animal's eyes or head"
                priority = .high
            case .object:
                reason = "Focus on the main object"
                priority = .medium
            case .text:
                reason = "Focus on text for readability"
                priority = .medium
            }
            
            return AdvancedSubjectResult.FocusRecommendation(
                suggestedFocusPoint: focusPoint,
                reason: reason,
                priority: priority
            )
        } else {
            return AdvancedSubjectResult.FocusRecommendation(
                suggestedFocusPoint: CGPoint(x: 0.5, y: 0.5),
                reason: "Focus on center of frame",
                priority: .low
            )
        }
    }
    
    private func calculateOverallConfidence(subjects: [DetectedSubject]) -> Float {
        guard !subjects.isEmpty else { return 0.0 }
        
        let totalConfidence = subjects.reduce(0.0) { $0 + $1.confidence }
        return totalConfidence / Float(subjects.count)
    }
    
    // MARK: - Object Tracking
    
    private func updateObjectTracking(detectedSubjects: [DetectedSubject], image: CIImage) {
        guard settings.trackingEnabled else { return }
        
        // Create tracking requests for new subjects
        for subject in detectedSubjects.prefix(settings.maxTrackedObjects) {
            if trackingRequests.count < settings.maxTrackedObjects {
                let trackingRequest = VNTrackObjectRequest(detectedObjectObservation: createObservationForTracking(subject))
                trackingRequests.append(trackingRequest)
            }
        }
        
        // Update existing tracking
        if !trackingRequests.isEmpty {
            do {
                try requestHandler.perform(trackingRequests, on: image)
            } catch {
                print("❌ Object tracking failed: \(error)")
            }
        }
    }
    
    private func createObservationForTracking(_ subject: DetectedSubject) -> VNDetectedObjectObservation {
        return VNDetectedObjectObservation(boundingBox: subject.boundingBox)
    }
    
    // MARK: - Suggestion Generation
    
    private func generateSubjectSuggestions(from result: AdvancedSubjectResult) -> [AISuggestion] {
        var suggestions: [AISuggestion] = []
        
        // Composition suggestions
        if result.compositionAnalysis.ruleOfThirdsCompliance < 0.3 {
            suggestions.append(AISuggestion(
                type: .composition,
                title: "Rule of Thirds",
                message: "Try positioning your subject along the grid lines for better composition",
                confidence: 0.8,
                priority: .medium
            ))
        }
        
        // Subject detection suggestions
        if result.detectedSubjects.isEmpty {
            suggestions.append(AISuggestion(
                type: .composition,
                title: "No Subject Detected",
                message: "Move closer to your subject or ensure good lighting",
                confidence: 0.9,
                priority: .high
            ))
        } else if let dominantSubject = result.dominantSubject {
            // Subject-specific suggestions
            switch dominantSubject.type {
            case .face:
                if dominantSubject.confidence < 0.7 {
                    suggestions.append(AISuggestion(
                        type: .lighting,
                        title: "Face Detection",
                        message: "Improve lighting to better detect facial features",
                        confidence: 0.7,
                        priority: .medium
                    ))
                }
                
                suggestions.append(AISuggestion(
                    type: .focus,
                    title: "Portrait Focus",
                    message: "Tap to focus on the eyes for sharp portrait",
                    confidence: 0.9,
                    priority: .high
                ))
                
            case .humanBody:
                suggestions.append(AISuggestion(
                    type: .composition,
                    title: "Full Body Shot",
                    message: "Consider the full figure in frame for better composition",
                    confidence: 0.7,
                    priority: .medium
                ))
                
            case .animal:
                suggestions.append(AISuggestion(
                    type: .focus,
                    title: "Animal Photography",
                    message: "Focus on the animal's eyes for engaging shots",
                    confidence: 0.8,
                    priority: .high
                ))
                
            case .object, .text:
                suggestions.append(AISuggestion(
                    type: .composition,
                    title: "Object Framing",
                    message: "Ensure the object is well-framed and properly lit",
                    confidence: 0.6,
                    priority: .medium
                ))
            }
        }
        
        // Background clutter suggestion
        if result.compositionAnalysis.backgroundClutter > 0.7 {
            suggestions.append(AISuggestion(
                type: .composition,
                title: "Background Clutter",
                message: "Simplify the background to make your subject stand out",
                confidence: 0.8,
                priority: .medium
            ))
        }
        
        // Focus recommendation
        suggestions.append(AISuggestion(
            type: .focus,
            title: result.focusRecommendation.reason,
            message: "Tap at (\(Int(result.focusRecommendation.suggestedFocusPoint.x * 100))%, \(Int(result.focusRecommendation.suggestedFocusPoint.y * 100))%) to focus",
            confidence: 0.9,
            priority: result.focusRecommendation.priority
        ))
        
        return suggestions
    }
}