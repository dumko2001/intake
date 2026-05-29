import Foundation

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
    let image_url: String?
    let r2_key: String?
    let audio_url: String?
    let model_name: String?
    let meal_time: String
    let meal_type: String
    let capture_type: String
    let raw_text_note: String?
    let barcode: String?
}

struct DetectedItem: Codable {
    let name_detected: String
    let name_normalized: String
    let portion_unit: String
    let portion_value: Double
    let estimated_grams_likely: Int
    let confidence: String
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

    init(
        calories_low: Int,
        calories_high: Int,
        calories_likely: Int,
        protein_g: Int,
        carbs_g: Int,
        fat_g: Int,
        fiber_g: Int?,
        confidence_score: Int,
        uncertainty_reasons: [String]
    ) {
        self.calories_low = calories_low
        self.calories_high = calories_high
        self.calories_likely = calories_likely
        self.protein_g = protein_g
        self.carbs_g = carbs_g
        self.fat_g = fat_g
        self.fiber_g = fiber_g
        self.confidence_score = confidence_score
        self.uncertainty_reasons = uncertainty_reasons
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        calories_low = try container.decodeRoundedInt(forKey: .calories_low)
        calories_high = try container.decodeRoundedInt(forKey: .calories_high)
        calories_likely = try container.decodeRoundedInt(forKey: .calories_likely)
        protein_g = try container.decodeRoundedInt(forKey: .protein_g)
        carbs_g = try container.decodeRoundedInt(forKey: .carbs_g)
        fat_g = try container.decodeRoundedInt(forKey: .fat_g)
        fiber_g = try container.decodeRoundedIntIfPresent(forKey: .fiber_g)
        confidence_score = try container.decodeRoundedInt(forKey: .confidence_score)
        uncertainty_reasons = (try? container.decode([String].self, forKey: .uncertainty_reasons)) ?? []
    }
}

struct IngestResponse: Codable {
    let event_id: String
    let meal_type: String
    let detected_items: [DetectedItem]
    let estimates: RecomputeEstimates
    let one_question: PortionQuestion?
}

struct APIErrorResponse: Codable {
    let error: String?
    let message: String?
}

struct RecomputeRequest: Codable {
    let action: String
    let event_id: String
    let user_id: String
    let selection_option: String
    let original_detected_items: [DetectedItem]
    let previous_estimates: RecomputeEstimates
}

struct RecomputeResponse: Codable {
    let event_id: String
    let estimates: RecomputeEstimates
}

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
    let items: [D1MealItem]
    let latest_estimate: D1Estimate?
}

struct D1MealItem: Codable {
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        model_provider = try container.decode(String.self, forKey: .model_provider)
        model_name = try container.decode(String.self, forKey: .model_name)
        prompt_version = try container.decode(String.self, forKey: .prompt_version)
        nutrition_engine_version = try container.decode(String.self, forKey: .nutrition_engine_version)
        calories_low = try container.decodeRoundedInt(forKey: .calories_low)
        calories_high = try container.decodeRoundedInt(forKey: .calories_high)
        calories_likely = try container.decodeRoundedInt(forKey: .calories_likely)
        protein_g = try container.decodeRoundedInt(forKey: .protein_g)
        carbs_g = try container.decodeRoundedInt(forKey: .carbs_g)
        fat_g = try container.decodeRoundedInt(forKey: .fat_g)
        fiber_g = try container.decodeRoundedIntIfPresent(forKey: .fiber_g)
        confidence_score = try container.decodeRoundedInt(forKey: .confidence_score)
        uncertainty_reasons = (try? container.decode(String.self, forKey: .uncertainty_reasons)) ?? "[]"
    }
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

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        user_id = try container.decode(String.self, forKey: .user_id)
        date = try container.decode(String.self, forKey: .date)
        calories_low = try container.decodeRoundedInt(forKey: .calories_low)
        calories_high = try container.decodeRoundedInt(forKey: .calories_high)
        calories_likely = try container.decodeRoundedInt(forKey: .calories_likely)
        protein_g = try container.decodeRoundedInt(forKey: .protein_g)
        carbs_g = try container.decodeRoundedInt(forKey: .carbs_g)
        fat_g = try container.decodeRoundedInt(forKey: .fat_g)
        events_count = try container.decodeRoundedInt(forKey: .events_count)
        photo_logs_count = try container.decodeRoundedInt(forKey: .photo_logs_count)
        no_image_logs_count = try container.decodeRoundedInt(forKey: .no_image_logs_count)
        confidence_score = try container.decodeRoundedInt(forKey: .confidence_score)
    }
}

extension KeyedDecodingContainer {
    func decodeRoundedInt(forKey key: Key) throws -> Int {
        if let intValue = try? decode(Int.self, forKey: key) {
            return intValue
        }
        if let doubleValue = try? decode(Double.self, forKey: key) {
            return Int(doubleValue.rounded())
        }
        if let stringValue = try? decode(String.self, forKey: key), let doubleValue = Double(stringValue) {
            return Int(doubleValue.rounded())
        }
        return 0
    }

    func decodeRoundedIntIfPresent(forKey key: Key) throws -> Int? {
        if !contains(key) {
            return nil
        }
        return try decodeRoundedInt(forKey: key)
    }
}

extension DateFormatter {
    static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSXXXXX"
        return formatter
    }()

    static let yyyyMMdd: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}
