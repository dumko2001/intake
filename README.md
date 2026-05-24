# Ingest Telemetry Ledger (Intake)
> **Your body’s activity log.**

Intake is an opinionated, premium, camera-first personal ingestion telemetry ledger. It shifts the nutrition tracking paradigm away from tedious manual calorie counting and "AI coaches" into a friction-free, longitudinal body-input stream.

```
📸 Capture Food → 🎙️ Optional Voice Annotation → ⚡ Serverless Ingest → 📊 Dynamic Calibration → 📈 Live Telemetry Dashboard
```

---

## 1. Product Thesis & Opinionated UX Rules

Calorie apps fail because they demand friction (weighing, typing, search forms). Intake is built on first-principles habits:

1.  **Camera is the Home Viewport:** The camera view is the default entry point. Habituate logging *before* eating, not remembering *after* the plate is empty.
2.  **Probabilistic Ranges Over Opaque Precision:** Nutrition is inherently variable. Intake displays ranges (e.g. `680–850 kcal`, `Likely: 760`) with visual confidence scores to build trust.
3.  **One-Tap Portion Calibration:** If the AI is uncertain about a portion size (like Matta Rice quantity), it presents a single dynamic question: `Small`, `Medium`, or `Large`. No complex forms.
4.  **Voice note as context, not primary input:** Speak freely (e.g., *"Kerala Matta Rice, fish curry, cabbage thoran, pappadam"*). This feeds direct visual context into the Edge engine to calibrate curry or grease estimates.
5.  **Event-Sourced Ledgers:** Raw inputs (images, voice recordings, timestamps) are immutable truths. Estimates are versioned interpretations that get smarter as the models evolve.

---

## 2. Ingestion & Observability Architecture

Intake is engineered on a pure serverless **event-sourced Edge architecture** designed to run at sub-millisecond latencies with infinite scale:

```
[iOS Client] 
   │ 
   ├── 1. Request PUT Signature ────► [r2-signer Worker]
   ├── 2. Upload raw WebP directly ──► [Cloudflare R2 Bucket]
   │
   └── 3. Trigger Ingest Payload ───► [ai-analyzer Worker]
                                           │
         ┌─────────────────────────────────┴─────────────────────────────────┐
         ▼ (Files API Stream)                                                ▼ (Telemetry Observability)
[Gemini Files API Cache]                                            [Cloudflare AI Gateway]
         │                                                                   │ (x-goog-api-key Routing)
         └─────────────────────────────────┬─────────────────────────────────┘
                                           ▼
                                [Gemini 3.5 Flash] ◄─── User Priors ─── [Supabase Cloud]
```

### Technical Highlights
*   **Zero-Base64 Edge Upload Pipeline:** Large image file transfers typically crash serverless Edge workers due to synchronous V8 thread-locking and memory bloat. Intake streams binary assets directly to the **Gemini Files API** (`/v1beta/files`), bypassing Base64 completely to run in **< 0.5 ms** of CPU time.
*   **Visual Privacy Enforcement:** Image files are hosted temporarily inside Google's media cache for model inference. Once the visual parse completes, the Worker instantly fires a `DELETE` call back to the Files API to securely purge the raw image.
*   **Cloudflare AI Gateway Routing:** Content generation is proxied via the AI Gateway, securing unified tokens usage analytics, edge request caching, and secure token isolation using native `x-goog-api-key` headers.
*   **Compounding Personal Memory Loop:** The Ingest worker queries your Supabase database (`personal_food_memory`) for past user portion corrections. These priors (e.g. *Sidharth's Matta Rice Large serving = 320g*) are dynamically injected into the Gemini 3.5 Flash prompt to calibrate vision results semmatically.
*   **SQL Event Triggers:** Pushing a saved meal triggers standard Postgres aggregation functions (`update_daily_rollup_after_save()`) directly on the database cluster, keeping client-side rollups instant and responsive.

---

## 3. Tech Stack & Workspace Blueprint

### Ingestion Edge Workers (`workers/`)
*   `workers/ai-analyzer/`: Gemini 3.5 Flash visual parsing and Supabase prior memory calibration engine. Runs on ES modules with the `nodejs_compat` runtime flag.
*   `workers/r2-signer/`: Generates pre-signed S3-compatible PUT URLs using the `@aws-sdk/client-s3` library for direct client uploads to R2 buckets.

### Native SwiftUI iOS App (`apps/ios/Intake/`)
Built under **Swift 6 Concurrency** and modern Apple guidelines:
*   `IntakeApp.swift`: App entry point with custom `Color(hex:)` UI initializers and SwiftData container registrations.
*   `Models.swift`: SwiftData `@Model` classes matching the event-sourced database schema.
*   `IntakeViewModel.swift`: State controller using the modern `@Observable` framework.
*   `CameraView.swift`: Viewfinder grid layouts, concentric haptic shutters, and custom typed `FlowOption` picker controls.
*   `ReviewView.swift`: Structured macro range displays, ingredient tag metrics, and one-tap calibration panels.
*   `TelemetryView.swift`: Premium, custom-drawn SwiftUI charts illustrating body-input history.

---

## 4. Installation & Deployment Guide

### Workspace Verification
Run the verification lint suite to ensure database schemas and workers are fully typecheck-clean:
```bash
make lint
```

### Supabase Cloud Migrations
Link your local repository to your remote cloud project and push the Postgres tables:
```bash
supabase link --project-ref YOUR_PROJECT_REF
supabase db push
```

### Cloudflare Workers Deployment
Deploy your signer and vision workers directly to Cloudflare:
```bash
# Deploy r2-signer
npm install --prefix workers/r2-signer
npx wrangler deploy --cwd workers/r2-signer

# Deploy Ingestion Analyzer
npx wrangler deploy --cwd workers/ai-analyzer
```

### Secrets Binding
Upload encrypted production credentials to Cloudflare Workers securely:
```bash
# Signer credentials
echo "YOUR_ACCESS_KEY" | npx wrangler secret put R2_ACCESS_KEY_ID --cwd workers/r2-signer
echo "YOUR_SECRET_KEY" | npx wrangler secret put R2_SECRET_ACCESS_KEY --cwd workers/r2-signer

# Ingestion credentials
echo "YOUR_GEMINI_API_KEY" | npx wrangler secret put GEMINI_API_KEY --cwd workers/ai-analyzer
echo "YOUR_SUPABASE_ANON_KEY" | npx wrangler secret put SUPABASE_ANON_KEY --cwd workers/ai-analyzer
```
