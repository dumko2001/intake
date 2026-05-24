//
//  ReviewView.swift
//  Intake
//
//  Created by Sidharth on 5/24/2026.
//  Copyright © 2026 Intake. All rights reserved.
//

import SwiftUI

public struct ReviewView: View {
    @Bindable var viewModel: IntakeViewModel

    public var body: some View {
        VStack(spacing: 0) {
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    if let _ = viewModel.activeEvent?.primaryImageUrl {
                        capturedImageHeader
                    } else {
                        backfillHeaderMock
                    }
                    
                    VStack(spacing: 20) {
                        calorieEstimateRangeBlock
                        detectedIngredientsSection
                        
                        if let question = viewModel.activeQuestion {
                            dynamicPortionCalibrationPanel(question: question)
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 24)
            }
            
            actionButtonsBar
        }
        .background(Color(hex: "07080a"))
    }
    
    // MARK: - View Sub-Components
    
    private var capturedImageHeader: some View {
        ZStack(alignment: .bottomTrailing) {
            AsyncImage(url: viewModel.activeEvent?.primaryImageUrl) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 180)
                    .clipped()
            } placeholder: {
                Color.gray.opacity(0.15)
                    .frame(height: 180)
            }
            
            // Modern visual glassmorphism overlay
            LinearGradient(
                gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.6)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 180)
            
            if let est = viewModel.activeEstimate {
                Text("\(est.confidenceScore)% Visual Confidence")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .padding([.bottom, .trailing], 12)
            }
        }
    }
    
    private var backfillHeaderMock: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(Color(hex: "f43f5e"))
                .font(.system(size: 16))
            
            Text("BACKFILL LOG (NO IMAGE / LOW CONFIDENCE)")
                .font(.system(size: 10, weight: .black, design: .rounded))
                .foregroundColor(Color(hex: "f43f5e"))
                .tracking(0.5)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(hex: "f43f5e").opacity(0.06))
        .overlay(
            Rectangle()
                .fill(Color(hex: "f43f5e").opacity(0.15))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private var calorieEstimateRangeBlock: some View {
        VStack(spacing: 8) {
            Text("CALORIE ESTIMATE RANGE")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "9ca3af"))
                .tracking(0.8)
            
            if let est = viewModel.activeEstimate {
                Text("\(est.caloriesLow)–\(est.caloriesHigh)")
                    .font(.system(size: 32, weight: .black, design: .rounded))
                    .foregroundColor(Color(hex: "ff6b35")) +
                Text(" kcal")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "9ca3af"))
                
                HStack(spacing: 12) {
                    Text("Likely: ")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "9ca3af")) +
                    Text("\(est.caloriesLikely) kcal")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("•")
                        .foregroundColor(.white.opacity(0.2))
                    
                    Text("Protein: ")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(hex: "9ca3af")) +
                    Text("\(est.proteinG)g")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(.white)
                }
                
                if !est.uncertaintyReasons.isEmpty {
                    VStack(spacing: 0) {
                        Divider()
                            .background(Color.white.opacity(0.04))
                            .padding(.vertical, 8)
                        
                        Text("Most uncertain: \(est.uncertaintyReasons.joined(separator: ", "))")
                            .font(.system(size: 9, weight: .medium))
                            .italic()
                            .foregroundColor(Color(hex: "9ca3af"))
                            .multilineTextAlignment(.center)
                            .lineSpacing(2)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "101216").opacity(0.5))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
    
    private var detectedIngredientsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DETECTED INGREDIENTS")
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(Color(hex: "6b7280"))
                .tracking(0.5)
            
            VStack(spacing: 6) {
                ForEach(viewModel.activeItems) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.nameDetected)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                            Text(item.nameNormalized)
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "9ca3af"))
                        }
                        
                        Spacer()
                        
                        let tagLabel = item.portionValue > 0 ? "\(item.portionValue) \(item.portionUnit)" : item.portionUnit
                        
                        Text(tagLabel)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(confidenceColor(conf: item.confidence))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(confidenceColor(conf: item.confidence).opacity(0.06))
                            .cornerRadius(8)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.01))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.03), lineWidth: 1)
                    )
                }
            }
        }
    }
    
    // MARK: - Dynamic Calibration Morphic UI View Factory
    
    private func dynamicPortionCalibrationPanel(question: PortionQuestion) -> some View {
        VStack(alignment: .center, spacing: 12) {
            HStack {
                Text("PORTION CALIBRATION")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "818cf8"))
                    .tracking(0.5)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(hex: "6366f1").opacity(0.1))
                    .cornerRadius(6)
                Spacer()
            }
            
            Text(question.question)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 4)
            
            // Switch rendering based on the decoded AI UI Type
            switch question.uiType {
            case "slice_counter":
                SliceCounterView(options: question.options, selected: $viewModel.selectedCorrectionOption) { opt in
                    viewModel.selectCorrection(option: opt)
                }
            case "fraction_picker":
                FractionPickerView(options: question.options, selected: $viewModel.selectedCorrectionOption) { opt in
                    viewModel.selectCorrection(option: opt)
                }
            case "unit_slider":
                UnitSliderView(options: question.options, selected: $viewModel.selectedCorrectionOption) { opt in
                    viewModel.selectCorrection(option: opt)
                }
            default:
                SingleChoiceView(options: question.options, selected: $viewModel.selectedCorrectionOption) { opt in
                    viewModel.selectCorrection(option: opt)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: "6366f1").opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color(hex: "6366f1").opacity(0.12), lineWidth: 1)
                )
        )
    }
    
    private var actionButtonsBar: some View {
        HStack(spacing: 12) {
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.activeView = .camera
                    viewModel.activeEvent = nil
                    viewModel.activeEstimate = nil
                    viewModel.activeItems = []
                }
            }) {
                Text("Retake")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(14)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
            .frame(maxWidth: .infinity)
            
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    viewModel.saveMeal()
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                    Text("Save Meal")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color(hex: "10b981"), Color(hex: "059669")]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .cornerRadius(14)
            }
            .frame(maxWidth: 2 * .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .padding(.bottom, 12)
        .background(Color.black)
        .overlay(
            Rectangle()
                .fill(Color.white.opacity(0.05))
                .frame(height: 1),
            alignment: .top
        )
    }
    
    private func confidenceColor(conf: String) -> Color {
        switch conf {
        case "High":
            return Color(hex: "10b981")
        case "Medium":
            return Color(hex: "f59e0b")
        default:
            return Color(hex: "f43f5e")
        }
    }
}

// MARK: - Morphic Control 1: Slice Pie Wedge Graphic Counter (e.g. Pizza slices)

struct SliceCounterView: View {
    let options: [String]
    @Binding var selected: String
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.05), lineWidth: 2)
                    .frame(width: 130, height: 130)
                
                // Draw 4 distinct pie slices representing slices
                ForEach(0..<4) { index in
                    PizzaSliceShape(index: index, total: 4)
                        .fill(isSliceFilled(index: index) ?
                            LinearGradient(
                                gradient: Gradient(colors: [Color(hex: "ff6b35"), Color(hex: "ff8c42")]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ) :
                            LinearGradient(
                                gradient: Gradient(colors: [Color.white.opacity(0.02), Color.white.opacity(0.04)]),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            PizzaSliceShape(index: index, total: 4)
                                .stroke(isSliceFilled(index: index) ? Color(hex: "ff6b35") : Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .onTapGesture {
                            let selectedOpt = options[min(index, options.count - 1)]
                            onSelect(selectedOpt)
                        }
                        .scaleEffect(isSliceFilled(index: index) ? 1.02 : 1.0)
                        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: selected)
                }
                
                // Outer clean layout indicator
                Circle()
                    .fill(Color(hex: "07080a").opacity(0.9))
                    .frame(width: 50, height: 50)
                
                Text(parseCountLabel(selected))
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            .frame(width: 140, height: 140)
            
            // Custom label selectors
            HStack(spacing: 8) {
                ForEach(options, id: \.self) { opt in
                    Button(action: { onSelect(opt) }) {
                        Text(opt)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(selected == opt ? .white : Color(hex: "9ca3af"))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selected == opt ? Color(hex: "ff6b35").opacity(0.12) : Color.white.opacity(0.04))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selected == opt ? Color(hex: "ff6b35").opacity(0.4) : Color.clear, lineWidth: 1)
                            )
                    }
                }
            }
        }
    }
    
    private func isSliceFilled(index: Int) -> Bool {
        let count = Int(selected.split(separator: " ").first ?? "1") ?? 1
        return index < count
    }
    
    private func parseCountLabel(_ str: String) -> String {
        let count = str.split(separator: " ").first ?? "1"
        return "\(count)x"
    }
}

struct PizzaSliceShape: Shape {
    let index: Int
    let total: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 4
        let startAngle = Angle.degrees(Double(index) * (360.0 / Double(total)) - 90 + 2)
        let endAngle = Angle.degrees(Double(index + 1) * (360.0 / Double(total)) - 90 - 2)
        
        path.move(to: center)
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
    }
}

// MARK: - Morphic Control 2: Fraction progress segments (e.g. Fruits, banana half/whole)

struct FractionPickerView: View {
    let options: [String]
    @Binding var selected: String
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.04), lineWidth: 8)
                    .frame(width: 110, height: 110)
                
                // Circular visual arc representing fraction portion progress
                Circle()
                    .trim(from: 0, to: CGFloat(parseFractionProgress(selected)))
                    .stroke(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(hex: "818cf8"), Color(hex: "6366f1")]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .frame(width: 110, height: 110)
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.35, dampingFraction: 0.8), value: selected)
                
                VStack(spacing: 2) {
                    Text(selected)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Portion")
                        .font(.system(size: 8))
                        .foregroundColor(Color(hex: "9ca3af"))
                }
            }
            .frame(width: 120, height: 120)
            .padding(.vertical, 4)
            
            // Custom progress segment taps
            HStack(spacing: 4) {
                ForEach(options, id: \.self) { opt in
                    Button(action: { onSelect(opt) }) {
                        Text(opt)
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(selected == opt ? .white : Color(hex: "9ca3af"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .background(selected == opt ? Color(hex: "6366f1").opacity(0.15) : Color.white.opacity(0.04))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(selected == opt ? Color(hex: "6366f1").opacity(0.4) : Color.clear, lineWidth: 1)
                            )
                    }
                }
            }
        }
    }
    
    private func parseFractionProgress(_ str: String) -> Double {
        let clean = str.lowercased()
        if clean.contains("quarter") { return 0.25 }
        if clean.contains("half") { return 0.5 }
        if clean.contains("three") { return 0.75 }
        if clean.contains("whole") || clean.contains("full") { return 1.0 }
        return 1.0
    }
}

// MARK: - Morphic Control 3: Ruler Ticks slider view (e.g. rice cups, oil spoons)

struct UnitSliderView: View {
    let options: [String]
    @Binding var selected: String
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Premium custom Horizontal engineering scale ticks
            HStack(alignment: .bottom, spacing: 0) {
                ForEach(0..<options.count, id: \.self) { idx in
                    let isCurrent = options[idx] == selected
                    
                    VStack(spacing: 8) {
                        // Vertical Ruler Tick
                        RoundedRectangle(cornerRadius: 2)
                            .fill(isCurrent ? Color(hex: "ff6b35") : Color.white.opacity(0.15))
                            .frame(width: 2.5, height: idx % 2 == 0 ? 24 : 14)
                            .scaleEffect(isCurrent ? 1.4 : 1.0)
                            
                        Text(options[idx].split(separator: " ").first ?? "")
                            .font(.system(size: 9, weight: isCurrent ? .black : .bold))
                            .foregroundColor(isCurrent ? .white : Color(hex: "6b7280"))
                    }
                    .frame(maxWidth: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        onSelect(options[idx])
                    }
                }
            }
            .frame(height: 50)
            .padding(.horizontal, 8)
            .background(Color.white.opacity(0.01))
            .cornerRadius(12)
            
            // Sliding scale container
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 6)
                
                GeometryReader { geo in
                    let width = geo.size.width
                    let step = width / CGFloat(options.count - 1)
                    let currentIdx = options.firstIndex(of: selected) ?? 0
                    
                    Circle()
                        .fill(Color(hex: "ff6b35"))
                        .frame(width: 16, height: 16)
                        .offset(x: CGFloat(currentIdx) * step - 8, y: -5)
                        .shadow(color: Color(hex: "ff6b35").opacity(0.5), radius: 5)
                        .animation(.spring(response: 0.25, dampingFraction: 0.85), value: selected)
                }
                .frame(height: 6)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            
            Text("Selected: \(selected)")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Color(hex: "ff6b35"))
        }
    }
}

// MARK: - Morphic Control 4: Refined glowing selection pills

struct SingleChoiceView: View {
    let options: [String]
    @Binding var selected: String
    let onSelect: (String) -> Void
    
    var body: some View {
        VStack(spacing: 6) {
            ForEach(options, id: \.self) { option in
                let isSelected = selected == option
                Button(action: {
                    onSelect(option)
                }) {
                    HStack {
                        Text(option)
                            .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                            .foregroundColor(isSelected ? .white : Color(hex: "9ca3af"))
                        
                        Spacer()
                        
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(Color(hex: "6366f1"))
                                .font(.system(size: 13))
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .background(isSelected ? Color(hex: "6366f1").opacity(0.12) : Color.clear)
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color(hex: "6366f1").opacity(0.3) : Color.white.opacity(0.04), lineWidth: 1)
                    )
                }
            }
        }
    }
}
