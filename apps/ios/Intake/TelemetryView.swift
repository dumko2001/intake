//
//  TelemetryView.swift
//  Intake
//
//  Created by Sidharth on 5/24/2026.
//  Copyright © 2026 Intake. All rights reserved.
//

import SwiftUI

public struct TelemetryView: View {
    // Standard let binding for Observable models
    let viewModel: IntakeViewModel
    
    private let repeatedFoods = [
        ("Kerala Matta Rice", 12, "400 kcal"),
        ("Amma's Fish Curry", 9, "220 kcal"),
        ("South Indian Filter Coffee", 8, "110 kcal"),
        ("Home Dosa", 6, "130 kcal/pc"),
        ("Egg Omelette", 5, "160 kcal")
    ]
    
    private let insights = [
        ("Hidden Calorie Sources", "Rice serving sizes represent roughly 38% of your overall carbohydrate intake, averaging larger than your typical portion sizes.", "warning", "+140 kcal"),
        ("Protein Inconsistency", "Your daily protein intake fell below your threshold of 65g on 8 out of the last 14 days, primarily due to low-protein dinners.", "warning", "Low consistency"),
        ("Late Meal Calorie Spike", "You logged meals after 10:00 PM on 4 days. These meals averaged 210 calories higher with a 15% higher fat composition.", "info", "+210 kcal"),
        ("Visual Log Success Rate", "82% of your logs this week included photos, preserving a highly detailed visual ledger for future re-calibrations.", "positive", "High confidence")
    ]

    public var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TELEMETRY")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "ff6b35"))
                        .tracking(1.0)
                    
                    Text("Body Intake")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                }
                
                Spacer()
                
                Button(action: {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                        viewModel.activeView = .camera
                    }
                }) {
                    Text("Camera")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color.black)
            .overlay(
                Rectangle()
                    .fill(Color.white.opacity(0.05))
                    .frame(height: 1),
                alignment: .bottom
            )
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 16) {
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "flame.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "ff6b35"))
                                Text("DAILY CALORIES")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "ff6b35"))
                            }
                            Text("2.2k–2.5k")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Avg: 2,340 kcal / day")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "9ca3af"))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                        )
                        
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 4) {
                                Image(systemName: "waveform.path.ecg")
                                    .font(.system(size: 11))
                                    .foregroundColor(Color(hex: "8b5cf6"))
                                Text("PROTEIN AVG")
                                    .font(.system(size: 9, weight: .bold, design: .rounded))
                                    .foregroundColor(Color(hex: "8b5cf6"))
                            }
                            Text("58g")
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                            Text("Consistency: 81%")
                                .font(.system(size: 10))
                                .foregroundColor(Color(hex: "9ca3af"))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Color.white.opacity(0.02))
                        .cornerRadius(16)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.white.opacity(0.04), lineWidth: 1)
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 4) {
                            Image(systemName: "calendar")
                                .font(.system(size: 11))
                                .foregroundColor(Color(hex: "ff6b35"))
                            Text("14-DAY OBSERVABILITY GRAPH")
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .foregroundColor(Color(hex: "ff6b35"))
                        }
                        
                        HStack(alignment: .bottom, spacing: 8) {
                            ForEach(viewModel.dailyRollups.suffix(14), id: \.date) { rollup in
                                VStack(spacing: 6) {
                                    let heightRatio = CGFloat(max(0, rollup.caloriesLikely - 1000)) / CGFloat(2500)
                                    let barHeight = max(10, min(100, 100 * heightRatio))
                                    
                                    ZStack(alignment: .bottom) {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.white.opacity(0.04))
                                            .frame(height: 100)
                                        
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(
                                                LinearGradient(
                                                    gradient: Gradient(colors: [Color(hex: "ff6b35"), Color(hex: "ff8c42")]),
                                                    startPoint: .top,
                                                    endPoint: .bottom
                                                )
                                            )
                                            .frame(height: barHeight)
                                    }
                                    
                                    Text(getDayLabel(date: rollup.date))
                                        .font(.system(size: 8, weight: .medium))
                                        .foregroundColor(Color(hex: "9ca3af"))
                                }
                                .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(height: 120)
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.01))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.03), lineWidth: 1)
                    )
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MOST REPEATED FOODS")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .tracking(0.5)
                        
                        VStack(spacing: 8) {
                            ForEach(0..<repeatedFoods.count, id: \.self) { idx in
                                let food = repeatedFoods[idx]
                                HStack {
                                    HStack(spacing: 8) {
                                        Text("\(idx + 1)")
                                            .font(.system(size: 9, weight: .bold))
                                            .foregroundColor(Color(hex: "ff6b35"))
                                            .frame(width: 18, height: 18)
                                            .background(Color(hex: "ff6b35").opacity(0.1))
                                            .cornerRadius(9)
                                        
                                        Text(food.0)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white)
                                    }
                                    
                                    Spacer()
                                    
                                    HStack(spacing: 8) {
                                        Text("\(food.1) logs")
                                            .font(.system(size: 10))
                                            .foregroundColor(Color(hex: "9ca3af"))
                                        
                                        Text(food.2)
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Color(hex: "9ca3af"))
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(Color.white.opacity(0.05))
                                            .cornerRadius(6)
                                    }
                                }
                                .padding(.bottom, 6)
                                if idx < repeatedFoods.count - 1 {
                                    Divider()
                                        .background(Color.white.opacity(0.04))
                                }
                            }
                        }
                    }
                    .padding(14)
                    .background(Color.white.opacity(0.02))
                    .cornerRadius(20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.04), lineWidth: 1)
                    )
                    
                    VStack(alignment: .leading, spacing: 10) {
                        Text("TELEMETRY INSIGHTS")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundColor(Color(hex: "9ca3af"))
                            .tracking(0.5)
                        
                        VStack(spacing: 10) {
                            ForEach(0..<insights.count, id: \.self) { idx in
                                let insight = insights[idx]
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: insight.2 == "warning" ? "exclamationmark.triangle.fill" : (insight.2 == "positive" ? "sparkles" : "clock.fill"))
                                        .foregroundColor(insight.2 == "warning" ? Color(hex: "f59e0b") : (insight.2 == "positive" ? Color(hex: "10b981") : Color(hex: "818cf8")))
                                        .font(.system(size: 14))
                                        .padding(.top, 2)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack {
                                            Text(insight.0)
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                            
                                            Spacer()
                                            
                                            Text(insight.3)
                                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                                .foregroundColor(insight.2 == "warning" ? Color(hex: "f59e0b") : (insight.2 == "positive" ? Color(hex: "10b981") : Color(hex: "818cf8")))
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Color.white.opacity(0.04))
                                                .cornerRadius(6)
                                        }
                                        
                                        Text(insight.1)
                                            .font(.system(size: 11))
                                            .foregroundColor(Color(hex: "9ca3af"))
                                            .lineSpacing(2)
                                    }
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.01))
                                .cornerRadius(16)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16)
                                        .stroke(Color.white.opacity(0.03), lineWidth: 1)
                                )
                            }
                        }
                    }
                    
                }
                .padding(16)
                .padding(.bottom, 24)
            }
        }
        .background(Color(hex: "07080a"))
    }
    
    private func getDayLabel(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
}
