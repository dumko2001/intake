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
                            oneTapCalibrationSection(question: question)
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
            Color.gray.opacity(0.15)
                .frame(height: 140)
            
            VStack {
                Text("📸")
                    .font(.system(size: 40))
                Text("Ingested plate captured successfully")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "9ca3af"))
            }
            .frame(height: 140)
            
            if let est = viewModel.activeEstimate {
                Text("\(est.confidenceScore)% Visual Confidence")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.6))
                    .cornerRadius(8)
                    .padding([.bottom, .trailing], 10)
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
                
                Text("Likely: ")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "9ca3af")) +
                Text("\(est.caloriesLikely) kcal")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white) +
                Text("  |  Protein: ")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(hex: "9ca3af")) +
                Text("\(est.proteinG)g")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
                
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
                        
                        let tagLabel = (item.nameDetected.contains("Matta Rice") && !viewModel.selectedCorrectionOption.isEmpty)
                            ? String(viewModel.selectedCorrectionOption.split(separator: " ").first ?? "Large")
                            : (item.portionValue > 0 ? "\(item.portionValue) \(item.portionUnit)" : item.portionUnit)
                        
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
    
    private func oneTapCalibrationSection(question: PortionQuestion) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Text("PORTION CALIBRATION")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "818cf8"))
                    .tracking(0.5)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color(hex: "6366f1").opacity(0.1))
                    .cornerRadius(6)
            }
            
            Text(question.question)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white)
                .padding(.bottom, 4)
            
            VStack(spacing: 6) {
                ForEach(question.options, id: \.self) { option in
                    let isSelected = viewModel.selectedCorrectionOption == option
                    Button(action: {
                        withAnimation(.spring(response: 0.2, dampingFraction: 0.85)) {
                            viewModel.selectCorrection(option: option)
                        }
                    }) {
                        HStack {
                            Text(option)
                                .font(.system(size: 11, weight: isSelected ? .bold : .regular))
                                .foregroundColor(isSelected ? .white : Color(hex: "9ca3af"))
                            
                            Spacer()
                            
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(Color(hex: "6366f1"))
                                    .font(.system(size: 14))
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 12)
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
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color(hex: "6366f1").opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color(hex: "6366f1").opacity(0.15), lineWidth: 1)
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
