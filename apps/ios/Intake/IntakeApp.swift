//
//  IntakeApp.swift
//  Intake
//
//  Created by Sidharth on 5/24/2026.
//  Copyright © 2026 Intake. All rights reserved.
//

import SwiftUI
import SwiftData

@main
struct IntakeApp: App {
    @State private var viewModel = IntakeViewModel()

    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.black.ignoresSafeArea()
                
                switch viewModel.activeView {
                case .camera:
                    CameraView(viewModel: viewModel)
                        .transition(.opacity)
                case .review:
                    ReviewView(viewModel: viewModel)
                        .transition(.asymmetric(
                            alignmentHelper: .bottom
                        ))
                case .telemetry:
                    TelemetryView(viewModel: viewModel)
                        .transition(.asymmetric(
                            alignmentHelper: .trailing
                        ))
                case .analyzing:
                    analyzingLoaderOverlay
                        .transition(.opacity)
                }
            }
            .intakeStatusBarHidden()
            .preferredColorScheme(.dark)
            .modelContainer(for: [
                FoodEvent.self,
                MealItem.self,
                EstimateVersion.self,
                PersonalMemory.self,
                DailyRollup.self
            ])
        }
    }
    
    private var analyzingLoaderOverlay: some View {
        VStack(spacing: 32) {
            Spacer()
            
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.06), lineWidth: 4)
                    .frame(width: 80, height: 80)
                
                Circle()
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "ff6b35"), Color(hex: "ff8c42")]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                
                Image(systemName: "activity")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(Color(hex: "ff6b35"))
            }
            
            VStack(spacing: 8) {
                Text("Analyzing Meal")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text("Estimating ingredients and portions")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "9ca3af"))
            }
            
            VStack(alignment: .leading, spacing: 16) {
                ForEach([
                    (1, "Uploading Photo", "Sending the selected image"),
                    (2, "Estimating Nutrition", "Reading ingredients and portions"),
                    (3, "Preparing Review", "Building the correction question")
                ], id: \.0) { step in
                    let isActive = viewModel.analysisStage == step.0
                    let isCompleted = viewModel.analysisStage > step.0
                    
                    HStack(alignment: .top, spacing: 12) {
                        ZStack {
                            if isCompleted {
                                Circle()
                                    .fill(Color(hex: "10b981"))
                                    .frame(width: 18, height: 18)
                                Image(systemName: "checkmark")
                                    .font(.system(size: 8, weight: .black))
                                    .foregroundColor(.white)
                            } else {
                                Circle()
                                    .fill(isActive ? Color(hex: "ff6b35").opacity(0.12) : Color.white.opacity(0.04))
                                    .frame(width: 18, height: 18)
                                    .overlay(
                                        Circle()
                                            .stroke(isActive ? Color(hex: "ff6b35") : Color.white.opacity(0.1), lineWidth: 1.5)
                                    )
                                Text("\(step.0)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(isActive ? Color(hex: "ff6b35") : Color(hex: "9ca3af"))
                            }
                        }
                        .padding(.top, 2)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(step.1)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(isCompleted ? Color(hex: "10b981") : (isActive ? Color(hex: "ff6b35") : .white.opacity(0.8)))
                            
                            Text(step.2)
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "9ca3af"))
                        }
                    }
                    .opacity(isActive ? 1.0 : (isCompleted ? 0.9 : 0.3))
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
            .background(Color.white.opacity(0.02))
            .cornerRadius(24)
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "07080a"))
    }
}

// SwiftUI transition extensions
extension AnyTransition {
    static func asymmetric(alignmentHelper: Edge) -> AnyTransition {
        .asymmetric(
            insertion: .move(edge: alignmentHelper == .bottom ? .bottom : .trailing),
            removal: .move(edge: alignmentHelper == .bottom ? .top : .leading)
        )
    }
}

// SwiftUI Color Hex Initializer
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, ((int >> 8) & 0xf) * 17, ((int >> 4) & 0xf) * 17, (int & 0xf) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, (int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = ((int >> 24) & 0xff, (int >> 16) & 0xff, (int >> 8) & 0xff, int & 0xff)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

extension View {
    @ViewBuilder
    func intakeStatusBarHidden() -> some View {
        #if os(iOS)
        self.statusBar(hidden: true)
        #else
        self
        #endif
    }

    func intakeTouchTarget(_ size: CGFloat = 44) -> some View {
        frame(minWidth: size, minHeight: size)
            .contentShape(Rectangle())
    }

    @ViewBuilder
    func intakeGlassPanel(cornerRadius: CGFloat, fallbackColor: Color = Color(hex: "101216").opacity(0.82)) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            self.glassEffect(.regular.interactive(false), in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(
                fallbackColor,
                in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            )
        }
    }
}
