import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

// MARK: - Advanced Camera Gestures

#if canImport(UIKit)
@available(iOS 15.0, macOS 12.0, *)
public struct AdvancedCameraGestures: UIViewRepresentable {
    
    @Binding var selectedGesture: CameraGesture?
    let onCapture: () async -> Void
    let onZoom: (CGFloat) async -> Void
    let onFocus: (CGPoint) async -> Void
    let onExposureAdjust: ((CGFloat) async -> Void)?
    let onModeSwitch: (() async -> Void)?
    
    public init(
        selectedGesture: Binding<CameraGesture?>,
        onCapture: @escaping () async -> Void,
        onZoom: @escaping (CGFloat) async -> Void,
        onFocus: @escaping (CGPoint) async -> Void,
        onExposureAdjust: ((CGFloat) async -> Void)? = nil,
        onModeSwitch: (() async -> Void)? = nil
    ) {
        self._selectedGesture = selectedGesture
        self.onCapture = onCapture
        self.onZoom = onZoom
        self.onFocus = onFocus
        self.onExposureAdjust = onExposureAdjust
        self.onModeSwitch = onModeSwitch
    }
    
    public func makeUIView(context: Context) -> UIView {
        let view = AdvancedGestureView()
        view.delegate = context.coordinator
        return view
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {
        // Update gesture state if needed
    }
    
    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Coordinator
    
    public class Coordinator: NSObject, AdvancedGestureViewDelegate {
        
        private let parent: AdvancedCameraGestures
        
        init(_ parent: AdvancedCameraGestures) {
            self.parent = parent
        }
        
        func didTapToFocus(at point: CGPoint) {
            parent.selectedGesture = .tap
            Task {
                await parent.onFocus(point)
            }
        }
        
        func didDoubleTap() {
            parent.selectedGesture = .doubleTap
            Task {
                await parent.onCapture()
            }
        }
        
        func didPinchToZoom(scale: CGFloat) {
            parent.selectedGesture = .pinch
            Task {
                await parent.onZoom(scale)
            }
        }
        
        func didPanForExposure(delta: CGFloat) {
            guard let onExposureAdjust = parent.onExposureAdjust else { return }
            parent.selectedGesture = .pan
            Task {
                await onExposureAdjust(delta)
            }
        }
        
        func didLongPress() {
            guard let onModeSwitch = parent.onModeSwitch else { return }
            parent.selectedGesture = .longPress
            Task {
                await onModeSwitch()
            }
        }
        
        func didPerformAdvancedGesture(_ gesture: AdvancedGestureType, data: GestureData) {
            Task {
                await handleAdvancedGesture(gesture, data: data)
            }
        }
        
        private func handleAdvancedGesture(_ gesture: AdvancedGestureType, data: GestureData) async {
            switch gesture {
            case .twoFingerTap:
                await parent.onModeSwitch?()
                
            case .threeFingerSwipeUp:
                // Switch to front camera
                break
                
            case .threeFingerSwipeDown:
                // Switch to back camera
                break
                
            case .circularRotation:
                // Adjust camera rotation
                await parent.onZoom(data.rotationAngle / 360.0 + 1.0)
                
            case .edgePan:
                // Quick settings panel
                break
                
            case .cornerTap:
                // AI assistant toggle
                break
            }
        }
    }
}

// MARK: - Advanced Gesture View

@available(iOS 15.0, macOS 12.0, *)
private class AdvancedGestureView: UIView {
    
    weak var delegate: AdvancedGestureViewDelegate?
    
    private var lastZoomScale: CGFloat = 1.0
    private var isExposurePanning = false
    private var panStartPoint: CGPoint = .zero
    private var circularRotationStart: CGFloat = 0
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupGestures()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupGestures()
    }
    
    private func setupGestures() {
        isMultipleTouchEnabled = true
        isUserInteractionEnabled = true
        
        // Single tap for focus
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(handleSingleTap(_:)))
        singleTap.numberOfTapsRequired = 1
        addGestureRecognizer(singleTap)
        
        // Double tap for capture
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(handleDoubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        addGestureRecognizer(doubleTap)
        
        // Two finger tap for mode switch
        let twoFingerTap = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap(_:)))
        twoFingerTap.numberOfTouchesRequired = 2
        twoFingerTap.numberOfTapsRequired = 1
        addGestureRecognizer(twoFingerTap)
        
        // Pinch for zoom
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinch)
        
        // Pan for exposure (single finger)
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        pan.minimumNumberOfTouches = 1
        pan.maximumNumberOfTouches = 1
        addGestureRecognizer(pan)
        
        // Long press
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        longPress.minimumPressDuration = 0.8
        addGestureRecognizer(longPress)
        
        // Three finger swipes
        let threeFingerSwipeUp = UISwipeGestureRecognizer(target: self, action: #selector(handleThreeFingerSwipeUp(_:)))
        threeFingerSwipeUp.numberOfTouchesRequired = 3
        threeFingerSwipeUp.direction = .up
        addGestureRecognizer(threeFingerSwipeUp)
        
        let threeFingerSwipeDown = UISwipeGestureRecognizer(target: self, action: #selector(handleThreeFingerSwipeDown(_:)))
        threeFingerSwipeDown.numberOfTouchesRequired = 3
        threeFingerSwipeDown.direction = .down
        addGestureRecognizer(threeFingerSwipeDown)
        
        // Rotation gesture for advanced control
        let rotation = UIRotationGestureRecognizer(target: self, action: #selector(handleRotation(_:)))
        addGestureRecognizer(rotation)
        
        // Edge pan gesture for quick settings
        let edgePan = UIScreenEdgePanGestureRecognizer(target: self, action: #selector(handleEdgePan(_:)))
        edgePan.edges = [.left, .right]
        addGestureRecognizer(edgePan)
        
        // Configure gesture priorities
        singleTap.require(toFail: doubleTap)
        pan.require(toFail: pinch)
    }
    
    // MARK: - Gesture Handlers
    
    @objc private func handleSingleTap(_ gesture: UITapGestureRecognizer) {
        let point = gesture.location(in: self)
        let normalizedPoint = CGPoint(
            x: point.x / bounds.width,
            y: point.y / bounds.height
        )
        
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        delegate?.didTapToFocus(at: normalizedPoint)
    }
    
    @objc private func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
        // Haptic feedback
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        delegate?.didDoubleTap()
    }
    
    @objc private func handleTwoFingerTap(_ gesture: UITapGestureRecognizer) {
        let data = GestureData(
            location: gesture.location(in: self),
            scale: 1.0,
            velocity: .zero,
            rotationAngle: 0
        )
        
        delegate?.didPerformAdvancedGesture(.twoFingerTap, data: data)
    }
    
    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            lastZoomScale = gesture.scale
            
        case .changed:
            let deltaScale = gesture.scale / lastZoomScale
            lastZoomScale = gesture.scale
            
            delegate?.didPinchToZoom(scale: deltaScale)
            
        case .ended, .cancelled:
            // Optional: Add zoom completion logic
            break
            
        default:
            break
        }
    }
    
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            panStartPoint = gesture.location(in: self)
            isExposurePanning = abs(gesture.velocity(in: self).y) > abs(gesture.velocity(in: self).x)
            
        case .changed:
            if isExposurePanning {
                let currentPoint = gesture.location(in: self)
                let deltaY = currentPoint.y - panStartPoint.y
                let normalizedDelta = -deltaY / bounds.height // Inverted for intuitive control
                
                delegate?.didPanForExposure(delta: normalizedDelta)
            }
            
        case .ended, .cancelled:
            isExposurePanning = false
            
        default:
            break
        }
    }
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        if gesture.state == .began {
            // Haptic feedback
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
            
            delegate?.didLongPress()
        }
    }
    
    @objc private func handleThreeFingerSwipeUp(_ gesture: UISwipeGestureRecognizer) {
        let data = GestureData(
            location: gesture.location(in: self),
            scale: 1.0,
            velocity: .zero,
            rotationAngle: 0
        )
        
        delegate?.didPerformAdvancedGesture(.threeFingerSwipeUp, data: data)
    }
    
    @objc private func handleThreeFingerSwipeDown(_ gesture: UISwipeGestureRecognizer) {
        let data = GestureData(
            location: gesture.location(in: self),
            scale: 1.0,
            velocity: .zero,
            rotationAngle: 0
        )
        
        delegate?.didPerformAdvancedGesture(.threeFingerSwipeDown, data: data)
    }
    
    @objc private func handleRotation(_ gesture: UIRotationGestureRecognizer) {
        switch gesture.state {
        case .began:
            circularRotationStart = gesture.rotation
            
        case .changed:
            let rotationDelta = gesture.rotation - circularRotationStart
            let data = GestureData(
                location: gesture.location(in: self),
                scale: 1.0,
                velocity: .zero,
                rotationAngle: rotationDelta * 180 / .pi // Convert to degrees
            )
            
            delegate?.didPerformAdvancedGesture(.circularRotation, data: data)
            
        case .ended, .cancelled:
            break
            
        default:
            break
        }
    }
    
    @objc private func handleEdgePan(_ gesture: UIScreenEdgePanGestureRecognizer) {
        if gesture.state == .began {
            let data = GestureData(
                location: gesture.location(in: self),
                scale: 1.0,
                velocity: gesture.velocity(in: self),
                rotationAngle: 0
            )
            
            delegate?.didPerformAdvancedGesture(.edgePan, data: data)
        }
    }
    
    // MARK: - Touch Events
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        
        // Check for corner taps
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        
        if isCornerTouch(location) {
            let data = GestureData(
                location: location,
                scale: 1.0,
                velocity: .zero,
                rotationAngle: 0
            )
            
            delegate?.didPerformAdvancedGesture(.cornerTap, data: data)
        }
    }
    
    private func isCornerTouch(_ location: CGPoint) -> Bool {
        let cornerRadius: CGFloat = 60
        let corners = [
            CGPoint(x: 0, y: 0),
            CGPoint(x: bounds.width, y: 0),
            CGPoint(x: 0, y: bounds.height),
            CGPoint(x: bounds.width, y: bounds.height)
        ]
        
        for corner in corners {
            let distance = sqrt(pow(location.x - corner.x, 2) + pow(location.y - corner.y, 2))
            if distance <= cornerRadius {
                return true
            }
        }
        
        return false
    }
}

// MARK: - Delegate Protocol

@available(iOS 15.0, macOS 12.0, *)
private protocol AdvancedGestureViewDelegate: AnyObject {
    func didTapToFocus(at point: CGPoint)
    func didDoubleTap()
    func didPinchToZoom(scale: CGFloat)
    func didPanForExposure(delta: CGFloat)
    func didLongPress()
    func didPerformAdvancedGesture(_ gesture: AdvancedGestureType, data: GestureData)
}

// MARK: - Supporting Types

@available(iOS 15.0, macOS 12.0, *)
public enum AdvancedGestureType: String, CaseIterable {
    case twoFingerTap = "two_finger_tap"
    case threeFingerSwipeUp = "three_finger_swipe_up"
    case threeFingerSwipeDown = "three_finger_swipe_down"
    case circularRotation = "circular_rotation"
    case edgePan = "edge_pan"
    case cornerTap = "corner_tap"
    
    public var displayName: String {
        switch self {
        case .twoFingerTap: return "Two Finger Tap"
        case .threeFingerSwipeUp: return "Three Finger Swipe Up"
        case .threeFingerSwipeDown: return "Three Finger Swipe Down"
        case .circularRotation: return "Circular Rotation"
        case .edgePan: return "Edge Pan"
        case .cornerTap: return "Corner Tap"
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
public struct GestureData {
    public let location: CGPoint
    public let scale: CGFloat
    public let velocity: CGPoint
    public let rotationAngle: CGFloat
    
    public init(location: CGPoint, scale: CGFloat, velocity: CGPoint, rotationAngle: CGFloat) {
        self.location = location
        self.scale = scale
        self.velocity = velocity
        self.rotationAngle = rotationAngle
    }
}

// MARK: - Gesture Configuration

@available(iOS 15.0, macOS 12.0, *)
public struct GestureConfiguration {
    
    public var isZoomEnabled = true
    public var isFocusEnabled = true
    public var isExposureAdjustmentEnabled = true
    public var isAdvancedGesturesEnabled = true
    public var minimumZoomScale: CGFloat = 0.5
    public var maximumZoomScale: CGFloat = 10.0
    public var hapticFeedbackEnabled = true
    
    public init() {}
}

// MARK: - Haptic Feedback Manager

@available(iOS 15.0, macOS 12.0, *)
public class HapticFeedbackManager {
    
    public static let shared = HapticFeedbackManager()
    
    private let lightFeedback = UIImpactFeedbackGenerator(style: .light)
    private let mediumFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let heavyFeedback = UIImpactFeedbackGenerator(style: .heavy)
    private let selectionFeedback = UISelectionFeedbackGenerator()
    private let notificationFeedback = UINotificationFeedbackGenerator()
    
    private init() {
        prepareFeedback()
    }
    
    public func prepareFeedback() {
        lightFeedback.prepare()
        mediumFeedback.prepare()
        heavyFeedback.prepare()
        selectionFeedback.prepare()
        notificationFeedback.prepare()
    }
    
    public func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        switch style {
        case .light:
            lightFeedback.impactOccurred()
        case .medium:
            mediumFeedback.impactOccurred()
        case .heavy:
            heavyFeedback.impactOccurred()
        @unknown default:
            mediumFeedback.impactOccurred()
        }
    }
    
    public func selection() {
        selectionFeedback.selectionChanged()
    }
    
    public func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        notificationFeedback.notificationOccurred(type)
    }
}
#endif