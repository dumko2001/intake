//
//  IntakeViewModel.swift
//  Intake
//
//  Created by Sidharth on 5/24/2026.
//  Copyright © 2026 Intake. All rights reserved.
//

import Foundation
import Observation
import Combine

public enum AppActiveView {
    case camera
    case analyzing
    case review
    case telemetry
}

/// State-of-the-art Swift 6 / iOS 17+ Observable model using the @Observable macro
@Observable
@MainActor
public final class IntakeViewModel {
    // Current UI view state
    public var activeView: AppActiveView = .camera
    
    // Core database collections
    public var savedEvents: [FoodEvent] = []
    public var savedItems: [UUID: [MealItem]] = [:]
    public var savedEstimates: [UUID: EstimateVersion] = [:]
    public var personalMemory: [PersonalMemory] = []
    public var dailyRollups: [DailyRollup] = []
    public var offlineQueue: [FoodEvent] = []
    
    // In-flight capture state
    public var activeEvent: FoodEvent?
    public var activeItems: [MealItem] = []
    public var activeEstimate: EstimateVersion?
    public var activeQuestion: PortionQuestion?
    public var selectedCorrectionOption: String = ""
    public var analysisStage: Int = 0
    
    // Settings toggles
    public var voiceAnnotationEnabled: Bool = true
    public var isOnline: Bool = true
    
    // Aggregated stats today
    public var todayRollup = DailyRollup(
        userId: "usr_sidharth_902",
        date: Date(),
        caloriesLow: 1100,
        caloriesHigh: 1450,
        caloriesLikely: 1280,
        proteinG: 42,
        carbsG: 190,
        fatG: 45,
        eventsCount: 2,
        photoLogsCount: 2,
        noImageLogsCount: 0,
        confidenceScore: 91
    )
    
    public init() {
        initializeMockTelemetry()
    }
    
    // MARK: - Ingestion Transitions
    
    public func triggerCapture(flowId: String) {
        let eventId = UUID()
        let userId = "usr_sidharth_902"
        let now = Date()
        
        var captureType: CaptureType = .photo
        var textNote: String? = nil
        var imageUrl: URL? = nil
        
        var mockItems: [MealItem] = []
        var mockEstimate: EstimateVersion?
        var mockQuestion: PortionQuestion?
        
        switch flowId {
        case "kerala_lunch":
            captureType = voiceAnnotationEnabled ? .photoVoice : .photo
            textNote = "Amma's lunch: matta rice, fish curry, cabbage thoran, pappadam"
            imageUrl = URL(string: "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=1000")
            
            mockItems = [
                MealItem(eventId: eventId, nameDetected: "Kerala Matta Rice", nameNormalized: "Cooked matta rice", portionLabel: "Large", estimatedGramsLow: 250, estimatedGramsHigh: 350, estimatedGramsLikely: 300, confidence: "High"),
                MealItem(eventId: eventId, nameDetected: "Fish Curry (Kerala style)", nameNormalized: "Fish curry with coconut gravy", portionLabel: "Medium bowl", estimatedGramsLow: 150, estimatedGramsHigh: 220, estimatedGramsLikely: 180, confidence: "Medium"),
                MealItem(eventId: eventId, nameDetected: "Cabbage Thoran", nameNormalized: "Cabbage thoran with shredded coconut", portionLabel: "Small side", estimatedGramsLow: 50, estimatedGramsHigh: 80, estimatedGramsLikely: 65, confidence: "High"),
                MealItem(eventId: eventId, nameDetected: "Pappadam", nameNormalized: "Fried papadum", portionLabel: "1 piece", estimatedGramsLow: 10, estimatedGramsHigh: 15, estimatedGramsLikely: 12, confidence: "High")
            ]
            
            mockEstimate = EstimateVersion(
                eventId: eventId,
                modelProvider: "openai",
                modelName: "gpt-4o-vision-2024-11-20",
                promptVersion: "v1.4",
                nutritionEngineVersion: "v2.0",
                caloriesLow: 780,
                caloriesHigh: 980,
                caloriesLikely: 870,
                proteinG: 34,
                carbsG: 110,
                fatG: 30,
                confidenceScore: 82,
                uncertaintyReasons: ["depth of rice on plate", "cooking oil / coconut content in curry gravy"]
            )
            
            mockQuestion = PortionQuestion(
                id: "q_rice_qty",
                question: "Was the Matta Rice serving closer to Small, Medium, or Large?",
                options: ["Small (fist size / ~150g)", "Medium (bowl size / ~250g)", "Large (loaded plate / ~350g)"],
                defaultOption: "Large (loaded plate / ~350g)",
                correctionType: "portion"
            )
            
        case "banana_chips":
            captureType = .photo
            textNote = "Snacking at desk"
            imageUrl = URL(string: "https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=1000")
            
            mockItems = [
                MealItem(eventId: eventId, nameDetected: "Kerala Banana Chips (Packaged)", nameNormalized: "Banana chips fried in coconut oil", portionLabel: "1 packet (65g)", estimatedGramsLow: 65, estimatedGramsHigh: 65, estimatedGramsLikely: 65, confidence: "High")
            ]
            
            mockEstimate = EstimateVersion(
                eventId: eventId,
                modelProvider: "openai",
                modelName: "gpt-4o-ocr-2024-11-20",
                promptVersion: "v1.4",
                nutritionEngineVersion: "v2.0",
                caloriesLow: 340,
                caloriesHigh: 340,
                caloriesLikely: 340,
                proteinG: 2,
                carbsG: 38,
                fatG: 20,
                confidenceScore: 98,
                uncertaintyReasons: []
            )
            
            mockQuestion = PortionQuestion(
                id: "q_chips_fraction",
                question: "Did you eat the entire 65g packet?",
                options: ["Half packet (~32g)", "Whole packet (65g)", "Two packets (130g)"],
                defaultOption: "Whole packet (65g)",
                correctionType: "portion"
            )
            
        case "dosa_backfill":
            captureType = .backfillVoice
            textNote = "Voice backfill: Had two dosas with coconut chutney and sambar, plus filter coffee"
            imageUrl = nil
            
            mockItems = [
                MealItem(eventId: eventId, nameDetected: "Dosa", nameNormalized: "Standard fermented rice dosa", portionLabel: "2 pieces", estimatedGramsLow: 120, estimatedGramsHigh: 160, estimatedGramsLikely: 140, confidence: "Low"),
                MealItem(eventId: eventId, nameDetected: "Coconut Chutney", nameNormalized: "Grated coconut chutney", portionLabel: "Small bowl", estimatedGramsLow: 40, estimatedGramsHigh: 70, estimatedGramsLikely: 50, confidence: "Low"),
                MealItem(eventId: eventId, nameDetected: "Sambar", nameNormalized: "Lentil vegetable sambar", portionLabel: "Small bowl", estimatedGramsLow: 100, estimatedGramsHigh: 150, estimatedGramsLikely: 120, confidence: "Low"),
                MealItem(eventId: eventId, nameDetected: "South Indian Filter Coffee", nameNormalized: "Filter coffee with whole milk", portionLabel: "1 tumbler", estimatedGramsLow: 120, estimatedGramsHigh: 150, estimatedGramsLikely: 135, confidence: "Low")
            ]
            
            mockEstimate = EstimateVersion(
                eventId: eventId,
                modelProvider: "openai",
                modelName: "gpt-4o-text-2024-11-20",
                promptVersion: "v1.4",
                nutritionEngineVersion: "v2.0",
                caloriesLow: 430,
                caloriesHigh: 670,
                caloriesLikely: 540,
                proteinG: 12,
                carbsG: 82,
                fatG: 19,
                confidenceScore: 55,
                uncertaintyReasons: [
                    "no photo to visually verify portion sizes",
                    "oil / ghee brushing amount on dosa is unknown",
                    "sugar concentration in coffee is unquantified"
                ]
            )
            
            mockQuestion = PortionQuestion(
                id: "q_dosa_ghee",
                question: "Were the dosas prepared with Ghee/Butter?",
                options: ["Standard/Dry dosa (very little oil)", "Ghee dosa (brushed generously)", "Butter dosa (crispy/thick)"],
                defaultOption: "Standard/Dry dosa (very little oil)",
                correctionType: "ghee_amount"
            )
            
        default:
            return
        }
        
        let newEvent = FoodEvent(
            id: eventId,
            userId: userId,
            createdAt: now,
            mealTime: getFormattedTime(date: now),
            mealType: flowId == "banana_chips" ? .snack : (flowId == "dosa_backfill" ? .breakfast : .lunch),
            captureType: captureType,
            status: isOnline ? .analyzed : .pending,
            rawTextNote: textNote,
            primaryImageUrl: imageUrl,
            thumbnailUrl: imageUrl
        )
        
        activeEvent = newEvent
        activeItems = mockItems
        activeEstimate = mockEstimate
        activeQuestion = mockQuestion
        selectedCorrectionOption = mockQuestion?.defaultOption ?? ""
        
        activeView = .analyzing
        analysisStage = 1
        
        // Staged concurrency trigger
        Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            analysisStage = 2
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            analysisStage = 3
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            
            if !isOnline {
                saveMeal(isOfflineSkip: true)
            } else {
                activeView = .review
            }
        }
    }
    
    public func selectCorrection(option: String) {
        selectedCorrectionOption = option
        guard let estimate = activeEstimate else { return }
        
        if activeEvent?.id.uuidString.contains("kerala") == true || activeQuestion?.id == "q_rice_qty" {
            if option.contains("Small") {
                estimate.caloriesLow = 620
                estimate.caloriesHigh = 780
                estimate.caloriesLikely = 700
            } else if option.contains("Medium") {
                estimate.caloriesLow = 720
                estimate.caloriesHigh = 880
                estimate.caloriesLikely = 790
            } else {
                estimate.caloriesLow = 780
                estimate.caloriesHigh = 980
                estimate.caloriesLikely = 870
            }
        } else if activeQuestion?.id == "q_chips_fraction" {
            if option.contains("Half") {
                estimate.caloriesLow = 170
                estimate.caloriesHigh = 170
                estimate.caloriesLikely = 170
            } else if option.contains("Whole") {
                estimate.caloriesLow = 340
                estimate.caloriesHigh = 340
                estimate.caloriesLikely = 340
            } else {
                estimate.caloriesLow = 680
                estimate.caloriesHigh = 680
                estimate.caloriesLikely = 680
            }
        } else if activeQuestion?.id == "q_dosa_ghee" {
            if option.contains("Standard") {
                estimate.caloriesLow = 430
                estimate.caloriesHigh = 670
                estimate.caloriesLikely = 540
            } else if option.contains("Ghee") {
                estimate.caloriesLow = 530
                estimate.caloriesHigh = 770
                estimate.caloriesLikely = 640
            } else {
                estimate.caloriesLow = 650
                estimate.caloriesHigh = 920
                estimate.caloriesLikely = 780
            }
        }
    }
    
    public func saveMeal(isOfflineSkip: Bool = false) {
        guard let event = activeEvent, let estimate = activeEstimate else { return }
        
        if isOnline {
            event.status = .saved
        } else {
            event.status = .pending
            offlineQueue.append(event)
        }
        
        savedEvents.insert(event, at: 0)
        savedItems[event.id] = activeItems
        savedEstimates[event.id] = estimate
        
        if event.id.uuidString.contains("kerala") == true || activeQuestion?.id == "q_rice_qty" {
            let label = selectedCorrectionOption.split(separator: " ").first.map(String.init) ?? "Large"
            updateMemory(
                signature: "home_lunch_matta_rice",
                displayName: "Amma's Matta Rice",
                portion: label,
                likelyKcal: label == "Small" ? 210 : (label == "Medium" ? 330 : 430)
            )
        }
        
        if !isOfflineSkip {
            todayRollup.caloriesLikely += estimate.caloriesLikely
            todayRollup.caloriesLow += estimate.caloriesLow
            todayRollup.caloriesHigh += estimate.caloriesHigh
            todayRollup.proteinG += estimate.proteinG
            todayRollup.eventsCount += 1
            if event.primaryImageUrl != nil {
                todayRollup.photoLogsCount += 1
            } else {
                todayRollup.noImageLogsCount += 1
            }
            
            if let index = dailyRollups.firstIndex(where: { Calendar.current.isDateInToday($0.date) }) {
                dailyRollups[index] = todayRollup
            }
        }
        
        activeView = .camera
        activeEvent = nil
        activeEstimate = nil
        activeItems = []
        activeQuestion = nil
    }
    
    public func toggleOnline() {
        isOnline.toggle()
        if isOnline && !offlineQueue.isEmpty {
            Task {
                for i in 0..<offlineQueue.count {
                    let queuedEvent = offlineQueue[i]
                    if let idx = savedEvents.firstIndex(where: { $0.id == queuedEvent.id }) {
                        savedEvents[idx].status = .saved
                        
                        if let est = savedEstimates[queuedEvent.id] {
                            todayRollup.caloriesLikely += est.caloriesLikely
                            todayRollup.caloriesLow += est.caloriesLow
                            todayRollup.caloriesHigh += est.caloriesHigh
                            todayRollup.proteinG += est.proteinG
                            todayRollup.eventsCount += 1
                            todayRollup.photoLogsCount += 1
                        }
                    }
                }
                offlineQueue.removeAll()
            }
        }
    }
    
    private func updateMemory(signature: String, displayName: String, portion: String, likelyKcal: Int) {
        if let idx = personalMemory.firstIndex(where: { $0.foodSignature == signature }) {
            personalMemory[idx].usualPortionLabel = portion
            personalMemory[idx].usualCaloriesLikely = likelyKcal
            personalMemory[idx].correctionCount += 1
            personalMemory[idx].confidenceScore = min(98, personalMemory[idx].confidenceScore + 2)
            personalMemory[idx].lastSeenAt = Date()
        } else {
            let record = PersonalMemory(
                userId: "usr_sidharth_902",
                foodSignature: signature,
                displayName: displayName,
                usualPortionLabel: portion,
                usualCaloriesLow: likelyKcal - 50,
                usualCaloriesHigh: likelyKcal + 50,
                usualCaloriesLikely: likelyKcal,
                correctionCount: 1,
                confidenceScore: 55
            )
            personalMemory.append(record)
        }
    }
    
    private func getFormattedTime(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func initializeMockTelemetry() {
        let calendar = Calendar.current
        let today = Date()
        
        var seedRollups: [DailyRollup] = []
        for i in (0...13).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -i, to: today) else { continue }
            
            var cLow = 2100, cHigh = 2500, cLikely = 2310, prot = 68, conf = 88, photos = 3, noPhotos = 0
            
            switch i {
            case 0:
                cLow = 1100; cHigh = 1450; cLikely = 1280; prot = 42; conf = 91; photos = 2; noPhotos = 0
            case 1:
                cLow = 2700; cHigh = 3300; cLikely = 2990; prot = 50; conf = 82; photos = 4; noPhotos = 1
            case 2:
                cLow = 2200; cHigh = 2650; cLikely = 2420; prot = 66; conf = 88; photos = 3; noPhotos = 0
            case 3:
                cLow = 2500; cHigh = 3000; cLikely = 2750; prot = 62; conf = 78; photos = 3; noPhotos = 1
            case 4:
                cLow = 1900; cHigh = 2350; cLikely = 2120; prot = 75; conf = 91; photos = 3; noPhotos = 0
            case 5:
                cLow = 2350; cHigh = 2800; cLikely = 2590; prot = 52; conf = 69; photos = 2; noPhotos = 2
            case 6:
                cLow = 2150; cHigh = 2600; cLikely = 2380; prot = 70; conf = 87; photos = 3; noPhotos = 0
            default:
                cLow = 2000 + i * 20; cHigh = 2400 + i * 30; cLikely = 2200 + i * 25; prot = 60 + i; conf = 85
            }
            
            let rollup = DailyRollup(
                userId: "usr_sidharth_902",
                date: date,
                caloriesLow: cLow,
                caloriesHigh: cHigh,
                caloriesLikely: cLikely,
                proteinG: prot,
                carbsG: cLikely * 50 / 100 / 4,
                fatG: cLikely * 30 / 100 / 9,
                eventsCount: photos + noPhotos,
                photoLogsCount: photos,
                noImageLogsCount: noPhotos,
                confidenceScore: conf
            )
            seedRollups.append(rollup)
        }
        
        self.dailyRollups = seedRollups
        if let currentRollup = seedRollups.last {
            self.todayRollup = currentRollup
        }
        
        personalMemory = [
            PersonalMemory(userId: "usr_sidharth_902", foodSignature: "home_lunch_matta_rice", displayName: "Amma's Matta Rice", usualPortionLabel: "Large", usualCaloriesLow: 380, usualCaloriesHigh: 480, usualCaloriesLikely: 430, correctionCount: 7, confidenceScore: 89),
            PersonalMemory(userId: "usr_sidharth_902", foodSignature: "home_fish_curry_coconut", displayName: "Amma's Fish Curry", usualPortionLabel: "Medium bowl", usualCaloriesLow: 180, usualCaloriesHigh: 260, usualCaloriesLikely: 220, correctionCount: 5, confidenceScore: 84),
            PersonalMemory(userId: "usr_sidharth_902", foodSignature: "breakfast_dosa_home", displayName: "Home Dosa", usualPortionLabel: "2 pieces", usualCaloriesLow: 220, usualCaloriesHigh: 300, usualCaloriesLikely: 260, correctionCount: 12, confidenceScore: 95),
            PersonalMemory(userId: "usr_sidharth_902", foodSignature: "filter_coffee_standard", displayName: "South Indian Filter Coffee", usualPortionLabel: "1 tumbler", usualCaloriesLow: 90, usualCaloriesHigh: 130, usualCaloriesLikely: 110, correctionCount: 19, confidenceScore: 92)
        ]
    }
}
