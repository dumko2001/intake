-- Intake Pure Cloudflare D1 SQLite Schema
-- Event-Sourced Personal Nutrition Observability Database

-- 1. Immutable Event Ledger
CREATE TABLE IF NOT EXISTS food_events (
    id TEXT PRIMARY KEY,               -- UUID string
    user_id TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    meal_time TEXT NOT NULL,           -- e.g., "13:20"
    meal_type TEXT NOT NULL,           -- e.g., "breakfast", "lunch", "dinner", "snack"
    capture_type TEXT NOT NULL,        -- e.g., "photo", "photo_voice", "backfill_text", "backfill_voice"
    status TEXT NOT NULL DEFAULT 'pending', -- e.g., "pending", "analyzed", "needs_review", "saved", "failed"
    raw_text_note TEXT,
    primary_image_url TEXT,
    thumbnail_url TEXT,
    timezone TEXT NOT NULL DEFAULT 'UTC',
    location_label_optional TEXT
);

CREATE INDEX IF NOT EXISTS idx_food_events_user ON food_events(user_id, created_at DESC);

-- 2. Visual & Auditory Media Records
CREATE TABLE IF NOT EXISTS food_media (
    id TEXT PRIMARY KEY,
    event_id TEXT NOT NULL REFERENCES food_events(id) ON DELETE CASCADE,
    media_type TEXT NOT NULL,          -- e.g., "image", "voice"
    r2_key TEXT NOT NULL,              -- R2 Bucket identifier
    width INTEGER,
    height INTEGER,
    bytes INTEGER,
    mime_type TEXT NOT NULL,
    sha256 TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_food_media_event ON food_media(event_id);

-- 3. Isolated Detected Ingredients (using objective physical units instead of relative portions)
CREATE TABLE IF NOT EXISTS meal_items (
    id TEXT PRIMARY KEY,
    event_id TEXT NOT NULL REFERENCES food_events(id) ON DELETE CASCADE,
    name_detected TEXT NOT NULL,
    name_normalized TEXT NOT NULL,
    portion_unit TEXT NOT NULL,        -- e.g. "cup", "gram", "slice", "bowl", "piece"
    portion_value REAL NOT NULL,       -- e.g. 1.5, 300, 2, 1
    estimated_grams_likely INTEGER,
    confidence TEXT NOT NULL           -- e.g. "High", "Medium", "Low"
);

CREATE INDEX IF NOT EXISTS idx_meal_items_event ON meal_items(event_id);

-- 4. Versioned derived estimate outputs
CREATE TABLE IF NOT EXISTS estimate_versions (
    id TEXT PRIMARY KEY,
    event_id TEXT NOT NULL REFERENCES food_events(id) ON DELETE CASCADE,
    model_provider TEXT NOT NULL,      -- e.g., "google-ai"
    model_name TEXT NOT NULL,          -- e.g., "gemini-3.5-flash"
    prompt_version TEXT NOT NULL,
    nutrition_engine_version TEXT NOT NULL,
    calories_low INTEGER NOT NULL,
    calories_high INTEGER NOT NULL,
    calories_likely INTEGER NOT NULL,
    protein_g INTEGER NOT NULL,
    carbs_g INTEGER NOT NULL,
    fat_g INTEGER NOT NULL,
    fiber_g INTEGER,
    confidence_score INTEGER NOT NULL,
    uncertainty_reasons TEXT NOT NULL,  -- JSON string array
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

CREATE INDEX IF NOT EXISTS idx_estimate_versions_event ON estimate_versions(event_id, created_at DESC);

-- 5. User Corrections & Calibration Streams
CREATE TABLE IF NOT EXISTS corrections (
    id TEXT PRIMARY KEY,
    event_id TEXT NOT NULL REFERENCES food_events(id) ON DELETE CASCADE,
    item_id TEXT,
    correction_type TEXT NOT NULL,     -- e.g., "portion", "food_name", "add_item"
    old_value TEXT NOT NULL,
    new_value TEXT NOT NULL,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);

-- 6. Personalized Calibration Prior memory layer
CREATE TABLE IF NOT EXISTS personal_food_memory (
    id TEXT PRIMARY KEY,
    user_id TEXT NOT NULL,
    food_signature TEXT NOT NULL,      -- e.g., "home_lunch_matta_rice"
    display_name TEXT NOT NULL,
    usual_portion_unit TEXT,           -- e.g. "cup"
    usual_portion_value REAL,          -- e.g. 1.5
    usual_calories_likely INTEGER,
    correction_count INTEGER DEFAULT 0,
    confidence_score INTEGER NOT NULL DEFAULT 50,
    last_seen_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now')),
    UNIQUE(user_id, food_signature)
);

CREATE INDEX IF NOT EXISTS idx_personal_memory ON personal_food_memory(user_id, food_signature);

-- 7. High-Speed aggregates rollup cache
CREATE TABLE IF NOT EXISTS daily_rollups (
    user_id TEXT NOT NULL,
    date TEXT NOT NULL,                -- e.g. "2026-05-24"
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

-- 8. Secure Serverless Passwordless OTP Storage
CREATE TABLE IF NOT EXISTS otp_codes (
    email TEXT PRIMARY KEY,
    code TEXT NOT NULL,
    expires_at INTEGER NOT NULL
);

-- 9. Edge-Constrained High-Speed Telemetry Log (Signal Only)
CREATE TABLE IF NOT EXISTS telemetry_logs (
    id TEXT PRIMARY KEY,
    event_type TEXT NOT NULL,
    duration_ms INTEGER NOT NULL,
    tokens_used INTEGER,
    error_message TEXT,
    created_at TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ', 'now'))
);
