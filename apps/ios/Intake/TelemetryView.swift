//
//  TelemetryView.swift
//  Intake
//
//  Created by Sidharth on 5/24/2026.
//  Copyright © 2026 Intake. All rights reserved.
//

import SwiftUI

public struct TelemetryView: View {
    let viewModel: IntakeViewModel
    
    @State private var selectedDate: Date? = nil
    @State private var showingDayDetailSheet = false
    @State private var scalePressed = false
    
    // Top repeated foods telemetry
    private let repeatedFoods = [
        ("Kerala Matta Rice", 12, "400 kcal"),
        ("Amma's Fish Curry", 9, "220 kcal"),
        ("South Indian Filter Coffee", 8, "110 kcal"),
        ("Home Dosa", 6, "130 kcal/pc"),
        ("Egg Omelette", 5, "160 kcal")
    ]
    
    // Standard insights engine mock
    private let insights = [
        ("Hidden Calorie Sources", "Rice serving sizes represent roughly 38% of your overall carbohydrate intake, averaging larger than your typical portion sizes.", "warning", "+140 kcal"),
        ("Protein Inconsistency", "Your daily protein intake fell below your threshold of 65g on 8 out of the last 14 days, primarily due to low-protein dinners.", "warning", "Low consistency"),
        ("Late Meal Calorie Spike", "You logged meals after 10:00 PM on 4 days. These meals averaged 210 calories higher with a 15% higher fat composition.", "info", "+210 kcal"),
        ("Visual Log Success Rate", "82% of your logs this week included photos, preserving a highly detailed visual ledger for future re-calibrations.", "positive", "High confidence")
    ]

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    summaryStatisticsRow
                    
                    dribbbleCalendarSection
                    
                    barTelemetryChartSection
                    
                    repeatedFoodsSection
                    
                    insightsSection
                }
                .padding(16)
                .padding(.bottom, 24)
            }
        }
        .background(Color(hex: "07080a"))
        .sheet(isPresented: $showingDayDetailSheet) {
            if let date = selectedDate {
                dayDetailBottomSheet(for: date)
                    .presentationDetents([.fraction(0.45)])
                    .presentationDragIndicator(.visible)
            }
        }
    }
    
    // MARK: - View Sub-Components
    
    private var headerBar: some View {
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
    }
    
    private var summaryStatisticsRow: some View {
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
                
                let avgCal = dailyAverageCalories()
                Text("\(avgCal - 150)–\(avgCal + 150)")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Avg: \(avgCal) kcal / day")
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
                
                let avgProt = dailyAverageProtein()
                Text("\(avgProt)g")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                
                Text("Consistency: 82%")
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
    }
    
    // MARK: - Dribbble-inspired 7 x 14 Telemetry Calendar Contribution Grid
    
    private var dribbbleCalendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "circle.grid.3x3.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "818cf8"))
                    Text("14-DAY DRIBBBLE CALENDAR GRID")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "818cf8"))
                        .tracking(0.5)
                }
                Spacer()
                
                Text("Click cells for details")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray)
            }
            
            // 7x14 Grid Layout representing 14 days chronologically
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 7), spacing: 8) {
                ForEach(viewModel.dailyRollups.suffix(14), id: \.date) { rollup in
                    Button(action: {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.75)) {
                            selectedDate = rollup.date
                            showingDayDetailSheet = true
                        }
                    }) {
                        Circle()
                            .fill(calendarCellColor(for: rollup))
                            .frame(height: 34)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                            )
                            .shadow(color: calendarCellShadowColor(for: rollup), radius: 4)
                            .overlay(
                                Text(getDayLabel(date: rollup.date))
                                    .font(.system(size: 8, weight: .bold, design: .rounded))
                                    .foregroundColor(rollup.caloriesLikely > 0 ? .white : Color(hex: "6b7280"))
                            )
                    }
                    .buttonStyle(StaticScaleButtonStyle())
                }
            }
            .padding(8)
            .background(Color.black.opacity(0.35))
            .cornerRadius(18)
        }
        .padding(14)
        .background(Color.white.opacity(0.01))
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.white.opacity(0.03), lineWidth: 1)
        )
    }
    
    private var barTelemetryChartSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 4) {
                Image(systemName: "chart.bar.fill")
                    .font(.system(size: 11))
                    .foregroundColor(Color(hex: "ff6b35"))
                Text("14-DAY OBSERVABILITY GRAPH")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "ff6b35"))
            }
            
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(viewModel.dailyRollups.suffix(14), id: \.date) { rollup in
                    VStack(spacing: 6) {
                        let heightRatio = CGFloat(max(0, rollup.caloriesLikely)) / CGFloat(2800)
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
    }
    
    private var repeatedFoodsSection: some View {
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
    }
    
    private var insightsSection: some View {
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
    
    // MARK: - Glassmorphic Sheet displaying Specific Day Log Cards
    
    private func dayDetailBottomSheet(for date: Date) -> some View {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        let dateStr = formatter.string(from: date)
        
        let logsForDay = getLogsForDate(date)
        let totalCals = logsForDay.reduce(0) { $0 + (viewModel.savedEstimates[$1.id]?.caloriesLikely ?? 0) }
        
        return VStack(spacing: 0) {
            VStack(spacing: 8) {
                Text(dateStr.uppercased())
                    .font(.system(size: 10, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "9ca3af"))
                    .tracking(1.0)
                
                Text("\(totalCals) kcal total")
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(.white)
            }
            .padding(.top, 16)
            .padding(.bottom, 8)
            
            Divider()
                .background(Color.white.opacity(0.08))
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 12) {
                    if logsForDay.isEmpty {
                        Text("No items logged on this day.")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                            .padding(.top, 40)
                    } else {
                        ForEach(logsForDay) { log in
                            HStack(spacing: 12) {
                                // Image thumbnail if present
                                if let url = log.thumbnailUrl {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 44, height: 44)
                                            .cornerRadius(8)
                                    } placeholder: {
                                        Color.white.opacity(0.05)
                                            .frame(width: 44, height: 44)
                                            .cornerRadius(8)
                                    }
                                } else {
                                    ZStack {
                                        Color.white.opacity(0.05)
                                            .frame(width: 44, height: 44)
                                            .cornerRadius(8)
                                        Text("🎙️")
                                            .font(.system(size: 14))
                                    }
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(log.mealTime)
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(Color(hex: "9ca3af"))
                                    
                                    let foodLabel = log.rawTextNote ?? "Photo capture log"
                                    Text(foodLabel)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                }
                                
                                Spacer()
                                
                                if let est = viewModel.savedEstimates[log.id] {
                                    Text("\(est.caloriesLikely) kcal")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundColor(Color(hex: "ff6b35"))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color(hex: "ff6b35").opacity(0.08))
                                        .cornerRadius(8)
                                }
                            }
                            .padding(10)
                            .background(Color.white.opacity(0.02))
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(16)
            }
        }
        .background(Color(hex: "101216"))
    }
    
    // MARK: - Telemetry Arithmetic Helpers
    
    private func dailyAverageCalories() -> Int {
        let rolled = viewModel.dailyRollups.suffix(14)
        guard !rolled.isEmpty else { return 2340 }
        let total = rolled.reduce(0) { $0 + $1.caloriesLikely }
        return total / rolled.count
    }
    
    private func dailyAverageProtein() -> Int {
        let rolled = viewModel.dailyRollups.suffix(14)
        guard !rolled.isEmpty else { return 58 }
        let total = rolled.reduce(0) { $0 + $1.proteinG }
        return total / rolled.count
    }
    
    private func getDayLabel(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func getLogsForDate(_ date: Date) -> [FoodEvent] {
        return viewModel.savedEvents.filter { Calendar.current.isDate($0.createdAt, inSameDayAs: date) }
    }
    
    private func calendarCellColor(for rollup: DailyRollup) -> LinearGradient {
        let kcal = rollup.caloriesLikely
        if kcal == 0 {
            return LinearGradient(colors: [Color.white.opacity(0.02), Color.white.opacity(0.03)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        
        // Emerald hit goal: 1700 - 2400 kcal
        if kcal >= 1700 && kcal <= 2400 {
            return LinearGradient(
                gradient: Gradient(colors: [Color(hex: "10b981"), Color(hex: "059669")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        // Amber exceeded: > 2400 kcal
        if kcal > 2400 {
            return LinearGradient(
                gradient: Gradient(colors: [Color(hex: "ff6b35"), Color(hex: "ff8c42")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        
        // Under goal: < 1700 kcal
        return LinearGradient(
            gradient: Gradient(colors: [Color(hex: "3b82f6").opacity(0.3), Color(hex: "1d4ed8").opacity(0.3)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    private func calendarCellShadowColor(for rollup: DailyRollup) -> Color {
        let kcal = rollup.caloriesLikely
        if kcal >= 1700 && kcal <= 2400 {
            return Color(hex: "10b981").opacity(0.15)
        }
        if kcal > 2400 {
            return Color(hex: "ff6b35").opacity(0.15)
        }
        return Color.clear
    }
}

// SwiftUI button scale helper
struct StaticScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.90 : 1.0)
            .animation(.spring(response: 0.15, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
