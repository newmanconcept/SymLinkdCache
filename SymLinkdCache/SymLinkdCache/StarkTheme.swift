//
//  StarkTheme.swift
//  SymLinkdCache
//
//  Created by Antigravity on 16/07/2026.
//

import SwiftUI

// MARK: - Color Palette
extension Color {
    public static let starkBg = Color.black
    public static let starkPanel = Color(white: 0.06)
    public static let starkBorder = Color(white: 0.22)
    public static let starkGrid = Color(white: 0.12)
    public static let starkText = Color.white
    public static let starkSubtext = Color(white: 0.55)
    public static let starkZinc = Color(white: 0.75)
    
    // State Colors (Strict Monochrome Accentuation)
    public static let starkSuccess = Color(red: 0.0, green: 1.0, blue: 0.0) // Pure Neon Green
    public static let starkWarning = Color(red: 1.0, green: 0.6, blue: 0.0) // Flat Amber
    public static let starkAlert = Color(red: 1.0, green: 0.0, blue: 0.0)   // Flat Red
}

// MARK: - Custom Button Styles
public struct StarkButtonStyle: ButtonStyle {
    public var isInverted: Bool = false
    public var isDisabled: Bool = false
    
    public init(isInverted: Bool = false, isDisabled: Bool = false) {
        self.isInverted = isInverted
        self.isDisabled = isDisabled
    }
    
    public func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(.body, design: .monospaced).bold())
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isInverted {
                        configuration.isPressed ? Color.starkZinc : Color.starkText
                    } else {
                        configuration.isPressed ? Color.starkBorder : Color.starkPanel
                    }
                }
            )
            .foregroundColor(isInverted ? Color.starkBg : Color.starkText)
            .overlay(
                Rectangle()
                    .stroke(Color.starkBorder, lineWidth: 1)
            )
            .animation(.none, value: configuration.isPressed)
    }
}

// MARK: - Custom UI Motifs
public struct StarkPanelModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .background(Color.starkPanel)
            .overlay(
                Rectangle()
                    .stroke(Color.starkBorder, lineWidth: 1)
            )
    }
}

extension View {
    public func starkPanel() -> some View {
        self.modifier(StarkPanelModifier())
    }
}

// MARK: - Flat Geometric Elements

/// A simple flat circular indicator that fills up based on relative size
public struct FlatCircularIndicator: View {
    public var fillRatio: Double // Value between 0.0 and 1.0
    
    public init(fillRatio: Double) {
        self.fillRatio = max(0.0, min(1.0, fillRatio))
    }
    
    public var body: some View {
        ZStack {
            Circle()
                .stroke(Color.starkBorder, lineWidth: 1.5)
                .frame(width: 14, height: 14)
            
            if fillRatio > 0 {
                Circle()
                    .fill(Color.starkText)
                    .frame(width: 14 * fillRatio, height: 14 * fillRatio)
            }
        }
        .frame(width: 16, height: 16)
    }
}

/// A neon dot for success or warning states
public struct StarkStatusDot: View {
    public var color: Color
    @State private var isFlashing = false
    public var flash: Bool = false
    
    public init(color: Color, flash: Bool = false) {
        self.color = color
        self.flash = flash
    }
    
    public var body: some View {
        Circle()
            .fill(color)
            .frame(width: 8, height: 8)
            .opacity(flash && isFlashing ? 0.3 : 1.0)
            .onAppear {
                if flash {
                    withAnimation(Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                        isFlashing = true
                    }
                }
            }
    }
}

/// A 1px dotted leader line for alignments
public struct DottedLeader: View {
    public init() {}
    public var body: some View {
        Line()
            .stroke(style: StrokeStyle(lineWidth: 1, lineCap: .round, lineJoin: .round, miterLimit: 10, dash: [1, 4], dashPhase: 0))
            .foregroundColor(Color.starkBorder)
            .frame(height: 1)
    }
    
    private struct Line: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            return path
        }
    }
}
