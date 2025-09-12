//
//  AdvancedCameraView.swift  
//  NeuroViews 2.0
//
//  Created by NeuroViews AI on 12/9/24.
//  Updated: Week 14 - Accessibility & Localization
//

import SwiftUI

@available(iOS 15.0, macOS 12.0, *)
struct AdvancedCameraView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: adaptiveSpacing) {
                    // Camera Icon with accessibility
                    Image(systemName: "camera.metering.center.weighted.average")
                        .font(.system(size: adaptiveIconSize))
                        .foregroundColor(.blue)
                        .accessibilityLabel(NSLocalizedString("camera.icon.label", 
                                          value: "NeuroViews Camera", 
                                          comment: "Camera interface icon"))
                    
                    // Title Section with Dynamic Type support
                    VStack(spacing: 12) {
                        Text(NSLocalizedString("advanced.camera.title", 
                                             value: "Advanced Camera Interface", 
                                             comment: "Main title for camera interface"))
                            .font(.title)
                            .fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        
                        Text(NSLocalizedString("advanced.camera.subtitle", 
                                             value: "AI-Powered Camera with Gesture Recognition", 
                                             comment: "Subtitle describing camera capabilities"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(NSLocalizedString("camera.title.combined", 
                                                        value: "Advanced Camera Interface. AI-Powered Camera with Gesture Recognition", 
                                                        comment: "Combined accessibility label for title section"))
                    
                    // Features List with enhanced accessibility
                    VStack(spacing: 16) {
                        AccessibleFeatureRow(
                            icon: "brain.head.profile", 
                            title: NSLocalizedString("feature.ai.title", value: "AI Guidance", comment: "AI feature title"),
                            description: NSLocalizedString("feature.ai.description", value: "Real-time shooting suggestions", comment: "AI feature description")
                        )
                        
                        AccessibleFeatureRow(
                            icon: "hand.tap.fill", 
                            title: NSLocalizedString("feature.gestures.title", value: "Advanced Gestures", comment: "Gestures feature title"),
                            description: NSLocalizedString("feature.gestures.description", value: "Tap, pinch, rotate controls", comment: "Gestures feature description")
                        )
                        
                        AccessibleFeatureRow(
                            icon: "camera.filters", 
                            title: NSLocalizedString("feature.processing.title", value: "Smart Processing", comment: "Processing feature title"),
                            description: NSLocalizedString("feature.processing.description", value: "Automatic enhancement", comment: "Processing feature description")
                        )
                        
                        AccessibleFeatureRow(
                            icon: "grid", 
                            title: NSLocalizedString("feature.grid.title", value: "Composition Grid", comment: "Grid feature title"),
                            description: NSLocalizedString("feature.grid.description", value: "Rule of thirds & golden ratio", comment: "Grid feature description")
                        )
                    }
                    .accessibilityElement(children: .contain)
                    .accessibilityLabel(NSLocalizedString("features.section.label", 
                                                        value: "Camera Features", 
                                                        comment: "Section label for camera features"))
                    
                    // Start Button with accessibility
                    Button(action: startCameraSession) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.title3)
                            Text(NSLocalizedString("start.camera.button", 
                                                 value: "Start Camera Session", 
                                                 comment: "Button to start camera"))
                        }
                        .padding()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .accessibilityLabel(NSLocalizedString("start.camera.accessibility", 
                                                        value: "Start Camera Session", 
                                                        comment: "Accessibility label for start button"))
                    .accessibilityHint(NSLocalizedString("start.camera.hint", 
                                                       value: "Double tap to begin advanced camera interface with AI guidance", 
                                                       comment: "Accessibility hint for start button"))
                    
                    // Status indicator
                    Text(NSLocalizedString("week.status", 
                                         value: "Week 14: Accessibility & Localization ✅", 
                                         comment: "Current week status"))
                        .font(.caption)
                        .foregroundColor(.green)
                        .fontWeight(.semibold)
                        .accessibilityLabel(NSLocalizedString("status.accessibility", 
                                                            value: "Current status: Week 14, Accessibility and Localization completed", 
                                                            comment: "Accessibility label for status"))
                    
                    Spacer(minLength: 20)
                }
                .padding(.horizontal, adaptivePadding)
            }
            .navigationTitle(NSLocalizedString("navigation.title", 
                                             value: "NeuroViews Camera", 
                                             comment: "Navigation bar title"))
        }
        #if os(iOS)
        .navigationViewStyle(.stack) // Better for accessibility on compact devices
        #endif
    }
    
    // MARK: - Adaptive Layout Properties
    
    private var adaptiveSpacing: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small, .medium:
            return 30
        case .large, .xLarge:
            return 35
        case .xxLarge, .xxxLarge:
            return 40
        default:
            return 45
        }
    }
    
    private var adaptiveIconSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 60
        case .medium, .large:
            return 80
        case .xLarge, .xxLarge:
            return 100
        default:
            return 120
        }
    }
    
    private var adaptivePadding: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small, .medium:
            return 24
        case .large, .xLarge:
            return 28
        default:
            return 32
        }
    }
    
    // MARK: - Actions
    
    private func startCameraSession() {
        print("🎥 Advanced Camera - Full integration pending NVAIKit linkage")
        
        // Accessibility announcement
        #if os(iOS)
        let announcement = NSLocalizedString("camera.starting.announcement", 
                                           value: "Camera interface starting", 
                                           comment: "Announcement when camera starts")
        UIAccessibility.post(notification: .announcement, argument: announcement)
        #endif
    }
}

// MARK: - Accessible Feature Row Component

struct AccessibleFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    var body: some View {
        HStack(spacing: adaptiveSpacing) {
            // Feature Icon
            Image(systemName: icon)
                .font(.system(size: adaptiveIconSize))
                .foregroundColor(.blue)
                .frame(width: adaptiveIconFrameSize, height: adaptiveIconFrameSize)
                .accessibilityHidden(true) // Icon is decorative, text provides context
            
            // Feature Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.leading)
                
                Text(description)
                    .font(adaptiveDescriptionFont)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Spacer(minLength: 8)
        }
        .padding(.vertical, 8)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title). \(description)")
        .accessibilityAddTraits(.isStaticText)
    }
    
    // MARK: - Adaptive Properties
    
    private var adaptiveSpacing: CGFloat {
        switch dynamicTypeSize {
        case .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return 20
        default:
            return 16
        }
    }
    
    private var adaptiveIconSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 18
        case .medium, .large:
            return 20
        case .xLarge, .xxLarge:
            return 24
        default:
            return 28
        }
    }
    
    private var adaptiveIconFrameSize: CGFloat {
        switch dynamicTypeSize {
        case .xSmall, .small:
            return 24
        case .medium, .large:
            return 28
        default:
            return 32
        }
    }
    
    private var adaptiveDescriptionFont: Font {
        switch dynamicTypeSize {
        case .xSmall, .small, .medium:
            return .caption
        case .large, .xLarge:
            return .footnote
        default:
            return .body
        }
    }
}

// MARK: - Legacy Feature Row (for compatibility)

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        AccessibleFeatureRow(icon: icon, title: title, description: description)
    }
}

#Preview {
    if #available(iOS 15.0, macOS 12.0, *) {
        AdvancedCameraView()
    } else {
        Text("Requires iOS 15.0+")
    }
}