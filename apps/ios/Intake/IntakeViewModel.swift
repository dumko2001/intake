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
import SwiftUI
import Vision

public enum AppActiveView {
    case camera
    case analyzing
    case review
    case telemetry
}

@Observable
@MainActor
public final class IntakeViewModel {
    private let signerUrl = URL(string: "https://r2-signer.tallyup-invoices.workers.dev")!
    private let analyzerUrl = URL(string: "https://ai-analyzer.tallyup-invoices.workers.dev")!
    
    // Current UI view state
    public var activeView: AppActiveView = .camera
    
    // Core database collections loaded dynamically from D1
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
    public var processingError: String? = nil
    
    // Settings toggles
    public var isOnline: Bool = true
    
    // Aggregated stats today
    public var todayRollup = DailyRollup(
        userId: "usr_sidharth_902",
        date: Date(),
        caloriesLow: 0,
        caloriesHigh: 0,
        caloriesLikely: 0,
        proteinG: 0,
        carbsG: 0,
        fatG: 0,
        eventsCount: 0,
        photoLogsCount: 0,
        noImageLogsCount: 0,
        confidenceScore: 100
    )
    
    public init() {
        Task {
            await fetchTelemetry()
        }
    }
    
    // MARK: - Ingestion Pipeline
    
    public func triggerCapture(flowId: String) {
        triggerCapture(flowId: flowId, imageData: nil)
    }

    public func triggerCapture(flowId: String, imageData: Data?) {
        triggerCapture(intent: CaptureIntent(legacyFlowId: flowId), imageData: imageData)
    }

    public func triggerCapture(
        intent: CaptureIntent,
        imageData: Data? = nil,
        noteText: String? = nil,
        mealType: MealType? = nil
    ) {
        processingError = nil

        let trimmedNote = noteText?.trimmingCharacters(in: .whitespacesAndNewlines)
        if intent.requiresImage && imageData == nil {
            processingError = "Add a photo before analyzing this meal."
            return
        }

        activeView = .analyzing
        analysisStage = 1
        
        let eventId = UUID()
        let userId = "usr_sidharth_902"
        let now = Date()
        let resolvedMealType = mealType ?? intent.defaultMealType
        let resolvedNote: String? = {
            if let trimmedNote, !trimmedNote.isEmpty {
                return trimmedNote
            }
            if intent == .packageLabel {
                return "Packaged food label photo"
            }
            return nil
        }()
        
        let newEvent = FoodEvent(
            id: eventId,
            userId: userId,
            createdAt: now,
            mealTime: getFormattedTime(date: now),
            mealType: resolvedMealType,
            captureType: intent.captureType,
            status: .pending,
            rawTextNote: resolvedNote,
            primaryImageUrl: nil,
            thumbnailUrl: nil
        )
        
        self.activeEvent = newEvent
        
        Task {
            do {
                if !isOnline {
                    try await Task.sleep(nanoseconds: 1_500_000_000)
                    saveMealOffline(event: newEvent)
                    return
                }

                var uploadedImageUrl: String?
                var uploadedR2Key: String?
                var detectedBarcode: String?
                var barcodeAnalysis: BarcodeAnalysis?
                if let imageData {
                    if intent == .packageLabel {
                        detectedBarcode = await detectBarcodePayload(in: imageData)
                        if let detectedBarcode {
                            barcodeAnalysis = await lookupBarcodeProduct(detectedBarcode)
                        }
                    }

                    let signerRequest = try createSignerRequest(eventId: eventId, mimeType: "image/jpeg")
                    let (signerData, signerRes) = try await URLSession.shared.data(for: signerRequest)

                    guard (signerRes as? HTTPURLResponse)?.statusCode == 200 else {
                        throw NSError(domain: "Intake", code: 500, userInfo: [NSLocalizedDescriptionKey: "Photo upload authorization failed"])
                    }

                    let signerPayload = try JSONDecoder().decode(SignerResponse.self, from: signerData)

                    var uploadRequest = URLRequest(url: URL(string: signerPayload.upload_url)!)
                    uploadRequest.httpMethod = "PUT"
                    uploadRequest.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
                    uploadRequest.httpBody = imageData

                    let (_, uploadRes) = try await URLSession.shared.data(for: uploadRequest)
                    guard (uploadRes as? HTTPURLResponse)?.statusCode == 200 else {
                        throw NSError(domain: "Intake", code: 500, userInfo: [NSLocalizedDescriptionKey: "Photo upload failed"])
                    }

                    uploadedImageUrl = signerPayload.public_url
                    uploadedR2Key = signerPayload.r2_key
                    newEvent.primaryImageUrl = URL(string: signerPayload.public_url)
                    newEvent.thumbnailUrl = URL(string: signerPayload.public_url)
                }
                
                self.analysisStage = 2

                if let barcodeAnalysis {
                    newEvent.status = .needsReview
                    newEvent.rawTextNote = "Barcode: \(barcodeAnalysis.productName)"
                    self.activeItems = [
                        MealItem(
                            eventId: eventId,
                            nameDetected: barcodeAnalysis.productName,
                            nameNormalized: barcodeAnalysis.genericName,
                            portionUnit: barcodeAnalysis.portionUnit,
                            portionValue: barcodeAnalysis.portionValue,
                            estimatedGramsLikely: barcodeAnalysis.estimatedGrams,
                            confidence: "High"
                        )
                    ]
                    self.activeEstimate = EstimateVersion(
                        eventId: eventId,
                        modelProvider: "open-food-facts",
                        modelName: "barcode",
                        promptVersion: "barcode-v1",
                        nutritionEngineVersion: "off-v1",
                        caloriesLow: max(0, Int(Double(barcodeAnalysis.calories) * 0.9)),
                        caloriesHigh: Int(Double(barcodeAnalysis.calories) * 1.1),
                        caloriesLikely: barcodeAnalysis.calories,
                        proteinG: barcodeAnalysis.proteinG,
                        carbsG: barcodeAnalysis.carbsG,
                        fatG: barcodeAnalysis.fatG,
                        fiberG: barcodeAnalysis.fiberG,
                        confidenceScore: 96,
                        uncertaintyReasons: barcodeAnalysis.warnings
                    )
                    self.activeQuestion = PortionQuestion(
                        id: "refine_barcode_qty",
                        question: "How much did you eat?",
                        options: ["Quarter pack", "Half pack", "Whole pack", "More than one"],
                        defaultOption: "Whole pack",
                        correctionType: "portion",
                        uiType: "fraction_picker"
                    )
                    self.selectedCorrectionOption = "Whole pack"
                    try await Task.sleep(nanoseconds: 350_000_000)
                    self.activeView = .review
                    return
                }
                
                let ingestPayload = IngestRequest(
                    event_id: eventId.uuidString,
                    user_id: userId,
                    image_url: uploadedImageUrl,
                    r2_key: uploadedR2Key,
                    audio_url: nil,
                    model_name: "gemini-2.5-flash",
                    meal_time: getFormattedTime(date: now),
                    meal_type: resolvedMealType.rawValue,
                    capture_type: intent.captureType.rawValue,
                    raw_text_note: resolvedNote,
                    barcode: detectedBarcode
                )
                
                var ingestRequest = URLRequest(url: analyzerUrl.appendingPathComponent("api/ingest"))
                ingestRequest.httpMethod = "POST"
                ingestRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                ingestRequest.setValue("Bearer intake_secure_shield_902", forHTTPHeaderField: "Authorization")
                ingestRequest.httpBody = try JSONEncoder().encode(ingestPayload)
                
                let (ingestData, ingestRes) = try await URLSession.shared.data(for: ingestRequest)
                let ingestStatus = (ingestRes as? HTTPURLResponse)?.statusCode ?? 500
                guard ingestStatus == 200 else {
                    throw NSError(
                        domain: "Intake",
                        code: ingestStatus,
                        userInfo: [NSLocalizedDescriptionKey: userFacingAPIError(data: ingestData, statusCode: ingestStatus)]
                    )
                }
                
                self.analysisStage = 3
                let analysis = try JSONDecoder().decode(IngestResponse.self, from: ingestData)
                newEvent.mealType = MealType(rawValue: analysis.meal_type) ?? resolvedMealType
                newEvent.status = .needsReview
                
                self.activeItems = analysis.detected_items.map { item in
                    MealItem(
                        eventId: eventId,
                        nameDetected: item.name_detected,
                        nameNormalized: item.name_normalized,
                        portionUnit: item.portion_unit,
                        portionValue: item.portion_value,
                        estimatedGramsLikely: item.estimated_grams_likely,
                        confidence: item.confidence
                    )
                }
                
                self.activeEstimate = EstimateVersion(
                    eventId: eventId,
                    modelProvider: "google-ai",
                    modelName: "gemini-2.5-flash",
                    promptVersion: "v2.2",
                    nutritionEngineVersion: "vision-v1",
                    caloriesLow: analysis.estimates.calories_low,
                    caloriesHigh: analysis.estimates.calories_high,
                    caloriesLikely: analysis.estimates.calories_likely,
                    proteinG: analysis.estimates.protein_g,
                    carbsG: analysis.estimates.carbs_g,
                    fatG: analysis.estimates.fat_g,
                    fiberG: analysis.estimates.fiber_g,
                    confidenceScore: analysis.estimates.confidence_score,
                    uncertaintyReasons: analysis.estimates.uncertainty_reasons
                )
                
                self.activeQuestion = analysis.one_question
                self.selectedCorrectionOption = analysis.one_question?.defaultOption ?? ""

                try await Task.sleep(nanoseconds: 500_000_000)
                self.activeView = .review
                
            } catch {
                self.processingError = error.localizedDescription
                self.activeView = .camera
                self.activeEvent = nil
                print("INGEST FAILS:", error.localizedDescription)
            }
        }
    }
    
    // MARK: - Recomputation Loop (Stateless text-only cached shifts)
    
    public func selectCorrection(option: String) {
        guard let event = activeEvent, let currentEstimate = activeEstimate else { return }
        
        selectedCorrectionOption = option
        
        let recomputePayload = RecomputeRequest(
            action: "recompute",
            event_id: event.id.uuidString,
            user_id: event.userId,
            selection_option: option,
            original_detected_items: activeItems.map { item in
                DetectedItem(
                    name_detected: item.nameDetected,
                    name_normalized: item.nameNormalized,
                    portion_unit: item.portionUnit,
                    portion_value: item.portionValue,
                    estimated_grams_likely: item.estimatedGramsLikely,
                    confidence: item.confidence
                )
            },
            previous_estimates: RecomputeEstimates(
                calories_low: currentEstimate.caloriesLow,
                calories_high: currentEstimate.caloriesHigh,
                calories_likely: currentEstimate.caloriesLikely,
                protein_g: currentEstimate.proteinG,
                carbs_g: currentEstimate.carbsG,
                fat_g: currentEstimate.fatG,
                fiber_g: currentEstimate.fiberG,
                confidence_score: currentEstimate.confidenceScore,
                uncertainty_reasons: currentEstimate.uncertaintyReasons
            )
        )
        
        Task {
            do {
                var req = URLRequest(url: analyzerUrl.appendingPathComponent("api/recompute"))
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("Bearer intake_secure_shield_902", forHTTPHeaderField: "Authorization")
                req.httpBody = try JSONEncoder().encode(recomputePayload)
                
                let (resData, res) = try await URLSession.shared.data(for: req)
                guard (res as? HTTPURLResponse)?.statusCode == 200 else {
                    print("Recompute transaction rejected by Edge API")
                    return
                }
                
                let payload = try JSONDecoder().decode(RecomputeResponse.self, from: resData)
                
                withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                    currentEstimate.caloriesLow = payload.estimates.calories_low
                    currentEstimate.caloriesHigh = payload.estimates.calories_high
                    currentEstimate.caloriesLikely = payload.estimates.calories_likely
                    currentEstimate.proteinG = payload.estimates.protein_g
                    currentEstimate.carbsG = payload.estimates.carbs_g
                    currentEstimate.fatG = payload.estimates.fat_g
                    currentEstimate.fiberG = payload.estimates.fiber_g
                    currentEstimate.confidenceScore = payload.estimates.confidence_score
                    currentEstimate.uncertaintyReasons = payload.estimates.uncertainty_reasons
                    
                    // Proportional scale on detected portions!
                    if let firstItem = self.activeItems.first {
                        let scale = Double(payload.estimates.calories_likely) / Double(recomputePayload.previous_estimates.calories_likely)
                        firstItem.portionValue = (firstItem.portionValue * scale * 100).rounded() / 100.0
                    }
                }
            } catch {
                print("RECOMPUTE NET FAILURE:", error.localizedDescription)
            }
        }
    }
    
    // MARK: - Save Meal Action (Triggers explicit D1 transaction)
    
    public func saveMeal() {
        guard let event = activeEvent, let estimate = activeEstimate else { return }
        processingError = nil
        
        Task {
            do {
                let transaction = SaveTransactionRequest(
                    event_id: event.id.uuidString,
                    user_id: event.userId,
                    meal_time: event.mealTime,
                    meal_type: event.mealType.rawValue,
                    capture_type: event.captureType.rawValue,
                    raw_text_note: event.rawTextNote,
                    image_url: event.primaryImageUrl?.absoluteString,
                    items: activeItems.map { item in
                        DetectedItem(
                            name_detected: item.nameDetected,
                            name_normalized: item.nameNormalized,
                            portion_unit: item.portionUnit,
                            portion_value: item.portionValue,
                            estimated_grams_likely: item.estimatedGramsLikely,
                            confidence: item.confidence
                        )
                    },
                    estimates: RecomputeEstimates(
                        calories_low: estimate.caloriesLow,
                        calories_high: estimate.caloriesHigh,
                        calories_likely: estimate.caloriesLikely,
                        protein_g: estimate.proteinG,
                        carbs_g: estimate.carbsG,
                        fat_g: estimate.fatG,
                        fiber_g: estimate.fiberG,
                        confidence_score: estimate.confidenceScore,
                        uncertainty_reasons: estimate.uncertaintyReasons
                    )
                )
                
                var req = URLRequest(url: analyzerUrl.appendingPathComponent("api/save"))
                req.httpMethod = "POST"
                req.setValue("application/json", forHTTPHeaderField: "Content-Type")
                req.setValue("Bearer intake_secure_shield_902", forHTTPHeaderField: "Authorization")
                req.httpBody = try JSONEncoder().encode(transaction)
                
                let (_, res) = try await URLSession.shared.data(for: req)
                guard (res as? HTTPURLResponse)?.statusCode == 200 else {
                    throw NSError(domain: "Intake", code: 500, userInfo: [NSLocalizedDescriptionKey: "Save failed. Please try again."])
                }
                
                event.status = .saved
                savedEvents.insert(event, at: 0)
                savedItems[event.id] = activeItems
                savedEstimates[event.id] = estimate
                mergeSavedEventIntoLocalRollups(event: event, estimate: estimate)
                
                await fetchTelemetry()
                
                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                    activeView = .camera
                    activeEvent = nil
                    activeEstimate = nil
                    activeItems = []
                    activeQuestion = nil
                }
                
            } catch {
                self.processingError = error.localizedDescription
                print("SAVE FAILED:", error.localizedDescription)
            }
        }
    }
    
    private func saveMealOffline(event: FoodEvent) {
        event.status = .pending
        offlineQueue.append(event)
        savedEvents.insert(event, at: 0)
        
        withAnimation {
            activeView = .camera
            activeEvent = nil
        }
    }
    
    // MARK: - Synchronize Telemetry D1 GET routes
    
    public func fetchTelemetry() async {
        guard isOnline else { return }
        
        do {
            let userId = "usr_sidharth_902"
            
            let historyUrl = analyzerUrl.appending(path: "api/history").appending(queryItems: [URLQueryItem(name: "user_id", value: userId)])
            var histReq = URLRequest(url: historyUrl)
            histReq.setValue("Bearer intake_secure_shield_902", forHTTPHeaderField: "Authorization")
            let (histData, histRes) = try await URLSession.shared.data(for: histReq)
            
            if (histRes as? HTTPURLResponse)?.statusCode == 200 {
                let enrichedEvents = try JSONDecoder().decode([D1EnrichedEvent].self, from: histData)
                self.savedEvents = enrichedEvents.map { e in
                    let fe = FoodEvent(
                        id: UUID(uuidString: e.id) ?? UUID(),
                        userId: e.user_id,
                        createdAt: DateFormatter.iso8601.date(from: e.created_at) ?? Date(),
                        mealTime: e.meal_time,
                        mealType: MealType(rawValue: e.meal_type) ?? .lunch,
                        captureType: CaptureType(rawValue: e.capture_type) ?? .photo,
                        status: EventStatus(rawValue: e.status) ?? .saved,
                        rawTextNote: e.raw_text_note,
                        primaryImageUrl: e.primary_image_url.flatMap(URL.init),
                        thumbnailUrl: e.thumbnail_url.flatMap(URL.init)
                    )
                    
                    if let est = e.latest_estimate {
                        let ev = EstimateVersion(
                            eventId: fe.id,
                            modelProvider: est.model_provider,
                            modelName: est.model_name,
                            promptVersion: est.prompt_version,
                            nutritionEngineVersion: est.nutrition_engine_version,
                            caloriesLow: est.calories_low,
                            caloriesHigh: est.calories_high,
                            caloriesLikely: est.calories_likely,
                            proteinG: est.protein_g,
                            carbsG: est.carbs_g,
                            fatG: est.fat_g,
                            fiberG: est.fiber_g,
                            confidenceScore: est.confidence_score,
                            uncertaintyReasons: (try? JSONDecoder().decode([String].self, from: est.uncertainty_reasons.data(using: .utf8)!)) ?? []
                        )
                        self.savedEstimates[fe.id] = ev
                    }
                    
                    self.savedItems[fe.id] = e.items.map { it in
                        MealItem(
                            eventId: fe.id,
                            nameDetected: it.name_detected,
                            nameNormalized: it.name_normalized,
                            portionUnit: it.portion_unit,
                            portionValue: it.portion_value,
                            estimatedGramsLikely: it.estimated_grams_likely,
                            confidence: it.confidence
                        )
                    }
                    
                    return fe
                }
            }
            
            let rollupUrl = analyzerUrl.appending(path: "api/rollup").appending(queryItems: [URLQueryItem(name: "user_id", value: userId)])
            var rollReq = URLRequest(url: rollupUrl)
            rollReq.setValue("Bearer intake_secure_shield_902", forHTTPHeaderField: "Authorization")
            let (rollData, rollRes) = try await URLSession.shared.data(for: rollReq)
            
            if (rollRes as? HTTPURLResponse)?.statusCode == 200 {
                let d1Rollups = try JSONDecoder().decode([D1Rollup].self, from: rollData)
                self.dailyRollups = d1Rollups.map { r in
                    DailyRollup(
                        userId: r.user_id,
                        date: DateFormatter.yyyyMMdd.date(from: r.date) ?? Date(),
                        caloriesLow: r.calories_low,
                        caloriesHigh: r.calories_high,
                        caloriesLikely: r.calories_likely,
                        proteinG: r.protein_g,
                        carbsG: r.carbs_g,
                        fatG: r.fat_g,
                        eventsCount: r.events_count,
                        photoLogsCount: r.photo_logs_count,
                        noImageLogsCount: r.no_image_logs_count,
                        confidenceScore: r.confidence_score
                    )
                }
                
                if let today = dailyRollups.last {
                    self.todayRollup = today
                }
            }
            
        } catch {
            print("TELEMETRY FETCH FAILS:", error.localizedDescription)
        }
    }
    
    public func toggleOnline() {
        isOnline.toggle()
        if isOnline && !offlineQueue.isEmpty {
            Task {
                for i in 0..<offlineQueue.count {
                    let queued = offlineQueue[i]
                    queued.status = .saved
                }
                offlineQueue.removeAll()
                await fetchTelemetry()
            }
        }
    }
    
    // MARK: - Private Utilities
    
    private func getFormattedTime(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
    
    private func createSignerRequest(eventId: UUID, mimeType: String) throws -> URLRequest {
        var req = URLRequest(url: signerUrl)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("Bearer intake_secure_shield_902", forHTTPHeaderField: "Authorization")
        let payload = SignerRequest(event_id: eventId.uuidString, mime_type: mimeType, file_extension: mimeType == "image/jpeg" ? "jpg" : "m4a")
        req.httpBody = try JSONEncoder().encode(payload)
        return req
    }

    private func detectBarcodePayload(in imageData: Data) async -> String? {
        await Task.detached(priority: .userInitiated) {
            let request = VNDetectBarcodesRequest()
            request.symbologies = [
                .ean8,
                .ean13,
                .upce,
                .code128,
                .qr,
                .dataMatrix,
                .pdf417
            ]

            let handler = VNImageRequestHandler(data: imageData, options: [:])
            try? handler.perform([request])
            return request.results?
                .compactMap { $0.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .first { !$0.isEmpty }
        }.value
    }

    private func lookupBarcodeProduct(_ barcode: String) async -> BarcodeAnalysis? {
        let encodedBarcode = barcode.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? barcode
        let urls = [
            "https://api.openfoodfacts.org/api/v2/product/\(encodedBarcode)",
            "https://ssl-api.openfoodfacts.org/api/v2/product/\(encodedBarcode)",
            "https://world.openfoodfacts.org/api/v2/product/\(encodedBarcode)"
        ].compactMap(URL.init(string:))

        for url in urls {
            do {
                var request = URLRequest(url: url)
                request.setValue("application/json", forHTTPHeaderField: "Accept")
                request.setValue("Intake iOS/1.0", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard (response as? HTTPURLResponse)?.statusCode == 200 else { continue }
                guard
                    let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                    (root["status"] as? Int) == 1,
                    let product = root["product"] as? [String: Any]
                else { continue }

                let nutriments = product["nutriments"] as? [String: Any] ?? [:]
                let name = nonEmptyString(product["product_name"]) ?? nonEmptyString(product["generic_name"]) ?? "Packaged food"
                let generic = nonEmptyString(product["generic_name"]) ?? name
                let servingSize = nonEmptyString(product["serving_size"]) ?? "serving"
                let servingGrams = numberValue(product["serving_quantity"]) ?? 100
                let calories = Int((numberValue(nutriments["energy-kcal_serving"]) ?? numberValue(nutriments["energy-kcal_100g"]) ?? 120).rounded())
                let protein = Int((numberValue(nutriments["proteins_serving"]) ?? numberValue(nutriments["proteins_100g"]) ?? 0).rounded())
                let carbs = Int((numberValue(nutriments["carbohydrates_serving"]) ?? numberValue(nutriments["carbohydrates_100g"]) ?? 0).rounded())
                let fat = Int((numberValue(nutriments["fat_serving"]) ?? numberValue(nutriments["fat_100g"]) ?? 0).rounded())
                let fiber = Int((numberValue(nutriments["fiber_serving"]) ?? numberValue(nutriments["fiber_100g"]) ?? 0).rounded())

                var warnings: [String] = []
                if let allergens = nonEmptyString(product["allergens_from_ingredients"]) {
                    warnings.append("Allergens: \(allergens)")
                }
                if let additives = product["additives_tags"] as? [Any], additives.count > 3 {
                    warnings.append("High additive count")
                }

                return BarcodeAnalysis(
                    productName: name,
                    genericName: generic,
                    portionUnit: servingSize == "serving" ? "serving" : servingSize,
                    portionValue: 1,
                    estimatedGrams: Int(servingGrams.rounded()),
                    calories: calories,
                    proteinG: protein,
                    carbsG: carbs,
                    fatG: fat,
                    fiberG: fiber,
                    warnings: warnings
                )
            } catch {
                continue
            }
        }

        return nil
    }

    private func nonEmptyString(_ value: Any?) -> String? {
        guard let string = value as? String else { return nil }
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func numberValue(_ value: Any?) -> Double? {
        if let double = value as? Double {
            return double
        }
        if let int = value as? Int {
            return Double(int)
        }
        if let string = value as? String {
            return Double(string)
        }
        return nil
    }

    private func mergeSavedEventIntoLocalRollups(event: FoodEvent, estimate: EstimateVersion) {
        guard Calendar.current.isDateInToday(event.createdAt) else { return }

        todayRollup.caloriesLow += estimate.caloriesLow
        todayRollup.caloriesHigh += estimate.caloriesHigh
        todayRollup.caloriesLikely += estimate.caloriesLikely
        todayRollup.proteinG += estimate.proteinG
        todayRollup.carbsG += estimate.carbsG
        todayRollup.fatG += estimate.fatG
        todayRollup.eventsCount += 1
        todayRollup.photoLogsCount += event.primaryImageUrl == nil ? 0 : 1
        todayRollup.noImageLogsCount += event.primaryImageUrl == nil ? 1 : 0
        todayRollup.confidenceScore = estimate.confidenceScore

        if let index = dailyRollups.firstIndex(where: { Calendar.current.isDate($0.date, inSameDayAs: event.createdAt) }) {
            dailyRollups[index] = todayRollup
        } else {
            dailyRollups.append(todayRollup)
        }
    }

    private func userFacingAPIError(data: Data, statusCode: Int) -> String {
        let decodedError = try? JSONDecoder().decode(APIErrorResponse.self, from: data)
        let rawMessage = [decodedError?.message, decodedError?.error]
            .compactMap { $0 }
            .first { !$0.isEmpty }
        let lowercased = rawMessage?.lowercased() ?? ""

        if statusCode == 422 || lowercased.contains("no food") {
            return "No food detected. Take a clear photo of food or a nutrition label."
        }
        if lowercased.contains("fetch image") || lowercased.contains("image url") || lowercased.contains("not readable") {
            return "The uploaded photo could not be read. Please retake it or choose another photo."
        }
        if statusCode == 401 {
            return "The app is not authorized to analyze meals right now."
        }
        if statusCode == 503 || lowercased.contains("temporarily busy") || lowercased.contains("high demand") {
            return "Meal analysis is temporarily busy. Please try again."
        }
        if let rawMessage, !rawMessage.isEmpty {
            return rawMessage
        }
        return "Meal analysis failed. Please try again."
    }
}

// MARK: - Save SQL Transaction Request Contract

private struct BarcodeAnalysis {
    let productName: String
    let genericName: String
    let portionUnit: String
    let portionValue: Double
    let estimatedGrams: Int
    let calories: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int
    let fiberG: Int
    let warnings: [String]
}

struct SaveTransactionRequest: Codable {
    let event_id: String
    let user_id: String
    let meal_time: String
    let meal_type: String
    let capture_type: String
    let raw_text_note: String?
    let image_url: String?
    let items: [DetectedItem]
    let estimates: RecomputeEstimates
}
