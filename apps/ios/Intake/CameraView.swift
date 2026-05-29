//
//  CameraView.swift
//  Intake
//
//  Created by Sidharth on 5/24/2026.
//  Copyright © 2026 Intake. All rights reserved.
//

import SwiftUI
import PhotosUI
#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

public struct CameraView: View {
    @Bindable var viewModel: IntakeViewModel
    @State private var activeCaptureIntent: CaptureIntent = .mealPhoto
    @State private var shutterPressed = false
    @State private var captureError: String?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedPhotoData: Data?
    @State private var selectedMealType: MealType = .defaultForCurrentTime()
#if os(iOS)
    @StateObject private var camera = CameraCaptureController()
#endif

    public var body: some View {
        ZStack {
            viewfinderMock
                .ignoresSafeArea()
            
            if activeCaptureIntent.requiresImage {
                viewfinderGridLines
                    .ignoresSafeArea()
                    .opacity(0.15)
            }
            
            VStack(spacing: 0) {
                floatingDashboardOverlay
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                
                if !viewModel.isOnline {
                    offlineQueueBanner
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                
                Spacer()
                
                if activeCaptureIntent.requiresImage {
                    noteInputPanel
                        .padding(.horizontal, 16)
                        .padding(.bottom, 16)
                }

                if let message = currentStatusMessage {
                    statusBanner(message)
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                }
                
                flowPickerSelector
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                
                bottomShutterPanel
            }
        }
        .background(Color.black)
#if os(iOS)
        .onAppear {
            selectedMealType = activeCaptureIntent.defaultMealType
            camera.requestAccessAndStart()
        }
        .onDisappear {
            camera.stop()
        }
#endif
        .onChange(of: selectedPhotoItem) { _, item in
            loadSelectedPhoto(item)
        }
        .gesture(
            DragGesture(minimumDistance: 36)
                .onEnded { value in
                    if value.translation.width < -80 {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            viewModel.activeView = .telemetry
                        }
                    }
                }
        )
    }
    
    // MARK: - View Sub-Components
    
    private var viewfinderMock: some View {
        GeometryReader { geo in
            ZStack {
                Color.black

                if let selectedPhotoData {
                    selectedPhotoPreview(data: selectedPhotoData)
                        .ignoresSafeArea()
                } else {
#if os(iOS)
                    if camera.permissionState == .authorized {
                        LiveCameraPreview(session: camera.session)
                            .ignoresSafeArea()

                        LinearGradient(
                            colors: [.black.opacity(0.22), .clear, .black.opacity(0.5)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    } else {
                        LinearGradient(
                            colors: [.black.opacity(0.55), .black, .black.opacity(0.75)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    }
#else
                    LinearGradient(
                        colors: [.black.opacity(0.55), .black, .black.opacity(0.75)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
#endif
                }
                
                if activeCaptureIntent.requiresImage {
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 220, height: 220)
                        .offset(y: -10)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
    }

    @ViewBuilder
    private func selectedPhotoPreview(data: Data) -> some View {
#if os(iOS)
        if let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .overlay(
                    LinearGradient(
                        colors: [.black.opacity(0.2), .clear, .black.opacity(0.55)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        } else {
            Color.black
        }
#elseif os(macOS)
        if let nsImage = NSImage(data: data) {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            Color.black
        }
#else
        Color.black
#endif
    }

    private func statusBanner(_ message: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(Color(hex: "fecaca"))

            Text(message)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 8)

#if os(iOS)
            if camera.permissionState == .denied, let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                Button {
                    UIApplication.shared.open(settingsURL)
                } label: {
                    Image(systemName: "gearshape.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                }
                .accessibilityLabel("Open camera settings")
            }
#endif
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .intakeGlassPanel(cornerRadius: 16, fallbackColor: Color(hex: "1f1113").opacity(0.94))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(hex: "fecaca").opacity(0.16), lineWidth: 1)
        )
    }

    private var noteInputPanel: some View {
        HStack(spacing: 10) {
            mealTypeMenu

            Spacer()

            if selectedPhotoData != nil {
                Button {
                    selectedPhotoData = nil
                    selectedPhotoItem = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.black.opacity(0.58))
                        .cornerRadius(22)
                }
                .accessibilityLabel("Clear selected photo")
            }
        }
    }

    private var mealTypeMenu: some View {
        Menu {
            Button("Breakfast") { selectedMealType = .breakfast }
            Button("Lunch") { selectedMealType = .lunch }
            Button("Dinner") { selectedMealType = .dinner }
            Button("Snack") { selectedMealType = .snack }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "clock")
                Text(selectedMealType.rawValue.capitalized)
            }
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.black.opacity(0.58))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .accessibilityLabel("Meal type")
        .accessibilityValue(selectedMealType.rawValue.capitalized)
    }

    private var currentStatusMessage: String? {
        if let captureError {
            return captureError
        }
        if let processingError = viewModel.processingError {
            return processingError
        }
#if os(iOS)
        if let errorMessage = camera.errorMessage {
            return errorMessage
        }
        switch camera.permissionState {
        case .denied:
            return "Camera access is off. Enable it in Settings or choose a photo."
        case .unavailable:
            return "Camera is unavailable. Choose a photo to analyze this meal."
        case .authorized, .unknown:
            return nil
        }
#else
        return "Choose a photo to analyze this meal."
#endif
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
        .intakeGlassPanel(cornerRadius: 24, fallbackColor: Color(hex: "101216").opacity(0.85))
        .overlay(
            RoundedRectangle(cornerRadius: 24)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.4), radius: 15, x: 0, y: 10)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Today's intake, approximately \(viewModel.todayRollup.caloriesLikely) calories, \(viewModel.todayRollup.proteinG) grams protein, \(viewModel.todayRollup.confidenceScore) percent confidence")
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
    
    private struct FlowOption: Hashable {
        let intent: CaptureIntent
        let label: String
    }

    private var flowPickerSelector: some View {
        let options = [
            FlowOption(intent: .mealPhoto, label: "Meal"),
            FlowOption(intent: .packageLabel, label: "Label")
        ]
        
        return HStack(spacing: 2) {
            ForEach(options, id: \.intent) { item in
                Button(action: {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        activeCaptureIntent = item.intent
                        selectedPhotoData = nil
                        selectedPhotoItem = nil
                        captureError = nil
                        selectedMealType = item.intent.defaultMealType
                    }
                }) {
                    Text(item.label)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(activeCaptureIntent == item.intent ? .white : Color(hex: "9ca3af"))
                        .padding(.vertical, 8)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(
                            activeCaptureIntent == item.intent ?
                            Color(hex: "ff6b35") : Color.clear
                        )
                        .cornerRadius(10)
                }
                .accessibilityLabel("\(item.label) capture mode")
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
        ZStack {
            HStack {
                Button(action: {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        viewModel.activeView = .telemetry
                    }
                }) {
                    Image(systemName: "chart.bar.xaxis")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(22)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
                .accessibilityLabel("Open history")

                Spacer()

                HStack(spacing: 14) {
#if os(iOS)
                    Button(action: {
                        selectedPhotoData = nil
                        selectedPhotoItem = nil
                        camera.switchCamera()
                    }) {
                        Image(systemName: "arrow.triangle.2.circlepath.camera")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(22)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .disabled(camera.permissionState != .authorized)
                    .opacity(camera.permissionState == .authorized ? 1.0 : 0.35)
                    .accessibilityLabel("Switch camera")
#endif

                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Image(systemName: selectedPhotoData == nil ? "photo" : "photo.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(22)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                    }
                    .accessibilityLabel("Choose photo")
                }
            }
            .padding(.horizontal, 24)

            Button(action: {
                runPrimaryAction()
            }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: shutterPressed ? 58 : 64, height: shutterPressed ? 58 : 64)
                    
                    Circle()
                        .stroke(Color.white, lineWidth: 3)
                        .frame(width: 74, height: 74)
                    
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.black)
                }
                .frame(width: 78, height: 78)
            }
            .accessibilityLabel("Capture meal photo")
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

    private func runPrimaryAction() {
        shutterPressed = true
        captureError = nil

        if let selectedPhotoData {
            withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                viewModel.triggerCapture(
                    intent: activeCaptureIntent,
                    imageData: selectedPhotoData,
                    noteText: nil,
                    mealType: selectedMealType
                )
            }
            shutterPressed = false
            return
        }

#if os(iOS)
        guard camera.permissionState == .authorized else {
            camera.requestAccessAndStart()
            captureError = "Allow camera access or choose a photo."
            shutterPressed = false
            return
        }

        camera.capturePhoto { data in
            guard let data else {
                captureError = "Photo capture failed. Try again or choose a photo."
                shutterPressed = false
                return
            }

            withAnimation(.spring(response: 0.15, dampingFraction: 0.6)) {
                viewModel.triggerCapture(
                    intent: activeCaptureIntent,
                    imageData: data,
                    noteText: nil,
                    mealType: selectedMealType
                )
            }
            shutterPressed = false
        }
#else
        captureError = "Choose a photo to analyze this meal."
        shutterPressed = false
#endif
    }

    private func loadSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        Task {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    await MainActor.run {
                        selectedPhotoData = data
                        captureError = nil
                    }
                }
            } catch {
                await MainActor.run {
                    captureError = "Could not load that photo."
                }
            }
        }
    }
}
