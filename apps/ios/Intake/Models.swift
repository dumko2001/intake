//
//  Models.swift
//  Intake
//
//  Created by Sidharth on 5/24/2026.
//  Copyright © 2026 Intake. All rights reserved.
//

import Foundation
import SwiftData

/// Represents the capture type of the ingestion log
public enum CaptureType: String, Codable {
    case photo = "photo"
    case photoVoice = "photo_voice"
    case backfillText = "backfill_text"
    case backfillVoice = "backfill_voice"
}

public enum CaptureIntent: String, Codable, Hashable {
    case mealPhoto = "meal_photo"
    case packageLabel = "package_label"

    public init(legacyFlowId: String) {
        switch legacyFlowId {
        case "package_label":
            self = .packageLabel
        default:
            self = .mealPhoto
        }
    }

    public var requiresImage: Bool {
        true
    }

    public var defaultMealType: MealType {
        switch self {
        case .mealPhoto:
            return .defaultForCurrentTime()
        case .packageLabel:
            return .snack
        }
    }

    public var captureType: CaptureType {
        .photo
    }
}

/// Represents the current server synchronization and parsing status
public enum EventStatus: String, Codable {
    case pending = "pending"
    case analyzed = "analyzed"
    case needsReview = "needs_review"
    case saved = "saved"
    case failed = "failed"
}

public enum HealthGoal: String, Codable, CaseIterable, Identifiable {
    case maintain
    case lose
    case gain
    case recomp

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .maintain: return "Maintain"
        case .lose: return "Lose"
        case .gain: return "Gain"
        case .recomp: return "Recomp"
        }
    }

    public var dailyCalorieAdjustment: Int {
        switch self {
        case .maintain: return 0
        case .lose: return -350
        case .gain: return 300
        case .recomp: return -100
        }
    }
}

public enum ActivityLevel: String, Codable, CaseIterable, Identifiable {
    case low
    case moderate
    case high

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .low: return "Light"
        case .moderate: return "Moderate"
        case .high: return "Active"
        }
    }

    public var multiplier: Double {
        switch self {
        case .low: return 1.35
        case .moderate: return 1.55
        case .high: return 1.75
        }
    }
}

public enum IntakeSex: String, Codable, CaseIterable, Identifiable {
    case female
    case male
    case unspecified

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .female: return "Female"
        case .male: return "Male"
        case .unspecified: return "Skip"
        }
    }
}

public struct NutritionTarget: Codable, Hashable {
    public var effectiveFrom: Date
    public var caloriesKcal: Int
    public var proteinG: Int
    public var carbsG: Int
    public var fatG: Int

    public init(
        effectiveFrom: Date = Date(),
        caloriesKcal: Int,
        proteinG: Int,
        carbsG: Int,
        fatG: Int
    ) {
        self.effectiveFrom = effectiveFrom
        self.caloriesKcal = caloriesKcal
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
    }

    public var macroCalories: Int {
        proteinG * 4 + carbsG * 4 + fatG * 9
    }

    public var isMacroBalanced: Bool {
        abs(macroCalories - caloriesKcal) <= 25
    }

    public func rebalanced(calories: Int? = nil, protein: Int? = nil, fatPercentOfRemaining: Double = 0.35) -> NutritionTarget {
        let resolvedCalories = max(900, min(5200, calories ?? caloriesKcal))
        let resolvedProtein = max(35, min(260, protein ?? proteinG))
        let remainingCalories = max(160, resolvedCalories - resolvedProtein * 4)
        let fatCalories = Double(remainingCalories) * fatPercentOfRemaining
        let resolvedFat = max(20, Int((fatCalories / 9).rounded()))
        let carbsCalories = max(0, resolvedCalories - resolvedProtein * 4 - resolvedFat * 9)
        let resolvedCarbs = max(0, Int((Double(carbsCalories) / 4).rounded()))

        return NutritionTarget(
            effectiveFrom: Date(),
            caloriesKcal: resolvedCalories,
            proteinG: resolvedProtein,
            carbsG: resolvedCarbs,
            fatG: resolvedFat
        )
    }

    public func adjustedForAdvancedMacro(protein: Int? = nil, carbs: Int? = nil, fat: Int? = nil) -> NutritionTarget {
        let resolvedProtein = max(35, min(260, protein ?? proteinG))
        let resolvedCarbs = max(0, min(650, carbs ?? carbsG))
        let resolvedFat = max(20, min(230, fat ?? fatG))
        return NutritionTarget(
            effectiveFrom: Date(),
            caloriesKcal: resolvedProtein * 4 + resolvedCarbs * 4 + resolvedFat * 9,
            proteinG: resolvedProtein,
            carbsG: resolvedCarbs,
            fatG: resolvedFat
        )
    }
}

public struct UserProfile: Codable, Hashable {
    public var userId: String
    public var completedOnboarding: Bool
    public var currentWeightKg: Double
    public var heightCm: Double
    public var age: Int
    public var sex: IntakeSex
    public var goal: HealthGoal
    public var activityLevel: ActivityLevel
    public var target: NutritionTarget
    public var updatedAt: Date

    public init(
        userId: String,
        completedOnboarding: Bool = false,
        currentWeightKg: Double,
        heightCm: Double,
        age: Int,
        sex: IntakeSex = .unspecified,
        goal: HealthGoal,
        activityLevel: ActivityLevel,
        target: NutritionTarget,
        updatedAt: Date = Date()
    ) {
        self.userId = userId
        self.completedOnboarding = completedOnboarding
        self.currentWeightKg = currentWeightKg
        self.heightCm = heightCm
        self.age = age
        self.sex = sex
        self.goal = goal
        self.activityLevel = activityLevel
        self.target = target
        self.updatedAt = updatedAt
    }
}

public struct WeightLog: Codable, Hashable, Identifiable {
    public var id: UUID
    public var userId: String
    public var loggedAt: Date
    public var weightKg: Double

    public init(id: UUID = UUID(), userId: String, loggedAt: Date = Date(), weightKg: Double) {
        self.id = id
        self.userId = userId
        self.loggedAt = loggedAt
        self.weightKg = weightKg
    }
}

/// Represents the meal type classifications
public enum MealType: String, Codable {
    case breakfast = "breakfast"
    case lunch = "lunch"
    case dinner = "dinner"
    case snack = "snack"

    public static func defaultForCurrentTime(_ date: Date = Date(), calendar: Calendar = .current) -> MealType {
        let hour = calendar.component(.hour, from: date)
        switch hour {
        case 5..<11:
            return .breakfast
        case 11..<16:
            return .lunch
        case 16..<18:
            return .snack
        case 18..<23:
            return .dinner
        default:
            return .snack
        }
    }
}

/// Core immutable meal logging event record persistently managed via SwiftData
@Model
public final class FoodEvent {
    @Attribute(.unique) public var id: UUID
    public var userId: String
    public var createdAt: Date
    public var mealTime: String
    public var mealTypeRaw: String
    public var captureTypeRaw: String
    public var statusRaw: String
    public var rawTextNote: String?
    public var primaryImageUrlString: String?
    public var thumbnailUrlString: String?
    public var timezone: String
    public var locationLabelOptional: String?
    
    // Cascading relationships managed by SwiftData
    @Relationship(deleteRule: .cascade) public var items: [MealItem] = []
    @Relationship(deleteRule: .cascade) public var estimates: [EstimateVersion] = []

    public var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw) ?? .lunch }
        set { mealTypeRaw = newValue.rawValue }
    }
    
    public var captureType: CaptureType {
        get { CaptureType(rawValue: captureTypeRaw) ?? .photo }
        set { captureTypeRaw = newValue.rawValue }
    }
    
    public var status: EventStatus {
        get { EventStatus(rawValue: statusRaw) ?? .pending }
        set { statusRaw = newValue.rawValue }
    }

    public var primaryImageUrl: URL? {
        get { primaryImageUrlString.flatMap(URL.init) }
        set { primaryImageUrlString = newValue?.absoluteString }
    }

    public var thumbnailUrl: URL? {
        get { thumbnailUrlString.flatMap(URL.init) }
        set { thumbnailUrlString = newValue?.absoluteString }
    }

    public init(
        id: UUID = UUID(),
        userId: String,
        createdAt: Date = Date(),
        mealTime: String,
        mealType: MealType,
        captureType: CaptureType,
        status: EventStatus = .pending,
        rawTextNote: String? = nil,
        primaryImageUrl: URL? = nil,
        thumbnailUrl: URL? = nil,
        timezone: String = TimeZone.current.identifier,
        locationLabelOptional: String? = nil
    ) {
        self.id = id
        self.userId = userId
        self.createdAt = createdAt
        self.mealTime = mealTime
        self.mealTypeRaw = mealType.rawValue
        self.captureTypeRaw = captureType.rawValue
        self.statusRaw = status.rawValue
        self.rawTextNote = rawTextNote
        self.primaryImageUrlString = primaryImageUrl?.absoluteString
        self.thumbnailUrlString = thumbnailUrl?.absoluteString
        self.timezone = timezone
        self.locationLabelOptional = locationLabelOptional
    }
}

/// Represents isolated parsed items detected within the meal
@Model
public final class MealItem {
    @Attribute(.unique) public var id: UUID
    public var eventId: UUID
    public var nameDetected: String
    public var nameNormalized: String
    public var portionUnit: String      // Objective unit: e.g. "cup", "gram", "slice", "bowl"
    public var portionValue: Double     // Objective value: e.g. 1.5, 300, 2
    public var estimatedGramsLikely: Int
    public var confidence: String

    public init(
        id: UUID = UUID(),
        eventId: UUID,
        nameDetected: String,
        nameNormalized: String,
        portionUnit: String,
        portionValue: Double,
        estimatedGramsLikely: Int,
        confidence: String
    ) {
        self.id = id
        self.eventId = eventId
        self.nameDetected = nameDetected
        self.nameNormalized = nameNormalized
        self.portionUnit = portionUnit
        self.portionValue = portionValue
        self.estimatedGramsLikely = estimatedGramsLikely
        self.confidence = confidence
    }
}

/// Versioned, replaceable nutrition calculation derived from model outputs
@Model
public final class EstimateVersion {
    @Attribute(.unique) public var id: UUID
    public var eventId: UUID
    public var modelProvider: String
    public var modelName: String
    public var promptVersion: String
    public var nutritionEngineVersion: String
    public var caloriesLow: Int
    public var caloriesHigh: Int
    public var caloriesLikely: Int
    public var proteinG: Int
    public var carbsG: Int
    public var fatG: Int
    public var fiberG: Int?
    public var confidenceScore: Int
    public var uncertaintyReasons: [String]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        eventId: UUID,
        modelProvider: String,
        modelName: String,
        promptVersion: String,
        nutritionEngineVersion: String,
        caloriesLow: Int,
        caloriesHigh: Int,
        caloriesLikely: Int,
        proteinG: Int,
        carbsG: Int,
        fatG: Int,
        fiberG: Int? = nil,
        confidenceScore: Int,
        uncertaintyReasons: [String] = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.eventId = eventId
        self.modelProvider = modelProvider
        self.modelName = modelName
        self.promptVersion = promptVersion
        self.nutritionEngineVersion = nutritionEngineVersion
        self.caloriesLow = caloriesLow
        self.caloriesHigh = caloriesHigh
        self.caloriesLikely = caloriesLikely
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.fiberG = fiberG
        self.confidenceScore = confidenceScore
        self.uncertaintyReasons = uncertaintyReasons
        self.createdAt = createdAt
    }
}

/// Compounds localized user habits, signatures, and default calibration counts
@Model
public final class PersonalMemory {
    @Attribute(.unique) public var id: UUID
    public var userId: String
    public var foodSignature: String
    public var displayName: String
    public var usualPortionUnit: String?
    public var usualPortionValue: Double?
    public var usualCaloriesLikely: Int
    public var correctionCount: Int
    public var confidenceScore: Int
    public var lastSeenAt: Date

    public init(
        id: UUID = UUID(),
        userId: String,
        foodSignature: String,
        displayName: String,
        usualPortionUnit: String? = nil,
        usualPortionValue: Double? = nil,
        usualCaloriesLikely: Int,
        correctionCount: Int = 0,
        confidenceScore: Int = 50,
        lastSeenAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.foodSignature = foodSignature
        self.displayName = displayName
        self.usualPortionUnit = usualPortionUnit
        self.usualPortionValue = usualPortionValue
        self.usualCaloriesLikely = usualCaloriesLikely
        self.correctionCount = correctionCount
        self.confidenceScore = confidenceScore
        self.lastSeenAt = lastSeenAt
    }
}

/// Materialized high-speed dashboard aggregation cache
@Model
public final class DailyRollup {
    public var userId: String
    public var date: Date
    public var caloriesLow: Int
    public var caloriesHigh: Int
    public var caloriesLikely: Int
    public var proteinG: Int
    public var carbsG: Int
    public var fatG: Int
    public var eventsCount: Int
    public var photoLogsCount: Int
    public var noImageLogsCount: Int
    public var confidenceScore: Int

    public init(
        userId: String,
        date: Date,
        caloriesLow: Int = 0,
        caloriesHigh: Int = 0,
        caloriesLikely: Int = 0,
        proteinG: Int = 0,
        carbsG: Int = 0,
        fatG: Int = 0,
        eventsCount: Int = 0,
        photoLogsCount: Int = 0,
        noImageLogsCount: Int = 0,
        confidenceScore: Int = 100
    ) {
        self.userId = userId
        self.date = date
        self.caloriesLow = caloriesLow
        self.caloriesHigh = caloriesHigh
        self.caloriesLikely = caloriesLikely
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.eventsCount = eventsCount
        self.photoLogsCount = photoLogsCount
        self.noImageLogsCount = noImageLogsCount
        self.confidenceScore = confidenceScore
    }
}

/// Dynamic Calibration Questionnaire UI Contract Structure
public struct PortionQuestion: Codable, Hashable {
    public let id: String
    public let question: String
    public let options: [String]
    public let defaultOption: String
    public let correctionType: String
    public let uiType: String           // e.g. "slice_counter", "fraction_picker", "unit_slider", "single_choice"

    public init(
        id: String,
        question: String,
        options: [String],
        defaultOption: String,
        correctionType: String,
        uiType: String
    ) {
        self.id = id
        self.question = question
        self.options = options
        self.defaultOption = defaultOption
        self.correctionType = correctionType
        self.uiType = uiType
    }

    enum CodingKeys: String, CodingKey {
        case id
        case question
        case options
        case defaultOption = "default_option"
        case correctionType = "correction_type"
        case uiType = "ui_type"
    }
}
