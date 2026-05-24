//
//  CameraView.swift
//  Intake
//
//  Created by Sidharth on 5/24/2026.
//  Copyright © 2026 Intake. All rights reserved.
//

import SwiftUI

public struct CameraView: View {
    // Modern iOS 17+ @Bindable wrapper for Observation properties
    @Bindable var viewModel: IntakeViewModel
    @State private var activeCaptureSelection: String = "kerala_lunch"
    @State private var shutterPressed = false

    public var body: some View {
        ZStack {
            // 1. Simulated Camera Viewfinder Ingestion Area
            viewfinderMock
                .ignoresSafeArea()
            
            // 2. Camera Grid Overlay
            viewfinderGridLines
                .ignoresSafeArea()
                .opacity(0.15)
            
            // 3. Main Screen UI Layout
            VStack(spacing: 0) {
                // Top floating telemetry dashboard rollup
                floatingDashboardOverlay
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                
                // Offline queuing banner if offline
                if !viewModel.isOnline {
                    offlineQueueBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
                
                // Voice logging annotation helper banner
                if viewModel.voiceAnnotationEnabled && activeCaptureSelection == "kerala_lunch" {
                    voiceLogAnnotationBanner
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }
                
                // Quick Capture Target Flow Selector
                flowPickerSelector
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                
                // Bottom Shutter Controls Panel
                bottomShutterPanel
            }
        }
        .background(Color.black)
    }
    
    // MARK: - View Sub-Components
    
    private var viewfinderMock: some View {
        GeometryReader { geo in
            ZStack {
                if activeCaptureSelection == "kerala_lunch" {
                    Color.gray.opacity(0.1)
                    Text("🍛")
                        .font(.system(size: 110))
                        .offset(y: -40)
                    Text("Focus Target: Kerala Meals")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                        .offset(y: 40)
                } else if activeCaptureSelection == "banana_chips" {
                    Color.gray.opacity(0.1)
                    Text("🏷️")
                        .font(.system(size: 110))
                        .offset(y: -40)
                    Text("Focus Target: Packaged OCR Label")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.gray)
                        .offset(y: 40)
                } else {
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "0b0c0e"), Color(hex: "1e1b4b")]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    Text("🎙️")
                        .font(.system(size: 90))
                        .offset(y: -30)
                    Text("Capture Target: Voice Annotation Log")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.indigo)
                        .offset(y: 40)
                }
                
                if activeCaptureSelection != "dosa_backfill" {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 220, height: 220)
                        .offset(y: -10)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }
    
    private var viewfinderGridLines: some View {
        GeometryReader { geo in
            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geo.size.height / 3))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 3))
                    
                    path.move(to: CGPoint(x: 0, y: geo.size.height * 2 / 3))
                    path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height * 2 / 3))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundColor(.white)
                
                Path { path in
                    path.move(to: CGPoint(x: geo.size.width / 3, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width / 3, y: geo.size.height))
                    
                    path.move(to: CGPoint(x: geo.size.width * 2 / 3, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width * 2 / 3, y: geo.size.height))
                }
                .stroke(style: StrokeStyle(lineWidth: 1, dash: [5]))
                .foregroundColor(.white)
            }
        }
    }
    
    private var floatingDashboardOverlay: some View {
        VStack(spacing: 8) {
            HStack {
                Text("TODAY'S INTAKE")
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "9ca3af"))
                    .tracking(1.0)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(viewModel.todayRollup.confidenceScore > 75 ? Color(hex: "10b981") : Color(hex: "f59e0b"))
                        .frame(width: 6, height: 6)
                    Text("\(viewModel.todayRollup.confidenceScore)% Confidence")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(viewModel.todayRollup.confidenceScore > 75 ? Color(hex: "10b981") : Color(hex: "f59e0b"))
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.04))
                .cornerRadius(8)
            }
            
            HStack(alignment: .lastTextBaseline) {
                Text("~\(viewModel.todayRollup.caloriesLikely)")
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                
                Text("kcal")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "9ca3af"))
                    .padding(.bottom, 2)
                
                Spacer()
                
                Text("Protein: ")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color(hex: "9ca3af")) +
                Text("\(viewModel.todayRollup.proteinG)g")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "101216").opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 10)
    }
    
    private var offlineQueueBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "wifi.slash")
                .font(.system(size: 11, weight: .bold))
            Text("Offline Mode: logs will queue locally on-device")
                .font(.system(size: 10, weight: .bold))
            Spacer()
        }
        .foregroundColor(.white)
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color(hex: "f43f5e").opacity(0.9))
        .cornerRadius(12)
    }
    
    private var voiceLogAnnotationBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "mic.fill")
                .foregroundColor(Color(hex: "818cf8"))
                .font(.system(size: 12))
            
            Text("\"Amma's lunch: matta rice, fish curry...\"")
                .font(.system(size: 11, weight: .medium))
                .italic()
                .foregroundColor(.white)
            
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "6366f1").opacity(0.12))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color(hex: "6366f1").opacity(0.25), lineWidth: 1)
                )
        )
    }
    
    private struct FlowOption: Hashable {
        let id: String
        let label: String
    }

    private var flowPickerSelector: some View {
        let options = [
            FlowOption(id: "kerala_lunch", label: "Matta Rice"),
            FlowOption(id: "banana_chips", label: "Chips Bag"),
            FlowOption(id: "dosa_backfill", label: "Backfill Log")
        ]
        
        return HStack(spacing: 2) {
            ForEach(options, id: \.id) { item in
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        activeCaptureSelection = item.id
                    }
                }) {
                    Text(item.label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(activeCaptureSelection == item.id ? .white : Color(hex: "9ca3af"))
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .background(
                            activeCaptureSelection == item.id ?
                            Color(hex: "ff6b35") : Color.clear
                        )
                        .cornerRadius(10)
                }
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.65))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
    
    private var bottomShutterPanel: some View {
        HStack {
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    viewModel.activeView = .telemetry
                }
            }) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 2)
                        .frame(width: 44, height: 44)
                    
                    Text("📊")
                        .font(.system(size: 20))
                }
            }
            .frame(maxWidth: .infinity)
            
            Button(action: {
                shutterPressed = true
                withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                    viewModel.triggerCapture(flowId: activeCaptureSelection)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    shutterPressed = false
                }
            }) {
                ZStack {
                    Circle()
                        .fill(activeCaptureSelection == "dosa_backfill" ? Color(hex: "6366f1") : Color.white)
                        .frame(width: shutterPressed ? 58 : 64, height: shutterPressed ? 58 : 64)
                    
                    Circle()
                        .stroke(activeCaptureSelection == "dosa_backfill" ? Color(hex: "6366f1") : Color.white, lineWidth: 3)
                        .frame(width: 74, height: 74)
                    
                    if activeCaptureSelection == "dosa_backfill" {
                        Image(systemName: "mic.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                    }
                }
                .frame(width: 78, height: 78)
            }
            .frame(maxWidth: .infinity)
            
            Button(action: {
                if activeCaptureSelection == "kerala_lunch" {
                    viewModel.voiceAnnotationEnabled.toggle()
                }
            }) {
                Image(systemName: viewModel.voiceAnnotationEnabled && activeCaptureSelection == "kerala_lunch" ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 20))
                    .foregroundColor(viewModel.voiceAnnotationEnabled && activeCaptureSelection == "kerala_lunch" ? Color(hex: "818cf8") : Color(hex: "9ca3af"))
                    .frame(width: 44, height: 44)
                    .background(viewModel.voiceAnnotationEnabled && activeCaptureSelection == "kerala_lunch" ? Color(hex: "6366f1").opacity(0.2) : Color.white.opacity(0.06))
                    .cornerRadius(22)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
            .frame(maxWidth: .infinity)
            .disabled(activeCaptureSelection != "kerala_lunch")
            .opacity(activeCaptureSelection == "kerala_lunch" ? 1.0 : 0.4)
        }
        .padding(.vertical, 16)
        .padding(.bottom, 12)
        .background(Color.black)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1),
            alignment: .top
        )
    }
}
