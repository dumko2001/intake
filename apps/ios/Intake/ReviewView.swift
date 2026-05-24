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
    
    @State private var showingIngredientsDetail = false

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
                        
                        // Sleek check button: Hidden by default, tap to open the full Visual Ingredient Layer
                        checkIngredientsButton
                        
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
        .sheet(isPresented: $showingIngredientsDetail) {
            visualIngredientLayerSheet
                .presentationDetents([.fraction(0.5)])
                .presentationDragIndicator(.visible)
        }
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
    
    // Sleek button to reveal detailed ingredient sheets
    private var checkIngredientsButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                showingIngredientsDetail = true
            }
        }) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles")
                    .foregroundColor(Color(hex: "10b981"))
                    .font(.system(size: 14, weight: .bold))
                
                Text("Check Ingredients & Additives")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .black))
                    .foregroundColor(Color(hex: "6b7280"))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.white.opacity(0.02))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white.opacity(0.05), lineWidth: 1)
            )
        }
    }
    
    // MARK: - Decoupled Visual Ingredient Layer Sheet (Allergens, Warnings, Clean score)
    
    private var visualIngredientLayerSheet: some View {
        VStack(spacing: 0) {
            VStack(spacing: 6) {
                Text("INGREDIENTS observatory")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "10b981"))
                    .tracking(1.0)
                
                Text("Culinary Telemetry Analysis")
                    .font(.system(size: 18, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.top, 20)
            .padding(.bottom, 12)
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    // 1. Warnings Card: High-contrast red/rose container for allergens, sugars, trans fats
                    let warningReasons = viewModel.activeEstimate?.uncertaintyReasons.filter { 
                        $0.lowercased().contains("warning") || $0.lowercased().contains("allergens") || $0.lowercased().contains("additive") || $0.lowercased().contains("oil")
                    } ?? []
                    
                    if !warningReasons.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.shield.fill")
                                    .foregroundColor(Color(hex: "f43f5e"))
                                    .font(.system(size: 13))
                                Text("ADDITIVES & WARNINGS")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "f43f5e"))
                                    .tracking(0.5)
                            }
                            
                            ForEach(warningReasons, id: \.self) { warn in
                                HStack(alignment: .top, spacing: 8) {
                                    Circle()
                                        .fill(Color(hex: "f43f5e"))
                                        .frame(width: 4, height: 4)
                                        .padding(.top, 5)
                                    Text(warn)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(Color(hex: "f43f5e"))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(14)
                        .background(Color(hex: "f43f5e").opacity(0.06))
                        .cornerRadius(18)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color(hex: "f43f5e").opacity(0.18), lineWidth: 1)
                        )
                    }
                    
                    // 2. Clean Ingredients Pills in Soft Emerald Tags
                    VStack(alignment: .leading, spacing: 10) {
                        Text("CLEAN INGREDIENTS LIST")
                            .font(.system(size: 9, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "9ca3af"))
                            .tracking(0.5)
                        
                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.activeItems) { item in
                                HStack(spacing: 4) {
                                    Circle()
                                        .fill(Color(hex: "10b981"))
                                        .frame(width: 4, height: 4)
                                    Text(item.nameDetected)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Color(hex: "10b981"))
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(Color(hex: "10b981").opacity(0.06))
                                .cornerRadius(10)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(Color(hex: "10b981").opacity(0.18), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                }
                .padding(16)
            }
        }
        .background(Color(hex: "07080a"))
    }
    
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
                Text("Dismiss")
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
}

// MARK: - FlowLayout SwiftUI Helper
struct FlowLayout: View {
    let spacing: CGFloat
    let content: [AnyView]
    
    init<Views: Sequence>(spacing: CGFloat = 8, @ViewBuilder content: () -> Views) where Views.Element == AnyView {
        self.spacing = spacing
        self.content = Array(content())
    }
    
    init<Data: RandomAccessCollection, Content: View>(
        _ data: Data,
        spacing: CGFloat = 8,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.spacing = spacing
        self.content = data.map { AnyView(content($0)) }
    }
    
    var body: some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(0..<content.count, id: \.self) { idx in
                    content[idx]
                        .alignmentGuide(.leading) { d in
                            if abs(width - d.width) > geo.size.width {
                                width = 0
                                height -= d.height + spacing
                            }
                            let result = width
                            if idx == content.count - 1 {
                                width = 0 // last item
                            } else {
                                width -= d.width + spacing
                            }
                            return result
                        }
                        .alignmentGuide(.top) { _ in
                            let result = height
                            if idx == content.count - 1 {
                                height = 0 // last item
                            }
                            return result
                        }
                }
            }
        }
        .frame(minHeight: 120)
    }
}
