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
    // Endpoints pointing to your live serverless Cloudflare Workers
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
    public var voiceAnnotationEnabled: Bool = true
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
        // Initial sync of rollups and history from Cloudflare D1
        Task {
            await fetchTelemetry()
        }
    }
    
    // MARK: - Ingestion Pipeline (Cloudflare Edge Worker + Gemini Files API)
    
    public func triggerCapture(flowId: String) {
        processingError = nil
        activeView = .analyzing
        analysisStage = 1 // Media ingestion & upload
        
        let eventId = UUID()
        let userId = "usr_sidharth_902"
        let now = Date()
        
        // Define default mock meal visual properties to fetch and upload natively to D1/R2
        var visualUrlString = "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600"
        var noteText: String? = nil
        var captureType: CaptureType = .photo
        
        switch flowId {
        case "kerala_lunch":
            visualUrlString = "https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=600"
            noteText = voiceAnnotationEnabled ? "Lunch with Rice, fish curry, thoran, pappadam" : nil
            captureType = voiceAnnotationEnabled ? .photoVoice : .photo
        case "banana_chips":
            visualUrlString = "https://images.unsplash.com/photo-1566478989037-eec170784d0b?w=600"
            noteText = "Snacking on packaged chips at desk"
            captureType = .photo
        case "dosa_backfill":
            visualUrlString = "https://images.unsplash.com/photo-1668236543090-82eba5ee5976?w=600"
            noteText = "Dosas with coconut chutney, filter coffee"
            captureType = .backfillVoice
        default:
            break
        }
        
        let newEvent = FoodEvent(
            id: eventId,
            userId: userId,
            createdAt: now,
            mealTime: getFormattedTime(date: now),
            mealType: flowId == "banana_chips" ? .snack : (flowId == "dosa_backfill" ? .breakfast : .lunch),
            captureType: captureType,
            status: .pending,
            rawTextNote: noteText,
            primaryImageUrl: URL(string: visualUrlString),
            thumbnailUrl: URL(string: visualUrlString)
        )
        
        self.activeEvent = newEvent
        
        Task {
            do {
                if !isOnline {
                    // Offline fallback: save event locally
                    try await Task.sleep(nanoseconds: 1_500_000_000)
                    saveMealOffline(event: newEvent)
                    return
                }
                
                // 1. Fetch raw asset binary
                guard let assetUrl = URL(string: visualUrlString) else {
                    throw NSError(domain: "Intake", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid asset source URL"])
                }
                
                let (imageData, _) = try await URLSession.shared.data(from: assetUrl)
                
                // 2. Request R2 Upload Presigned URL from r2-signer
                let signerRequest = try createSignerRequest(eventId: eventId, mimeType: "image/jpeg")
                let (signerData, signerRes) = try await URLSession.shared.data(for: signerRequest)
                
                guard (signerRes as? HTTPURLResponse)?.statusCode == 200 else {
                    throw NSError(domain: "Intake", code: 500, userInfo: [NSLocalizedDescriptionKey: "R2 presigned URL authorization failed"])
                }
                
                let signerPayload = try JSONDecoder().decode(SignerResponse.self, from: signerData)
                
                // 3. Upload Binary Image strictly zero-Base64 directly to R2 bucket
                var uploadRequest = URLRequest(url: URL(string: signerPayload.upload_url)!)
                uploadRequest.httpMethod = "PUT"
                uploadRequest.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
                uploadRequest.httpBody = imageData
                
                let (_, uploadRes) = try await URLSession.shared.data(for: uploadRequest)
                guard (uploadRes as? HTTPURLResponse)?.statusCode == 200 else {
                    throw NSError(domain: "Intake", code: 500, userInfo: [NSLocalizedDescriptionKey: "R2 PUT asset streaming failed"])
                }
                
                // 4. Handle optional simulated audio voice note upload
                var r2AudioUrl: String? = nil
                if voiceAnnotationEnabled && flowId == "kerala_lunch" {
                    // Create simulated audio note binary representing vocal calibration
                    let mockAudioText = "This is Kerala Matta Rice, about 1.5 cups, with standard fish curry and Thoran."
                    let mockAudioData = mockAudioText.data(using: .utf8)!
                    
                    let audSignerReq = try createSignerRequest(eventId: eventId, mimeType: "audio/mp4")
                    let (audSignerData, _) = try await URLSession.shared.data(for: audSignerReq)
                    let audSignerPayload = try JSONDecoder().decode(SignerResponse.self, from: audSignerData)
                    
                    var audUploadReq = URLRequest(url: URL(string: audSignerPayload.upload_url)!)
                    audUploadReq.httpMethod = "PUT"
                    audUploadReq.setValue("audio/mp4", forHTTPHeaderField: "Content-Type")
                    audUploadReq.httpBody = mockAudioData
                    
                    let (_, audUploadRes) = try await URLSession.shared.data(for: audUploadReq)
                    if (audUploadRes as? HTTPURLResponse)?.statusCode == 200 {
                        r2AudioUrl = audSignerPayload.public_url
                    }
                }
                
                self.analysisStage = 2 // Multimodal edge model parsing
                
                // 5. Invoke Edge Ingest Pipeline
                let ingestPayload = IngestRequest(
                    event_id: eventId.uuidString,
                    user_id: userId,
                    image_url: signerPayload.public_url,
                    audio_url: r2AudioUrl,
                    model_name: "gemini-3.5-flash",
                    meal_time: getFormattedTime(date: now),
                    meal_type: newEvent.mealType.rawValue,
                    capture_type: captureType.rawValue,
                    raw_text_note: noteText
                )
                
                var ingestRequest = URLRequest(url: analyzerUrl)
                ingestRequest.httpMethod = "POST"
                ingestRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
                ingestRequest.httpBody = try JSONEncoder().encode(ingestPayload)
                
                let (ingestData, ingestRes) = try await URLSession.shared.data(for: ingestRequest)
                guard (ingestRes as? HTTPURLResponse)?.statusCode == 200 else {
                    let errStr = String(data: ingestData, encoding: .utf8) ?? "Unknown Ingestion pipeline failure"
                    throw NSError(domain: "Intake", code: 500, userInfo: [NSLocalizedDescriptionKey: errStr])
                }
                
                self.analysisStage = 3 // Calibrating layout structures
                let analysis = try JSONDecoder().decode(IngestResponse.self, from: ingestData)
                
                // Establish structured records returned by Gemini D1 database execution
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
                    modelName: "gemini-3.5-flash",
                    promptVersion: "v2.1",
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
                
                // Save locally
                newEvent.status = .analyzed
                newEvent.primaryImageUrl = URL(string: signerPayload.public_url)
                
                try await Task.sleep(nanoseconds: 500_000_000)
                self.activeView = .review
                
            } catch {
                self.processingError = error.localizedDescription
                self.activeView = .camera
                self.activeEvent = nil
                print("INGEST ERROR:", error.localizedDescription)
            }
        }
    }
    
    // MARK: - Rapid Text-Only Prompt-Cached Recompute
    
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
                req.httpBody = try JSONEncoder().encode(recomputePayload)
                
                let (resData, res) = try await URLSession.shared.data(for: req)
                guard (res as? HTTPURLResponse)?.statusCode == 200 else {
                    print("Recompute query rejected by Edge API")
                    return
                }
                
                let payload = try JSONDecoder().decode(RecomputeResponse.self, from: resData)
                
                // Spring animate calorie and macro shifts instantly!
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
                }
            } catch {
                print("RECOMPUTE NET FAILURE:", error.localizedDescription)
            }
        }
    }
    
    // MARK: - Save Log Coordinates
    
    public func saveMeal() {
        guard let event = activeEvent, let estimate = activeEstimate else { return }
        
        event.status = .saved
        
        savedEvents.insert(event, at: 0)
        savedItems[event.id] = activeItems
        savedEstimates[event.id] = estimate
        
        // Refresh telemetry database stats dynamically
        Task {
            await fetchTelemetry()
        }
        
        // Complete the feedback loop and transition back to camera
        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
            activeView = .camera
            activeEvent = nil
            activeEstimate = nil
            activeItems = []
            activeQuestion = nil
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
    
    // MARK: - Database Rollups Synchronizations (Cloud D1 GET Endpoints)
    
    public func fetchTelemetry() async {
        guard isOnline else { return }
        
        do {
            let userId = "usr_sidharth_902"
            
            // 1. Fetch D1 SQLite Event Ledger history
            let historyUrl = analyzerUrl.appending(path: "api/history").appending(queryItems: [URLQueryItem(name: "user_id", value: userId)])
            let (histData, histRes) = try await URLSession.shared.data(from: historyUrl)
            
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
            
            // 2. Fetch D1 SQLite rollups
            let rollupUrl = analyzerUrl.appending(path: "api/rollup").appending(queryItems: [URLQueryItem(name: "user_id", value: userId)])
            let (rollData, rollRes) = try await URLSession.shared.data(from: rollupUrl)
            
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
        let payload = SignerRequest(event_id: eventId.uuidString, mime_type: mimeType, file_extension: mimeType == "image/jpeg" ? "jpg" : "m4a")
        req.httpBody = try JSONEncoder().encode(payload)
        return req
    }
}

// MARK: - Ingestion Networking Contracts

struct SignerRequest: Codable {
    let event_id: String
    let mime_type: String
    let file_extension: String
}

struct SignerResponse: Codable {
    let upload_url: String
    let r2_key: String
    let public_url: String
}

struct IngestRequest: Codable {
    let event_id: String
    let user_id: String
    let image_url: String
    let audio_url: String?
    let model_name: String
    let meal_time: String
    let meal_type: String
    let capture_type: String
    let raw_text_note: String?
}

struct DetectedItem: Codable {
    let name_detected: String
    let name_normalized: String
    let portion_unit: String
    let portion_value: Double
    let estimated_grams_likely: Int
    let confidence: String
}

struct IngestEstimates: Codable {
    let calories_low: Int
    let calories_high: Int
    let calories_likely: Int
    let protein_g: Int
    let carbs_g: Int
    let fat_g: Int
    let fiber_g: Int?
    let confidence_score: Int
    let uncertainty_reasons: [String]
}

struct IngestResponse: Codable {
    let meal_type: String
    let detected_items: [DetectedItem]
    let estimates: IngestEstimates
    let one_question: PortionQuestion?
}

// MARK: - Recomputation Contracts

struct RecomputeRequest: Codable {
    let action: String
    let event_id: String
    let user_id: String
    let selection_option: String
    let original_detected_items: [DetectedItem]
    let previous_estimates: RecomputeEstimates
}

struct RecomputeEstimates: Codable {
    let calories_low: Int
    let calories_high: Int
    let calories_likely: Int
    let protein_g: Int
    let carbs_g: Int
    let fat_g: Int
    let fiber_g: Int?
    let confidence_score: Int
    let uncertainty_reasons: [String]
}

struct RecomputeResponse: Codable {
    let event_id: String
    let estimates: RecomputeEstimates
}

// MARK: - D1 Database Pull Decoders

struct D1EnrichedEvent: Codable {
    let id: String
    let user_id: String
    let created_at: String
    let meal_time: String
    let meal_type: String
    let capture_type: String
    let status: String
    let raw_text_note: String?
    let primary_image_url: String?
    let thumbnail_url: String?
    let items: [D1Item]
    let latest_estimate: D1Estimate?
}

struct D1Item: Codable {
    let name_detected: String
    let name_normalized: String
    let portion_unit: String
    let portion_value: Double
    let estimated_grams_likely: Int
    let confidence: String
}

struct D1Estimate: Codable {
    let model_provider: String
    let model_name: String
    let prompt_version: String
    let nutrition_engine_version: String
    let calories_low: Int
    let calories_high: Int
    let calories_likely: Int
    let protein_g: Int
    let carbs_g: Int
    let fat_g: Int
    let fiber_g: Int?
    let confidence_score: Int
    let uncertainty_reasons: String
}

struct D1Rollup: Codable {
    let user_id: String
    let date: String
    let calories_low: Int
    let calories_high: Int
    let calories_likely: Int
    let protein_g: Int
    let carbs_g: Int
    let fat_g: Int
    let events_count: Int
    let photo_logs_count: Int
    let no_image_logs_count: Int
    let confidence_score: Int
}

// MARK: - Date Formatting Helpers

extension DateFormatter {
    static let iso8601: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()
    
    static let yyyyMMdd: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
}
