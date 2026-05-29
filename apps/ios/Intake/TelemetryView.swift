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

    private var repeatedFoods: [(String, Int, String)] {
        var counts: [String: (count: Int, calories: Int)] = [:]
        for event in viewModel.savedEvents {
            let estimate = viewModel.savedEstimates[event.id]
            for item in viewModel.savedItems[event.id] ?? [] {
                let name = item.nameDetected.isEmpty ? item.nameNormalized : item.nameDetected
                var current = counts[name] ?? (0, 0)
                current.count += 1
                current.calories += estimate?.caloriesLikely ?? 0
                counts[name] = current
            }
        }

        return counts
            .map { name, value in
                let avg = value.count == 0 ? 0 : value.calories / value.count
                return (name, value.count, avg > 0 ? "\(avg) kcal avg" : "No estimate")
            }
            .sorted { $0.1 > $1.1 }
            .prefix(5)
            .map { $0 }
    }

    private var insights: [(String, String, String, String)] {
        let rollups = Array(viewModel.dailyRollups.suffix(14))
        guard !rollups.isEmpty else { return [] }

        let totalEvents = rollups.reduce(0) { $0 + $1.eventsCount }
        let totalPhotoLogs = rollups.reduce(0) { $0 + $1.photoLogsCount }
        let averageConfidence = rollups.reduce(0) { $0 + $1.confidenceScore } / max(rollups.count, 1)
        let lowProteinDays = rollups.filter { $0.proteinG > 0 && $0.proteinG < 65 }.count

        var rows: [(String, String, String, String)] = []
        if totalEvents > 0 {
            let photoRate = Int((Double(totalPhotoLogs) / Double(totalEvents) * 100).rounded())
            rows.append((
                "Photo Log Rate",
                "\(photoRate)% of saved meals include a photo.",
                photoRate >= 70 ? "positive" : "info",
                "\(photoRate)%"
            ))
        }
        rows.append((
            "Estimate Confidence",
            "Your 14-day average confidence is \(averageConfidence)%.",
            averageConfidence >= 80 ? "positive" : "warning",
            "\(averageConfidence)%"
        ))
        if lowProteinDays > 0 {
            rows.append((
                "Protein Coverage",
                "\(lowProteinDays) day\(lowProteinDays == 1 ? "" : "s") were below 65g protein.",
                "warning",
                "\(lowProteinDays) days"
            ))
        }
        return rows
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerBar
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    summaryStatisticsRow
                    
                    calendarSection
                    
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
        .gesture(
            DragGesture(minimumDistance: 36)
                .onEnded { value in
                    if value.translation.width > 80 {
                        withAnimation(.spring(response: 0.32, dampingFraction: 0.86)) {
                            viewModel.activeView = .camera
                        }
                    }
                }
        )
    }
    
    // MARK: - View Sub-Components
    
    private var headerBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("RESULTS")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "ff6b35"))
                    .tracking(1.0)
                
                Text("Intake History")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
            }
            
            Spacer()
            
            Button(action: {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    viewModel.activeView = .camera
                }
            }) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .intakeTouchTarget()
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(22)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
            }
            .accessibilityLabel("Return to camera")
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
                Text("CALORIES / DAY")
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
                
                Text("\(loggedDaysCount()) logged days")
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
    
    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 4) {
                    Image(systemName: "circle.grid.3x3.fill")
                        .font(.system(size: 11))
                        .foregroundColor(Color(hex: "818cf8"))
                    Text("14-DAY LOG CALENDAR")
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundColor(Color(hex: "818cf8"))
                        .tracking(0.5)
                }
                Spacer()
                
                Text("Tap a day")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.gray)
            }
            
            if viewModel.dailyRollups.isEmpty {
                emptyState("No saved days yet.")
            } else {
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
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                        .accessibilityLabel("Open log details for \(getDayLabel(date: rollup.date))")
                        .buttonStyle(StaticScaleButtonStyle())
                    }
                }
                .padding(8)
                .background(Color.black.opacity(0.35))
                .cornerRadius(18)
            }
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
                Text("14-DAY CALORIES")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundColor(Color(hex: "ff6b35"))
            }
            
            HStack(alignment: .bottom, spacing: 8) {
                if viewModel.dailyRollups.isEmpty {
                    emptyState("Save meals to build this chart.")
                } else {
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
            }
            .frame(height: 120)

            Text("kcal per saved day")
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Color(hex: "6b7280"))
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
                if repeatedFoods.isEmpty {
                    emptyState("No repeated foods yet.")
                } else {
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
                if insights.isEmpty {
                    emptyState("Insights appear after saved meals.")
                } else {
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
                        ForEach(logsForDay, id: \.id) { log in
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
                                        Image(systemName: "photo")
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(Color(hex: "9ca3af"))
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

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(Color(hex: "9ca3af"))
            .frame(maxWidth: .infinity, minHeight: 60)
            .background(Color.white.opacity(0.01))
            .cornerRadius(12)
    }
    
    private func dailyAverageCalories() -> Int {
        let rolled = viewModel.dailyRollups.suffix(14)
        guard !rolled.isEmpty else { return 0 }
        let total = rolled.reduce(0) { $0 + $1.caloriesLikely }
        return total / rolled.count
    }
    
    private func dailyAverageProtein() -> Int {
        let rolled = viewModel.dailyRollups.suffix(14)
        guard !rolled.isEmpty else { return 0 }
        let total = rolled.reduce(0) { $0 + $1.proteinG }
        return total / rolled.count
    }

    private func loggedDaysCount() -> Int {
        viewModel.dailyRollups.suffix(14).filter { $0.eventsCount > 0 }.count
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
