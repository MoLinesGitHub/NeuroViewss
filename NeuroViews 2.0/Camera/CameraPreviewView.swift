//
//  CameraPreviewView.swift
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Week 16: Core Camera Implementation
//

import SwiftUI
import AVFoundation

#if os(iOS)
import UIKit
typealias ViewRepresentable = UIViewRepresentable
typealias PlatformView = UIView
typealias PlatformColor = UIColor
typealias TapGestureRecognizer = UITapGestureRecognizer
typealias PlatformTransform = CGAffineTransform
#elseif os(macOS)
import AppKit
// Para macOS, necesitaremos una implementación diferente
// Por ahora, marcamos como no disponible
#endif

#if os(iOS)
struct CameraPreviewView: ViewRepresentable {
    
    let previewLayer: AVCaptureVideoPreviewLayer
    
    func makeUIView(context: Context) -> PlatformView {
        let view = PreviewView()
        view.previewLayer = previewLayer
        return view
    }
    
    func updateUIView(_ uiView: PlatformView, context: Context) {
        // Update if needed
    }
}
#endif

#if os(iOS)
// MARK: - PreviewView (UIKit)
class PreviewView: PlatformView {
    
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            guard let previewLayer = previewLayer else { return }
            
            layer.addSublayer(previewLayer)
            previewLayer.frame = bounds
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}
#endif

#if os(iOS)
// MARK: - Camera Preview with Tap to Focus
struct InteractiveCameraPreviewView: ViewRepresentable {
    
    let previewLayer: AVCaptureVideoPreviewLayer
    let onTapToFocus: (CGPoint, AVCaptureVideoPreviewLayer) -> Void
    
    func makeUIView(context: Context) -> PlatformView {
        let view = InteractivePreviewView()
        view.previewLayer = previewLayer
        view.onTapToFocus = onTapToFocus
        return view
    }
    
    func updateUIView(_ uiView: PlatformView, context: Context) {
        if let view = uiView as? InteractivePreviewView {
            view.onTapToFocus = onTapToFocus
        }
    }
}
#endif

#if os(iOS)
// MARK: - Interactive Preview View (UIKit)
class InteractivePreviewView: PlatformView {
    
    var previewLayer: AVCaptureVideoPreviewLayer? {
        didSet {
            guard let previewLayer = previewLayer else { return }
            
            layer.addSublayer(previewLayer)
            previewLayer.frame = bounds
            
            // Add tap gesture recognizer
            setupTapGesture()
        }
    }
    
    var onTapToFocus: ((CGPoint, AVCaptureVideoPreviewLayer) -> Void)?
    private var tapGesture: TapGestureRecognizer?
    
    private func setupTapGesture() {
        // Remove existing gesture if any
        if let existingGesture = tapGesture {
            removeGestureRecognizer(existingGesture)
        }
        
        // Add new tap gesture
        tapGesture = TapGestureRecognizer(target: self, action: #selector(handleTap(_:)))
        if let tapGesture = tapGesture {
            addGestureRecognizer(tapGesture)
        }
    }
    
    @objc private func handleTap(_ gesture: TapGestureRecognizer) {
        let tapPoint = gesture.location(in: self)
        
        // Show focus indicator animation
        showFocusIndicator(at: tapPoint)
        
        // Call focus handler
        if let previewLayer = previewLayer {
            onTapToFocus?(tapPoint, previewLayer)
        }
    }
    
    private func showFocusIndicator(at point: CGPoint) {
        let focusView = FocusIndicatorView()
        focusView.center = point
        addSubview(focusView)
        
        focusView.animateFocus { [weak self] in
            focusView.removeFromSuperview()
        }
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
}
#endif

#if os(iOS)
// MARK: - Focus Indicator View
class FocusIndicatorView: PlatformView {
    
    override init(frame: CGRect) {
        super.init(frame: CGRect(x: 0, y: 0, width: 80, height: 80))
        setupView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupView()
    }
    
    private func setupView() {
        backgroundColor = PlatformColor.clear
        layer.borderColor = PlatformColor.systemYellow.cgColor
        layer.borderWidth = 2
        layer.cornerRadius = 4
        alpha = 0
    }
    
    func animateFocus(completion: @escaping () -> Void) {
        // Initial scale animation
        transform = PlatformTransform(scaleX: 1.5, y: 1.5)
        
        PlatformView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut) {
            self.alpha = 1
            self.transform = PlatformTransform.identity
        } completion: { _ in
            // Hold for a moment
            PlatformView.animate(withDuration: 0.3, delay: 0.5, options: .curveEaseIn) {
                self.alpha = 0
            } completion: { _ in
                completion()
            }
        }
    }
}
#endif

#if os(iOS)
// MARK: - SwiftUI Preview Wrapper
struct CameraPreviewView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a mock preview layer for preview
        let mockSession = AVCaptureSession()
        let mockPreviewLayer = AVCaptureVideoPreviewLayer(session: mockSession)
        
        CameraPreviewView(previewLayer: mockPreviewLayer)
            .previewDisplayName("Camera Preview")
            .frame(width: 300, height: 400)
    }
}
#endif