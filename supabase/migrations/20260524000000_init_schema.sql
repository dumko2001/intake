-- Intake Production Initial Schema Migration
-- Event-Sourced Personal Nutrition Observability System

-- Enable UUID extension
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- =========================================================================
-- 1. Immutable Event Ledger (food_events)
-- =========================================================================
CREATE TABLE IF NOT EXISTS food_events (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    meal_time VARCHAR(10) NOT NULL, -- e.g., "13:20"
    meal_type VARCHAR(20) NOT NULL, -- e.g., "breakfast", "lunch", "dinner", "snack"
    capture_type VARCHAR(30) NOT NULL, -- e.g., "photo", "photo_voice", "backfill_text", "backfill_voice"
    status VARCHAR(20) NOT NULL DEFAULT 'pending', -- e.g., "pending", "analyzed", "needs_review", "saved", "failed"
    raw_text_note TEXT,
    primary_image_url TEXT,
    thumbnail_url TEXT,
    timezone VARCHAR(50) NOT NULL DEFAULT 'UTC',
    location_label_optional TEXT
);

CREATE INDEX IF NOT EXISTS idx_food_events_user_date ON food_events(user_id, created_at DESC);

-- =========================================================================
-- 2. Visual and Auditory Media Records (food_media)
-- =========================================================================
CREATE TABLE IF NOT EXISTS food_media (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES food_events(id) ON DELETE CASCADE,
    media_type VARCHAR(20) NOT NULL, -- e.g., "image", "voice"
    r2_key TEXT NOT NULL,            -- Cloudflare R2 identifier
    width INTEGER,
    height INTEGER,
    bytes INTEGER,
    mime_type VARCHAR(50) NOT NULL,
    sha256 VARCHAR(64) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_food_media_event ON food_media(event_id);

-- =========================================================================
-- 3. Isolated Detected Ingredients (meal_items)
-- =========================================================================
CREATE TABLE IF NOT EXISTS meal_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES food_events(id) ON DELETE CASCADE,
    name_detected TEXT NOT NULL,
    name_normalized TEXT NOT NULL,
    portion_label VARCHAR(50), -- e.g., "small", "medium", "large", "bowl", "piece"
    estimated_grams_low INTEGER,
    estimated_grams_high INTEGER,
    estimated_grams_likely INTEGER,
    confidence VARCHAR(20) NOT NULL -- e.g., "High", "Medium", "Low"
);

CREATE INDEX IF NOT EXISTS idx_meal_items_event ON meal_items(event_id);

-- =========================================================================
-- 4. Versioned derived estimate outputs (estimate_versions)
-- =========================================================================
CREATE TABLE IF NOT EXISTS estimate_versions (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES food_events(id) ON DELETE CASCADE,
    model_provider VARCHAR(50) NOT NULL, -- e.g., "openai", "anthropic"
    model_name VARCHAR(100) NOT NULL,     -- e.g., "gpt-4o-vision-2024-11-20"
    prompt_version VARCHAR(20) NOT NULL,
    nutrition_engine_version VARCHAR(20) NOT NULL,
    calories_low INTEGER NOT NULL,
    calories_high INTEGER NOT NULL,
    calories_likely INTEGER NOT NULL,
    protein_g INTEGER NOT NULL,
    carbs_g INTEGER NOT NULL,
    fat_g INTEGER NOT NULL,
    fiber_g INTEGER,
    confidence_score INTEGER NOT NULL, -- e.g., 0 - 100
    uncertainty_reasons TEXT[] NOT NULL DEFAULT '{}',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_estimate_versions_event ON estimate_versions(event_id, created_at DESC);

-- =========================================================================
-- 5. User Corrections & Calibration Streams (corrections)
-- =========================================================================
CREATE TABLE IF NOT EXISTS corrections (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    event_id UUID NOT NULL REFERENCES food_events(id) ON DELETE CASCADE,
    item_id TEXT,                    -- Can tie to meal_items
    correction_type VARCHAR(30) NOT NULL, -- e.g., "portion", "food_name", "add_item"
    old_value TEXT NOT NULL,
    new_value TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_corrections_event ON corrections(event_id);

-- =========================================================================
-- 6. Personalized Calibration Prior memory layer (personal_food_memory)
-- =========================================================================
CREATE TABLE IF NOT EXISTS personal_food_memory (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id TEXT NOT NULL,
    food_signature TEXT NOT NULL,  -- e.g., "home_lunch_matta_rice"
    display_name TEXT NOT NULL,
    usual_portion_label VARCHAR(50),
    usual_calories_low INTEGER,
    usual_calories_high INTEGER,
    usual_calories_likely INTEGER,
    correction_count INTEGER DEFAULT 0,
    confidence_score INTEGER NOT NULL DEFAULT 50,
    last_seen_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT uq_user_signature UNIQUE (user_id, food_signature)
);

CREATE INDEX IF NOT EXISTS idx_personal_memory_lookup ON personal_food_memory(user_id, food_signature);

-- =========================================================================
-- 7. High-Speed aggregates rollup cache (daily_rollups)
-- =========================================================================
CREATE TABLE IF NOT EXISTS daily_rollups (
    user_id TEXT NOT NULL,
    date DATE NOT NULL,
    calories_low INTEGER NOT NULL DEFAULT 0,
    calories_high INTEGER NOT NULL DEFAULT 0,
    calories_likely INTEGER NOT NULL DEFAULT 0,
    protein_g INTEGER NOT NULL DEFAULT 0,
    carbs_g INTEGER NOT NULL DEFAULT 0,
    fat_g INTEGER NOT NULL DEFAULT 0,
    events_count INTEGER NOT NULL DEFAULT 0,
    photo_logs_count INTEGER NOT NULL DEFAULT 0,
    no_image_logs_count INTEGER NOT NULL DEFAULT 0,
    confidence_score INTEGER NOT NULL DEFAULT 100,
    PRIMARY KEY (user_id, date)
);

-- =========================================================================
-- 8. Row Level Security Mocks (Aesthetic & Practical setup)
-- =========================================================================
ALTER TABLE food_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE food_media ENABLE ROW LEVEL SECURITY;
ALTER TABLE meal_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE estimate_versions ENABLE ROW LEVEL SECURITY;
ALTER TABLE corrections ENABLE ROW LEVEL SECURITY;
ALTER TABLE personal_food_memory ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_rollups ENABLE ROW LEVEL SECURITY;

-- Dynamic functions to re-aggregate rollups on event status update
CREATE OR REPLACE FUNCTION update_daily_rollup_after_save()
RETURNS TRIGGER AS $$
BEGIN
    IF (NEW.status = 'saved') THEN
        INSERT INTO daily_rollups (
            user_id, date, calories_low, calories_high, calories_likely, 
            protein_g, carbs_g, fat_g, events_count, photo_logs_count, 
            no_image_logs_count, confidence_score
        )
        SELECT 
            fe.user_id, 
            DATE(fe.created_at) as log_date,
            SUM(ev.calories_low)::INT,
            SUM(ev.calories_high)::INT,
            SUM(ev.calories_likely)::INT,
            SUM(ev.protein_g)::INT,
            SUM(ev.carbs_g)::INT,
            SUM(ev.fat_g)::INT,
            COUNT(fe.id)::INT as events_count,
            COUNT(CASE WHEN fe.primary_image_url IS NOT NULL THEN 1 END)::INT as photo_logs,
            COUNT(CASE WHEN fe.primary_image_url IS NULL THEN 1 END)::INT as no_photo_logs,
            AVG(ev.confidence_score)::INT as avg_confidence
        FROM food_events fe
        JOIN estimate_versions ev ON fe.id = ev.event_id
        WHERE fe.id = NEW.id
        GROUP BY fe.user_id, log_date
        ON CONFLICT (user_id, date) DO UPDATE SET
            calories_low = EXCLUDED.calories_low,
            calories_high = EXCLUDED.calories_high,
            calories_likely = EXCLUDED.calories_likely,
            protein_g = EXCLUDED.protein_g,
            carbs_g = EXCLUDED.carbs_g,
            fat_g = EXCLUDED.fat_g,
            events_count = EXCLUDED.events_count,
            photo_logs_count = EXCLUDED.photo_logs_count,
            no_image_logs_count = EXCLUDED.no_image_logs_count,
            confidence_score = EXCLUDED.confidence_score;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_food_events_rollup_sync
AFTER INSERT OR UPDATE ON food_events
FOR EACH ROW
EXECUTE FUNCTION update_daily_rollup_after_save();
