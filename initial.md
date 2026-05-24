Product position
One rule: no normal food log without an image.
Voice is allowed as an annotation. Text is allowed as an annotation. But the default record must be:
photo first → optional voice/text → AI estimate → one-tap correction → saved ledger
Exception: backfill logs are allowed, but visually marked as low confidence / no image. They should not feel equal to photo logs.
This is the Apple-like opinionated stance.
The final product
Working name: Intake
Tagline:
Your body’s activity log.
Core promise:
Take a photo before eating. Intake remembers what you ate, estimates calories/macros, learns your portions, and shows your body-input patterns over time.
Not:
“Track calories manually.”
Not:
“AI diet coach.”
The killer loop:
Open app
→ camera is already open
→ snap food
→ optionally speak: “Kerala rice, meen curry, thoran”
→ AI estimates items + range
→ user taps one correction if needed
→ daily intake dashboard updates
Opinionated UX rules
1. Camera is the home screen
When the user opens the app, they should not see charts first.
They see:
[Full-screen camera]

Bottom:
[Last meal]     [Shutter]     [Voice note]

Top:
Today: ~1,620 kcal logged
Protein: 54g
Confidence: 82%
This trains the habit.
Second-order effect: the app becomes “take a photo before eating,” not “remember later and fill a form.”
2. Calories are displayed as a range
Never fake precision.
Bad:
743 kcal
Good:
680–850 kcal
Likely: 760
Confidence: Medium
This preserves trust.
3. The app asks only one correction
Example:
Biggest uncertainty: rice quantity.
Was it closer to:
[Small] [Medium] [Large]
Not a form. Not grams. Not “enter macros.”
4. Voice is an enhancer, not primary input
User can say:
“This is Kerala matta rice, fish curry, beetroot thoran, one pappadam.”
That helps the model, especially with Indian food where photos alone can confuse curries.
5. Raw logs are sacred; estimates are replaceable
The photo, timestamp, voice note, and text are the truth.
The calories are a derived estimate.
Later, when the model improves, you can reprocess old meals.
Five core user flows
Flow 1: Normal meal capture
User opens app before lunch.
UI:
Camera opens instantly.
User takes photo.
App shows "Analyzing…"
Review screen:
Photo at top

Detected:
- Kerala matta rice
- Fish curry
- Cabbage thoran
- Pappadam

Estimate:
720–940 kcal
Likely: 810 kcal

Confidence: Medium

One question:
Rice quantity?
[Small] [Medium] [Large]

[Save Meal]
Second-order effect: every meal creates a visual ledger. Even if estimates are imperfect, capture completeness becomes high.
Flow 2: Complex Kerala meal
User photographs a messy plate: rice, curry, thoran, avial, pickle.
AI is uncertain.
UI should not collapse into fake confidence.
Detected with uncertainty:

✓ Rice — high confidence
✓ Thoran — medium confidence
? Curry type — low confidence
? Oil/coconut amount — unknown

Likely total:
850–1,150 kcal

Biggest uncertainty:
Curry + oil quantity

Quick refine:
[Fish curry] [Chicken curry] [Sambar] [Other]
User taps “Fish curry.”
Then:
Updated:
780–980 kcal
Likely: 870 kcal
Second-order effect: the app learns food signatures like:
Home lunch: matta rice + fish curry + thoran
Usual rice portion: large
Usual curry serving: medium bowl
Flow 3: Snack / packaged food
User takes photo of chips, drink, protein bar, bakery item.
UI:
Detected:
- Banana chips packet
- Nutrition label visible

Action:
[Use label] [Estimate from image]
If label exists, use OCR + label values. If not, AI estimates.
Second-order effect: packaged foods become high-confidence logs, while homemade foods remain range-based.
Flow 4: Missed meal / no image
User forgot to take a photo.
They open app and tap:
+ Backfill without photo
UI deliberately makes this feel inferior:
No-image log
Confidence will be lower.

What did you eat?
[Voice] [Text]
Result:
Logged: “2 dosas, chutney, sambar”
Estimate: 450–700 kcal
Confidence: Low
Reason: no image, no portion evidence
Second-order effect: you don’t lose the user when they forget, but the product still trains photo-first behavior.
Flow 5: Weekly intake intelligence
After 7–14 days, app starts showing useful patterns.
UI:
This week

Average daily intake:
2,250–2,650 kcal

Most repeated foods:
1. Kerala rice
2. Fish curry
3. Eggs
4. Porotta
5. Tea/coffee

Hidden calorie sources:
- Rice portions
- Fried snacks
- Oil-heavy curries

Protein consistency:
Low on 5/7 days

Late eating:
Dinner after 10 PM on 4 days
Second-order effect: this becomes like iOS Screen Time. The user doesn’t need perfect accuracy to become aware.
Display model
Every meal card should show three layers:
1. What was logged
Photo
Time
Optional voice/text note
2. What AI thinks it is
Rice + fish curry + thoran + pappadam
3. What the app estimates
Calories: 720–940
Likely: 810
Protein: 32g
Carbs: 105g
Fat: 28g
Confidence: Medium
Then a small honesty line:
Most uncertain: rice quantity + oil in curry
That one line is trust.
Backend architecture
The architecture should be event-sourced.
Core principle
Raw event = truth
Estimate = versioned interpretation
Correction = training signal
Daily dashboard = derived view
Main pipeline
Mobile app
→ compress image locally
→ create food_event row
→ request R2 presigned upload URL
→ upload image directly to R2
→ enqueue analysis job
→ AI vision parses meal
→ nutrition engine estimates range
→ save estimate_version
→ update daily_rollup
→ return review UI
R2 direct upload is the right call. Cloudflare’s R2 supports presigned URLs for temporary upload/download access, and the docs explicitly describe client-side uploads where the server generates a presigned PUT URL so the client uploads directly without exposing credentials.
For browser/web uploads, configure CORS too; Cloudflare notes that browser-based presigned URL uploads/downloads still need a CORS policy even though the URL itself handles authentication.
Data model
food_events
The immutable meal log.
id
user_id
created_at
meal_time
capture_type -- photo, photo_voice, backfill_text, backfill_voice
status -- pending, analyzed, needs_review, saved, failed
timezone
location_label_optional
raw_text_note
voice_url_optional
primary_image_url
thumbnail_url
source -- ios, android, web, import
food_media
id
event_id
media_type -- image, voice
r2_key
width
height
bytes
mime_type
sha256
created_at
meal_items
id
event_id
name_detected
name_normalized
food_signature
portion_label -- small, medium, large, bowl, plate, piece
estimated_grams_low
estimated_grams_high
estimated_grams_likely
confidence
estimate_versions
Never overwrite estimates. Version them.
id
event_id
model_provider
model_name
prompt_version
nutrition_engine_version
calories_low
calories_high
calories_likely
protein_g
carbs_g
fat_g
fiber_g
confidence_score
uncertainty_reasons
created_at
corrections
id
event_id
item_id
correction_type -- portion, food_name, delete_item, add_item
old_value
new_value
created_at
personal_food_memory
This is the compounding asset.
id
user_id
food_signature
display_name
usual_portion_label
usual_calories_low
usual_calories_high
usual_calories_likely
correction_count
confidence_score
last_seen_at
daily_rollups
Fast dashboard table.
user_id
date
calories_low
calories_high
calories_likely
protein_g
carbs_g
fat_g
events_count
photo_logs_count
no_image_logs_count
confidence_score
Image handling
Do not upload raw huge images by default.
On-device:
Capture original
→ strip EXIF
→ create thumbnail: ~300px
→ create analysis image: 1024–1600px long edge
→ encode as WebP or JPEG
→ upload analysis image to R2
→ keep original locally only if user enables it
Why: AI recognition does not need a 12MP photo most of the time. You need enough detail to identify items and portions, not poster-quality storage.
OpenAI’s current image input docs support PNG, JPEG, WEBP, and non-animated GIF inputs, and the Responses API supports image inputs with text/JSON outputs, which fits this exact use case.
AI architecture
Do not do one AI call that guesses everything.
Use a staged pipeline.
Stage 1: Vision parse
Input:
image + optional voice/text
Output:
{
  "meal_type": "lunch",
  "items": [
    {
      "name": "Kerala matta rice",
      "visual_confidence": 0.91,
      "portion_label": "large",
      "portion_confidence": 0.64
    },
    {
      "name": "fish curry",
      "visual_confidence": 0.72,
      "portion_label": "medium bowl",
      "portion_confidence": 0.52
    }
  ],
  "uncertainties": [
    "oil quantity",
    "rice depth",
    "curry type"
  ],
  "one_question": {
    "question": "Was the rice closer to small, medium, or large?",
    "options": ["small", "medium", "large"]
  }
}
Stage 2: Nutrition engine
This is not “seed every food.”
This is:
global primitive priors
+ regional dish templates
+ user memory
+ current image estimate
= calorie range
Examples of primitives:
cooked rice
oil
coconut
fish
chicken
egg
beef
dal
curd
milk
sugar
banana
wheat/flour
Examples of dish templates:
thoran = vegetable + coconut + oil
fish curry = fish + gravy + oil
avial = vegetables + coconut + curd + oil
porotta = flour + oil
sambar = dal + vegetables
You are not building a static food database. You are building a calibration layer.
Stage 3: Personal memory adjustment
If user usually eats large rice portions:
visual estimate: medium-large
personal prior: large
final: large
Stage 4: Save estimate version
Every result gets saved with:
model version
prompt version
nutrition engine version
confidence
uncertainty
This lets you reprocess old logs later.
Cloud vs open-source model
You should support three modes.
Mode 1: Managed Cloud
Best UX.
User pays you.
You provide:
Supabase
R2 storage
AI inference
sync
backups
dashboard
model upgrades
User does nothing technical.
This is the paid product.
Mode 2: BYOK private mode
User uses your app but brings their own OpenAI API key.
Important: ChatGPT Plus cannot be used as a general API quota for your app. OpenAI’s Help Center says ChatGPT Plus is for enhanced access to the ChatGPT web app, and API usage is separate and billed independently. OpenAI also says API service is billed and managed separately from ChatGPT subscriptions.
So the realistic BYOK flow is:
User enters OpenAI API key
→ key stored in iOS Keychain / Android Keystore
→ app calls OpenAI directly or through user’s self-hosted worker
→ user pays OpenAI directly
Do not store BYOK keys on your server.
Mode 3: Full self-host
For privacy nerds and open-source users.
Options:
A. Local-only
- SQLite on device
- images stored on device
- optional API key
- export JSON/CSV

B. Self-host cloud
- user's Supabase
- user's R2/S3-compatible storage
- user's AI API key
- user's worker/functions
Is “one-click create Supabase” possible?
Yes, but not casually from the mobile app.
Supabase has a Management API for creating/managing projects, and their docs say OAuth2 is meant for third-party apps that need to create/manage Supabase projects on behalf of users with scoped short-lived tokens. Supabase for Platforms also documents project creation through POST /v1/projects.
So you can build a web setup wizard:
Open-source setup
→ “Connect Supabase”
→ user logs into Supabase OAuth
→ choose organization
→ wizard creates project
→ waits for health
→ applies migrations
→ creates storage bucket config
→ returns app config QR code
→ mobile app scans config
But for v1 self-host, simpler is better:
supabase init
supabase start
supabase db push
Supabase CLI supports local development and deployment, and their docs show supabase init and supabase start as the local setup path. Migrations are the normal way to track and apply schema changes.
My call:
Managed Cloud first.
Open-source local mode second.
One-click Supabase integration third.
Do not let self-host complexity delay the main product.
Recommended tech stack
Best product stack
Mobile:
SwiftUI iOS first

Backend:
Supabase Postgres
Supabase Auth
Supabase Edge Functions or Cloudflare Workers

Storage:
Cloudflare R2

Queue:
Cloudflare Queues / Supabase pgmq / simple jobs table initially

AI:
OpenAI Responses API for vision + structured JSON
Fallback/local option later: Ollama-compatible vision model if self-host users want it

Analytics:
PostHog or self-hosted event table

Exports:
JSON, CSV, Health-style monthly archive
Why SwiftUI first? Because you explicitly want Apple-like UX. Camera-native apps live or die by feel: launch speed, camera transition, haptics, review screen, offline queue, local storage. React Native can work, but native iOS is the sharper product call.
Open-source repo structure
intake/
  apps/
    ios/
    web-setup/
  packages/
    schema/
    nutrition-engine/
    ai-prompts/
    shared-types/
  supabase/
    migrations/
    seed/
    functions/
  workers/
    r2-signer/
    ai-analyzer/
  docs/
    self-host.md
    cloud-architecture.md
Cloud upload design
Do this:
1. App creates event in Supabase.
2. Backend returns presigned R2 PUT URL.
3. App uploads compressed image directly to R2.
4. App marks media uploaded.
5. Backend analysis worker reads image URL/key.
6. AI analyzes.
7. Result saved to Supabase.
Do not pipe images through your API server. Waste of bandwidth and money.
R2 is designed for S3-compatible object storage and has Workers API / S3-compatible API surfaces.
ChatGPT integration later
There are two separate ideas:
1. Use OpenAI API inside your app
This needs API billing or BYOK API key. ChatGPT Plus does not cover it.
2. Build a ChatGPT app/connector
Later, you can let users ask inside ChatGPT:
“What did I eat this week?”
OpenAI’s Apps SDK uses MCP servers and can support OAuth flows where ChatGPT connects to your service.
That is useful, but it does not replace your mobile app. Your mobile app owns capture. ChatGPT can be an analysis surface later.
Final product spec in one sentence
A camera-first intake ledger where every meal is photographed, compressed, stored, interpreted by AI, estimated as a calorie/macro range, corrected with one tap, and accumulated into a personal nutrition telemetry graph.
Build this like this:
Photo is mandatory.
Voice is context.
AI is interpretation.
Database is memory.
Calories are probabilistic.
Corrections are training data.
Dashboard is awareness.
That is the product.